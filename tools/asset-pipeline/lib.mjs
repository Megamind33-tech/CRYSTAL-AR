// Shared mesh steps for optimize.mjs (GLB files) and bake-game.mjs (in-memory game geometry).
import { MeshoptSimplifier } from "meshoptimizer";

export const triCount = (doc) =>
  doc.getRoot().listMeshes().flatMap((m) => m.listPrimitives()).reduce((n, p) => n + (p.getIndices()?.getCount() ?? p.getAttribute("POSITION").getCount()) / 3, 0);

/**
 * Simplify to `budget` triangles with meshopt's attribute-aware simplifier (experimental in 0.22). Meshy textures
 * are cut into many UV islands, so a position-only simplifier treats every seam as a wall and bottoms out far
 * above budget (aura: 5.5k of 1.2k). Here UV and normal differences are part of the collapse cost, so seams can
 * collapse where the texture allows it. Vertices left unused are compacted away afterwards.
 */
export async function simplifyTo(doc, io, budget, { uvWeight = 1, normalWeight = 0.4, error = 1, prune = true } = {}) {
  await MeshoptSimplifier.ready;
  MeshoptSimplifier.useExperimentalFeatures = true;
  const prim = doc.getRoot().listMeshes()[0].listPrimitives()[0];
  const posA = prim.getAttribute("POSITION"), nrmA = prim.getAttribute("NORMAL"), uvA = prim.getAttribute("TEXCOORD_0");
  const n = posA.getCount(), before = prim.getIndices().getCount() / 3;
  if (before <= budget) return { doc, tris: before, error: 0 };
  const pos = Float32Array.from(posA.getArray());
  const attrs = new Float32Array(n * 5);
  for (let i = 0; i < n; i++) {
    attrs.set(uvA.getArray().subarray(i * 2, i * 2 + 2), i * 5);
    attrs.set(nrmA.getArray().subarray(i * 3, i * 3 + 3), i * 5 + 2);
  }
  const idx = Uint32Array.from(prim.getIndices().getArray());
  // Walk an error ladder: a small cap keeps the most shape; Prune drops tiny disconnected pieces (filigree,
  // sparks) that edge collapse can never remove, but with a loose cap it eats the whole model. Take the first
  // result that lands within budget without collapsing below ~35% of it; otherwise the closest non-empty one.
  const w = [uvWeight, uvWeight, normalWeight, normalWeight, normalWeight];
  let best = null;
  for (const e of [0.01, 0.02, 0.04, 0.08, 0.15, 0.3, 0.6]) {
    const [o, er] = MeshoptSimplifier.simplifyWithAttributes(idx, pos, 3, attrs, 5, w, null, budget * 3, e, prune ? ["Prune"] : []);
    const t = o.length / 3;
    if (t === 0) break;
    if (!best || Math.abs(t - budget) < Math.abs(best.t - budget)) best = { o, er, t };
    if (t <= budget * 1.1 && t >= budget * 0.35) { best = { o, er, t }; break; }
  }
  const [out, err] = [best.o, best.er];
  // compact: keep only vertices still referenced, in first-use order
  const remap = new Int32Array(n).fill(-1);
  let count = 0;
  const idxOut = new Uint32Array(out.length);
  for (let k = 0; k < out.length; k++) { const v = out[k]; if (remap[v] < 0) remap[v] = count++; idxOut[k] = remap[v]; }
  for (const sem of prim.listSemantics()) {
    const acc = prim.getAttribute(sem), size = acc.getElementSize(), src = acc.getArray(), dst = new src.constructor(count * size);
    for (let v = 0; v < n; v++) if (remap[v] >= 0) dst.set(src.subarray(v * size, v * size + size), remap[v] * size);
    acc.setArray(dst);
  }
  prim.getIndices().setArray(count > 65535 ? idxOut : Uint16Array.from(idxOut));
  return { doc, tris: idxOut.length / 3, error: err };
}

/** Bake a rotation about X, a centring translation and a uniform scale into every vertex position. */
export function bake(doc, { rotateX = 0, maxDim }) {
  const prims = doc.getRoot().listMeshes().flatMap((m) => m.listPrimitives());
  const a = (rotateX * Math.PI) / 180, c = Math.cos(a), s = Math.sin(a);
  const rot = ([x, y, z]) => [x, y * c - z * s, y * s + z * c];
  for (const p of prims) {
    for (const name of ["POSITION", "NORMAL"]) {
      const acc = p.getAttribute(name);
      if (!acc) continue;
      const v = [0, 0, 0];
      for (let i = 0; i < acc.getCount(); i++) {
        acc.getElement(i, v);
        let r = rot(v);
        if (name === "NORMAL") { // simplification can leave near-zero or non-unit normals: renormalise (glTF requires unit length)
          const l = Math.hypot(r[0], r[1], r[2]);
          r = l > 1e-6 ? r.map((x) => x / l) : [0, 1, 0];
        }
        acc.setElement(i, r);
      }
    }
  }
  const mn = [Infinity, Infinity, Infinity], mx = [-Infinity, -Infinity, -Infinity];
  for (const p of prims) { const acc = p.getAttribute("POSITION"), v = [0, 0, 0]; for (let i = 0; i < acc.getCount(); i++) { acc.getElement(i, v); for (let k = 0; k < 3; k++) { mn[k] = Math.min(mn[k], v[k]); mx[k] = Math.max(mx[k], v[k]); } } }
  const ctr = mn.map((v, k) => (v + mx[k]) / 2), k = maxDim / Math.max(...mx.map((v, i) => v - mn[i]));
  for (const p of prims) { const acc = p.getAttribute("POSITION"), v = [0, 0, 0]; for (let i = 0; i < acc.getCount(); i++) { acc.getElement(i, v); acc.setElement(i, v.map((x, j) => (x - ctr[j]) * k)); } }
  return { scale: k, shift: ctr };
}
