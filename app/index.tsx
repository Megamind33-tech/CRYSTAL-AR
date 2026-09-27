import { useEffect, useRef } from "react";
import { Animated, Easing, Pressable, StyleSheet, Text, View } from "react-native";
import { useRouter } from "expo-router";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import { LEVELS } from "@/src/game/level";
import { CRYSTAL_COLORS } from "@/src/render/assets";
import { progressStore } from "@/src/state/settings";
import { useStore } from "@/src/state/store";
import { Button } from "@/src/ui/Button";
import { C, font } from "@/src/ui/theme";

/** Slowly drifting facets behind the title – pure RN, no 3D needed on the menu. */
function Facet({ i }: { i: number }) {
  const v = useRef(new Animated.Value(0)).current;
  useEffect(() => {
    Animated.loop(Animated.timing(v, { toValue: 1, duration: 9000 + i * 1700, easing: Easing.inOut(Easing.sin), useNativeDriver: true })).start();
  }, [v, i]);
  const size = 18 + ((i * 37) % 30);
  return (
    <Animated.View
      pointerEvents="none"
      style={{
        position: "absolute",
        left: `${(i * 23) % 90 + 3}%`,
        top: `${(i * 41) % 80 + 6}%`,
        width: size,
        height: size,
        backgroundColor: CRYSTAL_COLORS[i % 5],
        opacity: v.interpolate({ inputRange: [0, 0.5, 1], outputRange: [0.12, 0.38, 0.12] }),
        transform: [{ rotate: "45deg" }, { translateY: v.interpolate({ inputRange: [0, 1], outputRange: [0, -30] }) }],
        borderRadius: 3,
      }}
    />
  );
}

export default function Menu() {
  const router = useRouter();
  const insets = useSafeAreaInsets();
  const progress = useStore(progressStore, (p) => p);
  const glow = useRef(new Animated.Value(0)).current;
  useEffect(() => {
    Animated.loop(
      Animated.sequence([
        Animated.timing(glow, { toValue: 1, duration: 2200, useNativeDriver: true }),
        Animated.timing(glow, { toValue: 0, duration: 2200, useNativeDriver: true }),
      ]),
    ).start();
  }, [glow]);

  const play = (level: number) => router.push({ pathname: "/play", params: { level: String(level) } });

  return (
    <View style={[s.root, { paddingTop: insets.top + 40, paddingBottom: insets.bottom + 28 }]}>
      <View style={s.vignette} />
      {Array.from({ length: 14 }, (_, i) => (
        <Facet key={i} i={i} />
      ))}
      <View style={s.titleBlock}>
        <Animated.View style={[s.halo, { opacity: glow.interpolate({ inputRange: [0, 1], outputRange: [0.25, 0.6] }) }]} />
        <Text style={s.title}>CRYSTALS</Text>
        <Text style={s.titleAr}>AR</Text>
        <Text style={s.tagline}>Turn the real world into your puzzle board.</Text>
      </View>

      <View style={s.levels}>
        {LEVELS.map((l, i) => {
          const locked = i > progress.unlocked;
          return (
            <Pressable
              key={l.id}
              disabled={locked}
              accessibilityRole="button"
              accessibilityLabel={locked ? `Level ${l.id} locked` : `Play level ${l.id}, ${l.name}`}
              onPress={() => play(i)}
              style={({ pressed }) => [s.levelChip, locked && { opacity: 0.35 }, pressed && { transform: [{ scale: 0.96 }] }]}
            >
              <Text style={s.levelNum}>{locked ? "🔒" : l.id}</Text>
              <Text style={s.levelName} numberOfLines={1}>
                {l.name}
              </Text>
              <Text style={s.levelStars}>{"★".repeat(progress.stars[i]) + "☆".repeat(3 - progress.stars[i])}</Text>
            </Pressable>
          );
        })}
      </View>

      <View style={s.buttons}>
        <Button testID="play" label="PLAY" variant="primary" onPress={() => play(progress.unlocked)} />
        <Button testID="settings" label="SETTINGS" onPress={() => router.push("/settings")} />
      </View>
      <Text style={s.foot}>Forest Ruins · Best on a well-lit table</Text>
    </View>
  );
}

const s = StyleSheet.create({
  root: { flex: 1, backgroundColor: C.bg, paddingHorizontal: 24, justifyContent: "space-between" },
  vignette: { position: "absolute", top: 0, left: 0, right: 0, bottom: 0, backgroundColor: "#12201a", opacity: 0.55 },
  titleBlock: { alignItems: "center", marginTop: 24 },
  halo: { position: "absolute", top: -30, width: 260, height: 160, borderRadius: 130, backgroundColor: "#2f7a64" },
  title: { color: C.ink, fontSize: 46, letterSpacing: 10, fontFamily: font.display, fontWeight: "700" },
  titleAr: { color: C.gold, fontSize: 20, letterSpacing: 14, fontWeight: "800", marginTop: -2 },
  tagline: { color: C.inkDim, fontSize: 15, marginTop: 18, fontFamily: font.display, fontStyle: "italic", textAlign: "center" },
  levels: { flexDirection: "row", gap: 10, justifyContent: "center" },
  levelChip: { flex: 1, maxWidth: 130, paddingVertical: 14, paddingHorizontal: 8, borderRadius: 16, backgroundColor: "rgba(255,255,255,0.05)", borderWidth: StyleSheet.hairlineWidth, borderColor: C.line, alignItems: "center", gap: 4 },
  levelNum: { color: C.gold, fontSize: 22, fontWeight: "800" },
  levelName: { color: C.inkDim, fontSize: 11, fontFamily: font.body },
  levelStars: { color: C.gold, fontSize: 12, letterSpacing: 2 },
  buttons: { gap: 12 },
  foot: { color: C.inkFaint, fontSize: 12, textAlign: "center" },
});
