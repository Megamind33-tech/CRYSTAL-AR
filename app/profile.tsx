import { useState } from "react";
import { Pressable, Text, TextInput, View } from "react-native";
import { LUMINS, RARITY_ORDER } from "@/src/meta/config/collection";
import { leagueName } from "@/src/meta/competition";
import { keeperLevel } from "@/src/meta/core";
import { passStatus } from "@/src/meta/live";
import { achievementScore, achievementStatus, claimAchievement, sanctuaryRating } from "@/src/meta/progression";
import { act, metaStore, setPlayer } from "@/src/state/meta";
import { useStore } from "@/src/state/store";
import { DIMENSION_LABEL, keeperRank, RANKS, type Dimension } from "@/src/meta/rank";
import { Bar, Card, ErrorLine, Pill, RewardLine, Row, Screen, Section, T } from "@/src/ui/kit";
import { C, font } from "@/src/ui/theme";

const CAT_NAME: Record<string, string> = { explorer: "Explorer", restorer: "Restorer", collector: "Collector", master: "Master", keeper: "Keeper", champion: "Champion", loyalty: "Loyalty", secrets: "Secrets" };

export default function Profile() {
  const p = useStore(metaStore, (m) => m.player);
  const [err, setErr] = useState<string | null>(null);
  const [editing, setEditing] = useState(false);
  const [name, setName] = useState("");
  if (!p) return null;
  const now = Date.now();
  const lvl = keeperLevel(p.keeperXp);
  const pass = passStatus(p, now);
  const rare = LUMINS.filter((l) => p.lumins[l.id] && RARITY_ORDER.indexOf(l.rarity) >= 2);
  const ach = achievementStatus(p);

  const Stat = ({ k, v }: { k: string; v: string | number }) => (
    <View style={{ width: "33%", paddingVertical: 6 }}>
      <Text style={{ color: C.ink, fontSize: 17, fontWeight: "800" }}>{v}</Text>
      <Text style={{ color: C.inkFaint, fontSize: 11 }}>{k}</Text>
    </View>
  );

  const rank = keeperRank(p);
  return (
    <Screen title="Keeper" subtitle={`${rank.name} · ${p.profile.title}`}>
      <ErrorLine msg={err} />
      <Card style={{ alignItems: "center", gap: 8, paddingVertical: 20, borderColor: C.gold }}>
        <View style={{ width: 72, height: 72, borderRadius: 36, borderWidth: 2, borderColor: C.gold, backgroundColor: "#1d3a2f", alignItems: "center", justifyContent: "center" }}>
          <Text style={{ color: C.gold, fontSize: 32, fontFamily: font.display, fontWeight: "700" }}>{p.profile.keeperName[0]}</Text>
        </View>
        {editing ? (
          <Row>
            <TextInput value={name} onChangeText={setName} maxLength={16} autoFocus placeholder="Keeper name" placeholderTextColor={C.inkFaint} style={{ color: C.ink, borderBottomWidth: 1, borderBottomColor: C.gold, minWidth: 140, fontSize: 18, paddingVertical: 4 }} />
            <Pill label="SAVE" onPress={() => {
              const clean = name.trim().replace(/[^\p{L}\p{N} _-]/gu, "");
              if (clean.length >= 2) setPlayer((s) => ({ ...s, profile: { ...s.profile, keeperName: clean } }));
              setEditing(false);
            }} />
          </Row>
        ) : (
          <Pressable onPress={() => { setName(p.profile.keeperName); setEditing(true); }}>
            <Text style={{ color: C.ink, fontSize: 22, fontFamily: font.display, fontWeight: "700" }}>{p.profile.keeperName} ✎</Text>
          </Pressable>
        )}
        <Text style={{ color: C.inkDim }}>Keeper {lvl.level} · {leagueName(p.league.id)}</Text>
        <View style={{ width: "80%" }}><Bar value={lvl.progress} /></View>
        <Text style={{ color: C.inkFaint, fontSize: 11 }}>{lvl.into} / {lvl.need} XP to level {lvl.level + 1}</Text>
      </Card>

      <Card>
        <View style={{ flexDirection: "row", flexWrap: "wrap" }}>
          <Stat k="Heart Shards" v={p.heartShards.length} />
          <Stat k="Islands restored" v={Object.keys(p.islands).length} />
          <Stat k="Lumins rescued" v={Object.keys(p.lumins).length} />
          <Stat k="Relics found" v={Object.keys(p.relics).length} />
          <Stat k="Chronicle score" v={achievementScore(p)} />
          <Stat k="Return streak" v={p.checkin.streak} />
          <Stat k="Resonance" v={p.stats.resonance.toLocaleString()} />
          <Stat k="Longest chain" v={p.stats.bestCascade} />
          <Stat k="Trophies" v={p.trophies.length} />
          <Stat k="Sanctuary" v={`${sanctuaryRating(p).pct}%`} />
          <Stat k="Season level" v={pass?.tier ?? "–"} />
          <Stat k="Rare Lumins" v={rare.map((l) => l.name).join(", ") || "–"} />
        </View>
      </Card>

      <Section title="Keeper Rank" note={`${rank.index + 1} of ${RANKS.length}`}>
        <Card>
          {T.h(rank.name)}
          <Bar value={rank.score} color={C.gold} />
          {(Object.keys(rank.dimensions) as Dimension[]).map((k) => (
            <Row key={k} style={{ justifyContent: "space-between" }}>
              <Text style={{ color: C.inkDim, fontSize: 12.5 }}>{DIMENSION_LABEL[k]}</Text>
              <View style={{ width: 120 }}>
                <Bar value={rank.dimensions[k]} color={C.portal} height={5} />
              </View>
            </Row>
          ))}
          {rank.next ? T.p(rank.next, true) : T.p("The highest rank a Keeper can hold.", true)}
        </Card>
      </Section>

      <Section title="Chronicles" note={`${achievementScore(p)} points`}>
        {ach.filter((a) => !a.concealed).map((a) => (
          <Card key={a.def.id}>
            <Row style={{ justifyContent: "space-between" }}>
              <View style={{ flex: 1, gap: 4 }}>
                {T.h(`${a.def.name}  ${"◆".repeat(a.claimed)}${"◇".repeat(a.def.tiers.length - a.claimed)}`)}
                {T.p(`${CAT_NAME[a.def.category]} · ${a.def.description}${a.next ? ` · ${Math.min(a.value, a.next)}/${a.next}` : " · complete"}`, true)}
                {a.next ? <Bar value={a.value / a.next} height={3} /> : null}
              </View>
              <Pill label="CLAIM" disabled={!a.claimable} onPress={() => setErr(act((s, t) => claimAchievement(s, a.def.id, t)))} />
            </Row>
            {a.claimable && <RewardLine reward={a.def.tiers[a.claimed].reward} />}
          </Card>
        ))}
        <Card>{T.p(`${ach.filter((a) => a.concealed).length} secret chronicles remain hidden.`, true)}</Card>
      </Section>
    </Screen>
  );
}
