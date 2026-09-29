// Seam-free decimation for textured meshes.
//
// Why: Meshy textures are cut into many UV islands, so the model is a mesh of split vertices. A simplifier that
// works on the split mesh treats every seam as a border and stalls far above budget (aura: 5.5k of 1.2k). Instead:
//   1. weld the source by POSITION only and simplify that (reaches any budget),
//   2. re-attach UV + normal to every output corner by projecting it onto the ORIGINAL textured surface,
//      keeping each output triangle inside ONE UV island (so it never smears across the atlas),
//   3. re-weld output vertices whose position and UV agree, giving a compact indexed mesh.
import { MeshoptSimplifier } from "meshoptimizer";

/** Closest point on triangle (a,b,c) to p; returns [distSq, u, v, w] barycentric weights of a,b,c. (Ericson) */
function closestOnTri(p, a, b, c) {
  const ab = [b[0]-a[0], b[1]-a[1], b[2]-a[2]], ac = [c[0]-a[0], c[1]-a[1], c[2]-a[2]], ap = [p[0]-a[0], p[1]-a[1], p[2]-a[2]];
  const dot = (x, y) => x[0]*y[0] + x[1]*y[1] + x[2]*y[2];
  const d1 = dot(ab, ap), d2 = dot(ac, ap);
  const fin = (u, v, w) => { const q = [a[0]*u + b[0]*v + c[0]*w - p[0], a[1]*u + b[1]*v + c[1]*w - p[1], a[2]*u + b[2]*v + c[2]*w - p[2]]; return [dot(q, q), u, v, w]; };
  if (d1 <= 0 && d2 <= 0) return fin(1, 0, 0);
  const bp = [p[0]-b[0], p[1]-b[1], p[2]-b[2]], d3 = dot(ab, bp), d4 = dot(ac, bp);
  if (d3 >= 0 && d4 <= d3) return fin(0, 1, 0);
  const vc = d1*d4 - d3*d2;
  if (vc <= 0 && d1 >= 0 && d3 <= 0) { const v = d1 / (d1 - d3); return fin(1 - v, v, 0); }
  const cp = [p[0]-c[0], p[1]-c[1], p[2]-c[2]], d5 = dot(ab, cp), d6 = dot(ac, cp);
  if (d6 >= 0 && d5 <= d6) return fin(0, 0, 1);
  const vb = d5*d2 - d1*d6;
  if (vb <= 0 && d2 >= 0 && d6 <= 0) { const w = d2 / (d2 - d6); return fin(1 - w, 0, w); }
  const va = d3*d6 - d5*d4;
  if (va <= 0 && (d4 - d3) >= 0 && (d5 - d6) >= 0) { const w = (d4 - d3) / ((d4 - d3) + (d5 - d6)); return fin(0, 1 - w, w); }
  const sum = va + vb + vc;
  if (!(Math.abs(sum) > 1e-30)) return fin(1, 0, 0); // degenerate (zero-area) source triangle
  const den = 1 / sum, v = vb * den, w = vc * den;
  return fin(1 - v - w, v, w);
}

/** Uniform grid over the source triangles for nearest-surface queries. */
function buildGrid(P, I, cells) {
  const T = I.length / 3, mn = [Infinity, Infinity, Infinity], mx = [-Infinity, -Infinity, -Infinity];
  for (let i = 0; i < P.length; i += 3) for (let k = 0; k < 3; k++) { mn[k] = Math.min(mn[k], P[i+k]); mx[k] = Math.max(mx[k], P[i+k]); }
  const size = Math.max(mx[0]-mn[0], mx[1]-mn[1], mx[2]-mn[2]) / cells + 1e-9;
  const dim = [0, 1, 2].map((k) => Math.floor((mx[k]-mn[k]) / size) + 1);
  const cellOf = (x, k) => Math.min(dim[k]-1, Math.max(0, Math.floor((x - mn[k]) / size)));
  const map = new Map();
  for (let t = 0; t < T; t++) {
    const lo = [Infinity, Infinity, Infinity], hi = [-Infinity, -Infinity, -Infinity];
    for (let c = 0; c < 3; c++) for (let k = 0; k < 3; k++) { const v = P[I[t*3+c]*3+k]; lo[k] = Math.min(lo[k], v); hi[k] = Math.max(hi[k], v); }
    for (let x = cellOf(lo[0], 0); x <= cellOf(hi[0], 0); x++) for (let y = cellOf(lo[1], 1); y <= cellOf(hi[1], 1); y++) for (let z = cellOf(lo[2], 2); z <= cellOf(hi[2], 2); z++) {
      const key = (x * dim[1] + y) * dim[2] + z; const l = map.get(key); if (l) l.push(t); else map.set(key, [t]);
    }
  }
  return { map, mn, size, dim, cellOf };
}

/** Nearest source-triangle point to p (optionally only triangles of one UV island). */
function nearest(g, S, p, island = -1) {
  const c = [0, 1, 2].map((k) => g.cellOf(p[k], k));
  let best = null;
  const maxRing = Math.max(...g.dim);
  for (let ring = 0; ring <= maxRing; ring++) {
    if (best && Math.sqrt(best.d) <= (ring - 1) * g.size) break;
    for (let x = c[0]-ring; x <= c[0]+ring; x++) for (let y = c[1]-ring; y <= c[1]+ring; y++) for (let z = c[2]-ring; z <= c[2]+ring; z++) {
      if (Math.max(Math.abs(x-c[0]), Math.abs(y-c[1]), Math.abs(z-c[2])) !== ring) continue;
      if (x < 0 || y < 0 || z < 0 || x >= g.dim[0] || y >= g.dim[1] || z >= g.dim[2]) continue;
      const list = g.map.get((x * g.dim[1] + y) * g.dim[2] + z);
      if (!list) continue;
      for (const t of list) {
        if (island >= 0 && S.island[t] !== island) continue;
        const a = S.I[t*3], b = S.I[t*3+1], cc = S.I[t*3+2];
        const r = closestOnTri(p, [S.P[a*3], S.P[a*3+1], S.P[a*3+2]], [S.P[b*3], S.P[b*3+1], S.P[b*3+2]], [S.P[cc*3], S.P[cc*3+1], S.P[cc*3+2]]);
        if (!best || r[0] < best.d) best = { d: r[0], t, w: [r[1], r[2], r[3]] };
      }
    }
  }
  return best;
}

/**
 * @param src   { P, N, U, I } split-vertex source (Float32/Uint arrays)
 * @param budget target triangle count
 * @returns { v:number[], n:number[], t:number[], i:number[] } indexed game mesh
 */
export async function decimateTextured(src, budget, { cells = 40 } = {}) {
  await MeshoptSimplifier.ready;
  const { P, N, U, I } = src;
  // 1. position-only weld + simplify
  const key = new Map(), remap = new Uint32Array(P.length / 3), upos = [];
  for (let i = 0; i < remap.length; i++) {
    const k = `${Math.round(P[i*3]*1e5)},${Math.round(P[i*3+1]*1e5)},${Math.round(P[i*3+2]*1e5)}`;
    let u = key.get(k); if (u === undefined) { u = upos.length / 3; key.set(k, u); upos.push(P[i*3], P[i*3+1], P[i*3+2]); } remap[i] = u;
  }
  const widx = Uint32Array.from(I, (v) => remap[v]), wpos = Float32Array.from(upos);
  let out = null;
  for (const e of [0.01, 0.03, 0.08, 0.2, 1]) { const [o] = MeshoptSimplifier.simplify(widx, wpos, 3, budget * 3, e, []); out = o; if (o.length / 3 <= budget * 1.1) break; }

  // 2. UV islands of the source = connected components of the split-vertex mesh
  const T = I.length / 3, par = new Int32Array(P.length / 3).map((_, i) => i);
  const find = (x) => { while (par[x] !== x) { par[x] = par[par[x]]; x = par[x]; } return x; };
  for (let t = 0; t < T; t++) { const a = find(I[t*3]); par[find(I[t*3+1])] = a; par[find(I[t*3+2])] = a; }
  const island = new Int32Array(T); for (let t = 0; t < T; t++) island[t] = find(I[t*3]);
  const S = { P, N, U, I, island }, grid = buildGrid(P, I, cells);

  // 3. per output triangle: project the 3 corners into ONE island, read UV + normal there
  const uvAt = (q) => { const a = I[q.t*3], b = I[q.t*3+1], c = I[q.t*3+2], [w0, w1, w2] = q.w;
    return { u: U[a*2]*w0 + U[b*2]*w1 + U[c*2]*w2, v: U[a*2+1]*w0 + U[b*2+1]*w1 + U[c*2+1]*w2,
      n: [0, 1, 2].map((k) => N[a*3+k]*w0 + N[b*3+k]*w1 + N[c*3+k]*w2) }; };
  const verts = [], outIdx = [], weld = new Map();
  for (let t = 0; t < out.length; t += 3) {
    const ids = [out[t], out[t+1], out[t+2]], pts = ids.map((v) => [wpos[v*3], wpos[v*3+1], wpos[v*3+2]]);
    let hits = pts.map((p) => nearest(grid, S, p));
    const votes = new Map(); for (const h of hits) votes.set(island[h.t], (votes.get(island[h.t]) ?? 0) + 1);
    let win = [...votes.entries()].sort((a, b) => b[1] - a[1])[0][0];
    if (votes.size === 3) win = island[hits.reduce((a, b) => (a.d <= b.d ? a : b)).t]; // three-way tie: closest corner decides
    for (let k = 0; k < 3; k++) {
      // one UV per (vertex, island): every triangle of that island shares it, so the vertex welds instead of splitting
      const wk = `${ids[k]}|${win}`;
      let vi = weld.get(wk);
      if (vi === undefined) {
        const q = island[hits[k].t] === win ? hits[k] : nearest(grid, S, pts[k], win);
        const s = uvAt(q);
        if (![s.u, s.v, ...s.n].every(Number.isFinite)) { s.u = 0.5; s.v = 0.5; s.n = [0, 1, 0]; }
        const l = Math.hypot(...s.n) || 1;
        vi = verts.length; weld.set(wk, vi);
        verts.push({ p: pts[k], u: s.u, v: s.v, n: s.n.map((x) => x / l) });
      }
      outIdx.push(vi);
    }
  }
  for (const e of verts) { const l = Math.hypot(...e.n) || 1; e.n = e.n.map((x) => x / l); }
  return {
    v: verts.flatMap((e) => e.p), n: verts.flatMap((e) => e.n), t: verts.flatMap((e) => [e.u, e.v]), i: outIdx,
    stats: { srcTris: T, islands: new Set(island).size, tris: out.length / 3, verts: verts.length },
  };
}
