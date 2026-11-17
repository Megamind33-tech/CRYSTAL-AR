"""Top-down map of Kasei Valley: terrain relief plus everything WorldLayout
and CityLayout place. Dump the layout first, then plot:
  godot --headless -s tools/dump_world_layout.gd -- layout.json
  python3 tools/plot_world_map.py layout.json map.png
"""
import json, os, sys
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "blender"))
import world_terrain as W  # noqa: E402

src, out = sys.argv[1], sys.argv[2]
d = json.load(open(src))
half = W.SIZE / 2
xs = np.arange(-half, half, 8.0)
H = np.array([[W.height(x, z) for x in xs] for z in xs])
fig, ax = plt.subplots(figsize=(16, 16), dpi=90)
ax.imshow(H, extent=(-half, half, half, -half), cmap="copper", alpha=0.85)
ax.contour(xs, xs, H, levels=20, colors="k", linewidths=0.25, alpha=0.4)
for r in d["roads"]:
    a = np.array(r)
    ax.plot(a[:, 0], a[:, 1], color="#f5e6c8", lw=3, alpha=0.9)
for name, c, rad in d["regions"]:
    ax.add_patch(plt.Circle(c, rad, fill=False, color="cyan", lw=1.5, ls="--"))
    ax.text(c[0], c[1] - rad - 8, name.upper(), color="cyan", ha="center", fontsize=12, weight="bold")
for name, c, rad in d["landmarks"]:
    ax.add_patch(plt.Circle(c, rad, fill=False, color="yellow", lw=1, ls=":"))
    ax.text(c[0], c[1] + 6, name, color="yellow", ha="center", fontsize=9)
p = np.array([[x[1], x[2]] for x in d["pieces"]])
ax.scatter(p[:, 0], p[:, 1], s=10, c="white", edgecolors="k", linewidths=0.3, label="world pieces")
c = np.array([[x[1], x[2]] for x in d["city"]])
ax.scatter(c[:, 0], c[:, 1], s=8, c="#7fd4ff", label="city pieces")
styles = {"shops": ("P", "lime"), "residences": ("h", "orange"), "trees": ("^", "green"), "rigs": ("X", "red"),
          "garage": ("s", "magenta"), "factory": ("s", "magenta"), "lift": ("v", "magenta"), "convoy": ("D", "red")}
for k, pts in d["misc"].items():
    pts = [q for q in pts if q]
    if not pts:
        continue
    a = np.array(pts)
    if k == "monorail":
        ax.plot(a[:, 0], a[:, 1], color="violet", lw=2, ls="-.", label="monorail")
        continue
    m, col = styles.get(k, ("o", "white"))
    ax.scatter(a[:, 0], a[:, 1], marker=m, c=col, s=60, edgecolors="k", linewidths=0.5, label=k)
ax.set_xlim(-half, half); ax.set_ylim(half, -half)
ax.set_xlabel("x (m, east)"); ax.set_ylabel("z (m, south; up is north)")
ax.grid(alpha=0.2); ax.legend(loc="lower left", fontsize=9)
ax.set_title("Kasei Valley — current layout")
fig.savefig(out, bbox_inches="tight")
print("wrote", out)
