import { createStore } from "../state/store";

/** Realms whose island materials are registered with Viro, and whether the Meshy crystal materials are (see materialsBoot). */
export const materialsStore = createStore<{ realms: string[]; meshy: boolean; done: boolean }>({ realms: [], meshy: false, done: false });
