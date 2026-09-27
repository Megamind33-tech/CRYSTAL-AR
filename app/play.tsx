import { useEffect, useState } from "react";
import { Platform, StyleSheet, View } from "react-native";
import { useLocalSearchParams, useRouter } from "expo-router";
import { Viro3DSceneNavigator, ViroARSceneNavigator } from "@reactvision/react-viro";
import ARGameScene from "@/src/ar/ARGameScene";
import { setAmbientActive } from "@/src/audio/AudioManager";
import { DEV_AR_MOCK } from "@/src/config";
import { Diagnostics } from "@/src/dev/Diagnostics";
import { cellToScreen, installMockPicking } from "@/src/dev/mockPicking";
import MockScene from "@/src/dev/MockScene";
import { LEVELS } from "@/src/game/level";
import { arSession, requestResetPlacement } from "@/src/state/arSession";
import { endSession, gameEvents, gameStore, respawnView, restartLevel, startLevel } from "@/src/state/game";
import { useStore } from "@/src/state/store";
import { findValidMoves } from "@/src/game/board";
import { attemptSwap } from "@/src/state/game";
import { HUD } from "@/src/ui/HUD";
import { LevelResult, PauseMenu, PlacementGuide } from "@/src/ui/Overlays";
import { C } from "@/src/ui/theme";

export default function Play() {
  const router = useRouter();
  const params = useLocalSearchParams<{ level?: string; seed?: string; autoplace?: string }>();
  const level = Math.max(0, Math.min(LEVELS.length - 1, Number(params.level ?? 0) || 0));
  const phase = useStore(arSession, (s) => s.phase);
  const [paused, setPaused] = useState(false);

  useEffect(() => {
    arSession.set({ phase: DEV_AR_MOCK ? "surfaceFound" : "scanning", planes: 0, anchorId: null, yaw: 0, lastError: "" });
    endSession();
    setAmbientActive(true);
    const removePicking = Platform.OS === "web" ? installMockPicking() : () => {};
    // automation hook for DEV_AR_MOCK runs (CI / screenshots)
    if (DEV_AR_MOCK) (globalThis as Record<string, unknown>).__crystals = { gameStore, arSession, attemptSwap, findValidMoves, cellToScreen };
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
    if (!s.session) startLevel(level, params.seed ? Number(params.seed) : undefined);
    else respawnView();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [phase]);

  const placeMock = () => {
    arSession.set({ phase: "placed", anchorId: "mock-table", yaw: 0 });
    gameEvents.emit({ type: "sfx", name: "place" });
  };

  const exit = () => router.back();

  return (
    <View style={s.root}>
      {DEV_AR_MOCK ? (
        <Viro3DSceneNavigator initialScene={{ scene: MockScene as never }} style={s.fill} shadowsEnabled pbrEnabled hdrEnabled={false} />
      ) : (
        <ViroARSceneNavigator initialScene={{ scene: ARGameScene }} style={s.fill} autofocus />
      )}
      {phase === "placed" && <HUD onPause={() => setPaused(true)} />}
      <PlacementGuide mock={DEV_AR_MOCK} onPlaceMock={placeMock} />
      <Diagnostics mock={DEV_AR_MOCK} />
      <LevelResult
        onNext={() => {
          startLevel(gameStore.get().levelIndex + 1);
          router.setParams({ level: String(gameStore.get().levelIndex) });
        }}
        onReplay={restartLevel}
        onExit={exit}
      />
      <PauseMenu
        visible={paused}
        onResume={() => setPaused(false)}
        onRestart={() => {
          setPaused(false);
          restartLevel();
        }}
        onResetWorld={() => {
          setPaused(false);
          if (DEV_AR_MOCK) arSession.set({ phase: "surfaceFound", anchorId: null });
          else requestResetPlacement();
        }}
        onExit={exit}
      />
    </View>
  );
}

const s = StyleSheet.create({
  root: { flex: 1, backgroundColor: C.bg },
  fill: { flex: 1 },
});
