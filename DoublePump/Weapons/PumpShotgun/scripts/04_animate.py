"""Phase 5: author the first-person animation actions on Rig_PumpShotgun.

All actions are authored at 60 fps, start at frame 0 and only key bones
(no object transforms). Gameplay code decides when to play them and at what
speed; nothing here encodes cooldowns. Event frames are stored as pose
markers on each action and exported to exports/animations/animation_events.json.

Run: python 04_animate.py
"""
import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import bpy  # noqa: E402

import sg_dims as D  # noqa: E402
import sg_lib as L  # noqa: E402

FPS = 60
BLEND = L.p("blender", "PumpShotgun_Master.blend")
bpy.ops.wm.open_mainfile(filepath=BLEND)
scn = bpy.context.scene
scn.render.fps = FPS
arm = bpy.data.objects["Rig_PumpShotgun"]
arm.animation_data_create()
for pb in arm.pose.bones:
    pb.rotation_mode = "XYZ"

ANIMATED = ("Weapon", "Pump", "Bolt", "Trigger", "ShellCarrier", "ShellSpent", "ShellLive")
R = math.radians
S = D.PUMP_STROKE

for a in list(bpy.data.actions):
    if a.name.startswith("PumpShotgun_"):
        bpy.data.actions.remove(a)


def new_action(name, frames, loop=False, events=None, notes=""):
    act = bpy.data.actions.new("PumpShotgun_" + name)
    act.use_fake_user = True
    act.use_frame_range = True
    act.frame_range = (0, frames)
    act.use_cyclic = loop
    act["loop"] = loop
    act["notes"] = notes
    arm.animation_data.action = act
    for f, ev in (events or {}).items():
        m = act.pose_markers.new(ev)
        m.frame = f
    return act


def key(bone, frame, loc=(0, 0, 0), rot=(0, 0, 0)):
    pb = arm.pose.bones[bone]
    pb.location = loc
    pb.rotation_euler = tuple(R(v) for v in rot)
    pb.keyframe_insert("location", frame=frame, group=bone)
    pb.keyframe_insert("rotation_euler", frame=frame, group=bone)


def rest(frame, bones=ANIMATED):
    for b in bones:
        key(b, frame)


def bolt_and_pump(frame, d):
    key("Pump", frame, (0, -d, 0))
    key("Bolt", frame, (0, -d, 0))


actions = {}

# ------------------------------------------------------------------ Idle (loop)
a = new_action("Idle", 240, loop=True, notes="Subtle breathing sway. Loop.")
rest(0)
for f, (x, z, rx, rz) in {0: (0, 0, 0, 0), 60: (0.0006, 0.0012, 0.35, -0.25), 120: (0, 0.0004, -0.15, 0),
                           180: (-0.0006, 0.0012, 0.35, 0.25), 240: (0, 0, 0, 0)}.items():
    key("Weapon", f, (x, 0, z), (rx, 0, rz))
rest(240, [b for b in ANIMATED if b != "Weapon"])
actions["Idle"] = a

# ------------------------------------------------------------------ Fire
a = new_action("Fire", 18, events={0: "Fire", 12: "RecoverEnd"},
               notes="Recoil kick: back + muzzle up, fast recovery. Trigger pulled at frame 0.")
rest(0)
key("Trigger", 0, rot=(-14, 0, 0))
key("Weapon", 2, (0.002, -0.034, 0.004), (6.0, 0, -1.0))
key("Weapon", 5, (0.002, -0.027, 0.006), (7.5, 0, -1.2))
key("Trigger", 6, rot=(-6, 0, 0))
key("Weapon", 10, (0.0005, -0.008, 0.002), (2.0, 0, -0.3))
key("Trigger", 10, rot=(0, 0, 0))
rest(18)
actions["Fire"] = a

# ------------------------------------------------------------------ Pump
spent_rest_y = D.BOLT_FRONT + D.SHELL_LEN / 2
a = new_action("Pump", 30, events={8: "EjectShell", 11: "PumpBack", 26: "PumpForward"},
               notes="Forend + bolt travel back the full stroke, spent hull leaves the port, carrier lifts.")
rest(0)
bolt_and_pump(0, 0)
bolt_and_pump(3, S * 0.18)
bolt_and_pump(8, S * 0.78)
bolt_and_pump(11, S)
bolt_and_pump(13, S)
bolt_and_pump(18, S * 0.55)
bolt_and_pump(26, 0)
bolt_and_pump(30, 0)
key("Weapon", 0)
key("Weapon", 6, (0.001, -0.006, -0.004), (-1.5, 3.5, 0.6))
key("Weapon", 11, (0.001, -0.010, -0.005), (-2.2, 4.0, 0.8))
key("Weapon", 18, (0.0005, 0.004, -0.002), (0.8, 2.0, 0.2))
key("Weapon", 30)
# spent shell rides on the bolt face, then flips out of the port when it lines up (d ~= 0.072)
key("ShellSpent", 0)
key("ShellSpent", 3, (0, -S * 0.18, 0))
key("ShellSpent", 8, (0, -S * 0.78, 0))
key("ShellSpent", 9, (0.012, -S * 0.80, 0.002), (0, 0, -10))
key("ShellSpent", 11, (0.050, -S * 0.82, 0.012), (0, -15, -45))
key("ShellSpent", 15, (0.160, -S * 0.75, 0.060), (0, -40, -110))
key("ShellSpent", 29, (0.160, -S * 0.75, 0.060), (0, -40, -110))
key("ShellSpent", 30)  # snaps back into the chamber (hidden) for the next cycle
key("ShellCarrier", 0)
key("ShellCarrier", 9)
key("ShellCarrier", 12, rot=(12, 0, 0))
key("ShellCarrier", 16, rot=(12, 0, 0))
key("ShellCarrier", 22)
key("ShellCarrier", 30)
for b in ("Trigger", "ShellLive"):
    key(b, 0)
    key(b, 30)
actions["Pump"] = a

# ------------------------------------------------------------------ Reload (start / insert loop / end)
TILT = dict(loc=(0.004, 0.010, 0.022), rot=(9.0, 32.0, -4.0))
a = new_action("ReloadStart", 18, events={18: "ReadyToInsert"},
               notes="Rolls the gun to present the loading port. Follow with ReloadInsert.")
rest(0)
key("Weapon", 10, (0.004, 0.012, 0.024), (10.0, 34.0, -4.5))
key("Weapon", 18, **TILT)
rest(18, [b for b in ANIMATED if b != "Weapon"])
actions["ReloadStart"] = a

live_rest_y = D.RECV_FRONT + 0.03 + D.SHELL_LEN / 2
port_y = (D.LOAD_Y0 + D.LOAD_Y1) / 2


def live(frame, y, z, rx):
    """Absolute shell-centre target (y, z) -> bone offset from its rest pose."""
    key("ShellLive", frame, (0, y - live_rest_y, z - D.TUBE_Z), (rx, 0, 0))


a = new_action("ReloadInsert", 36, loop=False, events={22: "ShellInserted", 36: "InsertEnd"},
               notes="One shell through the loading port into the tube. Start and end poses match, "
                     "so it can repeat, or be cut after ShellInserted for ReloadEnd/Fire.")
key("Weapon", 0, **TILT)
key("Weapon", 16, TILT["loc"], TILT["rot"])
key("Weapon", 21, (TILT["loc"][0], TILT["loc"][1] + 0.002, TILT["loc"][2] + 0.004), (10.5, 32.5, -4.0))
key("Weapon", 28, **TILT)
key("Weapon", 36, **TILT)
live(0, port_y - 0.010, D.TUBE_Z - 0.080, -25)
live(8, port_y - 0.004, D.TUBE_Z - 0.050, -18)
live(14, port_y, D.TUBE_Z - 0.026, 8)
live(18, port_y + 0.004, D.TUBE_Z - 0.004, 2)
live(22, port_y + 0.030, D.TUBE_Z, 0)
live(26, live_rest_y, D.TUBE_Z, 0)
live(36, live_rest_y, D.TUBE_Z, 0)
key("ShellCarrier", 0)
key("ShellCarrier", 12)
key("ShellCarrier", 16, rot=(7, 0, 0))
key("ShellCarrier", 22, rot=(7, 0, 0))
key("ShellCarrier", 26)
key("ShellCarrier", 36)
for b in ("Pump", "Bolt", "Trigger", "ShellSpent"):
    key(b, 0)
    key(b, 36)
actions["ReloadInsert"] = a

a = new_action("ReloadEnd", 18, events={18: "ReloadDone"}, notes="Returns from the reload pose to rest.")
key("Weapon", 0, **TILT)
key("Weapon", 8, (0.002, 0.004, 0.010), (4.0, 12.0, -1.5))
key("Weapon", 18)
rest(0, [b for b in ANIMATED if b != "Weapon"])
rest(18, [b for b in ANIMATED if b != "Weapon"])
actions["ReloadEnd"] = a

# ------------------------------------------------------------------ Equip / Unequip / swap
LOW = dict(loc=(0.03, -0.06, -0.20), rot=(-38.0, 22.0, 8.0))
a = new_action("Equip", 24, events={20: "Ready"}, notes="Raise from below the screen to the ready position.")
key("Weapon", 0, **LOW)
key("Weapon", 12, (0.006, -0.012, -0.030), (-6.0, 4.0, 1.5))
key("Weapon", 18, (0.0, 0.002, 0.003), (1.2, -0.5, 0))
key("Weapon", 24)
rest(0, [b for b in ANIMATED if b != "Weapon"])
rest(24, [b for b in ANIMATED if b != "Weapon"])
actions["Equip"] = a

a = new_action("SwapIn", 9, events={7: "Ready"},
               notes="Fast raise for the double-pump swap (0.15 s at speed 1).")
key("Weapon", 0, **LOW)
key("Weapon", 5, (0.003, -0.004, -0.012), (-3.0, 2.0, 0.6))
key("Weapon", 7, (0.0, 0.001, 0.002), (0.6, 0, 0))
key("Weapon", 9)
rest(0, [b for b in ANIMATED if b != "Weapon"])
rest(9, [b for b in ANIMATED if b != "Weapon"])
actions["SwapIn"] = a

a = new_action("Unequip", 9, events={6: "Hidden"},
               notes="Fast drop out of view; used for the double-pump swap and holstering.")
key("Weapon", 0)
key("Weapon", 3, (0.006, -0.012, -0.030), (-7.0, 4.0, 1.5))
key("Weapon", 9, **LOW)
rest(0, [b for b in ANIMATED if b != "Weapon"])
rest(9, [b for b in ANIMATED if b != "Weapon"])
actions["Unequip"] = a


def fcurves(act):
    out = []
    for layer in getattr(act, "layers", []):
        for strip in layer.strips:
            for slot in act.slots:
                cb = strip.channelbag(slot)
                if cb:
                    out.extend(cb.fcurves)
    return out or list(getattr(act, "fcurves", []))


for act in actions.values():
    for fc in fcurves(act):
        for kp in fc.keyframe_points:
            kp.interpolation = "BEZIER"
            kp.handle_left_type = kp.handle_right_type = "AUTO_CLAMPED"
        fc.update()

# keep every action reachable as a muted NLA strip, and leave Idle active
tracks = arm.animation_data.nla_tracks
for t in list(tracks):
    tracks.remove(t)
for name, act in actions.items():
    t = tracks.new()
    t.name = act.name
    t.strips.new(act.name, 0, act)
    t.mute = True
arm.animation_data.action = actions["Idle"]
scn.frame_start, scn.frame_end = 0, 240

meta = {"fps": FPS, "units": "metres, bone-local (bones point +Y = muzzle)", "actions": {}}
for name, act in actions.items():
    f0, f1 = act.frame_range
    meta["actions"][act.name] = {
        "frames": [int(f0), int(f1)],
        "duration_s": round((f1 - f0) / FPS, 4),
        "loop": bool(act.get("loop")),
        "events": {m.name: {"frame": m.frame, "time_s": round(m.frame / FPS, 4)} for m in act.pose_markers},
        "notes": act.get("notes", ""),
    }
os.makedirs(L.p("exports", "animations"), exist_ok=True)
with open(L.p("exports", "animations", "animation_events.json"), "w") as f:
    json.dump(meta, f, indent=2)
print(json.dumps({k: (v["frames"], v["duration_s"]) for k, v in meta["actions"].items()}))
bpy.ops.wm.save_as_mainfile(filepath=BLEND)
