"""Geometry builders for each shotgun component. One function per part so a
single component can be reworked without touching the rest.

Every builder returns the created object(s) in rest pose (pump forward,
bolt closed). Materials are assigned by name (source/procedural materials,
see sg_materials.py); the bake step later swaps them for the atlas material.
"""
import math

import bmesh
import bpy
from mathutils import Matrix, Vector

import sg_dims as D
import sg_lib as L

TAU = 2 * math.pi


# ------------------------------------------------------------------ helpers
def rrect(hw, z0, z1, rt, rb, cs=6, cx=0.0):
    """Rounded rectangle section (XZ), 4*cs points, CCW from bottom-right."""
    pts = []
    arcs = [((cx + hw - rb, z0 + rb), rb, -90, 0),
            ((cx + hw - rt, z1 - rt), rt, 0, 90),
            ((cx - hw + rt, z1 - rt), rt, 90, 180),
            ((cx - hw + rb, z0 + rb), rb, 180, 270)]
    for (ax, az), r, a0, a1 in arcs:
        for k in range(cs):
            a = math.radians(a0 + (a1 - a0) * k / (cs - 1))
            pts.append((ax + r * math.cos(a), az + r * math.sin(a)))
    return pts


def sq_section(hw, z0, z1, n_top, n_bot, cs=6):
    """Superellipse section with the same point layout as rrect()."""
    cz, h = (z0 + z1) / 2, (z1 - z0) / 2
    pts = []
    for q, (a0, a1) in enumerate(((-90, 0), (0, 90), (90, 180), (180, 270))):
        for k in range(cs):
            # half-step offset: no duplicate points where quadrants meet
            a = math.radians(a0 + (a1 - a0) * (k + 0.5) / cs)
            c, s = math.cos(a), math.sin(a)
            n = n_top if s > 0 else n_bot
            x = hw * math.copysign(abs(c) ** (2 / n), c)
            z = h * math.copysign(abs(s) ** (2 / n), s)
            pts.append((x, cz + z))
    return pts


def lerp_sec(a, b, t):
    return [(ax + (bx - ax) * t, az + (bz - az) * t) for (ax, az), (bx, bz) in zip(a, b)]


def interp(table, y):
    """Smooth (cosine) interpolation in a sorted (y, value) table."""
    table = sorted(table)
    if y <= table[0][0]:
        return table[0][1]
    if y >= table[-1][0]:
        return table[-1][1]
    for (y0, v0), (y1, v1) in zip(table[:-1], table[1:]):
        if y0 <= y <= y1:
            t = (y - y0) / (y1 - y0)
            t = (1 - math.cos(math.pi * t)) / 2
            return v0 + (v1 - v0) * t
    return table[-1][1]


def interp_smooth(table, y):
    """Catmull-Rom style cubic through a sorted (y, value) table (no flat spots)."""
    t_ = sorted(table)
    if y <= t_[0][0]:
        return t_[0][1]
    if y >= t_[-1][0]:
        return t_[-1][1]
    n = len(t_)

    def slope(i):
        a, b = t_[max(i - 1, 0)], t_[min(i + 1, n - 1)]
        return (b[1] - a[1]) / (b[0] - a[0])
    for i in range(n - 1):
        (y0, v0), (y1, v1) = t_[i], t_[i + 1]
        if y0 <= y <= y1:
            h = y1 - y0
            t = (y - y0) / h
            m0, m1 = slope(i) * h, slope(i + 1) * h
            t2, t3 = t * t, t * t * t
            return ((2 * t3 - 3 * t2 + 1) * v0 + (t3 - 2 * t2 + t) * m0
                    + (-2 * t3 + 3 * t2) * v1 + (t3 - t2) * m1)
    return t_[-1][1]


def mat(obj, *names):
    """Replace all slots (booleans can leave empty ones) with the given materials."""
    obj.data.materials.clear()
    for n in names:
        obj.data.materials.append(bpy.data.materials[n])
    for poly in obj.data.polygons:
        poly.material_index = 0
    return obj


def finish_hard(obj, width=0.0008, segments=2, angle=40):
    """Hard-surface finish: angle-limited bevel + weighted normals, applied."""
    L.bevel(obj, width=width, segments=segments, angle=angle, apply=True)
    for poly in obj.data.polygons:
        poly.use_smooth = True
    L.weighted_normals(obj, apply=True)
    return obj


def finish_soft(obj, angle=50):
    L.shade_auto(obj, angle)
    return obj


def ext_rrect_yz(name, y0, y1, z0, z1, r, x0, x1, col, seg=5):
    """Extrude a rounded rectangle drawn in YZ across X (good for cutters)."""
    pts = []
    corners = [((y1 - r, z0 + r), -90, 0), ((y1 - r, z1 - r), 0, 90),
               ((y0 + r, z1 - r), 90, 180), ((y0 + r, z0 + r), 180, 270)]
    for (cy, cz), a0, a1 in corners:
        for k in range(seg):
            a = math.radians(a0 + (a1 - a0) * k / (seg - 1))
            pts.append((cy + r * math.cos(a), cz + r * math.sin(a)))
    return L.extrude_profile(name, pts, x0, x1, col)


def ext_rrect_xy(name, x0, x1, y0, y1, r, z0, z1, col, seg=5):
    o = ext_rrect_yz(name, x0, x1, y0, y1, r, z0, z1, col, seg)
    # rotate so the drawn plane (Y,Z) becomes (X,Y) and extrusion X becomes Z
    m = Matrix(((0, 1, 0, 0), (0, 0, 1, 0), (1, 0, 0, 0), (0, 0, 0, 1)))
    o.data.transform(m)
    return o


def disc(name, r, depth, center, axis, col, seg=16):
    return L.cylinder(name, r, depth, center, axis=axis, seg=seg, col=col)


def join(objs, name):
    objs = [o for o in objs if o]
    with bpy.context.temp_override(active_object=objs[0], selected_editable_objects=objs,
                                   selected_objects=objs, object=objs[0]):
        bpy.ops.object.join()
    objs[0].name = name
    objs[0].data.name = name
    return objs[0]


# ------------------------------------------------------------------ receiver
def receiver(col):
    top_t = [(D.RECV_REAR, 0.0305), (D.RECV_REAR + 0.016, 0.0345), (D.RECV_REAR + 0.032, D.RECV_TOP),
             (D.RECV_FRONT - 0.012, D.RECV_TOP), (D.RECV_FRONT, 0.0335)]
    bot_t = [(D.RECV_REAR, D.RECV_BOT), (D.RECV_FRONT - 0.006, D.RECV_BOT), (D.RECV_FRONT, D.RECV_BOT + 0.004)]
    hw_t = [(D.RECV_REAR, D.RECV_HW), (D.RECV_FRONT - 0.010, D.RECV_HW), (D.RECV_FRONT, D.RECV_HW - 0.0012)]
    ys = [D.RECV_REAR, D.RECV_REAR + 0.008, D.RECV_REAR + 0.016, D.RECV_REAR + 0.024, D.RECV_REAR + 0.032,
          -0.03, 0.04, D.RECV_FRONT - 0.012, D.RECV_FRONT - 0.006, D.RECV_FRONT]
    st = [(y, rrect(interp(hw_t, y), interp(bot_t, y), interp(top_t, y), 0.0105, 0.0025, cs=7)) for y in ys]
    rec = L.loft("Receiver", st, col, smooth=False)

    cutters = []
    # bolt channel (interior, visible through the ports)
    cutters.append(L.box("cut_channel", (0.025, (D.RECV_FRONT - 0.006) - (-0.097), D.BOLT_Z1 - D.BOLT_Z0 + 0.002),
                         (0, ((D.RECV_FRONT - 0.006) + (-0.097)) / 2, (D.BOLT_Z0 + D.BOLT_Z1) / 2), col))
    # ejection port, right side
    cutters.append(ext_rrect_yz("cut_port", D.PORT_Y0, D.PORT_Y1, D.PORT_Z0, D.PORT_Z1, 0.0035,
                                0.004, 0.05, col))
    # loading port, bottom
    cutters.append(ext_rrect_xy("cut_load", -D.LOAD_HW, D.LOAD_HW, D.LOAD_Y0, D.LOAD_Y1, 0.004,
                                -0.07, D.BOLT_Z0 + 0.0005, col))
    # action bar slots
    for sx in (-1, 1):
        cutters.append(L.box(f"cut_bar{sx}", (0.0032, 0.17, 0.0080),
                             (sx * 0.0150, D.RECV_FRONT - 0.075, D.TUBE_Z + 0.004), col))
    # magazine tube socket in the receiver front
    cutters.append(L.cylinder("cut_tube", D.TUBE_R + 0.0004, 0.03, (0, D.RECV_FRONT, D.TUBE_Z), col=col))
    # barrel socket
    cutters.append(L.cylinder("cut_barrel", 0.0146, 0.012, (0, D.RECV_FRONT, D.BORE_Z), col=col))
    # panel-line seams (shallow grooves both sides) + a vertical seam near the rear
    for sx in (-1, 1):
        cutters.append(L.box(f"cut_seam_h{sx}", (0.0016, 0.196, 0.0010),
                             (sx * D.RECV_HW, 0.0, -0.0235), col))
        cutters.append(L.box(f"cut_seam_v{sx}", (0.0016, 0.0010, 0.040),
                             (sx * D.RECV_HW, -0.082, 0.004), col))
    # left side lightening relief (shallow milled panel), gives the flat side some form
    cutters.append(ext_rrect_yz("cut_relief", -0.070, 0.090, -0.019, 0.022, 0.006,
                                -D.RECV_HW - 0.01, -D.RECV_HW + 0.0009, col))
    # right side: shallow relief behind the ejection port
    cutters.append(ext_rrect_yz("cut_relief_r", -0.070, -0.004, -0.019, 0.022, 0.006,
                                D.RECV_HW - 0.0009, D.RECV_HW + 0.01, col))
    for c in cutters:
        L.boolean(rec, c)
    finish_hard(rec, width=0.0009, segments=2, angle=40)
    return mat(rec, "M_Src_Metal")


def sight_rib(col):
    o = ext_rrect_yz("SightRib", -0.072, D.RECV_FRONT - 0.010, D.RECV_TOP - 0.0015, D.RECV_TOP + 0.0022,
                     0.0012, -0.0042, 0.0042, col)
    finish_hard(o, 0.0006)
    return mat(o, "M_Src_Serrated")


def rear_sight(col):
    o = ext_rrect_yz("RearSight", -0.068, -0.050, D.RECV_TOP + 0.001, D.RECV_TOP + 0.0105, 0.002,
                     -0.0080, 0.0080, col)
    notch = L.box("cut_notch", (0.006, 0.05, 0.006), (0, -0.059, D.RECV_TOP + 0.0105), col)
    notch.data.transform(Matrix.Translation((0, -0.059, D.RECV_TOP + 0.0105))
                         @ Matrix.Rotation(math.radians(45), 4, "Y")
                         @ Matrix.Translation((0, 0.059, -(D.RECV_TOP + 0.0105))))
    L.boolean(o, notch)
    finish_hard(o, 0.0005)
    return mat(o, "M_Src_Metal")


def receiver_pins(col):
    parts = []
    for y in (-0.072, -0.014):
        for sx in (-1, 1):
            parts.append(disc("pin", 0.0029, 0.0022, (sx * D.RECV_HW, y, D.RECV_BOT + 0.0075), "X", col, 14))
    # front screw head on the left (magazine/receiver screw)
    parts.append(disc("pin", 0.0034, 0.0022, (-D.RECV_HW, 0.098, -0.026), "X", col, 16))
    o = join(parts, "ReceiverPins")
    finish_hard(o, 0.0004, 1, 40)
    return mat(o, "M_Src_MetalDark")


# ------------------------------------------------------------------ trigger group
def trigger_plate(col):
    z1, z0 = D.RECV_BOT + 0.0012, D.RECV_BOT - 0.0070
    o = ext_rrect_yz("TriggerPlate", D.GUARD_Y0 - 0.004, D.GUARD_Y1, z0, z1, 0.0022, -0.0150, 0.0150, col)
    slot = L.box("cut_trigslot", (0.0080, 0.024, 0.03), (0, -0.031, z0), col)
    L.boolean(o, slot)
    finish_hard(o, 0.0008)
    return mat(o, "M_Src_MetalDark")


def trigger_guard(col):
    ztop = D.RECV_BOT - 0.0045
    outer = L.spline_pts([(-0.002, ztop), (0.0015, -0.054), (-0.010, -0.0735), (-0.036, -0.0805),
                          (-0.064, -0.0745), (-0.086, -0.057), (-0.093, ztop)], 6, closed=True)
    inner = L.spline_pts([(-0.0075, ztop - 0.0035), (-0.0085, -0.056), (-0.017, -0.0675), (-0.036, -0.0725),
                          (-0.058, -0.0675), (-0.075, -0.055), (-0.080, ztop - 0.0035)], 6, closed=True)
    o = L.extrude_profile("TriggerGuard", outer, -0.0058, 0.0058, col)
    hole = L.extrude_profile("cut_guardhole", inner, -0.02, 0.02, col)
    L.boolean(o, hole)
    finish_hard(o, 0.0016, 2, 30)
    # crossbolt safety (both sides of the plate) and slide-release lever (left)
    parts = [o]
    for sx in (-1, 1):
        parts.append(disc("safety", 0.0034, 0.0030, (sx * 0.0152, -0.086, D.RECV_BOT - 0.0030), "X", col, 16))
    lever = L.extrude_profile("lever", L.spline_pts([(-0.0005, D.RECV_BOT - 0.001), (-0.0105, D.RECV_BOT - 0.0015),
                                                       (-0.0135, D.RECV_BOT - 0.0075), (-0.0040, D.RECV_BOT - 0.0060)], 4),
                              -0.0172, -0.0146, col)
    parts.append(lever)
    for p_ in parts[1:]:
        finish_hard(p_, 0.0004, 1, 40)
    o = join(parts, "TriggerGuard")
    return mat(o, "M_Src_MetalDark")


def trigger(col):
    px, py, pz = D.TRIGGER_PIVOT
    prof = L.spline_pts([(py + 0.0045, pz + 0.004), (py + 0.0062, pz - 0.009), (py + 0.0050, pz - 0.020),
                         (py + 0.0005, pz - 0.0285), (py - 0.0050, pz - 0.0315), (py - 0.0040, pz - 0.0255),
                         (py - 0.0015, pz - 0.0180), (py - 0.0035, pz - 0.0060), (py - 0.0045, pz + 0.004)], 5)
    o = L.extrude_profile("Trigger", prof, -0.0030, 0.0030, col)
    finish_hard(o, 0.0010, 2, 30)
    return mat(o, "M_Src_Metal")


# ------------------------------------------------------------------ action
def bolt(col):
    o = L.box("Bolt", (2 * D.BOLT_HW, D.BOLT_FRONT - D.BOLT_REAR, D.BOLT_Z1 - D.BOLT_Z0),
              (0, (D.BOLT_FRONT + D.BOLT_REAR) / 2, (D.BOLT_Z0 + D.BOLT_Z1) / 2), col)
    face = L.cylinder("cut_face", 0.0112, 0.004, (0, D.BOLT_FRONT, D.BORE_Z), col=col, seg=28)
    L.boolean(o, face)
    pin = L.cylinder("cut_fpin", 0.0016, 0.01, (0, D.BOLT_FRONT, D.BORE_Z), col=col, seg=10)
    L.boolean(o, pin)
    # right-side detailing visible through the port: extractor slot + two grooves
    L.boolean(o, L.box("cut_ext", (0.004, 0.022, 0.0030), (D.BOLT_HW, D.BOLT_FRONT - 0.011, D.BORE_Z + 0.004), col))
    for y in (0.030, 0.042):
        L.boolean(o, L.box("cut_grv", (0.0024, 0.0035, 0.030), (D.BOLT_HW, y, (D.BOLT_Z0 + D.BOLT_Z1) / 2), col))
    # top locking lug recess
    L.boolean(o, L.box("cut_lug", (0.012, 0.016, 0.004), (0, 0.010, D.BOLT_Z1), col))
    finish_hard(o, 0.0006, 2, 40)
    return mat(o, "M_Src_Bright")


def carrier(col):
    z = D.RECV_BOT + 0.0065
    o = ext_rrect_xy("ShellCarrier", -D.LOAD_HW + 0.0012, D.LOAD_HW - 0.0012, D.LOAD_Y0 + 0.004,
                     D.LOAD_Y1 - 0.008, 0.003, z - 0.0015, z + 0.0015, col)
    # central relief groove that cradles the shell
    L.boolean(o, ext_rrect_xy("cut_cradle", -0.0045, 0.0045, D.LOAD_Y0 + 0.012, D.LOAD_Y1 - 0.016, 0.0025,
                              z - 0.005, z - 0.0005, col))
    finish_hard(o, 0.0005, 1, 40)
    return mat(o, "M_Src_Bright")


# ------------------------------------------------------------------ barrel & tube
def barrel(col):
    y0 = D.RECV_FRONT - 0.0055
    R = D.BARREL_R
    prof = [(0.0142, y0), (0.0146, y0 + 0.004), (0.0146, D.RECV_FRONT + 0.010), (0.0141, D.RECV_FRONT + 0.0135),
            (R + 0.0004, D.RECV_FRONT + 0.020), (R + 0.0002, D.RECV_FRONT + 0.12), (R, D.MUZZLE_Y - 0.004),
            (R - 0.0006, D.MUZZLE_Y - 0.0012), (R - 0.0016, D.MUZZLE_Y), (D.BORE_R + 0.0012, D.MUZZLE_Y),
            (D.BORE_R + 0.0002, D.MUZZLE_Y - 0.0014), (D.BORE_R, D.MUZZLE_Y - 0.006), (D.BORE_R, D.MUZZLE_Y - 0.08)]
    o = L.lathe("Barrel", [(r, y) for r, y in prof], seg=40, col=col, axis_z=D.BORE_Z, cap_start=True, cap_end=True)
    finish_soft(o, 40)
    return mat(o, "M_Src_Metal")


def front_sight(col):
    yt = D.MUZZLE_Y - 0.010
    zb = D.BORE_Z + D.BARREL_R - 0.003
    ramp = L.spline_pts([(yt - 0.040, zb), (yt - 0.030, zb + 0.0045), (yt - 0.012, zb + 0.0060),
                         (yt + 0.004, zb + 0.0060), (yt + 0.006, zb)], 5, closed=True)
    base = L.extrude_profile("FrontSight", ramp, -0.0042, 0.0042, col)
    post = ext_rrect_yz("post", yt - 0.008, yt + 0.0015, zb + 0.004, zb + 0.0175, 0.0012, -0.0019, 0.0019, col)
    finish_hard(base, 0.0007, 2, 35)
    finish_hard(post, 0.0004, 1, 40)
    o = join([base, post], "FrontSight")
    return mat(o, "M_Src_Metal")


def mag_tube(col):
    o = L.lathe("MagTube", [(D.TUBE_R - 0.0003, D.RECV_FRONT - 0.004), (D.TUBE_R, D.RECV_FRONT - 0.003),
                            (D.TUBE_R, D.TUBE_END_Y)], seg=32, col=col, axis_z=D.TUBE_Z,
                cap_start=True, cap_end=True)
    finish_soft(o, 40)
    return mat(o, "M_Src_Metal")


def mag_cap(col):
    y = D.TUBE_END_Y - 0.003
    r = D.TUBE_R + 0.0016
    prof = [(D.TUBE_R + 0.0003, y), (r, y + 0.0012)]
    yy = y + 0.002
    for k in range(5):  # grip rings
        prof += [(r, yy), (r - 0.0009, yy + 0.0008), (r - 0.0009, yy + 0.0018), (r, yy + 0.0026)]
        yy += 0.0032
    prof += [(r, y + D.CAP_LEN - 0.004), (r - 0.0012, y + D.CAP_LEN - 0.0008), (r - 0.004, y + D.CAP_LEN),
             (0.0035, y + D.CAP_LEN)]
    o = L.lathe("MagCap", prof, seg=24, col=col, axis_z=D.TUBE_Z, cap_start=True, cap_end=True)
    finish_soft(o, 40)
    # sling swivel eye under the cap
    eye = L.extrude_profile("eye", L.spline_pts([(y + 0.006, D.TUBE_Z - r + 0.002), (y + 0.016, D.TUBE_Z - r + 0.002),
                                                   (y + 0.014, D.TUBE_Z - r - 0.007), (y + 0.008, D.TUBE_Z - r - 0.007)], 4),
                            -0.0022, 0.0022, col)
    L.boolean(eye, L.cylinder("cut_eye", 0.0022, 0.02, (0.0, y + 0.011, D.TUBE_Z - r - 0.003), axis="X", col=col))
    finish_hard(eye, 0.0005, 1, 40)
    o = join([o, eye], "MagCap")
    return mat(o, "M_Src_MetalDark")


def barrel_band(col):
    y0, y1 = D.BAND_Y - 0.008, D.BAND_Y + 0.008
    rb, rt = D.BARREL_R + 0.0028, D.TUBE_R + 0.0028
    sec = []
    n = 40
    # stadium hull around barrel (top) and tube (bottom): sample convex hull of two circles
    for i in range(n):
        a = TAU * i / n
        c, s = math.cos(a), math.sin(a)
        p1 = (rb * c, D.BORE_Z + rb * s)
        p2 = (rt * c, D.TUBE_Z + rt * s)
        sec.append(p1 if (p1[0] * c + p1[1] * s) >= (p2[0] * c + p2[1] * s) else p2)
    sec = sec[n // 4:] + sec[:n // 4]
    st = [(y0, [(x * 0.97, D.BORE_Z + (z - D.BORE_Z) * 0.985) for x, z in sec]), (y0 + 0.0012, sec),
          (y1 - 0.0012, sec), (y1, [(x * 0.97, D.BORE_Z + (z - D.BORE_Z) * 0.985) for x, z in sec])]
    o = L.loft("BarrelBand", st, col, smooth=True)
    # split line between the two clamp halves + clamp screw boss on the right
    L.boolean(o, L.box("cut_split", (0.05, 0.020, 0.0012), (0, D.BAND_Y, (D.BORE_Z + D.TUBE_Z) / 2), col))
    finish_soft(o, 45)
    boss = disc("boss", 0.0042, 0.006, (rt + 0.001, D.BAND_Y, (D.BORE_Z + D.TUBE_Z) / 2), "X", col, 6)
    finish_hard(boss, 0.0004, 1, 40)
    o = join([o, boss], "BarrelBand")
    return mat(o, "M_Src_MetalDark")


# ------------------------------------------------------------------ pump group
def _pump_polar(n=48):
    """Forend outline as radii around the tube centre at n evenly spaced angles
    (starting at -90 deg). Polar form keeps the outline star-shaped so it bridges
    cleanly to the inner bore, and lets grooves scale the radius."""
    cz = D.TUBE_Z
    dense = []
    for i in range(4096):
        a = TAU * i / 4096
        c, s = math.cos(a), math.sin(a)
        ex = 2.6 if s > 0 else 2.3
        x = D.PUMP_HW * math.copysign(abs(c) ** (2 / ex), c)
        z = D.PUMP_CZ + D.PUMP_HH * math.copysign(abs(s) ** (2 / ex), s)
        dense.append((math.atan2(z - cz, x) % TAU, math.hypot(x, z - cz)))
    dense.sort()
    keys = [d[0] for d in dense]
    import bisect
    angles, radii = [], []
    for k in range(n):
        a = -math.pi / 2 + TAU * k / n
        idx = min(bisect.bisect_left(keys, a % TAU), len(dense) - 1)
        angles.append(a)
        radii.append(dense[idx][1])
    return angles, radii


SADDLE_CLEAR = D.BARREL_R + 0.0020


def _barrel_hit(a, clear=SADDLE_CLEAR):
    """Distance from the tube centre along angle a to the barrel clearance circle (inf if missed)."""
    dx, dz = math.cos(a), math.sin(a)
    oz = D.TUBE_Z - D.BORE_Z  # ray origin relative to the barrel centre (x = 0)
    b = oz * dz
    c = oz * oz - clear * clear
    disc = b * b - c
    if disc < 0:
        return float("inf")
    t = -b - math.sqrt(disc)
    return t if t > 0 else float("inf")


def _tube_annulus_loft(name, stations_scale, col, r_in, n=48):
    """Outer surface from the scaled polar forend outline (clamped clear of the
    barrel) + straight inner bore around the magazine tube."""
    angles, radii = _pump_polar(n)
    cz = D.TUBE_Z
    bm = bmesh.new()
    outer = []
    for y, s in stations_scale:
        ring = []
        for a, r in zip(angles, radii):
            rr = min(r * s, _barrel_hit(a))
            ring.append(bm.verts.new((rr * math.cos(a), y, cz + rr * math.sin(a))))
        outer.append(ring)
    inner = []
    for y in (stations_scale[0][0], stations_scale[-1][0]):
        inner.append([bm.verts.new((r_in * math.cos(a), y, cz + r_in * math.sin(a))) for a in angles])
    for a_, b_ in zip(outer[:-1], outer[1:]):
        for i in range(n):
            j = (i + 1) % n
            bm.faces.new((a_[i], a_[j], b_[j], b_[i]))
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((inner[0][i], inner[1][i], inner[1][j], inner[0][j]))
        bm.faces.new((outer[0][i], inner[0][i], inner[0][j], outer[0][j]))
        bm.faces.new((outer[-1][j], inner[1][j], inner[1][i], outer[-1][i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return L.mesh_object(name, bm, col)


def pump(col):
    y0, y1 = D.PUMP_REAR + 0.006, D.PUMP_FRONT
    st = [(y0, 0.925), (y0 + 0.0015, 0.965), (y0 + 0.004, 0.99), (y0 + 0.008, 1.0)]
    grooves = [y0 + 0.020 + 0.014 * k for k in range(3)] + [y1 - 0.022 - 0.014 * k for k in range(4)][::-1]
    for g in grooves:
        st += [(g - 0.0030, 1.0), (g - 0.0021, 0.996), (g - 0.0012, 0.915), (g, 0.902),
               (g + 0.0012, 0.915), (g + 0.0021, 0.996), (g + 0.0030, 1.0)]
    st += [(y1 - 0.010, 1.0), (y1 - 0.005, 0.985), (y1 - 0.002, 0.955), (y1, 0.90)]
    st.sort()
    o = _tube_annulus_loft("Pump", st, col, D.TUBE_R + 0.0009)
    finish_soft(o, 55)
    return mat(o, "M_Src_Wood")


def pump_ferrule(col):
    y0 = D.PUMP_REAR
    st = [(y0, 0.86), (y0 + 0.0012, 0.905), (y0 + 0.0050, 0.915), (y0 + 0.0068, 0.915)]
    o = _tube_annulus_loft("PumpFerrule", st, col, D.TUBE_R + 0.0009)
    finish_soft(o, 40)
    return mat(o, "M_Src_MetalDark")


def action_bars(col):
    parts = []
    y_front = D.PUMP_REAR + 0.004
    y_rear = D.PUMP_REAR - 0.152
    for sx in (-1, 1):
        b = ext_rrect_yz("bar", y_rear, y_front, D.TUBE_Z + 0.0012, D.TUBE_Z + 0.0068, 0.0008,
                         sx * 0.0150 - 0.0011, sx * 0.0150 + 0.0011, col, seg=3)
        finish_hard(b, 0.0003, 1, 40)
        parts.append(b)
    # bridge under the tube joining the bars to the ferrule
    br = L.box("bridge", (0.031, 0.006, 0.0022), (0, D.PUMP_REAR + 0.001, D.TUBE_Z - D.TUBE_R - 0.0015), col)
    finish_hard(br, 0.0004, 1, 40)
    parts.append(br)
    o = join(parts, "ActionBars")
    return mat(o, "M_Src_Bright")


# ------------------------------------------------------------------ stock
def stock(col):
    top_t = [(D.RECV_REAR, 0.0305), (-0.125, 0.0290), (-0.170, 0.0255), (-0.260, 0.0205), (D.STOCK_BUTT, 0.0165)]
    bot_t = [(D.RECV_REAR, D.RECV_BOT), (-0.122, -0.0385), (-0.150, -0.0445), (-0.190, -0.0560),
             (-0.260, -0.0780), (-0.330, -0.0985), (D.STOCK_BUTT, -0.1205)]
    hw_t = [(D.RECV_REAR, D.RECV_HW), (-0.125, 0.0186), (-0.150, 0.0172), (-0.210, 0.0182),
            (-0.300, 0.0204), (D.STOCK_BUTT, 0.0212)]
    cs = 9
    ys = [D.RECV_REAR - 0.0004, D.RECV_REAR - 0.0016]
    y = D.RECV_REAR - 0.006
    while y > D.STOCK_BUTT + 0.006:
        ys.append(y)
        y -= 0.008 if y > -0.20 else 0.012
    ys += [D.STOCK_BUTT + 0.005, D.STOCK_BUTT + 0.002, D.STOCK_BUTT + 0.0005, D.STOCK_BUTT]
    st = []
    for y in ys:
        hw, z0, z1 = interp_smooth(hw_t, y), interp_smooth(bot_t, y), interp_smooth(top_t, y)
        a = rrect(hw, z0, z1, 0.0105, 0.0025, cs)
        b = sq_section(hw, z0, z1, 2.7, 2.9, cs)
        t = min(1.0, max(0.0, (D.RECV_REAR - y) / 0.045))
        sec = lerp_sec(a, b, t)
        # edge roundover at both ends
        shrink = 1.0
        if y > D.RECV_REAR - 0.002:
            shrink = 0.965 if y > D.RECV_REAR - 0.001 else 0.99
        d_end = y - D.STOCK_BUTT
        if d_end < 0.0055:  # rounded butt edge: 5 mm, 2 mm, 0.5 mm, 0 mm from the butt
            shrink = 0.996 if d_end > 0.004 else 0.986 if d_end > 0.0015 else 0.972 if d_end > 0.0002 else 0.955
        cz = (z0 + z1) / 2
        sec = [(x * shrink, cz + (z - cz) * (1 - (1 - shrink) * 0.35)) for x, z in sec]
        st.append((y, sec))
    st.reverse()
    o = L.loft("Stock", st, col, smooth=True)
    finish_soft(o, 60)
    return mat(o, "M_Src_Wood")


def butt_pad(col):
    cs = 9
    y0, y1 = D.STOCK_BUTT, D.STOCK_BUTT - D.PAD_LEN
    hw, z0, z1 = 0.0212, -0.1205, 0.0165
    base = sq_section(hw, z0, z1, 2.7, 2.9, cs)
    cz = (z0 + z1) / 2

    def sc(s, dz=0.0):
        return [(x * s, cz + (z - cz) * (1 - (1 - s) * 0.5) + dz) for x, z in base]
    st = [(y1, sc(0.90)), (y1 + 0.0015, sc(0.97)), (y1 + 0.004, sc(1.005)), (y1 + 0.010, sc(1.01)),
          (y0 - 0.0040, sc(1.0)), (y0 - 0.0012, sc(0.985)), (y0, sc(0.955))]
    o = L.loft("ButtPad", st, col, smooth=True)
    # horizontal grip ribs on the pad sides
    for k in range(6):
        z = z0 + 0.022 + k * 0.018
        L.boolean(o, L.box("cut_rib", (0.08, 0.0080, 0.0022), (0, y1 + 0.009, z), col))
    finish_soft(o, 50)
    mat(o, "M_Src_Rubber")
    screws = []
    for z in (z1 - 0.026, z0 + 0.026):
        s = disc("screw", 0.0042, 0.003, (0, y1 - 0.0002, z), "Y", col, 16)
        L.boolean(s, L.box("cut_slot", (0.0090, 0.004, 0.0012), (0, y1 - 0.0016, z), col))
        finish_hard(s, 0.0004, 1, 40)
        screws.append(s)
    sw = join(screws, "PadScrews")
    return o, mat(sw, "M_Src_MetalDark")


def sling_stud(col):
    y, z = -0.330, -0.0985
    o = L.lathe("SlingStud", [(0.0046, 0.0), (0.0046, 0.004), (0.0026, 0.005), (0.0026, 0.011),
                              (0.0034, 0.012), (0.0034, 0.0145), (0.0001, 0.0150)], seg=16, col=col,
                cap_start=True)
    o.data.transform(Matrix.Translation((0, y, z + 0.002)) @ Matrix.Rotation(math.radians(-90), 4, "X"))
    L.boolean(o, L.cylinder("cut_hole", 0.0016, 0.02, (0, y, z - 0.0085), axis="X", col=col))
    finish_soft(o, 40)
    return mat(o, "M_Src_MetalDark")


# ------------------------------------------------------------------ shells
def shell(name, col, spent=False):
    R, Rr, H, Lh = D.SHELL_R, D.SHELL_RIM_R, D.SHELL_HEAD_LEN, D.SHELL_LEN
    prof = [(0.0001, 0.0), (Rr - 0.0007, 0.0), (Rr, 0.0005), (Rr, 0.0011), (R + 0.0002, 0.0016),
            (R + 0.0002, H), (R, H + 0.0006), (R, Lh - 0.004)]
    if spent:
        prof += [(R + 0.0003, Lh - 0.0005), (R - 0.0006, Lh + 0.002), (R - 0.0012, Lh + 0.0015),
                 (R - 0.0010, Lh - 0.004), (R - 0.0010, H + 0.004), (0.0001, H + 0.004)]
    else:
        prof += [(R - 0.0006, Lh - 0.0008), (R - 0.0030, Lh), (0.0040, Lh - 0.0006), (0.0001, Lh - 0.0012)]
    o = L.lathe(name, prof, seg=20, col=col, cap_start=False, cap_end=False)
    finish_soft(o, 40)
    mat(o, "M_Src_Brass", "M_Src_Hull")
    # faces past the brass head use the hull material
    for poly in o.data.polygons:
        cy = sum(o.data.vertices[v].co.y for v in poly.vertices) / len(poly.vertices)
        poly.material_index = 0 if cy < H + 0.0003 else 1
    return o
