import { useEffect, useState } from "react";
import { Platform, StyleSheet, View } from "react-native";
import { useLocalSearchParams, useRouter } from "expo-router";
import { useViewMode, ViewControls, WorldNavigator } from "@/src/ar/WorldNavigator";
import { GravityControl } from "@/src/ui/GravityControl";
import { setAmbientActive } from "@/src/audio/AudioManager";
import { DEV_AR_MOCK } from "@/src/config";
import { Diagnostics } from "@/src/dev/Diagnostics";
import { cellToScreen, installMockPicking } from "@/src/dev/mockPicking";
import { LEVELS } from "@/src/game/level";
import { arSession, requestResetPlacement } from "@/src/state/arSession";
import { endSession, gameEvents, gameStore, respawnView, restartLevel, startLevel } from "@/src/state/game";
import { useStore } from "@/src/state/store";
import { findValidMoves } from "@/src/game/board";
import { attemptSwap, turnTabletop } from "@/src/state/game";
import { HUD } from "@/src/ui/HUD";
import { PauseMenu, PlacementGuide } from "@/src/ui/Overlays";
import { RunResult } from "@/src/ui/RunResult";
import { RelicTray } from "@/src/ui/RelicTray";
import { Coach } from "@/src/ui/Coach";
import { Announce } from "@/src/ui/Announce";
import { PortalVeil } from "@/src/ui/PortalVeil";
import { Lightning } from "@/src/ui/Lightning";
import { RisingOverlay } from "@/src/ui/RisingOverlay";
import { trialDef, trialInstances } from "@/src/meta/competition";
import { ISLANDS } from "@/src/meta/config/world";
import { islandStatus } from "@/src/meta/progression";
import { analytics, metaStore, setPlayContext } from "@/src/state/meta";
import { L } from "@/src/ui/lux/tokens";

export default function Play() {
  const router = useRouter();
  const params = useLocalSearchParams<{ level?: string; seed?: string; autoplace?: string; island?: string; trial?: string }>();
  // What to play: a Realm Trial (fixed shared board), an island, or a raw level index (dev).
  const trial = params.trial ? trialInstances(Date.now()).find((i) => i.instanceId === params.trial) : undefined;
  const tdef = trial ? trialDef(trial.trialId) : undefined;
  const island = ISLANDS.find((i) => i.id === params.island) ?? (params.level === undefined && !tdef ? ISLANDS[0] : undefined);
  const level = tdef ? tdef.levelIndex : island ? island.levelIndex : Math.max(0, Math.min(LEVELS.length - 1, Number(params.level ?? 0) || 0));
  const seed = trial ? trial.seed : params.seed ? Number(params.seed) : undefined;
  const moves = tdef?.moves;
  const phase = useStore(arSession, (s) => s.phase);
  const viewMode = useViewMode();
  const travelling = useStore(gameStore, (s) => !!s.travel);
  const [paused, setPaused] = useState(false);

  useEffect(() => {
    arSession.set({ phase: DEV_AR_MOCK ? "surfaceFound" : "scanning", planes: 0, anchorId: null, yaw: 0, lastError: "" });
    endSession();
    setAmbientActive(true);
    const removePicking = Platform.OS === "web" ? installMockPicking() : () => {};
    // automation hook for DEV_AR_MOCK runs (CI / screenshots)
    if (DEV_AR_MOCK) (globalThis as Record<string, unknown>).__crystals = { gameStore, arSession, attemptSwap, findValidMoves, cellToScreen, turnTabletop };
    if (DEV_AR_MOCK && params.autoplace) setTimeout(() => arSession.set({ phase: "placed", anchorId: "mock-table", yaw: 0 }), 300);
    return () => {
      removePicking();
      setAmbientActive(false);
      endSession();
      arSession.set({ phase: "scanning", anchorId: null });
    };
  }, []);

  // Start the level the moment the world lands; on a re-placement keep the session.
  useEffect(() => {
    if (phase !== "placed") return;
    const s = gameStore.get();
    if (!s.session) {
      setPlayContext({ islandId: island?.id ?? null, trialInstanceId: trial?.instanceId ?? null });
      analytics.track(trial ? "tournament_joined" : "island_started", { id: trial?.trialId ?? island?.id ?? String(level) });
      startLevel(level, seed, moves);
    }
    else respawnView();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [phase]);

  const placeMock = () => {
    arSession.set({ phase: "placed", anchorId: "mock-table", yaw: 0 });
    gameEvents.emit({ type: "sfx", name: "place" });
  };

  /**
   * STEP THROUGH THE PORTAL: the world dives into the gate, the light hides the swap, and the next
   * island rises in place (no remount, no re-placement, no loading screen).
   */
  const continueTo = async (id: string) => {
    const next = ISLANDS.find((i) => i.id === id);
    if (!next || gameStore.get().travel) return;
    const seqNo = Date.now();
    gameStore.set({ travel: { phase: "dive", seq: seqNo, to: next.name } });
    gameEvents.emit({ type: "sfx", name: "portal" });
    gameEvents.emit({ type: "haptic", kind: "heavy" });
    try {
      await new Promise((r) => setTimeout(r, 1200));
      endSession();
      setPlayContext({ islandId: next.id, trialInstanceId: null });
      analytics.track("island_started", { id: next.id });
      startLevel(next.levelIndex);
      router.setParams({ island: next.id });
      gameStore.set({ travel: { phase: "emerge", seq: seqNo, to: next.name } });
      gameEvents.emit({ type: "sfx", name: "place" });
      await new Promise((r) => setTimeout(r, 1100));
    } finally {
      // whatever happens, the trip ends: the veil clears and the world returns to rest
      gameStore.set({ travel: null });
    }
  };

  const exit = () => (router.canGoBack() ? router.back() : router.replace("/"));
  const player = useStore(metaStore, (m) => m.player);
  const nextIsland = !trial && player ? ISLANDS.find((i) => i.id !== island?.id && !player.islands[i.id] && islandStatus(player, i, Date.now()).status === "available") : undefined;

  return (
    <View style={s.root}>
      <WorldNavigator />
      {phase === "placed" && <Lightning />}
      {phase === "placed" && <HUD onPause={() => setPaused(true)} />}
      {phase === "placed" && <RelicTray ranked={!!trial} />}
      {phase === "placed" && <GravityControl />}
      {phase === "placed" && <ViewControls column />}
      {phase === "placed" && !trial && <Coach />}
      {phase === "placed" && <Announce />}
      <RisingOverlay />
      <PlacementGuide mock={viewMode !== "ar"} cameraView={viewMode === "camera"} onPlaceMock={placeMock} />
      <Diagnostics mock={viewMode !== "ar"} />
      <PortalVeil />
      {!travelling && <RunResult
        ranked={!!trial}
        onNext={nextIsland ? () => continueTo(nextIsland.id) : null}
        onReplay={() => {
          metaStore.set({ lastOutcome: null });
          restartLevel();
        }}
        onExit={exit}
      />}
      <PauseMenu
        visible={paused}
        onResume={() => setPaused(false)}
        onRestart={() => {
          setPaused(false);
          restartLevel();
        }}
        onResetWorld={() => {
          setPaused(false);
          if (viewMode !== "ar") arSession.set({ phase: "surfaceFound", anchorId: null });
          else requestResetPlacement();
        }}
        onExit={exit}
      />
    </View>
  );
}

const s = StyleSheet.create({
  root: { flex: 1, backgroundColor: L.night900 },
  fill: { flex: 1 },
});
