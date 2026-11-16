# THE HUNT: the outlands' districts, built in Blender from code.
#   blender -b -P tools/blender/build_districts.py -- <out_dir>
# Futuristic Mars architecture (not Earth's boxes): twisted and lens-shaped
# towers on sky gardens, leaning twin towers joined by a sky bridge, a ring
# habitat on raking pylons, the Prism Galleria (a walk-in mall under a ribbed
# glass vault), cantilevered pod homes, the Skyport's pads, tower and
# shuttle, and the street furniture (solar trees, holo signs, lamps,
# planters, monorail pylons and cars).
#
# Same conventions as build_outpost_kit.py (Y-up glTF, metres, origin at the
# floor centre, front -Y in Blender = +Z in Godot). Material names carry the
# look into the game's cel shader (Comic.kit_mesh): "glass*" reflects the sky
# and lights up at night, "light_*"/"neon*" glow, "steel"/"chrome" are bare
# metal. Detail parts are named "d_*": walk-in pieces also export a
# "<piece>_col.glb" without them (KitCollision prefers it), so trims and
# fins don't snag you.
import bpy, bmesh, math, sys, os
sys.path.insert(0, os.path.dirname(__file__))
import build_outpost_kit as K  # noqa: E402

OUT = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "/tmp/districts"
os.makedirs(OUT, exist_ok=True)
K.OUT = OUT

MORE = {
    "concrete": (0.78, 0.74, 0.7, 1), "steel": (0.55, 0.58, 0.63, 1), "chrome": (0.8, 0.82, 0.86, 1),
    "copper": (0.78, 0.42, 0.22, 1), "teal": (0.1, 0.66, 0.62, 1), "solar": (0.07, 0.12, 0.3, 1),
    "glass_dark": (0.12, 0.36, 0.5, 1), "glass_warm": (0.95, 0.72, 0.45, 1),
    "neon_cyan": (0.2, 0.95, 1.0, 1), "neon_pink": (1.0, 0.2, 0.62, 1), "light_warm": (1.0, 0.86, 0.6, 1),
    "green": (0.25, 0.62, 0.22, 1), "green_dark": (0.12, 0.4, 0.14, 1), "sand": (0.86, 0.66, 0.46, 1),
    "wood": (0.55, 0.33, 0.18, 1),
}
K.COLORS.update(MORE)


def reset():
    K.reset()


def m(o, name):
    o.data.materials.clear()
    o.data.materials.append(bpy.data.materials[name])


# --- shapes -----------------------------------------------------------------

def rbox(name, size, loc, mat, bevel=0.06, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc, rotation=rot)
    o = bpy.context.object
    o.name = name
    o.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel > 0:
        b = o.modifiers.new("bevel", "BEVEL")
        b.width = min(bevel, min(size) * 0.45)
        b.segments = 1
        b.limit_method = "ANGLE"
        bpy.ops.object.modifier_apply(modifier="bevel")
    m(o, mat)
    return o


def cyl(name, r, h, loc, mat, verts=16, rot=(0, 0, 0), cap=True):
    return K.cyl(name, r, h, loc, mat, verts=verts, rot=rot, cap=cap)


def prism(name, pts, z0, h, mat, rot=0.0, off=(0.0, 0.0), top_scale=1.0, cap=True):
    """A polygon (x, y points, CCW) extruded from z0 up h; `rot` turns it,
    `top_scale` tapers the top."""
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    c, s = math.cos(rot), math.sin(rot)
    lo, hi = [], []
    for x, y in pts:
        rx, ry = x * c - y * s, x * s + y * c
        lo.append(bm.verts.new((rx + off[0], ry + off[1], z0)))
        hi.append(bm.verts.new((rx * top_scale + off[0], ry * top_scale + off[1], z0 + h)))
    n = len(pts)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new([lo[i], lo[j], hi[j], hi[i]])
    if cap:
        bm.faces.new(list(reversed(lo)))
        bm.faces.new(hi)
    bm.normal_update()
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    me.materials.append(bpy.data.materials[mat])
    return o


def superellipse(a, b, n=4.0, count=24):
    """A rounded square/oval footprint (half-sizes a, b)."""
    pts = []
    for i in range(count):
        t = i * math.tau / count
        ct, st = math.cos(t), math.sin(t)
        x = a * math.copysign(abs(ct) ** (2.0 / n), ct)
        y = b * math.copysign(abs(st) ** (2.0 / n), st)
        pts.append((x, y))
    return pts


def lens(a, b, count=20):
    """A lens (two arcs meeting at points on the X axis)."""
    pts = []
    for i in range(count):
        t = i * math.tau / count
        x = a * math.cos(t)
        y = b * math.sin(t) * (1.0 - 0.35 * abs(math.cos(t)) ** 3)
        pts.append((x, y))
    return pts


def ring_pts(r, count=24):
    return [(r * math.cos(i * math.tau / count), r * math.sin(i * math.tau / count)) for i in range(count)]


def torus(name, R, r, loc, mat, major=32, minor=8, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_torus_add(major_radius=R, minor_radius=r, major_segments=major, minor_segments=minor,
                                     location=loc, rotation=rot)
    o = bpy.context.object
    o.name = name
    m(o, mat)
    return o


def beam(name, a, b, w, h, mat, bevel=0.04):
    """A box from point a to point b (3D), w wide, h deep."""
    ax, ay, az = a
    bx, by, bz = b
    dx, dy, dz = bx - ax, by - ay, bz - az
    length = math.sqrt(dx * dx + dy * dy + dz * dz)
    o = rbox(name, (w, h, length), ((ax + bx) / 2, (ay + by) / 2, (az + bz) / 2), mat, bevel=bevel)
    # Point the box's Z along the segment.
    yaw = math.atan2(dy, dx)
    pitch = math.acos(max(-1.0, min(1.0, dz / length)))
    o.rotation_euler = (0, pitch, yaw)
    return o


def arc_rib(name, pts, w, mat="steel"):
    """A rib along a polyline of 3D points (beams joined end to end)."""
    for i in range(len(pts) - 1):
        beam("%s_%d" % (name, i), pts[i], pts[i + 1], w, w, mat, bevel=0.0)


def finish(piece, col=False):
    if col:
        export_col(piece)
    thicken_open_glass()
    K.finish(piece)


def thicken_open_glass():
    """Open glass surfaces (vault panes, domes, bands) get a thin second
    side: the ink outline pass draws back faces, so a single-sided pane
    seen from behind would be solid ink."""
    for o in list(bpy.context.scene.objects):
        if o.type != "MESH" or not o.data.materials or not o.data.materials[0].name.startswith("glass"):
            continue
        bm = bmesh.new()
        bm.from_mesh(o.data)
        open_edges = any(len(e.link_faces) < 2 for e in bm.edges)
        bm.free()
        if not open_edges:
            continue
        bpy.context.view_layer.objects.active = o
        for s in bpy.context.selected_objects:
            s.select_set(False)
        o.select_set(True)
        mod = o.modifiers.new("solid", "SOLIDIFY")
        mod.thickness = 0.05
        mod.offset = 0.0
        bpy.ops.object.modifier_apply(modifier="solid")


def export_col(piece):
    """The piece's walls and floors without its details (d_*), for collision."""
    bpy.ops.object.select_all(action="DESELECT")
    keep = [o for o in bpy.context.scene.objects if not o.name.startswith("d_")]
    for o in keep:
        o.select_set(True)
    path = os.path.join(OUT, piece + "_col.glb")
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", export_yup=True, export_apply=True,
                              export_materials="NONE", use_selection=True)
    print("KIT %s_col: %d parts -> %s" % (piece, len(keep), path))


# --- Helios Arcology ----------------------------------------------------------

def podium(w, d, h, lobby=True):
    """A tower's base: a rounded podium with a glass lobby and a canopy."""
    prism("podium", superellipse(w / 2, d / 2, 5.0, 28), 0.0, h, "concrete")
    prism("d_podium_cap", superellipse(w / 2 + 0.4, d / 2 + 0.4, 5.0, 28), h, 0.5, "white")
    if lobby:
        prism("d_lobby", superellipse(w / 2 + 0.06, d / 2 + 0.06, 5.0, 28), 0.4, 3.6, "glass_warm", cap=False)
        rbox("d_canopy", (10.0, 4.0, 0.35), (0, -d / 2 - 1.8, 4.4), "white", bevel=0.12)
        for x in (-4.2, 4.2):
            rbox("d_canopy_post", (0.3, 0.3, 4.3), (x, -d / 2 - 3.4, 2.15), "steel", bevel=0.05)
        rbox("d_canopy_light", (9.0, 0.2, 0.08), (0, -d / 2 - 3.6, 4.2), "light_warm", bevel=0.0)
    rbox("d_plinth", (w + 1.2, d + 1.2, 0.4), (0, 0, 0.2), "steel", bevel=0.08)


def twisted_floors(floors, fh, a, b, twist, z0, taper=0.75, shape="square", gardens=(), fins=True):
    for k in range(floors):
        t = k / max(floors - 1, 1)
        sc = 1.0 - (1.0 - taper) * t
        rot = math.radians(twist) * t
        aa, bb = a * sc, b * sc
        pts = superellipse(aa, bb, 4.5, 24) if shape == "square" else lens(aa, bb, 22)
        z = z0 + k * fh
        garden = k in gardens
        prism("slab%d" % k, [(x * 1.04, y * 1.04) for x, y in pts], z, 0.45, "white", rot=rot)
        if garden:
            # A sky garden: an open floor of planting behind a glass rail.
            prism("core%d" % k, superellipse(aa * 0.4, bb * 0.4, 4, 12), z + 0.45, fh - 0.45, "concrete", rot=rot)
            for i in range(8):
                ang = rot + i * math.tau / 8
                rr = aa * 0.72
                K.dome("d_tree%d_%d" % (k, i), 1.6, 2.2, (rr * math.cos(ang), rr * math.sin(ang), z + 1.6), "green", verts=8,
                       rings=2)
                cyl("d_trunk%d_%d" % (k, i), 0.18, 1.4, (rr * math.cos(ang), rr * math.sin(ang), z + 1.1), "wood", verts=6)
            prism("d_rail%d" % k, [(x * 1.02, y * 1.02) for x, y in pts], z + 0.45, 1.1, "glass", rot=rot, cap=False)
        else:
            prism("glass%d" % k, pts, z + 0.45, fh - 0.45, "glass" if k % 7 else "glass_dark", rot=rot)
        if fins:
            for i in range(4 if shape == "square" else 2):
                ang = rot + i * math.tau / (4 if shape == "square" else 2) + (math.pi / 4 if shape == "square" else 0)
                rr = (aa if shape == "square" else aa) * (1.18 if shape == "square" else 1.02)
                rbox("d_fin%d_%d" % (k, i), (0.5, 0.5, fh), (rr * math.cos(ang), rr * math.sin(ang), z + fh / 2), "steel",
                     bevel=0.0, rot=(0, 0, ang))


def crown(z, r, needle, beacon=True):
    cyl("d_crown_ring", r, 1.2, (0, 0, z + 0.6), "steel", verts=20, cap=False)
    cyl("d_crown_light", r + 0.05, 0.3, (0, 0, z + 1.0), "neon_cyan", verts=20, cap=False)
    bpy.ops.mesh.primitive_cone_add(vertices=8, radius1=r * 0.35, radius2=0.08, depth=needle, location=(0, 0, z + needle / 2))
    o = bpy.context.object
    o.name = "d_needle"
    m(o, "chrome")
    if beacon:
        rbox("d_beacon", (0.6, 0.6, 0.6), (0, 0, z + needle + 0.3), "neon_pink", bevel=0.1)


def spire_a():
    """Helios' centre tower: a twisting rounded-square shaft (~100 m)."""
    reset()
    podium(34, 34, 8.0)
    twisted_floors(24, 3.6, 11.0, 11.0, 60.0, 8.5, taper=0.72, gardens=(8, 16))
    crown(8.5 + 24 * 3.6, 6.0, 18.0)
    finish("spire_a")


def spire_b():
    """A lens-shaped tower with a cantilevered sky deck near the top."""
    reset()
    podium(30, 20, 6.0)
    twisted_floors(18, 3.6, 13.0, 7.5, 0.0, 6.5, taper=0.9, shape="lens", gardens=(9,))
    top = 6.5 + 18 * 3.6
    # Sky deck: a glass-floored box sticking out over the plaza.
    rbox("deck", (10.0, 8.0, 0.6), (0, -9.5, top - 7.0), "white", bevel=0.15)
    prism("d_deck_rail", superellipse(5.0, 4.0, 6, 16), top - 6.7, 1.1, "glass", off=(0, -9.5), cap=False)
    rbox("d_deck_strut", (0.4, 9.0, 0.4), (0, -6.0, top - 10.0), "steel", bevel=0.0, rot=(math.radians(40), 0, 0))
    # A vertical neon spine up the long face.
    rbox("d_spine", (0.3, 0.3, 18 * 3.6), (0, -7.6, 6.5 + 9 * 3.6), "neon_pink", bevel=0.0)
    crown(top, 5.0, 10.0)
    finish("spire_b")


def arc_towers():
    """Twin towers leaning together, joined at the top by a sky bridge."""
    reset()
    floors, fh = 16, 3.6
    for side in (-1, 1):
        prism("base%d" % side, superellipse(9, 8, 4, 16), 0.0, 5.0, "concrete", off=(side * 20.0, 0))
        for k in range(floors):
            t = k / (floors - 1)
            x = side * (20.0 - 9.0 * t * t)  # leaning in, more towards the top
            z = 5.0 + k * fh
            pts = superellipse(6.5, 7.5, 4.5, 16)
            prism("slab%d_%d" % (side, k), [(px * 1.05, py * 1.05) for px, py in pts], z, 0.4, "white", off=(x, 0))
            prism("glass%d_%d" % (side, k), pts, z + 0.4, fh - 0.4, "glass", off=(x, 0))
            rbox("d_band%d_%d" % (side, k), (0.3, 15.6, fh), (x - side * 6.6, 0, z + fh / 2), "copper", bevel=0.0)
    top = 5.0 + floors * fh
    rbox("bridge", (24.0, 12.0, 7.0), (0, 0, top + 1.0), "white", bevel=0.4)
    rbox("d_bridge_glass", (24.2, 12.2, 3.0), (0, 0, top + 1.2), "glass_dark", bevel=0.2)
    rbox("d_bridge_light", (24.3, 0.2, 0.25), (0, -6.15, top - 1.0), "neon_cyan", bevel=0.0)
    for side in (-1, 1):
        rbox("d_roof%d" % side, (14.0, 16.0, 0.6), (side * 11.0, 0, top + 4.8), "steel", bevel=0.1)
        cyl("d_mast%d" % side, 0.2, 12.0, (side * 11.0, 2.0, top + 11.0), "chrome", verts=6)
        rbox("d_mast_light%d" % side, (0.5, 0.5, 0.5), (side * 11.0, 2.0, top + 17.2), "neon_pink", bevel=0.1)
    finish("arc_towers")


def ring_hab():
    """A ring habitat 60 m across held 22 m up on raking pylons, with a lift
    core in the middle and spokes out to the ring."""
    reset()
    R, r, z = 30.0, 4.6, 22.0
    torus("ring", R, r, (0, 0, z), "white", major=40, minor=10)
    cyl("d_ring_glass_out", R + r * 0.92, 2.2, (0, 0, z), "glass", verts=40, cap=False)
    cyl("d_ring_glass_in", R - r * 0.92, 1.6, (0, 0, z), "glass_warm", verts=40, cap=False)
    cyl("d_ring_light", R + r + 0.05, 0.25, (0, 0, z - 2.4), "neon_cyan", verts=40, cap=False)
    for i in range(6):
        a = i * math.tau / 6
        foot = (math.cos(a) * (R + 12), math.sin(a) * (R + 12), 0.0)
        head = (math.cos(a) * R, math.sin(a) * R, z - r + 0.4)
        beam("pylon%d" % i, foot, head, 1.6, 1.6, "steel", bevel=0.2)
        cyl("d_foot%d" % i, 2.0, 1.2, (foot[0], foot[1], 0.6), "concrete", verts=10)
    for i in range(3):
        a = i * math.tau / 3 + 0.5
        beam("spoke%d" % i, (math.cos(a) * 4.5, math.sin(a) * 4.5, z), (math.cos(a) * (R - r), math.sin(a) * (R - r), z),
             2.8, 2.6, "white", bevel=0.3)
        beam("d_spoke_glass%d" % i, (math.cos(a) * 4.5, math.sin(a) * 4.5, z + 0.2),
             (math.cos(a) * (R - r), math.sin(a) * (R - r), z + 0.2), 2.9, 1.2, "glass", bevel=0.0)
    cyl("core", 4.5, z + 8.0, (0, 0, (z + 8.0) / 2), "concrete", verts=20)
    cyl("d_core_glass", 4.55, z + 6.0, (0, 0, (z + 6.0) / 2 + 0.5), "glass", verts=20, cap=False)
    K.dome("d_core_cap", 5.0, 2.5, (0, 0, z + 8.0), "chrome", verts=20, rings=3)
    finish("ring_hab")


# --- The Prism Galleria ------------------------------------------------------
# 100 x 38 m, long along X. A 14 m concourse down the middle under a ribbed
# glass barrel vault; shop units either side (10 m bays, 9 m deep, open to
# the concourse); a glass-domed atrium with a fountain at the centre;
# entrances at both ends behind sweeping portal arches.
G_LEN, G_HALF_W, G_CONC = 100.0, 19.0, 7.0  # length, half width, concourse half width
G_UNIT_H = 6.0


def galleria():
    reset()
    L2 = G_LEN / 2
    rbox("floor", (G_LEN, G_HALF_W * 2, 0.3), (0, 0, 0.15), "concrete", bevel=0.0)
    prism("d_floor_inlay", superellipse(L2 - 6, G_CONC - 1.5, 6, 24), 0.3, 0.02, "sand")
    t = 0.4
    # Outer long walls (shop backs) and the unit roofs.
    for s in (-1, 1):
        rbox("outer%d" % s, (G_LEN, t, G_UNIT_H), (0, s * (G_HALF_W - t / 2), G_UNIT_H / 2), "white", bevel=0.0)
        rbox("roof%d" % s, (G_LEN, G_HALF_W - G_CONC, 0.5), (0, s * (G_CONC + (G_HALF_W - G_CONC) / 2), G_UNIT_H + 0.25),
             "concrete", bevel=0.0)
        # The fascia over the shops (facing the concourse), lit.
        rbox("d_fascia%d" % s, (G_LEN - 2, 0.4, 1.4), (0, s * G_CONC, G_UNIT_H - 0.7), "white", bevel=0.08)
        rbox("d_fascia_light%d" % s, (G_LEN - 3, 0.1, 0.12), (0, s * (G_CONC - 0.22), G_UNIT_H - 1.3), "light_warm", bevel=0.0)
        # Unit dividers (bays of 10 m), skipping the atrium.
        for k in range(11):
            x = -L2 + k * 10.0
            if abs(x) < 12.5:
                continue
            rbox("div%d_%d" % (s, k), (0.3, G_HALF_W - G_CONC, G_UNIT_H), (x, s * (G_CONC + (G_HALF_W - G_CONC) / 2), G_UNIT_H / 2),
                 "white", bevel=0.0)
        # Outside: copper fins and a long light strip along the walls.
        for k in range(26):
            x = -L2 + 2 + k * 3.84
            rbox("d_ofin%d_%d" % (s, k), (0.25, 0.9, G_UNIT_H + 1.0), (x, s * (G_HALF_W + 0.45), (G_UNIT_H + 1.0) / 2), "copper",
                 bevel=0.0)
        rbox("d_ostrip%d" % s, (G_LEN, 0.12, 0.2), (0, s * (G_HALF_W + 0.95), G_UNIT_H - 0.4), "neon_cyan", bevel=0.0)
        # Solar roof.
        for k in range(8):
            rbox("d_solar%d_%d" % (s, k), (10.0, 8.0, 0.15), (-36 + k * 10.3, s * (G_CONC + 6.0), G_UNIT_H + 1.1), "solar",
                 bevel=0.0, rot=(math.radians(-12 * s), 0, 0))
    # Shop units: back counters and displays (deco: the game puts keepers and
    # its own counters where Career shops are).
    for s in (-1, 1):
        for k in range(10):
            x = -L2 + 5.0 + k * 10.0
            if abs(x) < 12.5:
                continue
            y = s * (G_HALF_W - 1.0)
            rbox("d_shelf%d_%d" % (s, k), (8.0, 0.8, 2.6), (x, y, 1.6), "steel", bevel=0.04)
            for j in range(5):
                rbox("d_goods%d_%d_%d" % (s, k, j), (1.2, 0.5, 0.5), (x - 3.0 + j * 1.5, y - s * 0.1, 2.2 + (j % 2) * 0.7),
                     ("teal", "magenta", "trim", "copper", "neon_cyan")[(j + k) % 5], bevel=0.05)
            rbox("counter%d_%d" % (s, k), (4.0, 0.9, 1.05), (x, s * (G_CONC + 3.2), 0.6), "white", bevel=0.08)
            rbox("d_counter_top%d_%d" % (s, k), (4.2, 1.1, 0.08), (x, s * (G_CONC + 3.2), 1.16), "wood", bevel=0.02)
            rbox("d_sign%d_%d" % (s, k), (6.0, 0.12, 0.8), (x, s * (G_CONC - 0.25), G_UNIT_H - 0.75),
                 ("neon_cyan", "neon_pink", "light_warm")[(k + (s > 0)) % 3], bevel=0.0)
    # The vault: glass panels between steel ribs (half-cylinder over the concourse).
    seg = 10
    for k in range(seg):
        a0 = math.pi * k / seg
        a1 = math.pi * (k + 1) / seg
        y0, z0 = -math.cos(a0) * G_CONC, G_UNIT_H + math.sin(a0) * G_CONC * 0.9
        y1, z1 = -math.cos(a1) * G_CONC, G_UNIT_H + math.sin(a1) * G_CONC * 0.9
        for half in (-1, 1):
            cx = half * (L2 + 12.5) / 2
            length = L2 - 12.5
            me = bpy.data.meshes.new("vault")
            bm = bmesh.new()
            v = [bm.verts.new((cx - length / 2, y0, z0)), bm.verts.new((cx + length / 2, y0, z0)),
                 bm.verts.new((cx + length / 2, y1, z1)), bm.verts.new((cx - length / 2, y1, z1))]
            bm.faces.new(v)
            bm.to_mesh(me)
            bm.free()
            o = bpy.data.objects.new("vault%d_%d" % (k, half), me)
            bpy.context.scene.collection.objects.link(o)
            me.materials.append(bpy.data.materials["glass"])
    for k in range(17):
        x = -L2 + 2 + k * 6.0
        if abs(x) < 12.5:
            continue
        arc_rib("d_rib%d" % k, [(x, -math.cos(math.pi * i / 10) * G_CONC, G_UNIT_H + math.sin(math.pi * i / 10) * G_CONC * 0.9)
                                 for i in range(11)], 0.3)
    rbox("d_spine", (G_LEN - 25, 0.4, 0.4), (0, 0, G_UNIT_H + G_CONC * 0.9), "steel", bevel=0.0)
    # The atrium: a glass dome on a ring beam, a fountain under it.
    cyl("atrium_ring", 12.6, 1.2, (0, 0, G_UNIT_H + 0.6), "white", verts=28, cap=False)
    K.dome("atrium_dome", 12.5, 9.0, (0, 0, G_UNIT_H + 1.2), "glass", verts=28, rings=5)
    for i in range(12):
        a = i * math.tau / 12
        arc_rib("d_dome_rib%d" % i, [(12.55 * math.cos(math.pi / 2 * j / 8) * math.cos(a),
                                      12.55 * math.cos(math.pi / 2 * j / 8) * math.sin(a),
                                      G_UNIT_H + 1.2 + 9.0 * math.sin(math.pi / 2 * j / 8)) for j in range(9)], 0.25)
    for i in range(8):
        a = i * math.tau / 8 + math.pi / 8
        cyl("atrium_col%d" % i, 0.35, G_UNIT_H, (12.0 * math.cos(a), 12.0 * math.sin(a), G_UNIT_H / 2), "steel", verts=10)
    cyl("fountain", 4.0, 0.7, (0, 0, 0.65), "white", verts=24)
    cyl("d_water", 3.6, 0.1, (0, 0, 1.0), "glass", verts=24)
    cyl("d_spout", 0.5, 2.4, (0, 0, 1.8), "chrome", verts=10)
    K.dome("d_spout_bowl", 1.4, 0.5, (0, 0, 3.0), "chrome", verts=14, rings=2)
    for i in range(6):
        a = i * math.tau / 6
        rbox("d_bench%d" % i, (2.8, 0.7, 0.45), (7.5 * math.cos(a), 7.5 * math.sin(a), 0.5), "wood", bevel=0.05,
             rot=(0, 0, a + math.pi / 2))
        K.dome("d_planter%d" % i, 1.0, 1.4, (8.5 * math.cos(a + 0.5), 8.5 * math.sin(a + 0.5), 0.9), "green", verts=8, rings=2)
        cyl("d_pot%d" % i, 1.0, 0.9, (8.5 * math.cos(a + 0.5), 8.5 * math.sin(a + 0.5), 0.45), "concrete", verts=10)
    # The atrium's side bays (glass walls to the outside).
    for s in (-1, 1):
        rbox("atrium_wall%d" % s, (25.0, t, G_UNIT_H), (0, s * (G_HALF_W - t / 2), G_UNIT_H / 2), "glass", bevel=0.0)
    # Entrances: portal arches at both ends, an air curtain (lit frame).
    for e in (-1, 1):
        x = e * L2
        for s in (-1, 1):
            rbox("end_wall%d_%d" % (e, s), (t, G_HALF_W - G_CONC - 2.0, G_UNIT_H),
                 (x, s * (G_CONC + 2.0 + (G_HALF_W - G_CONC - 2.0) / 2), G_UNIT_H / 2), "white", bevel=0.0)
            rbox("d_curtain_post%d_%d" % (e, s), (0.6, 0.6, G_UNIT_H + 4.0), (x, s * (G_CONC + 1.6), (G_UNIT_H + 4.0) / 2),
                 "steel", bevel=0.1)
            rbox("d_curtain_glow%d_%d" % (e, s), (0.2, 0.2, G_UNIT_H + 3.0), (x + e * 0.32, s * (G_CONC + 1.6),
                 (G_UNIT_H + 3.0) / 2), "neon_cyan", bevel=0.0)
        # The end of the vault, glass, above the door.
        prism("vault_end%d" % e, [(-G_CONC, G_UNIT_H + 4.0), (G_CONC, G_UNIT_H + 4.0), (0, G_UNIT_H + G_CONC * 0.9)], 0, 0.2,
              "glass", rot=0.0)
        o = bpy.context.object
        o.rotation_euler = (math.pi / 2, 0, math.pi / 2)
        o.location = (x, 0, 0)
        rbox("d_lintel%d" % e, (1.0, G_CONC * 2 + 4.0, 1.2), (x, 0, G_UNIT_H + 3.4), "white", bevel=0.2)
        rbox("d_name%d" % e, (0.3, 10.0, 1.6), (x + e * 0.6, 0, G_UNIT_H + 5.2), "neon_pink", bevel=0.0)
        # A sweeping portal arch outside.
        torus("d_portal%d" % e, G_CONC + 6.0, 0.6, (x + e * 4.0, 0, 0), "chrome", major=28, minor=6,
              rot=(math.pi / 2, 0, math.pi / 2))
        o = bpy.context.object
        o.scale = (1, 1.4, 1)
        rbox("d_steps%d" % e, (3.0, G_CONC * 2 + 2, 0.25), (x + e * 1.6, 0, 0.12), "concrete", bevel=0.0)
    finish("galleria", col=True)


# --- Nova Terrace: pod homes -------------------------------------------------

def pod_house(name, accent):
    """A walk-in home: a ground room (door at the front, glass wall, bed,
    locker, table) and a long cantilevered pod over it with a ribbon window,
    a roof terrace and solar sails."""
    reset()
    w, d, h, t = 9.0, 8.0, 3.4, 0.25
    door = 1.8
    rbox("floor", (w, d, 0.3), (0, 0, 0.15), "concrete", bevel=0.0)
    rbox("back", (w, t, h), (0, d / 2 - t / 2, h / 2), "white", bevel=0.0)
    for x in (-w / 2 + t / 2, w / 2 - t / 2):
        rbox("side", (t, d, h), (x, 0, h / 2), "white", bevel=0.0)
    side_w = (w - door) / 2
    for s in (-1, 1):
        cx = s * (door / 2 + side_w / 2)
        rbox("front_glass%d" % s, (side_w, 0.12, h - 0.4), (cx, -d / 2 + 0.06, (h - 0.4) / 2 + 0.3), "glass", bevel=0.0)
        rbox("d_mullion%d" % s, (0.12, 0.2, h), (s * (door / 2 + side_w / 2), -d / 2 + 0.06, h / 2), "steel", bevel=0.0)
    rbox("ceiling", (w, d, 0.4), (0, 0, h + 0.2), "white", bevel=0.0)
    rbox("d_door_frame", (door + 0.5, 0.3, 0.3), (0, -d / 2, h - 0.2), accent, bevel=0.05)
    for s in (-1, 1):
        rbox("d_door_glow%d" % s, (0.1, 0.1, h - 0.6), (s * (door / 2 + 0.15), -d / 2 - 0.12, (h - 0.6) / 2 + 0.3), "neon_cyan",
             bevel=0.0)
    # Inside.
    rbox("d_bed", (2.0, 3.2, 0.55), (-w / 2 + 1.4, d / 2 - 2.0, 0.55), accent, bevel=0.12)
    rbox("d_pillow", (1.4, 0.5, 0.2), (-w / 2 + 1.4, d / 2 - 0.8, 0.9), "white", bevel=0.08)
    rbox("locker", (1.2, 0.7, 2.0), (w / 2 - 1.0, d / 2 - 0.6, 1.3), "steel", bevel=0.05)
    rbox("d_table", (1.4, 1.0, 0.08), (1.0, 0.0, 1.0), "wood", bevel=0.02)
    cyl("d_table_leg", 0.08, 0.7, (1.0, 0.0, 0.6), "steel", verts=6)
    rbox("d_lamp", (1.6, 0.4, 0.06), (0, 0, h - 0.04), "light_warm", bevel=0.0)
    # The pod: cantilevered 3.5 m out over the side.
    px = 2.0
    rbox("pod", (13.0, 6.0, 3.2), (px, 0.5, h + 2.0), "white", bevel=1.0)
    rbox("d_pod_window", (12.0, 6.1, 1.1), (px, 0.5, h + 2.2), "glass", bevel=0.4)
    rbox("d_pod_stripe", (13.05, 6.05, 0.25), (px, 0.5, h + 0.75), accent, bevel=0.1)
    rbox("d_pod_strut", (0.35, 0.35, 3.6), (px + 6.0, 0.5 - 2.0, h / 2 + 0.2), "steel", bevel=0.0, rot=(0, math.radians(-20), 0))
    # The roof terrace: a rail and solar sails.
    prism("d_rail", superellipse(6.2, 2.7, 6, 16), h + 3.6, 1.0, "glass", off=(px, 0.5), cap=False)
    for k in range(3):
        rbox("d_sail%d" % k, (2.6, 1.6, 0.08), (px - 3.5 + k * 3.2, 1.6, h + 4.8), "solar", bevel=0.0,
             rot=(math.radians(28), 0, 0))
        cyl("d_sail_post%d" % k, 0.06, 1.4, (px - 3.5 + k * 3.2, 1.6, h + 4.0), "steel", verts=6)
    K.dome("d_bush", 0.8, 1.0, (px + 4.5, -1.2, h + 3.6), "green", verts=8, rings=2)
    rbox("d_step", (2.4, 1.2, 0.2), (0, -d / 2 - 0.6, 0.1), "concrete", bevel=0.0)
    finish(name, col=True)


# --- Kasei Skyport -----------------------------------------------------------

def landing_pad():
    reset()
    r = 14.0
    prism("pad", ring_pts(r, 6), 0.0, 0.3, "concrete")
    prism("d_pad_edge", ring_pts(r + 0.6, 6), 0.0, 0.25, "steel")
    cyl("d_ring", r * 0.62, 0.04, (0, 0, 0.32), "trim", verts=32, cap=True)
    cyl("d_ring_in", r * 0.56, 0.05, (0, 0, 0.32), "concrete", verts=32, cap=True)
    for k in range(3):
        rbox("d_chevron%d" % k, (1.0, 5.0, 0.04), (-2.5 + k * 2.5, 0, 0.36), "white", bevel=0.0)
    for i in range(6):
        a = i * math.tau / 6
        rbox("d_edge_light%d" % i, (0.5, 0.5, 0.3), ((r + 0.2) * math.cos(a), (r + 0.2) * math.sin(a), 0.4), "neon_cyan",
             bevel=0.1)
    finish("landing_pad")


def control_tower():
    reset()
    cyl("stem", 2.2, 28.0, (0, 0, 14.0), "concrete", verts=16)
    cyl("d_stem_band", 2.3, 0.6, (0, 0, 10.0), "trim", verts=16, cap=False)
    cyl("d_stem_glass", 2.25, 24.0, (0, 0, 13.0), "glass_dark", verts=16, cap=False)
    bpy.ops.mesh.primitive_cone_add(vertices=16, radius1=3.0, radius2=6.5, depth=3.0, location=(0, 0, 29.5))
    o = bpy.context.object
    o.name = "cab_base"
    m(o, "white")
    bpy.ops.mesh.primitive_cone_add(vertices=16, radius1=6.5, radius2=5.5, depth=3.4, location=(0, 0, 32.7),
                                    end_fill_type="NOTHING")
    o = bpy.context.object
    o.name = "d_cab_glass"
    m(o, "glass")
    cyl("cab_roof", 6.0, 0.6, (0, 0, 34.7), "white", verts=16)
    cyl("d_radar_post", 0.25, 2.0, (0, 0, 36.0), "steel", verts=6)
    rbox("d_radar", (4.0, 0.3, 0.9), (0, 0, 37.2), "chrome", bevel=0.1)
    rbox("d_beacon", (0.5, 0.5, 0.5), (0, 0, 38.0), "neon_pink", bevel=0.1)
    finish("control_tower")


def shuttle():
    """A parked orbital shuttle (~26 m): a lifting body, delta wings, twin
    fins, three engine bells, a cockpit canopy, landing legs."""
    reset()
    bpy.ops.mesh.primitive_uv_sphere_add(segments=20, ring_count=10, radius=1.0, location=(0, 0, 5.2))
    o = bpy.context.object
    o.name = "body"
    o.scale = (3.4, 12.5, 2.4)
    bpy.ops.object.transform_apply(scale=True)
    m(o, "white")
    rbox("d_belly", (5.6, 20.0, 0.6), (0, 0.5, 3.2), "dark", bevel=0.25)
    for s in (-1, 1):
        prism("wing%d" % s, [(0, -7), (s * 11.5, 4.5), (s * 11.5, 7.5), (0, 9)] if s > 0 else
              [(0, -7), (0, 9), (s * 11.5, 7.5), (s * 11.5, 4.5)], 3.9, 0.5, "white")
        rbox("d_wing_stripe%d" % s, (0.4, 8.0, 0.55), (s * 6.0, 3.5, 4.2), "magenta", bevel=0.0, rot=(0, 0, s * -0.85))
        rbox("fin%d" % s, (0.4, 5.0, 5.5), (s * 2.2, 8.5, 8.8), "white", bevel=0.15, rot=(math.radians(-25), s * 0.25, 0))
        rbox("d_fin_tip%d" % s, (0.45, 1.5, 0.6), (s * 2.6, 10.5, 11.2), "neon_pink", bevel=0.05)
        rbox("d_leg%d" % s, (0.4, 0.4, 3.4), (s * 2.6, -1.0, 1.7), "steel", bevel=0.0)
        rbox("d_foot%d" % s, (1.2, 1.6, 0.25), (s * 2.6, -1.0, 0.12), "steel", bevel=0.05)
    rbox("d_nose_leg", (0.4, 0.4, 3.0), (0, -8.5, 1.5), "steel", bevel=0.0)
    rbox("d_nose_foot", (1.0, 1.0, 0.25), (0, -8.5, 0.12), "steel", bevel=0.05)
    rbox("d_canopy", (2.6, 3.0, 1.0), (0, -8.2, 7.0), "glass_dark", bevel=0.4)
    for x in (-1.6, 0.0, 1.6):
        cyl("d_engine%d" % x, 0.9, 1.6, (x, 12.6, 5.2), "steel", verts=12, rot=(math.pi / 2, 0, 0))
        cyl("d_engine_glow%d" % x, 0.65, 0.2, (x, 13.45, 5.2), "light_warm", verts=12, rot=(math.pi / 2, 0, 0))
    rbox("d_hatch", (0.1, 2.0, 1.8), (3.3, -2.0, 5.0), "trim", bevel=0.05)
    rbox("d_ramp", (2.2, 4.0, 0.15), (4.6, -2.0, 1.9), "steel", bevel=0.0, rot=(0, math.radians(-40), 0))
    finish("shuttle")


# --- street furniture ------------------------------------------------------

def solar_tree():
    reset()
    cyl("trunk", 0.35, 7.0, (0, 0, 3.5), "steel", verts=10)
    cyl("d_base", 1.4, 0.6, (0, 0, 0.3), "concrete", verts=12)
    K.dome("d_bed", 1.3, 0.6, (0, 0, 0.6), "green", verts=12, rings=2)
    for i in range(5):
        a = i * math.tau / 5
        tip = (2.8 * math.cos(a), 2.8 * math.sin(a), 6.5 + (i % 2) * 1.4)
        beam("d_branch%d" % i, (0, 0, 5.5), tip, 0.18, 0.18, "steel", bevel=0.0)
        prism("d_panel%d" % i, ring_pts(1.5, 6), tip[2] + 0.05, 0.12, "solar", off=(tip[0], tip[1]))
        prism("d_glow%d" % i, ring_pts(1.3, 6), tip[2] - 0.05, 0.08, "light_warm", off=(tip[0], tip[1]))
    finish("solar_tree")


def holo_sign():
    reset()
    rbox("post", (0.6, 0.6, 8.0), (0, 0, 4.0), "steel", bevel=0.1)
    rbox("d_frame", (4.4, 0.5, 2.6), (0, 0, 6.6), "dark", bevel=0.12)
    rbox("d_screen", (4.0, 0.56, 2.2), (0, 0, 6.6), "neon_cyan", bevel=0.0)
    rbox("d_screen_band", (4.02, 0.58, 0.3), (0, 0, 6.0), "neon_pink", bevel=0.0)
    cyl("d_foot", 0.9, 0.4, (0, 0, 0.2), "concrete", verts=10)
    finish("holo_sign")


def lamp_neo():
    reset()
    cyl("pole", 0.12, 6.0, (0, 0, 3.0), "steel", verts=8)
    beam("d_arm", (0, 0, 5.8), (0, -1.8, 6.6), 0.16, 0.16, "steel", bevel=0.0)
    rbox("d_head", (0.5, 1.6, 0.18), (0, -2.0, 6.6), "white", bevel=0.06)
    rbox("d_bar", (0.36, 1.4, 0.06), (0, -2.0, 6.5), "light_warm", bevel=0.0)
    rbox("d_ring", (0.3, 0.3, 0.12), (0, 0, 1.2), "neon_cyan", bevel=0.0)
    finish("lamp_neo")


def planter():
    reset()
    prism("bowl", superellipse(2.2, 1.2, 4, 16), 0.0, 0.9, "concrete")
    prism("d_soil", superellipse(2.0, 1.0, 4, 16), 0.9, 0.05, "wood")
    for i, (x, r, hh) in enumerate(((-1.1, 0.8, 1.0), (0.0, 1.0, 1.4), (1.1, 0.7, 0.9))):
        K.dome("d_bush%d" % i, r, hh, (x, 0, 0.9), "green" if i != 1 else "green_dark", verts=8, rings=2)
    finish("planter")


def mono_pylon():
    reset()
    cyl("stem", 0.8, 9.0, (0, 0, 4.5), "concrete", verts=12)
    rbox("d_head", (1.6, 4.0, 1.0), (0, 0, 9.4), "white", bevel=0.25)
    for s in (-1, 1):
        beam("d_brace%d" % s, (0, 0, 6.5), (0, s * 1.8, 9.0), 0.4, 0.4, "steel", bevel=0.0)
    cyl("d_foot", 1.4, 0.5, (0, 0, 0.25), "steel", verts=12)
    finish("mono_pylon")


def mono_car():
    """A monorail car (~13 m): a rounded capsule with a ribbon window, a
    nose cone at the front (-Y), a lit band."""
    reset()
    rbox("body", (2.8, 13.0, 2.8), (0, 0, 1.8), "white", bevel=1.1)
    rbox("d_window", (2.85, 11.5, 0.9), (0, 0.3, 2.2), "glass", bevel=0.4)
    rbox("d_band", (2.86, 12.6, 0.18), (0, 0, 1.25), "neon_cyan", bevel=0.05)
    rbox("d_stripe", (2.86, 12.6, 0.3), (0, 0, 0.9), "magenta", bevel=0.1)
    rbox("d_bogie", (1.6, 10.0, 0.8), (0, 0, 0.1), "steel", bevel=0.1)
    rbox("d_nose", (2.0, 1.0, 1.0), (0, -6.6, 2.3), "glass_dark", bevel=0.4)
    finish("mono_car")


if __name__ == "__main__":
    for build in (spire_a, spire_b, arc_towers, ring_hab, galleria, landing_pad, control_tower, shuttle, solar_tree, holo_sign,
                  lamp_neo, planter, mono_pylon, mono_car):
        build()
    for name, accent in (("pod_a", "teal"), ("pod_b", "magenta"), ("pod_c", "trim")):
        pod_house(name, accent)
