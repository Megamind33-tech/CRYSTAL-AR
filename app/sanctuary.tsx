import { useState } from "react";
import { Text, View } from "react-native";
import { LUMINS } from "@/src/meta/config/collection";
import { SANCTUARY } from "@/src/meta/config/progression";
import { HEART_FACETS } from "@/src/meta/config/world";
import { bonuses, label, levelOf } from "@/src/meta/core";
import { collectSanctuary, feedLumin, houseLumin, pendingSanctuaryResonance, sanctuaryCost, sanctuaryRating, upgradeSanctuary } from "@/src/meta/progression";
import { act, metaStore } from "@/src/state/meta";
import { useStore } from "@/src/state/store";
import { Bar, Card, ErrorLine, Pill, Row, Screen, Section, T, Wallet } from "@/src/ui/kit";
import { useRouter } from "expo-router";
import { C } from "@/src/ui/theme";

export default function Sanctuary() {
  const p = useStore(metaStore, (m) => m.player);
  const [err, setErr] = useState<string | null>(null);
  const router = useRouter();
  if (!p) return null;
  const now = Date.now();
  const rating = sanctuaryRating(p);
  const pending = pendingSanctuaryResonance(p, now);
  const b = bonuses(p);
  const rescued = LUMINS.filter((l) => p.lumins[l.id]);

  return (
    <Screen title="Sanctuary" subtitle={`Rating ${rating.rating} · ${rating.pct}% restored`} right={<Wallet />}>
      <ErrorLine msg={err} />
      <Pill testID="sanctuary-ar" label="VIEW IN AR" tone="portal" onPress={() => router.push("/sanctuary-view")} />
      <Card>
        {T.h("The Heart Altar")}
        <View style={{ flexDirection: "row", flexWrap: "wrap", gap: 6, marginVertical: 4 }}>
          {Array.from({ length: HEART_FACETS }, (_, i) => (
            <View key={i} style={{ width: 20, height: 20, transform: [{ rotate: "45deg" }], borderWidth: 1, borderColor: C.gold, backgroundColor: i < p.heartShards.length ? C.gold : "transparent", opacity: i < p.heartShards.length ? 1 : 0.35 }} />
          ))}
        </View>
        {T.p(p.heartShards.length ? `${p.heartShards.length} of ${HEART_FACETS} facets of the Prism Heart rest here.` : "The altar is empty. Heart Shards are found beyond the portals.", true)}
      </Card>

      <Card>
        <Row style={{ justifyContent: "space-between" }}>
          <View style={{ flex: 1 }}>
            {T.h("Gathered Resonance")}
            {T.p(b.idleResonancePerHour ? `The Resonance Well gathers ${b.idleResonancePerHour}/hour while you are away.` : "Restore the Resonance Well to gather Resonance while you are away.", true)}
          </View>
          <Pill label={pending ? `COLLECT ${pending}` : "EMPTY"} disabled={!pending} onPress={() => setErr(act((s, t) => collectSanctuary(s, t)))} />
        </Row>
      </Card>

      <Section title="Restoration" note={`Stone ${p.items.sanctuaryStone} · Lumin Food ${p.items.luminFood}`}>
        {SANCTUARY.filter((d) => d.minKeeperLevel <= levelOf(p) + 1).map((d) => {
          const lvl = p.sanctuary.items[d.id] ?? 0;
          const maxed = lvl >= d.maxLevel;
          const locked = d.minKeeperLevel > levelOf(p);
          const cost = maxed ? {} : sanctuaryCost(d.id, lvl + 1);
          return (
            <Card key={d.id} testID={`sanct-${d.id}`}>
              <Row style={{ justifyContent: "space-between" }}>
                <View style={{ flex: 1, gap: 4 }}>
                  {T.h(`${d.name}${lvl ? `  ·  ${lvl}/${d.maxLevel}` : ""}`)}
                  <Bar value={lvl / d.maxLevel} height={4} />
                  {d.effect && T.p(`${lvl ? "Now: " + effectText(d.effect.kind, d.effect.perLevel * lvl) + " · " : ""}Next: ${effectText(d.effect.kind, d.effect.perLevel * (lvl + 1))}`, true)}
                </View>
                {locked ? <Text style={{ color: C.inkFaint, fontSize: 12 }}>🔒 Keeper {d.minKeeperLevel}</Text> : (
                  <Pill label={maxed ? "RESTORED" : lvl ? "UPGRADE" : "RESTORE"} disabled={maxed} onPress={() => setErr(act((s, t) => upgradeSanctuary(s, d.id, t), ["sanctuary_upgrade", { item: d.id, level: lvl + 1 }]))} />
                )}
              </Row>
              {!maxed && !locked && T.p(Object.entries(cost).map(([k, v]) => `${v} ${label(k)}`).join(" · "), true)}
            </Card>
          );
        })}
      </Section>

      <Section title="Lumin Grove" note={`${p.sanctuary.housed.length}/${b.luminSlots} housed`}>
        {rescued.length === 0 && T.p("No Lumins yet. Open portals to find them.", true)}
        {rescued.map((l) => {
          const housed = p.sanctuary.housed.includes(l.id);
          return (
            <Card key={l.id}>
              <Row style={{ justifyContent: "space-between" }}>
                <View style={{ flex: 1 }}>
                  {T.h(`${l.name}  ·  ${l.rarity}`)}
                  {T.p(housed ? l.sanctuaryBehaviour : `Bond ${p.lumins[l.id].bond}${l.evolvesTo ? ` / ${l.evolvesTo.bond} to evolve` : ""}`, true)}
                </View>
                <View style={{ gap: 6 }}>
                  <Pill label={housed ? "HOUSED" : "HOUSE"} tone={housed ? "ghost" : "gold"} onPress={() => setErr(act((s) => houseLumin(s, l.id)))} />
                  <Pill label="FEED" tone="ghost" disabled={!p.items.luminFood} onPress={() => setErr(act((s, t) => feedLumin(s, l.id, t)))} />
                </View>
              </Row>
            </Card>
          );
        })}
      </Section>
    </Screen>
  );
}

function effectText(kind: string, v: number) {
  switch (kind) {
    case "dustPct": return `+${v}% Prism Dust`;
    case "xpPct": return `+${v}% Keeper XP`;
    case "luminSlots": return `${1 + v} Lumin homes`;
    case "relicRegenPct": return `relics recharge ${v}% faster`;
    case "idleResonancePerHour": return `${v} Resonance/hour`;
    default: return String(v);
  }
}
