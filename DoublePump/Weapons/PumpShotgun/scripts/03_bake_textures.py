"""Phase 4: UV-unwrap every master mesh into one shared atlas and bake the
procedural source materials into game-ready PBR maps:

  textures/first_person/T_PumpShotgun_{BaseColor,Normal,Roughness,Metalness}.png  (2048)
  textures/roblox_1024/T_PumpShotgun_*.png                                         (1024 downsample)

Normal maps are tangent space, OpenGL (+Y) convention, as Roblox requires.
Afterwards every mesh gets the single image-based material M_PumpShotgun.

Run: python 03_bake_textures.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import bpy  # noqa: E402

import sg_imgutil as U  # noqa: E402
import sg_lib as L  # noqa: E402

RES = int(os.environ.get("BAKE_RES", "2048"))
SAMPLES = int(os.environ.get("BAKE_SAMPLES", "24"))
BLEND = L.p("blender", "PumpShotgun_Master.blend")
bpy.ops.wm.open_mainfile(filepath=BLEND)
scn = bpy.context.scene
meshes = [o for o in bpy.data.collections["PumpShotgun_Master"].all_objects if o.type == "MESH"]

# ------------------------------------------------------------------ UVs
for o in meshes:
    while o.data.uv_layers:
        o.data.uv_layers.remove(o.data.uv_layers[0])
    o.data.uv_layers.new(name="UVMap")
for o in bpy.context.view_layer.objects:
    o.select_set(o in meshes)
bpy.context.view_layer.objects.active = meshes[0]
bpy.ops.object.mode_set(mode="EDIT")
bpy.ops.mesh.select_all(action="SELECT")
bpy.ops.uv.smart_project(angle_limit=1.15, island_margin=0.003, area_weight=0.0, correct_aspect=True,
                         scale_to_bounds=False)
bpy.ops.uv.average_islands_scale()
bpy.ops.uv.pack_islands(udim_source="CLOSEST_UDIM", rotate=True, margin_method="FRACTION", margin=0.006)
bpy.ops.object.mode_set(mode="OBJECT")

# ------------------------------------------------------------------ images
MAPS = {"BaseColor": "sRGB", "Roughness": "Non-Color", "Metalness": "Non-Color", "Normal": "Non-Color"}
imgs = {}
for k, cs in MAPS.items():
    name = f"T_PumpShotgun_{k}"
    if name in bpy.data.images:
        bpy.data.images.remove(bpy.data.images[name])
    im = bpy.data.images.new(name, RES, RES, alpha=True, float_buffer=(k == "Normal"))
    im.generated_color = (0, 0, 0, 0)
    im.colorspace_settings.name = cs
    imgs[k] = im

src_mats = sorted({s.material for o in meshes for s in o.material_slots if s.material}, key=lambda m: m.name)
print("source materials:", [m.name for m in src_mats])


def set_target(img):
    for m in src_mats:
        nt = m.node_tree
        n = nt.nodes.get("BAKE_TARGET") or nt.nodes.new("ShaderNodeTexImage")
        n.name = "BAKE_TARGET"
        n.image = img
        nt.nodes.active = n
        n.select = True


def route(channel):
    """channel None -> BSDF to output; else named reroute -> emission -> output."""
    for m in src_mats:
        nt = m.node_tree
        out = nt.nodes["OUT"]
        if channel is None:
            nt.links.new(nt.nodes["BSDF"].outputs[0], out.inputs[0])
            continue
        em = nt.nodes.get("BAKE_EMIT") or nt.nodes.new("ShaderNodeEmission")
        em.name = "BAKE_EMIT"
        nt.links.new(nt.nodes[channel].outputs[0], em.inputs["Color"])
        nt.links.new(em.outputs[0], out.inputs[0])


scn.render.engine = "CYCLES"
scn.cycles.device = "CPU"
scn.cycles.samples = SAMPLES
# Margin 0: in a multi-object bake, Blender's per-object margin can paint over
# neighbouring islands. Padding is added afterwards by dilate().
scn.render.bake.margin = 0
scn.render.bake.use_clear = True
for o in bpy.context.view_layer.objects:
    o.select_set(o in meshes)
bpy.context.view_layer.objects.active = meshes[0]

tex_fp = L.p("textures", "first_person")
tex_rb = L.p("textures", "roblox_1024")
os.makedirs(tex_fp, exist_ok=True)
os.makedirs(tex_rb, exist_ok=True)


def save(img, folder, size=None):
    path = os.path.join(folder, os.path.splitext(img.name)[0] + ".png")
    if size:
        cp = img.copy()
        cp.scale(size, size)
        cp.filepath_raw = path
        cp.file_format = "PNG"
        cp.save()
        bpy.data.images.remove(cp)
        return path
    img.filepath_raw = path
    img.file_format = "PNG"
    if img.is_float:
        # write 16-bit PNG for the normal map
        scn.render.image_settings.color_depth = "16"
    img.save()
    return path


for key, chan in (("BaseColor", "OUT_BC"), ("Roughness", "OUT_RGH"), ("Metalness", "OUT_MET")):
    set_target(imgs[key])
    route(chan)
    print("baking", key)
    for m in src_mats:
        assert m.node_tree.nodes.active and m.node_tree.nodes.active.name == "BAKE_TARGET", m.name
    bpy.ops.object.bake(type="EMIT")
    U.dilate(imgs[key])
    save(imgs[key], tex_fp)
set_target(imgs["Normal"])
route(None)
print("baking Normal")
bpy.ops.object.bake(type="NORMAL", normal_space="TANGENT", normal_r="POS_X", normal_g="POS_Y", normal_b="POS_Z")
U.dilate(imgs["Normal"])
save(imgs["Normal"], tex_fp)

# reload from disk so the material references the saved files (relative paths)
final_imgs = {}
for k, im in imgs.items():
    bpy.data.images.remove(im)
    im2 = bpy.data.images.load(os.path.join(tex_fp, f"T_PumpShotgun_{k}.png"))
    im2.colorspace_settings.name = MAPS[k]
    final_imgs[k] = im2
    save(im2, tex_rb, 1024)
    im2.filepath = bpy.path.relpath(os.path.join(tex_fp, f"T_PumpShotgun_{k}.png"), start=L.p("blender"))

# ------------------------------------------------------------------ final material
fm = bpy.data.materials.get("M_PumpShotgun") or bpy.data.materials.new("M_PumpShotgun")
fm.use_nodes = True
nt = fm.node_tree
nt.nodes.clear()
out = nt.nodes.new("ShaderNodeOutputMaterial")
bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
nt.links.new(bsdf.outputs[0], out.inputs[0])


def tex(k, x):
    n = nt.nodes.new("ShaderNodeTexImage")
    n.image = final_imgs[k]
    n.location = (x, 0)
    n.label = k
    return n


nt.links.new(tex("BaseColor", -600).outputs["Color"], bsdf.inputs["Base Color"])
nt.links.new(tex("Roughness", -600).outputs["Color"], bsdf.inputs["Roughness"])
nt.links.new(tex("Metalness", -600).outputs["Color"], bsdf.inputs["Metallic"])
nm = nt.nodes.new("ShaderNodeNormalMap")
nt.links.new(tex("Normal", -900).outputs["Color"], nm.inputs["Color"])
nt.links.new(nm.outputs[0], bsdf.inputs["Normal"])

for m in src_mats:
    route(None)
    n = m.node_tree.nodes.get("BAKE_TARGET")
    if n:
        m.node_tree.nodes.remove(n)
    m.use_fake_user = True  # kept for re-baking / editing
for o in meshes:
    o["source_materials"] = ",".join(s.material.name for s in o.material_slots if s.material)
    o.data.materials.clear()
    o.data.materials.append(fm)
    for poly in o.data.polygons:
        poly.material_index = 0

bpy.ops.wm.save_as_mainfile(filepath=BLEND, relative_remap=True)
print("bake done", RES)
