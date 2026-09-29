// Height survey of an island mesh: top surface height on a grid (highest hit per column), flatness of candidate
// board windows, and the shape's footprint. Prints ASCII maps so a model can be judged without opening a viewer.
import { NodeIO } from "@gltf-transform/core";
const io = new NodeIO();
for (const realm of process.argv.slice(2)) {
  const doc = await io.read(`.cache/mid/${realm}.glb`);
  const prim = doc.getRoot().listMeshes()[0].listPrimitives()[0];
  const P = prim.getAttribute("POSITION").getArray(), I = prim.getIndices().getArray();
  const mn = [1e9, 1e9, 1e9], mx = [-1e9, -1e9, -1e9];
  for (let i = 0; i < P.length; i += 3) for (let k = 0; k < 3; k++) { mn[k] = Math.min(mn[k], P[i + k]); mx[k] = Math.max(mx[k], P[i + k]); }
  console.log(`\n== ${realm}: x ${mn[0].toFixed(2)}..${mx[0].toFixed(2)}  y ${mn[1].toFixed(2)}..${mx[1].toFixed(2)}  z ${mn[2].toFixed(2)}..${mx[2].toFixed(2)}`);
  const N = 40, top = Array.from({ length: N }, () => Array(N).fill(-Infinity));
  const cx = (x) => Math.min(N - 1, Math.floor(((x - mn[0]) / (mx[0] - mn[0])) * N)), cz = (z) => Math.min(N - 1, Math.floor(((z - mn[2]) / (mx[2] - mn[2])) * N));
  for (let t = 0; t < I.length; t += 3) for (let c = 0; c < 3; c++) { const v = I[t + c] * 3, i = cz(P[v + 2]), j = cx(P[v]); top[i][j] = Math.max(top[i][j], P[v + 1]); }
  const ys = top.flat().filter(Number.isFinite), yLo = Math.min(...ys), yHi = Math.max(...ys);
  const ramp = " .:-=+*#%@";
  for (let i = 0; i < N; i += 2) console.log(top[i].map((h) => (Number.isFinite(h) ? ramp[Math.min(9, Math.floor(((h - yLo) / (yHi - yLo + 1e-9)) * 10))] : " ")).join(""));
  console.log(`top surface height ${yLo.toFixed(2)}..${yHi.toFixed(2)} (range ${(yHi - yLo).toFixed(2)}), footprint ${ys.length}/${N * N} cells`);
}
