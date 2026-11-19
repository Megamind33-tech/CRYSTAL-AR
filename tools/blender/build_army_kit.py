# THE HUNT: the armies' aircraft (HuntArmy units), built in Blender from code
# in the outpost kit's comic style: bevelled panels in named flat colours
# (the game draws them with Comic.kit_material and an ink outline).
#   blender -b -P tools/blender/build_army_kit.py -- art/environment/army
# Each unit is one .glb, nose along -Z in the game (Blender +Y), centred.
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


for build in (attack_drone, scout_drone, emp_drone, aegis_drone, swarm_drone, strike_jet, raptor, bomber, nightwing):
    build()
