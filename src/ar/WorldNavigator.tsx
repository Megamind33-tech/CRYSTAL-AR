import { useEffect } from "react";
import { ActivityIndicator, Pressable, StyleSheet, Text, View } from "react-native";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import { Viro3DSceneNavigator, ViroARSceneNavigator } from "@reactvision/react-viro";
import { DEV_AR_MOCK } from "../config";
import MockScene from "../dev/MockScene";
import { arSession, nudgeWorldScale } from "../state/arSession";
import { arSupport, detectArSupport, effectiveViewMode } from "../state/arSupport";
import { settingsStore } from "../state/settings";
import { useStore } from "../state/store";
import { C, ui } from "../ui/theme";
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

  useEffect(() => {
    if (mode === "camera" && (phase === "scanning" || arSession.get().tracking !== "camera")) {
      arSession.set({ tracking: "camera", planes: 0, phase: phase === "placed" ? "placed" : "surfaceFound" });
    }
  }, [mode, phase]);


  if (mode === "checking") {
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
export function ViewControls() {
  const insets = useSafeAreaInsets();
  const mode = useViewMode();
  const placed = useStore(arSession, (s) => s.phase === "placed");
  if (mode === "ar" || mode === "checking" || !placed) return null;
  const turn = (d: number) => arSession.set((s) => ({ yaw: (s.yaw + d) % 360 }));
  const Btn = ({ label, onPress, a11y }: { label: string; onPress: () => void; a11y: string }) => (
    <Pressable accessibilityRole="button" accessibilityLabel={a11y} onPress={onPress} style={({ pressed }) => [ui.glass, s.btn, pressed && { opacity: 0.7 }]}>
      <Text style={s.txt}>{label}</Text>
    </Pressable>
  );
  return (
    <View pointerEvents="box-none" style={[s.wrap, { bottom: insets.bottom + 18 }]}>
      <Btn label="⟲" a11y="Turn world left" onPress={() => turn(-30)} />
      <Btn label="⟳" a11y="Turn world right" onPress={() => turn(30)} />
      <Btn label="−" a11y="Smaller world" onPress={() => nudgeWorldScale(-0.1)} />
      <Btn label="+" a11y="Larger world" onPress={() => nudgeWorldScale(0.1)} />
    </View>
  );
}

const s = StyleSheet.create({
  wrap: { position: "absolute", left: 14, flexDirection: "row", gap: 8 },
  btn: { width: 44, height: 44, borderRadius: 22, alignItems: "center", justifyContent: "center" },
  txt: { color: C.ink, fontSize: 20, fontWeight: "700" },
});
