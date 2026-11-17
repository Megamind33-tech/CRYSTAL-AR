# THE HUNT: Kasei Valley, built in Blender from code.
#   blender -b -P tools/blender/build_world.py -- <out_dir>
# freighter_wreck.glb: the crashed hauler landmark; the rovers, buggy and
# hauler; the factions' gear. (The ground itself is built in Godot at load
# from WorldTerrain: maps/world/terrain_mesh.gd.)
import bpy, math, sys, os
sys.path.insert(0, os.path.dirname(__file__))
from build_outpost_kit import reset, box, cyl, finish  # noqa: E402
import build_outpost_kit as K  # noqa: E402

OUT = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "/tmp/world"
os.makedirs(OUT, exist_ok=True)
K.OUT = OUT

def freighter_wreck():
    reset()
    # A long hauler nose-down in the dust, broken behind the cockpit.
    cyl("hull_a", 3.2, 22.0, (0, -6, 3.4), "hull", verts=10, rot=(math.radians(84), 0, 0))
    cyl("hull_b", 3.2, 14.0, (1.5, 13, 2.2), "rust", verts=10, rot=(math.radians(100), 0, math.radians(14)))
    bpy.ops.mesh.primitive_cone_add(vertices=10, radius1=3.2, radius2=0.8, depth=6.0, location=(0, -20, 4.4),
                                    rotation=(math.radians(84), 0, 0))
    o = bpy.context.object
    K.mat(o, "hull")
    box("cockpit", (2.4, 3.0, 1.2), (0, -18.5, 6.6), "glass")
    for x in (-4.2, 4.2):
        box("fin", (3.5, 6.0, 0.4), (x, -2, 2.6), "dark", rot_z=0.0)
        cyl("pod", 1.1, 6.0, (x * 1.15, 3, 2.0), "dark", verts=8, rot=(math.radians(90), 0, 0))
    box("stripe", (6.6, 1.2, 0.3), (0, -10, 6.1), "trim")
    box("debris1", (2.0, 1.4, 1.0), (6, 8, 0.5), "rust", rot_z=0.6)
    box("debris2", (1.4, 2.6, 0.8), (-5.5, 16, 0.4), "hull", rot_z=-0.4)
    finish("freighter_wreck")


# --- Vehicles: comic colours, real shapes (bevelled panels, tyres with
# tread, framed glass, lights). Bevels are applied per part before joining.

def rbox(name, size, loc, mat, bevel=0.06, rot=(0, 0, 0), taper=None):
    """A box with rounded edges; `taper` (x, y) scales its top face."""
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc, rotation=rot)
    o = bpy.context.object
    o.name = name
    o.scale = size
    bpy.ops.object.transform_apply(scale=True)
    if taper is not None:
        for v in o.data.vertices:
            if v.co.z > 0:
                v.co.x *= taper[0]
                v.co.y = v.co.y * taper[1] + (1 - taper[1]) * size[1] * -0.5 * 0.0
    if bevel > 0:
        m = o.modifiers.new("bevel", "BEVEL")
        m.width = bevel
        m.segments = 1
        m.limit_method = "ANGLE"
        bpy.ops.object.modifier_apply(modifier="bevel")
    K.mat(o, mat)
    return o


# Vehicles export their wheels separately (<model>_wheel_l/_r.glb, hub at
# the origin) so the game can spin and steer them: wheel() records where
# each goes instead of building it into the body.
SPLIT_WHEELS = None


def wheel(x, y, r, w, hub="trim"):
    """A tyre with tread blocks round it, a rim and a hub cap; axis along X."""
    if SPLIT_WHEELS is not None and SPLIT_WHEELS != "build":
        SPLIT_WHEELS.append((x, y, r, w, hub))
        return
    bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=r, depth=w, location=(x, y, r), rotation=(0, math.pi / 2, 0))
    o = bpy.context.object
    m = o.modifiers.new("bevel", "BEVEL"); m.width = r * 0.12; m.segments = 1
    bpy.ops.object.modifier_apply(modifier="bevel")
    K.mat(o, "dark")
    for i in range(8):  # tread
        a = i * 2 * math.pi / 8
        rbox("tread", (w * 0.96, r * 0.24, r * 0.1), (x, y + math.cos(a) * r * 0.99, r + math.sin(a) * r * 0.99), "dark",
             bevel=0.0, rot=(-a, 0, 0))
    side = 1 if x > 0 else -1
    cyl("rim", r * 0.62, w * 0.2, (x + side * w * 0.42, y, r), "white", verts=12, rot=(0, math.pi / 2, 0))
    cyl("hub", r * 0.25, w * 0.24, (x + side * w * 0.46, y, r), hub, verts=8, rot=(0, math.pi / 2, 0))
    for k in range(5):  # spokes on the rim, so you see it turn
        a = k * 2 * math.pi / 5
        rbox("spoke", (w * 0.06, r * 0.1, r * 0.5), (x + side * w * 0.53, y + math.cos(a) * r * 0.3, r + math.sin(a) * r * 0.3),
             "dark", bevel=0.0, rot=(-a + math.pi / 2, 0, 0))


def arch(x, y, r, w):
    """A wheel arch (a half ring of body panel over the tyre)."""
    bpy.ops.mesh.primitive_cylinder_add(vertices=20, radius=r * 1.18, depth=w, location=(x, y, r),
                                        rotation=(0, math.pi / 2, 0))
    o = bpy.context.object
    bm = bmesh.new(); bm.from_mesh(o.data)
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.y < r * 0.15 and False or (v.co.x < 0.0 and abs(v.co.x) > 1e-4)],
                     context="VERTS")
    bm.to_mesh(o.data); bm.free()
    K.mat(o, "hull")


def lights(y, z, xs, front=True):
    for x in xs:
        rbox("lamp", (0.34, 0.08, 0.2), (x, y, z), "light" if front else "red", bevel=0.03)


def rover():
    """The six-wheeled colony rover: a rounded cab with a raked windscreen,
    a ribbed cargo bed, wheel arches, a roof rack and lamps. Front +Y in
    Blender (Godot -Z). About 4.8 m long."""
    reset()
    rbox("chassis", (2.2, 4.6, 0.45), (0, 0, 0.95), "dark", bevel=0.08)
    rbox("sill", (2.35, 3.8, 0.25), (0, 0.1, 1.2), "rust", bevel=0.06)
    rbox("cab", (2.15, 2.0, 1.15), (0, 0.95, 1.85), "hull", bevel=0.18, taper=(0.9, 0.82))
    rbox("windscreen", (1.8, 0.1, 0.62), (0, 1.9, 2.0), "glass", bevel=0.04, rot=(math.radians(-28), 0, 0))
    rbox("screen_frame", (1.95, 0.14, 0.08), (0, 1.98, 2.36), "dark", bevel=0.02, rot=(math.radians(-28), 0, 0))
    for x in (-1.08, 1.08):
        rbox("side_window", (0.06, 1.1, 0.5), (x * 0.98, 0.95, 2.05), "glass", bevel=0.03)
        rbox("mirror", (0.12, 0.08, 0.16), (x * 1.12, 1.6, 1.95), "dark", bevel=0.02)
    rbox("hood", (2.1, 0.8, 0.45), (0, 2.15, 1.35), "hull", bevel=0.12)
    rbox("grille", (1.3, 0.06, 0.3), (0, 2.56, 1.3), "dark", bevel=0.02)
    for z in (1.22, 1.32, 1.42):
        rbox("slat", (1.2, 0.07, 0.03), (0, 2.6, z), "trim", bevel=0.0)
    lights(2.57, 1.45, (-0.8, 0.8))
    rbox("bumper", (2.4, 0.3, 0.28), (0, 2.65, 0.95), "trim", bevel=0.08)
    rbox("bed", (2.15, 2.0, 0.75), (0, -1.25, 1.55), "rust", bevel=0.08)
    for y in (-2.0, -1.5, -1.0, -0.5):
        for x in (-1.09, 1.09):
            rbox("rib", (0.05, 0.12, 0.7), (x, y, 1.55), "dark", bevel=0.0)
    rbox("tailgate", (2.1, 0.08, 0.7), (0, -2.27, 1.55), "trim", bevel=0.03)
    lights(-2.33, 1.55, (-0.8, 0.8), front=False)
    rbox("rack", (1.9, 1.5, 0.08), (0, 0.85, 2.55), "dark", bevel=0.02)
    for x in (-0.9, 0.9):
        rbox("rack_rail", (0.08, 1.6, 0.18), (x, 0.85, 2.6), "trim", bevel=0.02)
    rbox("stripe", (2.17, 1.9, 0.14), (0, 0.95, 1.5), "magenta", bevel=0.02)
    rbox("antenna", (0.04, 0.04, 1.1), (-0.85, -0.2, 2.9), "dark", bevel=0.0)
    for y in (-1.55, 0.0, 1.55):
        for x in (-1.25, 1.25):
            wheel(x, y, 0.55, 0.42)
    finish("rover")


def buggy():
    """A fast dune buggy: a tubular roll cage over the open seats, a sloped
    nose, big knobbly tyres on long arms, a light bar. About 3.8 m."""
    reset()
    rbox("floor", (1.6, 3.3, 0.25), (0, 0, 0.8), "dark", bevel=0.05)
    rbox("nose", (1.45, 1.1, 0.5), (0, 1.35, 1.05), "magenta", bevel=0.14, taper=(0.85, 0.7))
    rbox("engine", (1.25, 0.95, 0.6), (0, -1.25, 1.2), "rust", bevel=0.1)
    for x in (-0.3, 0.3):
        rbox("exhaust", (0.1, 0.5, 0.1), (x, -1.75, 1.45), "trim", bevel=0.03)
    for x in (-0.36, 0.36):
        rbox("seat", (0.55, 0.55, 0.15), (x, 0.0, 1.0), "dark", bevel=0.05)
        rbox("seat_back", (0.55, 0.12, 0.6), (x, -0.3, 1.3), "dark", bevel=0.05)
    for x in (-0.78, 0.78):
        for y in (0.6, -0.65):
            rbox("cage_post", (0.08, 0.08, 1.3), (x, y, 1.55), "trim", bevel=0.03)
        rbox("cage_rail", (0.08, 1.35, 0.08), (x, -0.02, 2.2), "trim", bevel=0.03)
        for y in (1.15, -1.15):
            rbox("arm", (0.55, 0.12, 0.1), (x * 1.3, y, 0.72), "dark", bevel=0.03)
            rbox("shock", (0.1, 0.1, 0.55), (x * 1.25, y, 0.95), "white", bevel=0.03)
    for y in (0.6, -0.65):
        rbox("cage_top", (1.64, 0.08, 0.08), (0, y, 2.2), "trim", bevel=0.03)
    rbox("light_bar", (1.3, 0.14, 0.14), (0, 0.6, 2.32), "dark", bevel=0.03)
    for x in (-0.45, -0.15, 0.15, 0.45):
        rbox("spot", (0.22, 0.06, 0.12), (x, 0.68, 2.32), "light", bevel=0.02)
    lights(1.88, 1.05, (-0.45, 0.45))
    for y in (-1.15, 1.15):
        for x in (-1.2, 1.2):
            wheel(x, y, 0.62, 0.52)
    finish("buggy")


def hauler():
    """The colony's cargo hauler: a tall rounded cab with a big windscreen,
    a long ribbed box body with roller doors, fuel tanks, eight wheels.
    About 7.2 m long."""
    reset()
    rbox("chassis", (2.5, 7.0, 0.5), (0, 0, 1.0), "dark", bevel=0.08)
    rbox("cab", (2.5, 1.9, 1.9), (0, 2.5, 2.2), "hull", bevel=0.22, taper=(0.94, 0.85))
    rbox("windscreen", (2.2, 0.1, 0.85), (0, 3.4, 2.55), "glass", bevel=0.04, rot=(math.radians(-12), 0, 0))
    for x in (-1.26, 1.26):
        rbox("side_window", (0.06, 0.9, 0.65), (x * 0.99, 2.65, 2.6), "glass", bevel=0.03)
        rbox("mirror", (0.12, 0.1, 0.4), (x * 1.12, 3.2, 2.5), "dark", bevel=0.03)
        rbox("fuel_tank", (0.35, 1.1, 0.45), (x * 0.95, 1.15, 1.0), "white", bevel=0.12)
        rbox("step", (0.25, 0.6, 0.06), (x * 1.08, 2.6, 1.15), "trim", bevel=0.02)
    rbox("grille", (1.8, 0.06, 0.55), (0, 3.47, 1.6), "dark", bevel=0.02)
    lights(3.48, 1.4, (-0.95, 0.95))
    rbox("bumper", (2.6, 0.35, 0.35), (0, 3.55, 0.95), "trim", bevel=0.1)
    rbox("cab_stripe", (2.52, 1.92, 0.2), (0, 2.5, 1.7), "magenta", bevel=0.03)
    rbox("beacon", (0.35, 0.35, 0.2), (0, 2.5, 3.25), "red", bevel=0.06)
    rbox("box", (2.6, 4.7, 2.3), (0, -1.0, 2.45), "rust", bevel=0.1)
    for y in (-3.0, -2.1, -1.2, -0.3, 0.6):
        for x in (-1.31, 1.31):
            rbox("rib", (0.05, 0.12, 2.2), (x, y, 2.45), "dark", bevel=0.0)
    rbox("roller_door", (2.3, 0.06, 2.0), (0, -3.36, 2.4), "trim", bevel=0.02)
    for z in (1.8, 2.3, 2.8):
        rbox("door_line", (2.25, 0.08, 0.03), (0, -3.39, z), "dark", bevel=0.0)
    lights(-3.4, 1.35, (-1.0, 1.0), front=False)
    for y in (-2.7, -1.5, 1.1, 2.45):
        for x in (-1.35, 1.35):
            wheel(x, y, 0.6, 0.5)
    finish("hauler")


def merc_gear():
    """The Kasei contractor's kit, modelled on the base body (1.81 m, front
    -Y in Blender = +Z in the game): a pressure helmet with an amber visor
    and filter, a chest rig, and a life-support pack with twin O2 bottles.
    Attached to the Head and spine_03 bones in the game."""
    # Helmet (Head bone).
    reset()
    bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=8, radius=0.165, location=(0, 0.01, 1.70))
    o = bpy.context.object
    o.scale = (1.0, 1.08, 1.05)
    K.mat(o, "hull")
    box("visor", (0.24, 0.06, 0.11), (0, -0.155, 1.715), "trim")
    box("visor_glass", (0.21, 0.05, 0.085), (0, -0.168, 1.715), "glass")
    cyl("filter", 0.045, 0.06, (0.0, -0.16, 1.60), "dark", verts=8, rot=(math.pi / 2, 0, 0))
    box("ridge", (0.04, 0.24, 0.05), (0, 0.0, 1.865), "dark")
    box("lamp", (0.05, 0.06, 0.04), (0.15, -0.08, 1.76), "light")
    finish("merc_helmet")
    # Chest rig and pack (spine_03).
    reset()
    box("front_plate", (0.36, 0.06, 0.32), (0, -0.155, 1.34), "dark")
    box("back_plate", (0.36, 0.05, 0.34), (0, 0.15, 1.36), "dark")
    for x in (-0.11, 0.0, 0.11):
        box("pouch", (0.09, 0.06, 0.1), (x, -0.2, 1.24), "rust")
    box("strap_l", (0.05, 0.32, 0.04), (-0.15, 0.0, 1.5), "dark")
    box("strap_r", (0.05, 0.32, 0.04), (0.15, 0.0, 1.5), "dark")
    box("pack", (0.32, 0.16, 0.4), (0, 0.24, 1.33), "hull")
    box("pack_band", (0.33, 0.17, 0.05), (0, 0.24, 1.42), "trim")
    for x in (-0.09, 0.09):
        cyl("o2", 0.055, 0.46, (x, 0.35, 1.33), "trim", verts=8)
    box("antenna", (0.012, 0.012, 0.4), (0.13, 0.3, 1.68), "dark")
    finish("merc_rig")


def faction_gear():
    """Uniform kit. The Tharsis Mining Concern's security: a full-face
    helmet with a red slit visor and a crest, a chest plate with the
    Concern's yellow chevron, pauldrons. The Hollow militia: a miner's hard
    hat with a lamp and a hi-vis harness."""
    reset()
    bpy.ops.mesh.primitive_uv_sphere_add(segments=10, ring_count=8, radius=0.17, location=(0, 0.0, 1.70))
    o = bpy.context.object
    o.scale = (1.0, 1.1, 1.08)
    K.mat(o, "dark")
    box("visor", (0.26, 0.05, 0.035), (0, -0.172, 1.72), "magenta")
    box("jaw", (0.22, 0.08, 0.09), (0, -0.14, 1.6), "dark")
    box("crest", (0.035, 0.28, 0.06), (0, 0.0, 1.88), "trim")
    finish("concern_helmet")
    reset()
    box("plate", (0.4, 0.09, 0.36), (0, -0.16, 1.34), "dark")
    box("chevron_l", (0.16, 0.02, 0.05), (-0.06, -0.21, 1.4), "trim", rot_z=0.0)
    box("chevron_r", (0.16, 0.02, 0.05), (0.06, -0.21, 1.4), "trim")
    box("back", (0.38, 0.07, 0.36), (0, 0.15, 1.36), "dark")
    for x in (-0.25, 0.25):
        box("pauldron", (0.16, 0.2, 0.08), (x, 0.0, 1.5), "hull")
        box("pauldron_band", (0.17, 0.21, 0.025), (x, 0.0, 1.47), "trim")
    box("belt", (0.36, 0.26, 0.05), (0, 0.0, 0.98), "dark")
    for x in (-0.08, 0.08):  # sealed suit: their air on the back
        cyl("o2", 0.05, 0.42, (x, 0.22, 1.34), "trim", verts=8)
    finish("concern_armor")
    reset()
    bpy.ops.mesh.primitive_uv_sphere_add(segments=10, ring_count=6, radius=0.155, location=(0, 0.01, 1.74))
    o = bpy.context.object
    bm = bmesh.new()
    bm.from_mesh(o.data)
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.z < -0.01], context="VERTS")
    bm.to_mesh(o.data)
    bm.free()
    K.mat(o, "trim")
    cyl("brim", 0.19, 0.03, (0, 0.0, 1.745), "trim", verts=12)
    box("lamp", (0.06, 0.05, 0.05), (0, -0.16, 1.79), "light")
    finish("militia_hat")
    reset()
    for x in (-0.11, 0.11):
        box("strap", (0.06, 0.34, 0.05), (x, 0.0, 1.38), "magenta")
    box("band", (0.36, 0.3, 0.06), (0, 0.0, 1.18), "magenta")
    box("radio", (0.08, 0.05, 0.12), (0.12, -0.18, 1.42), "dark")
    finish("militia_harness")


def marshal_gear():
    """The Kasei Marshals, Mars' police: a white helmet with a cyan visor
    and a red-blue light bar along the crown; a navy vest with a gold badge,
    white shoulder flashes and their air on the back."""
    reset()
    bpy.ops.mesh.primitive_uv_sphere_add(segments=10, ring_count=8, radius=0.17, location=(0, 0.0, 1.70))
    o = bpy.context.object
    o.scale = (1.0, 1.1, 1.06)
    K.mat(o, "white")
    box("visor", (0.28, 0.06, 0.09), (0, -0.165, 1.71), "glass")
    box("bar_red", (0.07, 0.12, 0.05), (-0.05, 0.0, 1.89), "red")
    box("bar_blue", (0.07, 0.12, 0.05), (0.05, 0.0, 1.89), "blue")
    box("bar_base", (0.17, 0.14, 0.02), (0, 0.0, 1.86), "dark")
    finish("marshal_helmet")
    reset()
    box("vest", (0.4, 0.09, 0.4), (0, -0.16, 1.3), "navy")
    box("back", (0.38, 0.07, 0.38), (0, 0.15, 1.32), "navy")
    box("badge", (0.07, 0.02, 0.08), (-0.1, -0.21, 1.42), "trim")
    box("stripe", (0.41, 0.02, 0.04), (0, -0.21, 1.2), "white")
    for x in (-0.25, 0.25):
        box("flash", (0.15, 0.19, 0.07), (x, 0.0, 1.5), "white")
    box("belt", (0.36, 0.26, 0.05), (0, 0.0, 0.98), "dark")
    box("radio", (0.07, 0.05, 0.11), (0.12, -0.2, 1.44), "dark")
    for x in (-0.08, 0.08):
        cyl("o2", 0.05, 0.42, (x, 0.22, 1.34), "white", verts=8)
    finish("marshal_vest")


freighter_wreck()
def split_vehicle(build, name):
    """The body without its wheels, then one wheel of each side: hub at the
    origin, axis along X. Prints where the wheels go (Godot axes)."""
    global SPLIT_WHEELS
    SPLIT_WHEELS = []
    build()
    placed = SPLIT_WHEELS
    x, y, r, w, hub = placed[0]
    for side, sx in (("l", -1), ("r", 1)):
        SPLIT_WHEELS = "build"
        reset()
        wheel(sx * 0.001, 0.0, r, w, hub)
        for o in bpy.context.scene.objects:
            o.location.z -= r
        finish("%s_wheel_%s" % (name, side))
    SPLIT_WHEELS = None
    print("WHEELS %s r=%.2f %s" % (name, r, [(round(px, 2), round(r, 2), round(-py, 2)) for px, py, r, w, h in placed]))


split_vehicle(rover, "rover")
split_vehicle(buggy, "buggy")
split_vehicle(hauler, "hauler")
merc_gear()
faction_gear()
marshal_gear()
