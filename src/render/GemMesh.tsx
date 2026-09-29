import { memo } from "react";
import { ViroGeometry, ViroMaterials, ViroNode } from "@reactvision/react-viro";
import { settingsStore } from "../state/settings";
import { useStore } from "../state/store";
import { MESHY_TEXTURES } from "./assets";
import { GEM_MESHES } from "./gemMeshes";
import { materialsStore } from "./materialsStore";
import { MESHY_MESHES } from "./meshyMeshes";

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

/** The built-in crystal models: hand-made low-poly meshes with flat colours. */
export const ClassicGem = memo(function ClassicGem({ name, scale = [1, 1, 1], rotation, position }: { name: string; scale?: V3; rotation?: V3; position?: V3 }) {
  registerGemMaterials();
  return (
    <ViroNode scale={scale} rotation={rotation} position={position}>
      {parts(name).map((p, i) => (
        <ViroGeometry key={i} vertices={p.vertices} normals={p.normals} triangleIndices={p.indices} materials={[p.material]} />
      ))}
    </ViroNode>
  );
});

// ---------------------------------------------------------------- Meshy crystals --
// Meshy-generated crystals baked to in-memory geometry (tools/asset-pipeline/bake-game.mjs): like the classic
// meshes they need no file load, so spawning them mid-game cannot trip Viro's async task scheduler. Their
// look comes from a 256 px base-colour texture; the materials are registered one at a time at boot.
type V2 = [number, number];
interface MeshyPart { vertices: V3[]; normals: V3[]; texcoords: V2[]; indices: V3[] }
const meshyCache = new Map<string, MeshyPart>();
function meshyPart(name: string): MeshyPart {
  let p = meshyCache.get(name);
  if (p) return p;
  const m = MESHY_MESHES[name];
  const vertices: V3[] = [], normals: V3[] = [], texcoords: V2[] = [], indices: V3[] = [];
  for (let i = 0; i < m.v.length; i += 3) {
    vertices.push([m.v[i], m.v[i + 1], m.v[i + 2]]);
    normals.push([m.n[i], m.n[i + 1], m.n[i + 2]]);
  }
  for (let i = 0; i < m.t.length; i += 2) texcoords.push([m.t[i], 1 - m.t[i + 1]]); // glTF v points down, Viro's up
  for (let i = 0; i < m.i.length; i += 3) indices.push([m.i[i], m.i[i + 1], m.i[i + 2]]);
  p = { vertices, normals, texcoords, indices };
  meshyCache.set(name, p);
  return p;
}

export const MESHY_NAMES = Object.keys(MESHY_MESHES);
const meshyMaterial = (name: string) => "mz_" + name;

/** Registers one Meshy crystal material (called one per step from materialsBoot). Returns false if it could not. */
export function registerMeshyMaterial(name: string): boolean {
  const tex = MESHY_TEXTURES[name];
  if (!tex) return false;
  try {
  const aura = name === "surge_aura";
  ViroMaterials.createMaterials({
    [meshyMaterial(name)]: aura
      // the aura is pure light: unlit and opaque (an additive blend washed the cyan out to white on the pale tiles)
      ? { lightingModel: "Constant", diffuseTexture: tex, cullMode: "None" }
      : { lightingModel: "PBR", diffuseTexture: tex, roughness: 0.42, metalness: 0.12, ...(name === "gem_relic" ? { cullMode: "None" } : {}) },
  } as never);
    return true;
  } catch {
    return false; // the classic crystals stay in use (see useMeshyStyle)
  }
}

/** The Meshy version of a crystal (geometry + textured material). */
export const MeshyGem = memo(function MeshyGem({ name, scale = [1, 1, 1], rotation, position }: { name: string; scale?: V3; rotation?: V3; position?: V3 }) {
  const p = meshyPart(name);
  return (
    <ViroNode scale={scale} rotation={rotation} position={position}>
      <ViroGeometry vertices={p.vertices} normals={p.normals} texcoords={p.texcoords} triangleIndices={p.indices} materials={[meshyMaterial(name)]} />
    </ViroNode>
  );
});

/** True while crystals use the Meshy models: not switched off in Settings, and their materials are registered. */
export function useMeshyStyle(): boolean {
  const classic = useStore(settingsStore, (s) => s.classicGems);
  const ready = useStore(materialsStore, (s) => s.meshy);
  return !classic && ready;
}

type GemProps = { name: string; scale?: V3; rotation?: V3; position?: V3 };
function SwitchGem(props: GemProps) {
  return useMeshyStyle() ? <MeshyGem {...props} /> : <ClassicGem {...props} />;
}

/** name: gem_red | gem_blue | gem_green | gem_purple | gem_gold | gem_prism | gem_relic | surge_aura | props */
export function GemMesh(props: GemProps) {
  // only the crystals have a Meshy version; everything else (sockets, covers, props) is untouched
  return props.name in MESHY_MESHES ? <SwitchGem {...props} /> : <ClassicGem {...props} />;
}

export const GEM_NAMES = ["gem_red", "gem_blue", "gem_green", "gem_purple", "gem_gold"];
