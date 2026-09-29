# Asset pipeline (offline, not part of the app)

Turns raw Meshy GLBs (20-260 MB, millions of triangles, 4096 px textures) into phone-sized GLBs.
Its dependencies live only in this folder; nothing here is imported by the app or shipped.

```bash
cd tools/asset-pipeline && npm install
MESHY_API_KEY=msy_... node fetch-meshy.mjs      # raw GLBs -> .cache/src/ (git-ignored). Links expire after ~3 days
node optimize.mjs [out_name ...]                 # -> assets/models/meshy/*.glb + report.json
node validate.mjs                                # budgets + Viro rules, exit 1 on any failure
```

The API key is read from the environment only. Never put it in a file.

## What it does, and why

| Step | Reason |
|---|---|
| weld, simplify (meshoptimizer) to a per-asset triangle budget | the game's shipped GLBs are 6-70 KB; a board holds up to 36 crystals plus covers |
| drop **normal** and occlusion maps | normal maps render black on Viro geometry |
| bake rotation, centring and scale into the vertices | node transforms stay identity, so the model is a drop-in for the game's own mesh (gems span ~1 unit and are scaled by `GEM_SCALE` at runtime, origin = visual centre) |
| resize textures to 256 / 512 px, re-encode as JPEG | 22-37 MB of textures per model was the bulk of the size |
| renormalise normals | simplification leaves non-unit normals (the glTF validator flags them) |
| **no** Draco / meshopt / quantization / WebP | those glTF extensions are not known to load in Viro, so "compression" is decimation + smaller textures in plain glTF 2.0 |

Models stay static: no rig, no animation, one mesh with one primitive (one draw call). Motion is code-driven
on ViroNode wrappers (`src/render/CrystalNode.tsx`).

## Game crystals: `bake-game.mjs` (what actually ships)

The game builds crystals from **in-memory `ViroGeometry`**, not GLB files (a GLB per crystal crashed Viro on the
Tecno). `node bake-game.mjs` turns the raw models into that format: `src/render/meshyMeshes.ts` (generated, indexed
geometry) plus a 256 px base-colour JPEG per model in `assets/textures/meshy/`. `src/render/GemMesh.tsx` renders
them; the materials are registered one at a time at boot (`materialsBoot.ts`).

Meshy textures are cut into hundreds of UV islands, so ordinary simplifiers stall at ~5x the budget (every seam is
a wall). `reproject.mjs` instead simplifies the position-welded mesh, then re-projects each output corner onto the
original textured surface, keeping every triangle inside one UV island.

Budgets (`GAME_LOD` in `config.mjs`) are set by bridge cost: every `ViroGeometry` sends its arrays over the React
Native bridge per instance. ~320 triangles / ~5.3k numbers per gem is ~1.7x the classic meshes; `meshy.test.ts`
fails if a bake goes over. Settings > "Classic crystals" switches back to the built-in meshes.

## Islands: `mid.mjs` then `bake-islands.mjs`

`node --max-old-space-size=14000 mid.mjs <realm ...>` cuts each 2-8M triangle island to ~60k (slow, minutes each,
cached in `.cache/mid`). `node bake-islands.mjs [realm ...]` then, per island: tries 4 yaws x every window, picks the
flattest ground for the board's stone dais (`buildIsland.DAIS`; the unit test checks the numbers stay in sync), bakes
scale/yaw/offset into the vertices so the dais top is exactly `SURFACE_Y`, clamps stray spikes under the dais, and
decimates to a hero LOD (~4.5k triangles) and a far LOD (~700) with the texture kept. Output: `src/render/meshyIslands/`
(lazy per realm) plus a 1024 px texture per realm. The runtime adds the dais and portal arch (`buildDais`).
`gen-fx.mjs` generates the effect and creature sprites (shards, glow, twinkle, gull, butterfly, manta, jellyfish).

Island polish in the bake: normals are recomputed from the decimated surface (the sampled ones come from the
multi-million-triangle original and shade the coarse facets against each other), and the texture gets a light blur
and slightly lower saturation to calm painted noise. At runtime each realm also has a colour grade
(`MeshyIsland.tsx`), drifting mist discs and a slow sun swing (`Life.tsx`), and its own creatures (`life.ts`, tested by
`life.test.ts`).

## Loading

Load through `Model` in `src/render/LoadQueue.tsx` (one GLB at a time): many simultaneous background loads
crashed Viro on the Tecno Camon 19. A board of 36 GLB crystals would queue 36 loads, which is why the game
still builds crystals from in-memory geometry (`GemMesh`). Wiring these in needs a plan for that.

## Preview

`/dev/models` in the web preview shows the optimised models (top row) against the meshes the game uses today.

## Current results

See `assets/models/meshy/report.json`. The aura stays near 5.6k triangles: its textured ring is cut into many
UV islands and the simplifier will not collapse across seams.
