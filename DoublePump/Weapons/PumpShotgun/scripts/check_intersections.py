"""Mechanical clearance check: evaluates moving parts against static parts at
sampled frames of every action and reports triangle intersections that are
not already present in the rest pose.

python check_intersections.py [blend]  -> prints a report, exit code 1 on new intersections
"""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import bpy  # noqa: E402
from mathutils.bvhtree import BVHTree  # noqa: E402

import sg_lib as L  # noqa: E402

blend = sys.argv[1] if len(sys.argv) > 1 else L.p("blender", "PumpShotgun_Master.blend")
bpy.ops.wm.open_mainfile(filepath=blend)
scn = bpy.context.scene
arm = bpy.data.objects["Rig_PumpShotgun"]
master = [o for o in bpy.data.collections["PumpShotgun_Master"].all_objects if o.type == "MESH"]
moving = [o for o in master if o.get("bone") not in ("Weapon",) and not o.name.startswith("Shell_")]
static = [o for o in master if o.get("bone") == "Weapon"]


def trees():
    deps = bpy.context.evaluated_depsgraph_get()
    out = {}
    for o in moving + static:
        ev = o.evaluated_get(deps)
        me = ev.to_mesh()
        verts = [ev.matrix_world @ v.co for v in me.vertices]
        polys = [tuple(p.vertices) for p in me.polygons]
        out[o.name] = BVHTree.FromPolygons(verts, polys, epsilon=0.0)
        ev.to_mesh_clear()
    return out


def pairs(t):
    res = {}
    for m in moving:
        for s in static:
            n = len(t[m.name].overlap(t[s.name]))
            if n:
                res[(m.name, s.name)] = n
    return res


arm.animation_data.action = None
for pb in arm.pose.bones:
    pb.location = (0, 0, 0)
    pb.rotation_euler = (0, 0, 0)
scn.frame_set(0)
base = pairs(trees())
print("rest-pose contacts (ignored as baseline):", base)
bad = 0
for act in [a for a in bpy.data.actions if a.name.startswith("PumpShotgun_")]:
    arm.animation_data.action = act
    f0, f1 = (int(x) for x in act.frame_range)
    for f in range(f0, f1 + 1, 1 if f1 - f0 <= 40 else 10):
        scn.frame_set(f)
        new = {k: v for k, v in pairs(trees()).items() if k not in base}
        if new:
            bad += 1
            print(f"  {act.name} frame {f}: NEW intersections {new}")
print("RESULT:", "PASS" if not bad else f"FAIL ({bad} frames)")
sys.exit(1 if bad else 0)
