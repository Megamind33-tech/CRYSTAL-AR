// Placement guide + pause menu — luminous fantasy. Secondary actions are plain RN glass rows so the
// scene never juggles more than a couple of Skia canvases over the 3D world.
import { useEffect, useState } from "react";
import { StyleSheet, Text, View } from "react-native";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import Animated, { FadeIn, useAnimatedStyle, ZoomIn } from "react-native-reanimated";
import { arSession, nudgeWorldScale } from "../state/arSession";
import { gameStore } from "../state/game";
import { useStore } from "../state/store";
import { PressSpring } from "./kit";
import { GlassFrame, LuxButton, useLoop } from "./lux/Lux";
import { F, L, titleGlow } from "./lux/tokens";
import { SettingsList } from "./SettingsList";

/** Scan → surface found → tap. Shown until the world is placed. */
export function PlacementGuide({ mock, onPlaceMock, cameraView = false }: { mock: boolean; onPlaceMock: () => void; cameraView?: boolean }) {
  const insets = useSafeAreaInsets();
  const phase = useStore(arSession, (s) => s.phase);
  const reason = useStore(arSession, (s) => s.trackingReason);
  const scale = useStore(arSession, (s) => s.worldScale);
  const resuming = useStore(gameStore, (s) => !!s.session);
  const sanctuary = useStore(arSession, (s) => s.world === "sanctuary");
  const t = useLoop(2200);
  const ring = useAnimatedStyle(() => {
    const k = Math.sin(t.value * Math.PI * 2);
    return { opacity: 0.45 + k * 0.35, transform: [{ scaleX: 1 + k * 0.05 }, { scaleY: 0.62 + k * 0.03 }] };
  });
  if (phase === "placed") return null;
  // Tabletop View / mock have no surface to scan: never show the scanning state there, so the
  // player can always place the world (was stuck on "Find a table" after leaving a level).
  const scanning = phase === "scanning" && !mock;

  const title =
    scanning ? (resuming ? "Find your table again" : "Find a table or floor") : cameraView ? "Tabletop View" : mock ? "Mock table ready" : "Surface found";
  const body =
    scanning
      ? reason || "Move your phone slowly across a flat, textured surface."
      : cameraView
        ? "This phone can’t use Google’s AR tracking, so the island rests on a virtual table. Turn it with ↶ ↷ and resize with − + on the right."
        : mock
        ? "DEV_AR_MOCK: a simulated table stands in for AR."
        : resuming
          ? "Tap the glowing area – your puzzle is waiting."
          : sanctuary
            ? "Tap the glowing area to bring your Sanctuary here."
            : "Tap the glowing area to raise the island.";

  return (
    <View pointerEvents="box-none" style={[StyleSheet.absoluteFill, { justifyContent: "flex-end", paddingBottom: insets.bottom + 24 }]}>
      {scanning && (
        <View pointerEvents="none" style={s.reticleWrap}>
          <Animated.View style={[s.reticle, ring]} />
          <Animated.View style={[s.reticle, s.reticleInner, ring]} />
        </View>
      )}
      <Animated.View entering={FadeIn.duration(400)}>
        <GlassFrame radius={22} style={s.card}>
          <Text style={s.title}>{title.toUpperCase()}</Text>
          <Text style={s.body}>{body}</Text>
          <View style={s.scaleRow}>
            <Text style={s.label}>WORLD SIZE</Text>
            <View style={{ flexDirection: "row", gap: 10, alignItems: "center" }}>
              <PressSpring accessibilityLabel="Smaller world" onPress={() => nudgeWorldScale(-0.1)} style={s.scaleBtn}>
                <Text style={s.scaleTxt}>−</Text>
              </PressSpring>
              <Text style={s.scaleVal}>{Math.round(scale * 70)} cm</Text>
              <PressSpring accessibilityLabel="Larger world" onPress={() => nudgeWorldScale(0.1)} style={s.scaleBtn}>
                <Text style={s.scaleTxt}>+</Text>
              </PressSpring>
            </View>
          </View>
          {mock && <LuxButton testID="place-world" label="PLACE WORLD" hero onPress={onPlaceMock} style={{ marginTop: 14 }} />}
        </GlassFrame>
      </Animated.View>
    </View>
  );
}

/** A quiet glass row: icon glyph, Cinzel label, gold chevron. */
function MenuRow({ glyph, label, onPress, tone = L.crystal, testID }: { glyph: string; label: string; onPress: () => void; tone?: string; testID?: string }) {
  return (
    <PressSpring testID={testID} accessibilityLabel={label} onPress={onPress} style={s.row}>
      <View style={[s.rowGlyph, { borderColor: tone }]}>
        <Text style={[s.rowGlyphTxt, { color: tone }, titleGlow(tone, 6)]}>{glyph}</Text>
      </View>
      <Text style={s.rowLabel}>{label}</Text>
      <Text style={s.rowChevron}>›</Text>
    </PressSpring>
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
  const level = useStore(gameStore, (g) => g.session?.level);
  useEffect(() => {
    if (!visible) setShowSettings(false);
  }, [visible]);
  if (!visible) return null;
  // no exit fade: the board must take touches the instant RESUME is pressed (a fading scrim swallowed taps)
  return (
    <Animated.View entering={FadeIn.duration(220)} style={[StyleSheet.absoluteFill, s.scrim]}>
      <Animated.View entering={ZoomIn.springify().damping(14)} style={s.panelWrap}>
        <GlassFrame radius={26} glowColor={L.violet} style={s.panel}>
          <Text style={s.kicker}>{showSettings ? "THE KEEPER'S" : level ? (level.label ?? `LEVEL ${level.id}`).toUpperCase() : "THE WORLD"}</Text>
          <Text style={s.heading}>{showSettings ? "SETTINGS" : "PAUSED"}</Text>
          <View style={s.rule}>
            <View style={s.ruleLine} />
            <Text style={s.ruleGem}>◆</Text>
            <View style={s.ruleLine} />
          </View>
          {showSettings ? (
            <>
              <SettingsList />
              <MenuRow glyph="‹" label="BACK" onPress={() => setShowSettings(false)} tone={L.goldPale} />
            </>
          ) : (
            <View style={{ gap: 10 }}>
              <LuxButton testID="resume" label="RESUME" hero onPress={onResume} style={{ marginBottom: 6 }} />
              <MenuRow glyph="↻" label="RESTART LEVEL" onPress={onRestart} />
              <MenuRow glyph="⌖" label="RESET WORLD POSITION" onPress={onResetWorld} />
              <MenuRow glyph="⚙" label="SETTINGS" onPress={() => setShowSettings(true)} />
              <MenuRow glyph="⌂" label="EXIT TO MENU" onPress={onExit} tone={L.rose} />
            </View>
          )}
        </GlassFrame>
      </Animated.View>
    </Animated.View>
  );
}

const s = StyleSheet.create({
  card: { marginHorizontal: 16, padding: 20, gap: 6 },
  title: { color: L.goldLight, fontSize: 19, fontFamily: F.title, letterSpacing: 1.5, ...titleGlow("#ffcf6a", 10) },
  body: { color: L.mist, fontSize: 13.5, lineHeight: 20, fontFamily: F.body },
  label: { color: L.goldPale, fontFamily: F.title, fontSize: 10, letterSpacing: 2 },
  reticleWrap: { position: "absolute", top: "38%", alignSelf: "center", width: 200, height: 200, alignItems: "center", justifyContent: "center" },
  reticle: { position: "absolute", width: 190, height: 190, borderRadius: 95, borderWidth: 2, borderColor: L.crystal, shadowColor: L.crystal, shadowRadius: 14, shadowOpacity: 0.9 },
  reticleInner: { width: 120, height: 120, borderRadius: 60, borderColor: L.goldPale, borderStyle: "dashed" },
  scaleRow: { flexDirection: "row", justifyContent: "space-between", alignItems: "center", marginTop: 10 },
  scaleBtn: {
    width: 40, height: 40, borderRadius: 20, alignItems: "center", justifyContent: "center",
    backgroundColor: "rgba(20,26,61,0.9)", borderWidth: 1.5, borderColor: "rgba(246,211,138,0.7)",
  },
  scaleTxt: { color: L.goldLight, fontSize: 22, fontFamily: F.bold, marginTop: -2 },
  scaleVal: { color: L.ivory, fontFamily: F.number, fontSize: 15, minWidth: 56, textAlign: "center" },
  scrim: { backgroundColor: "rgba(4,5,20,0.72)", justifyContent: "center", padding: 22 },
  panelWrap: { maxWidth: 420, width: "100%", alignSelf: "center" },
  panel: { paddingHorizontal: 20, paddingTop: 22, paddingBottom: 20 },
  kicker: { color: L.crystal, fontFamily: F.title, fontSize: 10, letterSpacing: 3, textAlign: "center" },
  heading: { color: L.goldLight, fontSize: 32, fontFamily: F.display, letterSpacing: 4, textAlign: "center", marginTop: 2, ...titleGlow("#ffcf6a", 18) },
  rule: { flexDirection: "row", alignItems: "center", gap: 8, marginVertical: 14, paddingHorizontal: 30 },
  ruleLine: { flex: 1, height: 1, backgroundColor: "rgba(246,211,138,0.45)" },
  ruleGem: { color: L.goldPale, fontSize: 10 },
  row: {
    flexDirection: "row", alignItems: "center", gap: 12, paddingHorizontal: 12, paddingVertical: 10, borderRadius: 16,
    backgroundColor: "rgba(30,35,82,0.75)", borderWidth: 1, borderColor: "rgba(246,211,138,0.28)",
  },
  rowGlyph: { width: 32, height: 32, borderRadius: 16, borderWidth: 1.2, alignItems: "center", justifyContent: "center", backgroundColor: "rgba(7,9,32,0.6)" },
  rowGlyphTxt: { fontSize: 16, fontFamily: F.bold },
  rowLabel: { flex: 1, color: L.ivory, fontFamily: F.title, fontSize: 13.5, letterSpacing: 1.4 },
  rowChevron: { color: L.goldPale, fontSize: 22, fontFamily: F.bold, marginTop: -2 },
});
