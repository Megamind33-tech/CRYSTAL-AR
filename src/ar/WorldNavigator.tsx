import { useEffect } from "react";
import { ActivityIndicator, StyleSheet, View } from "react-native";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import { Viro3DSceneNavigator, ViroARSceneNavigator } from "@reactvision/react-viro";
import { DEV_AR_MOCK } from "../config";
import MockScene from "../dev/MockScene";
import { arSession, nudgeWorldScale } from "../state/arSession";
import { arSupport, detectArSupport, effectiveViewMode } from "../state/arSupport";
import { settingsStore } from "../state/settings";
import { useStore } from "../state/store";
import { C } from "../ui/theme";
import { GlassOrb } from "../ui/lux/Orb";
import { L } from "../ui/lux/tokens";
import { materialsStore } from "../render/materialsStore";
import { bootMaterials } from "../render/materialsBoot";
import ARGameScene from "./ARGameScene";

/** Which navigator this phone gets. Exposed so overlays can adapt their copy and controls. */
export function useViewMode() {
  const detected = useStore(arSupport, (s) => s.detected);
  const forced = useStore(settingsStore, (s) => s.cameraView);
  return DEV_AR_MOCK ? ("mock" as const) : effectiveViewMode(detected, forced);
}

/**
 * ARCore phones get world tracking; everything else (uncertified phones such as the Tecno Camon 19,
 * or a player who forces it in Settings) gets Camera View – the same scene as the dev mock, with the
 * live camera feed behind the diorama. Nothing here requires Google Play Services for AR.
 */
export function WorldNavigator() {
  const mode = useViewMode();
  const phase = useStore(arSession, (s) => s.phase);
  useEffect(() => detectArSupport(), []);
  // a Viro scene must not start while materials are still being registered (MaterialManager race)
  const materialsDone = useStore(materialsStore, (m) => m.done);
  useEffect(() => bootMaterials(), []);

  useEffect(() => {
    if (mode === "camera" && (phase === "scanning" || arSession.get().tracking !== "camera")) {
      arSession.set({ tracking: "camera", planes: 0, phase: phase === "placed" ? "placed" : "surfaceFound" });
    }
  }, [mode, phase]);


  if (mode === "checking" || !materialsDone) {
    return (
      <View style={{ flex: 1, alignItems: "center", justifyContent: "center", backgroundColor: C.bg }}>
        <ActivityIndicator color={C.gold} />
      </View>
    );
  }
  if (mode === "ar") return <ViroARSceneNavigator initialScene={{ scene: ARGameScene }} style={{ flex: 1 }} autofocus />;
  return <Viro3DSceneNavigator key={mode} initialScene={{ scene: MockScene as never }} style={{ flex: 1 }} shadowsEnabled pbrEnabled hdrEnabled={false} />;
}

/** Turn and size the world in Camera View / mock (in AR the player simply walks around it). */
export function ViewControls({ column = false }: { column?: boolean }) {
  const insets = useSafeAreaInsets();
  const mode = useViewMode();
  const placed = useStore(arSession, (s) => s.phase === "placed");
  if (mode === "ar" || mode === "checking" || !placed) return null;
  const turn = (d: number) => arSession.set((s) => ({ yaw: (s.yaw + d) % 360 }));
  return (
    <View pointerEvents="box-none" style={column ? [s.col, { top: insets.top + 150 }] : [s.wrap, { bottom: insets.bottom + 18 }]}>
      <GlassOrb size={42} glyph="↶" accessibilityLabel="Turn world left" onPress={() => turn(-30)} breathe={false} />
      <GlassOrb size={42} glyph="↷" accessibilityLabel="Turn world right" onPress={() => turn(30)} breathe={false} />
      <View style={column ? s.sepCol : s.sepRow} />
      <GlassOrb size={42} glyph="−" tone={L.goldLight} accessibilityLabel="Smaller world" onPress={() => nudgeWorldScale(-0.1)} breathe={false} />
      <GlassOrb size={42} glyph="+" tone={L.goldLight} accessibilityLabel="Larger world" onPress={() => nudgeWorldScale(0.1)} breathe={false} />
    </View>
  );
}

const s = StyleSheet.create({
  wrap: { position: "absolute", left: 14, flexDirection: "row", alignItems: "center", gap: 2 },
  col: { position: "absolute", right: 8, alignItems: "center", gap: 2 },
  sepCol: { width: 18, height: 1, marginVertical: 3, backgroundColor: "rgba(246,211,138,0.45)" },
  sepRow: { width: 1, height: 18, marginHorizontal: 3, backgroundColor: "rgba(246,211,138,0.45)" },
});
