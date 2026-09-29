# Asset licenses

Models, sounds and branding are **original** and generated from code in this repo (regenerate with
`yarn gen:assets`). The only third-party game content is a set of **CC0** photo-scanned surface
textures (listed below), used on the runtime-generated islands.

| Asset(s) | Author | Source | License | Commercial use | Attribution | Modified | Local path |
|---|---|---|---|---|---|---|---|
| Crystal models (Ember Core, Tide Sapphire, Leaf Emerald, Void Amethyst, Solar Shard), Solar relic, obstacle meshes (ice, vines, chains, embers, cracked stone, runes), Prism, Surge aura | Crystals AR project | `scripts/gen-models.mjs` | Project-owned | Yes | None | n/a | `assets/models/gem_*.glb`, `surge_aura.glb` |
| Forest Ruins diorama (terrain, prop clusters, platform, portal, waterfall, blooms, vines, glow clusters, ground shadow) | Crystals AR project | `scripts/gen-models.mjs` | Project-owned | Yes | None | n/a | `assets/models/*.glb` |
| Realm islands (terrain, underside, portal arch, props) – built at runtime per level seed | Crystals AR project | `src/render/island/buildIsland.ts` | Project-owned | Yes | None | n/a | (generated in memory) |
| Particle sprite, shockwave ring, HDR lighting environment | Crystals AR project | `scripts/gen-models.mjs` | Project-owned | Yes | None | n/a | `assets/textures/` |
| All sound effects + Forest Ruins ambient loop (synthesised) | Crystals AR project | `scripts/gen-audio.mjs` | Project-owned | Yes | None | n/a | `assets/audio/*.wav` |
| App icon, adaptive icon layers, monochrome icon, splash, favicon | Crystals AR project | `scripts/gen-branding.mjs` | Project-owned | Yes | None | n/a | `assets/images/` |

## CC-BY 3.0 models (Poly Pizza) — attribution required

Supplied by the project owner on 2026-09-28; licence verified on each model page. Credited in-app in
Settings → Credits. Used unmodified (scaled/rotated at runtime only).

| Asset | Author | Source | License | Commercial use | Attribution | Modified | Local path |
|---|---|---|---|---|---|---|---|
| Red Dragon | Tomek Zamojski | https://poly.pizza/m/5SgYrV6nhws | CC-BY 3.0 | Yes | **Required** (Settings → Credits) | No | `assets/models/dragon_red.glb` |
| Dragon Rigged | na3ee1 | https://poly.pizza/m/WIOTISRjeX | CC-BY 3.0 | Yes | **Required** (Settings → Credits) | No | `assets/models/dragon_green.glb` |
| Flamethrower Turret | Zsky | https://poly.pizza/m/qNt5FqDnK6 | CC-BY 3.0 | Yes | **Required** (Settings → Credits) | No | `assets/models/flame_turret.glb` |

## CC0 HDRI (Poly Haven)

| Asset | Author | Source | License | Commercial use | Attribution | Modified | Local path |
|---|---|---|---|---|---|---|---|
| Studio Small 09 | Sergej Majboroda | https://polyhaven.com/a/studio_small_09 | CC0 1.0 | Yes | Not required | Resized 1K → 512×256 Radiance HDR | `assets/textures/studio_hdri.hdr` |

## CC0 surface textures (ambientCG)

Downloaded 2026-09-28 as the 1K-JPG packs; processed by `scripts/process-textures.mjs` (source zips are
kept outside the repo in `%LOCALAPPDATA%/crystals-asset-cache/acg`). CC0 1.0 = public domain dedication:
commercial use allowed, no attribution required (credited here anyway).

| Asset | Author | Source | License | Commercial use | Attribution | Modified | Local path |
|---|---|---|---|---|---|---|---|
| Grass004 (`grass`) | ambientCG (Lennart Demes) | https://ambientcg.com/view?id=Grass004 | CC0 1.0 | Yes | Not required | Colour, NormalGL, Roughness maps kept; resized 1K → 512 px JPEG | `assets/textures/pbr/grass_{c,n,r}.jpg` |
| Ground037 (`moss`) | ambientCG (Lennart Demes) | https://ambientcg.com/view?id=Ground037 | CC0 1.0 | Yes | Not required | Colour, NormalGL, Roughness maps kept; resized 1K → 512 px JPEG | `assets/textures/pbr/moss_{c,n,r}.jpg` |
| Rock063 (`rock`) | ambientCG (Lennart Demes) | https://ambientcg.com/view?id=Rock063 | CC0 1.0 | Yes | Not required | Colour, NormalGL, Roughness maps kept; resized 1K → 512 px JPEG | `assets/textures/pbr/rock_{c,n,r}.jpg` |
| Rock051 (`cliff`) | ambientCG (Lennart Demes) | https://ambientcg.com/view?id=Rock051 | CC0 1.0 | Yes | Not required | Colour, NormalGL, Roughness maps kept; resized 1K → 512 px JPEG | `assets/textures/pbr/cliff_{c,n,r}.jpg` |
| Rock064 (`rockMoss`) | ambientCG (Lennart Demes) | https://ambientcg.com/view?id=Rock064 | CC0 1.0 | Yes | Not required | Colour, NormalGL, Roughness maps kept; resized 1K → 512 px JPEG | `assets/textures/pbr/rockMoss_{c,n,r}.jpg` |
| Rock058 (`rockDark`) | ambientCG (Lennart Demes) | https://ambientcg.com/view?id=Rock058 | CC0 1.0 | Yes | Not required | Colour, NormalGL, Roughness maps kept; resized 1K → 512 px JPEG | `assets/textures/pbr/rockDark_{c,n,r}.jpg` |
| Ground054 (`sand`) | ambientCG (Lennart Demes) | https://ambientcg.com/view?id=Ground054 | CC0 1.0 | Yes | Not required | Colour, NormalGL, Roughness maps kept; resized 1K → 512 px JPEG | `assets/textures/pbr/sand_{c,n,r}.jpg` |
| Snow014 (`snow`) | ambientCG (Lennart Demes) | https://ambientcg.com/view?id=Snow014 | CC0 1.0 | Yes | Not required | Colour, NormalGL, Roughness maps kept; resized 1K → 512 px JPEG | `assets/textures/pbr/snow_{c,n,r}.jpg` |
| Ice003 (`ice`) | ambientCG (Lennart Demes) | https://ambientcg.com/view?id=Ice003 | CC0 1.0 | Yes | Not required | Colour, NormalGL, Roughness maps kept; resized 1K → 512 px JPEG | `assets/textures/pbr/ice_{c,n,r}.jpg` |
| Lava004 (`lava`) | ambientCG (Lennart Demes) | https://ambientcg.com/view?id=Lava004 | CC0 1.0 | Yes | Not required | Colour, NormalGL, Roughness maps kept; resized 1K → 512 px JPEG | `assets/textures/pbr/lava_{c,n,r}.jpg` |
| Bark014 (`bark`) | ambientCG (Lennart Demes) | https://ambientcg.com/view?id=Bark014 | CC0 1.0 | Yes | Not required | Colour, NormalGL, Roughness maps kept; resized 1K → 512 px JPEG | `assets/textures/pbr/bark_{c,n,r}.jpg` |
| Ground109 (`dirt`) | ambientCG (Lennart Demes) | https://ambientcg.com/view?id=Ground109 | CC0 1.0 | Yes | Not required | Colour, NormalGL, Roughness maps kept; resized 1K → 512 px JPEG | `assets/textures/pbr/dirt_{c,n,r}.jpg` |
| Gravel023 (`gravel`) | ambientCG (Lennart Demes) | https://ambientcg.com/view?id=Gravel023 | CC0 1.0 | Yes | Not required | Colour, NormalGL, Roughness maps kept; resized 1K → 512 px JPEG | `assets/textures/pbr/gravel_{c,n,r}.jpg` |
| PavingStones138 (`paving`) | ambientCG (Lennart Demes) | https://ambientcg.com/view?id=PavingStones138 | CC0 1.0 | Yes | Not required | Colour, NormalGL, Roughness maps kept; resized 1K → 512 px JPEG | `assets/textures/pbr/paving_{c,n,r}.jpg` |

Runtime-bundled third-party content (not game assets):

| Item | Where | License |
|---|---|---|
| Roboto font inside `viro-web.data` (web mock only) | `@reactvision/viro-web-renderer` | Apache-2.0 (shipped with the package) |

The match logic is an original TypeScript implementation. `sanyabeast/match3` (ISC) was inspected as a
reference only; no code or assets were copied.

## Meshy AI-generated models (assets/models/meshy/)
Eight crystal models (five gems, Prism, Relic, Surge Aura) generated with Meshy from this project's own prompts and
reference images, then decimated by `tools/asset-pipeline`. Ownership and commercial-use rights depend on the Meshy
plan the tasks were generated under: **confirm the plan's terms before release**. They are not used by the game yet
(only the `/dev/models` comparison page loads them).

