// One grid tile of the Armory: framed art, name, and a price / owned plate. City-builder shop style.
import { StyleSheet, Text, View } from "react-native";
import type { Boost } from "@/src/game/boosts";
import { BoostArt, RARITY_PAL } from "./BoostArt";
import { PressSpring } from "./kit";
import { F, L } from "./lux/tokens";

export function BoostTile({ boost, width, owned, canAfford, onPress }: {
  boost: Boost; width: number; owned: number; canAfford: boolean; onPress: () => void;
}) {
  const pal = RARITY_PAL[boost.rarity];
  return (
    <PressSpring onPress={onPress} testID={`tile-${boost.id}`} accessibilityLabel={boost.name} style={{ width }}>
      <View style={[s.tile, { borderColor: pal.mid + "88", shadowColor: pal.glow, backgroundColor: pal.card }]}>
        <View>
          <BoostArt boost={boost} size={width - 2} />
          {owned > 0 && (
            <View style={[s.owned, { backgroundColor: pal.mid, borderColor: pal.hi }]}>
              <Text style={s.ownedTxt}>×{owned}</Text>
            </View>
          )}
        </View>
        <View style={[s.info, { backgroundColor: pal.bottom + "88" }]}>
          <Text style={s.name} numberOfLines={1}>{boost.name}</Text>
          <Text style={[s.effect, { color: pal.hi }]} numberOfLines={1}>{boost.effect}</Text>
          <View style={[s.price, !canAfford && s.priceDim]}>
            <View style={s.coin} />
            <Text style={[s.priceTxt, !canAfford && { color: L.mistDim }]}>{boost.cost.toLocaleString()}</Text>
          </View>
        </View>
      </View>
    </PressSpring>
  );
}

const s = StyleSheet.create({
  tile: { borderRadius: 18, borderWidth: 1, overflow: "hidden", shadowOpacity: 0.35, shadowRadius: 12, shadowOffset: { width: 0, height: 4 } },
  info: { padding: 10, gap: 2 },
  name: { fontFamily: F.bold, fontSize: 13, color: L.ivory },
  effect: { fontFamily: F.bodyStrong, fontSize: 11, letterSpacing: 0.4 },
  price: { flexDirection: "row", alignItems: "center", gap: 6, marginTop: 6, alignSelf: "flex-start", paddingHorizontal: 10, paddingVertical: 4, borderRadius: 12, backgroundColor: "rgba(246,211,138,0.14)", borderWidth: 1, borderColor: "rgba(246,211,138,0.5)" },
  priceDim: { backgroundColor: "rgba(255,255,255,0.05)", borderColor: "rgba(255,255,255,0.14)" },
  coin: { width: 10, height: 10, borderRadius: 5, backgroundColor: L.goldPale, borderWidth: 1, borderColor: L.goldDeep },
  priceTxt: { fontFamily: F.number, fontSize: 13, color: L.goldLight },
  owned: { position: "absolute", top: 8, right: 8, minWidth: 30, paddingHorizontal: 7, paddingVertical: 2, borderRadius: 11, borderWidth: 1, alignItems: "center" },
  ownedTxt: { fontFamily: F.number, fontSize: 12, color: "#06081c" },
});
