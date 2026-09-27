import { useEffect, useRef, useState } from "react";
import { Animated, Pressable, StyleSheet, Text, View } from "react-native";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import { LEVELS } from "../game/level";
import { arSession, nudgeWorldScale } from "../state/arSession";
import { gameStore } from "../state/game";
import { useStore } from "../state/store";
import { Button } from "./Button";
import { SettingsList } from "./SettingsList";
import { C, font, ui } from "./theme";

/** Scan → surface found → tap. Shown until the world is placed. */
export function PlacementGuide({ mock, onPlaceMock, cameraView = false }: { mock: boolean; onPlaceMock: () => void; cameraView?: boolean }) {
  const insets = useSafeAreaInsets();
  const phase = useStore(arSession, (s) => s.phase);
  const reason = useStore(arSession, (s) => s.trackingReason);
  const scale = useStore(arSession, (s) => s.worldScale);
  const resuming = useStore(gameStore, (s) => !!s.session);
  const sanctuary = useStore(arSession, (s) => s.world === "sanctuary");
  const pulse = useRef(new Animated.Value(0)).current;
  useEffect(() => {
    const loop = Animated.loop(
      Animated.sequence([
        Animated.timing(pulse, { toValue: 1, duration: 1100, useNativeDriver: true }),
        Animated.timing(pulse, { toValue: 0, duration: 1100, useNativeDriver: true }),
      ]),
    );
    loop.start();
    return () => loop.stop();
  }, [pulse]);
  if (phase === "placed") return null;

  const title =
    phase === "scanning" ? (resuming ? "Find your table again" : "Find a table or floor") : cameraView ? "Camera View" : mock ? "Mock table ready" : "Surface found";
  const body =
    phase === "scanning"
      ? reason || "Move your phone slowly across a flat, textured surface."
      : cameraView
        ? "This phone can’t use Google’s AR tracking, so the world appears over your camera. Point at your table, then place it. Turn it with ⟲ ⟳."
        : mock
        ? "DEV_AR_MOCK: a simulated table stands in for AR."
        : resuming
          ? "Tap the glowing area – your puzzle is waiting."
          : sanctuary
            ? "Tap the glowing area to bring your Sanctuary here."
            : "Tap the glowing area to raise the Forest Ruins.";

  return (
    <View pointerEvents="box-none" style={[StyleSheet.absoluteFill, { justifyContent: "flex-end", paddingBottom: insets.bottom + 28 }]}>
      {phase === "scanning" && (
        <Animated.View
          pointerEvents="none"
          style={[s.reticle, { opacity: pulse.interpolate({ inputRange: [0, 1], outputRange: [0.35, 0.9] }), transform: [{ scale: pulse.interpolate({ inputRange: [0, 1], outputRange: [0.92, 1.06] }) }] }]}
        />
      )}
      <View style={[ui.glass, s.card]}>
        <Text style={s.title}>{title}</Text>
        <Text style={s.body}>{body}</Text>
        <View style={s.scaleRow}>
          <Text style={ui.label}>World size</Text>
          <View style={{ flexDirection: "row", gap: 8, alignItems: "center" }}>
            <Pressable accessibilityLabel="Smaller world" onPress={() => nudgeWorldScale(-0.1)} style={s.scaleBtn}>
              <Text style={s.scaleTxt}>−</Text>
            </Pressable>
            <Text style={[ui.value, { fontSize: 15, minWidth: 48, textAlign: "center" }]}>{Math.round(scale * 70)} cm</Text>
            <Pressable accessibilityLabel="Larger world" onPress={() => nudgeWorldScale(0.1)} style={s.scaleBtn}>
              <Text style={s.scaleTxt}>+</Text>
            </Pressable>
          </View>
        </View>
        {mock && phase === "surfaceFound" && <Button testID="place-world" label="PLACE WORLD" variant="primary" onPress={onPlaceMock} style={{ marginTop: 12 }} />}
      </View>
    </View>
  );
}

export function PauseMenu({ visible, onResume, onRestart, onResetWorld, onExit }: {
  visible: boolean;
  onResume: () => void;
  onRestart: () => void;
  onResetWorld: () => void;
  onExit: () => void;
}) {
  const [showSettings, setShowSettings] = useState(false);
  if (!visible) return null;
  return (
    <View style={[StyleSheet.absoluteFill, s.scrim]}>
      <View style={[ui.glass, s.panel, { backgroundColor: C.glassStrong }]}>
        <Text style={s.heading}>{showSettings ? "Settings" : "Paused"}</Text>
        {showSettings ? (
          <>
            <SettingsList />
            <Button label="BACK" onPress={() => setShowSettings(false)} style={{ marginTop: 14 }} />
          </>
        ) : (
          <View style={{ gap: 10 }}>
            <Button testID="resume" label="RESUME" variant="primary" onPress={onResume} />
            <Button label="RESTART LEVEL" onPress={onRestart} />
            <Button label="RESET WORLD POSITION" onPress={onResetWorld} />
            <Button label="SETTINGS" onPress={() => setShowSettings(true)} />
            <Button label="EXIT TO MENU" onPress={onExit} />
          </View>
        )}
      </View>
    </View>
  );
}

export function LevelResult({ onNext, onReplay, onExit }: { onNext: () => void; onReplay: () => void; onExit: () => void }) {
  const result = useStore(gameStore, (s) => s.result);
  const levelIndex = useStore(gameStore, (s) => s.levelIndex);
  const score = useStore(gameStore, (s) => s.hud.score);
  const appear = useRef(new Animated.Value(0)).current;
  const [show, setShow] = useState(false);

  useEffect(() => {
    if (!result) {
      setShow(false);
      appear.setValue(0);
      return;
    }
    // let the world celebrate before the card slides in
    const t = setTimeout(() => {
      setShow(true);
      Animated.spring(appear, { toValue: 1, useNativeDriver: true, friction: 7 }).start();
    }, result.won ? 1600 : 500);
    return () => clearTimeout(t);
  }, [result, appear]);

  if (!result || !show) return null;
  const hasNext = result.won && levelIndex < LEVELS.length - 1;
  return (
    <View style={[StyleSheet.absoluteFill, s.scrim, { backgroundColor: "rgba(0,0,0,0.25)" }]}>
      <Animated.View style={[ui.glass, s.panel, { backgroundColor: C.glassStrong, opacity: appear, transform: [{ translateY: appear.interpolate({ inputRange: [0, 1], outputRange: [40, 0] }) }] }]}>
        <Text style={s.heading}>{result.won ? "Portal Awakened" : "Out of Moves"}</Text>
        {result.won && (
          <Text style={s.stars} accessibilityLabel={`${result.stars} of 3 stars`}>
            {"★".repeat(result.stars)}
            <Text style={{ color: "rgba(255,255,255,0.2)" }}>{"★".repeat(3 - result.stars)}</Text>
          </Text>
        )}
        <Text style={s.body}>Score {score.toLocaleString()}</Text>
        <View style={{ gap: 10, marginTop: 16 }}>
          {hasNext && <Button testID="next-level" label="NEXT LEVEL" variant="primary" onPress={onNext} />}
          <Button testID="replay" label={result.won ? "REPLAY" : "TRY AGAIN"} variant={hasNext ? "ghost" : "primary"} onPress={onReplay} />
          <Button label="MENU" onPress={onExit} />
        </View>
      </Animated.View>
    </View>
  );
}

const s = StyleSheet.create({
  card: { marginHorizontal: 16, padding: 18, gap: 6 },
  title: { color: C.ink, fontSize: 20, fontFamily: font.display, fontWeight: "700" },
  body: { color: C.inkDim, fontSize: 14, lineHeight: 20, fontFamily: font.body },
  reticle: { position: "absolute", alignSelf: "center", top: "42%", width: 140, height: 90, borderRadius: 70, borderWidth: 2, borderColor: C.portal },
  scaleRow: { flexDirection: "row", justifyContent: "space-between", alignItems: "center", marginTop: 8 },
  scaleBtn: { width: 40, height: 40, borderRadius: 20, backgroundColor: "rgba(255,255,255,0.08)", alignItems: "center", justifyContent: "center" },
  scaleTxt: { color: C.ink, fontSize: 22, fontWeight: "600" },
  scrim: { backgroundColor: "rgba(0,0,0,0.45)", justifyContent: "center", padding: 20 },
  panel: { padding: 22, maxWidth: 420, width: "100%", alignSelf: "center" },
  heading: { color: C.ink, fontSize: 28, fontFamily: font.display, fontWeight: "700", textAlign: "center", marginBottom: 14 },
  stars: { color: C.gold, fontSize: 40, textAlign: "center", letterSpacing: 6 },
});
