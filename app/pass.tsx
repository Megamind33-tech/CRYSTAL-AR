import { useState } from "react";
import { Text, View } from "react-native";
import { useRouter } from "expo-router";
import { activeEvents, claimPass, passStatus } from "@/src/meta/live";
import { act, metaStore } from "@/src/state/meta";
import { useStore } from "@/src/state/store";
import { Bar, Card, ErrorLine, Label, Pill, RewardLine, Row, Screen, Section, T } from "@/src/ui/kit";
import { F, L, titleGlow } from "@/src/ui/lux/tokens";

export default function Pass() {
  const router = useRouter();
  const p = useStore(metaStore, (m) => m.player);
  const [err, setErr] = useState<string | null>(null);
  if (!p) return null;
  const now = Date.now();
  const st = passStatus(p, now);
  if (!st) return <Screen title="Crystal Pass">{T.p("No season is running right now.", true)}</Screen>;
  const next = st.season.passTiers[st.tier];
  const prev = st.season.passTiers[st.tier - 1];
  const within = next ? (st.passXp - (prev?.passXp ?? 0)) / (next.passXp - (prev?.passXp ?? 0)) : 1;

  return (
    <Screen title="Crystal Pass" subtitle={`Season ${st.season.number}: ${st.season.name} · ${st.daysLeft} days left`}>
      <ErrorLine msg={err} />
      <Card>
        {T.p(st.season.theme)}
        <Row style={{ justifyContent: "space-between" }}>
          <Text style={{ color: L.goldLight, fontFamily: F.display, fontSize: 20, letterSpacing: 1.5, ...titleGlow("#ffcf6a", 10) }}>TIER {st.tier}</Text>
          <Text style={{ color: L.mist, fontFamily: F.body, fontSize: 12.5 }}>{next ? `${st.toNext} Season XP to tier ${st.tier + 1}` : "Complete"}</Text>
        </Row>
        <Bar value={within} color={L.crystal} />
        {!st.premium && <Pill label="UNLOCK THE PREMIUM TRACK" tone="portal" onPress={() => router.push("/exchange")} />}
        {T.p("Season XP comes from islands, duties, missions and Trials. Heart Shards and the main story are never behind the pass.", true)}
      </Card>
      {activeEvents(now).map((e) => <Card key={e.id}>{T.h(e.title)}{T.p("Season event underway – see Keeper Duties.", true)}</Card>)}
      <Section title="Tiers">
        {st.season.passTiers.slice(Math.max(0, st.tier - 2), st.tier + 8).map((t) => {
          const reached = t.tier <= st.tier;
          const fClaimed = !st.claimableFree.includes(t.tier) && reached;
          const pClaimed = st.premium && !st.claimablePremium.includes(t.tier) && reached;
          return (
            <Card key={t.tier} style={{ opacity: reached ? 1 : 0.7 }}>
              <Text style={[{ color: reached ? L.goldLight : L.mistDim, fontFamily: F.title, fontSize: 14, letterSpacing: 1.6 }, reached && titleGlow("#ffcf6a", 8)]}>TIER {t.tier}</Text>
              <Row style={{ justifyContent: "space-between" }}>
                <View style={{ flex: 1 }}><Label color={L.mist}>FREE</Label><RewardLine reward={t.free} /></View>
                <Pill label={fClaimed ? "✓" : "CLAIM"} disabled={!st.claimableFree.includes(t.tier)} onPress={() => setErr(act((s, n) => claimPass(s, t.tier, "free", n)))} />
              </Row>
              <Row style={{ justifyContent: "space-between" }}>
                <View style={{ flex: 1 }}><Label color={L.crystal}>CRYSTAL PASS</Label><RewardLine reward={t.premium} /></View>
                <Pill tone="portal" label={pClaimed ? "✓" : st.premium ? "CLAIM" : "🔒"} disabled={!st.claimablePremium.includes(t.tier)} onPress={() => setErr(act((s, n) => claimPass(s, t.tier, "premium", n)))} />
              </Row>
            </Card>
          );
        })}
      </Section>
    </Screen>
  );
}
