// ARMORY — spend coins on pre-match boosts. Coins are earned by finishing levels; nothing here costs real money.
import { useEffect, useRef, useState } from "react";
import { StyleSheet, Text, View } from "react-native";
import { BOOSTS, BOOST_SLOTS, type BoostId } from "@/src/game/boosts";
import { buyBoostItem, metaStore } from "@/src/state/meta";
import { useStore } from "@/src/state/store";
import { BoostCard } from "@/src/ui/BoostCard";
import { ErrorLine, Screen, T } from "@/src/ui/kit";
import { LuxButton } from "@/src/ui/lux/Lux";
import { F, L } from "@/src/ui/lux/tokens";

function CoinChip({ coins }: { coins: number }) {
  return (
    <View style={s.chip} testID="coins">
      <Text style={s.chipGlyph}>●</Text>
      <Text style={s.chipValue}>{coins.toLocaleString()}</Text>
    </View>
  );
}

export default function Armory() {
  const player = useStore(metaStore, (m) => m.player);
  const [msg, setMsg] = useState<{ text: string; ok: boolean } | null>(null);
  const timer = useRef<ReturnType<typeof setTimeout> | null>(null);
  useEffect(() => () => { if (timer.current) clearTimeout(timer.current); }, []);
  if (!player) return null;

  const coins = player.wallet.coins ?? 0;
  const list = Object.values(BOOSTS).sort((a, b) => a.cost - b.cost);

  const buy = (id: BoostId) => {
    const err = buyBoostItem(id);
    setMsg(err ? { text: err, ok: false } : { text: `${BOOSTS[id].name} added to your armory`, ok: true });
    if (timer.current) clearTimeout(timer.current);
    timer.current = setTimeout(() => setMsg(null), 2600);
  };

  return (
    <Screen title="Armory" subtitle="Boosts for your next run" right={<CoinChip coins={coins} />}>
      {T.p(`Pick up to ${BOOST_SLOTS} owned boosts before a level begins. Each one you equip is used up, so choose the runs that matter. Finishing a level earns coins.`, true)}
      {msg && (msg.ok ? <Text style={s.ok}>{msg.text}</Text> : <ErrorLine msg={msg.text} />)}
      <View style={s.list}>
        {list.map((boost) => {
          const owned = player.items[boost.id] ?? 0;
          const afford = coins >= boost.cost;
          return (
            <BoostCard
              key={boost.id}
              boost={boost}
              owned={owned}
              testID={`boost-${boost.id}`}
              right={
                <View style={s.buy}>
                  <LuxButton
                    testID={`buy-${boost.id}`}
                    label={`${boost.cost}`}
                    variant={afford ? "gold" : "glass"}
                    disabled={!afford}
                    onPress={() => buy(boost.id)}
                  />
                </View>
              }
            />
          );
        })}
      </View>
      {coins < list[0].cost && <Text style={s.hint}>Not enough coins yet. Restore an island to earn more.</Text>}
    </Screen>
  );
}

const s = StyleSheet.create({
  list: { gap: 10 },
  buy: { minWidth: 84 },
  chip: { flexDirection: "row", alignItems: "center", gap: 6, paddingHorizontal: 12, paddingVertical: 7, borderRadius: 16, backgroundColor: "rgba(20,26,61,0.9)", borderWidth: 1, borderColor: "rgba(246,211,138,0.5)" },
  chipGlyph: { fontSize: 12, color: L.goldPale },
  chipValue: { fontFamily: F.number, fontSize: 14, color: L.goldLight },
  ok: { fontFamily: F.bodyStrong, fontSize: 13, color: L.crystal },
  hint: { fontFamily: F.body, fontSize: 12, color: L.mistDim, textAlign: "center" },
});
