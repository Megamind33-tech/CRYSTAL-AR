// Viro material registration, done up front from the root layout while the player is still on the
// home screen. Two device findings (Tecno Camon 19) shaped this:
//  1. Registering materials while a Viro scene starts crashes Viro's MaterialManager
//     (ConcurrentModificationException in reloadMaterials) – so nothing registers during scene start.
//  2. Each textured material decodes its images on the UI thread; registering every realm at once
//     froze the app ("isn't responding") – so realms are registered one at a time, spaced out.
// Islands draw their ground only once their realm is ready (see IslandWorld).
import { MESHY_NAMES, registerGemMaterials, registerMeshyMaterial } from "./GemMesh";
import { BIOMES } from "./island/biomes";
import { registerBiome } from "./island/IslandWorld";
import { materialsStore } from "./materialsStore";
import { registerMaterials } from "./registry";

export { materialsStore };


let started = false;
const SPACING_MS = 260;
/** the Meshy crystal textures are 256 px, so their steps can follow closer together */
const MESHY_SPACING_MS = 110;

/**
 * Start registration; `first` realm goes first (the one the player is most likely to open). The Meshy crystal
 * materials come last, one per step like the realms (each decodes a 256 px texture on the UI thread).
 */
export function bootMaterials(first = "verdant") {
  if (started) return;
  started = true;
  registerMaterials();
  registerGemMaterials();
  const order = [first, ...Object.keys(BIOMES).filter((id) => id !== first)];
  // If one Meshy material fails to register, every crystal stays on the classic models rather than half of them.
  let meshyFailed = false;
  const steps: (() => void)[] = [
    ...order.map((id) => () => {
      registerBiome(BIOMES[id]);
      materialsStore.set((s) => ({ realms: [...s.realms, id] }));
    }),
    ...MESHY_NAMES.map((name) => () => {
      if (!registerMeshyMaterial(name)) meshyFailed = true;
    }),
    () => materialsStore.set({ meshy: !meshyFailed }),
  ];
  let at = 200;
  steps.forEach((step, i) => {
    setTimeout(() => {
      // a step that throws must never keep the scene from starting: `done` is set regardless
      try {
        step();
      } catch {
        if (i >= order.length) meshyFailed = true;
      }
      if (i === steps.length - 1) materialsStore.set({ done: true });
    }, at);
    at += i < order.length ? SPACING_MS : MESHY_SPACING_MS;
  });
}

/** Registers one realm right now (e.g. a deep link straight into a level before the boot got there). */
export function ensureRealm(id: string) {
  if (materialsStore.get().realms.includes(id)) return;
  registerBiome(BIOMES[id] ?? BIOMES.verdant);
  materialsStore.set((s) => ({ realms: [...s.realms, id] }));
}
