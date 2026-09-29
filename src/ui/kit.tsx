// Shared building blocks for the meta-game screens, in the LUMINOUS FANTASY style
// (Figma › Luminous v2 › "Menu template"). Heavy GPU effects (Skia) are reserved for hero pieces;
// list cards and pills use a light-weight look-alike so long lists stay smooth on mid-range phones.
import { useEffect, type ReactNode } from "react";
import { Pressable, ScrollView, StyleSheet, Text, View, type ViewStyle } from "react-native";
import { useRouter } from "expo-router";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import Animated, { useAnimatedStyle, useSharedValue, withSpring } from "react-native-reanimated";
import { describeReward } from "../meta/core";
import type { Reward } from "../meta/types";
import { metaStore } from "../state/meta";
import { useStore } from "../state/store";
import { Capsule, Gem, Meter, NightSky, Rise } from "./lux/Lux";
import { F, L, titleGlow } from "./lux/tokens";

export function Screen({ title, subtitle, children, right }: { title: string; subtitle?: string; children: ReactNode; right?: ReactNode }) {
  const router = useRouter();
  const insets = useSafeAreaInsets();
  return (
    <View style={{ flex: 1, backgroundColor: L.night900 }}>
      <NightSky />
      <View style={[k.header, { paddingTop: insets.top + 10 }]}>
        <PressSpring accessibilityLabel="Back" onPress={() => (router.canGoBack() ? router.back() : router.replace("/"))} style={k.back}>
          <Text style={k.backTxt}>‹</Text>
        </PressSpring>
        <View style={{ flex: 1 }}>
          <Text style={k.title} numberOfLines={1}>{title.toUpperCase()}</Text>
          {subtitle ? <Text style={k.subtitle} numberOfLines={2}>{subtitle}</Text> : null}
        </View>
        {right}
      </View>
      <ScrollView contentContainerStyle={{ padding: 16, paddingBottom: insets.bottom + 40, gap: 16 }}>{children}</ScrollView>
    </View>
  );
}

export function Wallet() {
  const w = useStore(metaStore, (m) => m.player?.wallet);
  if (!w) return null;
  return (
    <View style={{ flexDirection: "row", gap: 6 }}>
      <Capsule value={w.prismDust.toLocaleString()} gem={<Gem size={16} />} />
      <Capsule value={w.aether.toLocaleString()} gem={<Gem size={16} colors={[L.crystalSoft, L.aether]} glow={L.aether} />} />
    </View>
  );
}

/** Pressable that squashes with a spring and glows back – every tappable surface uses it. */
export function PressSpring({ children, onPress, style, disabled, testID, accessibilityLabel }: {
  children: ReactNode; onPress?: () => void; style?: ViewStyle | ViewStyle[]; disabled?: boolean; testID?: string; accessibilityLabel?: string;
}) {
  const p = useSharedValue(0);
  const st = useAnimatedStyle(() => ({ transform: [{ scale: 1 - p.value * 0.045 }], opacity: 1 - p.value * 0.12 }));
  return (
    <Animated.View style={[st, { opacity: disabled ? 0.45 : 1 }]}>
      <Pressable
        testID={testID}
        accessibilityRole="button"
        accessibilityLabel={accessibilityLabel}
        disabled={disabled || !onPress}
        onPress={onPress}
        onPressIn={() => (p.value = withSpring(1, { damping: 14, stiffness: 420 }))}
        onPressOut={() => (p.value = withSpring(0, { damping: 10, stiffness: 260 }))}
        style={style}
      >
        {children}
      </Pressable>
    </Animated.View>
  );
}

/** Night-glass card: gold hairline, cyan rim, top sheen, soft drop – rises in on mount. */
export function Card({ children, style, onPress, testID }: { children: ReactNode; style?: ViewStyle; onPress?: () => void; testID?: string }) {
  const body = (
    <View style={[k.card, style]}>
      <View style={k.cardSheen} pointerEvents="none" />
      <View style={k.cardRim} pointerEvents="none" />
      {children}
    </View>
  );
  return (
    <Rise>
      {onPress ? (
        <PressSpring testID={testID} onPress={onPress}>
          {body}
        </PressSpring>
      ) : (
        body
      )}
    </Rise>
  );
}

export const Section = ({ title, children, note }: { title: string; children: ReactNode; note?: string }) => (
  <View style={{ gap: 10 }}>
    <View style={k.sectionHead}>
      <View style={k.diamond} />
      <Text style={k.section}>{title.toUpperCase()}</Text>
      <View style={k.hairline} />
      {note ? <Text style={k.note}>{note}</Text> : null}
    </View>
    {children}
  </View>
);

/** Progress: the liquid-light meter. */
export function Bar({ value, color = L.gold, height = 6 }: { value: number; color?: string; height?: number }) {
  const c: [string, string] = color === L.gold || color === "#f2c46b" ? [L.gold, L.goldLight] : [L.aether, color];
  return <Meter value={value} colors={c} height={Math.max(6, height)} />;
}

/** Compact action: gold, portal-blue glass, or ghost glass. Springs on press; the gold tone shimmers. */
export function Pill({ label, onPress, disabled, tone = "gold", testID }: { label: string; onPress?: () => void; disabled?: boolean; tone?: "gold" | "ghost" | "portal"; testID?: string }) {
  const shine = useSharedValue(0);
  useEffect(() => {
    if (tone === "gold" && !disabled) shine.value = withSpring(1, { damping: 20 });
  }, [tone, disabled, shine]);
  const bg = tone === "gold" ? L.gold : tone === "portal" ? "#2a5ab8" : "rgba(30,35,82,0.9)";
  const border = tone === "gold" ? L.goldLight : tone === "portal" ? L.crystal : "rgba(246,211,138,0.55)";
  return (
    <PressSpring testID={testID} accessibilityLabel={label} disabled={disabled} onPress={onPress} style={[k.pill, { backgroundColor: bg, borderColor: border }]}>
      <View style={[k.pillSheen, tone !== "gold" && { opacity: 0.35 }]} pointerEvents="none" />
      {tone === "gold" && <View style={k.pillDeep} pointerEvents="none" />}
      <Text style={[k.pillTxt, tone === "gold" ? { color: L.ink } : { color: "#eaf8ff", ...titleGlow(tone === "portal" ? L.crystal : L.aether, 6) }]} numberOfLines={1}>
        {label.toUpperCase()}
      </Text>
    </PressSpring>
  );
}

export const RewardLine = ({ reward, dim }: { reward: Reward; dim?: boolean }) => (
  <Text style={[k.reward, dim && { opacity: 0.55 }]} numberOfLines={2}>
    {describeReward(reward).join("  ·  ") || "—"}
  </Text>
);

export const Row = ({ children, style }: { children: ReactNode; style?: ViewStyle }) => (
  <View style={[{ flexDirection: "row", alignItems: "center", gap: 10 }, style]}>{children}</View>
);

export const T = {
  h: (t: string) => <Text style={k.h}>{t}</Text>,
  p: (t: string, dim = false) => <Text style={[k.p, dim && { color: L.mistDim }]}>{t}</Text>,
};

/** Transient feedback line for failed actions ("Not enough Prism Dust"). */
export const ErrorLine = ({ msg }: { msg: string | null }) => (msg ? <Text style={k.err}>{msg}</Text> : null);

export const k = StyleSheet.create({
  header: { flexDirection: "row", alignItems: "center", gap: 12, paddingHorizontal: 14, paddingBottom: 12 },
  back: {
    width: 40, height: 40, borderRadius: 20, alignItems: "center", justifyContent: "center",
    backgroundColor: "rgba(20,26,61,0.9)", borderWidth: 1.5, borderColor: "rgba(246,211,138,0.75)",
  },
  backTxt: { color: L.goldPale, fontSize: 26, marginTop: -3, fontFamily: F.bold },
  title: { color: L.goldLight, fontSize: 22, fontFamily: F.display, letterSpacing: 2.5, ...titleGlow("#ffcf6a", 12) },
  subtitle: { color: L.mist, fontSize: 12, marginTop: 2, fontFamily: F.body },
  card: {
    backgroundColor: "rgba(30,35,82,0.78)", borderRadius: 18, borderWidth: 1.2, borderColor: "rgba(246,211,138,0.5)",
    padding: 16, gap: 8, overflow: "hidden", elevation: 6,
    shadowColor: "#02030f", shadowOpacity: 0.5, shadowRadius: 12, shadowOffset: { width: 0, height: 6 },
  },
  cardSheen: { position: "absolute", left: 0, right: 0, top: 0, height: 40, backgroundColor: "rgba(255,255,255,0.06)" },
  cardRim: { position: "absolute", left: 2, right: 2, top: 2, bottom: 2, borderRadius: 16, borderWidth: 1, borderColor: "rgba(127,231,255,0.16)" },
  sectionHead: { flexDirection: "row", alignItems: "center", gap: 8 },
  diamond: { width: 8, height: 8, backgroundColor: L.goldPale, transform: [{ rotate: "45deg" }] },
  section: { color: L.goldPale, fontSize: 13, letterSpacing: 2.4, fontFamily: F.title, ...titleGlow("#ffcf6a", 8) },
  hairline: { flex: 1, height: 1, backgroundColor: "rgba(246,211,138,0.3)" },
  note: { color: L.mist, fontSize: 11.5, fontFamily: F.body },
  pill: { paddingHorizontal: 16, minHeight: 38, borderRadius: 19, alignItems: "center", justifyContent: "center", borderWidth: 1.5, overflow: "hidden", elevation: 4 },
  pillSheen: { position: "absolute", left: 6, right: 6, top: 2, height: "42%", borderRadius: 14, backgroundColor: "rgba(255,255,255,0.45)" },
  pillDeep: { position: "absolute", left: 0, right: 0, bottom: 0, height: "40%", backgroundColor: "#b8741e", opacity: 0.55 },
  pillTxt: { fontSize: 12.5, letterSpacing: 1.4, fontFamily: F.title },
  reward: { color: L.goldPale, fontSize: 12.5, fontFamily: F.bodyStrong },
  h: { color: L.ivory, fontSize: 16, fontFamily: F.bodyStrong },
  p: { color: L.mist, fontSize: 13.5, lineHeight: 20, fontFamily: F.body },
  err: { color: L.danger, fontSize: 13, textAlign: "center", fontFamily: F.bodyStrong },
});
