import { useState } from "react";
import { StyleSheet, Text, View } from "react-native";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import Animated, { FadeInDown, FadeOut, useAnimatedStyle } from "react-native-reanimated";
import { RELICS } from "../meta/config/collection";
import { relicCharges, activateRelic } from "../meta/progression";
import type { RunBoost } from "../meta/types";
import { gameStore, applyRelicEffect } from "../state/game";
import { act, metaStore } from "../state/meta";
import { useStore } from "../state/store";
import { PressSpring } from "./kit";
import { useLoop } from "./lux/Lux";
import { F, L, titleGlow } from "./lux/tokens";

const GLYPH: Record<string, string> = { hint: "◉", addMoves: "⧗", reshuffle: "✥" };
const TONE: Record<string, string> = { hint: L.crystal, addMoves: L.goldLight, reshuffle: L.rose };
const KIND: Record<string, RunBoost["kind"]> = { hint: "hint", addMoves: "moves", reshuffle: "reshuffle" };

/** A breathing relic orb: tinted core, gold ring, charge badge. */
function RelicOrb({ glyph, tone, charges, off }: { glyph: string; tone: string; charges: number; off: boolean }) {
  const t = useLoop(2600);
  const halo = useAnimatedStyle(() => ({ opacity: off ? 0 : 0.35 + Math.sin(t.value * Math.PI * 2) * 0.25 }));
  return (
    <View style={[s.orb, off && { opacity: 0.4 }]}>
      <Animated.View pointerEvents="none" style={[s.halo, { backgroundColor: tone, shadowColor: tone }, halo]} />
      <View style={[s.core, { borderColor: tone }]}>
        <Text style={[s.glyph, { color: tone }, titleGlow(tone, 10)]}>{glyph}</Text>
      </View>
      <View style={s.badge}>
        <Text style={s.count}>{charges}</Text>
      </View>
    </View>
  );
}

/** Relics usable during a run. Board-changing relics are unranked; Trials allow only approved ones. */
export function RelicTray({ ranked }: { ranked: boolean }) {
  const insets = useSafeAreaInsets();
  const p = useStore(metaStore, (m) => m.player);
  const busy = useStore(gameStore, (s) => s.busy || !!s.result || !s.session);
  const [msg, setMsg] = useState<string | null>(null);
  if (!p) return null;
  const now = Date.now();
  const usable = RELICS.filter((r) => p.relics[r.id] && KIND[r.effect] && (!ranked || r.trialApproved));
  if (!usable.length) return null;

  const use = async (id: string, effect: string, value: number) => {
    const err = act((s, t) => activateRelic(s, id, t, ranked));
    if (err) {
      setMsg(err);
      setTimeout(() => setMsg(null), 1800);
      return;
    }
    await applyRelicEffect(id, KIND[effect], value);
  };

  return (
    <View pointerEvents="box-none" style={[s.wrap, { bottom: insets.bottom + 18 }]}>
      {msg && (
        <Animated.Text entering={FadeInDown.duration(200)} exiting={FadeOut} style={s.msg}>
          {msg}
        </Animated.Text>
      )}
      <View style={s.row}>
        {usable.map((r) => {
          const ch = relicCharges(p, r.id, now);
          const empty = ch.charges === 0 && p.items.relicCharge === 0;
          return (
            <PressSpring
              key={r.id}
              accessibilityLabel={`${r.name}, ${ch.charges} charges`}
              disabled={busy || empty}
              onPress={() => use(r.id, r.effect, r.effectValue)}
            >
              <RelicOrb glyph={GLYPH[r.effect]} tone={TONE[r.effect]} charges={ch.charges} off={busy || empty} />
            </PressSpring>
          );
        })}
      </View>
    </View>
  );
}

const s = StyleSheet.create({
  wrap: { position: "absolute", right: 14, alignItems: "flex-end", gap: 8 },
  row: { flexDirection: "row", gap: 10 },
  orb: { width: 56, height: 56, alignItems: "center", justifyContent: "center" },
  halo: { position: "absolute", width: 50, height: 50, borderRadius: 25, shadowRadius: 14, shadowOpacity: 1, elevation: 0 },
  core: {
    width: 52, height: 52, borderRadius: 26, borderWidth: 2, alignItems: "center", justifyContent: "center",
    backgroundColor: "rgba(14,18,48,0.92)",
  },
  glyph: { fontSize: 22, fontFamily: F.bold },
  badge: {
    position: "absolute", right: -2, bottom: -2, minWidth: 20, height: 20, borderRadius: 10, paddingHorizontal: 5,
    alignItems: "center", justifyContent: "center", backgroundColor: L.gold, borderWidth: 1.5, borderColor: L.goldLight,
  },
  count: { color: L.ink, fontSize: 11, fontFamily: F.number },
  msg: {
    color: L.ivory, fontFamily: F.bodyStrong, fontSize: 12, backgroundColor: "rgba(20,26,61,0.94)", paddingHorizontal: 12, paddingVertical: 6,
    borderRadius: 12, borderWidth: 1, borderColor: "rgba(255,106,122,0.6)", overflow: "hidden",
  },
});
