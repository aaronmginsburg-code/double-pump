"""Shared helpers for the Double Pump pump-shotgun build scripts.

Conventions (see README):
  * 1 Blender unit = 1 metre.
  * Muzzle points +Y, the gun's right side (ejection port) is +X, up is +Z.
  * World origin sits on the bore axis at the receiver/stock joint height-ish;
    attachment bones/empties carry the meaningful reference points.
"""
import math
import os

import bmesh
import bpy
from mathutils import Matrix, Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))


def p(*parts):
    return os.path.join(ROOT, *parts)


# ---------------------------------------------------------------- scene utils
def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scn = bpy.context.scene
    scn.unit_settings.system = "METRIC"
    scn.unit_settings.scale_length = 1.0
    scn.render.fps = 60
    return scn


def get_collection(name, parent=None):
    col = bpy.data.collections.get(name)
    if col is None:
        col = bpy.data.collections.new(name)
        (parent or bpy.context.scene.collection).children.link(col)
    return col


def link(obj, col):
    for c in list(obj.users_collection):
        c.objects.unlink(obj)
    col.objects.link(obj)
    return obj


def mesh_object(name, bm, col=None, smooth=True):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    obj = bpy.data.objects.new(name, me)
    (col or bpy.context.scene.collection).objects.link(obj)
    if smooth:
        for poly in me.polygons:
            poly.use_smooth = True
    return obj


def set_active(obj):
    for o in bpy.context.view_layer.objects:
        o.select_set(False)
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj


# ---------------------------------------------------------------- primitives
def superellipse(w, h, n_top=4.0, n_bot=4.0, cz=0.0, cx=0.0, seg=32, flat_bottom=0.0):
    """Closed section in the XZ plane. w/h are half sizes. Exponent 2 = ellipse,
    larger = boxier. Returns list of (x, z), counter-clockwise starting at +X."""
    pts = []
    for i in range(seg):
        t = 2 * math.pi * i / seg
        c, s = math.cos(t), math.sin(t)
        n = n_top if s >= 0 else n_bot
        x = w * math.copysign(abs(c) ** (2.0 / n), c)
        z = h * math.copysign(abs(s) ** (2.0 / n), s)
        if flat_bottom and z < -h + flat_bottom:
            z = -h + flat_bottom * 0.0
        pts.append((cx + x, cz + z))
    return pts


def loft(name, stations, col=None, cap_start=True, cap_end=True, smooth=True):
    """stations: list of (y, [(x, z), ...]) with equal point counts."""
    bm = bmesh.new()
    rings = []
    for y, sec in stations:
        rings.append([bm.verts.new((x, y, z)) for x, z in sec])
    n = len(rings[0])
    for a, b in zip(rings[:-1], rings[1:]):
        for i in range(n):
            j = (i + 1) % n
            bm.faces.new((a[i], a[j], b[j], b[i]))
    if cap_start:
        bm.faces.new(list(reversed(rings[0])))
    if cap_end:
        bm.faces.new(rings[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return mesh_object(name, bm, col, smooth)


def lathe(name, profile, seg=32, col=None, axis_z=0.0, axis_x=0.0, smooth=True,
          cap_start=False, cap_end=False):
    """Revolve a (radius, y) polyline around the Y axis (offset to axis_x/axis_z)."""
    stations = []
    for r, y in profile:
        sec = [(axis_x + r * math.cos(2 * math.pi * i / seg),
                axis_z + r * math.sin(2 * math.pi * i / seg)) for i in range(seg)]
        stations.append((y, sec))
    return loft(name, stations, col, cap_start, cap_end, smooth)


def extrude_profile(name, pts_yz, x0, x1, col=None, smooth=False):
    """Extrude a closed (y, z) polygon across X from x0 to x1."""
    bm = bmesh.new()
    a = [bm.verts.new((x0, y, z)) for y, z in pts_yz]
    b = [bm.verts.new((x1, y, z)) for y, z in pts_yz]
    n = len(pts_yz)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((a[i], a[j], b[j], b[i]))
    bm.faces.new(list(reversed(a)))
    bm.faces.new(b)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return mesh_object(name, bm, col, smooth)


def box(name, size, loc, col=None):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co = Vector((v.co.x * size[0], v.co.y * size[1], v.co.z * size[2])) + Vector(loc)
    return mesh_object(name, bm, col, smooth=False)


def cylinder(name, r, depth, loc, axis="Y", seg=24, col=None, smooth=True):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=seg, radius1=r, radius2=r, depth=depth)
    rot = {"X": Matrix.Rotation(math.radians(90), 4, "Y"),
           "Y": Matrix.Rotation(math.radians(90), 4, "X"),
           "Z": Matrix.Identity(4)}[axis]
    bmesh.ops.transform(bm, matrix=Matrix.Translation(loc) @ rot, verts=bm.verts)
    obj = mesh_object(name, bm, col, smooth)
    # flat caps, smooth sides
    for poly in obj.data.polygons:
        if len(poly.vertices) > 4:
            poly.use_smooth = False
    return obj


def spline_pts(ctrl, samples_per_seg=8, closed=True):
    """Catmull-Rom through 2D control points -> dense polyline."""
    out = []
    n = len(ctrl)
    rng = range(n) if closed else range(n - 1)
    for i in rng:
        p0 = Vector(ctrl[(i - 1) % n] if closed or i > 0 else ctrl[0])
        p1 = Vector(ctrl[i])
        p2 = Vector(ctrl[(i + 1) % n])
        p3 = Vector(ctrl[(i + 2) % n] if closed or i + 2 < n else ctrl[-1])
        for k in range(samples_per_seg):
            t = k / samples_per_seg
            t2, t3 = t * t, t * t * t
            v = 0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2
                       + (-p0 + 3 * p1 - 3 * p2 + p3) * t3)
            out.append((v.x, v.y))
    if not closed:
        out.append(tuple(ctrl[-1]))
    return out


# ---------------------------------------------------------------- modifiers
def boolean(obj, cutter, op="DIFFERENCE", apply=True, hide_cutter=True):
    m = obj.modifiers.new("Bool_" + cutter.name, "BOOLEAN")
    m.operation = op
    m.object = cutter
    m.solver = "EXACT"
    if apply:
        apply_mod(obj, m.name)
        if hide_cutter:
            bpy.data.objects.remove(cutter, do_unlink=True)
    return m


def apply_mod(obj, name):
    with bpy.context.temp_override(object=obj, active_object=obj, selected_objects=[obj]):
        bpy.ops.object.modifier_apply(modifier=name)


def bevel(obj, width=0.0015, segments=2, angle=35, apply=False, harden=True, clamp=True):
    m = obj.modifiers.new("Bevel", "BEVEL")
    m.width = width
    m.segments = segments
    m.limit_method = "ANGLE"
    m.angle_limit = math.radians(angle)
    m.use_clamp_overlap = clamp
    m.harden_normals = harden
    m.miter_outer = "MITER_ARC"
    if apply:
        apply_mod(obj, m.name)
    return m


def weighted_normals(obj, apply=False):
    m = obj.modifiers.new("WeightedNormal", "WEIGHTED_NORMAL")
    m.keep_sharp = True
    m.weight = 50
    if apply:
        apply_mod(obj, m.name)
    return m


def shade_auto(obj, angle=35):
    """Smooth by angle without the geometry-nodes modifier (bake-friendly)."""
    me = obj.data
    for poly in me.polygons:
        poly.use_smooth = True
    bm = bmesh.new()
    bm.from_mesh(me)
    lim = math.radians(angle)
    for e in bm.edges:
        if len(e.link_faces) == 2:
            e.smooth = e.calc_face_angle(0) < lim
        else:
            e.smooth = False
    bm.to_mesh(me)
    bm.free()


def apply_all_mods(obj):
    for m in list(obj.modifiers):
        if m.type == "ARMATURE":
            continue
        apply_mod(obj, m.name)


def tri_count(obj):
    deps = bpy.context.evaluated_depsgraph_get()
    ev = obj.evaluated_get(deps)
    me = ev.to_mesh()
    n = sum(len(pl.vertices) - 2 for pl in me.polygons)
    ev.to_mesh_clear()
    return n


# ---------------------------------------------------------------- rendering
def studio(scn, samples=96, res=(1600, 900), bg=0.18, floor=False):
    scn.render.engine = "CYCLES"
    scn.cycles.device = "CPU"
    scn.cycles.samples = samples
    scn.cycles.use_denoising = True
    scn.render.resolution_x, scn.render.resolution_y = res
    scn.render.film_transparent = False
    scn.view_settings.view_transform = "AgX"
    scn.view_settings.look = "AgX - Medium High Contrast"
    world = bpy.data.worlds.get("StudioWorld") or bpy.data.worlds.new("StudioWorld")
    world.use_nodes = True
    nt = world.node_tree
    nt.nodes.clear()
    # soft studio "HDRI": bright overhead, darker floor bounce, so metals have something to reflect
    out = nt.nodes.new("ShaderNodeOutputWorld")
    bgn = nt.nodes.new("ShaderNodeBackground")
    tc = nt.nodes.new("ShaderNodeTexCoord")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    nt.links.new(tc.outputs["Generated"], sep.inputs[0])
    remap = nt.nodes.new("ShaderNodeMath")  # world "Generated" z is the ray direction, -1..1 -> 0..1
    remap.operation = "MULTIPLY_ADD"
    remap.inputs[1].default_value = 0.5
    remap.inputs[2].default_value = 0.5
    nt.links.new(sep.outputs["Z"], remap.inputs[0])
    nt.links.new(remap.outputs[0], ramp.inputs[0])
    e = ramp.color_ramp.elements
    e[0].position, e[0].color = 0.30, (bg * 0.30, bg * 0.30, bg * 0.32, 1)
    e[1].position, e[1].color = 0.85, (bg * 1.6, bg * 1.6, bg * 1.7, 1)
    mid = e.new(0.52)  # bright-ish horizon so flat vertical steel faces reflect a readable grey
    mid.color = (bg * 1.35, bg * 1.35, bg * 1.4, 1)
    nt.links.new(ramp.outputs[0], bgn.inputs[0])
    bgn.inputs[1].default_value = 0.8
    # camera rays see a flat neutral backdrop instead of the gradient
    lp = nt.nodes.new("ShaderNodeLightPath")
    flat = nt.nodes.new("ShaderNodeBackground")
    flat.inputs[0].default_value = (bg, bg, bg * 1.04, 1)
    mix = nt.nodes.new("ShaderNodeMixShader")
    nt.links.new(lp.outputs["Is Camera Ray"], mix.inputs[0])
    nt.links.new(bgn.outputs[0], mix.inputs[1])
    nt.links.new(flat.outputs[0], mix.inputs[2])
    nt.links.new(mix.outputs[0], out.inputs[0])
    scn.world = world
    col = get_collection("_Studio")
    for o in list(col.objects):
        bpy.data.objects.remove(o, do_unlink=True)

    def area(name, loc, energy, size, color=(1, 1, 1)):
        ld = bpy.data.lights.new(name, "AREA")
        ld.energy = energy
        ld.size = size
        ld.color = color
        lo = bpy.data.objects.new(name, ld)
        lo.location = loc
        direction = Vector((0, 0.15, 0)) - Vector(loc)
        lo.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
        col.objects.link(lo)
        return lo

    area("Key", (1.6, 0.6, 1.4), 110, 1.2, (1.0, 0.97, 0.92))
    fill = area("Fill", (-1.6, -0.2, 0.6), 55, 1.6, (0.9, 0.95, 1.0))
    area("Rim", (0.2, -1.8, 1.2), 70, 1.0)
    top = area("Top", (0, 0.2, 2.0), 40, 2.0)
    # large soft lights only light the gun; mirrored in flat blued steel they blow it out to white
    fill.visible_glossy = False
    top.visible_glossy = False
    if floor:
        bm = bmesh.new()
        bmesh.ops.create_grid(bm, x_segments=1, y_segments=1, size=6)
        fl = mesh_object("Floor", bm, col)
        fl.location.z = -0.2
        mat = bpy.data.materials.get("M_Floor") or bpy.data.materials.new("M_Floor")
        mat.use_nodes = True
        mat.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.2, 0.2, 0.21, 1)
        mat.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.8
        fl.data.materials.append(mat)
    return col


def camera(name, loc, target, lens=50, ortho=None, col=None):
    cd = bpy.data.cameras.get(name) or bpy.data.cameras.new(name)
    cd.lens = lens
    cd.clip_start = 0.005
    if ortho:
        cd.type = "ORTHO"
        cd.ortho_scale = ortho
    else:
        cd.type = "PERSP"
    co = bpy.data.objects.get(name) or bpy.data.objects.new(name, cd)
    if co.name not in (col or get_collection("_Studio")).objects:
        (col or get_collection("_Studio")).objects.link(co)
    co.location = loc
    d = Vector(target) - Vector(loc)
    if abs(d.normalized().z) > 0.99:  # straight down: put the muzzle (+Y) to screen-right
        co.rotation_euler = (0, 0, math.radians(90))
    else:
        co.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
    return co


def render(scn, cam, path):
    scn.camera = cam
    scn.render.filepath = path
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.render.render(write_still=True)
    return path


STANDARD_VIEWS = {
    # name: (camera location, target, ortho scale or None, lens)
    "left_side": ((-2.0, 0.11, 0.0), (0, 0.11, 0.0), 1.15, 50),
    "right_side": ((2.0, 0.11, 0.0), (0, 0.11, 0.0), 1.15, 50),
    "top": ((0, 0.11, 2.0), (0, 0.11, 0.0), 1.15, 50),
    "front_three_quarter": ((0.62, 0.95, 0.28), (0, 0.10, -0.02), None, 50),
    "rear_three_quarter": ((-0.62, -0.78, 0.30), (0, 0.08, -0.02), None, 50),
    "receiver_closeup": ((0.36, 0.17, 0.12), (0.0, 0.03, -0.005), None, 50),
    "front": ((0, 2.0, -0.03), (0, 0, -0.03), 0.30, 50),
    "receiver_closeup_left": ((-0.36, 0.15, 0.10), (0.0, 0.02, -0.01), None, 50),
    "pump_closeup": ((0.30, 0.52, 0.06), (0.0, 0.31, -0.012), None, 50),
    "muzzle_closeup": ((0.16, 0.78, 0.06), (0.0, 0.57, 0.0), None, 50),
    "underside": ((0.12, 0.25, -0.40), (0.0, 0.03, -0.03), None, 50),
    "stock_closeup": ((0.32, -0.10, 0.10), (0.0, -0.26, -0.04), None, 50),
}


def contact_sheet(paths, out, cols=2, label=True, width=1600):
    from PIL import Image, ImageDraw
    ims = [Image.open(x).convert("RGB") for x in paths]
    w = width // cols
    thumbs = []
    for im, path in zip(ims, paths):
        h = int(im.height * w / im.width)
        t = im.resize((w, h))
        if label:
            d = ImageDraw.Draw(t)
            d.rectangle((0, 0, w, 22), fill=(0, 0, 0))
            d.text((6, 5), os.path.basename(path), fill=(255, 255, 255))
        thumbs.append(t)
    rows = (len(thumbs) + cols - 1) // cols
    rh = max(t.height for t in thumbs)
    sheet = Image.new("RGB", (w * cols, rh * rows), (30, 30, 30))
    for i, t in enumerate(thumbs):
        sheet.paste(t, ((i % cols) * w, (i // cols) * rh))
    sheet.save(out)
    return out
