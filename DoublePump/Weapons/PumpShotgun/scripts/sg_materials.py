"""Procedural *source* materials. These only exist to be baked into the
game-ready PBR atlas (BaseColor / Normal / Roughness / Metalness); nothing in
the exported assets depends on Blender-only nodes.

Every source material exposes four named nodes whose first output carries a
channel: OUT_BC (colour), OUT_RGH (roughness), OUT_MET (metalness). The
Principled BSDF's Normal input carries the bump detail. The bake script reroutes
these into an Emission shader one channel at a time.
"""
import bpy


def _base(name):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    out.name = "OUT"
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.name = "BSDF"
    nt.links.new(bsdf.outputs[0], out.inputs[0])
    tc = nt.nodes.new("ShaderNodeTexCoord")
    tc.name = "TC"
    return m, nt, bsdf, tc


def _node(nt, kind, **inputs):
    n = nt.nodes.new(kind)
    for k, v in inputs.items():
        if k.startswith("_"):
            setattr(n, k[1:], v)
        else:
            n.inputs[k].default_value = v
    return n


def _named(nt, name, socket):
    """Pass a socket through a named Reroute so the baker can find it."""
    r = nt.nodes.new("NodeReroute")
    r.name = name
    nt.links.new(socket, r.inputs[0])
    return r.outputs[0]


def _math(nt, op, a, b=None, clamp=False):
    n = nt.nodes.new("ShaderNodeMath")
    n.operation = op
    n.use_clamp = clamp
    for i, v in enumerate((a, b)):
        if v is None:
            continue
        if isinstance(v, (int, float)):
            n.inputs[i].default_value = v
        else:
            nt.links.new(v, n.inputs[i])
    return n.outputs[0]


def _mix_col(nt, fac, a, b):
    n = nt.nodes.new("ShaderNodeMix")
    n.data_type = "RGBA"
    for sock, v in ((n.inputs[0], fac), (n.inputs[6], a), (n.inputs[7], b)):
        if isinstance(v, (int, float)):
            sock.default_value = v
        elif isinstance(v, tuple):
            sock.default_value = v
        else:
            nt.links.new(v, sock)
    return n.outputs[2]


def _edge_mask(nt, radius=0.0012, gain=7.0, noise_scale=180.0, tc=None):
    """Convex-edge mask from the Bevel node (works in Cycles bakes), broken up by noise."""
    bev = _node(nt, "ShaderNodeBevel", Radius=radius)
    bev.samples = 8
    geo = nt.nodes.new("ShaderNodeNewGeometry")
    dot = nt.nodes.new("ShaderNodeVectorMath")
    dot.operation = "DOT_PRODUCT"
    nt.links.new(bev.outputs[0], dot.inputs[0])
    nt.links.new(geo.outputs["Normal"], dot.inputs[1])
    e = _math(nt, "SUBTRACT", 1.0, dot.outputs["Value"])
    e = _math(nt, "MULTIPLY", e, gain, clamp=True)
    nz = _node(nt, "ShaderNodeTexNoise", Scale=noise_scale, Detail=6.0, Roughness=0.65)
    nt.links.new(tc.outputs["Object"], nz.inputs["Vector"])
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].position = 0.42
    ramp.color_ramp.elements[1].position = 0.62
    nt.links.new(nz.outputs["Fac"], ramp.inputs[0])
    return _math(nt, "MULTIPLY", e, ramp.outputs[0], clamp=True)


def _bump(nt, bsdf, height, strength, distance=0.001):
    b = _node(nt, "ShaderNodeBump", Strength=strength, Distance=distance)
    nt.links.new(height, b.inputs["Height"])
    nt.links.new(b.outputs[0], bsdf.inputs["Normal"])
    return b


def metal(name, base, base2, rough, wear_col=(0.32, 0.32, 0.33, 1), wear=1.0, metallic=1.0,
          serrations=False, brushed=True):
    m, nt, bsdf, tc = _base(name)
    # large-scale tone variation
    n1 = _node(nt, "ShaderNodeTexNoise", Scale=22.0, Detail=4.0, Roughness=0.55)
    nt.links.new(tc.outputs["Object"], n1.inputs["Vector"])
    col = _mix_col(nt, n1.outputs["Fac"], base, base2)
    edge = _edge_mask(nt, tc=tc)
    edge = _math(nt, "MULTIPLY", edge, wear, clamp=True)
    col = _mix_col(nt, edge, col, wear_col)
    # brushed/machined streaks along the bore axis (Y)
    mp = _node(nt, "ShaderNodeMapping")
    mp.inputs["Scale"].default_value = (1.0, 0.04, 1.0) if brushed else (1, 1, 1)
    nt.links.new(tc.outputs["Object"], mp.inputs["Vector"])
    streak = _node(nt, "ShaderNodeTexNoise", Scale=900.0, Detail=2.0, Roughness=0.5)
    nt.links.new(mp.outputs[0], streak.inputs["Vector"])
    smudge = _node(nt, "ShaderNodeTexNoise", Scale=9.0, Detail=3.0, Roughness=0.5)
    nt.links.new(tc.outputs["Object"], smudge.inputs["Vector"])
    r = _math(nt, "SUBTRACT", streak.outputs["Fac"], 0.5)
    r = _math(nt, "MULTIPLY", r, 0.12)
    r2 = _math(nt, "SUBTRACT", smudge.outputs["Fac"], 0.5)
    r2 = _math(nt, "MULTIPLY", r2, 0.22)
    r = _math(nt, "ADD", r, r2)
    r = _math(nt, "ADD", r, rough)
    r = _math(nt, "SUBTRACT", r, _math(nt, "MULTIPLY", edge, 0.12), clamp=True)
    # pitting / micro dents
    pit = _node(nt, "ShaderNodeTexVoronoi", Scale=700.0)
    nt.links.new(tc.outputs["Object"], pit.inputs["Vector"])
    pr = nt.nodes.new("ShaderNodeValToRGB")
    pr.color_ramp.elements[0].position = 0.0
    pr.color_ramp.elements[1].position = 0.06
    nt.links.new(pit.outputs["Distance"], pr.inputs[0])
    h = _math(nt, "MULTIPLY", pr.outputs[0], 0.3)
    h = _math(nt, "ADD", h, _math(nt, "MULTIPLY", streak.outputs["Fac"], 0.35))
    if serrations:
        w = _node(nt, "ShaderNodeTexWave", Scale=1.0, Distortion=0.0)
        w.wave_type = "BANDS"
        w.bands_direction = "Y"
        w.wave_profile = "TRI"
        mp2 = _node(nt, "ShaderNodeMapping")
        mp2.inputs["Scale"].default_value = (700.0, 700.0, 700.0)
        nt.links.new(tc.outputs["Object"], mp2.inputs["Vector"])
        nt.links.new(mp2.outputs[0], w.inputs["Vector"])
        h = _math(nt, "ADD", h, _math(nt, "MULTIPLY", w.outputs["Fac"], 2.0))
    _bump(nt, bsdf, h, 0.12 if not serrations else 0.35, 0.0006)
    bc = _named(nt, "OUT_BC", col)
    rg = _named(nt, "OUT_RGH", r)
    mt_val = _node(nt, "ShaderNodeValue")
    mt_val.outputs[0].default_value = metallic
    mt = _named(nt, "OUT_MET", mt_val.outputs[0])
    nt.links.new(bc, bsdf.inputs["Base Color"])
    nt.links.new(rg, bsdf.inputs["Roughness"])
    nt.links.new(mt, bsdf.inputs["Metallic"])
    return m


def wood(name):
    m, nt, bsdf, tc = _base(name)
    # elongated rings along the stock length (Y) -> flat-sawn grain
    mp = _node(nt, "ShaderNodeMapping")
    mp.inputs["Location"].default_value = (0.05, 0.0, 0.11)
    mp.inputs["Scale"].default_value = (1.0, 0.035, 1.6)
    nt.links.new(tc.outputs["Object"], mp.inputs["Vector"])
    dn = _node(nt, "ShaderNodeTexNoise", Scale=38.0, Detail=4.0, Roughness=0.5)
    nt.links.new(tc.outputs["Object"], dn.inputs["Vector"])
    vm = nt.nodes.new("ShaderNodeVectorMath")
    vm.operation = "ADD"
    nt.links.new(mp.outputs[0], vm.inputs[0])
    sc = nt.nodes.new("ShaderNodeVectorMath")
    sc.operation = "SCALE"
    sc.inputs["Scale"].default_value = 0.007
    nt.links.new(dn.outputs["Color"], sc.inputs[0])
    nt.links.new(sc.outputs[0], vm.inputs[1])
    rings = _node(nt, "ShaderNodeTexWave", Scale=1.0, Distortion=1.6, **{"Detail": 3.0, "Detail Scale": 1.0})
    rings.wave_type = "RINGS"
    rings.rings_direction = "SPHERICAL"
    rings.wave_profile = "SAW"
    sc2 = nt.nodes.new("ShaderNodeVectorMath")
    sc2.operation = "SCALE"
    sc2.inputs["Scale"].default_value = 130.0
    nt.links.new(vm.outputs[0], sc2.inputs[0])
    nt.links.new(sc2.outputs[0], rings.inputs["Vector"])
    gr = nt.nodes.new("ShaderNodeValToRGB")
    gr.color_ramp.elements[0].position = 0.25
    gr.color_ramp.elements[0].color = (0.25, 0.090, 0.027, 1)
    gr.color_ramp.elements[1].position = 0.95
    gr.color_ramp.elements[1].color = (0.095, 0.031, 0.010, 1)
    nt.links.new(rings.outputs["Fac"], gr.inputs[0])
    # broad colour variation (heartwood/sapwood) and pores
    big = _node(nt, "ShaderNodeTexNoise", Scale=7.0, Detail=2.0)
    nt.links.new(tc.outputs["Object"], big.inputs["Vector"])
    col = _mix_col(nt, _math(nt, "MULTIPLY", big.outputs["Fac"], 0.45), gr.outputs[0], (0.17, 0.058, 0.018, 1))
    mp2 = _node(nt, "ShaderNodeMapping")
    mp2.inputs["Scale"].default_value = (1.0, 0.06, 1.0)
    nt.links.new(tc.outputs["Object"], mp2.inputs["Vector"])
    pores = _node(nt, "ShaderNodeTexNoise", Scale=1400.0, Detail=1.0)
    nt.links.new(mp2.outputs[0], pores.inputs["Vector"])
    pr = nt.nodes.new("ShaderNodeValToRGB")
    pr.color_ramp.elements[0].position = 0.30
    pr.color_ramp.elements[1].position = 0.45
    nt.links.new(pores.outputs["Fac"], pr.inputs[0])
    col = _mix_col(nt, _math(nt, "MULTIPLY", _math(nt, "SUBTRACT", 1.0, pr.outputs[0]), 0.35), col,
                   (0.09, 0.035, 0.012, 1))
    # light edge wear: handled finish rubbed lighter/smoother
    edge = _edge_mask(nt, radius=0.002, gain=5.0, noise_scale=90.0, tc=tc)
    edge = _math(nt, "MULTIPLY", edge, 0.55)
    col = _mix_col(nt, edge, col, (0.40, 0.19, 0.075, 1))
    r = _math(nt, "ADD", 0.36, _math(nt, "MULTIPLY", rings.outputs["Fac"], 0.14))
    r = _math(nt, "ADD", r, _math(nt, "MULTIPLY", _math(nt, "SUBTRACT", 1.0, pr.outputs[0]), 0.12))
    r = _math(nt, "SUBTRACT", r, _math(nt, "MULTIPLY", edge, 0.15), clamp=True)
    h = _math(nt, "ADD", _math(nt, "MULTIPLY", rings.outputs["Fac"], 0.25), pr.outputs[0])
    _bump(nt, bsdf, h, 0.18, 0.0004)
    nt.links.new(_named(nt, "OUT_BC", col), bsdf.inputs["Base Color"])
    nt.links.new(_named(nt, "OUT_RGH", r), bsdf.inputs["Roughness"])
    v = _node(nt, "ShaderNodeValue")
    v.outputs[0].default_value = 0.0
    nt.links.new(_named(nt, "OUT_MET", v.outputs[0]), bsdf.inputs["Metallic"])
    return m


def simple(name, color, rough, metallic, bump_scale=600.0, bump_strength=0.08, var=0.08):
    m, nt, bsdf, tc = _base(name)
    nz = _node(nt, "ShaderNodeTexNoise", Scale=bump_scale, Detail=3.0)
    nt.links.new(tc.outputs["Object"], nz.inputs["Vector"])
    big = _node(nt, "ShaderNodeTexNoise", Scale=30.0, Detail=2.0)
    nt.links.new(tc.outputs["Object"], big.inputs["Vector"])
    c2 = tuple(min(1.0, c * 1.35) for c in color[:3]) + (1,)
    col = _mix_col(nt, _math(nt, "MULTIPLY", big.outputs["Fac"], 0.6), color, c2)
    r = _math(nt, "ADD", rough - var / 2, _math(nt, "MULTIPLY", big.outputs["Fac"], var))
    _bump(nt, bsdf, nz.outputs["Fac"], bump_strength, 0.0005)
    nt.links.new(_named(nt, "OUT_BC", col), bsdf.inputs["Base Color"])
    nt.links.new(_named(nt, "OUT_RGH", r), bsdf.inputs["Roughness"])
    v = _node(nt, "ShaderNodeValue")
    v.outputs[0].default_value = metallic
    nt.links.new(_named(nt, "OUT_MET", v.outputs[0]), bsdf.inputs["Metallic"])
    return m


def make_all():
    # Metalness workflow: a metal's base colour is its reflectance, so blued steel
    # stays a dark blue-grey rather than black.
    metal("M_Src_Metal", (0.105, 0.115, 0.135, 1), (0.145, 0.155, 0.175, 1), 0.33,
          wear_col=(0.46, 0.46, 0.47, 1))
    metal("M_Src_MetalDark", (0.070, 0.070, 0.075, 1), (0.095, 0.095, 0.100, 1), 0.52,
          wear_col=(0.38, 0.38, 0.39, 1), wear=0.7, brushed=False)
    metal("M_Src_Bright", (0.36, 0.36, 0.37, 1), (0.44, 0.44, 0.45, 1), 0.26, wear=0.0)
    metal("M_Src_Serrated", (0.105, 0.115, 0.135, 1), (0.145, 0.155, 0.175, 1), 0.40, serrations=True,
          wear_col=(0.46, 0.46, 0.47, 1))
    wood("M_Src_Wood")
    simple("M_Src_Rubber", (0.030, 0.030, 0.031, 1), 0.82, 0.0, 900.0, 0.12)
    simple("M_Src_Brass", (0.72, 0.50, 0.22, 1), 0.30, 1.0, 900.0, 0.03)
    simple("M_Src_Hull", (0.42, 0.035, 0.025, 1), 0.45, 0.0, 400.0, 0.05)
