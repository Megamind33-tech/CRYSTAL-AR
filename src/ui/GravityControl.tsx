// GRAVITY DIAL — luminous fantasy. A frosted capsule holding two glass turn orbs around a cyan dial
// whose needle springs to the new fall direction; charge pips glow like crystal and flare when spent.
// Plain RN + Reanimated (no Skia canvas): the in-game view is already close to the WebGL context cap.
import { useEffect, useRef } from "react";
import { StyleSheet, Text, View } from "react-native";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import Animated, { useAnimatedStyle, useSharedValue, withSequence, withSpring, withTiming } from "react-native-reanimated";
import { MAX_GRAVITY_CHARGES } from "../game/level";
import { rotatedGravity } from "../game/resolve";
import { gameStore, turnTabletop } from "../state/game";
import { useStore } from "../state/store";
import { useLoop } from "./lux/Lux";
import { GlassOrb } from "./lux/Orb";
import { F, L, titleGlow } from "./lux/tokens";

/** Needle angle for each fall direction (the needle glyph points down at 0°). */
const ANGLE = { left: 90, down: 0, right: -90 } as const;

function Pip({ on }: { on: boolean }) {
  const k = useSharedValue(on ? 1 : 0);
  const flare = useSharedValue(0);
  const first = useRef(true);
  useEffect(() => {
    if (first.current) {
      first.current = false;
      return;
    }
    k.value = withSpring(on ? 1 : 0, { damping: 9, stiffness: 220 });
    flare.value = withSequence(withTiming(1, { duration: 110 }), withTiming(0, { duration: 520 }));
  }, [on, k, flare]);
  const gem = useAnimatedStyle(() => ({
    backgroundColor: k.value > 0.5 ? L.crystal : "rgba(7,9,32,0.9)",
    transform: [{ rotate: "45deg" }, { scale: 0.8 + k.value * 0.2 + flare.value * 0.5 }],
  }));
  const glow = useAnimatedStyle(() => ({ opacity: k.value * 0.55 + flare.value * 0.45, transform: [{ scale: 1 + flare.value * 0.8 }] }));
  return (
    <View style={g.pipBox}>
      <Animated.View style={[g.pipGlow, glow]} />
      <Animated.View style={[g.pip, gem]} />
    </View>
  );
}

/**
 * GRAVITY SHIFT: turn the tabletop. Shows the current fall direction and remaining charges;
 * only present on levels that grant charges (introduced in Emerald Canyon).
 */
export function GravityControl() {
  const insets = useSafeAreaInsets();
  const uses = useStore(gameStore, (s) => (s.session?.level.gravityCharges ?? 0) > 0);
  const gravity = useStore(gameStore, (s) => s.gravity);
  const charges = useStore(gameStore, (s) => s.gravityCharges);
  const busy = useStore(gameStore, (s) => s.busy || !!s.result);

  const angle = useSharedValue<number>(ANGLE[gravity]);
  useEffect(() => {
    angle.value = withSpring(ANGLE[gravity], { damping: 8, stiffness: 120 });
  }, [gravity, angle]);
  const spin = useLoop(9000);
  const needle = useAnimatedStyle(() => ({ transform: [{ rotate: `${angle.value}deg` }] }));
  const halo = useAnimatedStyle(() => ({ transform: [{ rotate: `${spin.value * 360}deg` }] }));
  const t = useLoop(2400);
  const breathe = useAnimatedStyle(() => ({ opacity: charges > 0 ? 0.35 + Math.sin(t.value * Math.PI * 2) * 0.2 : 0.08 }));

  if (!uses) return null;
  const can = (turn: -1 | 1) => !busy && charges > 0 && !!rotatedGravity(gravity, turn);
  return (
    <View pointerEvents="box-none" style={[g.wrap, { bottom: insets.bottom + 16 }]}>
      <GlassOrb
        testID="turn-left"
        accessibilityLabel="Turn tabletop left"
        glyph="⟲"
        size={46}
        disabled={!can(-1)}
        onPress={() => turnTabletop(-1)}
      />
      <View style={g.center}>
        <View style={g.dial}>
          <Animated.View pointerEvents="none" style={[g.dialGlow, breathe]} />
          <Animated.View pointerEvents="none" style={[g.ticks, halo]}>
            {[0, 45, 90, 135, 180, 225, 270, 315].map((a) => (
              <View key={a} style={[g.tickArm, { transform: [{ rotate: `${a}deg` }] }]}>
                <View style={[g.tick, a % 90 === 0 && g.tickMajor]} />
              </View>
            ))}
          </Animated.View>
          <Animated.View pointerEvents="none" style={[g.needleWrap, needle]}>
            <View style={g.needleStem} />
            <Text style={g.needleHead}>▼</Text>
          </Animated.View>
          <View style={g.hub} />
        </View>
        <View style={g.pips}>
          {Array.from({ length: MAX_GRAVITY_CHARGES }, (_, i) => (
            <Pip key={i} on={i < charges} />
          ))}
        </View>
        <Text style={g.label}>GRAVITY</Text>
      </View>
      <GlassOrb
        testID="turn-right"
        accessibilityLabel="Turn tabletop right"
        glyph="⟳"
        size={46}
        disabled={!can(1)}
        onPress={() => turnTabletop(1)}
      />
    </View>
  );
}

const D = 44;
const g = StyleSheet.create({
  wrap: {
    position: "absolute", left: 12, flexDirection: "row", alignItems: "center", gap: 4, paddingHorizontal: 4, paddingVertical: 4, borderRadius: 40,
    backgroundColor: "rgba(14,18,48,0.82)", borderWidth: 1.2, borderColor: "rgba(246,211,138,0.55)",
    shadowColor: "#02030f", shadowOpacity: 0.55, shadowRadius: 10, shadowOffset: { width: 0, height: 5 }, elevation: 6,
  },
  center: { alignItems: "center", minWidth: 62, paddingTop: 2 },
  dial: {
    width: D, height: D, borderRadius: D / 2, alignItems: "center", justifyContent: "center",
    backgroundColor: "rgba(7,9,32,0.95)", borderWidth: 1.5, borderColor: L.crystal,
  },
  dialGlow: {
    position: "absolute", width: D + 8, height: D + 8, borderRadius: (D + 8) / 2, backgroundColor: L.aether,
    shadowColor: L.crystal, shadowRadius: 12, shadowOpacity: 1, shadowOffset: { width: 0, height: 0 },
  },
  ticks: { position: "absolute", width: D, height: D, alignItems: "center", justifyContent: "center" },
  tickArm: { position: "absolute", width: 2, height: D - 4, alignItems: "center" },
  tick: { width: 1.5, height: 3, borderRadius: 1, backgroundColor: "rgba(127,231,255,0.55)" },
  tickMajor: { width: 2, height: 5, backgroundColor: L.goldPale },
  needleWrap: { position: "absolute", width: D, height: D, alignItems: "center", justifyContent: "center" },
  needleStem: { position: "absolute", top: D / 2 - 2, width: 2.5, height: 11, borderRadius: 2, backgroundColor: L.crystalSoft },
  needleHead: { position: "absolute", top: D / 2 + 5, color: L.crystal, fontSize: 11, lineHeight: 12, fontFamily: F.bold, ...titleGlow(L.crystal, 8) },
  hub: { width: 9, height: 9, borderRadius: 5, backgroundColor: L.goldPale, borderWidth: 1, borderColor: L.goldDeep },
  pips: { flexDirection: "row", gap: 3, marginTop: 4 },
  pipBox: { width: 12, height: 12, alignItems: "center", justifyContent: "center" },
  pipGlow: {
    position: "absolute", width: 10, height: 10, borderRadius: 5, backgroundColor: L.crystal,
    shadowColor: L.crystal, shadowRadius: 6, shadowOpacity: 1, shadowOffset: { width: 0, height: 0 },
  },
  pip: { width: 7, height: 7, borderWidth: 1, borderColor: L.crystal },
  label: { color: L.goldPale, fontSize: 8, letterSpacing: 2, marginTop: 1, fontFamily: F.title },
});
