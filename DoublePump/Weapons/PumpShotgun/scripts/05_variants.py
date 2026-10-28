"""Phase 6: derive the production variants from the master, inside the same .blend.

FP_Viewmodel   : FP_PumpShotgun (all master parts joined, rigid-skinned to Rig_PumpShotgun)
                 + FP_Shell_Live / FP_Shell_Spent (separate so gameplay can hide them)
TP_WorldModel  : TP_Rig (Weapon, Pump + attachment bones) and TP_PumpShotgun, a decimated
                 copy of the master with tiny parts removed, plus a 1024 texture set whose
                 normal map is re-baked from the master onto the low-poly mesh.
_Demo          : FP_DemoCamera (Roblox default 70 deg vertical FOV) - never exported.

Run: python 05_variants.py
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import bpy  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

import sg_lib as L  # noqa: E402

BLEND = L.p("blender", "PumpShotgun_Master.blend")
bpy.ops.wm.open_mainfile(filepath=BLEND)
scn = bpy.context.scene
arm = bpy.data.objects["Rig_PumpShotgun"]
arm.animation_data.action = None
for pb in arm.pose.bones:
    pb.location = (0, 0, 0)
    pb.rotation_euler = (0, 0, 0)

for cname in ("FP_Viewmodel", "TP_WorldModel", "_Demo"):
    c = bpy.data.collections.get(cname)
    if c:
        for o in list(c.all_objects):
            bpy.data.objects.remove(o, do_unlink=True)
        bpy.data.collections.remove(c)
bpy.data.orphans_purge(do_recursive=True)
fp_col = L.get_collection("FP_Viewmodel")
tp_col = L.get_collection("TP_WorldModel")
demo_col = L.get_collection("_Demo")

master = [o for o in bpy.data.collections["PumpShotgun_Master"].all_objects if o.type == "MESH"]
gun_parts = [o for o in master if not o.name.startswith("Shell_")]


def dup(o, name, col):
    c = o.copy()
    c.data = o.data.copy()
    c.name = name
    c.data.name = name
    col.objects.link(c)
    return c


def triangulate(o):
    """Game meshes ship triangulated (exporters need tris/quads for tangents)."""
    t = o.modifiers.new("Triangulate", "TRIANGULATE")
    t.quad_method = "BEAUTY"
    t.ngon_method = "BEAUTY"
    t.keep_custom_normals = True
    L.apply_mod(o, t.name)


def join(objs, name):
    for o in bpy.context.view_layer.objects:
        o.select_set(False)
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    j = bpy.context.view_layer.objects.active
    j.name = name
    j.data.name = name
    return j


# ------------------------------------------------------------------ first-person
fp = join([dup(o, "FP_" + o.name, fp_col) for o in gun_parts], "FP_PumpShotgun")
for m in list(fp.modifiers):
    if m.type != "ARMATURE":
        fp.modifiers.remove(m)
fp.modifiers[0].object = arm
fp.parent = arm
for s in ("Shell_Live", "Shell_Spent"):
    c = dup(bpy.data.objects[s], "FP_" + s, fp_col)
    c.parent = arm
    triangulate(c)
mods = list(fp.modifiers)
for m in mods:  # triangulate must run before the armature modifier is evaluated
    fp.modifiers.remove(m)
triangulate(fp)
am = fp.modifiers.new("Armature", "ARMATURE")
am.object = arm

# ------------------------------------------------------------------ third-person rig
tp_arm = arm.copy()
tp_arm.data = arm.data.copy()
tp_arm.name = tp_arm.data.name = "TP_Rig"
tp_arm.animation_data_clear()
tp_col.objects.link(tp_arm)
for o in bpy.context.view_layer.objects:
    o.select_set(False)
bpy.context.view_layer.objects.active = tp_arm
tp_arm.select_set(True)
bpy.ops.object.mode_set(mode="EDIT")
for b in ("Bolt", "Trigger", "ShellCarrier", "ShellSpent", "ShellLive", "ShellLoad"):
    tp_arm.data.edit_bones.remove(tp_arm.data.edit_bones[b])
bpy.ops.object.mode_set(mode="OBJECT")

# per-part decimation ratios (None = drop part from the world model)
RATIO = {"Receiver": 0.30, "SightRib": 0.4, "RearSight": 0.35, "ReceiverPins": None, "TriggerPlate": 0.35,
         "TriggerGuard": 0.22, "Trigger": 0.35, "Barrel": 0.40, "FrontSight": 0.35, "MagTube": 0.6,
         "MagCap": 0.12, "BarrelBand": 0.35, "Stock": 0.38, "ButtPad": 0.30, "PadScrews": None,
         "SlingStud": None, "Pump": 0.16, "PumpFerrule": 0.25, "ActionBars": 0.5, "Bolt": 0.25,
         "ShellCarrier": None}
TP_BONE = {"Pump": "Pump", "PumpFerrule": "Pump", "ActionBars": "Pump"}

low_pairs = []
for o in gun_parts:
    r = RATIO.get(o.name, 0.35)
    if r is None:
        continue
    lo = dup(o, "TP_" + o.name, tp_col)
    for m in list(lo.modifiers):
        lo.modifiers.remove(m)
    d = lo.modifiers.new("Decimate", "DECIMATE")
    d.decimate_type = "COLLAPSE"
    d.ratio = r
    d.use_collapse_triangulate = True
    L.apply_mod(lo, d.name)
    for vg in list(lo.vertex_groups):
        lo.vertex_groups.remove(vg)
    vg = lo.vertex_groups.new(name=TP_BONE.get(o.name, "Weapon"))
    vg.add(range(len(lo.data.vertices)), 1.0, "REPLACE")
    lo.parent = None
    lo.matrix_world = Matrix.Identity(4)
    low_pairs.append((o, lo))

# --- TP texture set: colour/rough/metal are the FP atlas at 1024 (UVs survive decimation);
#     the normal map is baked high->low so the decimated silhouette keeps the master's shading.
tex_tp = L.p("textures", "third_person")
os.makedirs(tex_tp, exist_ok=True)
fm = bpy.data.materials["M_PumpShotgun"]
tm = fm.copy()
tm.name = "M_PumpShotgun_TP"
tp_imgs = {}
for n in tm.node_tree.nodes:
    if n.type == "TEX_IMAGE":
        key = n.label
        src = n.image
        if key == "Normal":
            im = bpy.data.images.new("T_PumpShotgun_TP_Normal", 1024, 1024, alpha=True, float_buffer=True)
            im.generated_color = (0, 0, 0, 0)
            im.colorspace_settings.name = "Non-Color"
        else:
            im = src.copy()
            im.name = f"T_PumpShotgun_TP_{key}"
            im.scale(1024, 1024)
            im.filepath_raw = os.path.join(tex_tp, im.name + ".png")
            im.file_format = "PNG"
            im.save()
        n.image = im
        tp_imgs[key] = (n, im)
for _, lo in low_pairs:
    lo.data.materials.clear()
    lo.data.materials.append(tm)

scn.render.engine = "CYCLES"
scn.cycles.device = "CPU"
scn.cycles.samples = 8
bake = scn.render.bake
bake.use_selected_to_active = True
bake.cage_extrusion = 0.0025
bake.max_ray_distance = 0.006
bake.margin = 0
nnode, nimg = tp_imgs["Normal"]
tm.node_tree.nodes.active = nnode
for i, (hi, lo) in enumerate(low_pairs):
    bake.use_clear = i == 0
    for o in bpy.context.view_layer.objects:
        o.select_set(False)
    hi.select_set(True)
    lo.select_set(True)
    bpy.context.view_layer.objects.active = lo
    bpy.ops.object.bake(type="NORMAL", normal_space="TANGENT")
bake.use_selected_to_active = False

import sg_imgutil as U  # noqa: E402
U.dilate(nimg)
nimg.filepath_raw = os.path.join(tex_tp, nimg.name + ".png")
nimg.file_format = "PNG"
scn.render.image_settings.color_depth = "16"
nimg.save()
# point the TP material at the files on disk (relative)
for key, (n, im) in tp_imgs.items():
    path = os.path.join(tex_tp, f"T_PumpShotgun_TP_{key}.png")
    bpy.data.images.remove(im)
    im2 = bpy.data.images.load(path)
    im2.colorspace_settings.name = "sRGB" if key == "BaseColor" else "Non-Color"
    im2.filepath = bpy.path.relpath(path, start=L.p("blender"))
    n.image = im2

tp = join([lo for _, lo in low_pairs], "TP_PumpShotgun")
triangulate(tp)
tp.parent = tp_arm
am = tp.modifiers.new("Armature", "ARMATURE")
am.object = tp_arm
for poly in tp.data.polygons:
    poly.use_smooth = True

# TP pump action: only the forend/bolt channels of the FP pump action (bolt is not in the TP rig)
src = bpy.data.actions["PumpShotgun_Pump"]
old = bpy.data.actions.get("PumpShotgun_TP_Pump")
if old:
    bpy.data.actions.remove(old)
tpa = src.copy()
tpa.name = "PumpShotgun_TP_Pump"
tpa.use_fake_user = True
for layer in tpa.layers:
    for strip in layer.strips:
        for slot in tpa.slots:
            cb = strip.channelbag(slot)
            if not cb:
                continue
            for fc in list(cb.fcurves):
                if 'pose.bones["Pump"]' not in fc.data_path:
                    cb.fcurves.remove(fc)
tp_arm.animation_data_create()
tp_arm.animation_data.action = tpa
if tpa.slots:
    tp_arm.animation_data.action_slot = tpa.slots[0]

# ------------------------------------------------------------------ demo first-person camera
cd = bpy.data.cameras.new("FP_DemoCamera")
cd.sensor_fit = "VERTICAL"
cd.angle_y = math.radians(70)  # Roblox Camera.FieldOfView default (vertical)
cd.clip_start = 0.01
cam = bpy.data.objects.new("FP_DemoCamera", cd)
demo_col.objects.link(cam)
# Camera pose in gun space (tuned from renders, see README "Viewmodel framing").
CAM_LOC = (-0.18, -0.34, 0.11)
CAM_YAW_DEG, CAM_PITCH_DEG = 8.0, 5.0   # yaw: + turns left; pitch: + looks up
rot = (Matrix.Rotation(math.radians(CAM_YAW_DEG), 4, "Z") @ Matrix.Rotation(math.radians(CAM_PITCH_DEG), 4, "X")
       @ Matrix.Rotation(math.radians(90), 4, "X"))
cam.matrix_world = Matrix.Translation(CAM_LOC) @ rot
cam["note"] = "Demo only. Gun pose relative to camera = camera.matrix_world.inverted()."

arm.animation_data.action = bpy.data.actions["PumpShotgun_Idle"]
fp_tris = L.tri_count(fp) + sum(L.tri_count(bpy.data.objects[n]) for n in ("FP_Shell_Live", "FP_Shell_Spent"))
print("FP tris (gun + 2 shells):", L.tri_count(fp), fp_tris)
print("TP tris:", L.tri_count(tp))
bpy.ops.wm.save_as_mainfile(filepath=BLEND, relative_remap=True)
