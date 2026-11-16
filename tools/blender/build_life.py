# THE HUNT: life on Mars, built in Blender from code (same conventions as
# build_outpost_kit.py). Vegetation is wealth: the city's dome holds trees
# and lawns; the frontier keeps one sickly greenhouse; the underground farm
# grows under lights. Plus walk-in buildings, the drill rig and the lift.
#   blender -b -P tools/blender/build_life.py -- <out_dir>
import bpy, bmesh, math, sys, os
sys.path.insert(0, os.path.dirname(__file__))
import build_outpost_kit as K  # noqa: E402
from build_outpost_kit import reset, box, cyl, dome, finish  # noqa: E402

K.OUT = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "/tmp/life"
os.makedirs(K.OUT, exist_ok=True)
GREENS = {"leaf": (0.18, 0.55, 0.16, 1), "leaf_dark": (0.08, 0.32, 0.12, 1), "bark": (0.32, 0.2, 0.12, 1),
          "leaf_sick": (0.55, 0.52, 0.18, 1), "soil": (0.22, 0.13, 0.08, 1)}


def colours():
    for name, rgba in GREENS.items():
        if name not in bpy.data.materials:
            m = bpy.data.materials.new(name)
            m.use_nodes = True
            m.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = rgba
            m.diffuse_color = rgba


def blob(name, r, loc, mat, subdiv=1, squash=1.0):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=subdiv, radius=r, location=loc)
    o = bpy.context.object
    o.name = name
    o.scale = (1, 1, squash)
    K.mat(o, mat)
    return o


def tree():
    reset(); colours()
    cyl("trunk", 0.22, 3.2, (0, 0, 1.6), "bark", verts=7)
    blob("crown", 1.7, (0, 0, 3.9), "leaf", squash=0.85)
    blob("crown2", 1.2, (0.9, 0.4, 3.3), "leaf_dark", squash=0.9)
    blob("crown3", 1.0, (-0.8, -0.5, 4.6), "leaf")
    finish("tree")


def shrub():
    reset(); colours()
    blob("a", 0.7, (0, 0, 0.5), "leaf_dark", squash=0.7)
    blob("b", 0.5, (0.6, 0.2, 0.4), "leaf", squash=0.8)
    finish("shrub")


def bench():
    reset()
    box("seat", (1.8, 0.5, 0.08), (0, 0, 0.45), "rust")
    box("back", (1.8, 0.06, 0.4), (0, 0.24, 0.75), "rust")
    for x in (-0.8, 0.8):
        box("leg", (0.08, 0.5, 0.45), (x, 0, 0.22), "dark")
    finish("bench")


def greenhouse():
    """The Hollow's one greenhouse: a glass hoop over two beds, half the
    plants yellowing."""
    reset(); colours()
    box("base", (6.0, 3.6, 0.3), (0, 0, 0.15), "dark")
    bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=1.8, depth=6.0, location=(0, 0, 0.3), rotation=(0, math.pi / 2, 0))
    o = bpy.context.object
    bm = bmesh.new(); bm.from_mesh(o.data)
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.x > 1e-4], context="VERTS")
    bm.to_mesh(o.data); bm.free()
    K.mat(o, "glass")
    for y in (-0.8, 0.8):
        box("bed", (5.4, 0.9, 0.4), (0, y, 0.5), "soil")
        for i in range(6):
            blob("plant", 0.28, (-2.3 + i * 0.9, y, 0.85), "leaf_sick" if (i + int(y > 0)) % 2 else "leaf")
    for x in (-3.0, 3.0):
        box("end", (0.1, 3.6, 2.0), (x, 0, 1.2), "hull")
    # Its ends closed: glass gables with a framed door at each, so it holds
    # its air.
    for x in (-3.0, 3.0):
        bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=1.8, depth=0.08, location=(x, 0, 0.3),
                                            rotation=(0, math.pi / 2, 0))
        g = bpy.context.object
        bm = bmesh.new(); bm.from_mesh(g.data)
        bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.x > 1e-4], context="VERTS")
        bm.to_mesh(g.data); bm.free()
        K.mat(g, "glass")
        box("door", (0.1, 0.9, 1.6), (x * 1.01, 0, 1.1), "dark")
        box("door_top", (0.12, 1.1, 0.12), (x * 1.01, 0, 1.95), "trim")
        for y in (-0.5, 0.5):
            box("door_post", (0.12, 0.1, 1.7), (x * 1.01, y, 1.15), "trim")
    finish("greenhouse")


def city_dome():
    """Tharsis Gate's pressure dome: a geodesic frame (glass is the game's
    transparent material on a sphere)."""
    reset()
    r = 74.0
    for i in range(16):
        a = i * math.tau / 16
        for k in range(6):
            t0, t1 = k / 6 * math.pi / 2, (k + 1) / 6 * math.pi / 2
            p0 = (r * math.cos(t0) * math.cos(a), r * math.cos(t0) * math.sin(a), r * math.sin(t0) * 0.55)
            p1 = (r * math.cos(t1) * math.cos(a), r * math.cos(t1) * math.sin(a), r * math.sin(t1) * 0.55)
            mid = [(p0[j] + p1[j]) / 2 for j in range(3)]
            d = [p1[j] - p0[j] for j in range(3)]
            length = math.sqrt(sum(c * c for c in d))
            bpy.ops.mesh.primitive_cube_add(size=1, location=mid)
            o = bpy.context.object
            o.scale = (0.5, 0.5, length)
            o.rotation_mode = "QUATERNION"
            from mathutils import Vector
            o.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(Vector(d).normalized())
            K.mat(o, "dark")
    for k in range(1, 6):
        t = k / 6 * math.pi / 2
        bpy.ops.mesh.primitive_torus_add(major_radius=r * math.cos(t), minor_radius=0.3, major_segments=48, minor_segments=4,
                                         location=(0, 0, r * math.sin(t) * 0.55))
        K.mat(bpy.context.object, "dark")
    bpy.ops.mesh.primitive_torus_add(major_radius=r, minor_radius=0.9, major_segments=48, minor_segments=4, location=(0, 0, 0.5))
    K.mat(bpy.context.object, "trim")
    finish("city_dome")


def mining_rig():
    """A drill rig over an ore seam: frame, drill string, motor housing, a
    conveyor out to a hopper."""
    reset()
    box("pad", (6.0, 6.0, 0.4), (0, 0, 0.2), "dark")
    for x in (-2.2, 2.2):
        for y in (-2.2, 2.2):
            box("leg", (0.3, 0.3, 9.0), (x, y, 4.7), "trim")
    box("crown", (5.0, 5.0, 0.5), (0, 0, 9.3), "rust")
    # The drill string and its motor turn: CityMode builds them (animated).
    box("conveyor", (7.0, 0.8, 0.3), (5.5, 0, 1.6), "rust", rot_z=0.0)
    box("hopper", (2.2, 2.2, 2.2), (9.6, 0, 1.3), "hull")
    box("ore", (1.8, 1.8, 0.4), (9.6, 0, 2.5), "magenta")
    box("panel", (0.8, 0.3, 1.4), (-3.2, -1.0, 0.9), "dark")
    box("screen", (0.6, 0.05, 0.4), (-3.2, -1.17, 1.3), "glass")
    finish("mining_rig")


def lift_head():
    """The lift down to Deep Furrow, the underground farm: a pressurised
    lift house with a lit door, at the foot of the Anvil mesa."""
    reset()
    box("house", (5.0, 5.0, 4.6), (0, 0, 2.3), "hull")
    box("roof", (5.6, 5.6, 0.4), (0, 0, 4.8), "dark")
    box("door", (2.2, 0.12, 2.8), (0, -2.52, 1.4), "light")
    box("frame", (2.8, 0.15, 0.3), (0, -2.55, 2.95), "trim")
    box("sign", (3.6, 0.15, 0.7), (0, -2.56, 3.8), "magenta")
    box("cable_tower", (1.2, 1.2, 3.5), (1.2, 1.2, 6.6), "dark")
    finish("lift_head")


def farm_hall():
    """Deep Furrow, under the Anvil: a long rock hall (open at one end, the
    lift), hydroponic beds of green under grow-light bars."""
    reset(); colours()
    L, W, H = 60.0, 22.0, 9.0
    box("floor", (W, L, 0.5), (0, 0, -0.25), "dark")
    box("ceiling", (W, L, 0.8), (0, 0, H), "rust")
    for x in (-W / 2, W / 2):
        box("wall", (0.8, L, H), (x, 0, H / 2), "rust")
    box("back", (W, 0.8, H), (0, L / 2, H / 2), "rust")
    box("front_l", (8.0, 0.8, H), (-7.0, -L / 2, H / 2), "rust")
    box("front_r", (8.0, 0.8, H), (7.0, -L / 2, H / 2), "rust")
    box("lift", (5.0, 4.0, 4.6), (0, -L / 2 - 2.0, 2.3), "hull")
    for row in range(4):
        x = -7.5 + row * 5.0
        box("bed", (2.2, L - 14, 0.6), (x, 3, 0.5), "soil")
        for k in range(14):
            blob("crop", 0.45, (x + (0.4 if k % 2 else -0.4), -20 + k * 3.4, 1.05), "leaf" if k % 3 else "leaf_dark",
                 squash=0.8)
        box("lightbar", (0.4, L - 14, 0.15), (x, 3, 6.4), "magenta")
    for y in (-26.0, 26.0):
        box("pipe", (W, 0.4, 0.4), (0, y, 7.6), "trim")
    finish("farm_hall")


def factory():
    """Kasei Motors: a long assembly hall with a sawtooth roof of glass,
    a wide bay door to the road (front), a strip of windows, a deep slab
    under it. Inside: the line's floor channel, parts racks along the walls,
    a showroom bay by the door. The robot arms and the rovers on the line
    are added (and animated) by the game."""
    reset(); colours()
    W, L, H = 26.0, 44.0, 11.0
    box("slab", (W + 2, L + 2, 3.0), (0, 0, -1.4), "dark")
    box("floor", (W, L, 0.2), (0, 0, 0.1), "trim")
    box("back", (W, 0.8, H), (0, L / 2, H / 2), "hull")
    for x in (-W / 2, W / 2):
        box("side", (0.8, L, H), (x, 0, H / 2), "hull")
        box("windows", (0.85, L - 6, 1.6), (x, 0, H - 2.6), "glass")
        box("stripe", (0.86, L, 0.5), (x, 0, 2.2), "magenta")
    # The front: a 12 m bay door, wall either side, a lintel, the sign.
    for x in (-9.5, 9.5):
        box("front", (7.0, 0.8, H), (x, -L / 2, H / 2), "hull")
    box("lintel", (12.0, 0.8, H - 8.0), (0, -L / 2, 8.0 + (H - 8.0) / 2), "hull")
    box("door_frame", (12.6, 1.0, 0.4), (0, -L / 2 - 0.1, 8.0), "trim")
    box("sign", (14.0, 0.4, 1.8), (0, -L / 2 - 0.5, H + 1.2), "magenta")
    box("sign_back", (14.4, 0.3, 2.2), (0, -L / 2 - 0.25, H + 1.2), "dark")
    # Sawtooth roof: slopes of panel, steep faces of glass to the north light.
    teeth = 6
    for i in range(teeth):
        y = -L / 2 + (i + 0.5) * L / teeth
        o = box("roof", (W, L / teeth * 1.05, 0.3), (0, y, H + 1.1), "rust")
        o.rotation_euler = (math.radians(-20), 0, 0)
        g = box("roof_glass", (W, 0.15, 2.3), (0, y + L / teeth * 0.48, H + 1.1), "glass")
    # Inside: the line's channel, racks, the showroom bay.
    box("line_channel", (4.0, L - 12, 0.25), (0, 2.0, 0.25), "dark")
    for y in range(-14, 22, 6):
        for x in (-W / 2 + 1.5, W / 2 - 1.5):
            box("rack", (1.6, 4.0, 4.5), (x, y, 2.45), "dark")
            for z in (1.4, 2.8, 4.2):
                box("parts", (1.4, 3.6, 0.6), (x, y, z), "trim" if (y // 6) % 2 else "rust")
    box("showroom", (8.0, 7.0, 0.3), (8.0, -L / 2 + 5.0, 0.35), "glass")
    box("showroom_edge", (8.2, 7.2, 0.15), (8.0, -L / 2 + 5.0, 0.2), "magenta")
    for x in (-W / 2 + 3, W / 2 - 3):
        box("light", (1.6, L - 4, 0.25), (x, 0, H - 0.5), "light")
    finish("factory")


def hab_open():
    """A walk-in habitat: a 10 m dome with its airlock open, two bunks, a
    table and lockers inside."""
    reset()
    r = 6.0
    bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=r, depth=3.2, location=(0, 0, 1.6), end_fill_type="NOTHING")
    o = bpy.context.object
    bm = bmesh.new(); bm.from_mesh(o.data)
    # The door gap: remove the wall faces facing -Y (the front).
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.calc_center_median().y < -r * 0.93], context="FACES")
    bm.to_mesh(o.data); bm.free()
    K.mat(o, "hull")
    dome("roof", r * 0.98, 2.4, (0, 0, 3.2), "hull", verts=16, rings=3)
    # The inside lining (faces turned inward): pale walls and ceiling, so
    # the room reads as a lit interior, not the outline's ink shell.
    bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=r - 0.18, depth=3.2, location=(0, 0, 1.6), end_fill_type="NOTHING")
    o = bpy.context.object
    bm = bmesh.new(); bm.from_mesh(o.data)
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.calc_center_median().y < -(r - 0.18) * 0.93], context="FACES")
    bmesh.ops.reverse_faces(bm, faces=bm.faces[:])
    bm.to_mesh(o.data); bm.free()
    K.mat(o, "light")
    inner = dome("ceiling", (r - 0.2) * 0.98, 2.2, (0, 0, 3.2), "light", verts=16, rings=3)
    bm = bmesh.new(); bm.from_mesh(inner.data)
    bmesh.ops.reverse_faces(bm, faces=bm.faces[:])
    bm.to_mesh(inner.data); bm.free()
    box("floor", (11.5, 11.5, 0.1), (0, 0, 0.05), "dark")
    for x in (-3.4, 3.4):
        box("bunk", (1.0, 2.2, 0.5), (x, 2.0, 0.45), "rust")
        box("mattress", (0.9, 2.0, 0.15), (x, 2.0, 0.78), "light")
    box("table", (1.6, 1.0, 0.08), (0, 1.0, 0.85), "trim")
    box("table_leg", (0.15, 0.15, 0.8), (0, 1.0, 0.4), "dark")
    for x in (-2.0, -1.0):
        box("locker", (0.8, 0.6, 2.0), (x, 4.6, 1.0), "dark")
    box("lamp", (1.4, 0.3, 0.1), (0, 0, 3.1), "light")
    finish("hab_open")


for build in (tree, shrub, bench, greenhouse, city_dome, mining_rig, lift_head, farm_hall, hab_open, factory):
    build()
