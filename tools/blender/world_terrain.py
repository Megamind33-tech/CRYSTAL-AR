# Kasei Valley's terrain height (metres) at world x, z (Godot axes: -Z is
# north). MUST match maps/world/world_terrain.gd line for line: Blender builds
# the visible mesh from this, the game builds collision and places the
# settlements with the GDScript copy.
import math

SIZE = 1600.0         # the world is SIZE x SIZE metres, centred on 0
STEP = 5.0            # grid spacing
CITY = (-220.0, 20.0, 14.0, 80.0, 150.0)     # x, z, height, flat radius, outer radius
HOLLOW = (60.0, -60.0, 2.0, 52.0, 95.0)
# The outlands' districts (flattened like the settlements).
HELIOS = (-520.0, -470.0, 18.0, 120.0, 180.0)    # Helios Arcology: towers and the ring
GALLERIA = (-560.0, 200.0, 16.0, 80.0, 130.0)     # the Prism Galleria (mall)
TERRACE = (470.0, 430.0, 6.0, 105.0, 165.0)       # Nova Terrace (homes)
SKYPORT = (520.0, -440.0, 10.0, 115.0, 170.0)     # Kasei Skyport
SITES = (CITY, HOLLOW, HELIOS, GALLERIA, TERRACE, SKYPORT)
DIG = (235.0, 3.0, 64.0)                     # canyon floor x range start, floor height, ...
MESAS = [(-60.0, -230.0, 46.0, 30.0), (255.0, -60.0, 34.0, 24.0), (-310.0, -210.0, 56.0, 34.0),
         (30.0, 250.0, 28.0, 22.0), (-90.0, 200.0, 26.0, 18.0),
         # the outlands
         (-420.0, -130.0, 40.0, 34.0), (360.0, 80.0, 42.0, 30.0), (-150.0, 560.0, 52.0, 40.0),
         (150.0, -560.0, 44.0, 30.0), (640.0, -60.0, 60.0, 44.0), (-660.0, 470.0, 48.0, 38.0),
         (-300.0, -620.0, 36.0, 26.0), (250.0, 620.0, 40.0, 32.0)]
CRATER = (150.0, -240.0, 58.0)
CRATER2 = (-330.0, 400.0, 75.0)


def smoothstep(e0, e1, x):
    t = min(max((x - e0) / (e1 - e0), 0.0), 1.0)
    return t * t * (3.0 - 2.0 * t)


def canyon_center(x):
    return 150.0 + 42.0 * math.sin(x * 0.012)


def height(x, z):
    h = 6.0 * math.sin(x * 0.011 + 0.7) * math.cos(z * 0.009) + 3.0 * math.sin(x * 0.023 - z * 0.017)
    h += 0.9 * math.sin(x * 0.09 + math.sin(z * 0.05) * 2.0) * math.cos(z * 0.031)  # dunes
    edge = max(abs(x), abs(z))
    # The outlands roll: long low swells beyond the old valley.
    out = smoothstep(330.0, 470.0, edge)
    h += out * (9.0 * math.sin(x * 0.0071 + 1.3) * math.cos(z * 0.0063 - 0.4) + 4.0 * math.sin(x * 0.017 + z * 0.013))
    h += smoothstep(690.0, 790.0, edge) * 70.0  # the basin's rim
    for cx, cz, r, mh in MESAS:
        d = math.hypot(x - cx, z - cz)
        h += mh * smoothstep(r + 16.0, r, d)
    cx, cz, cr = CRATER
    d = math.hypot(x - cx, z - cz)
    h += 9.0 * math.exp(-((d - cr) / 12.0) ** 2) - 12.0 * smoothstep(cr, cr * 0.4, d)
    cx, cz, cr = CRATER2
    d = math.hypot(x - cx, z - cz)
    h += 12.0 * math.exp(-((d - cr) / 15.0) ** 2) - 16.0 * smoothstep(cr, cr * 0.4, d)
    # The canyon east: a winding channel down to the dig's floor.
    dz = abs(z - canyon_center(x))
    depth = 22.0 * (1.0 - smoothstep(16.0, 40.0, dz)) * smoothstep(40.0, 110.0, x) * (1.0 - smoothstep(360.0, 395.0, x))
    h -= depth
    # Flat ground for the settlements (the city on its plateau).
    for sx, sz, sh, flat, outer in SITES:
        d = math.hypot(x - sx, z - sz)
        h += (sh - h) * smoothstep(outer, flat, d)
    return h
