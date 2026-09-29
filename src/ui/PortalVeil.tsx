// PORTAL VEIL — luminous fantasy. The light inside the gate: crystal, violet and gold rings bloom out
// of a white core, a rune circle turns, streaks of light rush past, and the destination is named in
// italic Cinzel. Every layer rides the same `glow` value, whose fade logic below must stay as it is
// (it fixed a stuck white screen). Plain RN views – no canvas – so it never costs a WebGL context.
import { useEffect, useRef, useState } from "react";
import { Animated, StyleSheet, Text, View } from "react-native";
import R, { useAnimatedStyle } from "react-native-reanimated";
import { gameStore } from "../state/game";
import { useStore } from "../state/store";
import { useLoop } from "./lux/Lux";
import { F, L, titleGlow } from "./lux/tokens";

const RINGS = [
  { size: 200, color: L.crystal, width: 3, to: 1.35 },
  { size: 280, color: L.violet, width: 2, to: 1.65 },
  { size: 360, color: L.goldPale, width: 1.5, to: 1.95 },
];
const STREAKS = Array.from({ length: 16 }, (_, i) => ({ a: (i * 360) / 16 + (i % 3) * 7, len: 60 + (i % 4) * 26, d: 90 + (i % 5) * 18 }));
const RUNES = Array.from({ length: 12 }, (_, i) => i * 30);

/**
 * The light inside the portal. It swells as the world rushes toward the gate, hides the swap to the
 * next island, and clears as the new island rises – there is no loading screen.
 */
export function PortalVeil() {
  const travel = useStore(gameStore, (s) => s.travel);
  const glow = useRef(new Animated.Value(0)).current;
  const [to, setTo] = useState("");
  const spin = useLoop(7000);
  const rush = useLoop(900);

  useEffect(() => {
    // never stop a running fade from a cleanup: a cancelled fade-out left the screen stuck white.
    // Each phase simply animates toward its own target; when travel ends the veil always clears.
    if (!travel) {
      Animated.timing(glow, { toValue: 0, duration: 350, useNativeDriver: true }).start();
      return;
    }
    setTo(travel.to);
    if (travel.phase === "dive") Animated.sequence([Animated.delay(500), Animated.timing(glow, { toValue: 1, duration: 650, useNativeDriver: true })]).start();
    else Animated.sequence([Animated.delay(250), Animated.timing(glow, { toValue: 0, duration: 800, useNativeDriver: true })]).start();
  }, [travel?.phase, travel?.seq]); // eslint-disable-line react-hooks/exhaustive-deps

  const runeSpin = useAnimatedStyle(() => ({ transform: [{ rotate: `${spin.value * 360}deg` }] }));
  const runeSpinBack = useAnimatedStyle(() => ({ transform: [{ rotate: `${-spin.value * 240}deg` }] }));
  const streak = useAnimatedStyle(() => ({ opacity: 0.25 + Math.sin(rush.value * Math.PI) * 0.55, transform: [{ scale: 0.8 + rush.value * 0.7 }] }));

  return (
    <Animated.View pointerEvents={travel ? "auto" : "none"} style={[StyleSheet.absoluteFill, s.veil, { opacity: glow }]}>
      <View style={s.tintTop} />
      <View style={s.tintBottom} />
      <Animated.View style={[s.core, { transform: [{ scale: glow.interpolate({ inputRange: [0, 1], outputRange: [0.2, 3.2] }) }] }]} />
      {travel && (
        <R.View pointerEvents="none" style={[s.center, streak]}>
          {STREAKS.map((k, i) => (
            <View key={i} style={[s.streakArm, { transform: [{ rotate: `${k.a}deg` }] }]}>
              <View style={[s.streak, { height: k.len, marginTop: -k.d - k.len, backgroundColor: i % 2 ? L.crystal : L.goldPale }]} />
            </View>
          ))}
        </R.View>
      )}
      {RINGS.map((r, i) => (
        <Animated.View
          key={i}
          pointerEvents="none"
          style={[
            s.ring,
            { width: r.size, height: r.size, borderRadius: r.size / 2, borderColor: r.color, borderWidth: r.width, shadowColor: r.color },
            { opacity: glow.interpolate({ inputRange: [0, 0.6, 1], outputRange: [0, 0.95, 0.8] }), transform: [{ scale: glow.interpolate({ inputRange: [0, 1], outputRange: [0.3, r.to] }) }] },
          ]}
        />
      ))}
      {travel && (
        <>
          <R.View pointerEvents="none" style={[s.runeRing, runeSpin]}>
            {RUNES.map((a) => (
              <View key={a} style={[s.runeArm, { transform: [{ rotate: `${a}deg` }] }]}>
                <View style={[s.rune, a % 90 === 0 && s.runeMajor]} />
              </View>
            ))}
          </R.View>
          <R.View pointerEvents="none" style={[s.runeRing, s.runeRingInner, runeSpinBack]} />
        </>
      )}
      {to ? (
        <View style={s.copy}>
          <Text style={s.kicker}>THROUGH THE PORTAL</Text>
          <Text style={s.to}>{to}</Text>
        </View>
      ) : null}
    </Animated.View>
  );
}

const s = StyleSheet.create({
  veil: { backgroundColor: "rgba(214,246,255,0.96)", alignItems: "center", justifyContent: "center", overflow: "hidden" },
  tintTop: { position: "absolute", left: 0, right: 0, top: 0, height: "38%", backgroundColor: "rgba(106,75,200,0.16)" },
  tintBottom: { position: "absolute", left: 0, right: 0, bottom: 0, height: "30%", backgroundColor: "rgba(246,211,138,0.2)" },
  center: { position: "absolute", width: 2, height: 2, alignItems: "center", justifyContent: "center" },
  streakArm: { position: "absolute", width: 2, height: 2, alignItems: "center" },
  streak: { width: 2, borderRadius: 1, opacity: 0.8 },
  ring: { position: "absolute", shadowRadius: 18, shadowOpacity: 1, shadowOffset: { width: 0, height: 0 } },
  runeRing: { position: "absolute", width: 230, height: 230, borderRadius: 115, borderWidth: 1, borderColor: "rgba(106,75,200,0.35)", alignItems: "center", justifyContent: "center" },
  runeRingInner: { width: 170, height: 170, borderRadius: 85, borderStyle: "dashed", borderColor: "rgba(184,122,40,0.45)" },
  runeArm: { position: "absolute", width: 10, height: 230, alignItems: "center" },
  rune: { width: 6, height: 6, marginTop: -3, backgroundColor: L.violet, transform: [{ rotate: "45deg" }], opacity: 0.7 },
  runeMajor: { width: 9, height: 9, marginTop: -4.5, backgroundColor: L.gold },
  core: { position: "absolute", width: 260, height: 260, borderRadius: 130, backgroundColor: "#ffffff", shadowColor: "#ffffff", shadowRadius: 40, shadowOpacity: 1 },
  copy: { alignItems: "center", gap: 6, paddingHorizontal: 30 },
  kicker: { color: L.violet, fontFamily: F.title, fontSize: 11, letterSpacing: 4 },
  to: { color: L.night700, fontFamily: F.title, fontStyle: "italic", fontSize: 26, letterSpacing: 1, textAlign: "center", ...titleGlow(L.crystal, 14) },
});
