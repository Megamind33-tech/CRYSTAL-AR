import { useState } from "react";
import { View } from "react-native";
import { KEEPERS_CACHE } from "@/src/meta/config/progression";
import { isUnlocked } from "@/src/meta/core";
import { activeEvents } from "@/src/meta/live";
import { availableQuests, claimDutyCache, claimQuest, dutyCacheStatus, openKeepersCache, questDef, refreshCycles } from "@/src/meta/progression";
import type { Quest } from "@/src/meta/types";
import { act, metaStore } from "@/src/state/meta";
import { useStore } from "@/src/state/store";
import { Bar, Card, ErrorLine, Pill, RewardLine, Row, Screen, Section, T, Wallet } from "@/src/ui/kit";

export default function Duties() {
  const raw = useStore(metaStore, (m) => m.player);
  const [err, setErr] = useState<string | null>(null);
  if (!raw) return null;
  const now = Date.now();
  const p = refreshCycles(raw, now);
  const cache = dutyCacheStatus(p);
  const quests = availableQuests(p, now);
  const byCat = (f: (q: Quest) => boolean) => quests.filter(f);

  const QuestCard = ({ q }: { q: Quest }) => {
    const st = p.quests[q.id] ?? { progress: 0, completed: false, claimed: false };
    return (
      <Card testID={`quest-${q.id}`}>
        <Row style={{ justifyContent: "space-between" }}>
          <View style={{ flex: 1, gap: 4 }}>
            {T.h(q.title)}
            <Bar value={st.progress / q.target} height={4} />
            {T.p(`${Math.min(st.progress, q.target).toLocaleString()} / ${q.target.toLocaleString()}`, true)}
          </View>
          <Pill
            label={st.claimed ? "DONE" : "CLAIM"}
            disabled={!st.completed || st.claimed}
            onPress={() => setErr(act((s, t) => claimQuest(s, q.id, t), ["mission_completed", { quest: q.id }]))}
          />
        </Row>
        <RewardLine reward={q.reward} dim={st.claimed} />
      </Card>
    );
  };

  return (
    <Screen title="Keeper Duties" subtitle="The realms ask small things of you each day" right={<Wallet />}>
      <ErrorLine msg={err} />
      {activeEvents(now).length > 0 && (
        <Card>
          {activeEvents(now).map((e) => (
            <View key={e.id}>
              {T.h(e.title)}
              {T.p(`${e.modifiers.resonanceMultiplier ? `×${e.modifiers.resonanceMultiplier} Resonance · ` : ""}ends ${new Date(e.endsAt).toUTCString().slice(0, 16)}`, true)}
            </View>
          ))}
        </Card>
      )}
      {isUnlocked(p, "duties") ? (
        <Section title="Today's Duties" note={`${cache.done}/${cache.needed} for the Keeper's Cache`}>
          {p.questCycles.daily.map((id) => <QuestCard key={id} q={questDef(id)!} />)}
          <Card>
            <Row style={{ justifyContent: "space-between" }}>
              <View style={{ flex: 1 }}>
                {T.h("Keeper's Cache")}
                <RewardLine reward={KEEPERS_CACHE} />
              </View>
              {p.items.keepersCache > 0 ? (
                <Pill label={`OPEN (${p.items.keepersCache})`} tone="portal" onPress={() => setErr(act((s, t) => openKeepersCache(s, t)))} />
              ) : (
                <Pill label={cache.claimed ? "COLLECTED" : "EARN"} disabled={!cache.claimable} onPress={() => setErr(act((s, t) => claimDutyCache(s, t)))} />
              )}
            </Row>
          </Card>
        </Section>
      ) : (
        T.p("Keeper Duties unlock at Keeper level 3.", true)
      )}
      {isUnlocked(p, "duties") && (
        <Section title="Realm Missions" note="this week">
          {p.questCycles.weekly.map((id) => <QuestCard key={id} q={questDef(id)!} />)}
        </Section>
      )}
      <Section title="Story">
        {byCat((q) => q.category === "story" && !p.quests[q.id]?.claimed).slice(0, 2).map((q) => <QuestCard key={q.id} q={q} />)}
      </Section>
      <Section title="Realm Quests">
        {byCat((q) => q.category === "realm").map((q) => <QuestCard key={q.id} q={q} />)}
      </Section>
    </Screen>
  );
}
