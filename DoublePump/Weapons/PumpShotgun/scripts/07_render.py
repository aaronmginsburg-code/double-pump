"""Phase 8: presentation renders into renders/.

01-06  standard views of the master (materials)
07     first-person view through FP_DemoCamera (Roblox 70 deg vertical FOV) + crosshair
08     pump-cycle poses (right side close-up strip + first-person mid-stroke)
09     third-person comparison: master vs low-poly, and the world model next to an
       R15-proportioned mannequin (5.2 studs tall at 0.28 m/stud)
10     wireframe/clay topology views

Run: python 07_render.py   (env SAMPLES, default 128)
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import bpy  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

import sg_lib as L  # noqa: E402

SAMPLES = int(os.environ.get("SAMPLES", "128"))
BLEND = L.p("blender", "PumpShotgun_Master.blend")
OUT = L.p("renders")
bpy.ops.wm.open_mainfile(filepath=BLEND)
scn = bpy.context.scene
O = bpy.data.objects
fp_rig, tp_rig = O["Rig_PumpShotgun"], O["TP_Rig"]
COLS = {c.name: c for c in bpy.data.collections}


def show(*names):
    for n, c in COLS.items():
        if n.startswith("_Studio"):
            continue
        c.hide_render = n not in names
    # sub-collections of the master follow their parent
    for n in ("Master_Static", "Master_Moving", "Master_Shells", "Rig"):
        COLS[n].hide_render = "PumpShotgun_Master" not in names


def pose(rig, action, frame):
    rig.animation_data.action = bpy.data.actions[action] if action else None
    if action and bpy.data.actions[action].slots:
        rig.animation_data.action_slot = bpy.data.actions[action].slots[0]
    if not action:
        for pb in rig.pose.bones:
            pb.location = (0, 0, 0)
            pb.rotation_euler = (0, 0, 0)
    scn.frame_set(frame)


def drive_master_from_rig():
    """Master objects deform with Rig_PumpShotgun already (armature modifiers)."""


L.studio(scn, samples=SAMPLES, res=(1920, 1080))
ONLY = set(filter(None, os.environ.get("RENDER_ONLY", "").split(",")))


def want(group):
    return not ONLY or group in ONLY
pose(fp_rig, None, 0)
pose(tp_rig, None, 0)

# ------------------------------------------------------------------ 01-06 standard views
show("PumpShotgun_Master")
std = [("01_left_side", "left_side"), ("02_right_side", "right_side"), ("03_front_three_quarter", "front_three_quarter"),
       ("04_rear_three_quarter", "rear_three_quarter"), ("05_top", "top"), ("06_receiver_closeup", "receiver_closeup"),
       ("06b_receiver_closeup_left", "receiver_closeup_left"), ("06c_muzzle_closeup", "muzzle_closeup"),
       ("06d_underside_loading_port", "underside"), ("06e_pump_closeup", "pump_closeup"),
       ("06f_stock_closeup", "stock_closeup")]
for fname, v in std if want("std") else []:
    loc, tgt, ortho, lens = L.STANDARD_VIEWS[v]
    L.render(scn, L.camera("Cam_" + v, loc, tgt, lens, ortho), os.path.join(OUT, fname + ".png"))

# ------------------------------------------------------------------ 07 first person
arena = L.get_collection("_Arena")
floor_z = O["FP_DemoCamera"].matrix_world.translation.z - 1.55


def arena_box(name, size, loc, color):
    o = L.box(name, size, loc, arena)
    m = bpy.data.materials.new("M_" + name)
    m.use_nodes = True
    m.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = color
    m.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.85
    o.data.materials.append(m)
    return o


arena_box("ArenaFloor", (14, 30, 0.1), (0, 8, floor_z - 0.05), (0.16, 0.17, 0.18, 1))
arena_box("CoverA", (1.6, 1.0, 1.1), (1.6, 5.5, floor_z + 0.55), (0.30, 0.22, 0.14, 1))
arena_box("CoverB", (2.5, 0.6, 2.2), (-2.6, 9.0, floor_z + 1.1), (0.22, 0.24, 0.27, 1))
arena_box("WallBack", (14, 0.4, 4.0), (0, 18, floor_z + 2.0), (0.26, 0.27, 0.29, 1))
arena_box("WallL", (0.4, 30, 4.0), (-6.5, 8, floor_z + 2.0), (0.24, 0.25, 0.27, 1))
arena_box("WallR", (0.4, 30, 4.0), (6.5, 8, floor_z + 2.0), (0.24, 0.25, 0.27, 1))
show("FP_Viewmodel", "_Arena")
cam = O["FP_DemoCamera"]
fp_shots = [("07_first_person", "PumpShotgun_Idle", 0), ("07b_first_person_fire_recoil", "PumpShotgun_Fire", 5),
            ("07c_first_person_reload", "PumpShotgun_ReloadInsert", 16),
            ("08f_first_person_pump_back", "PumpShotgun_Pump", 11)]


def crosshair(path):
    from PIL import Image, ImageDraw
    im = Image.open(path).convert("RGB")
    d = ImageDraw.Draw(im)
    cx, cy = im.width // 2, im.height // 2
    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        d.line((cx + dx * 8, cy + dy * 8, cx + dx * 22, cy + dy * 22), fill=(255, 255, 255), width=3)
    d.ellipse((cx - 2, cy - 2, cx + 2, cy + 2), fill=(255, 255, 255))
    im.save(path)


for fname, act, f in fp_shots if want("fp") else []:
    pose(fp_rig, act, f)
    p = L.render(scn, cam, os.path.join(OUT, fname + ".png"))
    crosshair(p)
pose(fp_rig, None, 0)
for o in list(arena.objects):
    bpy.data.objects.remove(o, do_unlink=True)

# ------------------------------------------------------------------ 08 pump cycle strip
show("PumpShotgun_Master")
scn.render.resolution_x, scn.render.resolution_y = 1200, 600
cam_p = L.camera("Cam_pump", (0.42, 0.12, 0.03), (0.0, 0.14, -0.01), 50)
frames = [0, 6, 9, 11, 18, 26] if want("pump") else []
paths = []
for f in frames:
    pose(fp_rig, "PumpShotgun_Pump", f)
    paths.append(L.render(scn, cam_p, os.path.join(OUT, "pump_cycle", f"pump_f{f:02d}.png")))
if paths:
    L.contact_sheet(paths, os.path.join(OUT, "08_pump_action_poses.png"), cols=3, width=2400)
reload_paths = []
for f in (0, 8, 14, 18, 22, 26) if want("pump") else []:
    pose(fp_rig, "PumpShotgun_ReloadInsert", f)
    cam_r = L.camera("Cam_reload", (0.10, 0.02, -0.40), (0.0, 0.05, -0.02), 50)
    reload_paths.append(L.render(scn, cam_r, os.path.join(OUT, "reload_cycle", f"reload_f{f:02d}.png")))
if reload_paths:
    L.contact_sheet(reload_paths, os.path.join(OUT, "08b_reload_insert_poses.png"), cols=3, width=2400)
pose(fp_rig, None, 0)

# ------------------------------------------------------------------ 09 third-person comparison
scn.render.resolution_x, scn.render.resolution_y = 1920, 1080
# master vs low-poly, same camera, objects offset vertically
tp_rig.location = (0, 0, -0.20)
show("PumpShotgun_Master", "TP_WorldModel")
L.render(scn, L.camera("Cam_cmp", (1.55, 0.10, -0.10), (0, 0.10, -0.10), 50, ortho=1.2),
         os.path.join(OUT, "09_fp_vs_tp_side.png"))
L.render(scn, L.camera("Cam_cmp2", (0.75, 0.75, 0.12), (0, 0.06, -0.10), 50),
         os.path.join(OUT, "09b_fp_vs_tp_three_quarter.png"))
tp_rig.location = (0, 0, 0)

# mannequin with R15-like proportions (studs -> metres)
S = 0.28
man = L.get_collection("_Mannequin")
mm = bpy.data.materials.new("M_Mannequin")
mm.use_nodes = True
mm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.16, 0.17, 0.19, 1)
parts = {  # name: (size studs, centre studs) with feet at z=0, character facing +Y
    "LeftLeg": ((1, 1, 2), (-0.5, 0, 1)), "RightLeg": ((1, 1, 2), (0.5, 0, 1)),
    "Torso": ((2, 1, 2), (0, 0, 3)), "Head": ((1.2, 1.2, 1.2), (0, 0, 4.6)),
    "LeftArm": ((1, 1, 2), (-1.5, 0, 3)),
}
for n, (sz, c) in parts.items():
    o = L.box("Man_" + n, tuple(v * S for v in sz), tuple(v * S for v in c), man)
    o.data.materials.append(mm)
# right arm raised forward holding the gun at hip/shoulder height
ra = L.box("Man_RightArm", (1 * S, 2 * S, 1 * S), (1.5 * S, 0.9 * S, 3.6 * S), man)
ra.data.materials.append(mm)
grip_b = tp_rig.data.bones["Grip"].head_local
hand = Vector((1.5 * S, 1.9 * S, 3.6 * S))
tp_rig.matrix_world = Matrix.Translation(hand - grip_b)
show("TP_WorldModel", "_Mannequin")
L.render(scn, L.camera("Cam_man", (3.3, 3.5, 1.35), (0.15, 0.25, 0.70), 40),
         os.path.join(OUT, "09c_tp_with_r15_mannequin.png"))
L.render(scn, L.camera("Cam_man_side", (3.5, 0.35, 0.78), (0.0, 0.35, 0.78), 50, ortho=1.9),
         os.path.join(OUT, "09d_tp_with_r15_mannequin_side.png"))
for o in list(man.objects):
    bpy.data.objects.remove(o, do_unlink=True)
tp_rig.matrix_world = Matrix.Identity(4)

# ------------------------------------------------------------------ 10 topology (clay + wire)
wire = bpy.data.materials.new("M_ClayWire")
wire.use_nodes = True
nt = wire.node_tree
b = nt.nodes["Principled BSDF"]
b.inputs["Base Color"].default_value = (0.32, 0.32, 0.33, 1)
b.inputs["Roughness"].default_value = 0.6
wf = nt.nodes.new("ShaderNodeWireframe")
wf.use_pixel_size = True
wf.inputs[0].default_value = 0.6
mix = nt.nodes.new("ShaderNodeMixShader")
em = nt.nodes.new("ShaderNodeEmission")
em.inputs[0].default_value = (0.02, 0.02, 0.02, 1)
out = nt.nodes["Material Output"]
nt.links.new(wf.outputs[0], mix.inputs[0])
nt.links.new(b.outputs[0], mix.inputs[1])
nt.links.new(em.outputs[0], mix.inputs[2])
nt.links.new(mix.outputs[0], out.inputs[0])
bpy.context.view_layer.material_override = wire
show("PumpShotgun_Master")
loc, tgt, ortho, lens = L.STANDARD_VIEWS["receiver_closeup"]
L.render(scn, L.camera("Cam_w1", loc, tgt, lens, ortho), os.path.join(OUT, "10_topology_master_receiver.png"))
tp_rig.location = (0, 0, 0)
show("TP_WorldModel")
L.render(scn, L.camera("Cam_w2", loc, tgt, lens, ortho), os.path.join(OUT, "10b_topology_tp_receiver.png"))
bpy.context.view_layer.material_override = None

# ------------------------------------------------------------------ overview sheet
main = ["01_left_side", "02_right_side", "03_front_three_quarter", "04_rear_three_quarter", "05_top",
        "06_receiver_closeup", "07_first_person", "08_pump_action_poses", "09_fp_vs_tp_side",
        "09c_tp_with_r15_mannequin"]
L.contact_sheet([os.path.join(OUT, n + ".png") for n in main], os.path.join(OUT, "00_overview.png"), cols=2,
                width=2400)
print("renders done")
