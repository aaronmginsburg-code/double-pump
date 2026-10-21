"""Uploads Double Pump's original sounds and map art to Roblox with Open Cloud, then writes
the new asset IDs into src/shared/Config/AssetIds.luau.

You need an Open Cloud API key with the "Assets" API (read + write) for the account or
group that will own the assets. See docs/ASSET_PIPELINE.md for how to create one.

    set ROBLOX_API_KEY=...            (PowerShell: $env:ROBLOX_API_KEY="...")
    python tools/upload_assets.py --user-id 123456789          # assets owned by you
    python tools/upload_assets.py --group-id 987654 --only Fire,Pump
    python tools/upload_assets.py --user-id 123 --dry-run      # list what would upload

Status: written against the documented Open Cloud Assets API (v1) but not run against
the live service from the build environment (no key there). If an upload fails, the
error from Roblox is printed and the remaining files still upload; IDs already in
AssetIds.luau are skipped unless you pass --force.

Requires only the Python standard library.
"""

import argparse
import json
import mimetypes
import os
import re
import sys
import time
import urllib.error
import urllib.request
import uuid

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
ASSET_IDS = os.path.join(ROOT, "src", "shared", "Config", "AssetIds.luau")
AUDIO_DIR = os.path.join(ROOT, "assets", "audio")
IMAGE_DIR = os.path.join(ROOT, "assets", "ui", "maps")
API = "https://apis.roblox.com/assets/v1"

# AssetIds.Images key -> file in assets/ui/maps
IMAGES = {"MapWarehouse": "Warehouse.png", "MapDustTown": "DustTown.png", "MapRooftops": "Rooftops.png"}


def request(method, url, key, body=None, content_type=None):
    req = urllib.request.Request(url, data=body, method=method)
    req.add_header("x-api-key", key)
    if content_type:
        req.add_header("Content-Type", content_type)
    try:
        with urllib.request.urlopen(req, timeout=120) as resp:
            return json.loads(resp.read().decode() or "{}")
    except urllib.error.HTTPError as err:
        detail = err.read().decode(errors="replace")
        raise RuntimeError(f"HTTP {err.code}: {detail}") from None


def multipart(fields, file_field, filename, data, mime):
    boundary = uuid.uuid4().hex
    parts = []
    for name, value in fields.items():
        parts.append(f'--{boundary}\r\nContent-Disposition: form-data; name="{name}"\r\n\r\n{value}\r\n'.encode())
    parts.append(
        f'--{boundary}\r\nContent-Disposition: form-data; name="{file_field}"; filename="{filename}"\r\n'
        f"Content-Type: {mime}\r\n\r\n".encode()
    )
    parts.append(data)
    parts.append(f"\r\n--{boundary}--\r\n".encode())
    return b"".join(parts), f"multipart/form-data; boundary={boundary}"


def upload(key, creator, path, asset_type, display_name, description):
    mime = mimetypes.guess_type(path)[0] or ("audio/ogg" if path.endswith(".ogg") else "image/png")
    if path.endswith(".ogg"):
        mime = "audio/ogg"
    req = {
        "assetType": asset_type,
        "displayName": display_name,
        "description": description,
        "creationContext": {"creator": creator},
    }
    with open(path, "rb") as f:
        body, ctype = multipart({"request": json.dumps(req)}, "fileContent", os.path.basename(path), f.read(), mime)
    op = request("POST", f"{API}/assets", key, body, ctype)
    # Uploads are asynchronous: poll the operation until it finishes
    op_path = op.get("path")
    for _ in range(60):
        if op.get("done"):
            break
        time.sleep(2)
        op = request("GET", f"{API}/{op_path}", key)
    if not op.get("done"):
        raise RuntimeError("upload still processing after 2 minutes; check the Creator Dashboard")
    if "error" in op:
        raise RuntimeError(json.dumps(op["error"]))
    return op["response"]["assetId"]


def decal_to_image(decal_id):
    """A Decal upload has its own ID; ImageLabels need the image inside it. The decal's
    public definition names that image. Returns None if it can't be resolved."""
    try:
        with urllib.request.urlopen(f"https://assetdelivery.roblox.com/v1/asset/?id={decal_id}", timeout=30) as r:
            text = r.read().decode(errors="replace")
        m = re.search(r"\?id=(\d+)", text)
        return m.group(1) if m else None
    except Exception:
        return None


def read_ids():
    with open(ASSET_IDS, encoding="utf-8") as f:
        return f.read()


def current_id(text, name):
    m = re.search(rf"\b{name}\s*=\s*\"(\d*)\"", text)
    return m.group(1) if m else None


def set_id(text, name, asset_id):
    return re.sub(rf"(\b{name}\s*=\s*)\"\d*\"", rf'\g<1>"{asset_id}"', text, count=1)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    who = ap.add_mutually_exclusive_group(required=True)
    who.add_argument("--user-id", type=int)
    who.add_argument("--group-id", type=int)
    ap.add_argument("--only", help="comma-separated names to upload (default: everything missing)")
    ap.add_argument("--force", action="store_true", help="re-upload even if an ID is already set")
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    key = os.environ.get("ROBLOX_API_KEY")
    if not key and not args.dry_run:
        sys.exit("Set ROBLOX_API_KEY first (see docs/ASSET_PIPELINE.md).")
    creator = {"userId": str(args.user_id)} if args.user_id else {"groupId": str(args.group_id)}
    only = set(args.only.split(",")) if args.only else None

    text = read_ids()
    jobs = []
    for file in sorted(os.listdir(AUDIO_DIR)):
        if file.endswith(".ogg"):
            jobs.append((file[:-4], os.path.join(AUDIO_DIR, file), "Audio"))
    for name, file in IMAGES.items():
        path = os.path.join(IMAGE_DIR, file)
        if os.path.exists(path):
            jobs.append((name, path, "Decal"))

    failures = 0
    for name, path, asset_type in jobs:
        if only and name not in only:
            continue
        existing = current_id(text, name)
        if existing is None:
            print(f"skip {name}: no entry in AssetIds.luau")
            continue
        if existing and not args.force:
            print(f"skip {name}: already {existing}")
            continue
        if args.dry_run:
            print(f"would upload {name} ({asset_type}) from {os.path.relpath(path, ROOT)}")
            continue
        try:
            asset_id = upload(key, creator, path, asset_type, f"DoublePump {name}", "Original asset made for Double Pump.")
            if asset_type == "Decal":
                image_id = decal_to_image(asset_id)
                if image_id:
                    asset_id = image_id
                else:
                    print(f"  {name}: decal {asset_id} uploaded; open it in Studio to get its image ID (see docs)")
            text = set_id(text, name, asset_id)
            with open(ASSET_IDS, "w", encoding="utf-8") as f:
                f.write(text)
            print(f"uploaded {name} -> {asset_id}")
        except Exception as err:  # keep going; report at the end
            failures += 1
            print(f"FAILED {name}: {err}")
    if failures:
        sys.exit(f"{failures} upload(s) failed; fix and re-run (finished ones are skipped).")


if __name__ == "__main__":
    main()
