import { useEffect, useRef } from "react";
import { ActivityIndicator, Animated, Easing, Pressable, StyleSheet, Text, View } from "react-native";
import { useRouter, type Href } from "expo-router";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import { ISLANDS } from "@/src/meta/config/world";
import { isUnlocked, keeperLevel, pendingReveals } from "@/src/meta/core";
import { keeperBriefing, nextObjective, type BriefingItem } from "@/src/meta/live";
import { claimKeepersReturn, islandStatus } from "@/src/meta/progression";
import { CRYSTAL_COLORS } from "@/src/render/assets";
import { act, loadKeeper, markFeatureSeen, metaStore } from "@/src/state/meta";
import { useStore } from "@/src/state/store";
import { Button } from "@/src/ui/Button";
import { Bar, Wallet } from "@/src/ui/kit";
import { NameKeeper } from "@/src/ui/NameKeeper";
import { C, font } from "@/src/ui/theme";

/** Slowly drifting facets behind the title – pure RN, no 3D needed on the menu. */
function Facet({ i }: { i: number }) {
  const v = useRef(new Animated.Value(0)).current;
  useEffect(() => {
    Animated.loop(Animated.timing(v, { toValue: 1, duration: 9000 + i * 1700, easing: Easing.inOut(Easing.sin), useNativeDriver: true })).start();
  }, [v, i]);
  const size = 14 + ((i * 37) % 24);
  return (
    <Animated.View
      pointerEvents="none"
      style={{
        position: "absolute", left: `${((i * 23) % 90) + 3}%`, top: `${((i * 41) % 80) + 6}%`, width: size, height: size,
        backgroundColor: CRYSTAL_COLORS[i % 5], borderRadius: 3,
        opacity: v.interpolate({ inputRange: [0, 0.5, 1], outputRange: [0.06, 0.22, 0.06] }),
        transform: [{ rotate: "45deg" }, { translateY: v.interpolate({ inputRange: [0, 1], outputRange: [0, -30] }) }],
      }}
    />
  );
}

const NAV: { feature: string; label: string; href: Href; glyph: string }[] = [
  { feature: "story", label: "Realms", href: "/realms", glyph: "◈" },
  { feature: "sanctuary", label: "Sanctuary", href: "/sanctuary", glyph: "⌂" },
  { feature: "trials", label: "Trials", href: "/trials", glyph: "⚑" },
  { feature: "archive", label: "Archive", href: "/archive", glyph: "❖" },
  { feature: "achievements", label: "Profile", href: "/profile", glyph: "✧" },
];
const SECONDARY: { feature: string; label: string; href: Href }[] = [
  { feature: "duties", label: "Keeper Duties", href: "/duties" },
  { feature: "season", label: "Crystal Pass", href: "/pass" },
  { feature: "exchange", label: "Realm Exchange", href: "/exchange" },
];

export default function Home() {
  const router = useRouter();
  const insets = useSafeAreaInsets();
  const player = useStore(metaStore, (m) => m.player);

  useEffect(() => {
    loadKeeper();
  }, []);

  if (!player) {
    return (
      <View style={[s.root, { justifyContent: "center", alignItems: "center" }]}>
        <ActivityIndicator color={C.gold} />
      </View>
    );
  }

  const now = Date.now();
  const lvl = keeperLevel(player.keeperXp);
  const briefing = keeperBriefing(player, now).slice(0, 3);
  const reveal = pendingReveals(player).find((f) => f.feature !== "story");
  const next = ISLANDS.find((i) => islandStatus(player, i, now).status === "available" && !player.islands[i.id]) ?? ISLANDS.find((i) => player.islands[i.id]);
  const playIsland = () => next && router.push({ pathname: "/play", params: { island: next.id } });

  const onBrief = (b: BriefingItem) => {
    const routes: Partial<Record<BriefingItem["kind"], Href>> = {
      sanctuary: "/sanctuary", duties: "/duties", quest: "/duties", achievement: "/profile", trial: "/trials", pass: "/pass", event: "/pass", portal: "/realms",
    };
    if (b.kind === "return") act((p, t) => claimKeepersReturn(p, t), ["daily_checkin", { streak: player.checkin.streak + 1 }]);
    else if (b.kind === "story") playIsland();
    else if (routes[b.kind]) router.push(routes[b.kind]!);
  };

  return (
    <View style={[s.root, { paddingTop: insets.top + 14, paddingBottom: insets.bottom + 16 }]}>
      {Array.from({ length: 10 }, (_, i) => <Facet key={i} i={i} />)}

      {/* Keeper identity */}
      <Pressable accessibilityRole="button" accessibilityLabel="Keeper profile" onPress={() => isUnlocked(player, "achievements") && router.push("/profile")} style={s.keeper}>
        <View style={s.avatar}><Text style={s.avatarTxt}>{player.profile.keeperName[0]}</Text></View>
        <View style={{ flex: 1, gap: 3 }}>
          <Text style={s.name}>{player.profile.keeperName} <Text style={s.lvl}>· Keeper {lvl.level}</Text></Text>
          <Bar value={lvl.progress} height={4} />
        </View>
        <Wallet />
      </Pressable>

      <View style={s.titleBlock}>
        <Text style={s.title}>CRYSTALS</Text>
        <Text style={s.titleAr}>AR</Text>
        <Text style={s.objective}>{nextObjective(player, now)}</Text>
      </View>

      {/* Keeper Briefing – one calm summary instead of launch pop-ups */}
      <View style={{ gap: 8 }}>
        <NameKeeper />
        {reveal && (
          <Pressable
            style={[s.brief, { borderColor: C.gold }]}
            onPress={() => {
              markFeatureSeen(reveal.feature);
              const nav = [...NAV, ...SECONDARY].find((n) => n.feature === reveal.feature);
              if (nav) router.push(nav.href);
            }}
          >
            <Text style={s.briefNew}>NEW</Text>
            <Text style={s.briefTxt}><Text style={{ fontWeight: "800" }}>{reveal.name}</Text> – {reveal.blurb}</Text>
          </Pressable>
        )}
        {briefing.map((b) => (
          <Pressable key={b.id} testID={`brief-${b.kind}`} style={s.brief} onPress={() => onBrief(b)}>
            <Text style={s.briefDot}>{b.kind === "return" ? "☀" : b.kind === "story" ? "◈" : "•"}</Text>
            <Text style={s.briefTxt}>{b.text}</Text>
          </Pressable>
        ))}
      </View>

      <View style={{ gap: 12 }}>
        <Button testID="play" label={next && player.islands[next.id] ? `REPLAY ${next.name.toUpperCase()}` : "PLAY"} variant="primary" onPress={playIsland} />
        <View style={s.nav}>
          {NAV.filter((n) => isUnlocked(player, n.feature)).map((n) => (
            <Pressable key={n.label} testID={`nav-${n.label}`} accessibilityRole="button" accessibilityLabel={n.label} style={s.navItem} onPress={() => { markFeatureSeen(n.feature); router.push(n.href); }}>
              <Text style={s.navGlyph}>{n.glyph}</Text>
              <Text style={s.navLabel}>{n.label}</Text>
              {!player.seenFeatures.includes(n.feature) && n.feature !== "story" && <View style={s.badge} />}
            </Pressable>
          ))}
        </View>
        <View style={s.secondary}>
          {SECONDARY.filter((n) => isUnlocked(player, n.feature)).map((n) => (
            <Pressable key={n.label} accessibilityRole="button" onPress={() => { markFeatureSeen(n.feature); router.push(n.href); }} hitSlop={8}>
              <Text style={s.link}>{n.label}</Text>
            </Pressable>
          ))}
          <Pressable accessibilityRole="button" testID="settings" onPress={() => router.push("/settings")} hitSlop={8}>
            <Text style={s.link}>Settings</Text>
          </Pressable>
        </View>
      </View>
    </View>
  );
}

const s = StyleSheet.create({
  root: { flex: 1, backgroundColor: C.bg, paddingHorizontal: 18, justifyContent: "space-between" },
  keeper: { flexDirection: "row", alignItems: "center", gap: 10 },
  avatar: { width: 40, height: 40, borderRadius: 20, backgroundColor: "#1d3a2f", borderWidth: 1.5, borderColor: C.gold, alignItems: "center", justifyContent: "center" },
  avatarTxt: { color: C.gold, fontWeight: "800", fontSize: 18, fontFamily: font.display },
  name: { color: C.ink, fontWeight: "700", fontSize: 15 },
  lvl: { color: C.inkFaint, fontWeight: "600" },
  titleBlock: { alignItems: "center" },
  title: { color: C.ink, fontSize: 42, letterSpacing: 10, fontFamily: font.display, fontWeight: "700" },
  titleAr: { color: C.gold, fontSize: 18, letterSpacing: 14, fontWeight: "800", marginTop: -2 },
  objective: { color: C.inkDim, fontSize: 15, marginTop: 14, fontFamily: font.display, fontStyle: "italic", textAlign: "center" },
  brief: { flexDirection: "row", gap: 10, alignItems: "center", padding: 12, borderRadius: 14, backgroundColor: "rgba(255,255,255,0.05)", borderWidth: StyleSheet.hairlineWidth, borderColor: C.line },
  briefDot: { color: C.gold, fontSize: 14, width: 16, textAlign: "center" },
  briefNew: { color: "#1f160a", backgroundColor: C.gold, fontSize: 10, fontWeight: "900", paddingHorizontal: 6, paddingVertical: 2, borderRadius: 6, overflow: "hidden" },
  briefTxt: { color: C.ink, fontSize: 13.5, flex: 1 },
  nav: { flexDirection: "row", justifyContent: "space-around" },
  navItem: { alignItems: "center", gap: 4, minWidth: 56, paddingVertical: 6 },
  navGlyph: { color: C.gold, fontSize: 22 },
  navLabel: { color: C.inkDim, fontSize: 11, letterSpacing: 0.5 },
  badge: { position: "absolute", top: 4, right: 10, width: 8, height: 8, borderRadius: 4, backgroundColor: C.portal },
  secondary: { flexDirection: "row", justifyContent: "center", gap: 18, flexWrap: "wrap" },
  link: { color: C.inkFaint, fontSize: 12.5, letterSpacing: 0.5 },
});
