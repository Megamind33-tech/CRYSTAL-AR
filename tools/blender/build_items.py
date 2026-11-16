# THE HUNT: the goods on the shelves as real 3D models (ShelfPanel renders
# each in a small studio): metal that's metal, plastic, glass, meat, rock,
# with bevelled edges that catch the light. One GLB per item, about the
# size of the thing in metres, standing on its base at the origin.
#   blender -b -P tools/blender/build_items.py -- <out_dir>
import bpy, bmesh, math, sys, os, random

OUT = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "/tmp/items"
os.makedirs(OUT, exist_ok=True)

# name: (base colour, metallic, roughness, alpha, emission strength)
MATS = {
    "steel": ((0.62, 0.64, 0.68), 1.0, 0.32, 1, 0), "dark_steel": ((0.18, 0.19, 0.21), 1.0, 0.4, 1, 0),
    "brushed": ((0.75, 0.76, 0.78), 1.0, 0.22, 1, 0), "brass": ((0.86, 0.66, 0.3), 1.0, 0.28, 1, 0),
    "gold": ((1.0, 0.77, 0.34), 1.0, 0.18, 1, 0), "copper": ((0.86, 0.45, 0.3), 1.0, 0.3, 1, 0),
    "rubber": ((0.05, 0.05, 0.055), 0.0, 0.85, 1, 0), "black_plastic": ((0.06, 0.06, 0.07), 0.0, 0.45, 1, 0),
    "white_plastic": ((0.9, 0.9, 0.88), 0.0, 0.4, 1, 0), "red_paint": ((0.72, 0.06, 0.05), 0.2, 0.42, 1, 0),
    "cyan_paint": ((0.12, 0.62, 0.78), 0.3, 0.38, 1, 0), "yellow_paint": ((0.95, 0.68, 0.05), 0.3, 0.4, 1, 0),
    "orange_paint": ((0.95, 0.38, 0.04), 0.2, 0.45, 1, 0), "olive": ((0.29, 0.33, 0.17), 0.0, 0.75, 1, 0),
    "khaki": ((0.55, 0.48, 0.32), 0.0, 0.8, 1, 0), "grey_paint": ((0.32, 0.34, 0.37), 0.4, 0.5, 1, 0),
    "glass": ((0.75, 0.9, 1.0), 0.0, 0.05, 0.35, 0), "blue_water": ((0.3, 0.6, 1.0), 0.0, 0.08, 0.55, 0),
    "ice": ((0.82, 0.93, 1.0), 0.0, 0.12, 0.7, 0), "lens": ((0.15, 0.35, 0.55), 0.6, 0.05, 1, 0),
    "meat": ((0.32, 0.015, 0.015), 0.0, 0.9, 1, 0), "meat_light": ((0.55, 0.1, 0.11), 0.0, 0.88, 1, 0),
    "fat": ((0.95, 0.88, 0.78), 0.0, 0.45, 1, 0), "bone": ((0.93, 0.89, 0.8), 0.0, 0.6, 1, 0),
    "leaf": ((0.18, 0.55, 0.12), 0.0, 0.55, 1, 0), "leaf_light": ((0.45, 0.78, 0.25), 0.0, 0.5, 1, 0),
    "algae": ((0.1, 0.75, 0.3), 0.0, 0.2, 1.0, 0.8), "red_powder": ((0.85, 0.08, 0.2), 0.0, 0.9, 1, 0),
    "rock": ((0.3, 0.27, 0.27), 0.0, 0.9, 1, 0), "crystal": ((0.8, 0.2, 0.55), 0.1, 0.08, 0.85, 0.3),
    "cardboard": ((0.62, 0.45, 0.27), 0.0, 0.9, 1, 0), "tape": ((0.78, 0.7, 0.5), 0.0, 0.35, 1, 0),
    "leather": ((0.33, 0.18, 0.09), 0.0, 0.7, 1, 0), "fabric": ((0.05, 0.05, 0.06), 0.0, 0.95, 1, 0),
    "screen": ((0.1, 0.9, 0.75), 0.0, 0.2, 1, 2.0), "glow": ((0.75, 0.3, 1.0), 0.0, 0.3, 1, 4.0),
    "green_edge": ((0.25, 0.85, 0.35), 0.4, 0.35, 1, 0.3), "label": ((0.95, 0.95, 0.92), 0.0, 0.6, 1, 0),
    "can_red": ((0.8, 0.05, 0.06), 0.9, 0.25, 1, 0),
}


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    for name, (col, metal, rough, alpha, emit) in MATS.items():
        m = bpy.data.materials.new(name)
        m.use_nodes = True
        p = m.node_tree.nodes["Principled BSDF"]
        p.inputs["Base Color"].default_value = (*col, 1)
        p.inputs["Metallic"].default_value = metal
        p.inputs["Roughness"].default_value = rough
        if alpha < 1:
            p.inputs["Alpha"].default_value = alpha
            m.blend_method = "BLEND"
        if emit > 0:
            p.inputs["Emission Color"].default_value = (*col, 1)
            p.inputs["Emission Strength"].default_value = emit


def _finish_obj(o, mat, bevel=0.0, smooth=True, subsurf=0):
    o.data.materials.append(bpy.data.materials[mat])
    if bevel > 0:
        b = o.modifiers.new("bevel", "BEVEL")
        b.width = bevel
        b.segments = 3
        b.limit_method = "ANGLE"
    if subsurf > 0:
        s = o.modifiers.new("sub", "SUBSURF")
        s.levels = subsurf
        s.render_levels = subsurf
    if smooth:
        bpy.ops.object.shade_smooth()
        o.data.use_auto_smooth = True
        o.data.auto_smooth_angle = math.radians(40)
    return o


def box(size, loc, mat, bevel=0.004, rot=(0, 0, 0), subsurf=0):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc, rotation=rot)
    o = bpy.context.object
    o.scale = size
    bpy.ops.object.transform_apply(scale=True)
    return _finish_obj(o, mat, bevel, True, subsurf)


def cyl(r, h, loc, mat, rot=(0, 0, 0), verts=32, bevel=0.002, r2=None):
    if r2 is None:
        bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=h, location=loc, rotation=rot)
    else:
        bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r, radius2=r2, depth=h, location=loc, rotation=rot)
    return _finish_obj(bpy.context.object, mat, bevel)


def sphere(r, loc, mat, scale=(1, 1, 1), subsurf=0, seg=32):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=seg, ring_count=seg // 2, radius=r, location=loc)
    o = bpy.context.object
    o.scale = scale
    bpy.ops.object.transform_apply(scale=True)
    return _finish_obj(o, mat, 0.0, True, subsurf)


def torus(r, minor, loc, mat, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_torus_add(major_radius=r, minor_radius=minor, location=loc, rotation=rot,
                                     major_segments=32, minor_segments=12)
    return _finish_obj(bpy.context.object, mat, 0.0)


def finish(name):
    """Apply modifiers, sit it on the ground at the origin, export."""
    bpy.ops.object.select_all(action="SELECT")
    objs = list(bpy.context.selected_objects)
    lo = min((o.matrix_world @ v.co).z for o in objs for v in o.data.vertices)
    for o in objs:
        o.location.z -= lo
    path = os.path.join(OUT, name + ".glb")
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", export_yup=True, export_apply=True,
                              export_materials="EXPORT")
    print("ITEM %s -> %s" % (name, path))


# --- The goods ---

def canister(name, body, band, h=0.42, r=0.08):
    reset()
    cyl(r, h, (0, 0, h / 2), body, bevel=0.01)
    sphere(r, (0, 0, h), body, scale=(1, 1, 0.55))
    cyl(r * 1.02, h * 0.1, (0, 0, h * 0.62), band, bevel=0.002)
    cyl(r * 1.02, h * 0.04, (0, 0, h * 0.15), band, bevel=0.002)
    cyl(r * 0.28, 0.05, (0, 0, h + r * 0.55 + 0.02), "steel")
    cyl(r * 0.4, 0.018, (0, 0, h + r * 0.55 + 0.05), "brass")
    torus(r * 0.55, 0.008, (0, 0, h + r * 0.55 + 0.085), "dark_steel", rot=(math.pi / 2, 0, 0))
    finish(name)


def oxygen_canister():
    canister("oxygen_canister", "cyan_paint", "white_plastic")


def helium3():
    canister("helium3", "yellow_paint", "black_plastic", h=0.36, r=0.075)


def fuel_cell():
    reset()
    box((0.17, 0.32, 0.36), (0, 0, 0.18), "orange_paint", bevel=0.02)
    for x in (-0.087, 0.087):  # the pressed ribs
        box((0.01, 0.24, 0.24), (x, 0.0, 0.17), "orange_paint", bevel=0.004)
    box((0.04, 0.2, 0.03), (0, -0.02, 0.38), "orange_paint", bevel=0.01)
    box((0.04, 0.03, 0.06), (0, 0.06, 0.36), "orange_paint", bevel=0.008)
    box((0.04, 0.03, 0.06), (0, -0.1, 0.36), "orange_paint", bevel=0.008)
    cyl(0.025, 0.04, (0, 0.12, 0.38), "black_plastic", rot=(0.3, 0, 0))
    finish("fuel_cell")


def water_ration():
    reset()
    cyl(0.055, 0.2, (0, 0, 0.1), "blue_water", bevel=0.008)
    cyl(0.055, 0.025, (0, 0, 0.215), "blue_water", r2=0.022, bevel=0.0)
    cyl(0.022, 0.03, (0, 0, 0.24), "white_plastic")
    cyl(0.0565, 0.07, (0, 0, 0.1), "label", bevel=0.0)
    finish("water_ration")


def stim_cola():
    reset()
    cyl(0.033, 0.115, (0, 0, 0.0575), "can_red", bevel=0.004)
    cyl(0.03, 0.006, (0, 0, 0.118), "brushed")
    cyl(0.0335, 0.03, (0, 0, 0.06), "label", bevel=0.0)
    box((0.016, 0.026, 0.002), (0, 0.012, 0.122), "brushed", bevel=0.001)
    finish("stim_cola")


def medkit():
    reset()
    box((0.3, 0.11, 0.22), (0, 0, 0.11), "white_plastic", bevel=0.015)
    box((0.29, 0.112, 0.006), (0, 0, 0.16), "grey_paint", bevel=0.0)
    box((0.12, 0.004, 0.035), (0, -0.057, 0.09), "red_paint", bevel=0.001)
    box((0.035, 0.004, 0.12), (0, -0.057, 0.09), "red_paint", bevel=0.001)
    box((0.12, 0.025, 0.02), (0, 0, 0.235), "grey_paint", bevel=0.008)
    finish("medkit")


def repair_kit():
    reset()
    box((0.36, 0.16, 0.14), (0, 0, 0.07), "red_paint", bevel=0.01)
    box((0.365, 0.165, 0.035), (0, 0, 0.155), "red_paint", bevel=0.008)
    for x in (-0.12, 0.12):
        box((0.03, 0.02, 0.04), (x, -0.083, 0.135), "steel", bevel=0.004)
    cyl(0.012, 0.18, (0, 0, 0.2), "black_plastic", rot=(0, math.pi / 2, 0))
    for x in (-0.09, 0.09):
        box((0.012, 0.012, 0.05), (x, 0, 0.18), "steel", bevel=0.003)
    finish("repair_kit")


def crowbar():
    reset()
    cyl(0.02, 0.56, (0, 0, 0.28), "red_paint", rot=(0, math.radians(70), 0), verts=6, bevel=0.003)
    # the hook end, and the flattened claws
    cyl(0.02, 0.12, (0.3, 0, 0.14), "red_paint", rot=(0, math.radians(20), 0), verts=6, bevel=0.003)
    box((0.05, 0.022, 0.07), (0.33, 0, 0.2), "steel", bevel=0.004, rot=(0, math.radians(20), 0))
    box((0.07, 0.022, 0.04), (-0.28, 0, 0.38), "steel", bevel=0.004, rot=(0, math.radians(-20), 0))
    finish("crowbar")


def lockpick():
    reset()
    cyl(0.03, 0.2, (0, 0, 0.03), "leather", rot=(0, math.pi / 2, 0), bevel=0.004)
    box((0.2, 0.004, 0.06), (0, -0.03, 0.06), "leather", bevel=0.001)
    for i in range(5):
        x = -0.07 + i * 0.035
        cyl(0.0025, 0.12, (x, -0.005, 0.1), "brushed", rot=(0.12, 0, 0), verts=8)
        box((0.012, 0.004, 0.02), (x, -0.005, 0.045), "black_plastic", bevel=0.001)
    finish("lockpick")


def hand_drill():
    reset()
    box((0.2, 0.07, 0.09), (0, 0, 0.2), "yellow_paint", bevel=0.02)
    cyl(0.025, 0.14, (-0.03, 0, 0.11), "rubber", rot=(math.radians(-12), 0, 0), bevel=0.006)
    box((0.11, 0.08, 0.05), (-0.03, 0, 0.025), "black_plastic", bevel=0.01)
    cyl(0.025, 0.05, (0.12, 0, 0.2), "dark_steel", rot=(0, math.pi / 2, 0))
    cyl(0.005, 0.12, (0.2, 0, 0.2), "steel", rot=(0, math.pi / 2, 0), verts=12)
    box((0.02, 0.02, 0.025), (0.0, 0, 0.145), "red_paint", bevel=0.004)
    finish("hand_drill")


def binoculars():
    reset()
    for x in (-0.045, 0.045):
        cyl(0.032, 0.13, (x, 0, 0.065), "rubber", bevel=0.005)
        cyl(0.034, 0.012, (x, 0, 0.128), "dark_steel")
        cyl(0.028, 0.002, (x, 0, 0.135), "lens")
        cyl(0.02, 0.03, (x, 0, -0.005 + 0.012), "black_plastic")
    box((0.06, 0.03, 0.04), (0, 0, 0.09), "dark_steel", bevel=0.006)
    cyl(0.009, 0.03, (0, -0.018, 0.11), "dark_steel", rot=(math.pi / 2, 0, 0))
    finish("binoculars")


def scanner():
    reset()
    box((0.11, 0.035, 0.18), (0, 0, 0.09), "black_plastic", bevel=0.012)
    box((0.085, 0.004, 0.08), (0, -0.018, 0.12), "screen", bevel=0.002)
    for i in range(3):
        cyl(0.007, 0.006, (-0.03 + i * 0.03, -0.018, 0.045), "grey_paint", rot=(math.pi / 2, 0, 0))
    cyl(0.005, 0.1, (0.035, 0, 0.22), "dark_steel", verts=10)
    sphere(0.008, (0.035, 0, 0.27), "red_paint")
    finish("scanner")


def mask():
    reset()
    o = sphere(0.1, (0, 0, 0.13), "fabric", scale=(0.85, 0.9, 1.25), subsurf=1)
    for x in (-0.035, 0.035):  # eye holes
        sphere(0.022, (x, -0.075, 0.16), "black_plastic", scale=(1.3, 0.5, 0.8))
        sphere(0.017, (x, -0.078, 0.16), "bone", scale=(1.2, 0.3, 0.75))
    sphere(0.02, (0, -0.085, 0.08), "bone", scale=(1.4, 0.3, 0.6))
    finish("mask")


def armour_plate():
    reset()
    bpy.ops.mesh.primitive_cylinder_add(vertices=48, radius=0.5, depth=0.32, location=(0, 0.45, 0.17))
    o = bpy.context.object
    bm = bmesh.new(); bm.from_mesh(o.data)
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.y > -0.44], context="VERTS")
    bm.to_mesh(o.data); bm.free()
    s = o.modifiers.new("thick", "SOLIDIFY"); s.thickness = 0.025
    _finish_obj(o, "grey_paint", 0.004)
    box((0.04, 0.03, 0.34), (-0.12, -0.035, 0.17), "olive", bevel=0.004)
    box((0.04, 0.03, 0.34), (0.12, -0.035, 0.17), "olive", bevel=0.004)
    finish("armour_plate")


def vat_meat():
    reset()
    box((0.22, 0.15, 0.025), (0, 0, 0.0125), "white_plastic", bevel=0.006)
    box((0.18, 0.11, 0.035), (0, 0, 0.04), "meat_light", bevel=0.012, subsurf=1)
    box((0.205, 0.135, 0.002), (0, 0, 0.062), "glass", bevel=0.0)
    box((0.07, 0.003, 0.02), (0.05, -0.068, 0.02), "label", bevel=0.0)
    finish("vat_meat")


def fresh_meat():
    """A leg joint from the hutches: the meat a plump teardrop with a cap of
    fat, the shank bone out of the narrow end, its knuckle."""
    reset()
    random.seed(4)
    meat = sphere(0.075, (-0.02, 0, 0.065), "meat", scale=(1.45, 1.0, 0.85), subsurf=1)
    for v in meat.data.vertices:  # narrower towards the bone, a little uneven
        t = max(v.co.x + 0.02, 0.0) / 0.11
        v.co.y *= 1.0 - 0.45 * t
        v.co.z = 0.065 + (v.co.z - 0.065) * (1.0 - 0.4 * t)
        v.co *= 1.0 + random.uniform(-0.025, 0.025)
    sphere(0.05, (-0.075, 0.0, 0.1), "fat", scale=(0.9, 0.9, 0.3), subsurf=1)  # a patch of fat on top
    cyl(0.013, 0.1, (0.12, 0, 0.065), "bone", rot=(0, math.pi / 2, 0), verts=16)
    for dy in (-0.012, 0.012):
        sphere(0.018, (0.172, dy, 0.065), "bone")
    finish("fresh_meat")


def meal_pack():
    reset()
    box((0.15, 0.04, 0.2), (0, 0, 0.1), "olive", bevel=0.015, subsurf=1)
    box((0.152, 0.042, 0.02), (0, 0, 0.19), "khaki", bevel=0.003)
    box((0.09, 0.002, 0.06), (0, -0.021, 0.1), "label", bevel=0.0)
    finish("meal_pack")


def fresh_food():
    reset()
    random.seed(7)
    sphere(0.07, (0, 0, 0.06), "leaf_light", scale=(1, 1, 0.8))
    for i in range(9):
        a = i * 2 * math.pi / 9
        sphere(0.06, (math.cos(a) * 0.04, math.sin(a) * 0.04, 0.05 + random.uniform(0, 0.03)),
               "leaf" if i % 2 else "leaf_light", scale=(1.3, 0.35, 1.1), subsurf=1)
        bpy.context.object.rotation_euler = (random.uniform(-0.4, 0.4), 0, a)
    finish("fresh_food")


def algae_culture():
    reset()
    cyl(0.055, 0.16, (0, 0, 0.08), "glass", bevel=0.01)
    cyl(0.05, 0.12, (0, 0, 0.065), "algae", bevel=0.0)
    cyl(0.058, 0.025, (0, 0, 0.17), "brushed", bevel=0.004)
    finish("algae_culture")


def red_dust():
    reset()
    box((0.12, 0.05, 0.03), (0, 0, 0.015), "black_plastic", bevel=0.004)
    for i in range(3):
        x = -0.035 + i * 0.035
        cyl(0.011, 0.08, (x, 0, 0.06), "glass", bevel=0.003)
        cyl(0.0095, 0.045, (x, 0, 0.045), "red_powder", bevel=0.0)
        cyl(0.012, 0.012, (x, 0, 0.105), "black_plastic")
    finish("red_dust")


def rare_ore():
    reset()
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=3, radius=0.09, location=(0, 0, 0.07))
    o = bpy.context.object
    tex = bpy.data.textures.new("rough", "CLOUDS"); tex.noise_scale = 0.05
    d = o.modifiers.new("disp", "DISPLACE"); d.texture = tex; d.strength = 0.035
    o.scale = (1.2, 1.0, 0.8)
    bpy.ops.object.transform_apply(scale=True)
    _finish_obj(o, "rock", 0.0, smooth=False)
    random.seed(2)
    for i in range(7):
        a = random.uniform(0, 2 * math.pi)
        cyl(0.02, 0.1, (math.cos(a) * 0.045, math.sin(a) * 0.035, 0.15), "crystal",
            rot=(random.uniform(-0.7, 0.7), random.uniform(-0.7, 0.7), 0), verts=6, r2=0.004, bevel=0.0)
    finish("rare_ore")


def water_ice():
    reset()
    cyl(0.05, 0.22, (0, 0, 0.05), "ice", rot=(0, math.pi / 2, 0), bevel=0.006)
    cyl(0.051, 0.01, (-0.06, 0, 0.05), "white_plastic", rot=(0, math.pi / 2, 0))
    finish("water_ice")


def scrap():
    reset()
    bpy.ops.mesh.primitive_plane_add(size=0.25, location=(0, 0, 0.05))
    o = bpy.context.object
    bpy.ops.object.mode_set(mode="EDIT"); bpy.ops.mesh.subdivide(number_cuts=6); bpy.ops.object.mode_set(mode="OBJECT")
    random.seed(9)
    for v in o.data.vertices:
        v.co.z += 0.04 * math.sin(v.co.x * 18) + random.uniform(-0.01, 0.01)
    s = o.modifiers.new("thick", "SOLIDIFY"); s.thickness = 0.006
    _finish_obj(o, "grey_paint", 0.0)
    o.rotation_euler = (0.35, 0.1, 0.4)
    for p in [(-0.08, 0.06), (0.07, -0.05), (0.02, 0.09)]:
        cyl(0.008, 0.012, (p[0], p[1], 0.1), "dark_steel", verts=6)
    finish("scrap")


def refined_ingot():
    reset()
    bpy.ops.mesh.primitive_cube_add(size=1, location=(0, 0, 0.03))
    o = bpy.context.object
    o.scale = (0.2, 0.09, 0.06)
    bpy.ops.object.transform_apply(scale=True)
    for v in o.data.vertices:
        if v.co.z > 0.03:
            v.co.x *= 0.82
            v.co.y *= 0.75
    _finish_obj(o, "brushed", 0.006)
    finish("refined_ingot")


def supply_crate():
    reset()
    box((0.4, 0.3, 0.3), (0, 0, 0.15), "olive", bevel=0.012)
    for x in (-0.18, 0.18):
        box((0.03, 0.31, 0.31), (x, 0, 0.15), "dark_steel", bevel=0.006)
    box((0.41, 0.31, 0.03), (0, 0, 0.28), "dark_steel", bevel=0.006)
    box((0.16, 0.003, 0.05), (0, -0.152, 0.15), "yellow_paint", bevel=0.0)
    finish("supply_crate")


def case(name, body):
    reset()
    box((0.42, 0.13, 0.3), (0, 0, 0.15), body, bevel=0.025)
    box((0.425, 0.135, 0.015), (0, 0, 0.15), "dark_steel", bevel=0.004)
    for x in (-0.12, 0.12):
        box((0.04, 0.02, 0.05), (x, -0.07, 0.2), "steel", bevel=0.005)
    torus(0.05, 0.01, (0, 0, 0.32), "black_plastic", rot=(math.pi / 2, 0, 0))
    finish(name)


def cargo_case():
    case("cargo_case", "grey_paint")


def stolen_cargo():
    case("stolen_cargo", "orange_paint")


def vault_relic():
    reset()
    cyl(0.07, 0.03, (0, 0, 0.015), "dark_steel", bevel=0.005)
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=0.07, location=(0, 0, 0.12))
    o = bpy.context.object
    o.scale = (0.7, 0.7, 1.3)
    bpy.ops.object.transform_apply(scale=True)
    _finish_obj(o, "gold", 0.004, smooth=False)
    sphere(0.03, (0, 0, 0.12), "glow")
    for a in range(3):
        torus(0.08, 0.004, (0, 0, 0.12), "brass", rot=(math.pi / 2, 0, a * math.pi / 3))
    finish("vault_relic")


def bounty_proof():
    reset()
    for i, dx in enumerate((-0.02, 0.02)):
        box((0.05, 0.003, 0.08), (dx, -0.002 * i, 0.06 + i * 0.01), "brushed", bevel=0.008, rot=(0, 0, 0.1 * i))
    torus(0.07, 0.002, (0, 0, 0.13), "steel", rot=(math.pi / 2, 0, 0))
    finish("bounty_proof")


def parcel():
    reset()
    box((0.25, 0.2, 0.15), (0, 0, 0.075), "cardboard", bevel=0.004)
    box((0.255, 0.05, 0.152), (0, 0, 0.075), "tape", bevel=0.0)
    box((0.05, 0.205, 0.152), (0, 0, 0.075), "tape", bevel=0.0)
    box((0.08, 0.002, 0.05), (0.07, -0.101, 0.08), "label", bevel=0.0)
    finish("parcel")


def cred_chip():
    reset()
    for i in range(5):
        cyl(0.03, 0.007, (0.004 * (i % 2), 0, 0.004 + i * 0.0075), "gold", bevel=0.001)
        cyl(0.031, 0.003, (0.004 * (i % 2), 0, 0.004 + i * 0.0075), "green_edge", bevel=0.0)
    cyl(0.03, 0.007, (0.07, 0.01, 0.0035), "gold", rot=(0, 0.2, 0), bevel=0.001)
    finish("cred_chip")


def plating():
    armour_plate()
    os.replace(os.path.join(OUT, "armour_plate.glb"), os.path.join(OUT, "plating.glb"))
    armour_plate()


def ammo():
    reset()
    box((0.36, 0.03, 0.05), (0, 0, 0.12), "olive", bevel=0.006)
    for i in range(4):
        box((0.065, 0.05, 0.09), (-0.12 + i * 0.08, -0.03, 0.09), "olive", bevel=0.012)
        box((0.067, 0.052, 0.025), (-0.12 + i * 0.08, -0.03, 0.13), "khaki", bevel=0.006)
    finish("ammo")


def torch():
    reset()
    cyl(0.022, 0.2, (0, 0, 0.1), "black_plastic", bevel=0.004)
    cyl(0.034, 0.06, (0, 0, 0.22), "dark_steel", r2=0.024, bevel=0.003)
    cyl(0.03, 0.004, (0, 0, 0.252), "screen")
    box((0.012, 0.012, 0.03), (0, 0.022, 0.12), "red_paint", bevel=0.002)
    for z in (0.04, 0.06, 0.08):
        cyl(0.0225, 0.006, (0, 0, z), "rubber", bevel=0.0)
    finish("torch")


def jetpack():
    reset()
    box((0.28, 0.12, 0.32), (0, 0, 0.3), "grey_paint", bevel=0.03)
    for x in (-0.09, 0.09):
        cyl(0.06, 0.34, (x, 0.08, 0.32), "white_plastic", bevel=0.01)
        cyl(0.045, 0.08, (x, 0.08, 0.11), "dark_steel", r2=0.065, bevel=0.004)
        cyl(0.04, 0.02, (x, 0.08, 0.06), "copper", bevel=0.0)
    for x in (-0.11, 0.11):
        box((0.04, 0.02, 0.36), (x, -0.07, 0.32), "black_plastic", bevel=0.006)
    box((0.1, 0.02, 0.06), (0, -0.065, 0.4), "screen", bevel=0.004)
    finish("jetpack")


for build in (torch, jetpack, oxygen_canister, helium3, fuel_cell, water_ration, stim_cola, medkit, repair_kit, crowbar, lockpick,
              hand_drill, binoculars, scanner, mask, plating, vat_meat, fresh_meat, meal_pack, fresh_food,
              algae_culture, red_dust, rare_ore, water_ice, scrap, refined_ingot, supply_crate, cargo_case,
              stolen_cargo, vault_relic, bounty_proof, parcel, cred_chip, ammo):
    build()
