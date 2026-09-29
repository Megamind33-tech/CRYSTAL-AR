// KEEPER'S WHISPER — first-session tips, luminous fantasy. Each new line springs up in a frosted glass
// bubble with a gold hairline and a breathing crystal sigil. Plain RN + Reanimated (no canvas).
import { useEffect, useRef } from "react";
import { StyleSheet, Text, View } from "react-native";
import Animated, { FadeInDown, FadeOut, useAnimatedStyle } from "react-native-reanimated";
import { gameStore } from "../state/game";
import { analytics, metaStore } from "../state/meta";
import { useStore } from "../state/store";
import { useLoop } from "./lux/Lux";
import { F, L, titleGlow } from "./lux/tokens";

/**
 * First-session coaching for a brand-new Keeper: one short line at a time, tied to real game state,
 * gone after the first restoration. No shop, trials or currencies are mentioned here.
 */
export function Coach() {
  const newKeeper = useStore(metaStore, (m) => !!m.player && Object.keys(m.player.islands).length === 0);
  const moves = useStore(gameStore, (s) => s.moveCount);
  const progress = useStore(gameStore, (s) => s.progress);
  const selected = useStore(gameStore, (s) => !!s.selected);
  const result = useStore(gameStore, (s) => s.result);
  const started = useRef(false);
  const t = useLoop(2600);
  const bob = useAnimatedStyle(() => ({ transform: [{ translateY: Math.sin(t.value * Math.PI * 2) * 3 }] }));
  const sigil = useAnimatedStyle(() => ({ opacity: 0.45 + Math.sin(t.value * Math.PI * 2) * 0.35, transform: [{ scale: 1 + Math.sin(t.value * Math.PI * 2) * 0.18 }] }));

  useEffect(() => {
    if (newKeeper && !started.current) {
      started.current = true;
      analytics.track("tutorial_started");
    }
  }, [newKeeper]);
  useEffect(() => {
    if (started.current && result?.won) analytics.track("tutorial_completed");
  }, [result]);

  if (!newKeeper || result) return null;
  const line =
    moves === 0 && !selected ? "Touch a crystal, then swipe it toward a neighbour."
    : moves === 0 ? "Swipe toward a neighbour to line up three of a kind."
    : moves < 3 ? "Every match sends Resonance into the portal. Watch the island answer."
    : progress < 0.5 ? "Line up four for a Surge crystal. Five makes a Prism."
    : progress < 1 ? "The portal is waking. Keep the Resonance flowing."
    : null;
  if (!line) return null;
  return (
    <View pointerEvents="none" style={s.wrap}>
      <Animated.View key={line} entering={FadeInDown.springify().damping(14)} exiting={FadeOut.duration(200)}>
        <Animated.View style={[s.bubble, bob]}>
          <View style={s.sheen} />
          <View style={s.sigilBox}>
            <Animated.View style={[s.sigilGlow, sigil]} />
            <Text style={s.sigil}>✧</Text>
          </View>
          <View style={{ flexShrink: 1 }}>
            <Text style={s.kicker}>KEEPER&apos;S WHISPER</Text>
            <Text style={s.txt}>{line}</Text>
          </View>
        </Animated.View>
      </Animated.View>
    </View>
  );
}

const s = StyleSheet.create({
  wrap: { position: "absolute", left: 16, right: 16, bottom: 118, alignItems: "center" },
  bubble: {
    flexDirection: "row", alignItems: "center", gap: 12, paddingLeft: 12, paddingRight: 16, paddingVertical: 10, borderRadius: 20, overflow: "hidden",
    backgroundColor: "rgba(20,26,61,0.9)", borderWidth: 1.2, borderColor: "rgba(246,211,138,0.6)", maxWidth: 380,
    shadowColor: "#02030f", shadowOpacity: 0.55, shadowRadius: 12, shadowOffset: { width: 0, height: 6 }, elevation: 6,
  },
  sheen: { position: "absolute", left: 0, right: 0, top: 0, height: "45%", backgroundColor: "rgba(255,255,255,0.06)" },
  sigilBox: { width: 32, height: 32, alignItems: "center", justifyContent: "center" },
  sigilGlow: {
    position: "absolute", width: 26, height: 26, borderRadius: 13, backgroundColor: L.aether,
    shadowColor: L.crystal, shadowRadius: 10, shadowOpacity: 1, shadowOffset: { width: 0, height: 0 },
  },
  sigil: { color: "#ffffff", fontSize: 18, fontFamily: F.bold, ...titleGlow(L.crystal, 8) },
  kicker: { color: L.goldPale, fontFamily: F.title, fontSize: 8.5, letterSpacing: 2.2, marginBottom: 1 },
  txt: { color: L.ivory, fontFamily: F.title, fontStyle: "italic", fontSize: 14, lineHeight: 20 },
});
