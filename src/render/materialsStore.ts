import { createStore } from "../state/store";

/** Realms whose island materials are registered with Viro (see materialsBoot). */
export const materialsStore = createStore<{ realms: string[]; done: boolean }>({ realms: [], done: false });
