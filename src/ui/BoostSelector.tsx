// Pre-match loadout: pick up to BOOST_SLOTS owned boosts. Each one equipped is used up when the run starts.
import { useState } from "react";
import { ScrollView, StyleSheet, Text, View } from "react-native";
import Animated, { FadeIn } from "react-native-reanimated";
import { useRouter } from "expo-router";
import { BOOSTS, BOOST_SLOTS, type BoostId } from "@/src/game/boosts";
import { BoostCard } from "./BoostCard";
import { PressSpring } from "./kit";
import { LuxButton } from "./lux/Lux";
import { F, L } from "./lux/tokens";

export function BoostSelector({ ownedBoosts, onEquip }: { ownedBoosts: Record<string, number>; onEquip: (boosts: BoostId[]) => void }) {
  const router = useRouter();
  const [equipped, setEquipped] = useState<BoostId[]>([]);
  const list = Object.values(BOOSTS).filter((b) => (ownedBoosts[b.id] ?? 0) > 0).sort((a, b) => a.cost - b.cost);
  const full = equipped.length >= BOOST_SLOTS;

  const toggle = (id: BoostId) => setEquipped((e) => (e.includes(id) ? e.filter((x) => x !== id) : e.length >= BOOST_SLOTS ? e : [...e, id]));

  return (
    <View style={s.scrim} pointerEvents="box-none">
      <Animated.View entering={FadeIn.duration(180)} style={s.sheet}>
        <View style={s.head}>
          <Text style={s.title}>Prepare your run</Text>
          <Text style={s.slots}>{equipped.length}/{BOOST_SLOTS} equipped</Text>
        </View>
        <Text style={s.hint}>Equipped boosts are used up when the level begins.</Text>
        <ScrollView style={s.list} contentContainerStyle={s.listContent} showsVerticalScrollIndicator={false}>
          {list.map((boost) => {
            const on = equipped.includes(boost.id);
            return (
              <BoostCard
                key={boost.id}
                boost={boost}
                owned={ownedBoosts[boost.id]}
                selected={on}
                disabled={!on && full}
                onPress={() => toggle(boost.id)}
                testID={`equip-${boost.id}`}
                right={<View style={[s.check, on && s.checkOn]}>{on && <Text style={s.tick}>✓</Text>}</View>}
              />
            );
          })}
        </ScrollView>
        <View style={s.foot}>
          <PressSpring onPress={() => router.push("/store")} style={s.link} accessibilityLabel="Visit the Armory">
            <Text style={s.linkText}>Armory</Text>
          </PressSpring>
          <LuxButton testID="start-level" label={equipped.length ? "Begin with boosts" : "Begin"} onPress={() => onEquip(equipped)} style={s.go} />
        </View>
      </Animated.View>
    </View>
  );
}

const s = StyleSheet.create({
  scrim: { ...StyleSheet.absoluteFill, justifyContent: "flex-end", backgroundColor: "rgba(4,5,18,0.55)" },
  sheet: { maxHeight: "72%", padding: 16, paddingBottom: 24, borderTopLeftRadius: 26, borderTopRightRadius: 26, backgroundColor: "rgba(11,14,36,0.97)", borderTopWidth: 1, borderColor: "rgba(246,211,138,0.3)" },
  head: { flexDirection: "row", alignItems: "baseline", justifyContent: "space-between" },
  title: { fontFamily: F.title, fontSize: 20, color: L.goldPale },
  slots: { fontFamily: F.bodyStrong, fontSize: 12, color: L.crystal },
  hint: { fontFamily: F.body, fontSize: 12, color: L.mist, marginTop: 2, marginBottom: 10 },
  list: { flexGrow: 0 },
  listContent: { gap: 10, paddingBottom: 6 },
  check: { width: 26, height: 26, borderRadius: 13, borderWidth: 2, borderColor: L.mistDim, alignItems: "center", justifyContent: "center" },
  checkOn: { backgroundColor: L.crystal, borderColor: L.crystal },
  tick: { fontFamily: F.bold, fontSize: 14, color: L.night900 },
  foot: { flexDirection: "row", alignItems: "center", gap: 12, marginTop: 14 },
  link: { paddingHorizontal: 14, paddingVertical: 12 },
  linkText: { fontFamily: F.bodyStrong, fontSize: 14, color: L.aether },
  go: { flex: 1 },
});
