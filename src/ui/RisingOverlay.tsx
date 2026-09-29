// THE WORLD RISES — the loading veil, luminous fantasy. Night sky, a heart crystal rising and turning
// inside a gold ring, the island's line in italic Cinzel and a liquid-light meter. The reveal logic
// (baseline / pending / give-up) is unchanged; only the look is new.
import { useEffect, useRef, useState } from "react";
import { Animated, StyleSheet, Text, View } from "react-native";
import R, { useAnimatedStyle } from "react-native-reanimated";
import { useLoadProgress } from "../render/LoadQueue";
import { arSession } from "../state/arSession";
import { useStore } from "../state/store";
import { Meter, NightSky, useLoop } from "./lux/Lux";
import { F, L, titleGlow } from "./lux/tokens";

/** A turning heart crystal on a gold ring, rising and settling in a slow breath. */
function RisingCrystal() {
  const t = useLoop(3200);
  const spin = useLoop(10000);
  const float = useAnimatedStyle(() => ({ transform: [{ translateY: Math.sin(t.value * Math.PI * 2) * 7 }] }));
  const glow = useAnimatedStyle(() => ({ opacity: 0.45 + Math.sin(t.value * Math.PI * 2) * 0.25, transform: [{ scale: 1 + Math.sin(t.value * Math.PI * 2) * 0.08 }] }));
  const ring = useAnimatedStyle(() => ({ transform: [{ rotate: `${spin.value * 360}deg` }] }));
  const facet = useAnimatedStyle(() => ({ transform: [{ rotate: "45deg" }, { scaleX: 0.72 + Math.abs(Math.cos(spin.value * Math.PI * 4)) * 0.28 }] }));
  return (
    <View style={c.box}>
      <R.View style={[c.halo, glow]} />
      <R.View style={[c.ring, ring]}>
        {[0, 90, 180, 270].map((a) => (
          <View key={a} style={[c.arm, { transform: [{ rotate: `${a}deg` }] }]}>
            <View style={c.pin} />
          </View>
        ))}
      </R.View>
      <R.View style={float}>
        <R.View style={[c.gem, facet]}>
          <View style={c.gemTop} />
          <View style={c.gemShine} />
        </R.View>
      </R.View>
    </View>
  );
}

/**
 * Covers the scene while the island's assets stream in one at a time, so the player sees the
 * world appear whole instead of assembling piece by piece.
 */
export function RisingOverlay({ label = "The Forest Ruins are rising…" }: { label?: string }) {
  const placed = useStore(arSession, (s) => s.phase === "placed");
  const { done, total, pending } = useLoadProgress();
  const [settled, setSettled] = useState(false);
  const fade = useRef(new Animated.Value(1)).current;
  // Viro mounts the world's parts some time after placement (seconds on a slow phone), so "nothing
  // pending" means nothing until this placement has actually queued its own loads.
  const baseline = useRef<number | null>(null);
  if (!placed) baseline.current = null;
  else if (baseline.current === null) baseline.current = total;
  const queued = placed && total > (baseline.current ?? total);

  useEffect(() => {
    if (!placed) {
      setSettled(false);
      fade.setValue(1);
      return;
    }
    const reveal = () => {
      setSettled(true);
      Animated.timing(fade, { toValue: 0, duration: 500, useNativeDriver: true }).start();
    };
    // never trap the player behind the overlay if a load goes missing
    const giveUp = setTimeout(reveal, 25000);
    if (!queued || pending > 0) return () => clearTimeout(giveUp);
    // give late-mounting parts a moment to take their place in the queue before calling it done
    const t = setTimeout(reveal, 700);
    return () => {
      clearTimeout(t);
      clearTimeout(giveUp);
    };
  }, [placed, queued, pending, fade]);

  if (!placed || settled) return null;
  const value = queued ? Math.max(0.05, (done - (baseline.current ?? 0)) / (total - (baseline.current ?? 0))) : 0.05;
  return (
    <Animated.View pointerEvents="none" style={[StyleSheet.absoluteFill, c.wrap, { opacity: fade }]}>
      <NightSky />
      <RisingCrystal />
      <Text style={c.kicker}>THE WORLD RISES</Text>
      <Text style={c.title}>{label}</Text>
      <View style={{ width: 220, marginTop: 6 }}>
        <Meter value={value} colors={[L.aether, L.crystal]} height={9} />
      </View>
      <Text style={c.pct}>{Math.round(Math.min(1, value) * 100)}%</Text>
    </Animated.View>
  );
}

const G = 56;
const c = StyleSheet.create({
  wrap: { backgroundColor: L.night900, alignItems: "center", justifyContent: "center", gap: 10 },
  box: { width: 160, height: 160, alignItems: "center", justifyContent: "center", marginBottom: 8 },
  halo: {
    position: "absolute", width: 110, height: 110, borderRadius: 55, backgroundColor: L.aether,
    shadowColor: L.crystal, shadowRadius: 40, shadowOpacity: 1, shadowOffset: { width: 0, height: 0 },
  },
  ring: { position: "absolute", width: 140, height: 140, borderRadius: 70, borderWidth: 1.5, borderColor: "rgba(246,211,138,0.7)", alignItems: "center", justifyContent: "center" },
  arm: { position: "absolute", width: 10, height: 140, alignItems: "center" },
  pin: { width: 9, height: 9, marginTop: -4.5, backgroundColor: L.goldPale, transform: [{ rotate: "45deg" }] },
  gem: { width: G, height: G, borderRadius: 8, overflow: "hidden", backgroundColor: "#1f6ab8", borderWidth: 2, borderColor: L.crystalSoft },
  gemTop: { position: "absolute", left: 0, top: 0, width: "58%", height: "58%", backgroundColor: L.crystal },
  gemShine: { position: "absolute", left: 7, top: 7, width: 10, height: 10, borderRadius: 2, backgroundColor: "rgba(255,255,255,0.9)" },
  kicker: { color: L.goldPale, fontFamily: F.title, fontSize: 10.5, letterSpacing: 4, ...titleGlow("#ffcf6a", 8) },
  title: { color: L.ivory, fontFamily: F.title, fontStyle: "italic", fontSize: 19, textAlign: "center", paddingHorizontal: 30, ...titleGlow(L.violet, 12) },
  pct: { color: L.mist, fontFamily: F.number, fontSize: 12, letterSpacing: 1 },
});
