// Shared building blocks for the meta-game screens, in the LUMINOUS FANTASY style
// (Figma › Luminous v2 › "Menu template"). Heavy GPU effects (Skia) are reserved for hero pieces;
// list cards and pills use a light-weight look-alike so long lists stay smooth on mid-range phones.
import { useEffect, type ReactNode } from "react";
import { Pressable, ScrollView, StyleSheet, Text, TextInput, View, type TextInputProps, type ViewStyle } from "react-native";
import { useRouter } from "expo-router";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import Animated, { Easing, interpolateColor, useAnimatedStyle, useSharedValue, withSpring, withTiming } from "react-native-reanimated";
import { describeReward } from "../meta/core";
import type { Reward } from "../meta/types";
import { metaStore } from "../state/meta";
import { useStore } from "../state/store";
import { Capsule, Gem, NightSky, Rise, useLoop } from "./lux/Lux";
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
          <Text style={[k.title, right && title.length > 10 ? k.titleTight : null]} numberOfLines={right ? 2 : 1}>{title.toUpperCase()}</Text>
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
  // the dim for `disabled` lives inside the animated style: a static opacity beside it is overridden
  const dim = disabled ? 0.45 : 1;
  const st = useAnimatedStyle(() => ({ transform: [{ scale: 1 - p.value * 0.045 }], opacity: dim * (1 - p.value * 0.12) }));
  return (
    <Animated.View style={st}>
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

export const Section = ({ title, children, note }: { title: string; children: ReactNode; note?: string }) => {
  const long = !!note && note.length > 22;
  return (
    <View style={{ gap: 10 }}>
      <View>
        <View style={k.sectionHead}>
          <View style={k.diamond} />
          <Text style={k.section} numberOfLines={1}>{title.toUpperCase()}</Text>
          <View style={k.hairline} />
          {note && !long ? <Text style={k.note}>{note}</Text> : null}
        </View>
        {long ? <Text style={[k.note, { marginLeft: 16, marginTop: 3 }]}>{note}</Text> : null}
      </View>
      {children}
    </View>
  );
};

/**
 * Progress: the liquid-light meter, drawn with plain views (lists hold dozens of these, and every Skia
 * canvas is a WebGL context on web – browsers cap them at ~16). The fill pours in, a shimmer travels
 * across it and a spark rides its head; the hero Skia `Meter` stays for the HUD and loading veil.
 */
export function Bar({ value, color = L.gold, height = 6 }: { value: number; color?: string; height?: number }) {
  const gold = color === L.gold;
  const [a, b] = gold ? [L.gold, L.goldLight] : [L.aether, color];
  const h = Math.max(6, height);
  const v = useSharedValue(0);
  const shimmer = useLoop(2400);
  useEffect(() => {
    v.value = withTiming(Math.max(0, Math.min(1, value)), { duration: 650, easing: Easing.out(Easing.cubic) });
  }, [value, v]);
  const fill = useAnimatedStyle(() => ({ width: `${Math.max(4, v.value * 100)}%` }));
  const shine = useAnimatedStyle(() => ({ left: `${-30 + shimmer.value * 160}%` }));
  return (
    <View style={[k.barTrack, { height: h + 4, borderRadius: (h + 4) / 2 }]}>
      <Animated.View style={[k.barFill, { height: h, borderRadius: h / 2, backgroundColor: a }, fill]}>
        <View style={[k.barTop, { backgroundColor: b, borderRadius: h / 2 }]} />
        <Animated.View style={[k.barShine, shine]} />
        <View style={[k.barHead, { width: h + 2, height: h + 2, borderRadius: (h + 2) / 2, marginTop: -1, shadowColor: b }]} />
      </Animated.View>
    </View>
  );
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

/** Tab / filter chip: the active one fills with gold and springs; the rest are night glass. */
export function Chip({ label, active, onPress, testID }: { label: string; active: boolean; onPress: () => void; testID?: string }) {
  const a = useSharedValue(active ? 1 : 0);
  useEffect(() => {
    a.value = withSpring(active ? 1 : 0, { damping: 12, stiffness: 220 });
  }, [active, a]);
  const st = useAnimatedStyle(() => ({
    backgroundColor: interpolateColor(a.value, [0, 1], ["rgba(30,35,82,0.85)", L.gold]),
    borderColor: interpolateColor(a.value, [0, 1], ["rgba(246,211,138,0.35)", L.goldLight]),
    transform: [{ scale: 1 + a.value * 0.04 }],
  }));
  return (
    <PressSpring testID={testID} accessibilityLabel={label} onPress={onPress}>
      <Animated.View style={[k.chip, st]}>
        {active && <View style={k.chipSheen} pointerEvents="none" />}
        <Text style={[k.chipTxt, { color: active ? L.ink : L.mist }]} numberOfLines={1}>{label.toUpperCase()}</Text>
      </Animated.View>
    </PressSpring>
  );
}

/** A row of Chips (wraps). */
export function Tabs<T extends string>({ items, value, onChange, labels }: { items: readonly T[]; value: T; onChange: (t: T) => void; labels?: Partial<Record<T, string>> }) {
  return (
    <View style={{ flexDirection: "row", flexWrap: "wrap", gap: 8 }}>
      {items.map((t) => (
        <Chip key={t} label={labels?.[t] ?? t} active={t === value} onPress={() => onChange(t)} />
      ))}
    </View>
  );
}

/** Gold crystal toggle: the knob springs across and the track fills with light. */
export function Toggle({ value, onChange, accessibilityLabel }: { value: boolean; onChange: (v: boolean) => void; accessibilityLabel?: string }) {
  const v = useSharedValue(value ? 1 : 0);
  useEffect(() => {
    v.value = withSpring(value ? 1 : 0, { damping: 13, stiffness: 260 });
  }, [value, v]);
  const track = useAnimatedStyle(() => ({
    backgroundColor: interpolateColor(v.value, [0, 1], ["rgba(7,9,32,0.9)", "rgba(224,169,74,0.55)"]),
    borderColor: interpolateColor(v.value, [0, 1], ["rgba(246,211,138,0.35)", L.goldLight]),
  }));
  const knob = useAnimatedStyle(() => ({
    transform: [{ translateX: v.value * 22 }],
    backgroundColor: interpolateColor(v.value, [0, 1], ["#8a8fb0", L.goldLight]),
    shadowOpacity: v.value,
  }));
  return (
    <Pressable
      accessibilityRole="switch"
      accessibilityLabel={accessibilityLabel}
      accessibilityState={{ checked: value }}
      onPress={() => onChange(!value)}
      hitSlop={8}
    >
      <Animated.View style={[k.toggle, track]}>
        <Animated.View style={[k.knob, knob]} />
      </Animated.View>
    </Pressable>
  );
}

/** A settings-style row: title, hint and a trailing control. */
export const OptionRow = ({ label, hint, children }: { label: string; hint?: string; children?: ReactNode }) => (
  <View style={k.option}>
    <View style={{ flex: 1 }}>
      <Text style={k.optLabel}>{label}</Text>
      {hint ? <Text style={k.optHint}>{hint}</Text> : null}
    </View>
    {children}
  </View>
);

/** Night-glass text field with a gold underline glow. */
export function Field(props: TextInputProps) {
  return <TextInput placeholderTextColor={L.mistDim} {...props} style={[k.field, props.style]} />;
}

/** A labelled number tile (profile stats, ranks). */
export const Stat = ({ label, value, tone = L.ivory }: { label: string; value: string | number; tone?: string }) => (
  <View style={k.stat}>
    <Text style={[k.statVal, { color: tone }, String(value).length > 9 && { fontSize: 12.5, fontFamily: F.bodyStrong }]} numberOfLines={2}>{value}</Text>
    <Text style={k.statLabel}>{label.toUpperCase()}</Text>
  </View>
);

/** Small Cinzel caps label. */
export const Label = ({ children, color = L.goldPale }: { children: ReactNode; color?: string }) => <Text style={[k.label, { color }]}>{children}</Text>;

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
  titleTight: { fontSize: 18, lineHeight: 22, letterSpacing: 2 },
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
  section: { flexShrink: 0, color: L.goldPale, fontSize: 13, letterSpacing: 2.4, fontFamily: F.title, ...titleGlow("#ffcf6a", 8) },
  hairline: { flex: 1, minWidth: 16, height: 1, backgroundColor: "rgba(246,211,138,0.3)" },
  note: { color: L.mist, fontSize: 11.5, fontFamily: F.body },
  pill: { paddingHorizontal: 16, minHeight: 38, borderRadius: 19, alignItems: "center", justifyContent: "center", borderWidth: 1.5, overflow: "hidden", elevation: 4 },
  pillSheen: { position: "absolute", left: 6, right: 6, top: 2, height: "42%", borderRadius: 14, backgroundColor: "rgba(255,255,255,0.45)" },
  pillDeep: { position: "absolute", left: 0, right: 0, bottom: 0, height: "40%", backgroundColor: "#b8741e", opacity: 0.55 },
  pillTxt: { fontSize: 12.5, letterSpacing: 1.4, fontFamily: F.title },
  reward: { color: L.goldPale, fontSize: 12.5, fontFamily: F.bodyStrong },
  h: { color: L.ivory, fontSize: 16, fontFamily: F.bodyStrong },
  p: { color: L.mist, fontSize: 13.5, lineHeight: 20, fontFamily: F.body },
  barTrack: { justifyContent: "center", paddingHorizontal: 2, backgroundColor: "rgba(7,9,32,0.92)", borderWidth: 1, borderColor: "rgba(246,211,138,0.45)" },
  barFill: { overflow: "hidden", flexDirection: "row", justifyContent: "flex-end", alignItems: "center" },
  barTop: { position: "absolute", left: 0, right: 0, top: 0, height: "50%", opacity: 0.55 },
  barShine: { position: "absolute", top: 0, bottom: 0, width: "22%", backgroundColor: "rgba(255,255,255,0.35)", transform: [{ skewX: "-20deg" }] },
  barHead: { backgroundColor: "#ffffff", shadowRadius: 6, shadowOpacity: 1, shadowOffset: { width: 0, height: 0 } },
  chip: { paddingVertical: 7, paddingHorizontal: 14, borderRadius: 16, borderWidth: 1.2, overflow: "hidden" },
  chipSheen: { position: "absolute", left: 4, right: 4, top: 1, height: "45%", borderRadius: 12, backgroundColor: "rgba(255,255,255,0.4)" },
  chipTxt: { fontSize: 11, letterSpacing: 1.4, fontFamily: F.title },
  toggle: { width: 50, height: 28, borderRadius: 14, borderWidth: 1.2, padding: 2, justifyContent: "center" },
  knob: { width: 22, height: 22, borderRadius: 11, shadowColor: "#ffcf6a", shadowRadius: 8, shadowOffset: { width: 0, height: 0 }, borderWidth: 1, borderColor: "rgba(255,255,255,0.6)" },
  option: { flexDirection: "row", alignItems: "center", gap: 12, paddingVertical: 12, borderBottomWidth: 1, borderBottomColor: "rgba(246,211,138,0.16)" },
  optLabel: { color: L.ivory, fontSize: 15, fontFamily: F.bodyStrong },
  optHint: { color: L.mist, fontSize: 12, marginTop: 2, fontFamily: F.body, lineHeight: 17 },
  field: {
    color: L.ivory, fontSize: 17, fontFamily: F.bodyStrong, paddingVertical: 6, paddingHorizontal: 10, borderRadius: 10,
    backgroundColor: "rgba(7,9,32,0.6)", borderWidth: 1, borderColor: "rgba(246,211,138,0.3)", borderBottomColor: L.goldPale, borderBottomWidth: 1.5,
  },
  stat: { width: "33.3%", paddingVertical: 8, paddingHorizontal: 4, alignItems: "center" },
  statVal: { fontSize: 18, fontFamily: F.number, textAlign: "center" },
  statLabel: { color: L.mist, fontSize: 8.5, letterSpacing: 1.2, fontFamily: F.title, textAlign: "center", marginTop: 1 },
  label: { fontSize: 10.5, letterSpacing: 2, fontFamily: F.title },
  err: { color: L.danger, fontSize: 13, textAlign: "center", fontFamily: F.bodyStrong },
});
