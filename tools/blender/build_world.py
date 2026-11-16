# THE HUNT: Kasei Valley, built in Blender from code.
#   blender -b -P tools/blender/build_world.py -- <out_dir>
# terrain.glb: the 800 x 800 m valley (4 m grid) from world_terrain.py with
# vertex colours: dust on the flats, layered rock strata on the slopes,
# ice in the crater, packed dirt on the roads. freighter_wreck.glb: the
# crashed hauler landmark. Godot shades both (cel bands, outlines on the
# wreck) and builds the terrain collision from the same height function.
import bpy, bmesh, math, sys, os
sys.path.insert(0, os.path.dirname(__file__))
import world_terrain as W  # noqa: E402
from build_outpost_kit import reset, box, cyl, finish  # noqa: E402
import build_outpost_kit as K  # noqa: E402

OUT = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "/tmp/world"
os.makedirs(OUT, exist_ok=True)
K.OUT = OUT

# Roads: polylines (x, z) between the places.
ROADS = [
    [(-220, 84), (-170, 92), (-110, 70), (-40, 20), (20, -30), (60, -60)],
    [(60, -60), (110, -10), (160, 60), (205, W.canyon_center(205)), (240, W.canyon_center(240))],
    [(60, -60), (110, -150), (140, -190)],
    [(-110, 70), (-160, -60), (-240, -146)],
    [(-220, 84), (-300, 140), (-420, 190), (-482, 200)],
    [(-240, -146), (-330, -290), (-420, -390), (-455, -430)],
    [(-170, 92), (-160, 200), (-100, 300), (150, 385), (370, 425)],
    [(60, -60), (250, -150), (400, -300), (460, -385)],
    [(240, W.canyon_center(240)), (300, W.canyon_center(300)), (370, W.canyon_center(370)), (420, 300), (440, 345)],
    [(-560, 120), (-590, -60), (-570, -250), (-540, -350)],
]


def seg_dist(px, pz, a, b):
    ax, az = a
    bx, bz = b
    dx, dz = bx - ax, bz - az
    t = max(0.0, min(1.0, ((px - ax) * dx + (pz - az) * dz) / (dx * dx + dz * dz)))
    return math.hypot(px - (ax + t * dx), pz - (az + t * dz))


def road_dist(x, z):
    return min(seg_dist(x, z, r[i], r[i + 1]) for r in ROADS for i in range(len(r) - 1))


def lerp3(a, b, t):
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


def color_at(x, z, h, slope):
    n = math.sin(x * 0.13) * math.cos(z * 0.11) * 0.5 + math.sin(x * 0.031 + z * 0.027) * 0.5
    dust = lerp3((0.62, 0.31, 0.17), (0.72, 0.42, 0.24), n * 0.5 + 0.5)
    # Strata on the slopes: bands by height.
    band = int(math.floor(h / 3.2)) % 3
    rock = [(0.42, 0.18, 0.11), (0.58, 0.29, 0.16), (0.33, 0.15, 0.1)][band]
    c = lerp3(dust, rock, W.smoothstep(0.12, 0.35, slope))
    for cx, cz, cr in (W.CRATER, W.CRATER2):
      if math.hypot(x - cx, z - cz) < cr * 0.42 and slope < 0.2:
        c = lerp3(c, (0.82, 0.86, 0.9), 0.75 * (0.5 + 0.5 * math.sin(x * 0.4) * math.sin(z * 0.37)))
    rd = road_dist(x, z)
    if rd < 5.0:
        c = lerp3(c, (0.36, 0.19, 0.12), W.smoothstep(5.0, 2.5, rd))
    return c


TILES = 10  # per side: tiles are culled off-screen and get the importer's LODs


def terrain():
    """The valley floor and walls, as TILES x TILES tiles (one object each,
    so the renderer skips tiles out of view and draws far ones at a lower
    detail level). Normals come from the height function, so tile edges
    don't show."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    n = int(W.SIZE / W.STEP) + 1
    half = W.SIZE / 2
    cells = n - 1
    per = int(math.ceil(cells / TILES))
    m = bpy.data.materials.new("terrain")
    m.use_nodes = True
    attr = m.node_tree.nodes.new("ShaderNodeVertexColor")
    attr.layer_name = "Col"
    m.node_tree.links.new(attr.outputs["Color"], m.node_tree.nodes["Principled BSDF"].inputs["Base Color"])
    total = 0
    for ty in range(TILES):
        for tx in range(TILES):
            i0, j0 = tx * per, ty * per
            i1, j1 = min(i0 + per, cells), min(j0 + per, cells)
            if i0 >= i1 or j0 >= j1:
                continue
            bm = bmesh.new()
            col = bm.loops.layers.color.new("Col")
            grid = {}
            normals = []
            for j in range(j0, j1 + 1):
                z = -half + j * W.STEP
                for i in range(i0, i1 + 1):
                    x = -half + i * W.STEP
                    h = W.height(x, z)
                    # Blender is Z-up, Y forward: Godot (x, y, z) = Blender (x, z, -y).
                    grid[(i, j)] = bm.verts.new((x, -z, h))
                    gx = (W.height(x + 1, z) - W.height(x - 1, z)) / 2.0
                    gz = (W.height(x, z + 1) - W.height(x, z - 1)) / 2.0
                    l = math.sqrt(gx * gx + gz * gz + 1.0)
                    normals.append((-gx / l, gz / l, 1.0 / l))
            bm.verts.ensure_lookup_table()
            for j in range(j0, j1):
                for i in range(i0, i1):
                    f = bm.faces.new([grid[(i, j)], grid[(i + 1, j)], grid[(i + 1, j + 1)], grid[(i, j + 1)]])
                    for loop in f.loops:
                        v = loop.vert
                        x, z, h = v.co.x, -v.co.y, v.co.z
                        gx = (W.height(x + 2, z) - W.height(x - 2, z)) / 4.0
                        gz = (W.height(x, z + 2) - W.height(x, z - 2)) / 4.0
                        r, g, b = color_at(x, z, h, math.hypot(gx, gz))
                        loop[col] = (r, g, b, 1.0)
            bm.faces.ensure_lookup_table()
            bm.normal_update()
            if bm.faces[0].normal.z < 0:  # normals up after the axis flip
                bmesh.ops.reverse_faces(bm, faces=bm.faces[:])
            name = "terrain_%d_%d" % (tx, ty)
            me = bpy.data.meshes.new(name)
            bm.to_mesh(me)
            bm.free()
            for p in me.polygons:
                p.use_smooth = True
            me.use_auto_smooth = True
            me.normals_split_custom_set_from_vertices(normals)
            ob = bpy.data.objects.new(name, me)
            bpy.context.scene.collection.objects.link(ob)
            me.color_attributes.active_color = me.color_attributes["Col"]
            me.color_attributes.render_color_index = 0
            me.materials.append(m)
            total += (i1 - i0) * (j1 - j0) * 2
    path = os.path.join(OUT, "terrain.glb")
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", export_yup=True, export_normals=True,
                              export_colors=True, export_materials="EXPORT")
    print("WORLD terrain: %d tris in %d tiles -> %s" % (total, TILES * TILES, path))


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


def wheel(x, y, r, w, hub="trim"):
    """A tyre with tread blocks round it, a rim and a hub cap; axis along X."""
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


terrain()
freighter_wreck()
rover()
buggy()
hauler()
merc_gear()
faction_gear()
marshal_gear()
