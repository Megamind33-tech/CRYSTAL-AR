import AsyncStorage from "@react-native-async-storage/async-storage";
import { LEVELS } from "../game/level";
import { gameEvents, gameStore } from "./game";
import { createStore } from "./store";

export interface Settings {
  music: boolean;
  sfx: boolean;
  haptics: boolean;
  diagnostics: boolean;
  /** force Camera View even if ARCore reports support */
  cameraView: boolean;
}

export interface Progress {
  /** highest unlocked level index */
  unlocked: number;
  stars: number[];
  best: number[];
}

const KEY_SETTINGS = "crystals.settings.v1";
const KEY_PROGRESS = "crystals.progress.v1";

export const settingsStore = createStore<Settings & { loaded: boolean }>({
  music: true,
  sfx: true,
  haptics: true,
  diagnostics: __DEV__,
  cameraView: false,
  loaded: false,
});

export const progressStore = createStore<Progress>({
  unlocked: 0,
  stars: LEVELS.map(() => 0),
  best: LEVELS.map(() => 0),
});

let loading: Promise<void> | null = null;
export function loadPersisted() {
  if (!loading) {
    loading = (async () => {
      try {
        const [s, p] = await Promise.all([AsyncStorage.getItem(KEY_SETTINGS), AsyncStorage.getItem(KEY_PROGRESS)]);
        if (s) settingsStore.set({ ...JSON.parse(s) });
        if (p) {
          const parsed = JSON.parse(p) as Partial<Progress>;
          const cur = progressStore.get();
          progressStore.set({
            unlocked: Math.min(LEVELS.length - 1, parsed.unlocked ?? 0),
            stars: cur.stars.map((v, i) => parsed.stars?.[i] ?? v),
            best: cur.best.map((v, i) => parsed.best?.[i] ?? v),
          });
        }
      } catch {
        // corrupt or unavailable storage: keep defaults
      }
      settingsStore.set({ loaded: true });
    })();
  }
  return loading;
}

export function updateSettings(patch: Partial<Settings>) {
  settingsStore.set(patch);
  const { loaded: _loaded, ...persist } = settingsStore.get();
  AsyncStorage.setItem(KEY_SETTINGS, JSON.stringify(persist)).catch(() => {});
}

export function recordLevelResult(levelIndex: number, stars: number, score: number) {
  const p = progressStore.get();
  const next: Progress = {
    unlocked: Math.min(LEVELS.length - 1, Math.max(p.unlocked, levelIndex + 1)),
    stars: p.stars.map((v, i) => (i === levelIndex ? Math.max(v, stars) : v)),
    best: p.best.map((v, i) => (i === levelIndex ? Math.max(v, score) : v)),
  };
  progressStore.set(next);
  AsyncStorage.setItem(KEY_PROGRESS, JSON.stringify(next)).catch(() => {});
}

// Persist wins as soon as the controller reports them.
gameEvents.on((e) => {
  if (e.type === "levelEnd" && e.won) {
    const idx = LEVELS.findIndex((l) => l.id === e.level);
    recordLevelResult(idx, e.stars, gameStore.get().hud.score);
  }
});
