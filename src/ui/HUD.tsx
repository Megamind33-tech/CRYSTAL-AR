// IN-GAME HUD — luminous fantasy (Figma › Luminous v2 › "In-game HUD v2"). Frosted objective panel
// with a liquid-light meter, a gold-ringed moves orb that pops on every move (and pulses red when
// low), a rolling score, a glass pause orb, and spring-in combo call-outs. The world stays the hero.
import { useEffect, useRef, useState } from "react";
import { StyleSheet, Text, View } from "react-native";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import Animated, { useAnimatedStyle, useDerivedValue, useSharedValue, withSequence, withSpring, withTiming } from "react-native-reanimated";
import { BlurMask, Canvas, Circle, Group, LinearGradient, RadialGradient, vec } from "@shopify/react-native-skia";
import { objectiveValueFrom, type Objective } from "../game/level";
import { CRYSTAL_COLORS, CRYSTAL_NAMES } from "../render/assets";
import { gameStore } from "../state/game";
import { useStore } from "../state/store";
import { PressSpring } from "./kit";
import { GlassFrame, Meter, useLoop } from "./lux/Lux";
import { F, L, titleGlow } from "./lux/tokens";

const COVER_VERB = { ice: "Melt the ice", vine: "Cut the vines", chain: "Break the chains", ember: "Quench the embers" } as const;

function objectiveLabel(o: Objective) {
  switch (o.kind) {
    case "power": return "Awaken the portal";
    case "score": return `Reach ${o.target.toLocaleString()}`;
    case "collect": return `Gather ${CRYSTAL_NAMES[o.crystal]}s`;
    case "cover": return COVER_VERB[o.cover];
    case "stone": return "Break the stones";
    case "rune": return "Unearth the runes";
    case "relic": return "Bring the relics down";
  }
}

const OBSTACLE_ACCENT = { ice: "#bfe9ff", vine: "#8cf5a0", chain: "#d8d0c0", ember: "#ffab7a" } as const;

/** A number that rolls toward its new value instead of jumping. */
function useRolling(target: number, ms = 450) {
  const [shown, setShown] = useState(target);
  const from = useRef(target);
  useEffect(() => {
    const start = Date.now(), a = from.current, b = target;
    if (a === b) return;
    const id = setInterval(() => {
      const t = Math.min(1, (Date.now() - start) / ms);
      const v = Math.round(a + (b - a) * (1 - Math.pow(1 - t, 3)));
      setShown(v);
      if (t >= 1) {
        clearInterval(id);
        from.current = b;
      }
    }, 33);
    return () => {
      clearInterval(id);
      from.current = b;
    };
  }, [target, ms]);
  return shown;
}

/** Gold-ringed moves orb; pops on every change and throbs red on the last three. */
function MovesOrb({ moves }: { moves: number }) {
  const S = 78, P = 16, c = S / 2 + P;
  const low = moves <= 3;
  const pop = useSharedValue(1);
  useEffect(() => {
    pop.value = withSequence(withTiming(1.16, { duration: 90 }), withSpring(1, { damping: 7, stiffness: 240 }));
  }, [moves, pop]);
  const t = useLoop(low ? 700 : 2800);
  const glow = useDerivedValue(() => (low ? 0.55 + Math.sin(t.value * Math.PI * 2) * 0.4 : 0.3 + Math.sin(t.value * Math.PI * 2) * 0.1));
  const st = useAnimatedStyle(() => ({ transform: [{ scale: pop.value }] }));
  return (
    <Animated.View style={[{ width: S, height: S }, st]} pointerEvents="none">
      <Canvas style={{ position: "absolute", left: -P, top: -P, width: S + P * 2, height: S + P * 2 }}>
        <Group opacity={glow}>
          <Circle cx={c} cy={c} r={S * 0.5} color={low ? L.danger : "#ffcf6a"}>
            <BlurMask blur={12} style="normal" />
          </Circle>
        </Group>
        <Circle cx={c} cy={c + 4} r={S * 0.48} color="rgba(3,4,18,0.6)">
          <BlurMask blur={6} style="normal" />
        </Circle>
        <Circle cx={c} cy={c} r={S * 0.48}>
          <LinearGradient start={vec(c, c - S / 2)} end={vec(c, c + S / 2)} colors={[L.goldLight, L.gold, L.goldDeep]} positions={[0, 0.5, 1]} />
        </Circle>
        <Circle cx={c} cy={c} r={S * 0.41}>
          <RadialGradient c={vec(c, c - S * 0.1)} r={S * 0.5} colors={low ? ["#5a1a3a", "#1a0a1e"] : ["#3a2a7a", L.night800]} />
        </Circle>
      </Canvas>
      <View style={StyleSheet.absoluteFill}>
        <Text style={[h.movesNum, low && { color: "#ffc8d0", ...titleGlow(L.danger, 10) }]}>{moves}</Text>
        <Text style={h.movesLabel}>MOVES</Text>
      </View>
    </Animated.View>
  );
}

/** Top strip: objective panel, moves orb, score and pause. */
export function HUD({ onPause }: { onPause: () => void }) {
  const insets = useSafeAreaInsets();
  const session = useStore(gameStore, (s) => s.session);
  const hud = useStore(gameStore, (s) => s.hud);
  const progress = useStore(gameStore, (s) => s.progress);
  const combo = useStore(gameStore, (s) => s.comboText);
  const score = useRolling(hud.score);

  // combo call-out: spring in, hold, drift up and fade
  const pop = useSharedValue(0);
  useEffect(() => {
    if (!combo) return;
    pop.value = 0;
    pop.value = withSequence(withSpring(1, { damping: 8, stiffness: 180 }), withTiming(1, { duration: 520 }), withTiming(2, { duration: 380 }));
  }, [combo, pop]);
  const comboSt = useAnimatedStyle(() => ({
    opacity: pop.value <= 1 ? pop.value : 2 - pop.value,
    transform: [{ scale: 0.6 + Math.min(1, pop.value) * 0.4 }, { translateY: pop.value > 1 ? -(pop.value - 1) * 30 : 0 }],
  }));

  if (!session) return null;
  const o = session.level.objective;
  const accent = o.kind === "collect" ? CRYSTAL_COLORS[o.crystal] : o.kind === "power" ? L.crystal : o.kind === "cover" ? OBSTACLE_ACCENT[o.cover] : o.kind === "score" ? L.goldPale : "#f0d9a8";
  const count = o.kind === "power" ? `${Math.round(progress * 100)}%` : o.kind === "score" ? `${Math.round(progress * 100)}%` : `${Math.min(objectiveValueFrom(o, hud), o.target)}/${o.target}`;
  const meterColors: [string, string] = o.kind === "power" || o.kind === "score" ? [L.aether, L.crystal] : [accent, "#ffffff"];

  return (
    <View pointerEvents="box-none" style={[StyleSheet.absoluteFill, { paddingTop: insets.top + 6 }]}>
      <View pointerEvents="box-none" style={h.row}>
        <GlassFrame gems={false} radius={18} tone="deep" style={h.objective}>
          <Text style={h.levelTag} numberOfLines={1}>
            {(session.level.label ?? `LEVEL ${session.level.id}`).toUpperCase()} · {session.level.name.toUpperCase()}
          </Text>
          <View style={h.objRow}>
            <Text style={h.objText} numberOfLines={1}>{objectiveLabel(o)}</Text>
            <Text style={[h.count, { color: accent }, titleGlow(accent, 8)]}>{count}</Text>
          </View>
          <Meter value={progress} colors={meterColors} height={9} />
        </GlassFrame>
        <MovesOrb moves={hud.movesLeft} />
      </View>
      <View pointerEvents="box-none" style={h.row2}>
        <Text pointerEvents="none" style={h.score}>{score.toLocaleString()}</Text>
        <PressSpring accessibilityLabel="Pause" onPress={onPause} style={h.pause}>
          <View style={h.pauseBar} />
          <View style={h.pauseBar} />
        </PressSpring>
      </View>
      {combo && (
        <Animated.Text pointerEvents="none" style={[h.combo, comboSt]}>
          {combo.text.toUpperCase()}
        </Animated.Text>
      )}
    </View>
  );
}

const h = StyleSheet.create({
  row: { flexDirection: "row", paddingHorizontal: 12, gap: 12, alignItems: "center" },
  objective: { flex: 1, paddingHorizontal: 14, paddingVertical: 10, gap: 5 },
  levelTag: { color: L.goldPale, fontFamily: F.title, fontSize: 9.5, letterSpacing: 1.8 },
  objRow: { flexDirection: "row", alignItems: "baseline", justifyContent: "space-between", gap: 8 },
  objText: { color: L.ivory, fontSize: 14.5, fontFamily: F.bodyStrong, flexShrink: 1 },
  count: { fontSize: 15, fontFamily: F.number },
  movesNum: { color: "#ffffff", fontFamily: F.number, fontSize: 28, textAlign: "center", marginTop: 12, ...titleGlow("#ffffff", 6) },
  movesLabel: { color: L.goldPale, fontFamily: F.title, fontSize: 8, letterSpacing: 2, textAlign: "center", marginTop: -3 },
  row2: { flexDirection: "row", justifyContent: "space-between", alignItems: "center", paddingHorizontal: 16, marginTop: 8 },
  score: { color: L.ivory, fontFamily: F.number, fontSize: 18, letterSpacing: 0.5, textShadowColor: "rgba(0,0,0,0.8)", textShadowRadius: 6 },
  pause: {
    width: 42, height: 42, borderRadius: 21, flexDirection: "row", gap: 5, alignItems: "center", justifyContent: "center",
    backgroundColor: "rgba(20,26,61,0.88)", borderWidth: 1.5, borderColor: "rgba(246,211,138,0.8)", elevation: 6,
  },
  pauseBar: { width: 4, height: 15, borderRadius: 2, backgroundColor: L.goldPale },
  combo: {
    position: "absolute", top: "58%", alignSelf: "center", color: L.goldLight, fontSize: 40, fontFamily: F.display, letterSpacing: 4,
    ...titleGlow("#ffcf6a", 22),
  },
});
