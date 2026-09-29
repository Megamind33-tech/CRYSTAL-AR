// STORE — Buy boosts and manage your inventory. Coins earned from levels, no real money here.
import { useState } from "react";
import { Pressable, ScrollView, StyleSheet, Text, View } from "react-native";
import { useRouter } from "expo-router";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import Animated, { FadeIn, FadeOut } from "react-native-reanimated";
import { useStore } from "@/src/state/store";
import { metaStore } from "@/src/state/meta";
import { BOOSTS, type BoostId } from "@/src/game/boosts";
import { PressSpring } from "@/src/ui/kit";
import { LuxButton, NightSky } from "@/src/ui/lux/Lux";
import { F, L } from "@/src/ui/lux/tokens";

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: L.night900 },
  header: { padding: 16, paddingTop: 12, paddingBottom: 24 },
  title: { fontSize: 28, fontFamily: "CinzelBlack", color: L.crystal, marginBottom: 4 },
  walletRow: { flexDirection: "row", gap: 16, marginTop: 12 },
  walletItem: { flexDirection: "row", alignItems: "center", gap: 8, backgroundColor: "#1a1a3e", paddingHorizontal: 12, paddingVertical: 8, borderRadius: 8 },
  walletLabel: { fontSize: 12, fontFamily: "PoppinsMedium", color: L.aether },
  walletValue: { fontSize: 16, fontFamily: "PoppinsBold", color: L.goldPale },
  grid: { paddingHorizontal: 12, paddingBottom: 20, gap: 12 },
  card: { backgroundColor: "#0f0f2e", borderRadius: 12, padding: 12, borderLeftWidth: 3 },
  cardRare: { borderLeftColor: "#ffd0a0" },
  cardUncommon: { borderLeftColor: "#a0d0ff" },
  cardCommon: { borderLeftColor: "#90f090" },
  cardHeader: { flexDirection: "row", justifyContent: "space-between", alignItems: "flex-start", marginBottom: 8 },
  icon: { fontSize: 24 },
  name: { fontSize: 14, fontFamily: "PoppinsBold", color: "#ffffff", flex: 1, marginLeft: 8 },
  desc: { fontSize: 12, fontFamily: "PoppinsMedium", color: "#b0b0d0", marginBottom: 8 },
  footer: { flexDirection: "row", justifyContent: "space-between", alignItems: "center" },
  cost: { fontSize: 13, fontFamily: "PoppinsBold", color: L.goldPale },
  button: { paddingHorizontal: 12, paddingVertical: 6 },
  buttonText: { fontSize: 12, fontFamily: "PoppinsBold" },
  backButton: { paddingHorizontal: 16, paddingVertical: 8, marginBottom: 12 },
  backText: { fontSize: 14, fontFamily: "PoppinsMedium", color: L.aether },
});

export default function Store() {
  const router = useRouter();
  const insets = useSafeAreaInsets();
  const player = useStore(metaStore, (s) => s.player);
  const coins = player?.wallet.coins ?? 0;
  const ownedBoosts = (player?.items ?? {}) as Record<string, number>;
  const [purchasing, setPurchasing] = useState<BoostId | null>(null);

  const buy = async (boostId: BoostId) => {
    if (!player) return;
    const boost = BOOSTS[boostId];
    if (coins < boost.cost) return; // not enough coins
    setPurchasing(boostId);
    // Simulate purchase delay
    await new Promise((r) => setTimeout(r, 300));
    try {
      metaStore.set((s) => {
        if (!s.player) return s;
        return {
          ...s,
          player: {
            ...s.player,
            wallet: { ...s.player.wallet, coins: s.player.wallet.coins - boost.cost },
            items: { ...s.player.items, [boostId]: (s.player.items[boostId] ?? 0) + 1 },
          },
        };
      });
    } finally {
      setPurchasing(null);
    }
  };

  const boostList = Object.values(BOOSTS).sort((a, b) => a.cost - b.cost);

  return (
    <View style={[styles.container, { paddingTop: insets.top }]}>
      <NightSky tint={L.goldPale} accent={L.crystal} />
      <ScrollView contentContainerStyle={{ flexGrow: 1 }} scrollEnabled={false}>
        <View style={styles.header}>
          <Text style={styles.title}>Keeper's Armory</Text>
          <View style={styles.walletRow}>
            <View style={styles.walletItem}>
              <Text style={{ fontSize: 14 }}>🪙</Text>
              <View>
                <Text style={styles.walletLabel}>Coins</Text>
                <Text style={styles.walletValue}>{coins.toLocaleString()}</Text>
              </View>
            </View>
          </View>
        </View>
        <ScrollView style={styles.grid} scrollEnabled>
          {boostList.map((boost) => {
            const owned = ownedBoosts[boost.id] ?? 0;
            const canAfford = coins >= boost.cost;
            const rarityStyle = boost.rarity === "rare" ? styles.cardRare : boost.rarity === "uncommon" ? styles.cardUncommon : styles.cardCommon;
            const isLoading = purchasing === boost.id;
            return (
              <Animated.View key={boost.id} entering={FadeIn.delay(boostList.indexOf(boost) * 50)} exiting={FadeOut}>
                <PressSpring onPress={() => buy(boost.id)} disabled={!canAfford || isLoading} style={[styles.card, rarityStyle]}>
                  <View style={styles.cardHeader}>
                    <Text style={styles.icon}>{boost.icon}</Text>
                    <Text style={styles.name}>{boost.name}</Text>
                  </View>
                  <Text style={styles.desc}>{boost.description}</Text>
                  <View style={styles.footer}>
                    <View>
                      <Text style={styles.cost}>{boost.cost} coins</Text>
                      {owned > 0 && <Text style={{ fontSize: 11, color: "#88ff88", fontFamily: "PoppinsMedium" }}>Owned: {owned}</Text>}
                    </View>
                    <LuxButton
                      label={isLoading ? "..." : canAfford ? "Buy" : "Need " + (boost.cost - coins)}
                      disabled={!canAfford || isLoading}
                      variant={canAfford ? "gold" : "glass"}
                    />
                  </View>
                </PressSpring>
              </Animated.View>
            );
          })}
        </ScrollView>
      </ScrollView>
      <View style={{ paddingHorizontal: 12, paddingBottom: insets.bottom + 12 }}>
        <PressSpring onPress={() => router.back()} style={styles.backButton}>
          <Text style={styles.backText}>← Back</Text>
        </PressSpring>
      </View>
    </View>
  );
}
