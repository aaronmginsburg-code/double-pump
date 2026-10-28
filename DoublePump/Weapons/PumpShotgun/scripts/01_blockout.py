"""Phase 2 blockout: proportion-only primitives from sg_dims, rendered from
several angles for comparison against the reference targets.

Run: python 01_blockout.py   (uses the bpy module)
"""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import bpy  # noqa: E402

import sg_dims as D  # noqa: E402
import sg_lib as L  # noqa: E402

scn = L.reset_scene()
col = L.get_collection("Blockout")
clay = bpy.data.materials.new("M_Clay")
clay.use_nodes = True
clay.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.55, 0.55, 0.55, 1)
clay.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.6

objs = []
rl = D.RECV_FRONT - D.RECV_REAR
objs.append(L.box("BO_Receiver", (2 * D.RECV_HW, rl, D.RECV_TOP - D.RECV_BOT),
                  (0, (D.RECV_FRONT + D.RECV_REAR) / 2, (D.RECV_TOP + D.RECV_BOT) / 2), col))
bl = D.MUZZLE_Y - D.RECV_FRONT
objs.append(L.cylinder("BO_Barrel", D.BARREL_R, bl, (0, D.RECV_FRONT + bl / 2, D.BORE_Z), col=col))
tl = D.TUBE_END_Y + D.CAP_LEN - D.RECV_FRONT
objs.append(L.cylinder("BO_Tube", D.TUBE_R, tl, (0, D.RECV_FRONT + tl / 2, D.TUBE_Z), col=col))
pl = D.PUMP_FRONT - D.PUMP_REAR
objs.append(L.cylinder("BO_Pump", D.PUMP_HW, pl, (0, (D.PUMP_FRONT + D.PUMP_REAR) / 2, D.PUMP_CZ), col=col))
# stock as a side-profile slab
stock = [(D.RECV_REAR, 0.033), (-0.16, 0.026), (-0.30, 0.019), (D.STOCK_BUTT, 0.016),
         (D.STOCK_BUTT, -0.120), (-0.32, -0.098), (-0.22, -0.068), (-0.15, -0.046),
         (D.RECV_REAR, D.RECV_BOT)]
objs.append(L.extrude_profile("BO_Stock", stock, -0.019, 0.019, col))
objs.append(L.box("BO_Pad", (0.042, D.PAD_LEN, 0.134), (0, D.STOCK_BUTT - D.PAD_LEN / 2, -0.056), col))
guard = [(D.GUARD_Y0, D.RECV_BOT), (D.GUARD_Y1, D.RECV_BOT), (D.GUARD_Y1 - 0.01, -0.072),
         (D.GUARD_Y0 + 0.01, -0.072)]
objs.append(L.extrude_profile("BO_Guard", guard, -0.006, 0.006, col))
for o in objs:
    o.data.materials.append(clay)

L.studio(scn, samples=48, res=(1400, 700))
outdir = L.p("renders", "blockout")
paths = []
for view in ("left_side", "right_side", "top", "front_three_quarter", "front"):
    loc, tgt, ortho, lens = L.STANDARD_VIEWS[view]
    cam = L.camera("Cam_" + view, loc, tgt, lens, ortho)
    paths.append(L.render(scn, cam, os.path.join(outdir, f"blockout_{view}.png")))
# first-person preview: Roblox default FieldOfView is 70 deg vertical
import math  # noqa: E402
fp = L.camera("Cam_FP", (-0.105, -0.30, 0.125), (-0.03, 2.0, 0.07), 50)
fp.data.sensor_fit = "VERTICAL"
fp.data.angle_y = math.radians(70)
scn.render.resolution_x, scn.render.resolution_y = 1600, 900
paths.append(L.render(scn, fp, os.path.join(outdir, "blockout_first_person.png")))
L.contact_sheet(paths, os.path.join(outdir, "blockout_sheet.png"))

# report measured extents
import mathutils  # noqa: E402
mn = mathutils.Vector((9, 9, 9)); mx = -mn
for o in objs:
    for c in o.bound_box:
        w = o.matrix_world @ mathutils.Vector(c)
        mn = mathutils.Vector(map(min, mn, w)); mx = mathutils.Vector(map(max, mx, w))
print("BLOCKOUT extents (m):", tuple(round(v, 4) for v in (mx - mn)))
bpy.ops.wm.save_as_mainfile(filepath=L.p("blender", "PumpShotgun_Blockout.blend"))
