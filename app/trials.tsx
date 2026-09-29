import { useEffect, useState } from "react";
import { Text, View } from "react-native";
import { useRouter } from "expo-router";
import type { LeaderboardResponse } from "@/src/backend/contracts";
import { leagueName, trialDef, trialInstances } from "@/src/meta/competition";
import { LEADERBOARDS, LEAGUES } from "@/src/meta/config/live";
import { levelOf } from "@/src/meta/core";
import type { LeaderboardId } from "@/src/meta/types";
import { backend, metaStore } from "@/src/state/meta";
import { useStore } from "@/src/state/store";
import { Bar, Card, Chip, Pill, RewardLine, Row, Screen, Section, T } from "@/src/ui/kit";
import { F, L, titleGlow } from "@/src/ui/lux/tokens";

const KIND: Record<string, string> = { highScore: "Highest score on a shared board", resonanceRush: "Most Resonance before time runs out", limitedMoves: "Best result with the same few moves", cascade: "Deepest crystal chain", portal: "Stabilise a difficult portal" };

export default function Trials() {
  const router = useRouter();
  const p = useStore(metaStore, (m) => m.player);
  const [board, setBoard] = useState<LeaderboardId>("globalKeeper");
  const [lb, setLb] = useState<LeaderboardResponse | null>(null);

  useEffect(() => {
    if (!p) return;
    let live = true;
    backend.sync(p, []).then(() => backend.leaderboard(board, p.profile.keeperId)).then((r) => live && setLb(r));
    return () => {
      live = false;
    };
  }, [board, p]);

  if (!p) return null;
  const now = Date.now();
  const league = LEAGUES.findIndex((l) => l.id === p.league.id);
  const nextLeague = LEAGUES[league + 1];

  const RankRow = ({ r, me }: { r: LeaderboardResponse["top10"][0]; me?: boolean }) => (
    <Row style={{ paddingVertical: 6, paddingHorizontal: 8, borderRadius: 10, backgroundColor: me ? "rgba(224,169,74,0.18)" : "transparent", borderWidth: me ? 1 : 0, borderColor: "rgba(246,211,138,0.5)" }}>
      <Text style={[{ color: r.rank <= 3 ? L.goldLight : L.mist, width: 44, fontFamily: F.title, fontSize: 14 }, r.rank <= 3 && titleGlow("#ffcf6a", 6)]}>#{r.rank}</Text>
      <Text style={{ color: L.ivory, flex: 1, fontFamily: F.body, fontSize: 13.5 }} numberOfLines={1}>{r.name} <Text style={{ color: L.mistDim }}>· {r.level}</Text></Text>
      <Text style={{ color: L.ivory, fontFamily: F.number, fontSize: 13.5 }}>{r.score.toLocaleString()}</Text>
    </Row>
  );

  return (
    <Screen title="Realm Trials" subtitle={`${leagueName(p.league.id)} · ${p.stats.trialPoints} season points`}>
      <Card>
        {T.h(leagueName(p.league.id))}
        <Bar value={nextLeague ? (p.stats.trialPoints - LEAGUES[league].minPoints) / (nextLeague.minPoints - LEAGUES[league].minPoints) : 1} />
        {T.p(nextLeague ? `${nextLeague.minPoints - p.stats.trialPoints} points to ${nextLeague.name}. Leagues rise with Trial placements only.` : "The highest league.", true)}
      </Card>

      <Section title="Open Trials" note="same board and moves for every Keeper">
        {trialInstances(now).map((inst) => {
          const def = trialDef(inst.trialId)!;
          const locked = def.minKeeperLevel > levelOf(p);
          const hoursLeft = Math.max(1, Math.round((inst.closesAt - now) / 3600000));
          return (
            <Card key={inst.instanceId} testID={`trial-${def.id}`}>
              <Row style={{ justifyContent: "space-between" }}>
                <View style={{ flex: 1 }}>
                  {T.h(def.name)}
                  {T.p(`${KIND[def.kind]} · ${def.moves} moves${def.timeLimitSec ? ` · ${def.timeLimitSec}s` : ""} · closes in ${hoursLeft}h`, true)}
                  {T.p(def.approvedRelics.length ? `Approved relics: ${def.approvedRelics.join(", ")}` : "No relics – pure skill", true)}
                </View>
                <Pill
                  label={locked ? `KEEPER ${def.minKeeperLevel}` : "ENTER"}
                  disabled={locked}
                  onPress={() => router.push({ pathname: "/play", params: { trial: inst.instanceId } })}
                />
              </Row>
              <RewardLine reward={def.rewards[0].reward} />
            </Card>
          );
        })}
      </Section>

      <Section title="Rankings" note="simulated rivals until the online service exists">
        <Row style={{ flexWrap: "wrap", gap: 8 }}>
          {LEADERBOARDS.map((l) => (
            <Chip key={l.id} label={l.name} active={board === l.id} onPress={() => setBoard(l.id)} />
          ))}
        </Row>
        {board === "regional" && !p.profile.country ? (
          <Card>{T.p("Regional rankings use the country from your account settings. No location is ever read.", true)}</Card>
        ) : lb ? (
          <Card>
            {lb.top10.map((r) => <RankRow key={r.keeperId} r={r} me={r.keeperId === p.profile.keeperId} />)}
            {lb.me && lb.me.rank > 10 && (
              <>
                <Text style={{ color: L.goldPale, textAlign: "center", fontFamily: F.bold }}>⋯</Text>
                {lb.neighbours.map((r) => <RankRow key={r.keeperId} r={r} me={r.keeperId === p.profile.keeperId} />)}
              </>
            )}
            {T.p(`${lb.total.toLocaleString()} Keepers`, true)}
          </Card>
        ) : T.p("Loading…", true)}
      </Section>
    </Screen>
  );
}
