"""Renders map previews (vote-card art and top-down overviews) with Blender's Python module.

These are offline renders of the exact part geometry the game builds (exported by
tools/export_map.luau), lit to roughly match each map's in-game lighting. They are not
in-game screenshots: Roblox's lighting, materials and text signs look different.

Usage (from the repo root):
    pip install bpy
    for m in Warehouse DustTown Rooftops; do lune run tools/export_map.luau $m build/maps/$m.json; done
    python3 tools/render_maps.py build/maps assets/ui/maps docs/images/maps
"""

import json
import math
import os
import sys

import bpy
from mathutils import Matrix, Vector

# Roblox (Y up, -Z forward) -> Blender (Z up)
C = Matrix(((1, 0, 0), (0, 0, -1), (0, 1, 0)))


def to_blender(v):
    return Vector((v[0], -v[2], v[1]))


def srgb_to_linear(c):
    return tuple(((x + 0.055) / 1.055) ** 2.4 if x > 0.04045 else x / 12.92 for x in c)


# Camera shots per map, in Roblox coordinates: (eye, target, lens mm)
SHOTS = {
    "Warehouse": ((-62, 46, -52), (6, 0, 6), 30),
    "DustTown": ((-78, 40, -66), (4, 2, 4), 32),
    "Rooftops": ((-74, 38, -62), (2, -2, 2), 32),
}

# Parts hidden for the cutaway view of indoor maps (the roof would hide everything)
CUTAWAY = {"Warehouse": 23.5}

# Exposure per map (the white warehouse walls blow out, the night map needs a lift)
EXPOSURE = {"Warehouse": -0.7, "DustTown": -0.25, "Rooftops": 1.3}


def box_vertices(size, cf):
    hx, hy, hz = size[0] / 2, size[1] / 2, size[2] / 2
    corners = [(sx * hx, sy * hy, sz * hz) for sx in (-1, 1) for sy in (-1, 1) for sz in (-1, 1)]
    faces = [(0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)]
    return corners, faces


def wedge_vertices(size, cf):
    hx, hy, hz = size[0] / 2, size[1] / 2, size[2] / 2
    # Roblox WedgePart: high edge at the back (+Z), slope facing front/up
    v = [(-hx, -hy, -hz), (hx, -hy, -hz), (hx, -hy, hz), (-hx, -hy, hz), (-hx, hy, hz), (hx, hy, hz)]
    faces = [(0, 3, 2, 1), (3, 4, 5, 2), (0, 1, 5, 4), (0, 4, 3), (1, 2, 5)]
    return v, faces


def cylinder_vertices(size, cf, segments=20):
    hx = size[0] / 2
    ry, rz = size[1] / 2, size[2] / 2
    r = min(ry, rz)
    verts = []
    for side in (-1, 1):
        for i in range(segments):
            a = 2 * math.pi * i / segments
            verts.append((side * hx, math.cos(a) * r, math.sin(a) * r))
    faces = []
    for i in range(segments):
        j = (i + 1) % segments
        faces.append((i, j, segments + j, segments + i))
    faces.append(tuple(range(segments - 1, -1, -1)))
    faces.append(tuple(range(segments, 2 * segments)))
    return verts, faces


MATERIAL_LOOK = {
    "Metal": dict(metallic=0.8, roughness=0.4),
    "DiamondPlate": dict(metallic=0.75, roughness=0.35),
    "CorrodedMetal": dict(metallic=0.45, roughness=0.75),
    "Foil": dict(metallic=0.9, roughness=0.25),
    "SmoothPlastic": dict(roughness=0.35),
    "Plastic": dict(roughness=0.45),
    "Glass": dict(roughness=0.05, transmission=1.0),
    "Neon": dict(emission=6.0),
    "Fabric": dict(roughness=1.0),
}


def make_material(key):
    material_name, color, transparency = key
    mat = bpy.data.materials.new(name=f"{material_name}_{len(bpy.data.materials)}")
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    lin = srgb_to_linear(color)
    look = MATERIAL_LOOK.get(material_name, dict(roughness=0.85))
    bsdf.inputs["Base Color"].default_value = (*lin, 1)
    bsdf.inputs["Roughness"].default_value = look.get("roughness", 0.8)
    bsdf.inputs["Metallic"].default_value = look.get("metallic", 0.0)
    if "transmission" in look:
        bsdf.inputs["Transmission Weight"].default_value = look["transmission"]
    if "emission" in look:
        bsdf.inputs["Emission Color"].default_value = (*lin, 1)
        bsdf.inputs["Emission Strength"].default_value = look["emission"]
    if transparency > 0:
        bsdf.inputs["Alpha"].default_value = max(0.05, 1 - transparency)
    # Gentle colour variation on rough natural materials so big surfaces aren't flat
    if material_name in ("Concrete", "Plaster", "Sand", "Sandstone", "Asphalt", "Ground", "WoodPlanks", "Wood", "Brick", "Cardboard"):
        nt = mat.node_tree
        noise = nt.nodes.new("ShaderNodeTexNoise")
        noise.inputs["Scale"].default_value = 0.35 if material_name in ("Sand", "Ground", "Asphalt") else 1.2
        noise.inputs["Detail"].default_value = 6
        ramp = nt.nodes.new("ShaderNodeMix")
        ramp.data_type = "RGBA"
        ramp.inputs["Factor"].default_value = 0.25
        ramp.inputs[6].default_value = (*lin, 1)
        ramp.inputs[7].default_value = (*(x * 0.72 for x in lin), 1)
        nt.links.new(noise.outputs["Fac"], ramp.inputs["Factor"])
        nt.links.new(ramp.outputs[2], bsdf.inputs["Base Color"])
    return mat


def build_scene(data, cutaway_y=None):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    groups = {}
    for part in data["parts"]:
        cfc = part["cframe"]
        pos = Vector(cfc[0:3])
        if cutaway_y is not None and pos.y > cutaway_y:
            continue
        if part["name"] in ("Water",) and part["transparency"] > 0.9:
            continue
        rot = Matrix((cfc[3:6], cfc[6:9], cfc[9:12]))
        if part["shape"] == "Wedge":
            verts, faces = wedge_vertices(part["size"], cfc)
        elif part["shape"] == "Cylinder":
            verts, faces = cylinder_vertices(part["size"], cfc)
        else:
            verts, faces = box_vertices(part["size"], cfc)
        world = [to_blender(pos + rot @ Vector(v)) for v in verts]
        key = (part["material"], tuple(round(c, 3) for c in part["color"]), round(part["transparency"], 2))
        g = groups.setdefault(key, ([], []))
        base = len(g[0])
        g[0].extend(world)
        g[1].extend(tuple(base + i for i in f) for f in faces)
    for key, (verts, faces) in groups.items():
        mesh = bpy.data.meshes.new("m")
        mesh.from_pydata([tuple(v) for v in verts], [], faces)
        mesh.update()
        obj = bpy.data.objects.new("g", mesh)
        obj.data.materials.append(make_material(key))
        scene.collection.objects.link(obj)

    for light in data["lights"]:
        pos = to_blender(light["position"])
        if cutaway_y is not None and light["position"][1] > cutaway_y + 2:
            pos = pos - Vector((0, 0, 3))
        kind = "SPOT" if light["kind"] == "SpotLight" else "POINT"
        ld = bpy.data.lights.new("l", kind)
        ld.color = srgb_to_linear(light["color"])
        ld.energy = light["brightness"] * light["range"] ** 2 * 1.6
        ld.shadow_soft_size = 0.6
        if kind == "SPOT":
            ld.spot_size = math.radians(120)
            ld.spot_blend = 0.6
        lo = bpy.data.objects.new("l", ld)
        lo.location = pos
        scene.collection.objects.link(lo)
    return scene


def setup_world(scene, lighting, night):
    world = bpy.data.worlds.new("w")
    scene.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes["Background"]
    t = lighting["clockTime"]
    elevation = math.sin((t - 6) / 12 * math.pi) * 62
    if night:
        bg.inputs["Color"].default_value = (0.05, 0.05, 0.12, 1)
        bg.inputs["Strength"].default_value = 2.5
        sun_strength, sun_color, elevation = 0.25, (0.55, 0.62, 1.0), 40
    else:
        sky = world.node_tree.nodes.new("ShaderNodeTexSky")
        try:
            sky.sky_type = "NISHITA"
        except TypeError:
            pass
        try:
            sky.sun_elevation = math.radians(max(elevation, 8))
            sky.sun_rotation = math.radians(210)
        except AttributeError:
            pass
        world.node_tree.links.new(sky.outputs["Color"], bg.inputs["Color"])
        bg.inputs["Strength"].default_value = 0.5
        warm = t > 15.5 or t < 8
        sun_strength = 4.2 if not warm else 3.6
        sun_color = (1.0, 0.78, 0.55) if warm else (1.0, 0.95, 0.88)
    sun = bpy.data.lights.new("sun", "SUN")
    sun.energy = sun_strength
    sun.color = sun_color
    sun.angle = math.radians(1.5)
    so = bpy.data.objects.new("sun", sun)
    so.rotation_euler = (math.radians(90 - max(elevation, 8)), 0, math.radians(210))
    scene.collection.objects.link(so)


def add_camera(scene, eye, target, lens, ortho_extent=None):
    cam = bpy.data.cameras.new("cam")
    co = bpy.data.objects.new("cam", cam)
    scene.collection.objects.link(co)
    scene.camera = co
    e, t = to_blender(eye), to_blender(target)
    co.location = e
    direction = t - e
    co.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    if ortho_extent:
        cam.type = "ORTHO"
        cam.ortho_scale = ortho_extent
    else:
        cam.lens = lens
    cam.clip_end = 2000


def render(scene, path, width, height, samples, exposure=0.0):
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = samples
    scene.cycles.use_denoising = True
    scene.cycles.max_bounces = 4
    scene.render.resolution_x = width
    scene.render.resolution_y = height
    scene.render.resolution_percentage = 100
    scene.view_settings.view_transform = "AgX"
    scene.view_settings.look = "AgX - Medium High Contrast"
    scene.view_settings.exposure = exposure
    scene.render.image_settings.file_format = "PNG"
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)


def main():
    src, card_dir, overview_dir = sys.argv[-3:]
    os.makedirs(card_dir, exist_ok=True)
    os.makedirs(overview_dir, exist_ok=True)
    samples = int(os.environ.get("SAMPLES", "48"))
    for map_id, (eye, target, lens) in SHOTS.items():
        path = os.path.join(src, f"{map_id}.json")
        if not os.path.exists(path):
            continue
        with open(path) as f:
            data = json.load(f)
        night = data["lighting"]["clockTime"] > 19 or data["lighting"]["clockTime"] < 5
        cut = CUTAWAY.get(map_id)
        # Vote card (3/4 aerial)
        scene = build_scene(data, cut)
        setup_world(scene, data["lighting"], night)
        add_camera(scene, eye, target, lens)
        render(scene, os.path.abspath(os.path.join(card_dir, f"{map_id}.png")), 1200, 780, samples, EXPOSURE.get(map_id, 0))
        # Top-down overview
        scene = build_scene(data, cut)
        setup_world(scene, data["lighting"], night)
        ex = data["extents"]
        cx, cz = (ex[0] + ex[2]) / 2, (ex[1] + ex[3]) / 2
        add_camera(scene, (cx, 200, cz + 0.01), (cx, 0, cz), 50, ortho_extent=max(ex[2] - ex[0], ex[3] - ex[1]) * 1.04)
        render(scene, os.path.abspath(os.path.join(overview_dir, f"{map_id}_overview.png")), 1400, 900, samples, EXPOSURE.get(map_id, 0))
        print("rendered", map_id)


if __name__ == "__main__":
    main()
