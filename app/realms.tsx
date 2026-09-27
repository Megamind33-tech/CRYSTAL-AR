import { useState } from "react";
import { Text, View } from "react-native";
import { useRouter } from "expo-router";
import { ISLANDS, REALMS } from "@/src/meta/config/world";
import { label, levelOf } from "@/src/meta/core";
import { islandStatus, unlockDiscovery } from "@/src/meta/progression";
import { act, metaStore } from "@/src/state/meta";
import { useStore } from "@/src/state/store";
import { Card, ErrorLine, Pill, RewardLine, Row, Screen, Section, T, Wallet } from "@/src/ui/kit";
import { C } from "@/src/ui/theme";

const PORTAL_NAME = { story: "Story Portal", discovery: "Discovery Portal", expedition: "Expedition Portal" } as const;

export default function Realms() {
  const router = useRouter();
  const p = useStore(metaStore, (m) => m.player);
  const [err, setErr] = useState<string | null>(null);
  if (!p) return null;
  const now = Date.now();

  return (
    <Screen title="Realms" subtitle={`${p.heartShards.length} Heart Shard${p.heartShards.length === 1 ? "" : "s"} recovered`} right={<Wallet />}>
      <ErrorLine msg={err} />
      {REALMS.map((realm) => {
        const visible = levelOf(p) >= realm.minKeeperLevel - 2 || realm.order === 1;
        const gateOpen = levelOf(p) >= realm.minKeeperLevel && p.heartShards.length >= realm.requiresShards;
        return (
          <Section key={realm.id} title={realm.name} note={gateOpen ? undefined : visible ? `Gate: Keeper ${realm.minKeeperLevel} · ${realm.requiresShards} Heart Shard` : "A faint signal…"}>
            {visible ? T.p(realm.blurb, !gateOpen) : T.p("Something is out there, beyond the edge of the Reach.", true)}
            {visible && realm.islands.length === 0 && T.p("Its islands have not surfaced yet.", true)}
            {visible &&
              realm.islands.map((id) => {
                const island = ISLANDS.find((i) => i.id === id)!;
                const st = islandStatus(p, island, now);
                const stars = p.islands[id]?.stars ?? 0;
                return (
                  <Card key={id} testID={`island-${id}`}>
                    <Row style={{ justifyContent: "space-between" }}>
                      <View style={{ flex: 1, gap: 2 }}>
                        {T.h(island.name)}
                        <Text style={{ color: island.portal === "expedition" ? C.portal : C.inkFaint, fontSize: 12 }}>
                          {PORTAL_NAME[island.portal]}
                          {st.status === "restored" ? ` · ${"★".repeat(stars)}${"☆".repeat(3 - stars)}` : ""}
                        </Text>
                      </View>
                      {st.status === "available" || st.status === "restored" ? (
                        <Pill testID={`enter-${id}`} label={st.status === "restored" ? "REPLAY" : "ENTER"} onPress={() => router.push({ pathname: "/play", params: { island: id } })} />
                      ) : st.status === "needsUnlock" && island.portal === "discovery" ? (
                        <Pill
                          label={`OPEN · ${Object.entries(island.unlockCost ?? {}).map(([k, v]) => `${v} ${label(k)}`).join(", ")}`}
                          tone="portal"
                          onPress={() => setErr(act((s, t) => unlockDiscovery(s, id, t)))}
                        />
                      ) : st.status === "needsUnlock" ? (
                        <Pill label="SIGNAL" tone="portal" onPress={() => router.push("/exchange")} />
                      ) : (
                        <Text style={{ color: C.inkFaint, fontSize: 12 }}>🔒 {st.reason}</Text>
                      )}
                    </Row>
                    {island.portal === "expedition" && st.status !== "restored" && island.expedition && (
                      T.p(`Unknown Realm Signal · Frozen Realm detected · portal stability ${island.expedition.signalHours} hours`, true)
                    )}
                    <RewardLine reward={st.status === "restored" ? island.replay : island.firstRestore} dim={st.status === "locked"} />
                  </Card>
                );
              })}
          </Section>
        );
      })}
    </Screen>
  );
}
