"""Inspection renders of a .blend: python render_views.py <blend> <outdir> [clay|mat] [view ...]

Views: the names in sg_lib.STANDARD_VIEWS. Writes <outdir>/<view>.png and a contact sheet.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import bpy  # noqa: E402

import sg_lib as L  # noqa: E402

args = sys.argv[1:]
blend, outdir = args[0], args[1]
mode = args[2] if len(args) > 2 else "mat"
views = args[3:] or list(L.STANDARD_VIEWS)
samples = int(os.environ.get("SAMPLES", "64"))
bpy.ops.wm.open_mainfile(filepath=blend)
scn = bpy.context.scene
for c in bpy.data.collections:
    if c.name.startswith(("FP_", "TP_")):
        c.hide_render = True
if mode == "clay":
    clay = bpy.data.materials.new("Clay")
    clay.use_nodes = True
    b = clay.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (0.20, 0.20, 0.20, 1)
    b.inputs["Roughness"].default_value = 0.55
    bpy.context.view_layer.material_override = clay
L.studio(scn, samples=samples, res=(1600, 800))
paths = []
for v in views:
    loc, tgt, ortho, lens = L.STANDARD_VIEWS[v]
    cam = L.camera("Cam_" + v, loc, tgt, lens, ortho)
    paths.append(L.render(scn, cam, os.path.join(outdir, f"{v}.png")))
L.contact_sheet(paths, os.path.join(outdir, "_sheet.png"))
