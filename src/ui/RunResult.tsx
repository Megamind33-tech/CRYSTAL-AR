// RESULTS — luminous fantasy (Figma › Luminous v2 › "Victory / Defeat"). Victory: god-rays turn behind
// the frame, three big stars spring in one after another, the score and reward gems count up, and the
// gold ENTER PORTAL leads on. Defeat: the portal ring flickers and fades, with a stabilize offer.
// One Skia canvas draws the rays/stars (or the fading ring); everything else is RN + Reanimated so
// the results sit comfortably under the browser's WebGL-context cap alongside the 3D scene and HUD.
import { useEffect, useMemo, useState } from "react";
import { ScrollView, StyleSheet, Text, View } from "react-native";
import Animated, { Easing, FadeIn, useAnimatedStyle, useDerivedValue, useSharedValue, withDelay, withSpring, withTiming, type SharedValue } from "react-native-reanimated";
import { BlurMask, Canvas, Circle, Group, LinearGradient, Path, RadialGradient, Skia, SweepGradient, vec } from "@shopify/react-native-skia";
import { devAdProvider } from "../backend/mockBackend";
import { describeReward } from "../meta/core";
import { LUMINS, RELICS } from "../meta/config/collection";
import { ECONOMY } from "../meta/config/live";
import { HEART_SHARDS, MEMORIES, STORY } from "../meta/config/world";
import { stabilizePortal } from "../meta/live";
import { gameEvents, gameStore, stabilizeLevel } from "../state/game";
import { act, analytics, metaStore } from "../state/meta";
import { useStore } from "../state/store";
import { PressSpring } from "./kit";
import { GlassFrame, LuxButton, useLoop } from "./lux/Lux";
import { F, L, titleGlow } from "./lux/tokens";

type Props = { onNext: (() => void) | null; onReplay: () => void; onExit: () => void; ranked: boolean };

/** A number that counts up from zero after `delay` ms (ease-out). */
function useCountUp(target: number, delay: number, ms = 900) {
  const [v, setV] = useState(0);
  useEffect(() => {
    setV(0);
    if (!target) return;
    let id: ReturnType<typeof setInterval> | undefined;
    const t0 = setTimeout(() => {
      const start = Date.now();
      id = setInterval(() => {
        const t = Math.min(1, (Date.now() - start) / ms);
        setV(Math.round(target * (1 - Math.pow(1 - t, 3))));
        if (t >= 1) clearInterval(id);
      }, 33);
    }, delay);
    return () => {
      clearTimeout(t0);
      if (id) clearInterval(id);
    };
  }, [target, delay, ms]);
  return v;
}

function starPath(cx: number, cy: number, r: number) {
  const p = Skia.Path.Make();
  for (let i = 0; i < 10; i++) {
    const a = -Math.PI / 2 + (i * Math.PI) / 5;
    const rr = i % 2 === 0 ? r : r * 0.46;
    const x = cx + Math.cos(a) * rr, y = cy + Math.sin(a) * rr;
    if (i === 0) p.moveTo(x, y);
    else p.lineTo(x, y);
  }
  p.close();
  return p;
}

function raysPath(cx: number, cy: number, r: number, n: number) {
  const p = Skia.Path.Make();
  for (let i = 0; i < n; i++) {
    const a = (i * Math.PI * 2) / n, w = Math.PI / n / 1.6;
    p.moveTo(cx, cy);
    p.lineTo(cx + Math.cos(a - w) * r, cy + Math.sin(a - w) * r);
    p.lineTo(cx + Math.cos(a + w) * r, cy + Math.sin(a + w) * r);
    p.close();
  }
  return p;
}

const CW = 340, CH = 210, CX = CW / 2, CY = 108;
const STARS = [
  { x: CX - 86, y: CY + 14, r: 30 },
  { x: CX, y: CY - 6, r: 42 },
  { x: CX + 86, y: CY + 14, r: 30 },
];

function Star({ x, y, r, k, earned }: { x: number; y: number; r: number; k: SharedValue<number>; earned: boolean }) {
  const tf = useDerivedValue(() => [{ scale: earned ? k.value : 1 }]);
  const glow = useDerivedValue(() => (earned ? Math.min(1, k.value) * 0.85 : 0));
  const outer = useMemo(() => starPath(x, y, r), [x, y, r]);
  const inner = useMemo(() => starPath(x, y - r * 0.06, r * 0.62), [x, y, r]);
  return (
    <Group origin={vec(x, y)} transform={tf}>
      {earned && (
        <Group opacity={glow}>
          <Path path={outer} color="#ffcf6a">
            <BlurMask blur={r * 0.45} style="normal" />
          </Path>
        </Group>
      )}
      <Path path={outer} color="rgba(3,4,18,0.55)" transform={[{ translateY: 4 }]}>
        <BlurMask blur={4} style="normal" />
      </Path>
      <Path path={outer}>
        <LinearGradient
          start={vec(x, y - r)}
          end={vec(x, y + r)}
          colors={earned ? [L.goldLight, L.gold, L.goldDeep] : ["#3a3f70", "#1e2352", "#141a3d"]}
          positions={[0, 0.55, 1]}
        />
      </Path>
      <Path path={inner} color={earned ? "rgba(255,255,255,0.42)" : "rgba(140,146,200,0.18)"} />
      <Path path={outer} style="stroke" strokeWidth={1.6} color={earned ? L.goldLight : "rgba(246,211,138,0.35)"} />
    </Group>
  );
}

/** Victory crown: turning god-rays, a gold bloom, three stars springing in on a stagger. */
function VictoryCrown({ stars }: { stars: number }) {
  const spin = useLoop(24000);
  const breathe = useLoop(3200);
  const bloom = useSharedValue(0);
  const k0 = useSharedValue(0), k1 = useSharedValue(0), k2 = useSharedValue(0);
  const ks = [k0, k1, k2];
  useEffect(() => {
    bloom.value = withTiming(1, { duration: 700, easing: Easing.out(Easing.cubic) });
    [k0, k1, k2].forEach((k, i) => {
      k.value = withDelay(380 + i * 330, withSpring(1, { damping: 7, stiffness: 150 }));
    });
    const ids = Array.from({ length: stars }, (_, i) =>
      setTimeout(() => {
        gameEvents.emit({ type: "haptic", kind: i === 2 ? "success" : "light" });
        gameEvents.emit({ type: "sfx", name: i === 2 ? "special_activate" : "select" });
      }, 420 + i * 330),
    );
    return () => ids.forEach(clearTimeout);
  }, [stars, bloom, k0, k1, k2]);
  const rays = useMemo(() => raysPath(CX, CY, 190, 14), []);
  const rot = useDerivedValue(() => [{ rotate: spin.value * Math.PI * 2 }]);
  const rot2 = useDerivedValue(() => [{ rotate: -spin.value * Math.PI * 2 * 0.6 }]);
  const rayOp = useDerivedValue(() => bloom.value * (0.5 + Math.sin(breathe.value * Math.PI * 2) * 0.12));
  const bloomR = useDerivedValue(() => 40 + bloom.value * 70 + Math.sin(breathe.value * Math.PI * 2) * 6);
  return (
    <Canvas style={r.crown} pointerEvents="none">
      <Group opacity={rayOp}>
        <Group origin={vec(CX, CY)} transform={rot}>
          <Path path={rays}>
            <RadialGradient c={vec(CX, CY)} r={190} colors={["rgba(255,241,184,0.85)", "rgba(246,211,138,0.25)", "rgba(246,211,138,0)"]} positions={[0, 0.45, 1]} />
          </Path>
        </Group>
        <Group origin={vec(CX, CY)} transform={rot2} opacity={0.5}>
          <Path path={rays}>
            <RadialGradient c={vec(CX, CY)} r={150} colors={["rgba(191,244,255,0.7)", "rgba(127,231,255,0)"]} />
          </Path>
        </Group>
      </Group>
      <Circle cx={CX} cy={CY} r={bloomR}>
        <RadialGradient c={vec(CX, CY)} r={110} colors={["rgba(255,241,184,0.75)", "rgba(255,207,106,0.2)", "rgba(255,207,106,0)"]} positions={[0, 0.5, 1]} />
      </Circle>
      {/* side stars first, the crowning centre star lands last */}
      <Star {...STARS[0]} k={ks[0]} earned={stars >= 1} />
      <Star {...STARS[2]} k={ks[1]} earned={stars >= 2} />
      <Star {...STARS[1]} k={ks[2]} earned={stars >= 3} />
    </Canvas>
  );
}

/** Defeat crown: the portal ring gutters – a flickering violet/rose band dimming toward dark. */
function FadingPortal() {
  const t = useLoop(1900);
  const drift = useLoop(6000);
  const fade = useSharedValue(1);
  useEffect(() => {
    fade.value = withTiming(0.45, { duration: 2400, easing: Easing.out(Easing.quad) });
  }, [fade]);
  const ringOp = useDerivedValue(() => fade.value * (0.75 + Math.sin(t.value * Math.PI * 2) * 0.12 + Math.sin(t.value * Math.PI * 14) * 0.08));
  const rot = useDerivedValue(() => [{ rotate: drift.value * Math.PI * 2 }]);
  const shards = useMemo(() => Array.from({ length: 9 }, (_, i) => ({ a: (i / 9) * Math.PI * 2 + 0.3, o: (i * 0.137) % 1 })), []);
  return (
    <Canvas style={r.crown} pointerEvents="none">
      <Circle cx={CX} cy={CY} r={78}>
        <RadialGradient c={vec(CX, CY)} r={78} colors={["rgba(7,9,32,0.95)", "rgba(42,20,80,0.6)", "rgba(42,20,80,0)"]} positions={[0, 0.7, 1]} />
      </Circle>
      <Group opacity={ringOp}>
        <Circle cx={CX} cy={CY} r={62} style="stroke" strokeWidth={14} color={L.violet}>
          <BlurMask blur={14} style="normal" />
        </Circle>
        <Group origin={vec(CX, CY)} transform={rot}>
          <Circle cx={CX} cy={CY} r={62} style="stroke" strokeWidth={5}>
            <SweepGradient c={vec(CX, CY)} colors={[L.rose, L.violet, "rgba(106,75,200,0.1)", L.rose]} />
          </Circle>
        </Group>
      </Group>
      {shards.map((s, i) => (
        <Shard key={i} a={s.a} o={s.o} phase={drift} />
      ))}
    </Canvas>
  );
}

function Shard({ a, o, phase }: { a: number; o: number; phase: SharedValue<number> }) {
  const cx = useDerivedValue(() => CX + Math.cos(a) * (64 + ((phase.value * 3 + o) % 1) * 40));
  const cy = useDerivedValue(() => CY + Math.sin(a) * (64 + ((phase.value * 3 + o) % 1) * 40) + ((phase.value * 3 + o) % 1) * 24);
  const op = useDerivedValue(() => 0.7 * (1 - ((phase.value * 3 + o) % 1)));
  return <Circle cx={cx} cy={cy} r={2.2} color={L.rose} opacity={op} />;
}

/** A reward gem (RN, no canvas): faceted diamond with glow, and its count-up value. */
function RewardGem({ value, label, tone, deep, delay }: { value: number; label: string; tone: string; deep: string; delay: number }) {
  const n = useCountUp(value, delay + 250);
  const p = useSharedValue(0);
  useEffect(() => {
    p.value = withDelay(delay, withSpring(1, { damping: 14, stiffness: 190 }));
  }, [delay, p]);
  const st = useAnimatedStyle(() => ({ opacity: Math.min(1, p.value), transform: [{ scale: 0.5 + p.value * 0.5 }, { translateY: (1 - p.value) * 12 }] }));
  return (
    <Animated.View style={[r.gemBox, st]}>
      <View style={r.gemWrap}>
        <View style={[r.gemGlow, { backgroundColor: tone, shadowColor: tone }]} />
        <View style={[r.gem, { backgroundColor: deep, borderColor: tone }]}>
          <View style={[r.gemTop, { backgroundColor: tone }]} />
          <View style={r.gemShine} />
        </View>
      </View>
      <Text style={[r.gemNum, titleGlow(tone, 8)]}>+{n.toLocaleString()}</Text>
      <Text style={r.gemLabel}>{label}</Text>
    </Animated.View>
  );
}

/** Small glass option for the stabilize offer (RN only). */
function Offer({ glyph, label, tone, onPress }: { glyph: string; label: string; tone: string; onPress: () => void }) {
  return (
    <View style={{ flex: 1 }}>
      <PressSpring accessibilityLabel={label} onPress={onPress} style={[r.offer, { borderColor: tone + "aa" }]}>
        <Text style={[r.offerGlyph, { color: tone }, titleGlow(tone, 8)]}>{glyph}</Text>
        <Text style={r.offerTxt} numberOfLines={1}>{label}</Text>
      </PressSpring>
    </View>
  );
}

/** Victory / failure flow: portal opens → story beat → what emerged → rewards. */
export function RunResult({ onNext, onReplay, onExit, ranked }: Props) {
  const result = useStore(gameStore, (s) => s.result);
  const outcome = useStore(metaStore, (m) => m.lastOutcome);
  const score = useStore(gameStore, (s) => s.hud.score);
  const appear = useSharedValue(0);
  const [show, setShow] = useState(false);
  const [stabs, setStabs] = useState(0);
  const [err, setErr] = useState<string | null>(null);
  const shownScore = useCountUp(show ? score : 0, 200, 1100);

  useEffect(() => {
    if (!result) {
      setShow(false);
      appear.value = 0;
      return;
    }
    const t = setTimeout(() => {
      setShow(true);
      appear.value = 0;
      appear.value = withSpring(1, { damping: 13, stiffness: 120 });
    }, result.won ? 1600 : 500);
    return () => clearTimeout(t);
  }, [result, appear]);

  const panel = useAnimatedStyle(() => ({ opacity: Math.min(1, appear.value * 1.5), transform: [{ translateY: (1 - appear.value) * 40 }, { scale: 0.92 + appear.value * 0.08 }] }));

  if (!result || !show) return null;

  const stabilize = async (via: "prismDust" | "aether" | "ad") => {
    setErr(null);
    if (via === "ad") {
      analytics.track("rewarded_ad_started", { placement: "stabilizePortal" });
      const r = await devAdProvider.showRewarded();
      if (!r.completed) return;
      analytics.track("rewarded_ad_completed", { placement: "stabilizePortal" });
    }
    let moves = 0;
    const e = act((s) => {
      const r = stabilizePortal(s, via, stabs);
      if (r.ok) moves = r.moves ?? 0;
      return r;
    });
    if (e) return setErr(e);
    if (stabilizeLevel(moves)) setStabs(stabs + 1);
  };

  const chapter = outcome?.storyChapter ? STORY.find((c) => c.id === outcome.storyChapter) : null;
  const log = outcome?.log;
  const reveals = [
    ...(log?.newShards ?? []).map((id) => `◆ Heart Shard recovered: ${HEART_SHARDS.find((h) => h.id === id)?.name}`),
    ...(log?.newLumins ?? []).map((id) => { const l = LUMINS.find((x) => x.id === id)!; return `✧ ${l.name} emerged (${l.rarity}) – ${l.discovery}`; }),
    ...(log?.newRelics ?? []).map((id) => `✦ Relic found: ${RELICS.find((x) => x.id === id)?.name}`),
    ...(log?.newMemories ?? []).map((id) => `❖ Memory Crystal: “${MEMORIES.find((x) => x.id === id)?.title}”`),
    ...(log?.levelUps ?? []).map((l) => `▲ Keeper level ${l}`),
  ];
  const won = result.won;
  const showReward = !!outcome && (won || !!outcome.secret) && !ranked;
  const reward = outcome?.reward;
  const extras = reward ? describeReward({ ...reward, prismDust: 0, aether: 0, keeperXp: 0 }) : [];
  const gems = reward
    ? [
        reward.prismDust ? { value: reward.prismDust, label: "PRISM DUST", tone: L.goldLight, deep: L.gold } : null,
        reward.aether ? { value: reward.aether, label: "AETHER", tone: L.crystal, deep: "#1f6ab8" } : null,
        reward.keeperXp ? { value: reward.keeperXp, label: "KEEPER XP", tone: "#d8b0ff", deep: L.violet } : null,
      ].filter((g): g is NonNullable<typeof g> => !!g)
    : [];
  const heading = won ? (outcome?.firstRestore ? "THE PORTAL OPENS" : ranked ? "TRIAL COMPLETE" : "ISLAND RESTORED") : ranked ? "TRIAL COMPLETE" : "THE PORTAL FADES";
  const canStabilize = !won && !ranked && stabs < ECONOMY.stabilize.perRunLimit;

  return (
    <Animated.View entering={FadeIn.duration(350)} style={[StyleSheet.absoluteFill, r.scrim, !won && r.scrimDefeat]}>
      <ScrollView contentContainerStyle={r.scroll} showsVerticalScrollIndicator={false}>
        <Animated.View style={[r.panelWrap, panel]}>
          <GlassFrame radius={26} glowColor={won ? "#ffcf6a" : L.rose} style={r.panel}>
            <View style={r.crownSpace}>{won ? <VictoryCrown stars={result.stars} /> : <FadingPortal />}</View>
            <Text style={[r.kicker, { color: won ? L.crystal : L.rose }]}>{won ? (ranked ? "REALM TRIAL" : "VICTORY") : ranked ? "REALM TRIAL" : "OUT OF MOVES"}</Text>
            <Text style={[r.heading, !won && r.headingDefeat]}>{heading}</Text>
            <View style={r.rule}>
              <View style={r.ruleLine} />
              <Text style={r.ruleGem}>◆</Text>
              <View style={r.ruleLine} />
            </View>
            <Text style={r.scoreLabel}>SCORE</Text>
            <Text style={r.score}>{shownScore.toLocaleString()}</Text>
            {outcome?.trial && <Text style={r.body}>Placed #{outcome.trial.rank} of {outcome.trial.of} · +{outcome.trial.points} season points</Text>}
            {outcome && !outcome.verified && <Text style={[r.body, { color: L.danger }]}>This run could not be verified and earned no rewards.</Text>}
            {chapter && chapter.beats.map((b, i) => <Text key={i} style={r.beat}>{b}</Text>)}
            {reveals.map((x, i) => <Text key={i} style={r.reveal}>{x}</Text>)}
            {outcome?.secret && <Text style={r.secret}>✦ Secret uncovered: a Memory Shard answers you.</Text>}
            {showReward && gems.length > 0 && (
              <View style={r.gems}>
                {gems.map((g, i) => (
                  <RewardGem key={g.label} {...g} delay={(won ? 1450 : 200) + i * 180} />
                ))}
              </View>
            )}
            {showReward && extras.length > 0 && <Text style={r.extras}>{extras.join("  ·  ")}</Text>}
            {err && <Text style={r.err}>{err}</Text>}

            <View style={{ gap: 10, marginTop: 16 }}>
              {canStabilize && (
                <View style={r.stabBox}>
                  <Text style={r.stabTitle}>STABILIZE THE PORTAL</Text>
                  <Text style={r.small}>+{ECONOMY.stabilize.moves} moves to finish the island</Text>
                  <View style={{ flexDirection: "row", gap: 8, marginTop: 8 }}>
                    <Offer glyph="✦" label={`${ECONOMY.stabilize.prismDust}`} tone={L.goldLight} onPress={() => stabilize("prismDust")} />
                    <Offer glyph="◆" label={`${ECONOMY.stabilize.aether}`} tone={L.crystal} onPress={() => stabilize("aether")} />
                    <Offer glyph="▶" label="WATCH" tone={L.rose} onPress={() => stabilize("ad")} />
                  </View>
                </View>
              )}
              {won && onNext && <LuxButton testID="next-level" label="ENTER PORTAL" hero onPress={onNext} />}
              <LuxButton
                testID="replay"
                label={won ? "PLAY AGAIN" : "TRY AGAIN"}
                variant={won && onNext ? "glass" : "gold"}
                hero={!(won && onNext)}
                onPress={onReplay}
              />
              <PressSpring accessibilityLabel="Return to Sanctuary" onPress={onExit} style={r.link}>
                <Text style={r.linkTxt}>‹  RETURN TO SANCTUARY</Text>
              </PressSpring>
            </View>
          </GlassFrame>
        </Animated.View>
      </ScrollView>
    </Animated.View>
  );
}

const r = StyleSheet.create({
  scrim: { backgroundColor: "rgba(4,5,20,0.7)" },
  scrimDefeat: { backgroundColor: "rgba(10,4,22,0.78)" },
  scroll: { flexGrow: 1, justifyContent: "center", paddingHorizontal: 20, paddingTop: 96, paddingBottom: 30 },
  panelWrap: { maxWidth: 420, width: "100%", alignSelf: "center" },
  panel: { paddingHorizontal: 20, paddingBottom: 18, gap: 6 },
  crownSpace: { height: 92, alignItems: "center" },
  crown: { position: "absolute", top: -CY - 6 + 46, width: CW, height: CH },
  kicker: { fontFamily: F.title, fontSize: 10.5, letterSpacing: 3.5, textAlign: "center" },
  heading: { color: L.goldLight, fontSize: 28, fontFamily: F.display, letterSpacing: 3, textAlign: "center", ...titleGlow("#ffcf6a", 18) },
  headingDefeat: { color: "#f3d8ff", ...titleGlow(L.rose, 16) },
  rule: { flexDirection: "row", alignItems: "center", gap: 8, marginVertical: 8, paddingHorizontal: 40 },
  ruleLine: { flex: 1, height: 1, backgroundColor: "rgba(246,211,138,0.45)" },
  ruleGem: { color: L.goldPale, fontSize: 10 },
  scoreLabel: { color: L.goldPale, fontFamily: F.title, fontSize: 10, letterSpacing: 2.5, textAlign: "center" },
  score: { color: "#ffffff", fontFamily: F.number, fontSize: 30, textAlign: "center", marginTop: -4, ...titleGlow(L.aether, 10) },
  body: { color: L.mist, fontSize: 13.5, textAlign: "center", fontFamily: F.body },
  beat: { color: L.ivory, fontSize: 14.5, fontFamily: F.title, fontStyle: "italic", textAlign: "center", lineHeight: 22, marginTop: 2 },
  reveal: { color: L.crystalSoft, fontSize: 13, lineHeight: 19, fontFamily: F.body },
  secret: { color: L.goldLight, fontSize: 13.5, textAlign: "center", fontFamily: F.bodyStrong, ...titleGlow("#ffcf6a", 8) },
  gems: { flexDirection: "row", justifyContent: "center", gap: 10, marginTop: 10 },
  gemBox: {
    flex: 1, maxWidth: 110, alignItems: "center", paddingVertical: 10, borderRadius: 16, gap: 2,
    backgroundColor: "rgba(7,9,32,0.55)", borderWidth: 1, borderColor: "rgba(246,211,138,0.3)",
  },
  gemWrap: { width: 34, height: 34, alignItems: "center", justifyContent: "center", marginBottom: 2 },
  gemGlow: { position: "absolute", width: 22, height: 22, borderRadius: 11, opacity: 0.55, shadowRadius: 12, shadowOpacity: 1, shadowOffset: { width: 0, height: 0 } },
  gem: { width: 22, height: 22, borderRadius: 4, borderWidth: 1.5, overflow: "hidden", transform: [{ rotate: "45deg" }] },
  gemTop: { position: "absolute", left: 0, top: 0, width: "55%", height: "55%", opacity: 0.9 },
  gemShine: { position: "absolute", left: 3, top: 3, width: 5, height: 5, borderRadius: 1, backgroundColor: "rgba(255,255,255,0.85)" },
  gemNum: { color: "#ffffff", fontFamily: F.number, fontSize: 17 },
  gemLabel: { color: L.goldPale, fontFamily: F.title, fontSize: 8.5, letterSpacing: 1.6 },
  extras: { color: L.goldPale, fontSize: 12.5, fontFamily: F.bodyStrong, textAlign: "center", marginTop: 4 },
  err: { color: L.danger, textAlign: "center", fontFamily: F.bodyStrong, fontSize: 13 },
  stabBox: { padding: 12, borderRadius: 18, backgroundColor: "rgba(40,16,70,0.55)", borderWidth: 1, borderColor: "rgba(255,122,217,0.35)", alignItems: "stretch" },
  stabTitle: { color: "#f3d8ff", fontFamily: F.title, fontSize: 13, letterSpacing: 2.2, textAlign: "center", ...titleGlow(L.rose, 8) },
  small: { color: L.mist, fontSize: 12, textAlign: "center", fontFamily: F.body },
  offer: {
    flexDirection: "row", gap: 6, alignItems: "center", justifyContent: "center", height: 42, borderRadius: 21, borderWidth: 1.5,
    backgroundColor: "rgba(20,26,61,0.92)",
  },
  offerGlyph: { fontSize: 14, fontFamily: F.bold },
  offerTxt: { color: L.ivory, fontFamily: F.number, fontSize: 13.5 },
  link: { alignSelf: "center", paddingVertical: 8, paddingHorizontal: 14 },
  linkTxt: { color: L.goldPale, fontFamily: F.title, fontSize: 12.5, letterSpacing: 2 },
});
