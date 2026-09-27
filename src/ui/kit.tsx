// Shared building blocks for meta-game screens. Calm, dark, in-world – no store-card clutter.
import type { ReactNode } from "react";
import { Pressable, ScrollView, StyleSheet, Text, View, type ViewStyle } from "react-native";
import { useRouter } from "expo-router";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import { describeReward } from "../meta/core";
import type { Reward } from "../meta/types";
import { metaStore } from "../state/meta";
import { useStore } from "../state/store";
import { C, font } from "./theme";

export function Screen({ title, subtitle, children, right }: { title: string; subtitle?: string; children: ReactNode; right?: ReactNode }) {
  const router = useRouter();
  const insets = useSafeAreaInsets();
  return (
    <View style={{ flex: 1, backgroundColor: C.bg }}>
      <View style={[k.header, { paddingTop: insets.top + 10 }]}>
        <Pressable accessibilityRole="button" accessibilityLabel="Back" onPress={() => (router.canGoBack() ? router.back() : router.replace("/"))} hitSlop={12} style={k.back}>
          <Text style={k.backTxt}>‹</Text>
        </Pressable>
        <View style={{ flex: 1 }}>
          <Text style={k.title}>{title}</Text>
          {subtitle ? <Text style={k.subtitle}>{subtitle}</Text> : null}
        </View>
        {right}
      </View>
      <ScrollView contentContainerStyle={{ padding: 16, paddingBottom: insets.bottom + 32, gap: 14 }}>{children}</ScrollView>
    </View>
  );
}

export function Wallet() {
  const w = useStore(metaStore, (m) => m.player?.wallet);
  if (!w) return null;
  return (
    <View style={{ flexDirection: "row", gap: 10 }}>
      <Text style={k.coin}>✦ {w.prismDust.toLocaleString()}</Text>
      <Text style={[k.coin, { color: C.portal }]}>◆ {w.aether.toLocaleString()}</Text>
    </View>
  );
}

export function Card({ children, style, onPress, testID }: { children: ReactNode; style?: ViewStyle; onPress?: () => void; testID?: string }) {
  if (onPress)
    return (
      <Pressable testID={testID} onPress={onPress} style={({ pressed }) => [k.card, style, pressed && { opacity: 0.8 }]}>
        {children}
      </Pressable>
    );
  return <View style={[k.card, style]}>{children}</View>;
}

export const Section = ({ title, children, note }: { title: string; children: ReactNode; note?: string }) => (
  <View style={{ gap: 8 }}>
    <View style={{ flexDirection: "row", justifyContent: "space-between", alignItems: "baseline" }}>
      <Text style={k.section}>{title}</Text>
      {note ? <Text style={k.note}>{note}</Text> : null}
    </View>
    {children}
  </View>
);

export function Bar({ value, color = C.gold, height = 6 }: { value: number; color?: string; height?: number }) {
  return (
    <View style={{ height, borderRadius: height, backgroundColor: "rgba(255,255,255,0.1)", overflow: "hidden" }}>
      <View style={{ width: `${Math.max(0, Math.min(1, value)) * 100}%`, height, backgroundColor: color, borderRadius: height }} />
    </View>
  );
}

export function Pill({ label, onPress, disabled, tone = "gold", testID }: { label: string; onPress?: () => void; disabled?: boolean; tone?: "gold" | "ghost" | "portal"; testID?: string }) {
  const bg = tone === "gold" ? C.gold : tone === "portal" ? C.portal : "rgba(255,255,255,0.08)";
  return (
    <Pressable
      testID={testID}
      accessibilityRole="button"
      accessibilityLabel={label}
      disabled={disabled || !onPress}
      onPress={onPress}
      style={({ pressed }) => [k.pill, { backgroundColor: bg, opacity: disabled ? 0.4 : pressed ? 0.8 : 1 }]}
    >
      <Text style={[k.pillTxt, tone === "ghost" && { color: C.ink }]}>{label}</Text>
    </Pressable>
  );
}

export const RewardLine = ({ reward, dim }: { reward: Reward; dim?: boolean }) => (
  <Text style={[k.reward, dim && { opacity: 0.6 }]} numberOfLines={2}>
    {describeReward(reward).join(" · ") || "—"}
  </Text>
);

export const Row = ({ children, style }: { children: ReactNode; style?: ViewStyle }) => (
  <View style={[{ flexDirection: "row", alignItems: "center", gap: 10 }, style]}>{children}</View>
);

export const T = {
  h: (t: string) => <Text style={k.h}>{t}</Text>,
  p: (t: string, dim = false) => <Text style={[k.p, dim && { color: C.inkFaint }]}>{t}</Text>,
};

/** Transient feedback line for failed actions ("Not enough Prism Dust"). */
export const ErrorLine = ({ msg }: { msg: string | null }) => (msg ? <Text style={k.err}>{msg}</Text> : null);

export const k = StyleSheet.create({
  header: { flexDirection: "row", alignItems: "center", gap: 10, paddingHorizontal: 12, paddingBottom: 10, borderBottomWidth: StyleSheet.hairlineWidth, borderBottomColor: C.line },
  back: { width: 36, height: 36, alignItems: "center", justifyContent: "center" },
  backTxt: { color: C.ink, fontSize: 30, marginTop: -4 },
  title: { color: C.ink, fontSize: 24, fontFamily: font.display, fontWeight: "700" },
  subtitle: { color: C.inkFaint, fontSize: 12, marginTop: 2 },
  coin: { color: C.gold, fontWeight: "700", fontSize: 14 },
  card: { backgroundColor: "rgba(255,255,255,0.045)", borderRadius: 16, borderWidth: StyleSheet.hairlineWidth, borderColor: C.line, padding: 14, gap: 6 },
  section: { color: C.inkDim, fontSize: 12, letterSpacing: 1.6, textTransform: "uppercase", fontWeight: "700" },
  note: { color: C.inkFaint, fontSize: 12 },
  pill: { paddingHorizontal: 16, minHeight: 38, borderRadius: 19, alignItems: "center", justifyContent: "center" },
  pillTxt: { color: "#1f160a", fontWeight: "800", fontSize: 13, letterSpacing: 1 },
  reward: { color: C.gold, fontSize: 12.5 },
  h: { color: C.ink, fontSize: 16, fontWeight: "700", fontFamily: font.body },
  p: { color: C.inkDim, fontSize: 13.5, lineHeight: 19, fontFamily: font.body },
  err: { color: C.danger, fontSize: 13, textAlign: "center" },
});
