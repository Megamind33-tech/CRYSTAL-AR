import { createAudioPlayer, setAudioModeAsync, type AudioPlayer } from "expo-audio";
import * as Haptics from "expo-haptics";
import { Platform } from "react-native";
import { gameEvents, type SfxName } from "../state/game";
import { settingsStore } from "../state/settings";

const SFX: Record<SfxName, number> = {
  select: require("../../assets/audio/select.wav"),
  swap: require("../../assets/audio/swap.wav"),
  invalid: require("../../assets/audio/invalid.wav"),
  match1: require("../../assets/audio/match1.wav"),
  match2: require("../../assets/audio/match2.wav"),
  match3: require("../../assets/audio/match3.wav"),
  match4: require("../../assets/audio/match4.wav"),
  special_create: require("../../assets/audio/special_create.wav"),
  special_activate: require("../../assets/audio/special_activate.wav"),
  place: require("../../assets/audio/place.wav"),
  complete: require("../../assets/audio/complete.wav"),
  portal: require("../../assets/audio/portal.wav"),
};
const VOLUME: Partial<Record<SfxName, number>> = { select: 0.5, swap: 0.55, invalid: 0.6, portal: 0.7 };
/** Frequent sounds get two voices so rapid repeats overlap instead of cutting off. */
const VOICES: Partial<Record<SfxName, number>> = { select: 2, swap: 2, match1: 2, match2: 2 };

let pools: Partial<Record<SfxName, { players: AudioPlayer[]; next: number }>> = {};
let ambient: AudioPlayer | null = null;
let started = false;
let ambientWanted = false;

export function initAudio() {
  if (started) return;
  started = true;
  setAudioModeAsync({ playsInSilentMode: true, shouldPlayInBackground: false, interruptionMode: "mixWithOthers" }).catch(() => {});
  for (const name of Object.keys(SFX) as SfxName[]) {
    const players = Array.from({ length: VOICES[name] ?? 1 }, () => {
      const p = createAudioPlayer(SFX[name]);
      p.volume = VOLUME[name] ?? 0.8;
      return p;
    });
    pools[name] = { players, next: 0 };
  }
  ambient = createAudioPlayer(require("../../assets/audio/ambient_forest.wav"));
  ambient.loop = true;
  ambient.volume = 0.45;

  gameEvents.on((e) => {
    const s = settingsStore.get();
    if (e.type === "sfx" && s.sfx) playSfx(e.name);
    if (e.type === "haptic" && s.haptics && Platform.OS !== "web") haptic(e.kind);
  });
  settingsStore.subscribe(syncAmbient);
}

export function playSfx(name: SfxName) {
  const pool = pools[name];
  if (!pool) return;
  const p = pool.players[pool.next];
  pool.next = (pool.next + 1) % pool.players.length;
  try {
    p.seekTo(0).catch(() => {});
    p.play();
  } catch {
    // audio focus lost etc. – never let sound break gameplay
  }
}

function haptic(kind: "light" | "medium" | "heavy" | "success" | "error") {
  const run =
    kind === "success"
      ? Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success)
      : kind === "error"
        ? Haptics.notificationAsync(Haptics.NotificationFeedbackType.Warning)
        : Haptics.impactAsync(
            kind === "light" ? Haptics.ImpactFeedbackStyle.Light : kind === "medium" ? Haptics.ImpactFeedbackStyle.Medium : Haptics.ImpactFeedbackStyle.Heavy,
          );
  run.catch(() => {});
}

/** Ambient forest loop runs only while a level is on screen and music is enabled. */
export function setAmbientActive(active: boolean) {
  ambientWanted = active;
  syncAmbient();
}

function syncAmbient() {
  if (!ambient) return;
  try {
    if (ambientWanted && settingsStore.get().music) ambient.play();
    else ambient.pause();
  } catch {
    // ignore
  }
}
