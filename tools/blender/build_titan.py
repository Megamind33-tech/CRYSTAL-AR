# THE HUNT on Titan: the settlement block's buildings (docs/art-reference),
# built in Blender from code in the kit's comic materials. Long capsule
# modules with chamfered corners, lit window bands, roof plant, and an
# airlock porch at each entrance (outer door -> lock -> inner door); inside,
# rooms laid out for what the building is for.
#   blender -b -P tools/blender/build_titan.py -- art/environment/titan
# Each building exports three files:
#   <b>.glb      the shell and its outside details (drawn from afar)
#   <b>_in.glb   the furnished interior (drawn only up close: StaticBatches)
#   <b>_col.glb  walls, floors and furniture people bump into (no "d_" or
#                "id_" details), for KitCollision
# Conventions as the other kits: metres, origin at the floor centre, the
# front faces -Y in Blender (+Z in Godot). Doorways are 1.6 m wide and
# 2.4 m high; the doors themselves slide in the game (TitanDoors).
# Names: "i_" interior that collides, "id_" interior detail, "d_" outside
# detail, anything else the shell.
import bpy, math, sys, os
sys.path.insert(0, os.path.dirname(__file__))
import build_districts as D  # noqa: E402
from build_districts import rbox, cyl  # noqa: E402
import build_outpost_kit as K  # noqa: E402

OUT = D.OUT
T = 0.25      # wall thickness
H = 3.2       # storey height (ceiling)
DOOR = 1.6
DOOR_H = 2.4


def reset():
    D.reset()


# --- pieces of a module ------------------------------------------------------

def wall(name, x0, y0, x1, y1, h=H, mat="light", z0=0.0, doors=()):
    """A wall from (x0,y0) to (x1,y1) (axis-aligned), with door gaps at the
    given positions along it (centre offsets from its start)."""
    horiz = abs(y1 - y0) < 1e-3
    length = abs(x1 - x0) if horiz else abs(y1 - y0)
    start = min(x0, x1) if horiz else min(y0, y1)
    fixed = y0 if horiz else x0
    cuts = sorted(doors)
    edges = [0.0]
    for c in cuts:
        edges += [c - DOOR / 2, c + DOOR / 2]
    edges.append(length)
    for i in range(0, len(edges), 2):
        a, b = edges[i], edges[i + 1]
        if b - a < 0.05:
            continue
        mid = start + (a + b) / 2
        size = (b - a, T, h) if horiz else (T, b - a, h)
        loc = (mid, fixed, z0 + h / 2) if horiz else (fixed, mid, z0 + h / 2)
        rbox(name, size, loc, mat, bevel=0.0)
    for c in cuts:  # the lintel over each doorway, and its frame
        mid = start + c
        size = (DOOR, T, h - DOOR_H) if horiz else (T, DOOR, h - DOOR_H)
        loc = (mid, fixed, z0 + DOOR_H + (h - DOOR_H) / 2) if horiz else (fixed, mid, z0 + DOOR_H + (h - DOOR_H) / 2)
        rbox(name, size, loc, mat, bevel=0.0)
        fsize = (DOOR + 0.3, T + 0.1, 0.14) if horiz else (T + 0.1, DOOR + 0.3, 0.14)
        floc = (mid, fixed, z0 + DOOR_H + 0.07) if horiz else (fixed, mid, z0 + DOOR_H + 0.07)
        rbox(name.replace("i_", "id_") + "_frame", fsize, floc, "steel", bevel=0.02)


def capsule(w, d, h, accent, windows=(), sign=None):
    """The module's shell: a chamfered box (the ink outline reads its edges),
    a floor, inner lining, a lit window band on the long sides and a roof
    with plant. Front wall at y = -d/2 with the entrance at x = 0."""
    rbox("hull_roof", (w, d, 0.5), (0, 0, h + 0.25), "hull", bevel=0.35)
    rbox("floor", (w, d, 0.2), (0, 0, 0.1), "dark", bevel=0.0)
    rbox("plinth", (w + 0.5, d + 0.5, 0.35), (0, 0, 0.0), "dark", bevel=0.08)
    # Outer walls: thick, chamfered at the corners (posts), the entrance cut.
    wall("hull_wall", -w / 2, -d / 2, w / 2, -d / 2, h=h, mat="hull", doors=(w / 2,))
    wall("hull_wall", -w / 2, d / 2, w / 2, d / 2, h=h, mat="hull")
    wall("hull_wall", -w / 2, -d / 2, -w / 2, d / 2, h=h, mat="hull")
    wall("hull_wall", w / 2, -d / 2, w / 2, d / 2, h=h, mat="hull")
    for sx in (-1, 1):
        for sy in (-1, 1):
            rbox("hull_post", (0.7, 0.7, h + 0.4), (sx * (w / 2), sy * (d / 2), (h + 0.4) / 2), "hull", bevel=0.25)
    # Accent band and ribs between the panels (the capsule look).
    rbox("d_band", (w + 0.1, d + 0.1, 0.3), (0, 0, h - 0.15), accent, bevel=0.05)
    n = max(2, int(w / 3.5))
    for i in range(1, n):
        x = -w / 2 + i * w / n
        for sy in (-1, 1):
            rbox("d_rib", (0.3, 0.25, h + 0.1), (x, sy * (d / 2 + 0.08), (h + 0.1) / 2), "steel", bevel=0.05)
    # Lit windows: framed glass you can see the rooms through.
    for (x, y, along_x, ww) in windows:
        size = (ww, 0.3, 1.3) if along_x else (0.3, ww, 1.3)
        rbox("d_win_frame", (size[0] + 0.25, size[1] + 0.05, 1.55) if along_x else (size[0] + 0.05, size[1] + 0.25, 1.55),
             (x, y, 1.75), "dark", bevel=0.04)
        rbox("win", size, (x, y, 1.75), "glass_warm", bevel=0.0)
    # Roof plant: heat exchangers, a scrubber stack and a vent.
    for x in (-w / 3, w / 4):
        rbox("d_ac", (1.6, 1.2, 0.8), (x, d / 6, h + 0.9), "white", bevel=0.12)
        cyl("d_ac_fan", 0.4, 0.06, (x, d / 6 - 0.62, h + 0.9), "dark", verts=10, rot=(math.pi / 2, 0, 0))
    cyl("d_stack", 0.22, 1.4, (w / 2 - 1.0, d / 2 - 1.0, h + 1.2), "steel", verts=8)
    rbox("d_stack_cap", (0.6, 0.6, 0.12), (w / 2 - 1.0, d / 2 - 1.0, h + 1.95), "dark", bevel=0.02)
    # Insulation pipes along the back (warm water, air): how it survives.
    cyl("d_pipe_air", 0.12, w - 1.0, (0, d / 2 + 0.35, h - 0.6), "copper", verts=8, rot=(0, math.pi / 2, 0))
    cyl("d_pipe_heat", 0.12, w - 1.0, (0, d / 2 + 0.35, h - 1.0), "trim", verts=8, rot=(0, math.pi / 2, 0))
    if sign:
        rbox("d_sign", (sign[0], 0.2, 0.9), (0, -d / 2 - 0.2, h - 0.7), "dark", bevel=0.05)
        rbox("d_sign_face", (sign[0] - 0.3, 0.06, 0.6), (0, -d / 2 - 0.32, h - 0.7), sign[1], bevel=0.0)


def airlock(w, d, accent):
    """The entrance porch in front (-Y): an outer doorway, a lock 2.4 m
    deep, the inner doorway being the module's front wall cut."""
    y0, y1 = -d / 2 - 2.4, -d / 2
    rbox("lock_floor", (2.8, 2.4, 0.2), (0, (y0 + y1) / 2, 0.1), "dark", bevel=0.0)
    rbox("lock_roof", (3.2, 2.8, 0.35), (0, (y0 + y1) / 2, 2.95), "hull", bevel=0.15)
    for sx in (-1, 1):
        rbox("lock_side", (T, 2.4, 2.8), (sx * 1.4, (y0 + y1) / 2, 1.4), "hull", bevel=0.05)
    wall("lock_front", -1.4, y0, 1.4, y0, h=2.8, mat="hull", doors=(1.4,))
    # Status lights either side of the outer door: the lock's state.
    for sx in (-1, 1):
        rbox("d_lock_light", (0.12, 0.08, 0.5), (sx * 1.05, y0 - 0.16, 2.0), "neon_cyan", bevel=0.0)
    rbox("d_lock_stripe", (2.9, 0.1, 0.18), (0, y0 - 0.14, 2.65), accent, bevel=0.0)
    rbox("id_lock_bench", (0.4, 1.2, 0.45), (1.05, (y0 + y1) / 2, 0.42), "steel", bevel=0.04)
    rbox("id_suit_rack", (0.25, 1.4, 1.9), (-1.12, (y0 + y1) / 2, 1.15), "dark", bevel=0.03)
    for i in range(2):
        rbox("id_suit", (0.3, 0.45, 1.3), (-1.0, (y0 + y1) / 2 - 0.35 + i * 0.7, 1.2), "trim", bevel=0.12)


def ceiling_lights(xs, ys, z=H - 0.06):
    for x in xs:
        for y in ys:
            rbox("id_lamp", (1.2, 0.35, 0.06), (x, y, z), "light_warm", bevel=0.0)


def lining(w, d):
    """Pale interior wall faces and a ceiling, so rooms read as lit rooms."""
    rbox("i_ceiling", (w - 0.5, d - 0.5, 0.1), (0, 0, H - 0.02), "white", bevel=0.0)


# --- R-14: a residential module ---------------------------------------------

def hab_r14():
    """Home for a household: an airlock porch, a common room (kitchen,
    table, sofa, screen), two bedrooms, a washroom, and a utility room with
    the heater, the air scrubber and the household locker (y 3.4)."""
    reset()
    w, d = 14.0, 10.0
    capsule(w, d, H + 0.2, "trim", sign=(4.0, "light_warm"),
            windows=[(-5.2, -d / 2, True, 2.4), (5.2, -d / 2, True, 2.4), (-w / 2, -0.5, False, 2.0), (w / 2, -0.5, False, 2.0)])
    airlock(w, d, "trim")
    lining(w, d)
    # Partitions: bedrooms west and east, washroom and utility at the back.
    wall("i_wall", -3.5, -d / 2, -3.5, 2.0, doors=(4.0,))
    wall("i_wall", 3.5, -d / 2, 3.5, 2.0, doors=(4.0,))
    wall("i_wall", -w / 2, 2.0, w / 2, 2.0, doors=(w / 2 - 2.2, w / 2 + 1.7))
    wall("i_wall", -0.9, 2.0, -0.9, d / 2)
    wall("i_wall", -3.5, 2.0, -3.5, d / 2)
    wall("i_wall", 3.5, 2.0, 3.5, d / 2)
    # Common room: kitchen run on the east partition, a table, a sofa.
    rbox("i_kitchen", (0.7, 3.0, 0.95), (3.0, -0.6, 0.48), "white", bevel=0.04)
    rbox("id_worktop", (0.75, 3.05, 0.06), (3.0, -0.6, 0.98), "dark", bevel=0.0)
    rbox("id_cooker", (0.5, 0.6, 0.04), (3.0, -1.4, 1.02), "steel", bevel=0.0)
    rbox("id_wall_cab", (0.4, 2.6, 0.7), (3.15, -0.6, 2.2), "teal", bevel=0.04)
    rbox("i_table", (1.6, 0.9, 0.06), (-0.6, -0.6, 0.78), "wood", bevel=0.02)
    rbox("id_table_leg", (0.12, 0.12, 0.76), (-0.6, -0.6, 0.38), "dark", bevel=0.0)
    for (x, y) in ((-1.5, -0.6), (0.3, -0.6), (-0.6, -1.3), (-0.6, 0.1)):
        rbox("id_stool", (0.4, 0.4, 0.45), (x, y, 0.23), "trim", bevel=0.06)
    rbox("i_sofa", (2.2, 0.8, 0.45), (-1.0, 1.4, 0.23), "teal", bevel=0.1)
    rbox("id_sofa_back", (2.2, 0.2, 0.5), (-1.0, 1.75, 0.7), "teal", bevel=0.08)
    rbox("id_screen", (1.6, 0.06, 0.9), (-0.6, -d / 2 + 0.18, 1.7), "glass_dark", bevel=0.0)
    rbox("id_rug", (2.4, 1.6, 0.02), (-0.6, -0.4, 0.21), "magenta", bevel=0.0)
    cyl("id_plant_pot", 0.25, 0.5, (-3.0, 1.4, 0.45), "copper", verts=8)
    rbox("id_plant", (0.6, 0.6, 0.7), (-3.0, 1.4, 1.0), "green", bevel=0.2)
    # West bedroom: a double bed, a wardrobe, a shelf with things on it.
    rbox("i_bed", (2.0, 2.2, 0.45), (-5.4, -1.8, 0.33), "wood", bevel=0.05)
    rbox("id_mattress", (1.9, 2.1, 0.2), (-5.4, -1.8, 0.65), "white", bevel=0.06)
    rbox("id_blanket", (1.95, 1.3, 0.06), (-5.4, -1.4, 0.78), "magenta", bevel=0.02)
    rbox("i_wardrobe", (1.6, 0.6, 2.1), (-5.4, 1.5, 1.15), "teal", bevel=0.04)
    rbox("id_shelf", (1.4, 0.3, 0.05), (-6.7, -0.2, 1.5), "wood", bevel=0.0)
    for i in range(3):
        rbox("id_thing", (0.25, 0.2, 0.3), (-6.75, -0.6 + i * 0.4, 1.68), ("trim", "glass", "copper")[i], bevel=0.04)
    # East bedroom: a bunk for two, a desk with a terminal.
    for z in (0.35, 1.45):
        rbox("i_bunk" if z < 1 else "id_bunk_top", (0.95, 2.1, 0.3), (6.3, -2.6, z), "rust", bevel=0.04)
        rbox("id_bunk_mat", (0.9, 2.0, 0.14), (6.3, -2.6, z + 0.22), "white", bevel=0.04)
    rbox("id_bunk_post", (0.1, 0.1, 1.9), (5.8, -1.55, 0.95), "steel", bevel=0.0)
    rbox("i_desk", (1.4, 0.7, 0.06), (6.2, 0.9, 0.78), "wood", bevel=0.02)
    rbox("id_desk_screen", (0.7, 0.05, 0.45), (6.2, 1.2, 1.15), "glass_dark", bevel=0.0)
    rbox("id_chair", (0.45, 0.45, 0.5), (6.1, 0.3, 0.25), "dark", bevel=0.06)
    # Washroom: a shower cubicle, a toilet, a basin.
    rbox("id_shower_tray", (1.0, 1.0, 0.08), (-3.0, 4.3, 0.24), "white", bevel=0.02)
    rbox("id_shower_glass", (0.05, 1.0, 2.0), (-2.45, 4.3, 1.2), "glass", bevel=0.0)
    rbox("i_toilet", (0.45, 0.6, 0.45), (-1.4, 4.6, 0.43), "white", bevel=0.12)
    rbox("i_basin", (0.6, 0.4, 0.2), (-2.2, 2.4, 0.9), "white", bevel=0.06)
    # Utility: the heater, the scrubber (its lamp says the air is good),
    # the water tank, the household locker at (0, 3.4).
    rbox("i_heater", (1.0, 0.6, 1.4), (2.6, 4.4, 0.9), "rust", bevel=0.05)
    for i in range(4):
        rbox("id_heater_fin", (0.9, 0.04, 1.0), (2.6, 4.06 - i * 0.0, 0.5 + i * 0.25), "steel", bevel=0.0)
    rbox("i_scrubber", (0.9, 0.6, 1.8), (1.3, 4.4, 1.1), "white", bevel=0.06)
    rbox("id_scrubber_ok", (0.3, 0.05, 0.12), (1.3, 4.08, 1.7), "green", bevel=0.0)
    cyl("i_water", 0.45, 1.6, (-0.3, 4.4, 1.0), "teal", verts=12)
    rbox("i_locker", (0.8, 0.5, 1.9), (0.2, 3.0, 1.15), "dark", bevel=0.03)
    ceiling_lights((-5.2, 0, 5.2), (-1.5,))
    ceiling_lights((-2.2, 1.5), (3.6,))
    export("titan/hab_r14")


# --- The market hub: commercial ---------------------------------------------

def market_hub():
    """A shop people trade in: an airlock porch, a sales floor (two gondola
    rows, a display table, a counter with the register; the keeper stands
    at y 2.4), a storeroom and a staff room behind it."""
    reset()
    w, d = 12.0, 10.0
    capsule(w, d, H + 0.6, "magenta", sign=(6.0, "light_warm"),
            windows=[(-3.6, -d / 2, True, 2.8), (3.6, -d / 2, True, 2.8)])
    # The lit MARKET board above the porch.
    rbox("d_market_board", (5.0, 0.3, 1.2), (0, -d / 2 - 2.2, H + 0.9), "dark", bevel=0.08)
    rbox("d_market_face", (4.6, 0.08, 0.9), (0, -d / 2 - 2.38, H + 0.9), "neon_pink", bevel=0.0)
    for i in range(4):  # an awning over the windows
        rbox("d_awning", (2.6, 1.6, 0.1), (-4.4 + (i % 2) * 1.6 + (6.0 if i > 1 else 0), -d / 2 - 0.8, 2.85), ("magenta", "white")[i % 2],
             bevel=0.0, rot=(math.radians(-10), 0, 0))
    airlock(w, d, "magenta")
    lining(w, d)
    # Back rooms: a wall at y 3 with a door to the storeroom (behind the
    # counter) and one to the staff room.
    wall("i_wall", -w / 2, 3.0, w / 2, 3.0, doors=(w / 2 + 3.6, w / 2 - 3.8))
    wall("i_wall", 0.4, 3.0, 0.4, d / 2)
    # The counter (keeper behind it at y 2.4), the register.
    rbox("i_counter", (4.4, 0.8, 1.05), (1.8, 1.6, 0.53), "rust", bevel=0.05)
    rbox("id_counter_top", (4.6, 1.0, 0.08), (1.8, 1.6, 1.08), "dark", bevel=0.02)
    rbox("id_register", (0.5, 0.4, 0.3), (2.6, 1.6, 1.27), "steel", bevel=0.04)
    rbox("id_reg_screen", (0.4, 0.04, 0.25), (2.6, 1.42, 1.45), "glass", bevel=0.0)
    # Gondolas: two rows of stocked shelves, an aisle between.
    for x in (-3.8, -1.6):
        rbox("i_gondola", (0.7, 3.4, 1.6), (x, -1.0, 0.9), "white", bevel=0.03)
        for z in (0.55, 1.05, 1.55):
            for k in range(5):
                for side in (-1, 1):
                    rbox("id_goods", (0.22, 0.5, 0.3), (x + side * 0.42, -2.4 + k * 0.7, z + 0.15),
                         ("trim", "teal", "magenta", "copper", "glass")[(k + int(z * 3) + side) % 5], bevel=0.04)
    rbox("i_display", (1.6, 1.0, 0.85), (2.6, -2.6, 0.43), "teal", bevel=0.05)
    for k in range(3):
        rbox("id_display_item", (0.35, 0.35, 0.35), (2.0 + k * 0.6, -2.6, 1.05), ("copper", "glass", "trim")[k], bevel=0.06)
    # Wall shelves on the back wall of the floor, behind the counter.
    for z in (1.4, 2.1):
        rbox("id_wall_shelf", (4.0, 0.35, 0.05), (1.8, 2.75, z), "wood", bevel=0.0)
        for k in range(6):
            rbox("id_wall_goods", (0.4, 0.3, 0.35), (0.2 + k * 0.65, 2.75, z + 0.2), ("glass", "magenta", "trim")[k % 3], bevel=0.04)
    # Storeroom (west back): racks of crates.
    for x in (-5.2, -3.2):
        rbox("i_rack", (1.4, 0.6, 2.2), (x, 4.3, 1.2), "steel", bevel=0.02)
        for z in (0.6, 1.3, 2.0):
            rbox("id_crate", (1.1, 0.5, 0.5), (x, 4.3, z), ("rust", "trim", "teal")[int(z) % 3], bevel=0.05)
    rbox("i_crate_stack", (1.2, 1.0, 1.0), (-1.2, 3.8, 0.6), "rust", bevel=0.06)
    # Staff room (east back): table, lockers, a coffee machine.
    rbox("i_staff_table", (1.2, 0.8, 0.06), (2.8, 4.1, 0.78), "wood", bevel=0.02)
    for x in (4.6, 5.2):
        rbox("i_staff_locker", (0.55, 0.5, 1.9), (x, 4.6, 1.15), "dark", bevel=0.03)
    rbox("id_coffee", (0.4, 0.35, 0.5), (1.2, 4.6, 1.2), "magenta", bevel=0.05)
    ceiling_lights((-3.0, 0.0, 3.0), (-2.0, 1.0))
    ceiling_lights((-3.0, 2.8), (4.0,))
    export("titan/market_hub")


# --- EX-03: industrial (the settlement's air, heat and water) ------------------

def plant_ex03():
    """The life-support plant: a control room with screens over the hall, a
    machine hall (two electrolysers, a heat exchanger, a water pump, pipes),
    a maintenance bay with a workbench. Tall, tanks and a stack outside."""
    reset()
    w, d, hh = 16.0, 12.0, 5.5
    capsule(w, d, hh, "trim", sign=(4.0, "light_warm"),
            windows=[(-5.0, -d / 2, True, 3.0), (w / 2, -2.0, False, 2.4)])
    airlock(w, d, "trim")
    rbox("i_ceiling", (w - 0.5, d - 0.5, 0.1), (0, 0, hh - 0.02), "white", bevel=0.0)
    # Control room (front west) behind glass; the hall beyond it.
    wall("i_wall", -w / 2, -1.0, -2.0, -1.0, h=H, doors=())
    rbox("i_ctrl_glass", (5.8, 0.12, 1.4), (-5.0, -1.0, 1.9), "glass", bevel=0.0)
    wall("i_wall", -2.0, -d / 2, -2.0, -1.0, h=H, doors=(2.6,))
    rbox("i_ctrl_roof", (6.0, 5.0, 0.2), (-5.0, -3.5, H + 0.1), "hull", bevel=0.0)
    rbox("i_console", (4.4, 0.8, 0.9), (-5.0, -1.6, 0.45), "dark", bevel=0.05)
    for k in range(3):
        rbox("id_monitor", (1.1, 0.06, 0.7), (-6.4 + k * 1.4, -1.25, 1.35), "glass", bevel=0.0)
        rbox("id_monitor_glow", (0.9, 0.04, 0.5), (-6.4 + k * 1.4, -1.29, 1.35), "neon_cyan", bevel=0.0)
    for x in (-6.2, -3.8):
        rbox("id_ctrl_chair", (0.5, 0.5, 0.5), (x, -2.4, 0.25), "trim", bevel=0.08)
    rbox("id_ctrl_map", (2.4, 0.06, 1.2), (-5.0, -d / 2 + 0.2, 2.0), "glass_dark", bevel=0.0)
    # Machine hall: electrolysers (air), the heat exchanger, the water pump.
    for x in (1.0, 4.0):
        cyl("i_electrolyser", 0.9, 3.6, (x, 3.4, 1.9), "white", verts=12)
        rbox("id_elec_band", (1.9, 1.9, 0.25), (x, 3.4, 3.0), "trim", bevel=0.05)
        cyl("id_elec_pipe", 0.12, 2.6, (x, 3.4, 4.6), "copper", verts=8)
    rbox("i_heat_exch", (2.4, 1.4, 2.0), (6.0, 0.0, 1.1), "rust", bevel=0.06)
    for k in range(5):
        rbox("id_hx_fin", (2.2, 0.05, 1.6), (6.0, -0.75, 1.1), "steel", bevel=0.0)
    rbox("i_pump", (1.4, 1.0, 1.0), (1.5, -2.6, 0.6), "teal", bevel=0.06)
    cyl("id_pump_motor", 0.35, 0.8, (2.4, -2.6, 0.6), "steel", verts=10, rot=(0, math.pi / 2, 0))
    for y in (1.6, 5.2):  # overhead pipes the length of the hall
        cyl("id_hall_pipe", 0.16, w - 2.0, (0, y, 4.6 if y > 2 else 4.2), ("copper", "trim")[int(y) % 2], verts=8,
            rot=(0, math.pi / 2, 0))
    rbox("id_walkway", (8.0, 1.2, 0.1), (3.0, 5.0, 3.6), "steel", bevel=0.0)
    # Maintenance bay (front east): a workbench, a tool board, spare parts.
    rbox("i_bench", (2.4, 0.9, 0.9), (5.6, -4.6, 0.45), "wood", bevel=0.04)
    rbox("id_toolboard", (2.4, 0.06, 1.2), (5.6, -d / 2 + 0.15, 1.9), "dark", bevel=0.0)
    for k in range(5):
        rbox("id_tool", (0.08, 0.04, 0.6), (4.7 + k * 0.45, -d / 2 + 0.2, 1.9), "steel", bevel=0.0)
    rbox("i_parts", (1.0, 1.0, 0.8), (3.0, -4.8, 0.5), "trim", bevel=0.06)
    ceiling_lights((-4.0, 0.0, 4.0), (0.0, 3.5), z=hh - 0.08)
    ceiling_lights((-5.0,), (-3.5,), z=H - 0.06)
    # Outside: the tank farm, the stack, a gantry crane over the yard.
    for x in (-w / 2 - 2.0, -w / 2 - 2.0):
        pass
    for k, y in enumerate((-2.0, 2.0)):
        cyl("d_tank", 1.4, 4.4, (w / 2 + 2.2, y, 2.2), ("white", "trim")[k], verts=12)
        rbox("d_tank_band", (3.0, 3.0, 0.3), (w / 2 + 2.2, y, 3.0), "rust", bevel=0.1)
    cyl("d_stack_big", 0.6, 9.0, (-w / 2 + 1.5, d / 2 - 1.5, hh + 4.5), "steel", verts=10)
    rbox("d_stack_light", (0.3, 0.3, 0.3), (-w / 2 + 1.5, d / 2 - 1.5, hh + 9.2), "neon_pink", bevel=0.05)
    for x in (-3.0, 3.0):
        rbox("d_gantry_leg", (0.3, 0.3, 4.0), (x, d / 2 + 2.5, hh + 2.0), "trim", bevel=0.03)
    rbox("d_gantry_beam", (6.6, 0.4, 0.4), (0, d / 2 + 2.5, hh + 4.0), "trim", bevel=0.03)
    export("titan/plant_ex03")


# --- The gatehouse: security ---------------------------------------------------

def gatehouse():
    """The settlement's way in: a vehicle and foot airlock hall 8 m wide
    through the middle (doors both ends), a security office on the west
    (reception desk, monitors, a scanner arch, an equipment room, a
    detention cell) and a watchtower over the east side."""
    reset()
    w, d, hh = 24.0, 10.0, 6.0
    # Floor and roof over everything; the hall open front and back (doors
    # slide in the game), side walls between hall and wings.
    rbox("floor", (w, d, 0.2), (0, 0, 0.1), "dark", bevel=0.0)
    rbox("hull_roof", (w, d, 0.6), (0, 0, hh + 0.3), "hull", bevel=0.35)
    for sx in (-1, 1):
        rbox("hull_end", (T, d, hh), (sx * w / 2, 0, hh / 2), "hull", bevel=0.05)
        # Wing walls front and back, the hall's sides.
        for sy in (-1, 1):
            rbox("hull_wing", (w / 2 - 4.0, T, hh), (sx * (w / 4 + 2.0), sy * d / 2, hh / 2), "hull", bevel=0.05)
        rbox("hull_hall_side", (T, d, hh), (sx * 4.0, 0, hh / 2), "hull", bevel=0.0)
        for sy in (-1, 1):  # the great door frames
            rbox("d_door_post", (0.8, 0.8, hh + 0.2), (sx * 4.2, sy * (d / 2 + 0.1), (hh + 0.2) / 2), "trim", bevel=0.2)
    rbox("d_lintel_front", (9.2, 0.9, 1.0), (0, -d / 2 - 0.1, hh - 0.2), "trim", bevel=0.15)
    rbox("d_lintel_back", (9.2, 0.9, 1.0), (0, d / 2 + 0.1, hh - 0.2), "trim", bevel=0.15)
    for sy in (-1, 1):  # hazard stripes and lights over the doors
        for k in range(6):
            rbox("d_stripe", (0.6, 0.06, 0.35), (-3.0 + k * 1.2, sy * (d / 2 + 0.58), hh - 0.25), ("dark", "trim")[k % 2],
                 bevel=0.0, rot=(0, math.radians(30), 0))
        for sx in (-1, 1):
            rbox("d_door_light", (0.3, 0.12, 0.3), (sx * 3.5, sy * (d / 2 + 0.6), hh - 1.0), "neon_cyan", bevel=0.0)
    # In the hall: the scanner arch for people on foot, lane markings.
    for sx in (-1, 1):
        rbox("i_scanner_post", (0.3, 0.3, 2.6), (sx * 1.1 - 2.2, 0, 1.3), "steel", bevel=0.05)
    rbox("id_scanner_top", (2.6, 0.35, 0.3), (-2.2, 0, 2.7), "neon_cyan", bevel=0.05)
    for y in (-3.0, 0.0, 3.0):
        rbox("id_lane", (0.2, 1.4, 0.02), (1.2, y, 0.21), "trim", bevel=0.0)
    # West wing: the security office, a door into the hall.
    wall("i_wall", -4.0 + T, -1.5, -4.0, -1.5)  # (stub, keeps the wing's front room square)
    rbox("i_reception", (3.2, 0.8, 1.1), (-7.0, -1.8, 0.55), "trim", bevel=0.05)
    for k in range(3):
        rbox("id_sec_monitor", (0.9, 0.05, 0.6), (-8.0 + k * 1.0, -1.45, 1.5), "glass", bevel=0.0)
        rbox("id_sec_glow", (0.75, 0.04, 0.45), (-8.0 + k * 1.0, -1.42, 1.5), "neon_cyan", bevel=0.0)
    rbox("id_sec_chair", (0.5, 0.5, 0.5), (-7.0, -0.9, 0.25), "dark", bevel=0.08)
    rbox("hull_office_door", (T, DOOR, 0.6), (-4.0, -3.0, 2.7), "hull", bevel=0.0)
    # Equipment room and the cell, behind a wall at y 1.
    wall("i_wall", -w / 2, 1.0, -4.0, 1.0, doors=(2.5, 6.0))
    wall("i_wall", -8.0, 1.0, -8.0, d / 2)
    for k in range(3):
        rbox("i_arms_locker", (0.8, 0.5, 2.0), (-10.8 + k * 0.9, 4.5, 1.1), "dark", bevel=0.03)
    rbox("id_armour_rack", (1.4, 0.3, 1.6), (-9.0, 4.6, 1.0), "steel", bevel=0.02)
    for k in range(6):  # the cell's bars
        cyl("i_bar", 0.04, 2.4, (-7.4 + k * 0.5, 1.15, 1.3), "steel", verts=6)
    rbox("i_cell_bunk", (0.9, 2.0, 0.45), (-4.7, 3.6, 0.33), "rust", bevel=0.04)
    # Remove the office's hall wall at its door (stub above is the frame).
    # East wing: the tower base, stores, stairs up to the watch room.
    rbox("i_stores", (2.0, 1.0, 1.2), (8.5, 3.8, 0.7), "rust", bevel=0.05)
    rbox("hull_tower", (4.0, 4.0, 6.0), (8.5, -1.5, hh + 3.0), "hull", bevel=0.3)
    rbox("d_tower_glass", (4.1, 4.1, 1.2), (8.5, -1.5, hh + 4.6), "glass_dark", bevel=0.1)
    rbox("d_tower_roof", (4.6, 4.6, 0.3), (8.5, -1.5, hh + 6.15), "trim", bevel=0.1)
    cyl("d_beacon", 0.25, 0.4, (8.5, -1.5, hh + 6.5), "neon_pink", verts=8)
    rbox("d_banner", (1.4, 0.08, 3.0), (-6.0, -d / 2 - 0.15, hh - 2.0), "red", bevel=0.0)
    rbox("d_banner2", (1.4, 0.08, 3.0), (6.0, -d / 2 - 0.15, hh - 2.0), "red", bevel=0.0)
    ceiling_lights((-8.0, -6.0), (-2.5, 3.0))
    ceiling_lights((-2.0, 2.0), (-3.0, 0.0, 3.0), z=hh - 0.1)
    export("titan/gatehouse")


# --- export ------------------------------------------------------------------

def _select(pred):
    bpy.ops.object.select_all(action="DESELECT")
    objs = [o for o in bpy.context.scene.objects if o.type == "MESH" and pred(o.name)]
    for o in objs:
        o.select_set(True)
    return objs


def _export(objs, path, materials=True):
    for o in objs:
        for p in o.data.polygons:
            p.use_smooth = False
    tris = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in objs)
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", export_yup=True, export_apply=True,
                              export_materials="EXPORT" if materials else "NONE", use_selection=True)
    print("KIT %s: %d tris" % (os.path.basename(path), tris))


def export(piece):
    D.thicken_open_glass()
    name = piece.split("/")[-1]
    base = os.path.join(OUT, name)
    _export(_select(lambda n: not n.startswith("d_") and not n.startswith("id_")), base + "_col.glb", materials=False)
    _export(_select(lambda n: not n.startswith("i_") and not n.startswith("id_")), base + ".glb")
    _export(_select(lambda n: n.startswith("i_") or n.startswith("id_")), base + "_in.glb")


for build in (hab_r14, market_hub, plant_ex03, gatehouse):
    build()
