# THE HUNT: the Mars outpost structure kit, built in Blender from code.
#   blender -b -P tools/blender/build_outpost_kit.py -- <out_dir>
# Each piece is exported as its own .glb (Y-up, metres, origin at the floor
# centre). Materials are flat named colours (hull, rust, trim, glass, dark,
# light); the game replaces them by name with its cel material and ink
# outline (Comic.kit_material). Low poly by design: the comic shading and
# outlines carry the look, not geometry.
import bpy, bmesh, math, sys, os
from mathutils import Vector, Matrix

OUT = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "/tmp/kit"
os.makedirs(OUT, exist_ok=True)
# finish() exports into OUT; a script importing these helpers shares it.

COLORS = {
    "hull": (0.62, 0.56, 0.5, 1), "rust": (0.55, 0.22, 0.12, 1), "trim": (1.0, 0.75, 0.15, 1),
    "glass": (0.25, 0.85, 0.95, 1), "dark": (0.12, 0.1, 0.12, 1), "light": (0.95, 0.85, 0.6, 1),
    "magenta": (0.95, 0.15, 0.45, 1),
    "blue": (0.12, 0.3, 0.92, 1), "red": (0.95, 0.1, 0.1, 1), "white": (0.93, 0.94, 0.96, 1),
    "navy": (0.08, 0.12, 0.28, 1),
}


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    for name, rgba in COLORS.items():
        m = bpy.data.materials.new(name)
        m.use_nodes = True
        m.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = rgba
        m.diffuse_color = rgba


def mat(obj, name):
    obj.data.materials.append(bpy.data.materials[name])


def box(name, size, loc, material, rot_z=0.0):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc, rotation=(0, 0, rot_z))
    o = bpy.context.object
    o.name = name
    o.scale = size
    mat(o, material)
    return o


def cyl(name, r, h, loc, material, verts=12, rot=(0, 0, 0), cap=True):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=h, location=loc, rotation=rot,
                                        end_fill_type="NGON" if cap else "NOTHING")
    o = bpy.context.object
    o.name = name
    mat(o, material)
    return o


def dome(name, r, h, loc, material, verts=12, rings=4):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=verts, ring_count=rings * 2, radius=r, location=loc)
    o = bpy.context.object
    o.name = name
    bm = bmesh.new()
    bm.from_mesh(o.data)
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.z < -1e-4], context="VERTS")
    for v in bm.verts:
        v.co.z *= h / r
    bm.to_mesh(o.data)
    bm.free()
    mat(o, material)
    return o


def finish(piece):
    """Join everything, apply transforms, flat shading, export."""
    bpy.ops.object.select_all(action="SELECT")
    bpy.context.view_layer.objects.active = bpy.context.selected_objects[0]
    bpy.ops.object.join()
    o = bpy.context.object
    o.name = piece
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    for p in o.data.polygons:
        p.use_smooth = False
    tris = sum(len(p.vertices) - 2 for p in o.data.polygons)
    path = os.path.join(globals()["OUT"], piece + ".glb")
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", export_yup=True, export_apply=True,
                              export_materials="EXPORT", export_normals=True)
    print("KIT %s: %d tris -> %s" % (piece, tris, path))


def hab_dome():
    reset()
    r = 6.0
    cyl("wall", r, 3.2, (0, 0, 1.6), "hull", verts=12)
    # Ribs around the wall and a dark band of windows.
    for i in range(12):
        a = i * math.tau / 12
        box("rib%d" % i, (0.35, 0.35, 3.4), (math.cos(a) * r, math.sin(a) * r, 1.7), "dark", rot_z=a)
    cyl("windows", r + 0.04, 0.6, (0, 0, 2.2), "glass", verts=12, cap=False)
    dome("roof", r * 0.98, 2.4, (0, 0, 3.2), "hull", verts=12, rings=3)
    cyl("roof_band", r + 0.08, 0.3, (0, 0, 3.25), "trim", verts=12, cap=False)
    # Airlock: a boxy porch on +X with a lit door.
    box("airlock", (2.4, 2.6, 2.8), (r + 0.9, 0, 1.4), "hull")
    box("door", (0.1, 1.4, 2.2), (r + 2.12, 0, 1.1), "light")
    box("door_frame", (0.2, 1.9, 0.25), (r + 2.15, 0, 2.35), "trim")
    cyl("vent", 0.5, 1.2, (-2.0, 1.5, 6.0), "dark", verts=8)
    finish("hab_dome")


def tank_cluster():
    reset()
    box("base", (8.0, 4.5, 0.4), (0, 0, 0.2), "dark")
    for i, x in enumerate((-2.6, 0.0, 2.6)):
        cyl("tank%d" % i, 1.15, 5.5, (x, 0, 3.15), "hull" if i != 1 else "rust", verts=12)
        dome("cap%d" % i, 1.15, 0.6, (x, 0, 5.9), "hull", verts=12, rings=2)
        cyl("band%d" % i, 1.2, 0.25, (x, 0, 4.4), "trim", verts=12, cap=False)
    cyl("pipe", 0.22, 7.6, (0, -1.6, 1.2), "dark", verts=8, rot=(0, math.pi / 2, 0))
    finish("tank_cluster")


def pipe_run():
    reset()
    cyl("pipe", 0.45, 8.0, (0, 0, 1.6), "hull", verts=10, rot=(0, math.pi / 2, 0))
    for x in (-3.0, 3.0):
        box("leg%d" % x, (0.25, 1.2, 1.2), (x, 0, 0.6), "dark")
        cyl("collar%d" % x, 0.52, 0.3, (x, 0, 1.6), "trim", verts=10, rot=(0, math.pi / 2, 0))
    finish("pipe_run")


def comms_tower():
    reset()
    h = 16.0
    for x in (-0.8, 0.8):
        for y in (-0.8, 0.8):
            box("post", (0.18, 0.18, h), (x, y, h / 2), "dark")
    for z in range(2, int(h), 3):
        box("ring%d" % z, (1.8, 1.8, 0.14), (0, 0, z), "rust")
    cyl("dish_arm", 0.12, 2.0, (0, -1.2, h - 1.5), "dark", verts=6, rot=(math.pi / 2, 0, 0))
    dome("dish", 1.4, 0.5, (0, -2.4, h - 1.5), "hull", verts=12, rings=2)
    bpy.context.object.rotation_euler = (-math.pi / 2, 0, 0)
    box("beacon", (0.4, 0.4, 0.5), (0, 0, h + 0.25), "magenta")
    finish("comms_tower")


def hangar():
    reset()
    w, d = 14.0, 10.0
    # A half-cylinder of corrugated panels (ribs every 2 m) on a plinth.
    bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=d / 2, depth=w, location=(0, 0, 0.4),
                                        rotation=(0, math.pi / 2, 0))
    o = bpy.context.object
    bm = bmesh.new()
    bm.from_mesh(o.data)
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.x > 1e-4], context="VERTS")  # local X = world Z
    bm.to_mesh(o.data)
    bm.free()
    mat(o, "rust")
    for i in range(8):
        x = -w / 2 + i * w / 7
        bpy.ops.mesh.primitive_torus_add(major_radius=d / 2 + 0.1, minor_radius=0.15, major_segments=16,
                                         minor_segments=4, location=(x, 0, 0.4), rotation=(0, math.pi / 2, 0))
        t = bpy.context.object
        bm = bmesh.new()
        bm.from_mesh(t.data)
        bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.x > 0.2], context="VERTS")
        bm.to_mesh(t.data)
        bm.free()
        mat(t, "dark")
    box("plinth", (w + 0.6, d + 0.6, 0.4), (0, 0, 0.2), "dark")
    box("door", (0.15, 5.0, 4.0), (w / 2 + 0.05, 0, 2.4), "trim")
    box("door_stripe", (0.18, 5.2, 0.4), (w / 2 + 0.07, 0, 4.6), "dark")
    finish("hangar")


def gate_arch():
    reset()
    for y in (-7.0, 7.0):
        box("tower", (3.0, 3.0, 11.0), (0, y, 5.5), "hull")
        box("tower_cap", (3.6, 3.6, 0.8), (0, y, 11.4), "dark")
        box("tower_band", (3.1, 3.1, 0.5), (0, y, 8.5), "trim")
        box("light", (0.2, 1.6, 1.6), (1.55, y, 9.8), "glass")
    box("beam", (2.4, 17.0, 2.0), (0, 0, 10.0), "dark")
    box("sign", (0.3, 11.0, 2.6), (1.3, 0, 10.0), "magenta")
    box("sign_trim", (0.35, 11.4, 0.3), (1.32, 0, 11.4), "trim")
    finish("gate_arch")


if __name__ == "__main__":
    for build in (hab_dome, tank_cluster, pipe_run, comms_tower, hangar, gate_arch):
        build()
