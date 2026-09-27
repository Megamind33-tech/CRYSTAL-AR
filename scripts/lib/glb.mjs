// Tiny flat-shaded mesh builder + GLB (glTF 2.0 binary) writer. No dependencies.
import { writeFileSync } from "node:fs";

export function rng(seed) {
  let s = seed >>> 0;
  return () => {
    s = (s + 0x6d2b79f5) >>> 0;
    let t = s;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

const sub = (a, b) => [a[0] - b[0], a[1] - b[1], a[2] - b[2]];
const cross = (a, b) => [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]];
const norm = (v) => {
  const l = Math.hypot(v[0], v[1], v[2]) || 1;
  return [v[0] / l, v[1] / l, v[2] / l];
};

/** Transform: scale -> rotate (x, y, z order, radians) -> translate. */
export function xf({ s = [1, 1, 1], r = [0, 0, 0], t = [0, 0, 0] } = {}) {
  const sc = typeof s === "number" ? [s, s, s] : s;
  const [cx, sx] = [Math.cos(r[0]), Math.sin(r[0])];
  const [cy, sy] = [Math.cos(r[1]), Math.sin(r[1])];
  const [cz, sz] = [Math.cos(r[2]), Math.sin(r[2])];
  return (p) => {
    let [x, y, z] = [p[0] * sc[0], p[1] * sc[1], p[2] * sc[2]];
    [y, z] = [y * cx - z * sx, y * sx + z * cx];
    [x, z] = [x * cy + z * sy, -x * sy + z * cy];
    [x, y] = [x * cz - y * sz, x * sz + y * cz];
    return [x + t[0], y + t[1], z + t[2]];
  };
}

export class Model {
  constructor() {
    this.materials = [];
    this.buckets = new Map(); // material name -> { pos: [], nrm: [] }
  }
  material(name, { color, metallic = 0, roughness = 0.8, emissive = [0, 0, 0], alpha = 1, doubleSided = false }) {
    this.materials.push({ name, color, metallic, roughness, emissive, alpha, doubleSided });
    this.buckets.set(name, { pos: [], nrm: [] });
    return name;
  }
  /** Adds triangles (array of [a,b,c] point triplets) with flat normals. */
  tris(mat, triangles, transform = (p) => p) {
    const b = this.buckets.get(mat);
    if (!b) throw new Error("unknown material " + mat);
    for (const tri of triangles) {
      const [a, c, d] = tri.map(transform);
      const n = norm(cross(sub(c, a), sub(d, a)));
      if (!Number.isFinite(n[0])) continue;
      for (const p of [a, c, d]) {
        b.pos.push(...p);
        b.nrm.push(...n);
      }
    }
  }
  write(path) {
    const chunks = [];
    let byteLen = 0;
    const bufferViews = [];
    const accessors = [];
    const primitives = [];
    const push = (typed, target) => {
      const bytes = Buffer.from(typed.buffer, typed.byteOffset, typed.byteLength);
      const pad = (4 - (bytes.length % 4)) % 4;
      bufferViews.push({ buffer: 0, byteOffset: byteLen, byteLength: bytes.length, target });
      chunks.push(bytes, Buffer.alloc(pad));
      byteLen += bytes.length + pad;
      return bufferViews.length - 1;
    };
    const matIndex = new Map(this.materials.map((m, i) => [m.name, i]));
    for (const [name, b] of this.buckets) {
      const vcount = b.pos.length / 3;
      for (let start = 0; start < vcount; start += 65535 - (65535 % 3)) {
        const end = Math.min(vcount, start + 65535 - (65535 % 3));
        const pos = new Float32Array(b.pos.slice(start * 3, end * 3));
        const nrm = new Float32Array(b.nrm.slice(start * 3, end * 3));
        const ind = new Uint16Array(end - start).map((_, i) => i);
        const min = [Infinity, Infinity, Infinity], max = [-Infinity, -Infinity, -Infinity];
        for (let i = 0; i < pos.length; i += 3)
          for (let k = 0; k < 3; k++) {
            min[k] = Math.min(min[k], pos[i + k]);
            max[k] = Math.max(max[k], pos[i + k]);
          }
        accessors.push({ bufferView: push(pos, 34962), componentType: 5126, count: end - start, type: "VEC3", min, max });
        const pa = accessors.length - 1;
        accessors.push({ bufferView: push(nrm, 34962), componentType: 5126, count: end - start, type: "VEC3" });
        const na = accessors.length - 1;
        accessors.push({ bufferView: push(ind, 34963), componentType: 5123, count: ind.length, type: "SCALAR" });
        primitives.push({ attributes: { POSITION: pa, NORMAL: na }, indices: accessors.length - 1, material: matIndex.get(name) });
      }
    }
    const gltf = {
      asset: { version: "2.0", generator: "crystals-ar gen-models" },
      scene: 0,
      scenes: [{ nodes: [0] }],
      nodes: [{ mesh: 0 }],
      meshes: [{ primitives }],
      materials: this.materials.map((m) => ({
        name: m.name,
        pbrMetallicRoughness: {
          baseColorFactor: [...m.color, m.alpha],
          metallicFactor: m.metallic,
          roughnessFactor: m.roughness,
        },
        emissiveFactor: m.emissive,
        alphaMode: m.alpha < 1 ? "BLEND" : "OPAQUE",
        doubleSided: m.doubleSided,
      })),
      accessors,
      bufferViews,
      buffers: [{ byteLength: byteLen }],
    };
    const json = Buffer.from(JSON.stringify(gltf));
    const jsonPad = Buffer.alloc((4 - (json.length % 4)) % 4, 0x20);
    const bin = Buffer.concat(chunks);
    const total = 12 + 8 + json.length + jsonPad.length + 8 + bin.length;
    const header = Buffer.alloc(12);
    header.writeUInt32LE(0x46546c67, 0);
    header.writeUInt32LE(2, 4);
    header.writeUInt32LE(total, 8);
    const jh = Buffer.alloc(8);
    jh.writeUInt32LE(json.length + jsonPad.length, 0);
    jh.writeUInt32LE(0x4e4f534a, 4);
    const bh = Buffer.alloc(8);
    bh.writeUInt32LE(bin.length, 0);
    bh.writeUInt32LE(0x004e4942, 4);
    writeFileSync(path, Buffer.concat([header, jh, json, jsonPad, bh, bin]));
    const tri = [...this.buckets.values()].reduce((n, b) => n + b.pos.length / 9, 0);
    return { bytes: total, triangles: tri };
  }
}

// ---- primitive generators (return triangle lists) --------------------------

/**
 * Lofts a sequence of rings. ring: { n, r, y, rot=0, rx, rz, cx=0, cz=0, jitter }
 * A ring with r=0 is an apex. Winding makes outward-facing normals for rings ascending in y.
 */
export function loft(rings, { capBottom = true, capTop = true } = {}) {
  const pts = rings.map((g) => {
    const out = [];
    for (let i = 0; i < g.n; i++) {
      const a = (i / g.n) * Math.PI * 2 + (g.rot || 0);
      const j = g.jitter ? g.jitter(i) : 1;
      out.push([(g.cx || 0) + Math.cos(a) * (g.rx ?? g.r) * j, g.y + (g.dy ? g.dy(i) : 0), (g.cz || 0) + Math.sin(a) * (g.rz ?? g.r) * j]);
    }
    return out;
  });
  const t = [];
  for (let k = 0; k < pts.length - 1; k++) {
    const A = pts[k], B = pts[k + 1], n = A.length;
    for (let i = 0; i < n; i++) {
      const i2 = (i + 1) % n;
      if (rings[k].r === 0) t.push([A[0], B[i], B[i2]]);
      else if (rings[k + 1].r === 0) t.push([A[i], B[0], A[i2]]);
      else {
        t.push([A[i], B[i], B[i2]]);
        t.push([A[i], B[i2], A[i2]]);
      }
    }
  }
  const center = (P) => [P.reduce((s, p) => s + p[0], 0) / P.length, P.reduce((s, p) => s + p[1], 0) / P.length, P.reduce((s, p) => s + p[2], 0) / P.length];
  if (capBottom && rings[0].r !== 0) {
    const P = pts[0], c = center(P);
    for (let i = 0; i < P.length; i++) t.push([c, P[i], P[(i + 1) % P.length]]);
  }
  const last = pts.length - 1;
  if (capTop && rings[last].r !== 0) {
    const P = pts[last], c = center(P);
    for (let i = 0; i < P.length; i++) t.push([c, P[(i + 1) % P.length], P[i]]);
  }
  return t;
}

export const cylinder = (n, r, h, opts = {}) => loft([{ n, r, y: 0, ...opts }, { n, r: opts.rTop ?? r, y: h, ...opts }]);
export const cone = (n, r, h, rot = 0) => loft([{ n, r, y: 0, rot }, { n, r: 0, y: h }]);

/** Icosphere (subdiv 1) with optional per-vertex radial jitter – rocks, bushes, canopies. */
export function blob(r, rand, amount = 0.15, subdiv = 1) {
  const p = (1 + Math.sqrt(5)) / 2;
  let v = [[-1, p, 0], [1, p, 0], [-1, -p, 0], [1, -p, 0], [0, -1, p], [0, 1, p], [0, -1, -p], [0, 1, -p], [p, 0, -1], [p, 0, 1], [-p, 0, -1], [-p, 0, 1]].map(norm);
  let f = [[0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11], [1, 5, 9], [5, 11, 4], [11, 10, 2], [10, 7, 6], [7, 1, 8], [3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9], [4, 9, 5], [2, 4, 11], [6, 2, 10], [8, 6, 7], [9, 8, 1]];
  for (let s = 0; s < subdiv; s++) {
    const cache = new Map();
    const mid = (a, b) => {
      const k = a < b ? a + "_" + b : b + "_" + a;
      if (!cache.has(k)) {
        v.push(norm([(v[a][0] + v[b][0]) / 2, (v[a][1] + v[b][1]) / 2, (v[a][2] + v[b][2]) / 2]));
        cache.set(k, v.length - 1);
      }
      return cache.get(k);
    };
    const nf = [];
    for (const [a, b, c] of f) {
      const ab = mid(a, b), bc = mid(b, c), ca = mid(c, a);
      nf.push([a, ab, ca], [b, bc, ab], [c, ca, bc], [ab, bc, ca]);
    }
    f = nf;
  }
  const scaled = v.map((q) => {
    const k = r * (1 + (rand() * 2 - 1) * amount);
    return [q[0] * k, q[1] * k, q[2] * k];
  });
  return f.map(([a, b, c]) => [scaled[a], scaled[b], scaled[c]]);
}

/** Axis-aligned box centred on origin (for cut stone blocks). */
export function box(w, h, d) {
  const [x, y, z] = [w / 2, h / 2, d / 2];
  const P = [[-x, -y, -z], [x, -y, -z], [x, y, -z], [-x, y, -z], [-x, -y, z], [x, -y, z], [x, y, z], [-x, y, z]];
  const q = (a, b, c, d2) => [[P[a], P[b], P[c]], [P[a], P[c], P[d2]]];
  return [...q(4, 5, 6, 7), ...q(1, 0, 3, 2), ...q(5, 1, 2, 6), ...q(0, 4, 7, 3), ...q(7, 6, 2, 3), ...q(0, 1, 5, 4)];
}

/** Bevelled slab: top face inset by `bevel` – reads as dressed stone rather than a raw box. */
export function slab(w, h, d, bevel) {
  const hw = w / 2, hd = d / 2;
  const ring = (iw, id, y) => [[-iw, y, -id], [iw, y, -id], [iw, y, id], [-iw, y, id]];
  const b0 = ring(hw, hd, 0), b1 = ring(hw, hd, h - bevel), b2 = ring(hw - bevel, hd - bevel, h);
  const t = [];
  const band = (A, B) => {
    for (let i = 0; i < 4; i++) {
      const j = (i + 1) % 4;
      t.push([A[i], B[i], B[j]], [A[i], B[j], A[j]]);
    }
  };
  band(b0, b1);
  band(b1, b2);
  t.push([b2[0], b2[2], b2[1]], [b2[0], b2[3], b2[2]]);
  t.push([b0[0], b0[1], b0[2]], [b0[0], b0[2], b0[3]]);
  return t;
}

/**
 * "Pillow cut" gem from a 2D outline (x,y in [-0.5,0.5]): front and back faces rise to
 * faceted apexes, giving a readable silhouette plus sparkling facets.
 */
export function pillowGem(outline, depth = 0.22, bulge = 0.16, inner = 0.55) {
  let area = 0;
  for (let i = 0; i < outline.length; i++) {
    const [x1, y1] = outline[i], [x2, y2] = outline[(i + 1) % outline.length];
    area += x1 * y2 - x2 * y1;
  }
  if (area < 0) outline = outline.slice().reverse(); // facets assume counter-clockwise
  const n = outline.length;
  const ringF = outline.map(([x, y]) => [x, y, depth / 2]);
  const ringB = outline.map(([x, y]) => [x, y, -depth / 2]);
  const cx = outline.reduce((s, p) => s + p[0], 0) / n, cy = outline.reduce((s, p) => s + p[1], 0) / n;
  const innerF = outline.map(([x, y]) => [cx + (x - cx) * inner, cy + (y - cy) * inner, depth / 2 + bulge * 0.75]);
  const innerB = outline.map(([x, y]) => [cx + (x - cx) * inner, cy + (y - cy) * inner, -depth / 2 - bulge * 0.75]);
  const apexF = [cx, cy, depth / 2 + bulge], apexB = [cx, cy, -depth / 2 - bulge];
  const t = [];
  for (let i = 0; i < n; i++) {
    const j = (i + 1) % n;
    t.push([ringB[i], ringB[j], ringF[j]], [ringB[i], ringF[j], ringF[i]]); // girdle
    t.push([ringF[i], ringF[j], innerF[j]], [ringF[i], innerF[j], innerF[i]]); // crown facets
    t.push([innerF[i], innerF[j], apexF]); // table facets
    t.push([ringB[j], ringB[i], innerB[j]], [ringB[i], innerB[i], innerB[j]]);
    t.push([innerB[j], innerB[i], apexB]);
  }
  return t;
}
