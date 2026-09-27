import { useEffect, useRef } from "react";
import { StyleSheet, Text, View } from "react-native";
import { gameStore } from "../state/game";
import { analytics, metaStore } from "../state/meta";
import { useStore } from "../state/store";
import { C, font } from "./theme";

/**
 * First-session coaching for a brand-new Keeper: one short line at a time, tied to real game state,
 * gone after the first restoration. No shop, trials or currencies are mentioned here.
 */
export function Coach() {
  const newKeeper = useStore(metaStore, (m) => !!m.player && Object.keys(m.player.islands).length === 0);
  const moves = useStore(gameStore, (s) => s.moveCount);
  const progress = useStore(gameStore, (s) => s.progress);
  const selected = useStore(gameStore, (s) => !!s.selected);
  const result = useStore(gameStore, (s) => s.result);
  const started = useRef(false);

  useEffect(() => {
    if (newKeeper && !started.current) {
      started.current = true;
      analytics.track("tutorial_started");
    }
  }, [newKeeper]);
  useEffect(() => {
    if (started.current && result?.won) analytics.track("tutorial_completed");
  }, [result]);

  if (!newKeeper || result) return null;
  const line =
    moves === 0 && !selected ? "Touch a crystal, then swipe it toward a neighbour."
    : moves === 0 ? "Swipe toward a neighbour to line up three of a kind."
    : moves < 3 ? "Every match sends Resonance into the portal. Watch the island answer."
    : progress < 0.5 ? "Line up four for a Surge crystal. Five makes a Prism."
    : progress < 1 ? "The portal is waking. Keep the Resonance flowing."
    : null;
  if (!line) return null;
  return (
    <View pointerEvents="none" style={s.wrap}>
      <Text style={s.txt}>{line}</Text>
    </View>
  );
}

const s = StyleSheet.create({
  wrap: { position: "absolute", left: 16, right: 16, bottom: 90, alignItems: "center" },
  txt: { color: C.ink, backgroundColor: C.glass, borderColor: C.line, borderWidth: StyleSheet.hairlineWidth, paddingHorizontal: 14, paddingVertical: 10, borderRadius: 14, fontFamily: font.display, fontStyle: "italic", fontSize: 15, textAlign: "center", overflow: "hidden" },
});
