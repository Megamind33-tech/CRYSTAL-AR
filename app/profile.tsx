import { useState } from "react";
import { Pressable, Text, View } from "react-native";
import { LUMINS, RARITY_ORDER } from "@/src/meta/config/collection";
import { leagueName } from "@/src/meta/competition";
import { keeperLevel } from "@/src/meta/core";
import { passStatus } from "@/src/meta/live";
import { achievementScore, achievementStatus, claimAchievement, sanctuaryRating } from "@/src/meta/progression";
import { act, metaStore, setPlayer } from "@/src/state/meta";
import { useStore } from "@/src/state/store";
import { DIMENSION_LABEL, keeperRank, RANKS, type Dimension } from "@/src/meta/rank";
import { Bar, Card, ErrorLine, Field, Pill, RewardLine, Row, Screen, Section, Stat, T } from "@/src/ui/kit";
import { useLoop } from "@/src/ui/lux/Lux";
import { F, L, titleGlow } from "@/src/ui/lux/tokens";
import Animated, { useAnimatedStyle } from "react-native-reanimated";

const CAT_NAME: Record<string, string> = { explorer: "Explorer", restorer: "Restorer", collector: "Collector", master: "Master", keeper: "Keeper", champion: "Champion", loyalty: "Loyalty", secrets: "Secrets" };

export default function Profile() {
  const p = useStore(metaStore, (m) => m.player);
  const [err, setErr] = useState<string | null>(null);
  const [editing, setEditing] = useState(false);
  const [name, setName] = useState("");
  const t = useLoop(3000);
  const halo = useAnimatedStyle(() => ({ opacity: 0.35 + Math.sin(t.value * Math.PI * 2) * 0.2, transform: [{ scale: 1 + Math.sin(t.value * Math.PI * 2) * 0.05 }] }));
  if (!p) return null;
  const now = Date.now();
  const lvl = keeperLevel(p.keeperXp);
  const pass = passStatus(p, now);
  const rare = LUMINS.filter((l) => p.lumins[l.id] && RARITY_ORDER.indexOf(l.rarity) >= 2);
  const ach = achievementStatus(p);


  const rank = keeperRank(p);
  return (
    <Screen title="Keeper" subtitle={`${rank.name} · ${p.profile.title}`}>
      <ErrorLine msg={err} />
      <Card style={{ alignItems: "center", gap: 8, paddingVertical: 20, borderColor: "rgba(246,211,138,0.85)" }}>
        <View style={{ width: 92, height: 92, alignItems: "center", justifyContent: "center" }}>
          <Animated.View style={[{ position: "absolute", width: 88, height: 88, borderRadius: 44, backgroundColor: L.gold, shadowColor: "#ffcf6a", shadowRadius: 18, shadowOpacity: 1 }, halo]} />
          <View style={{ width: 78, height: 78, borderRadius: 39, padding: 3, backgroundColor: L.gold, borderWidth: 1, borderColor: L.goldLight }}>
            <View style={{ flex: 1, borderRadius: 36, backgroundColor: L.night700, alignItems: "center", justifyContent: "center", borderWidth: 1, borderColor: "rgba(127,231,255,0.4)" }}>
              <Text style={{ color: L.goldLight, fontSize: 34, fontFamily: F.display, ...titleGlow("#ffcf6a", 12) }}>{p.profile.keeperName[0]}</Text>
            </View>
          </View>
        </View>
        {editing ? (
          <Row>
            <Field value={name} onChangeText={setName} maxLength={16} autoFocus placeholder="Keeper name" style={{ minWidth: 150 }} />
            <Pill label="SAVE" onPress={() => {
              const clean = name.trim().replace(/[^\p{L}\p{N} _-]/gu, "");
              if (clean.length >= 2) setPlayer((s) => ({ ...s, profile: { ...s.profile, keeperName: clean } }));
              setEditing(false);
            }} />
          </Row>
        ) : (
          <Pressable onPress={() => { setName(p.profile.keeperName); setEditing(true); }}>
            <Text style={{ color: L.goldLight, fontSize: 22, fontFamily: F.title, letterSpacing: 1, ...titleGlow("#ffcf6a", 10) }}>{p.profile.keeperName} <Text style={{ color: L.mist, fontSize: 15 }}>✎</Text></Text>
          </Pressable>
        )}
        <Text style={{ color: L.crystal, fontFamily: F.title, fontSize: 12, letterSpacing: 1.6 }}>KEEPER {lvl.level} · {leagueName(p.league.id).toUpperCase()}</Text>
        <View style={{ width: "80%" }}><Bar value={lvl.progress} /></View>
        <Text style={{ color: L.mist, fontSize: 11.5, fontFamily: F.body }}>{lvl.into} / {lvl.need} XP to level {lvl.level + 1}</Text>
      </Card>

      <Card>
        <View style={{ flexDirection: "row", flexWrap: "wrap", rowGap: 4 }}>
          <Stat label="Heart Shards" value={p.heartShards.length} />
          <Stat label="Islands restored" value={Object.keys(p.islands).length} />
          <Stat label="Lumins rescued" value={Object.keys(p.lumins).length} />
          <Stat label="Relics found" value={Object.keys(p.relics).length} />
          <Stat label="Chronicle score" value={achievementScore(p)} />
          <Stat label="Return streak" value={p.checkin.streak} />
          <Stat label="Resonance" value={p.stats.resonance.toLocaleString()} />
          <Stat label="Longest chain" value={p.stats.bestCascade} />
          <Stat label="Trophies" value={p.trophies.length} />
          <Stat label="Sanctuary" value={`${sanctuaryRating(p).pct}%`} />
          <Stat label="Season level" value={pass?.tier ?? "–"} />
          <Stat label="Rare Lumins" value={rare.map((l) => l.name).join(", ") || "–"} />
        </View>
      </Card>

      <Section title="Keeper Rank" note={`${rank.index + 1} of ${RANKS.length}`}>
        <Card>
          {T.h(rank.name)}
          <Bar value={rank.score} color={L.gold} />
          {(Object.keys(rank.dimensions) as Dimension[]).map((k) => (
            <Row key={k} style={{ justifyContent: "space-between" }}>
              <Text style={{ color: L.mist, fontSize: 12.5, fontFamily: F.body }}>{DIMENSION_LABEL[k]}</Text>
              <View style={{ width: 120 }}>
                <Bar value={rank.dimensions[k]} color={L.crystal} height={5} />
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
