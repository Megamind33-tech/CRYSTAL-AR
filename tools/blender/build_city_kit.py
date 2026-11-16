# THE HUNT: Tharsis Gate city pieces, built in Blender from code (same
# conventions as build_outpost_kit.py: Y-up glTF, metres, origin at the
# floor centre; each piece's front faces -Y in Blender, +Z in Godot).
#   blender -b -P tools/blender/build_city_kit.py -- <out_dir>
import bpy, math, sys, os
sys.path.insert(0, os.path.dirname(__file__))
from build_outpost_kit import reset, box, cyl, dome, finish, OUT  # noqa: E402  (shared helpers)

# Blender: -Y is the front (it becomes +Z, towards the plaza, in Godot).


def shopfront():
    """A walk-in shop: an open doorway, a lit room with a counter and stocked
    shelves, and a solid upper storey above the ceiling slab."""
    reset()
    w, d, h = 12.0, 8.0, 7.5
    t = 0.3          # wall thickness
    g = 3.6          # ground-floor ceiling height
    door = 2.4       # doorway width
    box("floor", (w, d, 0.2), (0, 0, 0.1), "dark")
    box("plinth", (w + 0.4, d + 0.4, 0.3), (0, 0, 0.05), "dark")
    # Ground-floor walls: back, sides, and a front split around the door.
    box("back", (w, t, g), (0, d / 2 - t / 2, g / 2), "hull")
    for x in (-w / 2 + t / 2, w / 2 - t / 2):
        box("side", (t, d, g), (x, 0, g / 2), "hull")
    side_w = (w - door) / 2
    for s in (-1, 1):
        cx = s * (door / 2 + side_w / 2)
        box("front_low", (side_w, t, 0.9), (cx, -d / 2 + t / 2, 0.45), "hull")
        box("front_pier", (0.4, t, g), (s * (w / 2 - 0.2), -d / 2 + t / 2, g / 2), "hull")
        box("front_pier", (0.4, t, g), (s * (door / 2 + 0.2), -d / 2 + t / 2, g / 2), "hull")
        box("glass", (side_w - 0.8, 0.08, 2.2), (cx, -d / 2 + t / 2, 2.0), "glass")
    box("lintel", (door, t, g - 2.9), (0, -d / 2 + t / 2, 2.9 + (g - 2.9) / 2), "hull")
    # The ceiling slab, then the solid upper storey and roof.
    box("ceiling", (w, d, 0.35), (0, 0, g + 0.175), "trim")
    up = h - g - 0.35
    box("upper", (w, d, up), (0, 0, g + 0.35 + up / 2), "hull")
    box("roof_lip", (w + 0.6, d + 0.6, 0.5), (0, 0, h + 0.25), "dark")
    box("floor_band", (w + 0.1, d + 0.1, 0.35), (0, 0, g + 0.175), "trim")
    # Inside: a counter across the back half, shelves on the back wall.
    box("counter", (6.0, 0.9, 1.05), (0, 1.2, 0.6), "rust")
    box("counter_top", (6.2, 1.1, 0.1), (0, 1.2, 1.15), "dark")
    for z in (0.9, 1.7, 2.5):
        box("shelf", (w - 2.0, 0.6, 0.08), (0, d / 2 - t - 0.3, z), "dark")
        for i in range(7):
            x = -4.2 + i * 1.4
            box("goods", (0.6, 0.4, 0.45), (x, d / 2 - t - 0.3, z + 0.27),
                ("trim", "magenta", "glass", "light")[(i + int(z * 10)) % 4])
    box("lamp", (4.0, 0.6, 0.08), (0, 0, g - 0.06), "light")
    # Outside: awning, posts, upper windows, sign, vent.
    box("awning", (w - 1.0, 2.2, 0.18), (0, -d / 2 - 1.1, 3.25), "magenta")
    for x in (-w / 2 + 0.8, w / 2 - 0.8):
        box("post", (0.2, 0.2, 3.2), (x, -d / 2 - 2.1, 1.6), "dark")
    for x in (-3.6, 0.0, 3.6):
        box("win", (2.2, 0.1, 1.4), (x, -d / 2 - 0.04, 5.2), "glass")
    box("sign", (w - 3.0, 0.3, 1.2), (0, -d / 2 - 0.25, 6.8), "trim")
    box("vent", (1.6, 1.6, 1.0), (3.0, 1.5, h + 1.0), "dark")
    finish("shopfront")


def market_stall():
    reset()
    box("counter", (3.4, 1.2, 1.0), (0, 0, 0.5), "rust")
    box("top", (3.6, 1.4, 0.12), (0, 0, 1.06), "dark")
    for x in (-1.7, 1.7):
        for y in (-0.7, 1.3):
            box("pole", (0.1, 0.1, 2.6), (x, y, 1.3), "dark")
    box("canopy", (3.8, 2.4, 0.14), (0, 0.3, 2.65), "trim")
    box("canopy_stripe", (3.82, 0.5, 0.16), (0, -0.6, 2.66), "magenta")
    for i, x in enumerate((-1.1, 0.0, 1.1)):
        box("goods%d" % i, (0.7, 0.6, 0.45), (x, 0.1, 1.35), ("glass", "trim", "hull")[i])
    finish("market_stall")


def kiosk():
    reset()
    box("base", (1.4, 1.0, 0.3), (0, 0, 0.15), "dark")
    box("pillar", (0.9, 0.6, 2.2), (0, 0, 1.4), "hull")
    box("screen", (0.8, 0.08, 1.0), (0, -0.33, 1.8), "glass")
    box("hood", (1.1, 0.8, 0.2), (0, -0.1, 2.6), "trim")
    box("beacon", (0.3, 0.3, 0.35), (0, 0, 2.9), "magenta")
    finish("kiosk")


def street_lamp():
    reset()
    cyl("pole", 0.09, 5.0, (0, 0, 2.5), "dark", verts=6)
    box("arm", (0.12, 1.2, 0.12), (0, -0.55, 4.9), "dark")
    box("head", (0.5, 0.7, 0.25), (0, -1.1, 4.8), "trim")
    box("bulb", (0.36, 0.5, 0.06), (0, -1.1, 4.66), "light")
    finish("street_lamp")


def wall_segment():
    reset()
    box("wall", (10.0, 1.0, 6.0), (0, 0, 3.0), "hull")
    box("cap", (10.2, 1.4, 0.4), (0, 0, 6.2), "dark")
    box("stripe", (10.05, 1.05, 0.5), (0, 0, 1.0), "trim")
    for x in (-4.6, 4.6):
        box("buttress", (0.8, 1.8, 6.4), (x, 0.3, 3.2), "dark")
    finish("wall_segment")


def crate_stack():
    reset()
    box("a", (1.6, 1.6, 1.6), (0, 0, 0.8), "rust")
    box("b", (1.6, 1.6, 1.6), (1.7, 0.1, 0.8), "hull")
    box("c", (1.4, 1.4, 1.4), (0.8, 0.0, 2.3), "trim")
    finish("crate_stack")


for build in (shopfront, market_stall, kiosk, street_lamp, wall_segment, crate_stack):
    build()
