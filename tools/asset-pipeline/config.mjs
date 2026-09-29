// What to build and to what budget. Sizes are in the units of the game's existing procedural meshes
// (src/render/gemMeshes.ts): gems span ~1 unit and are scaled at runtime by GEM_SCALE (0.036 m), so the
// baked scale here makes a Meshy model a drop-in for the mesh it replaces. Positions are re-centred on the
// bounding box (the procedural gems are centred too), so the node origin is the visual centre.
//
// Budgets are deliberately small: the shipped GLBs are 6-70 KB (the biggest asset, a CC-BY dragon, is 3.6 MB)
// and a board holds up to 36 crystals plus covers on a Helio G85 phone.

export const SRC_DIR = process.env.MESHY_SRC ?? new URL("./.cache/src/", import.meta.url).pathname;
export const OUT_DIR = new URL("../../assets/models/meshy/", import.meta.url).pathname;

/**
 * name    Meshy task name (fetch-meshy.mjs saves it as <slug>.glb)
 * out     output file / existing mesh it can stand in for
 * maxDim  longest bounding-box edge after scaling
 * tris    triangle budget (simplifier stops at or under this; validate.mjs allows +15%)
 * tex     square texture size in px (power of two), applied to every kept map
 * rotateX degrees about X applied before scaling (orient a model like the mesh it replaces)
 * doubleSided keep back faces (thin plates only; closed gems cull them)
 */
export const ASSETS = [
  { name: "Ember Core", out: "gem_red", maxDim: 1.0, tris: 1500, tex: 256, doubleSided: false },
  { name: "Tide Sapphire", out: "gem_blue", maxDim: 1.0, tris: 1500, tex: 256, doubleSided: false },
  { name: "Leaf Emerald", out: "gem_green", maxDim: 1.0, tris: 1500, tex: 256, doubleSided: false },
  { name: "Void Amethyst", out: "gem_purple", maxDim: 1.0, tris: 1500, tex: 256, doubleSided: false },
  { name: "Solar Shard", out: "gem_gold", maxDim: 1.0, tris: 1500, tex: 256, doubleSided: false },
  { name: "Prism", out: "gem_prism", maxDim: 1.1, tris: 2500, tex: 512, doubleSided: false },
  { name: "Relic", out: "gem_relic", maxDim: 1.32, tris: 2500, tex: 512, doubleSided: true },
  // Meshy's aura is a ring lying in XZ; the game's aura is a plate in XY (thin in Z), yawed 0/90 in code.
  // Its ~5.5k-triangle floor is real: the textured ring is cut into many UV islands and the simplifier will not
  // collapse across seams (one aura per special gem on the board, so the cost is small)
  { name: "Surge Aura", out: "surge_aura", maxDim: 1.84, tris: 5600, tex: 512, rotateX: 90, doubleSided: true },
];

export const slug = (s) => s.toLowerCase().replace(/[^a-z0-9]+/g, "_").replace(/^_|_$/g, "");

/** Maps that survive. Normal maps are dropped (they render black on Viro geometry) and so is occlusion. */
export const KEEP_NORMAL = false;
