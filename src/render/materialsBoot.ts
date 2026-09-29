// Viro material registration, done up front from the root layout while the player is still on the
// home screen. Two device findings (Tecno Camon 19) shaped this:
//  1. Registering materials while a Viro scene starts crashes Viro's MaterialManager
//     (ConcurrentModificationException in reloadMaterials) – so nothing registers during scene start.
//  2. Each textured material decodes its images on the UI thread; registering every realm at once
//     froze the app ("isn't responding") – so realms are registered one at a time, spaced out.
// Islands draw their ground only once their realm is ready (see IslandWorld).
import { registerGemMaterials } from "./GemMesh";
import { BIOMES } from "./island/biomes";
import { registerBiome } from "./island/IslandWorld";
import { materialsStore } from "./materialsStore";
import { registerMaterials } from "./registry";

export { materialsStore };


let started = false;
const SPACING_MS = 260;

/** Start registration; `first` realm goes first (the one the player is most likely to open). */
export function bootMaterials(first = "verdant") {
  if (started) return;
  started = true;
  registerMaterials();
  registerGemMaterials();
  const order = [first, ...Object.keys(BIOMES).filter((id) => id !== first)];
  order.forEach((id, i) =>
    setTimeout(() => {
      registerBiome(BIOMES[id]);
      materialsStore.set((s) => ({ realms: [...s.realms, id], done: i === order.length - 1 }));
    }, 200 + i * SPACING_MS),
  );
}

/** Registers one realm right now (e.g. a deep link straight into a level before the boot got there). */
export function ensureRealm(id: string) {
  if (materialsStore.get().realms.includes(id)) return;
  registerBiome(BIOMES[id] ?? BIOMES.verdant);
  materialsStore.set((s) => ({ realms: [...s.realms, id] }));
}
