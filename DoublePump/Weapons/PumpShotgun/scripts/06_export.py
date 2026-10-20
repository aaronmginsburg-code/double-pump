"""Phase 7: export Roblox-ready files from the master .blend.

exports/first_person/PumpShotgun_FP.fbx     rig + skinned gun + 2 shell meshes (no animation)
exports/first_person/PumpShotgun_FP.glb     same + every FP animation (glTF 2.0 binary)
exports/third_person/PumpShotgun_TP.fbx     TP rig + skinned low-poly gun
exports/third_person/PumpShotgun_TP.glb     same + TP pump animation
exports/animations/PumpShotgun_<Action>.fbx one action per file, armature only (Roblox Animation Editor import)
exports/props/Shell_Live.fbx, Shell_Spent.fbx  standalone shells for physics props
exports/attachments.json                     every reference bone in Blender + Roblox space, and the
                                             demo-camera viewmodel offset as a Roblox CFrame

Axis: Blender +Y (muzzle) -> file -Z (Roblox LookVector), Blender +Z -> file +Y. Units: metres.

Run: python 06_export.py
"""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import bpy  # noqa: E402
from mathutils import Matrix  # noqa: E402

import sg_lib as L  # noqa: E402

STUD = 0.28  # metres per stud (Roblox physics/character convention)
BLEND = L.p("blender", "PumpShotgun_Master.blend")
bpy.ops.wm.open_mainfile(filepath=BLEND)
scn = bpy.context.scene
O = bpy.data.objects
fp_rig, tp_rig = O["Rig_PumpShotgun"], O["TP_Rig"]
fp_objs = [fp_rig, O["FP_PumpShotgun"], O["FP_Shell_Live"], O["FP_Shell_Spent"]]
tp_objs = [tp_rig, O["TP_PumpShotgun"]]
ex = L.p("exports")
for d in ("first_person", "third_person", "animations", "props"):
    os.makedirs(os.path.join(ex, d), exist_ok=True)


def rest_pose(rig):
    if rig.animation_data:
        rig.animation_data.action = None
    for pb in rig.pose.bones:
        pb.location = (0, 0, 0)
        pb.rotation_euler = (0, 0, 0)
        pb.rotation_quaternion = (1, 0, 0, 0)


def select(objs):
    for o in bpy.context.view_layer.objects:
        o.select_set(False)
    for o in objs:
        o.hide_set(False)
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]


FBX_COMMON = dict(use_selection=True, apply_unit_scale=True, apply_scale_options="FBX_SCALE_UNITS",
                  axis_forward="-Z", axis_up="Y", add_leaf_bones=False, use_armature_deform_only=False,
                  primary_bone_axis="Y", secondary_bone_axis="X", path_mode="COPY", embed_textures=True,
                  use_custom_props=True, mesh_smooth_type="FACE", use_tspace=True, use_mesh_modifiers=True,
                  bake_anim_use_all_actions=False, bake_anim_use_nla_strips=False,
                  bake_anim_force_startend_keying=True, bake_anim_simplify_factor=0.0, bake_anim_step=1.0)


def fbx(path, objs, types, anim, embed=True):
    select(objs)
    opts = dict(FBX_COMMON)
    if not embed:  # props reuse the gun's texture set; don't duplicate 4 maps per file
        opts.update(path_mode="STRIP", embed_textures=False)
    bpy.ops.export_scene.fbx(filepath=path, object_types=types, bake_anim=anim, **opts)
    print("wrote", os.path.relpath(path, L.ROOT), os.path.getsize(path), "bytes")


def glb(path, objs, anim, mode):
    select(objs)
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_yup=True,
                              export_apply=False, export_skins=True, export_animations=anim,
                              export_animation_mode=mode, export_force_sampling=True,
                              export_def_bones=False, export_cameras=False, export_lights=False,
                              export_extras=True, export_tangents=True, export_image_format="AUTO")
    print("wrote", os.path.relpath(path, L.ROOT), os.path.getsize(path), "bytes")


# ------------------------------------------------------------------ meshes + rigs
rest_pose(fp_rig)
rest_pose(tp_rig)
scn.frame_set(0)
fbx(os.path.join(ex, "first_person", "PumpShotgun_FP.fbx"), fp_objs, {"ARMATURE", "MESH"}, False)
fbx(os.path.join(ex, "third_person", "PumpShotgun_TP.fbx"), tp_objs, {"ARMATURE", "MESH"}, False)

# ------------------------------------------------------------------ animations: one FBX per action
fp_actions = sorted((a for a in bpy.data.actions if a.name.startswith("PumpShotgun_") and "_TP_" not in a.name),
                    key=lambda a: a.name)


def bind(rig, act):
    rig.animation_data_create()
    rig.animation_data.action = act
    if act.slots:
        rig.animation_data.action_slot = act.slots[0]
    f0, f1 = (int(x) for x in act.frame_range)
    scn.frame_start, scn.frame_end = f0, f1


nla_mute = {}
for rig in (fp_rig, tp_rig):
    for t in rig.animation_data.nla_tracks if rig.animation_data else []:
        nla_mute[(rig.name, t.name)] = t.mute
        t.mute = True
for act in fp_actions:
    bind(fp_rig, act)
    fbx(os.path.join(ex, "animations", act.name + ".fbx"), [fp_rig], {"ARMATURE"}, True)
tp_act = bpy.data.actions["PumpShotgun_TP_Pump"]
bind(tp_rig, tp_act)
fbx(os.path.join(ex, "animations", tp_act.name + ".fbx"), [tp_rig], {"ARMATURE"}, True)

# ------------------------------------------------------------------ glTF (with animations)
# FP: one glTF animation per FP NLA track (unmuted just for the export); TP: its single action
scn.frame_start, scn.frame_end = 0, 240
fp_rig.animation_data.action = None
for t in fp_rig.animation_data.nla_tracks:
    t.mute = False
glb(os.path.join(ex, "first_person", "PumpShotgun_FP.glb"), fp_objs, True, "NLA_TRACKS")
for t in fp_rig.animation_data.nla_tracks:
    t.mute = True
bind(tp_rig, tp_act)
glb(os.path.join(ex, "third_person", "PumpShotgun_TP.glb"), tp_objs, True, "ACTIVE_ACTIONS")
rest_pose(fp_rig)
rest_pose(tp_rig)

# ------------------------------------------------------------------ shell props (origin at centre, static)
tmp = L.get_collection("_export_tmp")
for name in ("Shell_Live", "Shell_Spent"):
    src = O[name]
    c = src.copy()
    c.data = src.data.copy()
    c.name = name + "_Prop"
    tmp.objects.link(c)
    c.parent = None
    c.modifiers.clear()
    c.vertex_groups.clear()
    bb = [c.matrix_world @ v.co for v in c.data.vertices]
    cy = (min(v.y for v in bb) + max(v.y for v in bb)) / 2
    c.data.transform(Matrix.Translation((-bb[0].x * 0, -cy, -sum(v.z for v in bb) / len(bb))))
    c.matrix_world = Matrix.Identity(4)
    c.name = name
    fbx(os.path.join(ex, "props", name + ".fbx"), [c], {"MESH"}, False, embed=False)
    c.name = name + "_Prop"
for o in list(tmp.objects):
    bpy.data.objects.remove(o, do_unlink=True)
bpy.data.collections.remove(tmp)

# ------------------------------------------------------------------ attachments.json
C = Matrix(((1, 0, 0, 0), (0, 0, 1, 0), (0, -1, 0, 0), (0, 0, 0, 1)))  # Blender -> Roblox axes
CI = C.inverted()


def cframe(m, unit=1 / STUD):
    """4x4 Blender-space matrix (metres) -> Roblox CFrame components (studs)."""
    r = C @ m @ CI
    p = r.translation * unit
    rot = r.to_3x3()
    return [round(v, 5) for v in (p.x, p.y, p.z, rot[0][0], rot[0][1], rot[0][2], rot[1][0], rot[1][1],
                                   rot[1][2], rot[2][0], rot[2][1], rot[2][2])]


def bones(rig):
    out = {}
    for b in rig.data.bones:
        h = b.head_local
        out[b.name] = {
            "deform": b.use_deform,
            "parent": b.parent.name if b.parent else None,
            "blender_m": [round(v, 5) for v in h],
            "roblox_studs": [round(v / STUD, 4) for v in (h.x, h.z, -h.y)],
            "roblox_cframe_from_root": cframe(b.matrix_local),
        }
    return out


cam = O["FP_DemoCamera"]
offset = cam.matrix_world.inverted() @ CI  # viewmodel root (imported model frame) in camera space
r = offset.to_3x3()
p = offset.translation / STUD
meta = {
    "stud_m": STUD,
    "axis_note": "Blender (x, y, z) -> Roblox (x, z, -y). Muzzle = -Z (LookVector) in the imported model.",
    "first_person": {"rig": fp_rig.name, "bones": bones(fp_rig)},
    "third_person": {"rig": tp_rig.name, "bones": bones(tp_rig)},
    "viewmodel_demo_camera": {
        "fov_vertical_deg": round(cam.data.angle_y * 57.29578, 3),
        "camera_in_gun_space_m": [round(v, 4) for v in cam.matrix_world.translation],
        "viewmodel_offset_cframe": [round(v, 5) for v in (p.x, p.y, p.z, r[0][0], r[0][1], r[0][2], r[1][0],
                                                           r[1][1], r[1][2], r[2][0], r[2][1], r[2][2])],
        "usage": "viewmodel:PivotTo(workspace.CurrentCamera.CFrame * CFrame.new(unpack(viewmodel_offset_cframe)))",
    },
}
with open(os.path.join(ex, "attachments.json"), "w") as f:
    json.dump(meta, f, indent=2)
print("viewmodel offset (studs):", meta["viewmodel_demo_camera"]["viewmodel_offset_cframe"][:3])
for (rn, tn), m in nla_mute.items():
    O[rn].animation_data.nla_tracks[tn].mute = m
bind(fp_rig, bpy.data.actions["PumpShotgun_Idle"])
bpy.ops.wm.save_as_mainfile(filepath=BLEND)
