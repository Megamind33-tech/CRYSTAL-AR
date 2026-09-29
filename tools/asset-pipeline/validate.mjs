// Checks every built model against the budgets and the Viro rules; exits non-zero on any failure.
//   node validate.mjs
import { readFileSync, statSync, existsSync } from "node:fs";
import { NodeIO } from "@gltf-transform/core";
import { ALL_EXTENSIONS } from "@gltf-transform/extensions";
import { getBounds } from "@gltf-transform/functions";
import validator from "gltf-validator";
import { ASSETS, OUT_DIR } from "./config.mjs";

const MAX_KB = 512;        // per model
const TRI_SLACK = 1.15;    // the simplifier stops near, not exactly at, the target
const io = new NodeIO().registerExtensions(ALL_EXTENSIONS);
let failed = 0;
for (const a of ASSETS) {
  const file = `${OUT_DIR}${a.out}.glb`;
  const problems = [];
  if (!existsSync(file)) { console.log(`FAIL ${a.out}: missing`); failed++; continue; }
  const buf = readFileSync(file), kb = statSync(file).size / 1024;
  const doc = await io.readBinary(new Uint8Array(buf)), root = doc.getRoot();
  const tris = root.listMeshes().flatMap((m) => m.listPrimitives()).reduce((n, p) => n + p.getIndices().getCount() / 3, 0);
  const rep = await validator.validateBytes(new Uint8Array(buf), { uri: a.out + ".glb" });
  if (rep.issues.numErrors) problems.push(`${rep.issues.numErrors} glTF validator errors: ${rep.issues.messages.filter((m) => m.severity === 0).slice(0, 2).map((m) => m.code).join(",")}`);
  if (root.listExtensionsUsed().length) problems.push("uses extensions: " + root.listExtensionsUsed().map((e) => e.extensionName).join(","));
  if (tris > a.tris * TRI_SLACK) problems.push(`${tris} tris > budget ${a.tris}`);
  if (kb > MAX_KB) problems.push(`${kb.toFixed(0)} KB > ${MAX_KB}`);
  if (root.listMeshes().length !== 1 || root.listMeshes()[0].listPrimitives().length !== 1) problems.push("expected one mesh with one primitive (one draw call)");
  if (root.listSkins().length || root.listAnimations().length) problems.push("has skin/animation (assets must stay static)");
  for (const m of root.listMaterials()) {
    if (m.getNormalTexture()) problems.push("normal map present (renders black on Viro geometry)");
    if (m.getOcclusionTexture()) problems.push("occlusion map present");
  }
  for (const t of root.listTextures()) {
    const [w, h] = t.getSize();
    if (w > a.tex || h > a.tex) problems.push(`texture ${w}x${h} > ${a.tex}`);
    if ((w & (w - 1)) || (h & (h - 1))) problems.push(`texture ${w}x${h} not power of two`);
    if (t.getMimeType() !== "image/jpeg") problems.push(`texture is ${t.getMimeType()} (only JPEG is used)`);
  }
  const b = getBounds(root.listScenes()[0]);
  const size = b.max.map((v, i) => v - b.min[i]), ctr = b.max.map((v, i) => (v + b.min[i]) / 2);
  if (Math.abs(Math.max(...size) - a.maxDim) > 0.01) problems.push(`longest edge ${Math.max(...size).toFixed(3)} != ${a.maxDim}`);
  if (Math.max(...ctr.map(Math.abs)) > 0.01) problems.push(`not centred: ${ctr.map((v) => v.toFixed(3))}`);
  if (root.listNodes().some((n) => n.getMatrix().some((v, i) => Math.abs(v - (i % 5 === 0 ? 1 : 0)) > 1e-6))) problems.push("non-identity node transform (transforms must be baked)");
  console.log(`${problems.length ? "FAIL" : "ok  "} ${a.out.padEnd(11)} ${String(tris).padStart(5)} tris ${kb.toFixed(0).padStart(4)} KB  ${a.tex}px  warnings ${rep.issues.numWarnings}${problems.length ? "  <- " + problems.join("; ") : ""}`);
  if (problems.length) failed++;
}
process.exit(failed ? 1 : 0);
