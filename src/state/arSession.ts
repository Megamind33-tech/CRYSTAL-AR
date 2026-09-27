import { createStore } from "./store";

export type PlacementPhase = "scanning" | "surfaceFound" | "placed";

export interface ArSessionState {
  phase: PlacementPhase;
  planes: number;
  tracking: "normal" | "limited" | "unavailable" | "mock";
  trackingReason: string;
  /** ARCore light estimate, used to match the diorama to the room. */
  lightIntensity: number;
  lightColor: string;
  anchorId: string | null;
  yaw: number;
  worldScale: number;
  resetRequest: number;
  lastError: string;
  fps: number;
}

export const arSession = createStore<ArSessionState>({
  phase: "scanning",
  planes: 0,
  tracking: "unavailable",
  trackingReason: "",
  lightIntensity: 1000,
  lightColor: "#ffffff",
  anchorId: null,
  yaw: 0,
  worldScale: 1,
  resetRequest: 0,
  lastError: "",
  fps: 0,
});

export const WORLD_SCALE_MIN = 0.7;
export const WORLD_SCALE_MAX = 1.35;

/** Ask the active AR scene to drop the current anchor and re-scan. */
export function requestResetPlacement() {
  arSession.set((s) => ({ phase: "scanning", anchorId: null, resetRequest: s.resetRequest + 1 }));
}

export function nudgeWorldScale(delta: number) {
  arSession.set((s) => ({ worldScale: Math.min(WORLD_SCALE_MAX, Math.max(WORLD_SCALE_MIN, +(s.worldScale + delta).toFixed(2))) }));
}
