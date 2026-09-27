import { useEffect, useRef } from "react";
import { Animated, Pressable, StyleSheet, Text, View } from "react-native";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import type { Objective } from "../game/level";
import { CRYSTAL_COLORS, CRYSTAL_NAMES } from "../render/assets";
import { gameStore } from "../state/game";
import { useStore } from "../state/store";
import { C, font, ui } from "./theme";

function objectiveLabel(o: Objective) {
  if (o.kind === "power") return "Awaken the portal";
  if (o.kind === "score") return `Reach ${o.target.toLocaleString()} points`;
  return `Gather ${o.target} ${CRYSTAL_NAMES[o.crystal]}s`;
}

/** Top strip: level + objective meter, moves, score. The world stays the hero. */
export function HUD({ onPause }: { onPause: () => void }) {
  const insets = useSafeAreaInsets();
  const session = useStore(gameStore, (s) => s.session);
  const hud = useStore(gameStore, (s) => s.hud);
  const progress = useStore(gameStore, (s) => s.progress);
  const combo = useStore(gameStore, (s) => s.comboText);
  const bar = useRef(new Animated.Value(0)).current;
  const pop = useRef(new Animated.Value(0)).current;

  useEffect(() => {
    Animated.timing(bar, { toValue: progress, duration: 450, useNativeDriver: false }).start();
  }, [progress, bar]);

  useEffect(() => {
    if (!combo) return;
    pop.setValue(0);
    Animated.sequence([
      Animated.spring(pop, { toValue: 1, useNativeDriver: true, friction: 5, tension: 140 }),
      Animated.delay(550),
      Animated.timing(pop, { toValue: 0, duration: 260, useNativeDriver: true }),
    ]).start();
  }, [combo, pop]);

  if (!session) return null;
  const o = session.level.objective;
  const accent = o.kind === "collect" ? CRYSTAL_COLORS[o.crystal] : o.kind === "power" ? C.portal : C.gold;
  const count =
    o.kind === "collect" ? `${Math.min(hud.collected[o.crystal], o.target)}/${o.target}` : o.kind === "power" ? `${Math.round(progress * 100)}%` : hud.score.toLocaleString();

  return (
    <View pointerEvents="box-none" style={[StyleSheet.absoluteFill, { paddingTop: insets.top + 8 }]}>
      <View pointerEvents="box-none" style={s.row}>
        <View style={[ui.glass, s.objective]} pointerEvents="none">
          <Text style={ui.label} numberOfLines={1}>
            Level {session.level.id} · {session.level.name}
          </Text>
          <Text style={s.objText} numberOfLines={1}>
            {objectiveLabel(o)} <Text style={{ color: accent }}>{count}</Text>
          </Text>
          <View style={s.track}>
            <Animated.View style={[s.fill, { backgroundColor: accent, width: bar.interpolate({ inputRange: [0, 1], outputRange: ["0%", "100%"] }) }]} />
          </View>
        </View>
        <View style={[ui.glass, s.stat]} pointerEvents="none">
          <Text style={ui.label}>Moves</Text>
          <Text style={[ui.value, hud.movesLeft <= 3 && { color: C.danger }]}>{hud.movesLeft}</Text>
        </View>
        <Pressable accessibilityRole="button" accessibilityLabel="Pause" onPress={onPause} style={[ui.glass, s.pause]} hitSlop={10}>
          <View style={s.pauseBar} />
          <View style={s.pauseBar} />
        </Pressable>
      </View>
      {o.kind !== "score" && (
        <Text pointerEvents="none" style={s.score}>
          {hud.score.toLocaleString()}
        </Text>
      )}
      {combo && (
        <Animated.Text
          pointerEvents="none"
          style={[s.combo, { opacity: pop, transform: [{ scale: pop.interpolate({ inputRange: [0, 1], outputRange: [0.6, 1] }) }] }]}
        >
          {combo.text}
        </Animated.Text>
      )}
    </View>
  );
}

const s = StyleSheet.create({
  row: { flexDirection: "row", paddingHorizontal: 12, gap: 8, alignItems: "stretch" },
  objective: { flex: 1, paddingHorizontal: 14, paddingVertical: 10, gap: 3 },
  objText: { color: C.ink, fontSize: 14, fontWeight: "600", fontFamily: font.body },
  track: { height: 5, borderRadius: 3, backgroundColor: "rgba(255,255,255,0.12)", overflow: "hidden", marginTop: 4 },
  fill: { height: 5, borderRadius: 3 },
  stat: { width: 66, alignItems: "center", justifyContent: "center" },
  pause: { width: 52, flexDirection: "row", alignItems: "center", justifyContent: "center", gap: 5 },
  pauseBar: { width: 4, height: 16, borderRadius: 2, backgroundColor: C.ink },
  score: { alignSelf: "center", marginTop: 8, color: C.ink, fontSize: 15, fontWeight: "700", letterSpacing: 1, opacity: 0.85, textShadowColor: "#000", textShadowRadius: 6 },
  combo: {
    position: "absolute",
    top: "30%",
    alignSelf: "center",
    color: C.gold,
    fontSize: 34,
    fontFamily: font.display,
    fontStyle: "italic",
    fontWeight: "700",
    textShadowColor: "rgba(0,0,0,0.7)",
    textShadowRadius: 12,
  },
});
