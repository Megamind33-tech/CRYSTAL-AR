# THE HUNT: the armies' aircraft (HuntArmy units), built in Blender from code
# in the outpost kit's comic style: bevelled panels in named flat colours
# (the game draws them with Comic.kit_material and an ink outline).
#   blender -b -P tools/blender/build_army_kit.py -- art/environment/army
# Each unit is one .glb, nose along -Z in the game (Blender +Y), centred;
# ground units and defences stand on the origin, and the parts that turn
# (turret heads, gun cradles, the radar dish) are their own pieces.
import bpy, bmesh, math, sys, os
sys.path.insert(0, os.path.dirname(__file__))
import build_outpost_kit as K  # noqa: E402
from build_outpost_kit import cyl, finish  # noqa: E402

OUT = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "/tmp/army"
os.makedirs(OUT, exist_ok=True)
K.OUT = OUT
K.COLORS.update({
    "gunmetal": (0.2, 0.22, 0.25, 1), "olive": (0.33, 0.38, 0.22, 1), "violet": (0.5, 0.28, 0.95, 1),
    "orange": (0.95, 0.45, 0.1, 1), "cyan": (0.2, 0.85, 1.0, 1), "sand": (0.72, 0.62, 0.45, 1),
})
R = math.radians


def reset():
    K.reset()


def rb(name, size, loc, mat, bevel=0.04, rot=(0, 0, 0), taper=None):
    """A box with bevelled edges; `taper` (x, y) scales its top face."""
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc, rotation=rot)
    o = bpy.context.object
    o.name = name
    o.scale = size
    bpy.ops.object.transform_apply(scale=True)
    if taper is not None:
        for v in o.data.vertices:
            if v.co.z > 0:
                v.co.x *= taper[0]
                v.co.y *= taper[1]
    if bevel > 0:
        m = o.modifiers.new("bevel", "BEVEL")
        m.width = bevel
        m.segments = 1
        m.limit_method = "ANGLE"
        bpy.ops.object.modifier_apply(modifier="bevel")
    K.mat(o, mat)
    return o


def cone(name, r1, r2, depth, loc, mat, verts=12, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r1, radius2=r2, depth=depth, location=loc, rotation=rot)
    o = bpy.context.object
    o.name = name
    K.mat(o, mat)
    return o


def ring(name, r, thick, loc, mat, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_torus_add(major_radius=r, minor_radius=thick, major_segments=20, minor_segments=6,
                                     location=loc, rotation=rot)
    o = bpy.context.object
    o.name = name
    K.mat(o, mat)
    return o


def ball(name, r, loc, mat, segs=12):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segs, ring_count=segs // 2, radius=r, location=loc)
    o = bpy.context.object
    o.name = name
    K.mat(o, mat)
    return o


def wing(name, root, tip, span, sweep, thick, x0, y0, z0, mat, side):
    """A tapered wing panel: root chord at x0, tip at x0+span*side, swept by `sweep` (m, +y forward)."""
    me = bpy.data.meshes.new(name)
    o = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(o)
    bm = bmesh.new()
    pts = [(x0, y0 + root * 0.5), (x0, y0 - root * 0.5), (x0 + span * side, y0 - tip * 0.5 + sweep),
           (x0 + span * side, y0 + tip * 0.5 + sweep)]
    top = [bm.verts.new((x, y, z0 + thick * 0.5)) for x, y in pts]
    bot = [bm.verts.new((x, y, z0 - thick * 0.5)) for x, y in pts]
    bm.faces.new(top if side > 0 else top[::-1])
    bm.faces.new(bot[::-1] if side > 0 else bot)
    for i in range(4):
        j = (i + 1) % 4
        f = [top[i], top[j], bot[j], bot[i]]
        bm.faces.new(f if side > 0 else f[::-1])
    bm.normal_update()
    bm.to_mesh(me)
    bm.free()
    K.mat(o, mat)
    bpy.context.view_layer.objects.active = o
    return o


def rotor_arm(x, y, z, r, mat="gunmetal", blade="dark"):
    rb("arm", (abs(x) * 1.1 + 0.05, 0.08, 0.06), (x * 0.5, y * 0.5, z), mat, bevel=0.02,
       rot=(0, 0, math.atan2(y, x)))
    cyl("motor", 0.07, 0.12, (x, y, z + 0.06), mat, verts=10)
    ring("guard", r, 0.025, (x, y, z + 0.08), "dark")
    rb("blade", (r * 1.8, 0.05, 0.015), (x, y, z + 0.13), blade, bevel=0.0, rot=(0, 0, 0.6))


# --- Drones ---

def attack_drone():
    reset()
    rb("body", (0.7, 0.9, 0.28), (0, 0, 0), "orange", bevel=0.08, taper=(0.8, 1.0))
    rb("spine", (0.3, 0.7, 0.1), (0, -0.05, 0.17), "gunmetal", bevel=0.03)
    for x in (-1, 1):
        for y in (-1, 1):
            rotor_arm(0.7 * x, 0.65 * y, 0.05, 0.3)
    cyl("gun", 0.05, 0.6, (0, 0.45, -0.22), "dark", verts=8, rot=(R(90), 0, 0))
    rb("gun_pod", (0.22, 0.4, 0.16), (0, 0.15, -0.2), "gunmetal", bevel=0.03)
    ball("eye", 0.09, (0, 0.47, 0.0), "red", segs=10)
    finish("attack_drone")


def scout_drone():
    reset()
    rb("body", (0.4, 0.55, 0.18), (0, 0, 0), "white", bevel=0.06)
    rb("stripe", (0.42, 0.12, 0.19), (0, 0.1, 0), "cyan", bevel=0.02)
    for x in (-1, 1):
        for y in (-1, 1):
            rotor_arm(0.42 * x, 0.4 * y, 0.03, 0.2)
    ball("camera", 0.11, (0, 0.2, -0.13), "dark", segs=10)
    ball("lens", 0.05, (0, 0.29, -0.14), "glass", segs=8)
    cyl("antenna", 0.01, 0.3, (0.12, -0.2, 0.22), "dark", verts=6)
    finish("scout_drone")


def emp_drone():
    reset()
    ball("core", 0.32, (0, 0, 0), "gunmetal", segs=14)
    ring("coil_a", 0.55, 0.05, (0, 0, 0), "cyan")
    ring("coil_b", 0.45, 0.04, (0, 0, 0), "cyan", rot=(R(90), 0, 0))
    for x in (-1, 1):
        for y in (-1, 1):
            rotor_arm(0.75 * x, 0.75 * y, 0.2, 0.26)
    cone("emitter", 0.18, 0.05, 0.3, (0, 0, -0.42), "dark", rot=(R(180), 0, 0))
    ball("spark", 0.08, (0, 0, -0.6), "cyan", segs=8)
    finish("emp_drone")


def aegis_drone():
    reset()
    cyl("body", 0.5, 0.3, (0, 0, 0), "blue", verts=6)
    cyl("plate", 0.62, 0.06, (0, 0, -0.18), "white", verts=6)
    cone("dome", 0.32, 0.1, 0.3, (0, 0, 0.3), "glass", verts=12)
    ring("field", 0.85, 0.035, (0, 0, -0.05), "cyan")
    for k in range(3):
        a = k * math.tau / 3 + 0.5
        rotor_arm(math.cos(a) * 0.9, math.sin(a) * 0.9, 0.12, 0.28)
    finish("aegis_drone")


def swarm_drone():
    reset()
    wing("wl", 0.5, 0.1, 0.42, -0.3, 0.06, 0.02, 0, 0, "olive", -1)
    wing("wr", 0.5, 0.1, 0.42, -0.3, 0.06, -0.02, 0, 0, "olive", 1)
    cone("nose", 0.1, 0.0, 0.4, (0, 0.35, 0), "gunmetal", verts=8, rot=(R(-90), 0, 0))
    cyl("prop_hub", 0.05, 0.1, (0, -0.28, 0), "dark", verts=8, rot=(R(90), 0, 0))
    ring("prop", 0.16, 0.02, (0, -0.33, 0), "dark", rot=(R(90), 0, 0))
    ball("eye", 0.04, (0, 0.5, 0.02), "red", segs=8)
    finish("swarm_drone")


# --- Jets ---

def fuselage(length, r, mat, nose_mat="gunmetal"):
    cyl("fuse", r, length * 0.62, (0, -length * 0.05, 0), mat, verts=12, rot=(R(90), 0, 0))
    cone("nose", r, 0.06, length * 0.3, (0, length * 0.41, 0), nose_mat, verts=12, rot=(R(-90), 0, 0))
    cone("tail", r, r * 0.6, length * 0.12, (0, -length * 0.42, 0), "dark", verts=12, rot=(R(90), 0, 0))
    rb("canopy", (r * 1.1, length * 0.16, r * 0.8), (0, length * 0.2, r * 0.75), "glass", bevel=r * 0.3,
       taper=(0.6, 1.0))
    ball("burner", r * 0.55, (0, -length * 0.49, 0), "orange", segs=10)


def strike_jet():
    reset()
    fuselage(9.0, 0.6, "sand")
    for s in (-1, 1):
        wing("wing", 3.0, 0.9, 4.2, -1.8, 0.16, 0.5 * s, -0.6, -0.1, "sand", s)
        wing("tail", 1.4, 0.5, 1.6, -0.8, 0.1, 0.4 * s, -3.6, 0.0, "sand", s)
        rb("intake", (0.5, 1.6, 0.6), (0.75 * s, 1.0, -0.15), "gunmetal", bevel=0.1)
        cyl("missile", 0.1, 1.6, (2.6 * s, -0.4, -0.3), "white", verts=8, rot=(R(90), 0, 0))
        rb("stripe", (0.1, 1.2, 0.17), (2.0 * s, -0.8, -0.1), "trim", bevel=0.0)
    rb("fin", (0.14, 1.6, 1.5), (0, -3.4, 0.9), "sand", bevel=0.05, taper=(1.0, 0.5))
    finish("strike_jet")


def raptor():
    reset()
    fuselage(9.5, 0.62, "blue", nose_mat="white")
    for s in (-1, 1):
        wing("wing", 2.4, 1.1, 4.0, 1.3, 0.16, 0.5 * s, -1.6, -0.1, "blue", s)  # forward swept
        wing("canard", 0.9, 0.4, 1.4, 0.2, 0.08, 0.5 * s, 2.4, 0.05, "white", s)
        rb("fin", (0.12, 1.5, 1.4), (0.7 * s, -3.4, 0.9), "blue", bevel=0.05, rot=(0, R(18 * s), 0), taper=(1.0, 0.5))
        rb("stripe", (0.1, 1.3, 0.17), (2.2 * s, -0.4, -0.1), "white", bevel=0.0)
    finish("raptor")


def bomber():
    reset()
    # A flying wing: a deep centre body blended into long swept wings, four engines.
    rb("body", (2.6, 6.0, 1.1), (0, 0.4, 0), "gunmetal", bevel=0.4, taper=(0.7, 1.0))
    rb("cockpit", (1.2, 1.4, 0.5), (0, 2.6, 0.6), "glass", bevel=0.2, taper=(0.6, 1.0))
    for s in (-1, 1):
        wing("wing", 4.6, 1.2, 8.5, -4.2, 0.4, 1.2 * s, 0.4, 0, "gunmetal", s)
        for x in (3.0, 5.2):
            cyl("engine", 0.42, 2.4, (x * s, -0.4 - (x - 3.0) * 0.4, -0.45), "dark", verts=12, rot=(R(90), 0, 0))
            ring("intake", 0.42, 0.06, (x * s, 0.8 - (x - 3.0) * 0.4, -0.45), "trim", rot=(R(90), 0, 0))
            ball("burner", 0.3, (x * s, -1.6 - (x - 3.0) * 0.4, -0.45), "orange", segs=10)
        rb("stripe", (2.6, 0.3, 0.42), (5.5 * s, -2.0, 0.0), "red", bevel=0.0, rot=(0, 0, R(-26 * s)))
    finish("bomber")


def nightwing():
    reset()
    # Stealth: flat facets, no round parts but the burner, dark with violet trim.
    for s in (-1, 1):
        wing("wing", 6.5, 0.6, 4.8, -4.0, 0.35, 0.0, 0.5, 0, "navy", s)
        wing("edge", 0.35, 0.12, 4.6, -3.95, 0.37, 0.0, 3.6, 0, "violet", s)
        rb("fin", (0.1, 1.2, 1.1), (1.2 * s, -2.4, 0.5), "navy", bevel=0.0, rot=(0, R(30 * s), 0), taper=(1.0, 0.4))
    rb("hump", (1.4, 4.0, 0.7), (0, 0.6, 0.25), "navy", bevel=0.15, taper=(0.5, 0.8))
    rb("canopy", (0.7, 1.2, 0.35), (0, 2.0, 0.6), "violet", bevel=0.1, taper=(0.5, 1.0))
    ball("burner", 0.3, (0, -2.6, 0.1), "violet", segs=10)
    finish("nightwing")


# --- Ground: tracks, tanks, the crawler ---

def track(x, length, h, w, mat="dark"):
    """A tank track along Y at side x: a rounded belt, wheels showing, a skirt."""
    rb("belt", (w, length, h), (x, 0, h * 0.5), mat, bevel=h * 0.35)
    for k in range(6):
        y = -length * 0.4 + k * length * 0.8 / 5
        cyl("road_wheel", h * 0.32, w * 1.06, (x, y, h * 0.42), "gunmetal", verts=10, rot=(0, R(90), 0))
        cyl("hub", h * 0.12, w * 1.1, (x, y, h * 0.42), "trim", verts=6, rot=(0, R(90), 0))
    for k in range(14):  # tread cleats
        y = -length * 0.46 + k * length * 0.92 / 13
        rb("cleat", (w * 1.02, 0.08, 0.06), (x, y, h + 0.01), "dark", bevel=0.0)


def tank():
    reset()
    for s in (-1, 1):
        track(0.95 * s, 4.6, 0.8, 0.55)
        rb("skirt", (0.12, 4.2, 0.45), (1.27 * s, 0, 0.75), "olive", bevel=0.03)
    rb("hull", (1.8, 4.4, 0.6), (0, 0, 1.05), "olive", bevel=0.12, taper=(0.9, 0.92))
    rb("glacis", (1.7, 1.0, 0.4), (0, 2.0, 0.95), "olive", bevel=0.1, rot=(R(-20), 0, 0))
    rb("engine_deck", (1.4, 1.0, 0.18), (0, -1.6, 1.42), "gunmetal", bevel=0.04)
    for x in (-0.4, 0.0, 0.4):
        rb("grille", (0.25, 0.9, 0.05), (x, -1.6, 1.53), "dark", bevel=0.0)
    rb("stripe", (1.82, 0.25, 0.62), (0, 1.3, 1.05), "trim", bevel=0.02)
    for x in (-0.65, 0.65):
        rb("light", (0.22, 0.08, 0.14), (x, 2.48, 1.1), "light", bevel=0.02)
    finish("tank")


def tank_turret():
    reset()  # origin: the turret ring (it turns about it)
    rb("turret", (1.5, 1.9, 0.7), (0, -0.1, 0.35), "olive", bevel=0.18, taper=(0.75, 0.85))
    rb("mantlet", (0.7, 0.4, 0.5), (0, 0.95, 0.35), "gunmetal", bevel=0.08)
    cyl("gun", 0.1, 2.6, (0, 2.3, 0.38), "gunmetal", verts=10, rot=(R(90), 0, 0))
    cyl("muzzle", 0.16, 0.35, (0, 3.6, 0.38), "dark", verts=10, rot=(R(90), 0, 0))
    cyl("bore_evac", 0.14, 0.4, (0, 2.0, 0.38), "dark", verts=10, rot=(R(90), 0, 0))
    cyl("hatch", 0.28, 0.1, (0.35, -0.4, 0.75), "gunmetal", verts=10)
    cyl("hmg", 0.04, 0.8, (-0.4, 0.1, 0.95), "dark", verts=6, rot=(R(90), 0, 0))
    rb("hmg_mount", (0.18, 0.25, 0.2), (-0.4, -0.25, 0.82), "gunmetal", bevel=0.02)
    rb("stowage", (0.25, 1.0, 0.35), (-0.78, -0.4, 0.3), "sand", bevel=0.05)
    cyl("antenna", 0.012, 1.4, (0.55, -0.85, 1.4), "dark", verts=6)
    rb("stripe", (1.52, 0.2, 0.2), (0, -0.4, 0.6), "trim", bevel=0.02)
    finish("tank_turret")


def bastion():
    reset()
    # Halden's heavy tank: wider and longer, slab armour, deep skirts; dark
    # steel with red bands.
    for s in (-1, 1):
        track(1.15 * s, 5.4, 0.9, 0.65)
        rb("skirt", (0.18, 5.0, 0.75), (1.55 * s, 0, 0.85), "gunmetal", bevel=0.05)
        for k in range(4):  # bolted armour plates on the skirt
            rb("plate", (0.08, 1.05, 0.5), (1.66 * s, -1.8 + k * 1.2, 0.9), "dark", bevel=0.02)
        rb("band", (0.2, 0.3, 0.78), (1.56 * s, 1.6, 0.85), "red", bevel=0.0)
    rb("hull", (2.4, 5.2, 0.75), (0, 0, 1.25), "gunmetal", bevel=0.14, taper=(0.9, 0.92))
    rb("glacis", (2.3, 1.2, 0.55), (0, 2.4, 1.05), "gunmetal", bevel=0.12, rot=(R(-24), 0, 0))
    rb("dozer", (2.6, 0.3, 0.6), (0, 3.0, 0.55), "dark", bevel=0.06)
    rb("engine_deck", (1.9, 1.3, 0.2), (0, -1.9, 1.7), "dark", bevel=0.04)
    for x in (-0.6, 0.0, 0.6):
        rb("grille", (0.3, 1.1, 0.05), (x, -1.9, 1.82), "gunmetal", bevel=0.0)
    for x in (-0.8, 0.8):
        rb("light", (0.25, 0.08, 0.15), (x, 2.95, 1.25), "light", bevel=0.02)
        cyl("smoke", 0.09, 0.4, (x * 1.15, 1.5, 1.75), "dark", verts=8, rot=(R(-30), 0, 0))
    finish("bastion")


def bastion_turret():
    reset()  # origin: the turret ring
    rb("turret", (2.0, 2.3, 0.85), (0, -0.15, 0.42), "gunmetal", bevel=0.16, taper=(0.78, 0.85))
    rb("band", (2.02, 0.3, 0.3), (0, -0.6, 0.55), "red", bevel=0.02)
    rb("mantlet", (1.0, 0.45, 0.6), (0, 1.1, 0.42), "dark", bevel=0.08)
    for x in (-0.22, 0.22):  # the twin cannon
        cyl("gun", 0.09, 2.8, (x, 2.5, 0.45), "dark", verts=10, rot=(R(90), 0, 0))
        cyl("muzzle", 0.14, 0.35, (x, 3.85, 0.45), "gunmetal", verts=10, rot=(R(90), 0, 0))
    for s in (-1, 1):  # anti-air autocannons on the turret's sides (its gun shoots aircraft)
        rb("aa_mount", (0.35, 0.6, 0.45), (1.12 * s, 0.0, 0.75), "gunmetal", bevel=0.05)
        for z in (0.68, 0.84):
            cyl("aa_gun", 0.05, 1.3, (1.12 * s, 0.75, z), "dark", verts=6, rot=(R(70), 0, 0))
    cyl("radar_mast", 0.05, 0.6, (-0.55, -0.85, 1.1), "dark", verts=6)
    rb("radar", (0.7, 0.12, 0.35), (-0.55, -0.85, 1.45), "light", bevel=0.03)
    cyl("hatch", 0.3, 0.1, (0.45, -0.5, 0.88), "dark", verts=10)
    finish("bastion_turret")


def crawler():
    reset()
    for s in (-1, 1):
        track(1.05 * s, 6.0, 0.95, 0.65)
    rb("chassis", (1.9, 5.6, 0.5), (0, 0, 1.15), "gunmetal", bevel=0.08)
    rb("cab", (1.9, 1.4, 1.3), (0, 2.1, 2.0), "trim", bevel=0.15, taper=(0.9, 0.85))
    rb("windscreen", (1.6, 0.1, 0.55), (0, 2.82, 2.25), "glass", bevel=0.03, rot=(R(-15), 0, 0))
    rb("hopper", (2.2, 3.0, 1.4), (0, -0.8, 2.1), "olive", bevel=0.12, taper=(1.1, 1.05))
    for y in (-2.0, -0.8, 0.4):
        rb("rib", (2.3, 0.15, 1.2), (y * 0 + 0, y, 2.15), "gunmetal", bevel=0.03)
    rb("load", (1.9, 2.6, 0.4), (0, -0.8, 2.85), "rust", bevel=0.12)
    # The drill: a cone on an arm at the front, ringed with teeth.
    rb("arm", (0.5, 1.4, 0.5), (0, 3.3, 1.1), "gunmetal", bevel=0.06)
    cone("drill", 0.65, 0.05, 1.5, (0, 4.6, 1.0), "trim", verts=10, rot=(R(-90), 0, 0))
    for k in range(3):
        ring("tooth_ring", 0.5 - k * 0.14, 0.05, (0, 4.15 + k * 0.38, 1.0), "dark", rot=(R(90), 0, 0))
    for x in (-0.7, 0.7):
        rb("beacon", (0.15, 0.15, 0.2), (x, 1.5, 2.75), "orange", bevel=0.03)
    cyl("exhaust", 0.1, 1.0, (0.8, 1.2, 2.8), "dark", verts=8)
    finish("crawler")


# --- Camp defences: a base, and the parts that turn (exported apart) ---

def turret_base():
    reset()
    rb("bunker", (2.4, 2.4, 1.9), (0, 0, 0.95), "hull", bevel=0.25, taper=(0.82, 0.82))
    rb("slit", (2.0, 0.1, 0.25), (0, 1.17, 1.35), "dark", bevel=0.0)
    for s in (-1, 1):
        rb("buttress", (0.5, 2.6, 0.9), (1.2 * s, 0, 0.45), "rust", bevel=0.1)
    cyl("ring", 0.85, 0.25, (0, 0, 2.0), "gunmetal", verts=16)
    rb("stripe", (2.42, 0.3, 0.3), (0, 0, 1.5), "trim", bevel=0.02)
    finish("turret_base")


def turret_head():
    reset()  # origin on the ring
    rb("housing", (1.4, 1.5, 0.75), (0, 0, 0.38), "gunmetal", bevel=0.18, taper=(0.8, 0.85))
    rb("visor", (0.8, 0.1, 0.18), (0, 0.72, 0.5), "red", bevel=0.02)
    for x in (-0.32, 0.32):
        cyl("barrel", 0.08, 1.6, (x, 1.4, 0.35), "dark", verts=8, rot=(R(90), 0, 0))
        cyl("shroud", 0.13, 0.6, (x, 0.95, 0.35), "gunmetal", verts=8, rot=(R(90), 0, 0))
    rb("ammo", (0.4, 0.6, 0.45), (0.8, -0.2, 0.3), "olive", bevel=0.05)
    cyl("sensor", 0.06, 0.6, (-0.45, -0.4, 0.95), "dark", verts=6)
    ball("sensor_eye", 0.1, (-0.45, -0.4, 1.28), "red", segs=8)
    finish("turret_head")


def flak_base(aegis):
    reset()
    k = 1.35 if aegis else 1.0
    cyl("pad", 1.8 * k, 0.3, (0, 0, 0.15), "gunmetal", verts=14)
    for b in range(12):  # sandbags round the pit
        a = math.tau * b / 12
        rb("bag", (0.9 * k, 0.5 * k, 0.45 * k), (math.cos(a) * 1.6 * k, math.sin(a) * 1.6 * k, 0.5 * k), "sand",
           bevel=0.15 * k, rot=(0, 0, a + R(90)))
    cone("column", 0.55 * k, 0.38 * k, 1.2 * k, (0, 0, 0.9 * k), "hull", verts=12)
    for q in ((1.9, 0.9), (2.0, -0.3)):
        rb("crate", (0.7 * k, 0.5 * k, 0.5 * k), (q[0] * k, q[1] * k, 0.25 * k), "olive", bevel=0.05)
        rb("crate_band", (0.72 * k, 0.1, 0.52 * k), (q[0] * k, q[1] * k, 0.25 * k), "trim", bevel=0.0)
    if aegis:
        cyl("mast", 0.1, 2.3, (-1.6 * k, -1.2 * k, 1.15), "gunmetal", verts=8)
        rb("console", (0.8, 0.5, 0.9), (1.2 * k, -1.6 * k, 0.45), "blue", bevel=0.08)
    finish("aegis_base" if aegis else "flak_base")


def flak_head(aegis):
    reset()  # origin: the head's pivot
    k = 1.35 if aegis else 1.0
    rb("body", (1.6 * k, 1.3 * k, 0.9 * k), (0, 0, 0), "hull" if not aegis else "white", bevel=0.18 * k, taper=(0.85, 0.85))
    rb("stripe", (1.62 * k, 1.32 * k, 0.18 * k), (0, 0, 0.2 * k), "trim" if not aegis else "blue", bevel=0.02)
    rb("sight", (0.3 * k, 0.4 * k, 0.3 * k), (0.55 * k, 0.3 * k, 0.55 * k), "gunmetal", bevel=0.05)
    ball("sight_lens", 0.08 * k, (0.55 * k, 0.52 * k, 0.58 * k), "glass", segs=8)
    if aegis:
        for s in (-1, 1):  # armour skirts
            rb("skirt", (0.14 * k, 1.4 * k, 0.7 * k), (0.88 * s * k, 0, -0.15 * k), "blue", bevel=0.04)
        rb("pod", (0.9 * k, 1.1 * k, 0.7 * k), (0, -0.1 * k, 0.78 * k), "white", bevel=0.1)
        for t in range(6):
            cyl("tube", 0.1 * k, 0.12, ((t % 3 - 1) * 0.27 * k, 0.48 * k, 0.78 * k + (t // 3 - 0.5) * 0.28 * k),
                "dark", verts=8, rot=(R(90), 0, 0))
            cone("tip", 0.08 * k, 0.0, 0.18, ((t % 3 - 1) * 0.27 * k, 0.6 * k, 0.78 * k + (t // 3 - 0.5) * 0.28 * k),
                 "red", verts=8, rot=(R(-90), 0, 0))
    finish("aegis_head" if aegis else "flak_head")


def flak_guns(aegis):
    reset()  # origin: the cradle's pivot; barrels forward
    k = 1.35 if aegis else 1.0
    rb("cradle", (1.2 * k, 0.5 * k, 0.6 * k), (0, 0, 0), "gunmetal", bevel=0.08)
    for q in ((-0.45, 0.2), (0.45, 0.2), (-0.45, -0.15), (0.45, -0.15)):
        cyl("barrel", 0.08 * k, 2.6 * k, (q[0] * k, 1.3 * k, q[1] * k), "dark", verts=8, rot=(R(90), 0, 0))
        cyl("jacket", 0.12 * k, 0.8 * k, (q[0] * k, 0.5 * k, q[1] * k), "gunmetal", verts=8, rot=(R(90), 0, 0))
        cone("flash", 0.08 * k, 0.15 * k, 0.32 * k, (q[0] * k, 2.68 * k, q[1] * k), "gunmetal", verts=8, rot=(R(-90), 0, 0))
    finish("aegis_guns" if aegis else "flak_guns")


def aegis_dish():
    reset()  # origin: the top of the mast
    cyl("hub", 0.15, 0.3, (0, 0, 0.1), "gunmetal", verts=8)
    cone("dish", 0.95, 0.2, 0.35, (0, 0.15, 0.55), "white", verts=16, rot=(R(-65), 0, 0))
    cyl("feed", 0.03, 0.7, (0, 0.5, 0.75), "dark", verts=6, rot=(R(-65), 0, 0))
    ball("emitter", 0.08, (0, 0.75, 0.88), "blue", segs=8)
    finish("aegis_dish")


for build in (attack_drone, scout_drone, emp_drone, aegis_drone, swarm_drone, strike_jet, raptor, bomber, nightwing,
              tank, tank_turret, bastion, bastion_turret, crawler, turret_base, turret_head, aegis_dish):
    build()
for aegis in (False, True):
    flak_base(aegis)
    flak_head(aegis)
    flak_guns(aegis)
