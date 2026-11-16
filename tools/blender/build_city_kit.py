# THE HUNT: Tharsis Gate city pieces, built in Blender from code (same
# conventions as build_outpost_kit.py: Y-up glTF, metres, origin at the
# floor centre; each piece's front faces -Y in Blender, +Z in Godot).
#   blender -b -P tools/blender/build_city_kit.py -- <out_dir>
# Comic with realism: the walls, floors and counters stay where the game
# expects them (shops, collision); bevelled edges, framed glass, kick
# plates, wall lamps, lit signs, roof plant and pipes are details ("d_*",
# left out of the walk-in pieces' collision: <piece>_col.glb).
import bpy, math, sys, os
sys.path.insert(0, os.path.dirname(__file__))
import build_districts as D  # noqa: E402  (shared helpers, materials, collision export)
from build_districts import rbox, cyl, finish  # noqa: E402
import build_outpost_kit as K  # noqa: E402

# Blender: -Y is the front (it becomes +Z, towards the plaza, in Godot).


def ac_unit(x, y, z):
    rbox("d_ac", (1.6, 1.1, 0.9), (x, y, z + 0.45), "steel", bevel=0.06)
    cyl("d_ac_fan", 0.42, 0.06, (x, y, z + 0.93), "dark", verts=12)
    rbox("d_ac_grille", (0.04, 1.0, 0.6), (x - 0.82, y, z + 0.45), "dark", bevel=0.0)


def framed_window(x, y, z, w, h, depth_sign=-1):
    """A window with a steel frame, a mullion and a white sill, in a wall
    whose face is at y (front: depth_sign -1)."""
    rbox("d_win_frame", (w + 0.24, 0.14, h + 0.24), (x, y + depth_sign * 0.03, z), "steel", bevel=0.03)
    rbox("win", (w, 0.16, h), (x, y + depth_sign * 0.05, z), "glass", bevel=0.0)
    rbox("d_mullion", (0.08, 0.18, h), (x, y + depth_sign * 0.06, z), "steel", bevel=0.0)
    rbox("d_sill", (w + 0.4, 0.3, 0.1), (x, y + depth_sign * 0.15, z - h / 2 - 0.12), "white", bevel=0.03)


def shopfront():
    """A walk-in shop: an open doorway, a lit room with a counter and stocked
    shelves, and an upper storey above the ceiling slab."""
    D.reset()
    w, d, h = 12.0, 8.0, 7.5
    t = 0.3          # wall thickness
    g = 3.6          # ground-floor ceiling height
    door = 2.4       # doorway width
    fy = -d / 2 + t / 2  # the front wall's centre line
    rbox("floor", (w, d, 0.2), (0, 0, 0.1), "dark", bevel=0.0)
    rbox("plinth", (w + 0.4, d + 0.4, 0.3), (0, 0, 0.05), "dark", bevel=0.05)
    rbox("back", (w, t, g), (0, d / 2 - t / 2, g / 2), "hull", bevel=0.0)
    for x in (-w / 2 + t / 2, w / 2 - t / 2):
        rbox("side", (t, d, g), (x, 0, g / 2), "hull", bevel=0.0)
    side_w = (w - door) / 2
    for s in (-1, 1):
        cx = s * (door / 2 + side_w / 2)
        rbox("front_low", (side_w, t, 0.9), (cx, fy, 0.45), "hull", bevel=0.04)
        rbox("front_pier", (0.5, t + 0.1, g), (s * (w / 2 - 0.25), fy, g / 2), "hull", bevel=0.08)
        rbox("front_pier", (0.4, t + 0.1, g), (s * (door / 2 + 0.2), fy, g / 2), "hull", bevel=0.06)
        rbox("glass", (side_w - 0.9, 0.08, 2.2), (cx, fy, 2.0), "glass", bevel=0.0)
        # Window frame, a mullion, a kick plate below.
        rbox("d_frame_top", (side_w - 0.8, 0.2, 0.12), (cx, fy - 0.05, 3.12), "steel", bevel=0.02)
        rbox("d_frame_bot", (side_w - 0.8, 0.24, 0.12), (cx, fy - 0.06, 0.9), "steel", bevel=0.02)
        rbox("d_mullion", (0.1, 0.2, 2.2), (cx, fy - 0.05, 2.0), "steel", bevel=0.0)
        rbox("d_kick", (side_w - 0.5, 0.06, 0.6), (cx, fy - t / 2 - 0.03, 0.4), "steel", bevel=0.01)
        # A wall lamp either side of the door.
        rbox("d_lamp_box", (0.26, 0.2, 0.4), (s * (door / 2 + 0.6), fy - 0.22, 2.7), "dark", bevel=0.04)
        rbox("d_lamp_face", (0.2, 0.06, 0.3), (s * (door / 2 + 0.6), fy - 0.33, 2.7), "light_warm", bevel=0.0)
        # Downpipe on the corner, a utility box on the side.
        cyl("d_downpipe", 0.08, h, (s * (w / 2 + 0.12), fy + 0.2, h / 2), "steel", verts=8)
        rbox("d_utility", (0.2, 0.7, 0.9), (s * (w / 2 + 0.12), 1.5, 1.4), "steel", bevel=0.04)
    rbox("lintel", (door, t, g - 2.9), (0, fy, 2.9 + (g - 2.9) / 2), "hull", bevel=0.0)
    rbox("d_door_frame", (door + 0.3, 0.36, 0.16), (0, fy - 0.03, 2.86), "steel", bevel=0.03)
    for s in (-1, 1):
        rbox("d_door_jamb", (0.14, 0.36, 2.8), (s * (door / 2 + 0.05), fy - 0.03, 1.4), "steel", bevel=0.02)
        # The sliding door, parked open inside the wall.
        rbox("d_door_leaf", (door / 2, 0.06, 2.6), (s * (door / 2 + door / 4 + 0.1), fy + 0.25, 1.4), "glass", bevel=0.0)
    # The ceiling slab, then the upper storey and roof.
    rbox("ceiling", (w, d, 0.35), (0, 0, g + 0.175), "trim", bevel=0.0)
    up = h - g - 0.35
    rbox("upper", (w, d, up), (0, 0, g + 0.35 + up / 2), "hull", bevel=0.12)
    rbox("d_floor_band", (w + 0.16, d + 0.16, 0.4), (0, 0, g + 0.175), "trim", bevel=0.06)
    rbox("d_cornice", (w + 0.7, d + 0.7, 0.45), (0, 0, h + 0.22), "white", bevel=0.12)
    rbox("d_cornice_light", (w + 0.74, 0.08, 0.1), (0, -d / 2 - 0.37, h - 0.04), "neon_cyan", bevel=0.0)
    for z in (5.0, 6.4):  # panel seams round the upper storey
        rbox("d_seam", (w + 0.03, d + 0.03, 0.05), (0, 0, z), "dark", bevel=0.0)
    for x in (-3.6, 3.6):
        framed_window(x, -d / 2, 5.3, 2.2, 1.3)
    # Inside: a counter across the back half, shelves on the back wall.
    rbox("counter", (6.0, 0.9, 1.05), (0, 1.2, 0.6), "rust", bevel=0.05)
    rbox("counter_top", (6.2, 1.1, 0.1), (0, 1.2, 1.15), "dark", bevel=0.03)
    rbox("d_counter_kick", (6.0, 0.05, 0.2), (0, 0.73, 0.2), "steel", bevel=0.0)
    for z in (0.9, 1.7, 2.5):
        rbox("shelf", (w - 2.0, 0.6, 0.08), (0, d / 2 - t - 0.3, z), "dark", bevel=0.0)
        for i in range(7):
            x = -4.2 + i * 1.4
            rbox("goods", (0.6, 0.4, 0.45), (x, d / 2 - t - 0.3, z + 0.27),
                 ("trim", "magenta", "glass", "teal", "copper")[(i + int(z * 10)) % 5], bevel=0.04)
    for x in (-3.0, 0.0, 3.0):
        rbox("d_lamp", (1.4, 0.4, 0.06), (x, 0, g - 0.06), "light_warm", bevel=0.0)
    # Outside: the awning (ribs and stripes), its posts, the lit sign box.
    for i in range(6):
        x = -w / 2 + 1.2 + i * (w - 2.4) / 5
        rbox("d_awning_rib", (0.08, 2.3, 0.08), (x, -d / 2 - 1.1, 3.38), "steel", bevel=0.0)
    for i in range(5):
        x = -w / 2 + 1.0 + (i + 0.5) * (w - 2.0) / 5
        rbox("awning", ((w - 2.0) / 5 - 0.02, 2.2, 0.14), (x, -d / 2 - 1.1, 3.28), ("magenta", "white")[i % 2], bevel=0.0,
             rot=(math.radians(-8), 0, 0))
    for x in (-w / 2 + 0.8, w / 2 - 0.8):
        cyl("d_post", 0.1, 3.2, (x, -d / 2 - 2.1, 1.6), "steel", verts=8)
    rbox("sign", (w - 3.0, 0.5, 1.3), (0, -d / 2 - 0.3, 6.75), "dark", bevel=0.08)
    rbox("d_sign_face", (w - 3.4, 0.08, 1.0), (0, -d / 2 - 0.58, 6.75), "light_warm", bevel=0.0)
    for z in (6.08, 7.42):
        rbox("d_sign_neon", (w - 2.9, 0.06, 0.06), (0, -d / 2 - 0.56, z), "neon_pink", bevel=0.0)
    # Roof plant: two AC units, a duct, a mast.
    ac_unit(-3.0, 1.6, h + 0.45)
    ac_unit(2.4, 2.0, h + 0.45)
    cyl("d_duct", 0.25, 5.0, (0.0, 2.8, h + 0.75), "steel", verts=10, rot=(0, math.pi / 2, 0))
    cyl("d_mast", 0.05, 2.4, (4.6, -2.6, h + 1.65), "steel", verts=6)
    rbox("d_mast_light", (0.16, 0.16, 0.16), (4.6, -2.6, h + 2.9), "neon_pink", bevel=0.02)
    for x in range(-5, 6, 2):  # parapet rail
        cyl("d_rail_post", 0.04, 0.9, (x, -d / 2 + 0.1, h + 0.9), "steel", verts=6)
    rbox("d_rail", (w - 1.0, 0.06, 0.06), (0, -d / 2 + 0.1, h + 1.35), "steel", bevel=0.0)
    finish("shopfront", col=True)


def market_stall():
    D.reset()
    rbox("counter", (3.4, 1.2, 1.0), (0, 0, 0.5), "wood", bevel=0.05)
    rbox("top", (3.6, 1.4, 0.12), (0, 0, 1.06), "dark", bevel=0.03)
    for x in (-1.7, 1.7):
        for y in (-0.7, 1.3):
            cyl("pole", 0.06, 2.6, (x, y, 1.3), "steel", verts=8)
    for i in range(6):
        rbox("canopy", (0.62, 2.4, 0.1), (-1.55 + i * 0.62, 0.3, 2.65), ("trim", "white")[i % 2], bevel=0.0,
             rot=(math.radians(-10), 0, 0))
    rbox("d_valance", (3.8, 0.06, 0.3), (0, -0.92, 2.5), "magenta", bevel=0.0)
    for i in range(6):  # a string of bulbs under the canopy edge
        rbox("d_bulb", (0.1, 0.1, 0.12), (-1.5 + i * 0.6, -0.9, 2.3), "light_warm", bevel=0.02)
    for i, x in enumerate((-1.1, 0.0, 1.1)):
        rbox("d_crate%d" % i, (0.8, 0.6, 0.3), (x, 0.1, 1.27), "wood", bevel=0.03)
        for k in range(4):  # produce in each crate
            K.dome("d_fruit%d_%d" % (i, k), 0.15, 0.2, (x - 0.24 + k * 0.16, 0.1 + (k % 2) * 0.12 - 0.06, 1.42),
                   ("magenta", "trim", "green", "copper")[(i + k) % 4], verts=8, rings=2)
        rbox("d_price%d" % i, (0.3, 0.04, 0.2), (x, -0.25, 1.6), "light_warm", bevel=0.0)
    finish("market_stall")


def kiosk():
    D.reset()
    rbox("base", (1.4, 1.0, 0.3), (0, 0, 0.15), "dark", bevel=0.06)
    rbox("pillar", (0.9, 0.6, 2.2), (0, 0, 1.4), "white", bevel=0.18)
    rbox("d_bezel", (0.86, 0.1, 1.08), (0, -0.3, 1.8), "dark", bevel=0.04)
    rbox("screen", (0.74, 0.08, 0.94), (0, -0.34, 1.8), "neon_cyan", bevel=0.0)
    rbox("hood", (1.1, 0.8, 0.2), (0, -0.1, 2.6), "trim", bevel=0.08)
    rbox("d_edge", (0.06, 0.62, 2.0), (0.47, 0, 1.4), "neon_pink", bevel=0.0)
    rbox("d_edge2", (0.06, 0.62, 2.0), (-0.47, 0, 1.4), "neon_pink", bevel=0.0)
    rbox("beacon", (0.3, 0.3, 0.35), (0, 0, 2.9), "neon_pink", bevel=0.06)
    rbox("d_card_slot", (0.3, 0.06, 0.08), (0, -0.33, 1.15), "steel", bevel=0.0)
    finish("kiosk")


def street_lamp():
    D.reset()
    cyl("pole", 0.09, 5.0, (0, 0, 2.5), "steel", verts=8)
    cyl("d_foot", 0.22, 0.4, (0, 0, 0.2), "dark", verts=8)
    D.beam("d_arm", (0, 0, 4.7), (0, -1.1, 5.0), 0.12, 0.12, "steel", bevel=0.0)
    rbox("head", (0.5, 0.8, 0.2), (0, -1.2, 4.95), "white", bevel=0.06)
    rbox("bulb", (0.36, 0.6, 0.05), (0, -1.2, 4.83), "light_warm", bevel=0.0)
    rbox("d_band", (0.22, 0.22, 0.1), (0, 0, 1.0), "neon_cyan", bevel=0.0)
    finish("street_lamp")


def wall_segment():
    D.reset()
    rbox("wall", (10.0, 1.0, 6.0), (0, 0, 3.0), "hull", bevel=0.06)
    rbox("cap", (10.2, 1.4, 0.4), (0, 0, 6.2), "dark", bevel=0.08)
    rbox("stripe", (10.05, 1.05, 0.5), (0, 0, 1.0), "trim", bevel=0.02)
    for x in (-2.4, 0.0, 2.4):  # recessed panels
        for s in (-1, 1):
            rbox("d_panel", (2.0, 0.06, 3.2), (x, s * 0.52, 3.4), "concrete", bevel=0.02)
    for s in (-1, 1):
        rbox("d_light", (9.6, 0.05, 0.08), (0, s * 0.72, 5.9), "neon_cyan", bevel=0.0)
    for x in (-4.6, 4.6):
        rbox("buttress", (0.8, 1.8, 6.4), (x, 0.3, 3.2), "dark", bevel=0.1)
    finish("wall_segment")


def crate_stack():
    D.reset()
    for name, size, loc, col in (("a", 1.6, (0, 0, 0.8), "rust"), ("b", 1.6, (1.7, 0.1, 0.8), "hull"),
                                 ("c", 1.4, (0.8, 0.0, 2.3), "trim")):
        rbox(name, (size, size, size), loc, col, bevel=0.07)
        for z in (-0.3, 0.3):  # straps
            rbox("d_strap", (size + 0.03, size + 0.03, 0.08), (loc[0], loc[1], loc[2] + z * size), "dark", bevel=0.0)
        rbox("d_stencil", (size * 0.5, 0.03, 0.2), (loc[0], loc[1] - size / 2 - 0.01, loc[2]), "white", bevel=0.0)
    finish("crate_stack")


for build in (shopfront, market_stall, kiosk, street_lamp, wall_segment, crate_stack):
    build()
