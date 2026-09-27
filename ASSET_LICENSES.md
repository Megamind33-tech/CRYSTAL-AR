# Asset licenses

Every game asset in Crystals AR is **original** and generated from code in this repo — no third-party
models, textures or sounds are used. Regenerate with `yarn gen:assets`.

| Asset(s) | Author | Source | License | Commercial use | Attribution | Modified | Local path |
|---|---|---|---|---|---|---|---|
| Crystal models (Ember Heart, Deep Diamond, Leaf Emerald, Spiral Amethyst, Sun Star), Prism, Surge aura | Crystals AR project | `scripts/gen-models.mjs` | Project-owned | Yes | None | n/a | `assets/models/gem_*.glb`, `surge_aura.glb` |
| Forest Ruins diorama (terrain, prop clusters, platform, portal, waterfall, blooms, vines, glow clusters, ground shadow) | Crystals AR project | `scripts/gen-models.mjs` | Project-owned | Yes | None | n/a | `assets/models/*.glb` |
| Particle sprite, shockwave ring, HDR lighting environment | Crystals AR project | `scripts/gen-models.mjs` | Project-owned | Yes | None | n/a | `assets/textures/` |
| All sound effects + Forest Ruins ambient loop (synthesised) | Crystals AR project | `scripts/gen-audio.mjs` | Project-owned | Yes | None | n/a | `assets/audio/*.wav` |
| App icon, adaptive icon layers, monochrome icon, splash, favicon | Crystals AR project | `scripts/gen-branding.mjs` | Project-owned | Yes | None | n/a | `assets/images/` |

Runtime-bundled third-party content (not game assets):

| Item | Where | License |
|---|---|---|
| Roboto font inside `viro-web.data` (web mock only) | `@reactvision/viro-web-renderer` | Apache-2.0 (shipped with the package) |

The match logic is an original TypeScript implementation. `sanyabeast/match3` (ISC) was inspected as a
reference only; no code or assets were copied.
