// HOME — luminous fantasy (Figma › Luminous v2 › "Home v2"). The Keeper stands before the island
// they are restoring: a floating isle turning under a portal ring, notices as glass rows, a rail of
// glowing orbs, and the gold PLAY crystal.
import { useEffect, useMemo, useState } from "react";
import { ActivityIndicator, Pressable, StyleSheet, Text, View } from "react-native";
import { useRouter, type Href } from "expo-router";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import Animated, { Easing, useAnimatedStyle, useDerivedValue, useSharedValue, withRepeat, withTiming } from "react-native-reanimated";
import { BlurMask, Canvas, Circle, Group, LinearGradient, Oval, Path, RadialGradient, Skia, vec } from "@shopify/react-native-skia";
import { ISLANDS } from "@/src/meta/config/world";
import { isUnlocked, keeperLevel, pendingReveals } from "@/src/meta/core";
import { keeperBriefing, nextObjective, type BriefingItem } from "@/src/meta/live";
import { claimKeepersReturn, islandStatus } from "@/src/meta/progression";
import { keeperRank } from "@/src/meta/rank";
import { act, loadKeeper, markFeatureSeen, metaStore } from "@/src/state/meta";
import { useStore } from "@/src/state/store";
import { Wallet, PressSpring } from "@/src/ui/kit";
import { LuxButton, Meter, NightSky, Rise, useLoop } from "@/src/ui/lux/Lux";
import { F, L, REALM_LIGHT, titleGlow } from "@/src/ui/lux/tokens";
import { NameKeeper } from "@/src/ui/NameKeeper";
import { LEVELS } from "@/src/game/level";

const RAIL: { feature: string; label: string; href: Href; glyph: string; color: string }[] = [
  { feature: "story", label: "Map", href: "/realms", glyph: "◈", color: L.crystal },
  { feature: "sanctuary", label: "Sanctuary", href: "/sanctuary", glyph: "⌂", color: "#8cf5a0" },
  { feature: "archive", label: "Archive", href: "/archive", glyph: "❖", color: "#c8a0ff" },
  { feature: "duties", label: "Duties", href: "/duties", glyph: "✓", color: L.goldPale },
  { feature: "trials", label: "Trials", href: "/trials", glyph: "⚑", color: L.rose },
  { feature: "season", label: "Pass", href: "/pass", glyph: "✦", color: "#ffd08a" },
  { feature: "store", label: "Armory", href: "/store", glyph: "⚔", color: "#ff9070" },
  { feature: "exchange", label: "Exchange", href: "/exchange", glyph: "⇄", color: L.aether },
];

/** The hero: the island being restored, floating and turning under its portal. */
function HeroIsland({ realm }: { realm: string }) {
  const W = 300, H = 280, cx = W / 2;
  const [bright, deep] = REALM_LIGHT[realm] ?? REALM_LIGHT.verdant;
  const bob = useSharedValue(0);
  useEffect(() => {
    bob.value = withRepeat(withTiming(1, { duration: 4200, easing: Easing.inOut(Easing.sin) }), -1, true);
  }, [bob]);
  const float = useAnimatedStyle(() => ({ transform: [{ translateY: -8 + bob.value * 16 }] }));
  const spin = useLoop(16000);
  const pulse = useLoop(2600);
  const ring = useDerivedValue(() => [{ rotate: spin.value * Math.PI * 2 }], [spin]);
  const coreR = useDerivedValue(() => 24 + Math.sin(pulse.value * Math.PI * 2) * 4);
  const glowOp = useDerivedValue(() => 0.55 + Math.sin(pulse.value * Math.PI * 2) * 0.25);
  const underside = useMemo(() => {
    const p = Skia.Path.Make();
    p.moveTo(cx - 118, 170);
    p.cubicTo(cx - 90, 205, cx - 50, 250, cx - 6, 272);
    p.cubicTo(cx + 20, 250, cx + 70, 214, cx + 118, 170);
    p.close();
    return p;
  }, [cx]);
  const trees = useMemo(() => {
    const p = Skia.Path.Make();
    [[-86, 0], [-54, 6], [-24, -2], [28, 4], [60, -4], [90, 4]].forEach(([dx, dy]) => {
      p.moveTo(cx + dx, 136 + dy);
      p.lineTo(cx + dx + 12, 168 + dy);
      p.lineTo(cx + dx - 12, 168 + dy);
      p.close();
    });
    return p;
  }, [cx]);
  const motes = useMemo(() => Array.from({ length: 8 }, (_, i) => i / 8), []);
  return (
    <Animated.View style={[{ width: W, height: H, alignSelf: "center" }, float]} pointerEvents="none">
      <Canvas style={{ width: W, height: H }}>
        <Circle cx={cx} cy={120} r={140}>
          <RadialGradient c={vec(cx, 120)} r={140} colors={[L.crystal + "44", "transparent"]} />
        </Circle>
        <Path path={underside}>
          <LinearGradient start={vec(cx, 170)} end={vec(cx, 272)} colors={["#3a3a72", "rgba(11,14,36,0.2)"]} />
        </Path>
        <Oval x={cx - 122} y={148} width={244} height={46}>
          <LinearGradient start={vec(cx, 148)} end={vec(cx, 194)} colors={[bright, deep]} />
        </Oval>
        <Oval x={cx - 122} y={148} width={244} height={46} style="stroke" strokeWidth={2} color={bright} opacity={0.5}>
          <BlurMask blur={6} style="normal" />
        </Oval>
        <Path path={trees} color={deep} />
        {/* portal ring with a turning dashed rune circle */}
        <Circle cx={cx} cy={96} r={46} style="stroke" strokeWidth={9}>
          <LinearGradient start={vec(cx, 50)} end={vec(cx, 142)} colors={["#efe4c8", "#7a6a5a"]} />
        </Circle>
        <Group origin={vec(cx, 96)} transform={ring}>
          {Array.from({ length: 12 }, (_, i) => {
            const a = (i / 12) * Math.PI * 2;
            return <Circle key={i} cx={cx + Math.cos(a) * 58} cy={96 + Math.sin(a) * 58} r={2.2} color={L.goldPale} opacity={0.8} />;
          })}
        </Group>
        <Group opacity={glowOp}>
          <Circle cx={cx} cy={96} r={40} color={L.crystal}>
            <BlurMask blur={22} style="normal" />
          </Circle>
        </Group>
        <Circle cx={cx} cy={96} r={coreR}>
          <RadialGradient c={vec(cx, 96)} r={30} colors={["#ffffff", L.crystal, "rgba(63,184,255,0)"]} positions={[0, 0.45, 1]} />
        </Circle>
        {motes.map((o, i) => (
          <OrbitMote key={i} cx={cx} cy={120} phase={spin} offset={o} />
        ))}
      </Canvas>
    </Animated.View>
  );
}

function OrbitMote({ cx, cy, phase, offset }: { cx: number; cy: number; phase: { value: number }; offset: number }) {
  const x = useDerivedValue(() => cx + Math.cos((phase.value * 2 + offset) * Math.PI * 2) * 130);
  const y = useDerivedValue(() => cy + Math.sin((phase.value * 2 + offset) * Math.PI * 2) * 34);
  const op = useDerivedValue(() => 0.35 + Math.sin((phase.value * 2 + offset) * Math.PI * 2) * 0.5);
  return (
    <Group opacity={op}>
      <Circle cx={x} cy={y} r={5} color={L.goldPale}>
        <BlurMask blur={4} style="normal" />
      </Circle>
      <Circle cx={x} cy={y} r={1.6} color="#ffffff" />
    </Group>
  );
}

/** A glowing orb on the right rail. */
function RailOrb({ glyph, label, color, badge, onPress, testID }: { glyph: string; label: string; color: string; badge?: boolean; onPress: () => void; testID?: string }) {
  return (
    <PressSpring testID={testID} accessibilityLabel={label} onPress={onPress} style={s.orbWrap}>
      <View style={[s.orb, { shadowColor: color }]}>
        <View style={[s.orbCore, { backgroundColor: color, opacity: 0.22 }]} />
        <Text style={[s.orbGlyph, { color }, titleGlow(color, 8)]}>{glyph}</Text>
      </View>
      <Text style={s.orbLabel}>{label.toUpperCase()}</Text>
      {badge && <View style={s.orbBadge} />}
    </PressSpring>
  );
}

export default function Home() {
  const router = useRouter();
  const insets = useSafeAreaInsets();
  const player = useStore(metaStore, (m) => m.player);
  // the hero island shrinks to the room the notices leave it, instead of spilling over the title
  const [heroRoom, setHeroRoom] = useState(280);

  useEffect(() => {
    loadKeeper();
  }, []);

  if (!player) {
    return (
      <View style={[s.root, { justifyContent: "center", alignItems: "center" }]}>
        <NightSky />
        <ActivityIndicator color={L.goldPale} />
      </View>
    );
  }

  const now = Date.now();
  const lvl = keeperLevel(player.keeperXp);
  const rank = keeperRank(player);
  const briefing = keeperBriefing(player, now).slice(0, 3);
  const reveal = pendingReveals(player).find((f) => f.feature !== "story");
  const next = ISLANDS.find((i) => islandStatus(player, i, now).status === "available" && !player.islands[i.id]) ?? ISLANDS.find((i) => player.islands[i.id]);
  const nextLevel = next ? LEVELS[next.levelIndex] : undefined;
  const playIsland = () => next && router.push({ pathname: "/play", params: { island: next.id } });

  const onBrief = (b: BriefingItem) => {
    const routes: Partial<Record<BriefingItem["kind"], Href>> = {
      sanctuary: "/sanctuary", duties: "/duties", quest: "/duties", achievement: "/profile", trial: "/trials", pass: "/pass", event: "/pass", portal: "/realms",
    };
    if (b.kind === "return") act((p, t) => claimKeepersReturn(p, t), ["daily_checkin", { streak: player.checkin.streak + 1 }]);
    else if (b.kind === "story") playIsland();
    else if (routes[b.kind]) router.push(routes[b.kind]!);
  };
  const briefColor = (k: BriefingItem["kind"]) => (k === "return" ? L.goldPale : k === "story" || k === "portal" ? L.crystal : k === "trial" ? L.rose : L.gold);

  return (
    <View style={s.root}>
      <NightSky />
      <View style={{ flex: 1, paddingTop: insets.top + 10, paddingBottom: insets.bottom + 14 }}>
        {/* Keeper identity + wallet */}
        <View style={s.top}>
          <PressSpring accessibilityLabel="Keeper profile" onPress={() => isUnlocked(player, "achievements") && router.push("/profile")} style={s.keeper}>
            <View style={s.avatar}>
              <Text style={s.avatarTxt}>{player.profile.keeperName[0]}</Text>
            </View>
            <View style={{ gap: 3, width: 110 }}>
              <Text style={s.rank} numberOfLines={1}>{rank.name}</Text>
              <Meter value={lvl.progress} height={5} colors={[L.gold, L.goldLight]} />
            </View>
          </PressSpring>
          <Wallet />
        </View>

        <View style={s.titleBlock}>
          <Text style={s.title}>CRYSTALS</Text>
          <Text style={s.titleAr}>— A R —</Text>
          <Text style={s.objective}>{nextObjective(player, now)}</Text>
        </View>

        <View style={{ flex: 1, justifyContent: "center", alignItems: "center" }} onLayout={(e) => setHeroRoom(e.nativeEvent.layout.height)}>
          <View style={{ transform: [{ scale: Math.max(0.45, Math.min(1, heroRoom / 280)) }] }}>
            <HeroIsland realm={nextLevel?.realm ?? "verdant"} />
          </View>
        </View>

        {/* right rail */}
        <View style={[s.rail, { top: insets.top + 196 }]}>
          {RAIL.filter((n) => isUnlocked(player, n.feature)).map((n) => (
            <RailOrb key={n.label} testID={`nav-${n.label}`} glyph={n.glyph} label={n.label} color={n.color}
              badge={!player.seenFeatures.includes(n.feature) && n.feature !== "story"}
              onPress={() => { markFeatureSeen(n.feature); router.push(n.href); }} />
          ))}
          <RailOrb testID="settings" glyph="⚙" label="Settings" color={L.mist} onPress={() => router.push("/settings")} />
        </View>

        {/* notices */}
        <View style={{ gap: 8, paddingHorizontal: 18, marginBottom: 14 }}>
          <NameKeeper />
          {reveal && (
            <Rise>
              <PressSpring style={[s.brief, { borderColor: L.goldPale }]} onPress={() => {
                markFeatureSeen(reveal.feature);
                const nav = RAIL.find((n) => n.feature === reveal.feature);
                if (nav) router.push(nav.href);
              }}>
                <Text style={s.briefNew}>NEW</Text>
                <Text style={s.briefTxt}><Text style={{ fontFamily: F.bold }}>{reveal.name}</Text> – {reveal.blurb}</Text>
              </PressSpring>
            </Rise>
          )}
          {briefing.map((b, i) => (
            <Rise key={b.id} delay={120 + i * 90}>
              <PressSpring testID={`brief-${b.kind}`} style={[s.brief, { borderColor: briefColor(b.kind) + "88" }]} onPress={() => onBrief(b)}>
                <View style={[s.briefDot, { backgroundColor: briefColor(b.kind), shadowColor: briefColor(b.kind) }]} />
                <Text style={s.briefTxt} numberOfLines={2}>{b.text}</Text>
              </PressSpring>
            </Rise>
          ))}
        </View>

        <View style={{ paddingHorizontal: 30 }}>
          <LuxButton testID="play" hero label={next && player.islands[next.id] ? "PLAY AGAIN" : "PLAY"} onPress={playIsland} />
          {nextLevel && <Text style={s.nextName}>{player.islands[next!.id] ? "Return to" : "Next:"} {nextLevel.label ?? `Level ${nextLevel.id}`} · {next!.name}</Text>}
        </View>
      </View>
    </View>
  );
}

const s = StyleSheet.create({
  root: { flex: 1, backgroundColor: L.night900 },
  top: { flexDirection: "row", alignItems: "center", justifyContent: "space-between", paddingHorizontal: 14 },
  keeper: { flexDirection: "row", alignItems: "center", gap: 10 },
  avatar: {
    width: 46, height: 46, borderRadius: 23, backgroundColor: "#2a2070", borderWidth: 2.5, borderColor: L.gold, alignItems: "center", justifyContent: "center",
    shadowColor: "#ffcf6a", shadowOpacity: 0.7, shadowRadius: 10, elevation: 8,
  },
  avatarTxt: { color: L.goldPale, fontSize: 20, fontFamily: F.display },
  rank: { color: L.goldPale, fontSize: 13, fontFamily: F.title, letterSpacing: 1 },
  titleBlock: { alignItems: "center", marginTop: 26 },
  title: { color: L.goldLight, fontSize: 46, letterSpacing: 8, fontFamily: F.display, ...titleGlow("#ffcf6a", 22) },
  titleAr: { color: L.crystal, fontSize: 14, letterSpacing: 10, fontFamily: F.title, marginTop: -2, ...titleGlow(L.crystal, 10) },
  objective: { color: "#e8e2f4", fontSize: 14, marginTop: 12, fontFamily: F.body, textAlign: "center", paddingHorizontal: 40 },
  rail: { position: "absolute", right: 8, gap: 10, alignItems: "center" },
  orbWrap: { alignItems: "center", width: 62 },
  orb: {
    width: 44, height: 44, borderRadius: 22, backgroundColor: "rgba(11,14,36,0.9)", borderWidth: 1.5, borderColor: L.goldPale,
    alignItems: "center", justifyContent: "center", overflow: "hidden", shadowOpacity: 0.9, shadowRadius: 10, elevation: 7,
  },
  orbCore: { position: "absolute", width: 44, height: 44, borderRadius: 22 },
  orbGlyph: { fontSize: 19, fontFamily: F.bold },
  orbLabel: { color: "#e8e2f4", fontSize: 8, letterSpacing: 1, marginTop: 3, fontFamily: F.bodyStrong },
  orbBadge: { position: "absolute", top: 0, right: 10, width: 10, height: 10, borderRadius: 5, backgroundColor: L.rose, borderWidth: 1.5, borderColor: "#fff" },
  brief: {
    flexDirection: "row", gap: 12, alignItems: "center", paddingVertical: 12, paddingHorizontal: 14, borderRadius: 16,
    backgroundColor: "rgba(20,26,61,0.82)", borderWidth: 1, marginRight: 64,
  },
  briefDot: { width: 10, height: 10, borderRadius: 5, shadowOpacity: 1, shadowRadius: 6, elevation: 4 },
  briefNew: { color: L.ink, backgroundColor: L.goldPale, fontSize: 10, fontFamily: F.number, paddingHorizontal: 7, paddingVertical: 2, borderRadius: 6, overflow: "hidden" },
  briefTxt: { color: L.ivory, fontSize: 13, flex: 1, fontFamily: F.bodyStrong },
  nextName: { color: L.mist, fontSize: 12, textAlign: "center", marginTop: 10, fontFamily: F.body },
});
