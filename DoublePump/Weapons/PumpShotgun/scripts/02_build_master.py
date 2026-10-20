"""Phase 3: build the detailed master model + rig and save
blender/PumpShotgun_Master.blend (geometry, source materials, armature,
attachment bones). Later steps (bake, animate, variants, export) open and
extend that file.

Run: python 02_build_master.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import bpy  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

import sg_dims as D  # noqa: E402
import sg_lib as L  # noqa: E402
import sg_materials as M  # noqa: E402
import sg_parts as P  # noqa: E402

scn = L.reset_scene()
M.make_all()

master = L.get_collection("PumpShotgun_Master")
c_static = L.get_collection("Master_Static", master)
c_moving = L.get_collection("Master_Moving", master)
c_shells = L.get_collection("Master_Shells", master)
c_rig = L.get_collection("Rig", master)
tmp = L.get_collection("_tmp")

# ------------------------------------------------------------------ geometry
static = {}
for fn in (P.receiver, P.sight_rib, P.rear_sight, P.receiver_pins, P.trigger_plate, P.trigger_guard,
           P.barrel, P.front_sight, P.mag_tube, P.mag_cap, P.barrel_band, P.stock, P.sling_stud):
    o = fn(tmp)
    static[o.name] = o
pad, screws = P.butt_pad(tmp)
static[pad.name] = pad
static[screws.name] = screws

moving = {"Pump": [P.pump(tmp), P.pump_ferrule(tmp), P.action_bars(tmp)],
          "Bolt": [P.bolt(tmp)],
          "Trigger": [P.trigger(tmp)],
          "ShellCarrier": [P.carrier(tmp)]}

spent = P.shell("Shell_Spent", tmp, spent=True)
spent.data.transform(Matrix.Translation((0, D.BOLT_FRONT, D.BORE_Z)))
live = P.shell("Shell_Live", tmp, spent=False)
SHELL_LIVE_REST = (0, D.RECV_FRONT + 0.03, D.TUBE_Z)
live.data.transform(Matrix.Translation(SHELL_LIVE_REST))

for o in static.values():
    L.link(o, c_static)
for objs in moving.values():
    for o in objs:
        L.link(o, c_moving)
L.link(spent, c_shells)
L.link(live, c_shells)
# any leftover helper objects (cutters are deleted by boolean())
for o in list(tmp.objects):
    bpy.data.objects.remove(o, do_unlink=True)
bpy.data.collections.remove(tmp)

# ------------------------------------------------------------------ rig
arm_data = bpy.data.armatures.new("Rig_PumpShotgun")
arm = bpy.data.objects.new("Rig_PumpShotgun", arm_data)
c_rig.objects.link(arm)
arm.show_in_front = True
L.set_active(arm)
bpy.ops.object.mode_set(mode="EDIT")
eb = arm_data.edit_bones
BL = 0.03  # bone display length; every bone points +Y (muzzle), roll 0


def bone(name, head, parent=None, deform=True, length=BL):
    b = eb.new(name)
    b.head = Vector(head)
    b.tail = Vector(head) + Vector((0, length, 0))
    b.roll = 0.0
    b.use_deform = deform
    if parent:
        b.parent = eb[parent]
    return b


bone("ViewmodelRoot", (0, 0, 0), deform=False, length=0.05)
bone("Weapon", (0, -0.112, -0.022), "ViewmodelRoot")
bone("Pump", (0, (D.PUMP_REAR + D.PUMP_FRONT) / 2, D.TUBE_Z), "Weapon")
bone("Bolt", (0, (D.BOLT_REAR + D.BOLT_FRONT) / 2, (D.BOLT_Z0 + D.BOLT_Z1) / 2), "Weapon")
bone("Trigger", D.TRIGGER_PIVOT, "Weapon", length=0.015)
bone("ShellCarrier", (0, D.LOAD_Y0 + 0.004, D.RECV_BOT + 0.0065), "Weapon", length=0.02)
bone("ShellSpent", (0, D.BOLT_FRONT + D.SHELL_LEN / 2, D.BORE_Z), "Weapon", length=0.02)
bone("ShellLive", (SHELL_LIVE_REST[0], SHELL_LIVE_REST[1] + D.SHELL_LEN / 2, SHELL_LIVE_REST[2]), "Weapon",
     length=0.02)
# attachment / reference bones (non-deforming)
bone("Grip", (0, -0.112, -0.022), "Weapon", deform=False, length=0.02)
bone("Muzzle", (0, D.MUZZLE_Y, D.BORE_Z), "Weapon", deform=False, length=0.02)
bone("ShellEject", (D.RECV_HW + 0.002, (D.PORT_Y0 + D.PORT_Y1) / 2, (D.PORT_Z0 + D.PORT_Z1) / 2), "Weapon",
     deform=False, length=0.02)
bone("ShellLoad", (0, (D.LOAD_Y0 + D.LOAD_Y1) / 2, D.RECV_BOT - 0.002), "Weapon", deform=False, length=0.02)
bone("SupportHand", (0, (D.PUMP_REAR + D.PUMP_FRONT) / 2 - 0.01, D.PUMP_CZ - D.PUMP_HH - 0.004), "Pump",
     deform=False, length=0.02)
bpy.ops.object.mode_set(mode="OBJECT")

BONE_OF = {n: "Weapon" for n in static}
for b, objs in moving.items():
    for o in objs:
        BONE_OF[o.name] = b
BONE_OF["Shell_Spent"] = "ShellSpent"
BONE_OF["Shell_Live"] = "ShellLive"

for name, b in BONE_OF.items():
    o = bpy.data.objects[name]
    vg = o.vertex_groups.new(name=b)
    vg.add(range(len(o.data.vertices)), 1.0, "REPLACE")
    o.parent = arm
    m = o.modifiers.new("Armature", "ARMATURE")
    m.object = arm
    o["bone"] = b

arm["description"] = "Rigid-skinned rig. Deform bones: Weapon, Pump, Bolt, Trigger, ShellCarrier, ShellSpent, ShellLive."

# ------------------------------------------------------------------ report + save
total = 0
rows = []
for o in sorted([o for o in master.all_objects if o.type == "MESH"], key=lambda o: o.name):
    t = L.tri_count(o)
    total += t
    rows.append(f"  {o.name:16s} {t:6d} tris  bone={o['bone']}")
print("MASTER objects:\n" + "\n".join(rows))
print("MASTER total tris:", total)
os.makedirs(L.p("blender"), exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=L.p("blender", "PumpShotgun_Master.blend"))
print("saved")
