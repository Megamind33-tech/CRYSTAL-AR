// ARMORY — a city-builder style shop: category tabs, a grid of framed items, and a detail sheet to buy from.
// Coins are earned by finishing levels; nothing here costs real money.
import { useEffect, useRef, useState } from "react";
import { Pressable, ScrollView, StyleSheet, Text, useWindowDimensions, View } from "react-native";
import Animated, { FadeIn, FadeInDown, SlideInDown } from "react-native-reanimated";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import { BOOSTS, BOOST_SLOTS, CATEGORIES, type Boost, type BoostCategory, type BoostId } from "@/src/game/boosts";
import { buyBoostItem, metaStore } from "@/src/state/meta";
import { useStore } from "@/src/state/store";
import { BoostArt, RARITY_PAL } from "@/src/ui/BoostArt";
import { BoostTile } from "@/src/ui/BoostTile";
import { PressSpring, Screen } from "@/src/ui/kit";
import { LuxButton } from "@/src/ui/lux/Lux";
import { F, L } from "@/src/ui/lux/tokens";

const GAP = 12, PAD = 16, MIN_TILE = 150;

function CoinChip({ coins }: { coins: number }) {
  return (
    <View style={s.chip} testID="coins">
      <View style={s.coin} />
      <Text style={s.chipValue}>{coins.toLocaleString()}</Text>
    </View>
  );
}

function Tabs({ value, onChange, counts }: { value: BoostCategory | "all"; onChange: (v: BoostCategory | "all") => void; counts: Record<string, number> }) {
  const tabs = [{ id: "all" as const, name: "All" }, ...CATEGORIES];
  return (
    <View style={s.tabs}>
      {tabs.map((t) => {
        const on = value === t.id;
        return (
          <PressSpring key={t.id} onPress={() => onChange(t.id)} testID={`tab-${t.id}`} style={on ? { ...s.tab, ...s.tabOn } : s.tab}>
            <Text style={[s.tabTxt, on && s.tabTxtOn]}>{t.name}</Text>
            <Text style={[s.tabCount, on && s.tabTxtOn]}>{counts[t.id]}</Text>
          </PressSpring>
        );
      })}
    </View>
  );
}

function Detail({ boost, owned, coins, note, onBuy, onClose }: {
  boost: Boost; owned: number; coins: number; note: string | null; onBuy: () => void; onClose: () => void;
}) {
  const insets = useSafeAreaInsets();
  const pal = RARITY_PAL[boost.rarity];
  const afford = coins >= boost.cost;
  return (
    <View style={StyleSheet.absoluteFill} testID="detail">
      <Animated.View entering={FadeIn.duration(160)} style={s.scrim}>
        <Pressable style={StyleSheet.absoluteFill} onPress={onClose} accessibilityLabel="Close" />
      </Animated.View>
      <Animated.View entering={SlideInDown.duration(240)} style={[s.sheet, { paddingBottom: insets.bottom + 18, borderColor: pal.mid + "88" }]}>
        <View style={s.artWrap}><BoostArt boost={boost} size={176} /></View>
        <Text style={s.dName}>{boost.name}</Text>
        <View style={s.tags}>
          <Text style={[s.tag, { color: pal.hi, borderColor: pal.mid }]}>{boost.rarity.toUpperCase()}</Text>
          <Text style={[s.tag, { color: L.crystal, borderColor: "rgba(127,231,255,0.5)" }]}>{CATEGORIES.find((c) => c.id === boost.category)!.name.toUpperCase()}</Text>
        </View>
        <Text style={s.dDesc}>{boost.description}</Text>
        <View style={s.stats}>
          <View style={s.stat}><Text style={s.statL}>EFFECT</Text><Text style={s.statV}>{boost.effect}</Text></View>
          <View style={s.stat}><Text style={s.statL}>OWNED</Text><Text style={[s.statV, owned > 0 && { color: L.crystal }]} testID="detail-owned">{owned}</Text></View>
          <View style={s.stat}><Text style={s.statL}>SLOTS</Text><Text style={s.statV}>{BOOST_SLOTS} per run</Text></View>
        </View>
        {note ? <Text style={[s.note, note.startsWith("Not") && { color: L.danger }]}>{note}</Text> : <View style={{ height: 18 }} />}
        <View style={s.buyRow}>
          <PressSpring onPress={onClose} style={s.closeBtn} accessibilityLabel="Back"><Text style={s.closeTxt}>Back</Text></PressSpring>
          <LuxButton testID="buy" label={afford ? `Buy  ·  ${boost.cost}` : `Need ${boost.cost - coins} more`} variant={afford ? "gold" : "glass"} disabled={!afford} onPress={onBuy} style={{ flex: 1 }} />
        </View>
      </Animated.View>
    </View>
  );
}

export default function Armory() {
  const player = useStore(metaStore, (m) => m.player);
  const { width } = useWindowDimensions();
  const insets = useSafeAreaInsets();
  const [cat, setCat] = useState<BoostCategory | "all">("all");
  const [open, setOpen] = useState<BoostId | null>(null);
  const [note, setNote] = useState<string | null>(null);
  const timer = useRef<ReturnType<typeof setTimeout> | null>(null);
  useEffect(() => () => { if (timer.current) clearTimeout(timer.current); }, []);
  if (!player) return null;

  const coins = player.wallet.coins ?? 0;
  const all = Object.values(BOOSTS).sort((a, b) => a.cost - b.cost);
  const shown = cat === "all" ? all : all.filter((b) => b.category === cat);
  const counts: Record<string, number> = { all: all.length };
  for (const c of CATEGORIES) counts[c.id] = all.filter((b) => b.category === c.id).length;
  const cols = Math.max(2, Math.floor((width - PAD * 2 + GAP) / (MIN_TILE + GAP)));
  const tile = Math.floor((width - PAD * 2 - GAP * (cols - 1)) / cols);

  const buy = (id: BoostId) => {
    const err = buyBoostItem(id);
    setNote(err ? `Not enough coins` : "Added to your armory");
    if (timer.current) clearTimeout(timer.current);
    timer.current = setTimeout(() => setNote(null), 2200);
  };
  const close = () => { setOpen(null); setNote(null); };

  return (
    <View style={{ flex: 1 }}>
      <Screen title="Armory" subtitle="Boosts for your next run" right={<CoinChip coins={coins} />}>
        <Tabs value={cat} onChange={setCat} counts={counts} />
        <View style={s.grid} testID="grid">
          {shown.map((boost, i) => (
            <Animated.View key={boost.id} entering={FadeInDown.delay(i * 40).duration(260)}>
              <BoostTile boost={boost} width={tile} owned={player.items[boost.id] ?? 0} canAfford={coins >= boost.cost} onPress={() => setOpen(boost.id)} />
            </Animated.View>
          ))}
        </View>
        <Text style={s.foot}>Equip up to {BOOST_SLOTS} boosts before a level. Each is used up when the level begins. Finish levels to earn coins.</Text>
      </Screen>
      {open && <Detail boost={BOOSTS[open]} owned={player.items[open] ?? 0} coins={coins} note={note} onBuy={() => buy(open)} onClose={close} />}
      <View style={{ height: 0, marginBottom: insets.bottom }} />
    </View>
  );
}

const s = StyleSheet.create({
  grid: { flexDirection: "row", flexWrap: "wrap", gap: GAP },
  tabs: { flexDirection: "row", gap: 8 },
  tab: { flexDirection: "row", alignItems: "center", gap: 6, paddingHorizontal: 14, paddingVertical: 8, borderRadius: 18, backgroundColor: "rgba(20,26,61,0.85)", borderWidth: 1, borderColor: "rgba(246,211,138,0.25)" },
  tabOn: { backgroundColor: L.goldPale, borderColor: L.goldLight },
  tabTxt: { fontFamily: F.bodyStrong, fontSize: 13, color: L.ivory },
  tabTxtOn: { color: L.ink },
  tabCount: { fontFamily: F.body, fontSize: 11, color: L.mistDim },
  chip: { flexDirection: "row", alignItems: "center", gap: 7, paddingHorizontal: 12, paddingVertical: 7, borderRadius: 16, backgroundColor: "rgba(20,26,61,0.9)", borderWidth: 1, borderColor: "rgba(246,211,138,0.5)" },
  coin: { width: 12, height: 12, borderRadius: 6, backgroundColor: L.goldPale, borderWidth: 1, borderColor: L.goldDeep },
  chipValue: { fontFamily: F.number, fontSize: 14, color: L.goldLight },
  foot: { fontFamily: F.body, fontSize: 12, lineHeight: 17, color: L.mistDim, textAlign: "center", marginTop: 4 },
  scrim: { ...StyleSheet.absoluteFill, backgroundColor: "rgba(3,4,16,0.66)" },
  sheet: { position: "absolute", left: 0, right: 0, bottom: 0, alignItems: "center", paddingTop: 20, paddingHorizontal: 18, borderTopLeftRadius: 28, borderTopRightRadius: 28, borderTopWidth: 1, backgroundColor: "rgba(11,14,36,0.98)" },
  artWrap: { marginTop: -70 },
  dName: { fontFamily: F.title, fontSize: 22, color: L.goldPale, marginTop: 12, textAlign: "center" },
  tags: { flexDirection: "row", gap: 8, marginTop: 8 },
  tag: { fontFamily: F.bodyStrong, fontSize: 10, letterSpacing: 1.2, paddingHorizontal: 10, paddingVertical: 3, borderRadius: 10, borderWidth: 1, overflow: "hidden" },
  dDesc: { fontFamily: F.body, fontSize: 14, lineHeight: 20, color: L.mist, textAlign: "center", marginTop: 12 },
  stats: { flexDirection: "row", alignSelf: "stretch", marginTop: 14, borderRadius: 14, backgroundColor: "rgba(255,255,255,0.05)", borderWidth: 1, borderColor: "rgba(246,211,138,0.16)" },
  stat: { flex: 1, alignItems: "center", paddingVertical: 10, gap: 2 },
  statL: { fontFamily: F.body, fontSize: 9, letterSpacing: 1.4, color: L.mistDim },
  statV: { fontFamily: F.bold, fontSize: 13, color: L.ivory },
  note: { fontFamily: F.bodyStrong, fontSize: 13, color: L.crystal, marginTop: 10, height: 18 },
  buyRow: { flexDirection: "row", alignItems: "center", gap: 12, alignSelf: "stretch", marginTop: 4 },
  closeBtn: { paddingHorizontal: 14, paddingVertical: 12 },
  closeTxt: { fontFamily: F.bodyStrong, fontSize: 14, color: L.aether },
});
