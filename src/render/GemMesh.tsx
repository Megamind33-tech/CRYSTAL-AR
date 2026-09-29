import { memo } from "react";
import { ViroGeometry, ViroMaterials, ViroNode } from "@reactvision/react-viro";
import { GEM_MESHES } from "./gemMeshes";

type V3 = [number, number, number];
interface Part {
  material: string;
  vertices: V3[];
  normals: V3[];
  indices: V3[];
}

/**
 * Crystals are built from in-memory geometry instead of GLB files. Creating a ViroGeometry needs
 * no background file load, so spawning crystals mid-game can't trip Viro's async task scheduler
 * (it aborted in VROPlatformRunTask on a Tecno Camon 19). It is also cheaper on mid-range phones.
 */
const cache = new Map<string, Part[]>();
let materialsReady = false;

export function registerGemMaterials() {
  if (materialsReady) return;
  materialsReady = true;
  const defs: Record<string, object> = {};
  for (const parts of Object.values(GEM_MESHES)) {
    for (const p of parts) {
      const rgb = p.color.map((c) => Math.round(Math.min(1, c) * 255));
      const glow = p.emissive.some((e) => e > 0.4);
      const cull = p.doubleSided ? { cullMode: "None" } : {};
      const solid = `rgb(${rgb.join(",")})`;
      const clear = `rgba(${rgb.join(",")},${p.alpha})`;
      // crystal shells keep their glassy PBR; small props are matte
      const gem = p.material.startsWith("gem_") || p.material.startsWith("prism_") || p.material === "surge";
      // gem shells: near-mirror facets that pick up the studio HDRI highlights
      const shell = gem ? { roughness: 0.03, metalness: 0.55 } : { roughness: 0.1, metalness: 0.3 };
      defs["gm_" + p.material] =
        p.alpha < 1
          ? { lightingModel: glow ? "Constant" : "PBR", diffuseColor: clear, blendMode: "Alpha", ...shell, writesToDepthBuffer: !glow, ...cull }
          : glow
            ? { lightingModel: "Constant", diffuseColor: solid, ...cull }
            : { lightingModel: "PBR", diffuseColor: solid, roughness: gem ? 0.2 : 0.8, metalness: gem ? 0.3 : 0.02, ...cull };
    }
  }
  ViroMaterials.createMaterials(defs as never);
}

function parts(name: string): Part[] {
  let out = cache.get(name);
  if (out) return out;
  out = (GEM_MESHES[name] ?? []).map((p) => {
    const vertices: V3[] = [], normals: V3[] = [], indices: V3[] = [];
    for (let i = 0; i < p.v.length; i += 3) {
      vertices.push([p.v[i], p.v[i + 1], p.v[i + 2]]);
      normals.push([p.n[i], p.n[i + 1], p.n[i + 2]]);
    }
    for (let i = 0; i < vertices.length; i += 3) indices.push([i, i + 1, i + 2]);
    return { material: "gm_" + p.material, vertices, normals, indices };
  });
  cache.set(name, out);
  return out;
}

/** name: gem_red | gem_blue | gem_green | gem_purple | gem_gold | gem_prism | surge_aura */
export const GemMesh = memo(function GemMesh({ name, scale = [1, 1, 1], rotation, position }: { name: string; scale?: V3; rotation?: V3; position?: V3 }) {
  registerGemMaterials();
  return (
    <ViroNode scale={scale} rotation={rotation} position={position}>
      {parts(name).map((p, i) => (
        <ViroGeometry key={i} vertices={p.vertices} normals={p.normals} triangleIndices={p.indices} materials={[p.material]} />
      ))}
    </ViroNode>
  );
});

export const GEM_NAMES = ["gem_red", "gem_blue", "gem_green", "gem_purple", "gem_gold"];
