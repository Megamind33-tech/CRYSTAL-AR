export interface IslandMesh { v: number[]; n: number[]; t: number[]; i: number[] }
/** A Meshy realm island fitted to the board (see tools/asset-pipeline/bake-islands.mjs). Coordinates are world-local
 *  game units: the dais top is at SURFACE_Y and the dais is centred on the board. */
export interface MeshyIsland { realm: string; yaw: number; scale: number; bottomY: number; hero: IslandMesh; far: IslandMesh }
