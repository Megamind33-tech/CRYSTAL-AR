import { useEffect, useRef, useState } from "react";
import { Animated, StyleSheet, Text, View } from "react-native";
import { devAdProvider } from "../backend/mockBackend";
import { LUMINS, RELICS } from "../meta/config/collection";
import { ECONOMY } from "../meta/config/live";
import { HEART_SHARDS, MEMORIES, STORY } from "../meta/config/world";
import { stabilizePortal } from "../meta/live";
import { gameStore, stabilizeLevel } from "../state/game";
import { act, analytics, metaStore } from "../state/meta";
import { useStore } from "../state/store";
import { Button } from "./Button";
import { RewardLine } from "./kit";
import { C, font, ui } from "./theme";

type Props = { onNext: (() => void) | null; onReplay: () => void; onExit: () => void; ranked: boolean };

/** Victory / failure flow: portal opens → story beat → what emerged → rewards. */
export function RunResult({ onNext, onReplay, onExit, ranked }: Props) {
  const result = useStore(gameStore, (s) => s.result);
  const outcome = useStore(metaStore, (m) => m.lastOutcome);
  const score = useStore(gameStore, (s) => s.hud.score);
  const appear = useRef(new Animated.Value(0)).current;
  const [show, setShow] = useState(false);
  const [stabs, setStabs] = useState(0);
  const [err, setErr] = useState<string | null>(null);

  useEffect(() => {
    if (!result) {
      setShow(false);
      appear.setValue(0);
      return;
    }
    const t = setTimeout(() => {
      setShow(true);
      Animated.spring(appear, { toValue: 1, useNativeDriver: true, friction: 7 }).start();
    }, result.won ? 1600 : 500);
    return () => clearTimeout(t);
  }, [result, appear]);

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

  return (
    <View style={[StyleSheet.absoluteFill, s.scrim]}>
      <Animated.View style={[ui.glass, s.panel, { opacity: appear, transform: [{ translateY: appear.interpolate({ inputRange: [0, 1], outputRange: [40, 0] }) }] }]}>
        {result.won ? (
          <>
            <Text style={s.heading}>{outcome?.firstRestore ? "The Portal Opens" : ranked ? "Trial Complete" : "Island Restored"}</Text>
            <Text style={s.stars}>{"★".repeat(result.stars)}<Text style={{ color: "rgba(255,255,255,0.2)" }}>{"★".repeat(3 - result.stars)}</Text></Text>
          </>
        ) : (
          <Text style={s.heading}>{ranked ? "Trial Complete" : "The Portal Falters"}</Text>
        )}
        <Text style={s.body}>Score {score.toLocaleString()}</Text>
        {outcome?.trial && <Text style={s.body}>Placed #{outcome.trial.rank} of {outcome.trial.of} · +{outcome.trial.points} season points</Text>}
        {outcome && !outcome.verified && <Text style={[s.body, { color: C.danger }]}>This run could not be verified and earned no rewards.</Text>}
        {chapter && chapter.beats.map((b, i) => <Text key={i} style={s.beat}>{b}</Text>)}
        {reveals.map((r, i) => <Text key={i} style={s.reveal}>{r}</Text>)}
        {outcome?.secret && <Text style={[s.body, { color: C.gold }]}>✦ Secret uncovered: a Memory Shard answers you.</Text>}
        {outcome && (result.won || outcome.secret) && !ranked && <RewardLine reward={outcome.reward} />}
        {err && <Text style={{ color: C.danger, textAlign: "center" }}>{err}</Text>}

        <View style={{ gap: 10, marginTop: 14 }}>
          {!result.won && !ranked && stabs < ECONOMY.stabilize.perRunLimit && (
            <>
              <Text style={s.small}>Stabilize the portal: +{ECONOMY.stabilize.moves} moves</Text>
              <View style={{ flexDirection: "row", gap: 8 }}>
                <Button label={`✦ ${ECONOMY.stabilize.prismDust}`} variant="primary" style={{ flex: 1, paddingHorizontal: 8 }} onPress={() => stabilize("prismDust")} />
                <Button label={`◆ ${ECONOMY.stabilize.aether}`} style={{ flex: 1, paddingHorizontal: 8 }} onPress={() => stabilize("aether")} />
                <Button label="WATCH" style={{ flex: 1, paddingHorizontal: 8 }} onPress={() => stabilize("ad")} />
              </View>
            </>
          )}
          {result.won && onNext && <Button testID="next-level" label="STEP THROUGH THE PORTAL" variant="primary" onPress={onNext} />}
          <Button testID="replay" label={result.won ? "REPLAY" : "TRY AGAIN"} variant={result.won && onNext ? "ghost" : "primary"} onPress={onReplay} />
          <Button label="RETURN TO SANCTUARY" onPress={onExit} />
        </View>
      </Animated.View>
    </View>
  );
}

const s = StyleSheet.create({
  scrim: { backgroundColor: "rgba(0,0,0,0.35)", justifyContent: "center", padding: 18 },
  panel: { padding: 20, maxWidth: 440, width: "100%", alignSelf: "center", backgroundColor: C.glassStrong, gap: 6 },
  heading: { color: C.ink, fontSize: 28, fontFamily: font.display, fontWeight: "700", textAlign: "center" },
  stars: { color: C.gold, fontSize: 36, textAlign: "center", letterSpacing: 6 },
  body: { color: C.inkDim, fontSize: 14, textAlign: "center" },
  beat: { color: C.ink, fontSize: 14, fontFamily: font.display, fontStyle: "italic", textAlign: "center", lineHeight: 20 },
  reveal: { color: C.portal, fontSize: 13, lineHeight: 18 },
  small: { color: C.inkFaint, fontSize: 12, textAlign: "center" },
});
