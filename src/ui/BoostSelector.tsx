// Boost selector: choose which boosts to equip before a level starts.
import { useState } from "react";
import { Pressable, ScrollView, StyleSheet, Text, View } from "react-native";
import Animated, { FadeIn, FadeOut } from "react-native-reanimated";
import { BOOSTS, type BoostId } from "@/src/game/boosts";
import { PressSpring } from "./kit";
import { LuxButton } from "./lux/Lux";
import { F, L } from "./lux/tokens";

const styles = StyleSheet.create({
  container: { padding: 16, backgroundColor: "rgba(0,0,0,0.8)", borderRadius: 12, marginHorizontal: 12, marginBottom: 12 },
  title: { fontSize: 16, fontFamily: "CinzelBold", color: L.crystal, marginBottom: 12 },
  grid: { gap: 8 },
  boostRow: { flexDirection: "row", alignItems: "center", justifyContent: "space-between", backgroundColor: "#0f0f2e", paddingHorizontal: 12, paddingVertical: 10, borderRadius: 8, borderLeftWidth: 2 },
  boostRare: { borderLeftColor: "#ffd0a0" },
  boostUncommon: { borderLeftColor: "#a0d0ff" },
  boostCommon: { borderLeftColor: "#90f090" },
  boostInfo: { flex: 1, marginLeft: 8 },
  boostName: { fontSize: 13, fontFamily: "PoppinsBold", color: "#ffffff" },
  boostDesc: { fontSize: 11, fontFamily: "PoppinsMedium", color: "#b0b0d0", marginTop: 2 },
  icon: { fontSize: 18 },
  checkbox: { width: 24, height: 24, borderRadius: 4, borderWidth: 2, borderColor: L.crystal, alignItems: "center", justifyContent: "center" },
  checkboxChecked: { backgroundColor: L.crystal },
  checkmark: { fontSize: 12, color: L.night900, fontFamily: "PoppinsBold" },
  footer: { flexDirection: "row", justifyContent: "space-between", alignItems: "center", marginTop: 12, paddingTop: 12, borderTopWidth: 1, borderTopColor: "#333366" },
  coinsUsed: { fontSize: 12, fontFamily: "PoppinsMedium", color: L.goldPale },
  button: { flex: 1, marginLeft: 12 },
});

export function BoostSelector({ ownedBoosts, onEquip }: { ownedBoosts: Record<string, number>; onEquip: (boosts: BoostId[]) => void }) {
  const [equipped, setEquipped] = useState<BoostId[]>([]);
  const coinsUsed = equipped.reduce((sum, id) => sum + BOOSTS[id].cost, 0);

  const toggle = (id: BoostId) => {
    setEquipped((e) => (e.includes(id) ? e.filter((x) => x !== id) : [...e, id]));
  };

  const canEquip = (id: BoostId) => (ownedBoosts[id] ?? 0) > 0;
  const boostList = Object.values(BOOSTS).sort((a, b) => a.cost - b.cost);

  return (
    <Animated.View entering={FadeIn} exiting={FadeOut} style={styles.container}>
      <Text style={styles.title}>Equip Boosts</Text>
      <ScrollView style={styles.grid} scrollEnabled={false}>
        {boostList.map((boost) => {
          const isEquipped = equipped.includes(boost.id);
          const owned = ownedBoosts[boost.id] ?? 0;
          const rarityStyle =
            boost.rarity === "rare" ? styles.boostRare : boost.rarity === "uncommon" ? styles.boostUncommon : styles.boostCommon;
          return (
            <Animated.View key={boost.id} entering={FadeIn.delay(boostList.indexOf(boost) * 30)}>
              <PressSpring
                onPress={() => canEquip(boost.id) && toggle(boost.id)}
                disabled={!canEquip(boost.id)}
                style={[styles.boostRow, rarityStyle]}>
                <View style={{ flexDirection: "row", flex: 1, alignItems: "center" }}>
                  <Text style={styles.icon}>{boost.icon}</Text>
                  <View style={styles.boostInfo}>
                    <Text style={styles.boostName}>{boost.name}</Text>
                    <Text style={styles.boostDesc}>{boost.description}</Text>
                  </View>
                </View>
                <View style={[styles.checkbox, isEquipped && styles.checkboxChecked]}>
                  {isEquipped && <Text style={styles.checkmark}>✓</Text>}
                </View>
              </PressSpring>
            </Animated.View>
          );
        })}
      </ScrollView>
      <View style={styles.footer}>
        <Text style={styles.coinsUsed}>Cost: {coinsUsed} coins</Text>
        <View style={styles.button}>
          <LuxButton label="Start Level" onPress={() => onEquip(equipped)} />
        </View>
      </View>
    </Animated.View>
  );
}
