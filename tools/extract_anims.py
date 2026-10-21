"""Bakes the shotgun's Blender animations (from the exported glTF files) into a Luau data module.

Each frame stores, per moving bone, a rigid "model-space delta" D such that
    bone_world_animated = root * D * bone_world_rest_relative_to_root
in Roblox axes (muzzle -Z, up +Y) and studs. Because D is in model space it does not
depend on how Roblox's FBX importer orients each Bone's local axes, so the same data
drives the imported Bones (via Bone.Transform) and the stand-in model's parts.

Usage: python3 tools/extract_anims.py <PumpShotgun dir> src/shared/Weapons/ShotgunAnimData.luau
"""
import json, sys
import numpy as np
from pygltflib import GLTF2

STUD_M = 0.28
# Deforming bones only; reference bones (Muzzle, ShellEject, ...) follow their parent.
KEEP = {"Weapon", "Pump", "Bolt", "Trigger", "ShellCarrier", "ShellSpent", "ShellLive"}

def quat_to_mat(q):
    x, y, z, w = q
    return np.array([
        [1-2*(y*y+z*z), 2*(x*y-z*w), 2*(x*z+y*w)],
        [2*(x*y+z*w), 1-2*(x*x+z*z), 2*(y*z-x*w)],
        [2*(x*z-y*w), 2*(y*z+x*w), 1-2*(x*x+y*y)],
    ])

def mat_to_quat(m):
    t = np.trace(m)
    if t > 0:
        s = np.sqrt(t + 1.0) * 2
        w = 0.25 * s; x = (m[2,1]-m[1,2])/s; y = (m[0,2]-m[2,0])/s; z = (m[1,0]-m[0,1])/s
    elif m[0,0] > m[1,1] and m[0,0] > m[2,2]:
        s = np.sqrt(1.0 + m[0,0] - m[1,1] - m[2,2]) * 2
        w = (m[2,1]-m[1,2])/s; x = 0.25*s; y = (m[0,1]+m[1,0])/s; z = (m[0,2]+m[2,0])/s
    elif m[1,1] > m[2,2]:
        s = np.sqrt(1.0 + m[1,1] - m[0,0] - m[2,2]) * 2
        w = (m[0,2]-m[2,0])/s; x = (m[0,1]+m[1,0])/s; y = 0.25*s; z = (m[1,2]+m[2,1])/s
    else:
        s = np.sqrt(1.0 + m[2,2] - m[0,0] - m[1,1]) * 2
        w = (m[1,0]-m[0,1])/s; x = (m[0,2]+m[2,0])/s; y = (m[1,2]+m[2,1])/s; z = 0.25*s
    q = np.array([x, y, z, w])
    if q[3] < 0:
        q = -q
    return q / np.linalg.norm(q)

def slerp(a, b, t):
    a = np.array(a); b = np.array(b)
    d = np.dot(a, b)
    if d < 0:
        b = -b; d = -d
    if d > 0.9995:
        r = a + t * (b - a)
        return r / np.linalg.norm(r)
    th = np.arccos(d)
    return (np.sin((1-t)*th)*a + np.sin(t*th)*b) / np.sin(th)

def trs(t, r, s):
    m = np.eye(4)
    m[:3, :3] = quat_to_mat(r) @ np.diag(s)
    m[:3, 3] = t
    return m

def read_accessor(g, idx):
    acc = g.accessors[idx]
    view = g.bufferViews[acc.bufferView]
    data = g.binary_blob()
    ncomp = {"SCALAR": 1, "VEC3": 3, "VEC4": 4}[acc.type]
    start = (view.byteOffset or 0) + (acc.byteOffset or 0)
    arr = np.frombuffer(data, dtype=np.float32, count=acc.count * ncomp, offset=start)
    return arr.reshape(acc.count, ncomp) if ncomp > 1 else arr

def sample(times, values, t, is_rot):
    if t <= times[0]:
        return values[0]
    if t >= times[-1]:
        return values[-1]
    i = int(np.searchsorted(times, t)) - 1
    a = (t - times[i]) / (times[i+1] - times[i])
    if is_rot:
        return slerp(values[i], values[i+1], a)
    return values[i] + (values[i+1] - values[i]) * a

def bake(path, events_json, fps_for):
    g = GLTF2().load(path)
    names = {i: n.name for i, n in enumerate(g.nodes)}
    parent = {}
    for i, n in enumerate(g.nodes):
        for c in n.children or []:
            parent[c] = i
    rest = {i: (list(n.translation or [0,0,0]), list(n.rotation or [0,0,0,1]), list(n.scale or [1,1,1])) for i, n in enumerate(g.nodes)}
    root = next(i for i, n in enumerate(g.nodes) if n.name == "ViewmodelRoot")
    bones = set(g.skins[0].joints)

    def global_mat(local_of, i):
        m = trs(*local_of(i))
        p = parent.get(i)
        while p is not None and p in bones:
            m = trs(*local_of(p)) @ m
            p = parent.get(p)
        return m  # relative to the rig object (above ViewmodelRoot)

    rest_g = {b: global_mat(lambda i: rest[i], b) for b in bones}
    root_rest = rest_g[root]
    out = {}
    for anim in g.animations:
        chans = {}
        dur = 0
        for c in anim.channels:
            s = anim.samplers[c.sampler]
            times = read_accessor(g, s.input)
            vals = read_accessor(g, s.output)
            chans[(c.target.node, c.target.path)] = (times, vals)
            dur = max(dur, float(times[-1]))
        fps = fps_for(anim.name)
        nframes = int(round(dur * fps)) + 1
        tracks = {}
        for b in bones:
            if b == root or names[b] not in KEEP:
                continue
            frames = []
            for f in range(nframes):
                t = f / fps
                def local_of(i):
                    tr, ro, sc = rest[i]
                    if (i, "translation") in chans: tr = sample(*chans[(i, "translation")], t, False)
                    if (i, "rotation") in chans: ro = sample(*chans[(i, "rotation")], t, True)
                    if (i, "scale") in chans: sc = sample(*chans[(i, "scale")], t, False)
                    return tr, ro, sc
                ga = global_mat(local_of, b)
                # Delta in the rig object's space: glTF Y-up = Roblox axes (muzzle -Z, up +Y).
                # The root bone sits at the origin, so this is the imported model's space.
                d = ga @ np.linalg.inv(rest_g[b])
                q = mat_to_quat(d[:3, :3])
                p = d[:3, 3] / STUD_M
                frames.append([round(float(v), 5) for v in list(p) + list(q)])
            moving = any(max(abs(fr[i] - [0,0,0,0,0,0,1][i]) for i in range(7)) > 1e-4 for fr in frames)
            if moving:
                tracks[names[b]] = frames
        name = anim.name if anim.name != "Animation" else "PumpShotgun_TP_Pump"
        ev = events_json["actions"].get(name, events_json["actions"].get("PumpShotgun_Pump") if name.endswith("TP_Pump") else {})
        out[name] = {"fps": fps, "duration": dur, "loop": bool(ev.get("loop", False)),
                     "events": {k: v["time_s"] for k, v in ev.get("events", {}).items()}, "tracks": tracks}
    return out

def lua(v, ind=""):
    if isinstance(v, dict):
        items = []
        for k, x in sorted(v.items()):
            key = k if k.isidentifier() else f'["{k}"]'
            items.append(f"{ind}\t{key} = {lua(x, ind + chr(9))},")
        return "{\n" + "\n".join(items) + f"\n{ind}}}"
    if isinstance(v, list):
        if v and isinstance(v[0], list):
            return "{\n" + "\n".join(f"{ind}\t{{ {', '.join(repr(n) for n in fr)} }}," for fr in v) + f"\n{ind}}}"
        return "{ " + ", ".join(repr(n) for n in v) + " }"
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, float):
        return repr(round(v, 5))
    return repr(v)

if __name__ == "__main__":
    src, dst = sys.argv[1], sys.argv[2]
    events = json.load(open(f"{src}/exports/animations/animation_events.json"))
    fps = lambda n: 30 if n.endswith("Idle") else 60
    fp = bake(f"{src}/exports/first_person/PumpShotgun_FP.glb", events, fps)
    tp = bake(f"{src}/exports/third_person/PumpShotgun_TP.glb", events, fps)
    att = json.load(open(f"{src}/exports/attachments.json"))
    data = {"FirstPerson": fp, "ThirdPerson": tp}
    with open(dst, "w") as fh:
        fh.write("--!strict\n-- GENERATED by tools/extract_anims.py from the Blender exports in\n")
        fh.write("-- DoublePump/Weapons/PumpShotgun/exports. Do not edit by hand; re-run the script.\n")
        fh.write("-- Frame = { px, py, pz, qx, qy, qz, qw }: model-space delta of a bone (studs, Roblox axes).\n\n")
        fh.write("return " + lua(data) + "\n")
    for k, a in fp.items():
        print(k, a["duration"], a["fps"], list(a["tracks"].keys()))
    for k, a in tp.items():
        print("TP", k, a["duration"], list(a["tracks"].keys()))
