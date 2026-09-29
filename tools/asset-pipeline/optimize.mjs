// Raw Meshy GLB -> phone-sized GLB, plain glTF 2.0 (no Draco / meshopt / quantization / WebP extensions:
// Viro's loaders are not known to support them, so "compression" here is decimation + welding + smaller
// JPEG textures). Steps per asset:
//   weld -> simplify to the triangle budget -> drop normal/occlusion maps -> orient, centre and scale the
//   vertex data itself (node transforms stay identity) -> resize/re-encode textures -> prune -> write.
// Usage: node optimize.mjs [out_name ...]     (no args = everything in config.mjs)
import { mkdirSync, statSync } from "node:fs";
import { NodeIO } from "@gltf-transform/core";
import { ALL_EXTENSIONS } from "@gltf-transform/extensions";
import { weld, simplify, prune, dedup, textureCompress, getBounds, flatten, resample } from "@gltf-transform/functions";
import { MeshoptSimplifier } from "meshoptimizer";
import sharp from "sharp";
import { ASSETS, KEEP_NORMAL, OUT_DIR, SRC_DIR, slug } from "./config.mjs";

await MeshoptSimplifier.ready;
mkdirSync(OUT_DIR, { recursive: true });
const io = new NodeIO().registerExtensions(ALL_EXTENSIONS);
const only = new Set(process.argv.slice(2));

const triCount = (doc) => doc.getRoot().listMeshes().flatMap((m) => m.listPrimitives()).reduce((n, p) => n + (p.getIndices()?.getCount() ?? p.getAttribute("POSITION").getCount()) / 3, 0);

/** Bake a rotation about X, a centring translation and a uniform scale into every vertex position. */
function bake(doc, { rotateX = 0, maxDim }) {
  const prims = doc.getRoot().listMeshes().flatMap((m) => m.listPrimitives());
  const a = (rotateX * Math.PI) / 180, c = Math.cos(a), s = Math.sin(a);
  const rot = ([x, y, z]) => [x, y * c - z * s, y * s + z * c];
  for (const p of prims) {
    for (const name of ["POSITION", "NORMAL"]) {
      const acc = p.getAttribute(name); if (!acc) continue;
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
  let mn = [Infinity, Infinity, Infinity], mx = [-Infinity, -Infinity, -Infinity];
  for (const p of prims) { const acc = p.getAttribute("POSITION"), v = [0, 0, 0]; for (let i = 0; i < acc.getCount(); i++) { acc.getElement(i, v); for (let k = 0; k < 3; k++) { mn[k] = Math.min(mn[k], v[k]); mx[k] = Math.max(mx[k], v[k]); } } }
  const ctr = mn.map((v, k) => (v + mx[k]) / 2), k = maxDim / Math.max(...mx.map((v, i) => v - mn[i]));
  for (const p of prims) { const acc = p.getAttribute("POSITION"), v = [0, 0, 0]; for (let i = 0; i < acc.getCount(); i++) { acc.getElement(i, v); acc.setElement(i, v.map((x, j) => (x - ctr[j]) * k)); } }
  return { scale: k, shift: ctr };
}

const report = [];
for (const spec of ASSETS) {
  if (only.size && !only.has(spec.out)) continue;
  const srcFile = `${SRC_DIR}${slug(spec.name)}.glb`;
  let doc = await io.read(srcFile);
  const before = { tris: triCount(doc), mb: statSync(srcFile).size / 1e6 };

  // the model is the mesh in the scene; flatten any node transforms into it first
  await doc.transform(flatten());
  await doc.transform(weld({ tolerance: 1e-5 }));

  // simplify toward the budget. One meshopt pass often stops short (seams, error cap), so repeat passes
  // re-aim at the budget from the current mesh; the error cap loosens per pass, and it stops as soon as a
  // pass makes no progress. Each pass runs on a copy so a bad one can be discarded.
  let tris = triCount(doc);
  for (const error of [0.01, 0.02, 0.05, 0.1, 0.2, 0.4, 0.8]) {
    if (tris <= spec.tris * 1.05) break;
    const attempt = await io.readBinary(await io.writeBinary(doc));
    await attempt.transform(simplify({ simplifier: MeshoptSimplifier, ratio: Math.min(1, spec.tris / tris), error, lockBorder: false }));
    const t = triCount(attempt);
    if (t < tris) { doc = attempt; tris = t; spec.usedError = error; }
  }

  // materials: keep base colour, metal/rough and emissive; drop normal + occlusion maps (Viro rule)
  for (const m of doc.getRoot().listMaterials()) {
    if (!KEEP_NORMAL) m.setNormalTexture(null);
    m.setOcclusionTexture(null);
    m.setDoubleSided(!!spec.doubleSided);
  }
  const baked = bake(doc, spec);
  await doc.transform(
    textureCompress({ encoder: sharp, resize: [spec.tex, spec.tex], targetFormat: "jpeg", quality: 82 }),
    dedup(), prune(),
  );
  doc.getRoot().listScenes()[0].setName(spec.out);
  const outFile = `${OUT_DIR}${spec.out}.glb`;
  await io.write(outFile, doc);
  const bounds = getBounds(doc.getRoot().listScenes()[0]);
  const row = {
    out: spec.out, from: spec.name, tris_before: before.tris, tris_after: tris, mb_before: +before.mb.toFixed(1),
    kb_after: Math.round(statSync(outFile).size / 1024), tex: spec.tex, error: spec.usedError,
    size: bounds.max.map((v, i) => +(v - bounds.min[i]).toFixed(3)), scale: +baked.scale.toFixed(4),
  };
  report.push(row);
  console.log(`${row.out.padEnd(11)} ${String(row.tris_before).padStart(8)} -> ${String(row.tris_after).padStart(5)} tris  ${String(row.mb_before).padStart(5)} MB -> ${String(row.kb_after).padStart(4)} KB  size ${row.size.join("x")}  (simplify error ${row.error})`);
}
const { writeFileSync } = await import("node:fs");
writeFileSync(`${OUT_DIR}report.json`, JSON.stringify(report, null, 1) + "\n");
