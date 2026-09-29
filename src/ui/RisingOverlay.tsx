import { useEffect, useRef, useState } from "react";
import { Animated, StyleSheet, Text, View } from "react-native";
import { useLoadProgress } from "../render/LoadQueue";
import { arSession } from "../state/arSession";
import { useStore } from "../state/store";
import { Bar } from "./kit";
import { C, font } from "./theme";

/**
 * Covers the scene while the island's assets stream in one at a time, so the player sees the
 * world appear whole instead of assembling piece by piece.
 */
export function RisingOverlay({ label = "The Forest Ruins are rising…" }: { label?: string }) {
  const placed = useStore(arSession, (s) => s.phase === "placed");
  const { done, total, pending } = useLoadProgress();
  const [settled, setSettled] = useState(false);
  const fade = useRef(new Animated.Value(1)).current;
  // Viro mounts the world's parts some time after placement (seconds on a slow phone), so "nothing
  // pending" means nothing until this placement has actually queued its own loads.
  const baseline = useRef<number | null>(null);
  if (!placed) baseline.current = null;
  else if (baseline.current === null) baseline.current = total;
  const queued = placed && total > (baseline.current ?? total);

  useEffect(() => {
    if (!placed) {
      setSettled(false);
      fade.setValue(1);
      return;
    }
    const reveal = () => {
      setSettled(true);
      Animated.timing(fade, { toValue: 0, duration: 500, useNativeDriver: true }).start();
    };
    // never trap the player behind the overlay if a load goes missing
    const giveUp = setTimeout(reveal, 25000);
    if (!queued || pending > 0) return () => clearTimeout(giveUp);
    // give late-mounting parts a moment to take their place in the queue before calling it done
    const t = setTimeout(reveal, 700);
    return () => {
      clearTimeout(t);
      clearTimeout(giveUp);
    };
  }, [placed, queued, pending, fade]);

  if (!placed || settled) return null;
  return (
    <Animated.View pointerEvents="none" style={[StyleSheet.absoluteFill, s.wrap, { opacity: fade }]}>
      <Text style={s.title}>{label}</Text>
      <View style={{ width: 180 }}>
        <Bar value={queued ? Math.max(0.05, (done - (baseline.current ?? 0)) / (total - (baseline.current ?? 0))) : 0.05} color={C.portal} />
      </View>
    </Animated.View>
  );
}

const s = StyleSheet.create({
  wrap: { backgroundColor: "rgba(12,15,19,0.92)", alignItems: "center", justifyContent: "center", gap: 14 },
  title: { color: C.ink, fontFamily: font.display, fontStyle: "italic", fontSize: 18 },
});
