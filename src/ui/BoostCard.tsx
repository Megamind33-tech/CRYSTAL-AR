// One boost, drawn the same way in the Armory and in the pre-match loadout.
import type { ReactNode } from "react";
import { StyleSheet, Text, View } from "react-native";
import type { Boost } from "@/src/game/boosts";
import { BoostArt, RARITY_PAL } from "./BoostArt";
import { PressSpring } from "./kit";
import { F, L } from "./lux/tokens";

export const RARITY: Record<Boost["rarity"], { color: string; label: string }> = {
  common: { color: "#8fe6a4", label: "Common" },
  uncommon: { color: "#7fc4ff", label: "Uncommon" },
  rare: { color: "#ffc27a", label: "Rare" },
};

export function BoostCard({ boost, owned, selected, disabled, onPress, right, testID }: {
  boost: Boost; owned?: number; selected?: boolean; disabled?: boolean; onPress?: () => void; right?: ReactNode; testID?: string;
}) {
  const r = RARITY[boost.rarity];
  const style = [s.card, { borderColor: selected ? L.crystal : "rgba(246,211,138,0.18)", backgroundColor: selected ? "rgba(127,231,255,0.16)" : RARITY_PAL[boost.rarity].card + "e6" }];
  const content = (
    <>
      <BoostArt boost={boost} size={64} animate={false} />
      <View style={s.body}>
        <Text style={s.name}>{boost.name}</Text>
        <Text style={s.desc}>{boost.description}</Text>
        <Text style={s.meta}>
          <Text style={{ color: r.color }}>{r.label.toUpperCase()}</Text>
          {owned !== undefined && <Text style={owned > 0 ? { color: L.crystal } : undefined}>{owned > 0 ? `   Owned ×${owned}` : "   Not owned"}</Text>}
        </Text>
      </View>
      {right}
    </>
  );
  // a card with nothing to press must not be a (disabled) Pressable: that would swallow taps on its own buttons
  if (!onPress) return <View testID={testID} style={style}>{content}</View>;
  return (
    <PressSpring onPress={onPress} disabled={disabled} testID={testID} accessibilityLabel={boost.name} style={style}>
      {content}
    </PressSpring>
  );
}

const s = StyleSheet.create({
  card: { flexDirection: "row", alignItems: "center", gap: 12, padding: 12, borderRadius: 16, borderWidth: 1 },
  badge: { width: 46, height: 46, borderRadius: 23, borderWidth: 1.5, alignItems: "center", justifyContent: "center", backgroundColor: "rgba(7,9,32,0.7)" },
  icon: { fontSize: 18, color: L.ivory },
  body: { flex: 1, gap: 2 },
  name: { fontFamily: F.bold, fontSize: 14, color: L.ivory },
  desc: { fontFamily: F.body, fontSize: 12, lineHeight: 17, color: L.mist },
  meta: { fontFamily: F.bodyStrong, fontSize: 10, letterSpacing: 0.8, color: L.mistDim, marginTop: 3 },
});
