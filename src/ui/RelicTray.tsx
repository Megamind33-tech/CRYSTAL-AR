import { useState } from "react";
import { Pressable, StyleSheet, Text, View } from "react-native";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import { RELICS } from "../meta/config/collection";
import { relicCharges, activateRelic } from "../meta/progression";
import type { RunBoost } from "../meta/types";
import { gameStore, applyRelicEffect } from "../state/game";
import { act, metaStore } from "../state/meta";
import { useStore } from "../state/store";
import { C } from "./theme";

const GLYPH: Record<string, string> = { hint: "◉", addMoves: "⧗", reshuffle: "✥" };
const KIND: Record<string, RunBoost["kind"]> = { hint: "hint", addMoves: "moves", reshuffle: "reshuffle" };

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
      {msg && <Text style={s.msg}>{msg}</Text>}
      <View style={s.row}>
        {usable.map((r) => {
          const ch = relicCharges(p, r.id, now);
          const empty = ch.charges === 0 && p.items.relicCharge === 0;
          return (
            <Pressable
              key={r.id}
              accessibilityRole="button"
              accessibilityLabel={`${r.name}, ${ch.charges} charges`}
              disabled={busy || empty}
              onPress={() => use(r.id, r.effect, r.effectValue)}
              style={({ pressed }) => [s.btn, (busy || empty) && { opacity: 0.4 }, pressed && { transform: [{ scale: 0.94 }] }]}
            >
              <Text style={s.glyph}>{GLYPH[r.effect]}</Text>
              <Text style={s.count}>{ch.charges}</Text>
            </Pressable>
          );
        })}
      </View>
    </View>
  );
}

const s = StyleSheet.create({
  wrap: { position: "absolute", right: 14, alignItems: "flex-end", gap: 6 },
  row: { flexDirection: "row", gap: 8 },
  btn: { width: 52, height: 52, borderRadius: 26, backgroundColor: C.glass, borderWidth: 1, borderColor: C.line, alignItems: "center", justifyContent: "center" },
  glyph: { color: C.portal, fontSize: 22 },
  count: { position: "absolute", right: 4, bottom: 2, color: C.gold, fontSize: 11, fontWeight: "800" },
  msg: { color: C.ink, backgroundColor: C.glass, paddingHorizontal: 10, paddingVertical: 4, borderRadius: 10, fontSize: 12 },
});
