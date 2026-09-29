// Raw Meshy GLB -> phone-sized GLB, plain glTF 2.0 (no Draco / meshopt / quantization / WebP extensions:
// Viro's loaders are not known to support them, so "compression" here is decimation + welding + smaller
// JPEG textures). Steps per asset:
//   weld -> simplify to the triangle budget -> drop normal/occlusion maps -> orient, centre and scale the
//   vertex data itself (node transforms stay identity) -> resize/re-encode textures -> prune -> write.
// Usage: node optimize.mjs [out_name ...]     (no args = everything in config.mjs)
import { mkdirSync, statSync } from "node:fs";
import { NodeIO } from "@gltf-transform/core";
import { ALL_EXTENSIONS } from "@gltf-transform/extensions";
import { weld, prune, dedup, textureCompress, getBounds, flatten } from "@gltf-transform/functions";
import { MeshoptSimplifier } from "meshoptimizer";
import { bake, simplifyTo, triCount } from "./lib.mjs";
import sharp from "sharp";
import { ASSETS, KEEP_NORMAL, OUT_DIR, SRC_DIR, slug } from "./config.mjs";

await MeshoptSimplifier.ready;
mkdirSync(OUT_DIR, { recursive: true });
const io = new NodeIO().registerExtensions(ALL_EXTENSIONS);
const only = new Set(process.argv.slice(2));

const report = [];
for (const spec of ASSETS) {
  if (only.size && !only.has(spec.out)) continue;
  const srcFile = `${SRC_DIR}${slug(spec.name)}.glb`;
  let doc = await io.read(srcFile);
  const before = { tris: triCount(doc), mb: statSync(srcFile).size / 1e6 };

  // the model is the mesh in the scene; flatten any node transforms into it first
  await doc.transform(flatten());
  await doc.transform(weld({ tolerance: 1e-5 }));

  const simplified = await simplifyTo(doc, io, spec.tris);
  doc = simplified.doc;
  const tris = simplified.tris;
  spec.usedError = simplified.error;

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
