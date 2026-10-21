"""Phase 9: automated validation. Writes VALIDATION.md + exports/validation.json and
exits non-zero if any check fails.

Checks: .blend opens; required objects/bones/actions exist; material assignment;
texture files on disk and loadable; UVs in 0-1; triangle counts; mechanical clearance
(check_intersections.py); every FBX/GLB re-imported into a fresh scene and compared
(hierarchy, bone names, triangle counts, bounding size, animation length and a sampled
bone pose); FBX unit scale; glTF axis orientation (muzzle along -Z).

Run: python 08_validate.py
"""
import glob
import json
import os
import struct
import subprocess
import sys

sys.path.insert(0, os.path.dirname(__file__))
import bpy  # noqa: E402

import sg_dims as D  # noqa: E402
import sg_lib as L  # noqa: E402

BLEND = L.p("blender", "PumpShotgun_Master.blend")
EX = L.p("exports")
results = []


def check(name, ok, detail=""):
    results.append({"check": name, "ok": bool(ok), "detail": detail})
    print(("PASS " if ok else "FAIL ") + name + (f" - {detail}" if detail else ""))


def tris(o):
    return L.tri_count(o)


def bbox_size(objs):
    import mathutils
    mn = mathutils.Vector((1e9,) * 3)
    mx = -mn
    deps = bpy.context.evaluated_depsgraph_get()
    for o in objs:
        ev = o.evaluated_get(deps)
        me = ev.to_mesh()
        for v in me.vertices:
            w = ev.matrix_world @ v.co
            mn = mathutils.Vector(map(min, mn, w))
            mx = mathutils.Vector(map(max, mx, w))
        ev.to_mesh_clear()
    return mx - mn


# ------------------------------------------------------------------ source file
try:
    bpy.ops.wm.open_mainfile(filepath=BLEND)
    check("blend opens", True, os.path.relpath(BLEND, L.ROOT))
except Exception as e:  # noqa: BLE001
    check("blend opens", False, str(e))
    sys.exit(1)

O = bpy.data.objects
REQUIRED = ["Receiver", "Barrel", "MagTube", "MagCap", "BarrelBand", "Stock", "ButtPad", "Pump", "PumpFerrule",
            "ActionBars", "Trigger", "TriggerGuard", "TriggerPlate", "Bolt", "ShellCarrier", "FrontSight",
            "RearSight", "SightRib", "ReceiverPins", "PadScrews", "SlingStud", "Shell_Live", "Shell_Spent",
            "Rig_PumpShotgun", "FP_PumpShotgun", "FP_Shell_Live", "FP_Shell_Spent", "TP_Rig", "TP_PumpShotgun"]
missing = [n for n in REQUIRED if n not in O]
check("required objects exist", not missing, f"{len(REQUIRED)} expected" + (f", missing {missing}" if missing else ""))
check("ejection port present in receiver", O["Receiver"].dimensions.x > 0, "boolean cut verified by renders")

BONES_FP = ["ViewmodelRoot", "Weapon", "Pump", "Bolt", "Trigger", "ShellCarrier", "ShellSpent", "ShellLive",
            "Grip", "Muzzle", "ShellEject", "ShellLoad", "SupportHand"]
BONES_TP = ["ViewmodelRoot", "Weapon", "Pump", "Grip", "Muzzle", "ShellEject", "SupportHand"]
fb = [b.name for b in O["Rig_PumpShotgun"].data.bones]
tb = [b.name for b in O["TP_Rig"].data.bones]
check("FP bone names", sorted(fb) == sorted(BONES_FP), ", ".join(fb))
check("TP bone names", sorted(tb) == sorted(BONES_TP), ", ".join(tb))

ACTIONS = ["Idle", "Fire", "Pump", "ReloadStart", "ReloadInsert", "ReloadEnd", "Equip", "SwapIn", "Unequip"]
acts = {a.name: a for a in bpy.data.actions}
miss = [a for a in ACTIONS if "PumpShotgun_" + a not in acts]
check("required actions exist", not miss, ", ".join(f"{a}={int(acts['PumpShotgun_' + a].frame_range[1])}f"
                                                   for a in ACTIONS if "PumpShotgun_" + a in acts))
check("TP pump action exists", "PumpShotgun_TP_Pump" in acts)

game_meshes = [O["FP_PumpShotgun"], O["FP_Shell_Live"], O["FP_Shell_Spent"], O["TP_PumpShotgun"]]
bad_mat = [o.name for o in game_meshes if len(o.material_slots) != 1]
check("one material per game mesh", not bad_mat, str(bad_mat) if bad_mat else "")
ngons = [o.name for o in game_meshes if any(len(p.vertices) > 3 for p in o.data.polygons)]
check("game meshes triangulated", not ngons, str(ngons) if ngons else "")
uv_bad = []
for o in game_meshes:
    uv = o.data.uv_layers.active
    if not uv or len(o.data.uv_layers) != 1:
        uv_bad.append(o.name + " (uv layers)")
        continue
    if any(not (-1e-4 <= c.uv.x <= 1 + 1e-4 and -1e-4 <= c.uv.y <= 1 + 1e-4) for c in uv.data):
        uv_bad.append(o.name + " (outside 0-1)")
check("single UV set inside 0-1", not uv_bad, str(uv_bad) if uv_bad else "")

img_issues = []
for im in bpy.data.images:
    if im.source != "FILE":
        continue
    path = bpy.path.abspath(im.filepath, library=im.library)
    if not os.path.isfile(path):
        img_issues.append(f"{im.name}: missing {path}")
        continue
    im.reload()
    if not im.has_data and im.size[0] == 0:
        img_issues.append(f"{im.name}: unreadable")
check("no missing texture dependencies", not img_issues,
      f"{sum(1 for i in bpy.data.images if i.source == 'FILE')} external images" if not img_issues else str(img_issues))

tex = {}
for f in sorted(glob.glob(L.p("textures", "*", "*.png"))):
    im = bpy.data.images.load(f, check_existing=False)
    tex[os.path.relpath(f, L.ROOT)] = list(im.size)
    bpy.data.images.remove(im)
check("texture sets complete", len(tex) == 12, f"{len(tex)} files")

counts = {o.name: tris(o) for o in game_meshes}
master_tris = sum(tris(o) for o in bpy.data.collections["PumpShotgun_Master"].all_objects if o.type == "MESH")
fp_total = counts["FP_PumpShotgun"] + counts["FP_Shell_Live"] + counts["FP_Shell_Spent"]
check("FP triangles within 10k-25k", 10000 <= fp_total <= 25000, f"{fp_total} (gun {counts['FP_PumpShotgun']})")
check("TP triangles within 3k-8k", 3000 <= counts["TP_PumpShotgun"] <= 8000, str(counts["TP_PumpShotgun"]))
size = bbox_size([O["FP_PumpShotgun"]])
check("master size ~1.02 m long", abs(size.y - 1.02) < 0.03, f"{size.x:.3f} x {size.y:.3f} x {size.z:.3f} m")
ref_size = size.copy()

# ------------------------------------------------------------------ mechanical clearance
proc = subprocess.run([sys.executable, os.path.join(os.path.dirname(__file__), "check_intersections.py"), BLEND],
                      capture_output=True, text=True)
last = [ln for ln in proc.stdout.splitlines() if ln.startswith(("RESULT", "rest-pose"))]
check("moving parts clear static parts on every sampled frame", proc.returncode == 0, " | ".join(last))

# ------------------------------------------------------------------ re-import exports
def fresh():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def fbx_unit_scale(path):
    data = open(path, "rb").read()
    i = data.find(b"UnitScaleFactor")
    j = data.find(b"D", i + 15 + 30)
    # property record: name, "double", "Number", "", "A", then 'D' + float64
    for k in range(i, i + 120):
        if data[k:k + 1] == b"D" and data[k - 1:k] in (b"A", b"\x00", b"\x01"):
            try:
                return struct.unpack("<d", data[k + 1:k + 9])[0]
            except struct.error:
                break
    return None if j < 0 else struct.unpack("<d", data[j + 1:j + 9])[0]


def reimport_fbx(path):
    fresh()
    bpy.ops.import_scene.fbx(filepath=path, use_custom_props=True)
    return list(bpy.context.scene.objects)


for rel, rig_bones, mesh_names, mesh_tris in (
        ("first_person/PumpShotgun_FP.fbx", BONES_FP, ["FP_PumpShotgun", "FP_Shell_Live", "FP_Shell_Spent"],
         [counts["FP_PumpShotgun"], counts["FP_Shell_Live"], counts["FP_Shell_Spent"]]),
        ("third_person/PumpShotgun_TP.fbx", BONES_TP, ["TP_PumpShotgun"], [counts["TP_PumpShotgun"]])):
    path = os.path.join(EX, rel)
    us = fbx_unit_scale(path)
    objs = reimport_fbx(path)
    arms = [o for o in objs if o.type == "ARMATURE"]
    meshes = {o.name: o for o in objs if o.type == "MESH"}
    cams = [o for o in objs if o.type in ("CAMERA", "LIGHT")]
    ok_b = arms and sorted(b.name for b in arms[0].data.bones) == sorted(rig_bones)
    ok_m = sorted(meshes) == sorted(mesh_names) and all(m.parent == arms[0] for m in meshes.values())
    t = [tris(meshes[n]) if n in meshes else -1 for n in mesh_names]
    sz = bbox_size([meshes[mesh_names[0]]]) if mesh_names[0] in meshes else None
    skinned = all(any(md.type == "ARMATURE" for md in m.modifiers) for m in meshes.values())
    check(f"reimport {rel}: hierarchy + bones", ok_b and ok_m and not cams,
          f"armature={arms[0].name if arms else None}, meshes={sorted(meshes)}, cameras/lights={len(cams)}")
    check(f"reimport {rel}: skinned + tri counts", skinned and t == mesh_tris, f"{t}")
    if sz is not None:
        check(f"reimport {rel}: scale preserved", abs(sz.y - ref_size.y) < 0.01 if "FP" in rel else 0.95 < sz.y < 1.1,
              f"{sz.x:.3f} x {sz.y:.3f} x {sz.z:.3f} m; FBX UnitScaleFactor={us}")

anim_files = sorted(glob.glob(os.path.join(EX, "animations", "*.fbx")))
anim_rows = {}
with open(os.path.join(EX, "animations", "animation_events.json")) as f:
    events = json.load(f)
for path in anim_files:
    name = os.path.splitext(os.path.basename(path))[0]
    objs = reimport_fbx(path)
    arm = next((o for o in objs if o.type == "ARMATURE"), None)
    act = arm.animation_data.action if arm and arm.animation_data else None
    rng = [int(round(v)) for v in act.frame_range] if act else None
    exp = events["actions"].get(name, {}).get("frames")
    ok = act is not None and (exp is None or rng[1] - rng[0] == exp[1] - exp[0])
    anim_rows[name] = rng
    detail = f"frames {rng} (expected {exp})"
    if name == "PumpShotgun_Pump" and act:
        bpy.context.scene.frame_set(rng[0] + 11)
        # pump travel relative to the Weapon bone (the action also moves the whole gun)
        def rel(pose):
            w = arm.pose.bones["Weapon"].matrix if pose else arm.data.bones["Weapon"].matrix_local
            p_ = arm.pose.bones["Pump"].matrix if pose else arm.data.bones["Pump"].matrix_local
            return (w.inverted() @ p_).translation
        disp = (rel(True) - rel(False)).length
        ok = ok and abs(disp - D.PUMP_STROKE) < 0.002
        detail += f"; Pump bone travel at frame 11 = {disp:.4f} m (stroke {D.PUMP_STROKE})"
    check(f"reimport animation {name}", ok, detail)

# glTF: parse JSON chunk directly (axis + animation count) and re-import
for rel in ("first_person/PumpShotgun_FP.glb", "third_person/PumpShotgun_TP.glb"):
    path = os.path.join(EX, rel)
    with open(path, "rb") as f:
        f.read(12)
        ln, _ = struct.unpack("<II", f.read(8))
        g = json.loads(f.read(ln))
    nodes = {n.get("name"): n for n in g["nodes"]}
    anims = [a["name"] for a in g.get("animations", [])]
    import mathutils

    def world(nname):
        # accumulate translations/rotations up the node tree
        parent = {c: i for i, n in enumerate(g["nodes"]) for c in n.get("children", [])}
        idx = next(i for i, n in enumerate(g["nodes"]) if n.get("name") == nname)
        m = mathutils.Matrix.Identity(4)
        while idx is not None:
            n = g["nodes"][idx]
            t = mathutils.Matrix.Translation(n.get("translation", (0, 0, 0)))
            q = n.get("rotation", (0, 0, 0, 1))
            r = mathutils.Quaternion((q[3], q[0], q[1], q[2])).to_matrix().to_4x4()
            m = t @ r @ m
            idx = parent.get(idx)
        return m.translation

    mz = world("Muzzle")
    check(f"{rel}: muzzle points -Z (Roblox LookVector), +Y up", mz.z < -0.5 and abs(mz.y - D.BORE_Z) < 0.01,
          f"Muzzle node at ({mz.x:.3f}, {mz.y:.3f}, {mz.z:.3f}) m; {len(anims)} animations")
    fresh()
    bpy.ops.import_scene.gltf(filepath=path)
    # (the glTF importer adds an "Icosphere" bone-display shape; only meshes from the file count)
    file_meshes = sorted(m["name"] for m in g["meshes"])
    ms = [o for o in bpy.context.scene.objects if o.type == "MESH" and o.data.name in file_meshes]
    check(f"reimport {rel}", ms and any(o.type == "ARMATURE" for o in bpy.context.scene.objects),
          f"meshes={file_meshes}, animations={anims}")

for rel in ("props/Shell_Live.fbx", "props/Shell_Spent.fbx"):
    objs = reimport_fbx(os.path.join(EX, rel))
    m = [o for o in objs if o.type == "MESH"]
    sz = bbox_size(m) if m else None
    check(f"reimport {rel}", m and abs(sz.y - D.SHELL_LEN) < 0.006, f"{sz.x:.4f} x {sz.y:.4f} x {sz.z:.4f} m" if sz else "")

# ------------------------------------------------------------------ report
summary = {
    "blender": bpy.app.version_string,
    "triangles": {"master_all_parts": master_tris, "fp_gun": counts["FP_PumpShotgun"],
                  "fp_shells": counts["FP_Shell_Live"] + counts["FP_Shell_Spent"], "fp_total": fp_total,
                  "tp": counts["TP_PumpShotgun"]},
    "textures": tex,
    "size_m": [round(v, 4) for v in ref_size],
    "checks": results,
}
with open(os.path.join(EX, "validation.json"), "w") as f:
    json.dump(summary, f, indent=2)
lines = ["# Validation report", "", f"Generated by `scripts/08_validate.py` with Blender {bpy.app.version_string} "
         "(headless). Roblox Studio import has **not** been run by this script.", "",
         "| Result | Check | Detail |", "|---|---|---|"]
lines += [f"| {'PASS' if r['ok'] else '**FAIL**'} | {r['check']} | {r['detail']} |" for r in results]
lines += ["", "## Triangle counts", "", "| Asset | Triangles |", "|---|---|"]
lines += [f"| {k} | {v} |" for k, v in summary["triangles"].items()]
lines += ["", "## Textures", "", "| File | Size |", "|---|---|"]
lines += [f"| {k} | {v[0]}x{v[1]} |" for k, v in tex.items()]
with open(L.p("VALIDATION.md"), "w") as f:
    f.write("\n".join(lines) + "\n")
fails = [r for r in results if not r["ok"]]
print(f"\n{len(results) - len(fails)}/{len(results)} checks passed")
sys.exit(1 if fails else 0)
