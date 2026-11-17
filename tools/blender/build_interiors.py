# THE HUNT: interiors and aircraft, built in Blender from code.
#   blender -b -P tools/blender/build_interiors.py -- <out_dir>
# apartment.glb: a tower apartment (living room, kitchen, bedroom, a glass
# wall onto a skyline). office.glb: an office with a view. Both are walk-in
# (with <piece>_col.glb) and sit deep under the valley; a building's door
# takes you there. skyhopper.glb (the rotorcraft, + its wheel-less body):
# the Skyport's aircraft, a VTOL hopper and a jet. Conventions as in
# build_districts.py (front -Y in Blender = +Z in Godot).
import bpy, math, sys, os
sys.path.insert(0, os.path.dirname(__file__))
import build_districts as D  # noqa: E402
from build_districts import rbox, cyl, prism, superellipse, finish  # noqa: E402
import build_outpost_kit as K  # noqa: E402


def skyline(y0, w):
    """Towers beyond the glass: near and far, some with spires."""
    import random
    rnd = random.Random(7)
    x = -w
    while x < w:
        tw = rnd.uniform(6, 14)
        th = rnd.uniform(25, 90)
        dist = rnd.uniform(35, 90)
        rbox("d_tower", (tw, tw * 0.8, th), (x, y0 + dist, -40 + th / 2), rnd.choice(("glass", "glass_dark", "glass")),
             bevel=0.0)
        rbox("d_tower_cap", (tw + 0.6, tw * 0.8 + 0.6, 1.0), (x, y0 + dist, -40 + th), "white", bevel=0.0)
        if rnd.random() < 0.35:
            cyl("d_spire", 0.3, 12, (x, y0 + dist, -40 + th + 6), "chrome", verts=6)
            rbox("d_spire_light", (0.6, 0.6, 0.6), (x, y0 + dist, -40 + th + 12.3), "neon_pink", bevel=0.0)
        x += tw + rnd.uniform(2, 10)
    rbox("d_ground_far", (w * 3, 140, 0.5), (0, y0 + 70, -40), "sand", bevel=0.0)


def room_shell(w, d, h, door=1.6):
    t = 0.25
    rbox("floor", (w, d, 0.3), (0, 0, -0.15), "wood", bevel=0.0)
    rbox("ceiling", (w, d, 0.3), (0, 0, h + 0.15), "white", bevel=0.0)
    for x in (-w / 2 - t / 2, w / 2 + t / 2):
        rbox("side", (t, d, h), (x, 0, h / 2), "white", bevel=0.0)
    side_w = (w - door) / 2
    for s in (-1, 1):
        rbox("front", (side_w, t, h), (s * (door / 2 + side_w / 2), -d / 2 - t / 2, h / 2), "white", bevel=0.0)
    rbox("lintel", (door, t, h - 2.4), (0, -d / 2 - t / 2, 2.4 + (h - 2.4) / 2), "white", bevel=0.0)
    # The way out: a lit frame and a closed door you walk "through" (the
    # game takes you back outside when you step into it).
    rbox("door_back", (door, 0.1, 2.4), (0, -d / 2 - 0.6, 1.2), "steel", bevel=0.0)
    for s in (-1, 1):
        rbox("d_door_glow", (0.08, 0.08, 2.4), (s * (door / 2 + 0.05), -d / 2 + 0.05, 1.2), "neon_cyan", bevel=0.0)
    # The glass wall at the back, framed.
    rbox("window", (w, 0.12, h), (0, d / 2 + 0.06, h / 2), "glass", bevel=0.0)
    for k in range(int(w / 2) + 1):
        rbox("d_mullion", (0.12, 0.2, h), (-w / 2 + k * w / int(w / 2), d / 2 + 0.06, h / 2), "steel", bevel=0.0)
    rbox("d_sill", (w, 0.4, 0.15), (0, d / 2 - 0.2, 0.08), "steel", bevel=0.0)
    for x in (-w / 4, w / 4):
        rbox("d_ceiling_light", (2.4, 0.5, 0.06), (x, 0, h - 0.04), "light_warm", bevel=0.0)


def apartment():
    D.reset()
    w, d, h = 16.0, 11.0, 3.6
    room_shell(w, d, h)
    skyline(d / 2, 60)
    # Living room (left): an L sofa, a rug, a table, a screen on the wall.
    rbox("d_rug", (5.0, 3.6, 0.03), (-4.0, 0.8, 0.02), "teal", bevel=0.0)
    rbox("sofa", (4.2, 1.0, 0.5), (-4.6, 2.6, 0.25), "concrete", bevel=0.15)
    rbox("d_sofa_back", (4.2, 0.3, 0.6), (-4.6, 3.05, 0.75), "concrete", bevel=0.12)
    rbox("sofa_l", (1.0, 2.4, 0.5), (-6.7, 1.0, 0.25), "concrete", bevel=0.15)
    for x in (-5.6, -4.0):
        rbox("d_cushion", (0.7, 0.2, 0.45), (x, 2.85, 0.75), "magenta", bevel=0.08)
    rbox("table", (1.6, 0.9, 0.4), (-4.2, 0.9, 0.2), "wood", bevel=0.05)
    rbox("d_screen", (3.2, 0.08, 1.8), (-4.4, -d / 2 + 0.05, 1.7), "dark", bevel=0.04)
    rbox("d_screen_glow", (3.0, 0.06, 1.6), (-4.4, -d / 2 + 0.1, 1.7), "neon_cyan", bevel=0.0)
    cyl("d_lamp_post", 0.04, 1.6, (-7.2, 3.6, 0.8), "chrome", verts=6)
    K.dome("d_lamp_shade", 0.35, 0.3, (-7.2, 3.6, 1.6), "light_warm", verts=10, rings=2)
    # Kitchen (middle back): counters and an island with stools.
    rbox("counter", (4.0, 0.7, 0.95), (0.6, -d / 2 + 0.45, 0.48), "white", bevel=0.04)
    rbox("d_counter_top", (4.1, 0.75, 0.05), (0.6, -d / 2 + 0.45, 0.98), "dark", bevel=0.0)
    rbox("island", (2.4, 1.0, 0.95), (0.6, -1.6, 0.48), "white", bevel=0.05)
    rbox("d_island_top", (2.6, 1.2, 0.05), (0.6, -1.6, 0.98), "wood", bevel=0.0)
    for x in (-0.1, 1.3):
        cyl("d_stool", 0.22, 0.75, (x, -0.7, 0.38), "steel", verts=8)
    rbox("d_fridge", (0.8, 0.7, 2.0), (3.2, -d / 2 + 0.45, 1.0), "chrome", bevel=0.04)
    # Bedroom (right): the bed, a locker for your things, a plant.
    rbox("bed", (2.2, 2.6, 0.5), (5.6, 2.8, 0.25), "white", bevel=0.12)
    rbox("d_blanket", (2.25, 1.8, 0.12), (5.6, 2.4, 0.52), "teal", bevel=0.06)
    rbox("d_headboard", (2.4, 0.2, 1.0), (5.6, 4.15, 0.6), "wood", bevel=0.05)
    rbox("locker", (1.0, 0.6, 2.0), (7.3, -3.6, 1.0), "steel", bevel=0.05)
    rbox("d_locker_light", (0.06, 0.04, 0.3), (7.0, -3.92, 1.4), "neon_cyan", bevel=0.0)
    cyl("d_pot", 0.35, 0.6, (7.3, 4.6, 0.3), "concrete", verts=10)
    K.dome("d_plant", 0.6, 1.2, (7.3, 4.6, 0.6), "green", verts=8, rings=2)
    rbox("d_divider", (0.15, 3.2, 2.4), (3.4, 2.4, 1.2), "wood", bevel=0.0)
    finish("apartment", col=True)


def office():
    D.reset()
    w, d, h = 12.0, 10.0, 3.6
    room_shell(w, d, h)
    skyline(d / 2, 50)
    rbox("desk", (3.0, 1.2, 0.75), (0, 2.2, 0.38), "wood", bevel=0.05)
    rbox("d_desk_screen", (1.4, 0.06, 0.8), (0, 2.6, 1.2), "neon_cyan", bevel=0.0)
    rbox("chair", (0.7, 0.7, 1.0), (0, 1.2, 0.5), "dark", bevel=0.1)
    for x in (-4.0, -2.6):
        rbox("d_visitor", (0.7, 0.7, 0.9), (x, -1.0, 0.45), "concrete", bevel=0.1)
    rbox("locker", (1.2, 0.7, 1.4), (5.0, -3.6, 0.7), "steel", bevel=0.05)  # the safe
    rbox("d_safe_dial", (0.3, 0.05, 0.3), (5.0, -3.96, 0.9), "chrome", bevel=0.02)
    rbox("d_board", (3.0, 0.06, 1.4), (-3.5, -d / 2 + 0.05, 1.7), "white", bevel=0.0)
    rbox("d_board_chart", (2.6, 0.04, 1.0), (-3.5, -d / 2 + 0.09, 1.7), "light_warm", bevel=0.0)
    cyl("d_pot", 0.35, 0.6, (5.0, 4.0, 0.3), "concrete", verts=10)
    K.dome("d_plant", 0.6, 1.4, (5.0, 4.0, 0.6), "green", verts=8, rings=2)
    finish("office", col=True)


def skyhopper():
    """A VTOL hopper (~10 m): a rounded cockpit pod, two ducted fans on stub
    wings, a tail boom with twin fins, landing skids."""
    D.reset()
    rbox("pod", (2.6, 4.6, 2.2), (0, 0.6, 1.9), "white", bevel=0.8)
    rbox("canopy", (2.3, 2.0, 1.2), (0, 2.0, 2.5), "glass_dark", bevel=0.5)
    rbox("d_stripe", (2.65, 4.0, 0.25), (0, 0.4, 1.6), "magenta", bevel=0.08)
    rbox("boom", (0.8, 5.0, 0.8), (0, -3.8, 2.2), "white", bevel=0.25)
    for s in (-1, 1):
        rbox("fin%d" % s, (0.15, 1.4, 1.8), (s * 0.9, -6.0, 2.9), "white", bevel=0.05, rot=(0, s * 0.3, 0))
        rbox("d_fin_tip%d" % s, (0.18, 0.5, 0.3), (s * 1.05, -6.2, 3.7), "neon_pink", bevel=0.0)
        rbox("wing%d" % s, (2.6, 1.4, 0.3), (s * 2.4, 0.0, 2.2), "white", bevel=0.1)
        D.torus("duct%d" % s, 1.5, 0.3, (s * 4.2, 0.0, 2.2), "steel", major=20, minor=6)
        cyl("d_hub%d" % s, 0.3, 0.5, (s * 4.2, 0.0, 2.2), "dark", verts=10)
        for k in range(4):
            a = k * math.pi / 4 + 0.3
            rbox("d_blade%d_%d" % (s, k), (2.6, 0.25, 0.05), (s * 4.2, 0.0, 2.2), "dark", bevel=0.0, rot=(0, 0, a))
        cyl("d_duct_glow%d" % s, 1.52, 0.1, (s * 4.2, 0.0, 1.95), "neon_cyan", verts=20, cap=False)
        rbox("skid%d" % s, (0.15, 4.6, 0.15), (s * 1.1, 0.4, 0.1), "steel", bevel=0.0)
        for y in (-1.2, 1.8):
            rbox("d_strut%d" % s, (0.12, 0.12, 0.9), (s * 1.1, y, 0.55), "steel", bevel=0.0)
    rbox("d_light", (0.4, 0.15, 0.2), (0, 2.95, 1.6), "light_warm", bevel=0.03)
    finish("skyhopper")


if __name__ == "__main__":
    apartment()
    office()
    skyhopper()
