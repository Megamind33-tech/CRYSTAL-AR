// The Meshy realm islands as game geometry (baked by tools/asset-pipeline/bake-islands.mjs). Like the crystals they are
// in-memory ViroGeometry with a texture material registered at boot, so no file is loaded while playing.
import { memo } from "react";
import { ViroGeometry, ViroMaterials } from "@reactvision/react-viro";
import { settingsStore } from "../../state/settings";
import { useStore } from "../../state/store";
import { ISLAND_TEXTURES } from "../assets";
import { Gated } from "../LoadQueue";
import { materialsStore } from "../materialsStore";
import { meshyIsland, MESHY_ISLAND_REALMS } from "../meshyIslands";
import type { IslandMesh } from "../meshyIslands/types";

type V3 = [number, number, number];
type V2 = [number, number];
const cache = new WeakMap<IslandMesh, { vertices: V3[]; normals: V3[]; texcoords: V2[]; indices: V3[] }>();
function geometry(m: IslandMesh) {
  let g = cache.get(m);
  if (g) return g;
  const vertices: V3[] = [], normals: V3[] = [], texcoords: V2[] = [], indices: V3[] = [];
  for (let i = 0; i < m.v.length; i += 3) {
    vertices.push([m.v[i], m.v[i + 1], m.v[i + 2]]);
    normals.push([m.n[i], m.n[i + 1], m.n[i + 2]]);
  }
  for (let i = 0; i < m.t.length; i += 2) texcoords.push([m.t[i], 1 - m.t[i + 1]]); // glTF v points down, Viro's up
  for (let i = 0; i < m.i.length; i += 3) indices.push([m.i[i], m.i[i + 1], m.i[i + 2]]);
  g = { vertices, normals, texcoords, indices };
  cache.set(m, g);
  return g;
}

export const islandMaterial = (realm: string) => "mi_" + realm;

/** A gentle grade per realm (multiplies the texture): tames blown-out whites and pulls each island toward its mood. */
const GRADE: Record<string, string> = {
  verdant: "#eef2e2", canyon: "#f2e4d6", tide: "#e6f0f2", sky: "#b4bccb", hollow: "#e4dcee",
  caverns: "#dfe4f0", frozen: "#d8e2f0", solar: "#f0e6cf", ember: "#eddcd2", void: "#e6dcf0",
};

/** Registers one island material (called from materialsBoot with the realm's other materials). False on failure. */
export function registerMeshyIslandMaterial(realm: string): boolean {
  const tex = ISLAND_TEXTURES[realm];
  if (!tex || !MESHY_ISLAND_REALMS.includes(realm)) return false;
  try {
    ViroMaterials.createMaterials({ [islandMaterial(realm)]: { lightingModel: "PBR", diffuseTexture: tex, diffuseColor: GRADE[realm] ?? "#ffffff", roughness: 0.9, metalness: 0, cullMode: "None" } } as never);
    return true;
  } catch {
    return false;
  }
}

/** True when this realm's Meshy island can be shown: not switched off in Settings, and its material is registered. */
export function useMeshyIsland(realm: string) {
  const classic = useStore(settingsStore, (s) => s.classicGems);
  const ready = useStore(materialsStore, (s) => s.islands.includes(realm));
  return !classic && ready ? meshyIsland(realm) : null;
}

/** One island mesh (hero under the board, or the far LOD on the horizon). */
export const MeshyIslandMesh = memo(function MeshyIslandMesh({ realm, lod }: { realm: string; lod: "hero" | "far" }) {
  const isl = meshyIsland(realm);
  if (!isl) return null;
  const g = geometry(isl[lod]);
  return (
    <Gated settleMs={220}>
      <ViroGeometry vertices={g.vertices} normals={g.normals} texcoords={g.texcoords} triangleIndices={g.indices} materials={[islandMaterial(realm)]} ignoreEventHandling />
    </Gated>
  );
});
