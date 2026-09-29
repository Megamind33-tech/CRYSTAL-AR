// THE ISLAND SPEAKS — luminous fantasy call-outs. A twist slams in as an ember banner between gold
// hairlines ("THE ISLAND STIRS"), a secret arrives with a gold glint sweeping its face, and the arrival
// passage drifts up as an italic Cinzel line. Plain RN + Reanimated: no canvas over the 3D world.
import { useEffect, useState } from "react";
import { StyleSheet, Text, View } from "react-native";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import Animated, { Easing, useAnimatedStyle, useSharedValue, withDelay, withSequence, withSpring, withTiming } from "react-native-reanimated";
import { gameStore } from "../state/game";
import { useStore } from "../state/store";
import { useLoop } from "./lux/Lux";
import { F, L, titleGlow } from "./lux/tokens";

const HOLD = { story: 6500, twist: 2600, secret: 3800 } as const;
const ACCENT = { story: L.crystalSoft, twist: L.ember, secret: L.goldLight } as const;

/**
 * The island speaks: its arrival passage when you land, a line when a hidden twist strikes, and a
 * glint when a secret is found. Quiet, in-world, and gone on its own.
 */
export function Announce() {
  const insets = useSafeAreaInsets();
  const msg = useStore(gameStore, (s) => s.announce);
  const [shown, setShown] = useState(msg);
  const [w, setW] = useState(0);
  const p = useSharedValue(0); // 0 hidden → 1 shown
  const glint = useSharedValue(0);
  const t = useLoop(2400);

  useEffect(() => {
    if (!msg) return;
    setShown(msg);
    p.value = 0;
    glint.value = 0;
    const inn = msg.tone === "story" ? withTiming(1, { duration: 700, easing: Easing.out(Easing.cubic) }) : withSpring(1, { damping: 11, stiffness: 170 });
    p.value = withSequence(inn, withDelay(HOLD[msg.tone], withTiming(0, { duration: 600 })));
    glint.value = withDelay(msg.tone === "secret" ? 250 : 350, withTiming(1, { duration: 900, easing: Easing.inOut(Easing.quad) }));
  }, [msg?.seq]); // eslint-disable-line react-hooks/exhaustive-deps

  const tone = shown?.tone ?? "story";
  const wrap = useAnimatedStyle(() => ({
    opacity: Math.min(1, p.value * 1.4),
    transform: tone === "story"
      ? [{ translateY: (1 - p.value) * 14 }]
      : [{ scale: tone === "twist" ? 1.12 - p.value * 0.12 : 0.85 + p.value * 0.15 }],
  }));
  const sweep = useAnimatedStyle(() => ({ transform: [{ translateX: -120 + glint.value * (w + 240) }, { skewX: "-20deg" }] }));
  const lines = useAnimatedStyle(() => ({ transform: [{ scaleX: Math.min(1, p.value) }] }));
  const spark = useAnimatedStyle(() => ({ transform: [{ rotate: `${t.value * 360}deg` }, { scale: 0.85 + Math.sin(t.value * Math.PI * 4) * 0.15 }] }));
  const ember = useAnimatedStyle(() => ({ opacity: 0.35 + Math.sin(t.value * Math.PI * 2) * 0.2 }));

  if (!shown) return null;
  const accent = ACCENT[tone];

  if (tone === "story") {
    return (
      <Animated.View pointerEvents="none" style={[s.storyWrap, { top: insets.top + 122 }, wrap]}>
        <View style={s.storyRule}>
          <View style={[s.storyLine, { backgroundColor: "rgba(191,244,255,0.35)" }]} />
          <Text style={s.storyGem}>✧</Text>
          <View style={[s.storyLine, { backgroundColor: "rgba(191,244,255,0.35)" }]} />
        </View>
        <Text style={s.story}>{shown.text}</Text>
      </Animated.View>
    );
  }

  return (
    <Animated.View pointerEvents="none" style={[s.wrap, { top: insets.top + 118 }, wrap]} onLayout={(e) => setW(e.nativeEvent.layout.width)}>
      {tone === "twist" && <Animated.View style={[s.emberGlow, ember]} />}
      <View style={s.band}>
        <Animated.View style={[s.hair, s.hairTop, { backgroundColor: accent }, lines]} />
        <Animated.View style={[s.hair, s.hairBottom, { backgroundColor: accent }, lines]} />
        <View style={[s.pin, s.pinTop, { backgroundColor: accent }]} />
        <View style={[s.pin, s.pinBottom, { backgroundColor: accent }]} />
        <Animated.View style={[s.sweep, sweep]} />
        <View style={s.tagRow}>
          {tone === "secret" && <Animated.Text style={[s.spark, spark]}>✦</Animated.Text>}
          <Text style={[s.tag, { color: accent }, titleGlow(tone === "twist" ? L.ember : "#ffcf6a", 14)]}>
            {tone === "twist" ? "THE ISLAND STIRS" : "SECRET FOUND"}
          </Text>
          {tone === "secret" && <Animated.Text style={[s.spark, spark]}>✦</Animated.Text>}
        </View>
        <Text style={s.text}>{shown.text}</Text>
      </View>
    </Animated.View>
  );
}

const s = StyleSheet.create({
  wrap: { position: "absolute", left: 12, right: 64, alignItems: "stretch" },
  emberGlow: {
    position: "absolute", left: 20, right: 20, top: 6, bottom: 6, borderRadius: 30, backgroundColor: L.ember,
    shadowColor: L.ember, shadowRadius: 26, shadowOpacity: 1, shadowOffset: { width: 0, height: 0 },
  },
  band: {
    paddingHorizontal: 18, paddingTop: 12, paddingBottom: 11, borderRadius: 6, overflow: "hidden", gap: 3,
    backgroundColor: "rgba(12,14,40,0.9)",
  },
  hair: { position: "absolute", left: "8%", right: "8%", height: 1.5, opacity: 0.9 },
  hairTop: { top: 2 },
  hairBottom: { bottom: 2 },
  pin: { position: "absolute", alignSelf: "center", left: "50%", marginLeft: -4, width: 8, height: 8, transform: [{ rotate: "45deg" }] },
  pinTop: { top: -2 },
  pinBottom: { bottom: -2 },
  sweep: { position: "absolute", top: -10, bottom: -10, width: 70, backgroundColor: "rgba(255,241,184,0.28)" },
  tagRow: { flexDirection: "row", alignItems: "center", justifyContent: "center", gap: 10 },
  tag: { fontSize: 17, letterSpacing: 4, fontFamily: F.display, textAlign: "center" },
  spark: { color: L.goldLight, fontSize: 14, ...titleGlow("#ffcf6a", 10) },
  text: { color: L.ivory, fontSize: 13.5, lineHeight: 19, fontFamily: F.body, textAlign: "center" },
  storyWrap: { position: "absolute", left: 18, right: 64, alignItems: "center", gap: 6 },
  storyRule: { flexDirection: "row", alignItems: "center", gap: 8, width: 160 },
  storyLine: { flex: 1, height: 1 },
  storyGem: { color: L.crystalSoft, fontSize: 11, ...titleGlow(L.crystal, 8) },
  story: {
    color: L.ivory, fontSize: 16, lineHeight: 24, fontFamily: F.title, fontStyle: "italic", textAlign: "center", letterSpacing: 0.4,
    textShadowColor: "rgba(4,5,20,0.95)", textShadowRadius: 10, textShadowOffset: { width: 0, height: 1 },
  },
});
