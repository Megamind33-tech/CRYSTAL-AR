import { useState } from "react";
import { Text, View } from "react-native";
import { HEART_SHARDS, REALMS } from "@/src/meta/config/world";
import { relicCharges, archive } from "@/src/meta/progression";
import { metaStore } from "@/src/state/meta";
import { useStore } from "@/src/state/store";
import { Bar, Card, Row, Screen, T, Tabs } from "@/src/ui/kit";
import { F, L, titleGlow } from "@/src/ui/lux/tokens";

const TABS = ["Lumins", "Relics", "Memories", "Heart", "Realms"] as const;
type Tab = (typeof TABS)[number];
const RARITY_COLOR: Record<string, string> = { common: L.mist, rare: L.aether, epic: "#c8a0ff", mythic: L.ember, ancient: L.crystal };

export default function Archive() {
  const p = useStore(metaStore, (m) => m.player);
  const [tab, setTab] = useState<Tab>("Lumins");
  const [open, setOpen] = useState<string | null>(null);
  if (!p) return null;
  const a = archive(p);
  const now = Date.now();
  const Silhouette = ({ text }: { text: string }) => <Text style={{ color: L.mistDim, fontSize: 13, letterSpacing: 2, fontFamily: F.title }}>{text}</Text>;

  return (
    <Screen title="Keeper Archive" subtitle={`${a.pct}% of the Shattered Realms recorded`}>
      <Bar value={a.pct / 100} />
      <Tabs items={TABS} value={tab} onChange={setTab} />

      {tab === "Lumins" && a.lumins.entries.map(({ def, found }) => (
        <Card key={def.id}>
          {found ? (
            <>
              <Row style={{ justifyContent: "space-between" }}>{T.h(def.name)}<Text style={{ color: RARITY_COLOR[def.rarity], fontSize: 10.5, letterSpacing: 1.6, fontFamily: F.title, ...titleGlow(RARITY_COLOR[def.rarity], 6) }}>{def.rarity.toUpperCase()}</Text></Row>
              {T.p(`${def.species} of ${REALMS.find((r) => r.id === def.realm)?.name}`, true)}
              {T.p(def.discovery)}
            </>
          ) : <Silhouette text={`? ? ?   ·   ${def.rarity === "ancient" ? "a legend of the Reach" : REALMS.find((r) => r.id === def.realm)?.name}`} />}
        </Card>
      ))}

      {tab === "Relics" && a.relics.entries.map(({ def, found }) => {
        const ch = found ? relicCharges(p, def.id, now) : null;
        return (
          <Card key={def.id}>
            {found && ch ? (
              <>
                <Row style={{ justifyContent: "space-between" }}>{T.h(def.name)}<Text style={{ color: L.crystal, fontSize: 12, fontFamily: F.bodyStrong }}>{ch.charges}/{ch.max} charges</Text></Row>
                {T.p(def.lore, true)}
                {T.p(`${def.set}${def.trialApproved ? " · approved for Realm Trials" : ""}`, true)}
              </>
            ) : <Silhouette text={`? ? ?   ·   ${def.set}`} />}
          </Card>
        );
      })}

      {tab === "Memories" && a.memories.entries.map(({ def, found }) => (
        <Card key={def.id} onPress={found ? () => setOpen(open === def.id ? null : def.id) : undefined}>
          {found ? (
            <>
              {T.h(def.title)}
              {open === def.id ? T.p(def.text) : T.p("Tap to remember", true)}
            </>
          ) : <Silhouette text="A clouded Memory Crystal" />}
        </Card>
      ))}

      {tab === "Heart" && (
        <Card>
          {T.h(`The Prism Heart · ${a.heart.facets}/${a.heart.of} facets`)}
          {HEART_SHARDS.map((h) => <View key={h.id}>{T.p(`${p.heartShards.includes(h.id) ? "◆" : "◇"}  ${p.heartShards.includes(h.id) ? h.name : "Unrecovered facet"}`, !p.heartShards.includes(h.id))}</View>)}
          {T.p("Heart Shards are earned by restoring realms. They can never be bought.", true)}
        </Card>
      )}

      {tab === "Realms" && a.realms.entries.map(({ def, found }) => (
        <Card key={def.id}>
          {found ? <>{T.h(def.name)}{T.p(def.blurb, true)}</> : <Silhouette text="An undiscovered realm" />}
        </Card>
      ))}
      <View style={{ height: 8 }} />
    </Screen>
  );
}
