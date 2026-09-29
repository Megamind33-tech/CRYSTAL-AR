// LUX UI KIT — GPU-drawn (Skia) and animated (Reanimated) building blocks for the luminous-fantasy UI.
// Design source: Figma "Crystals AR – Game UI" › Luminous v2. Every interactive piece moves: buttons
// breathe light and spring on press, the sky twinkles and drifts, meters pour liquid light.
import { useEffect, useMemo, useState, type ReactNode } from "react";
import { Pressable, StyleSheet, Text, View, type LayoutChangeEvent, type StyleProp, type TextStyle, type ViewStyle } from "react-native";
import Animated, { Easing, useAnimatedStyle, useDerivedValue, useSharedValue, withRepeat, withSequence, withSpring, withTiming } from "react-native-reanimated";
import { BlurMask, Canvas, Circle, Group, LinearGradient, Path, RadialGradient, Rect, RoundedRect, Skia, vec } from "@shopify/react-native-skia";
import { F, L, titleGlow } from "./tokens";

// ------------------------------------------------------------------ helpers --
const useSize = () => {
  const [size, setSize] = useState({ w: 0, h: 0 });
  const onLayout = (e: LayoutChangeEvent) => {
    const { width, height } = e.nativeEvent.layout;
    if (Math.abs(width - size.w) > 0.5 || Math.abs(height - size.h) > 0.5) setSize({ w: width, h: height });
  };
  return { ...size, onLayout };
};

/** A looping 0→1 phase for ambient motion. */
export function useLoop(ms: number, delay = 0) {
  const t = useSharedValue(0);
  useEffect(() => {
    const id = setTimeout(() => {
      t.value = withRepeat(withTiming(1, { duration: ms, easing: Easing.linear }), -1, false);
    }, delay);
    return () => clearTimeout(id);
  }, [ms, delay, t]);
  return t;
}

function hexagon(cx: number, cy: number, r: number, squash = 1) {
  const p = Skia.Path.Make();
  for (let i = 0; i < 6; i++) {
    const a = Math.PI / 6 + (i * Math.PI) / 3;
    const x = cx + Math.cos(a) * r, y = cy + Math.sin(a) * r * squash;
    if (i === 0) p.moveTo(x, y);
    else p.lineTo(x, y);
  }
  p.close();
  return p;
}

function diamond(cx: number, cy: number, r: number) {
  const p = Skia.Path.Make();
  p.moveTo(cx, cy - r);
  p.lineTo(cx + r, cy);
  p.lineTo(cx, cy + r);
  p.lineTo(cx - r, cy);
  p.close();
  return p;
}

// ---------------------------------------------------------------- night sky --
/**
 * The universe behind every screen: a deep night gradient, slow-breathing nebulae, two layers of
 * stars twinkling out of phase, and light motes rising. Fills its parent (position absolute).
 */
export function NightSky({ tint = L.violet, accent = L.aether }: { tint?: string; accent?: string }) {
  const { w, h, onLayout } = useSize();
  const breathe = useLoop(9000);
  const twinkle = useLoop(3200);
  const rise = useLoop(14000);
  const stars = useMemo(() => {
    const out: { x: number; y: number; r: number; layer: number }[] = [];
    for (let i = 0; i < 90; i++) out.push({ x: ((i * 131.7) % 1000) / 1000, y: ((i * 71.3) % 1000) / 1000, r: 0.6 + ((i * 7) % 4) * 0.45, layer: i % 2 });
    return out;
  }, []);
  const neb1 = useDerivedValue(() => 0.35 + Math.sin(breathe.value * Math.PI * 2) * 0.12);
  const neb2 = useDerivedValue(() => 0.25 + Math.cos(breathe.value * Math.PI * 2) * 0.1);
  const starsA = useDerivedValue(() => 0.45 + Math.sin(twinkle.value * Math.PI * 2) * 0.4);
  const starsB = useDerivedValue(() => 0.45 - Math.sin(twinkle.value * Math.PI * 2) * 0.4);
  const motes = useMemo(() => Array.from({ length: 14 }, (_, i) => ({ x: ((i * 173) % 97) / 97, o: (i * 0.071) % 1, r: 1.2 + (i % 3) })), []);
  return (
    <View style={StyleSheet.absoluteFill} onLayout={onLayout} pointerEvents="none">
      {w > 0 && (
        <Canvas style={StyleSheet.absoluteFill}>
          <Rect x={0} y={0} width={w} height={h}>
            <LinearGradient start={vec(0, 0)} end={vec(0, h)} colors={[L.night900, L.night700, "#241d5a"]} positions={[0, 0.5, 1]} />
          </Rect>
          <Group opacity={neb1}>
            <Circle cx={w * 0.15} cy={h * 0.22} r={w * 0.7}>
              <RadialGradient c={vec(w * 0.15, h * 0.22)} r={w * 0.7} colors={[tint, "transparent"]} />
            </Circle>
          </Group>
          <Group opacity={neb2}>
            <Circle cx={w * 0.9} cy={h * 0.62} r={w * 0.65}>
              <RadialGradient c={vec(w * 0.9, h * 0.62)} r={w * 0.65} colors={[accent, "transparent"]} />
            </Circle>
            <Circle cx={w * 0.2} cy={h * 0.9} r={w * 0.5}>
              <RadialGradient c={vec(w * 0.2, h * 0.9)} r={w * 0.5} colors={[L.rose + "55", "transparent"]} />
            </Circle>
          </Group>
          <Group opacity={starsA}>
            {stars.filter((s) => s.layer === 0).map((s, i) => <Circle key={i} cx={s.x * w} cy={s.y * h} r={s.r} color="#ffffff" />)}
          </Group>
          <Group opacity={starsB}>
            {stars.filter((s) => s.layer === 1).map((s, i) => <Circle key={i} cx={s.x * w} cy={s.y * h} r={s.r} color="#dff6ff" />)}
          </Group>
          {motes.map((m, i) => (
            <Mote key={i} x={m.x * w} h={h} offset={m.o} r={m.r} phase={rise} />
          ))}
        </Canvas>
      )}
    </View>
  );
}

function Mote({ x, h, offset, r, phase }: { x: number; h: number; offset: number; r: number; phase: { value: number } }) {
  const cy = useDerivedValue(() => h - (((phase.value + offset) % 1) * (h + 40)) + 20);
  const op = useDerivedValue(() => Math.sin(((phase.value + offset) % 1) * Math.PI) * 0.8);
  return (
    <Group opacity={op}>
      <Circle cx={x} cy={cy} r={r * 2.5} color={L.crystal + "33"}>
        <BlurMask blur={4} style="normal" />
      </Circle>
      <Circle cx={x} cy={cy} r={r * 0.7} color="#ffffff" />
    </Group>
  );
}

// ------------------------------------------------------------- glass frame --
const PAD = 16; // room around the canvas for shadows and glow

/** Frosted night-glass surface with a gold filigree edge, cyan rim light and corner gems. */
export function GlassFrame({ radius = 22, gems = true, glowColor, tone = "night", style, children }: {
  radius?: number; gems?: boolean; glowColor?: string; tone?: "night" | "deep"; style?: StyleProp<ViewStyle>; children?: ReactNode;
}) {
  const { w, h, onLayout } = useSize();
  const top = tone === "night" ? "rgba(42,47,106,0.9)" : "rgba(26,30,72,0.94)";
  return (
    <View style={style} onLayout={onLayout}>
      {w > 0 && (
        <Canvas style={{ position: "absolute", left: -PAD, top: -PAD, width: w + PAD * 2, height: h + PAD * 2 }} pointerEvents="none">
          <Group transform={[{ translateX: PAD }, { translateY: PAD }]}>
            <RoundedRect x={0} y={6} width={w} height={h} r={radius} color="rgba(3,4,18,0.55)">
              <BlurMask blur={12} style="normal" />
            </RoundedRect>
            {glowColor && (
              <RoundedRect x={0} y={0} width={w} height={h} r={radius} color={glowColor} opacity={0.35}>
                <BlurMask blur={14} style="outer" />
              </RoundedRect>
            )}
            <RoundedRect x={0} y={0} width={w} height={h} r={radius}>
              <LinearGradient start={vec(0, 0)} end={vec(0, h)} colors={[top, "rgba(20,26,61,0.94)"]} />
            </RoundedRect>
            <RoundedRect x={1} y={1} width={w - 2} height={Math.min(80, h * 0.4)} r={radius}>
              <LinearGradient start={vec(0, 0)} end={vec(0, Math.min(80, h * 0.4))} colors={["rgba(255,255,255,0.13)", "rgba(255,255,255,0)"]} />
            </RoundedRect>
            <RoundedRect x={2} y={2} width={w - 4} height={h - 4} r={radius - 2} style="stroke" strokeWidth={1} color="rgba(127,231,255,0.28)" />
            <RoundedRect x={0.75} y={0.75} width={w - 1.5} height={h - 1.5} r={radius} style="stroke" strokeWidth={1.5}>
              <LinearGradient start={vec(0, 0)} end={vec(w, h)} colors={[L.goldPale, L.filigree, L.goldPale, L.filigree]} />
            </RoundedRect>
            {gems &&
              [[0, 0], [w, 0], [0, h], [w, h]].map(([x, y], i) => (
                <Group key={i}>
                  <Path path={diamond(x, y, 9)} color={L.goldPale} opacity={0.55}>
                    <BlurMask blur={6} style="normal" />
                  </Path>
                  <Path path={diamond(x, y, 6)}>
                    <LinearGradient start={vec(x, y - 6)} end={vec(x, y + 6)} colors={["#fff8d8", L.gold]} />
                  </Path>
                </Group>
              ))}
          </Group>
        </Canvas>
      )}
      {children}
    </View>
  );
}

// ------------------------------------------------------------------ button --
type Variant = "gold" | "glass" | "rose";
const BTN: Record<Variant, { colors: string[]; text: string; glow: string; stroke: [string, string] }> = {
  gold: { colors: [L.goldLight, "#f0b44a", "#b8741e"], text: L.ink, glow: "#ffcf6a", stroke: ["#fff8e0", L.filigree] },
  glass: { colors: ["#3a4a9a", "#233070", L.night700], text: "#e6f7ff", glow: L.aether, stroke: [L.goldPale, L.filigree] },
  rose: { colors: ["#ffd0f0", "#e05ab8", "#8a1a6a"], text: "#ffffff", glow: L.rose, stroke: ["#ffe8f8", "#8a1a6a"] },
};

/**
 * The call-to-action. A light sweep crosses its face every few seconds; pressing squashes it with a
 * spring and flares its glow. `size`: regular (54) or hero (68).
 */
export function LuxButton({ label, onPress, variant = "gold", hero, disabled, style, testID, icon }: {
  label: string; onPress?: () => void; variant?: Variant; hero?: boolean; disabled?: boolean; style?: StyleProp<ViewStyle>; testID?: string; icon?: ReactNode;
}) {
  const v = BTN[variant];
  const { w, h, onLayout } = useSize();
  const press = useSharedValue(0);
  const sweep = useLoop(variant === "gold" ? 3400 : 5200, 400);
  const scale = useAnimatedStyle(() => ({ transform: [{ scale: 1 - press.value * 0.06 }] }));
  const glowOp = useDerivedValue(() => 0.45 + press.value * 0.5);
  const sweepX = useDerivedValue(() => -w * 0.6 + sweep.value * w * 2.4);
  const r = hero ? 24 : 18;
  return (
    <Animated.View style={[scale, style, disabled && { opacity: 0.45 }]}>
      <Pressable
        testID={testID}
        accessibilityRole="button"
        accessibilityLabel={label}
        disabled={disabled || !onPress}
        onPress={onPress}
        onPressIn={() => (press.value = withSpring(1, { damping: 14, stiffness: 420 }))}
        onPressOut={() => (press.value = withSpring(0, { damping: 9, stiffness: 260 }))}
        onLayout={onLayout}
        style={[b.btn, { minHeight: hero ? 66 : 50, borderRadius: r, paddingHorizontal: hero ? 36 : 22 }]}
      >
        {w > 0 && (
          <Canvas style={{ position: "absolute", left: -PAD, top: -PAD, width: w + PAD * 2, height: h + PAD * 2 }} pointerEvents="none">
            <Group transform={[{ translateX: PAD }, { translateY: PAD }]}>
              <RoundedRect x={0} y={6} width={w} height={h} r={r} color="rgba(3,4,18,0.6)">
                <BlurMask blur={8} style="normal" />
              </RoundedRect>
              <Group opacity={glowOp}>
                <RoundedRect x={0} y={0} width={w} height={h} r={r} color={v.glow}>
                  <BlurMask blur={16} style="outer" />
                </RoundedRect>
              </Group>
              <RoundedRect x={0} y={0} width={w} height={h} r={r}>
                <LinearGradient start={vec(0, 0)} end={vec(0, h)} colors={v.colors} positions={[0, 0.55, 1]} />
              </RoundedRect>
              <RoundedRect x={w * 0.07} y={4} width={w * 0.86} height={h * 0.36} r={r * 0.7}>
                <LinearGradient start={vec(0, 4)} end={vec(0, h * 0.4)} colors={["rgba(255,255,255,0.6)", "rgba(255,255,255,0)"]} />
              </RoundedRect>
              <Group clip={Skia.RRectXY(Skia.XYWHRect(0, 0, w, h), r, r)}>
                <Group transform={[{ skewX: -0.35 }]}>
                  <Rect x={sweepX} y={-4} width={w * 0.22} height={h + 8}>
                    <LinearGradient start={vec(0, 0)} end={vec(w * 0.22, 0)} colors={["rgba(255,255,255,0)", "rgba(255,255,255,0.55)", "rgba(255,255,255,0)"]} />
                  </Rect>
                </Group>
              </Group>
              <RoundedRect x={0.75} y={0.75} width={w - 1.5} height={h - 1.5} r={r} style="stroke" strokeWidth={2}>
                <LinearGradient start={vec(0, 0)} end={vec(0, h)} colors={v.stroke} />
              </RoundedRect>
            </Group>
          </Canvas>
        )}
        <View style={b.btnRow}>
          {icon}
          <Text style={[b.btnTxt, { color: v.text, fontSize: hero ? 23 : 16 }, variant !== "gold" && titleGlow(v.glow, 8)]} numberOfLines={1}>
            {label}
          </Text>
        </View>
      </Pressable>
    </Animated.View>
  );
}

// ------------------------------------------------------------- gem glyph --
/** A glowing hexagonal crystal – currency icons, rewards, relic slots. */
export function Gem({ size = 26, colors = [L.goldLight, L.gold], glow = "#ffcf6a", pulse }: { size?: number; colors?: [string, string]; glow?: string; pulse?: boolean }) {
  const t = useLoop(2400);
  const op = useDerivedValue(() => (pulse ? 0.45 + Math.sin(t.value * Math.PI * 2) * 0.3 : 0.6));
  const s = size, c = s / 2 + 6;
  return (
    <Canvas style={{ width: s + 12, height: s + 12, margin: -6 }} pointerEvents="none">
      <Group opacity={op}>
        <Path path={hexagon(c, c, s * 0.52)} color={glow}>
          <BlurMask blur={s * 0.3} style="normal" />
        </Path>
      </Group>
      <Path path={hexagon(c, c, s * 0.45)}>
        <LinearGradient start={vec(c, c - s / 2)} end={vec(c, c + s / 2)} colors={colors} />
      </Path>
      <Path path={hexagon(c, c - s * 0.08, s * 0.22)} color="rgba(255,255,255,0.55)" />
    </Canvas>
  );
}

// --------------------------------------------------------------- capsule --
/** Currency / status capsule: night glass, gold hairline, glowing gem, value. */
export function Capsule({ value, gem, onPress, testID }: { value: string; gem: ReactNode; onPress?: () => void; testID?: string }) {
  return (
    <Pressable onPress={onPress} testID={testID} disabled={!onPress} style={b.capsule}>
      {gem}
      <Text style={b.capsuleTxt}>{value}</Text>
    </Pressable>
  );
}

// ----------------------------------------------------------------- meter --
/** Liquid light: the fill pours toward `value` (0..1), a spark rides its head and a shimmer travels. */
export function Meter({ value, colors = [L.aether, L.crystal], height = 12 }: { value: number; colors?: [string, string]; height?: number }) {
  const { w, onLayout } = useSize();
  const v = useSharedValue(0);
  const shimmer = useLoop(2200);
  useEffect(() => {
    v.value = withTiming(Math.max(0, Math.min(1, value)), { duration: 650, easing: Easing.out(Easing.cubic) });
  }, [value, v]);
  const fillW = useDerivedValue(() => Math.max(height, (w - 4) * v.value));
  const head = useDerivedValue(() => 2 + Math.max(height, (w - 4) * v.value) - height / 2);
  const shX = useDerivedValue(() => -40 + shimmer.value * (w + 80));
  const h = height;
  return (
    <View style={{ height: h + 4 }} onLayout={onLayout}>
      {w > 0 && (
        <Canvas style={{ position: "absolute", left: 0, top: -6, width: w, height: h + 16 }}>
          <Group transform={[{ translateY: 6 }]}>
            <RoundedRect x={0} y={0} width={w} height={h + 4} r={(h + 4) / 2} color="rgba(7,9,32,0.92)" />
            <RoundedRect x={0.5} y={0.5} width={w - 1} height={h + 3} r={(h + 3) / 2} style="stroke" strokeWidth={1} color="rgba(246,211,138,0.45)" />
            <Group clip={Skia.RRectXY(Skia.XYWHRect(2, 2, w - 4, h), h / 2, h / 2)}>
              <RoundedRect x={2} y={2} width={fillW} height={h} r={h / 2}>
                <LinearGradient start={vec(0, 0)} end={vec(w, 0)} colors={colors} />
              </RoundedRect>
              <Rect x={shX} y={2} width={40} height={h}>
                <LinearGradient start={vec(0, 0)} end={vec(40, 0)} colors={["rgba(255,255,255,0)", "rgba(255,255,255,0.45)", "rgba(255,255,255,0)"]} />
              </Rect>
            </Group>
            <Circle cx={head} cy={2 + h / 2} r={h * 0.9} color={colors[1]} opacity={0.7}>
              <BlurMask blur={6} style="normal" />
            </Circle>
            <Circle cx={head} cy={2 + h / 2} r={h * 0.32} color="#ffffff" />
          </Group>
        </Canvas>
      )}
    </View>
  );
}

// ------------------------------------------------------------- medallion --
/**
 * A map node: gold-ringed crystal medallion. `current` breathes a gold halo; `locked` is frosted.
 * The number is drawn by the caller on top (Cinzel).
 */
export function Medallion({ size, colors, state }: { size: number; colors: [string, string]; state: "done" | "current" | "locked" }) {
  const t = useLoop(2600);
  const s = size, P = s * 0.4, c = s / 2 + P;
  return (
    <Canvas style={{ position: "absolute", left: -P, top: -P, width: s + P * 2, height: s + P * 2 }} pointerEvents="none">
      <MedallionShape cx={c} cy={c} size={s} colors={colors} state={state} pulse={t} />
    </Canvas>
  );
}

/**
 * The medallion's drawing, for use inside any Skia canvas (the map draws every node in ONE canvas:
 * browsers cap live GPU contexts at ~16, and many canvases are costly on phones too).
 */
export function MedallionShape({ cx, cy, size, colors, state, pulse }: {
  cx: number; cy: number; size: number; colors: [string, string]; state: "done" | "current" | "locked"; pulse: { value: number };
}) {
  const s = size, c = { x: cx, y: cy };
  const halo = useDerivedValue(() => (state === "current" ? 0.55 + Math.sin(pulse.value * Math.PI * 2) * 0.35 : 0));
  const haloR = useDerivedValue(() => s * (0.62 + Math.sin(pulse.value * Math.PI * 2) * 0.05));
  const core = state === "locked" ? ["#3a3f66", "#1a1d3a"] : colors;
  return (
    <Group>
      <Circle cx={c.x} cy={c.y + 5} r={s * 0.48} color="rgba(3,4,18,0.6)">
        <BlurMask blur={8} style="normal" />
      </Circle>
      {state === "current" && (
        <Group opacity={halo}>
          <Circle cx={c.x} cy={c.y} r={haloR} color="#ffcf6a">
            <BlurMask blur={s * 0.22} style="normal" />
          </Circle>
        </Group>
      )}
      <Circle cx={c.x} cy={c.y} r={s * 0.47}>
        <LinearGradient start={vec(c.x, c.y - s / 2)} end={vec(c.x, c.y + s / 2)} colors={state === "locked" ? ["#8a8fb0", "#4a4f70", "#2a2d48"] : [L.goldLight, L.gold, L.goldDeep]} positions={[0, 0.5, 1]} />
      </Circle>
      <Circle cx={c.x} cy={c.y} r={s * 0.37}>
        <RadialGradient c={vec(c.x - s * 0.08, c.y - s * 0.1)} r={s * 0.45} colors={state === "locked" ? core : ["#ffffff", core[0], core[1]]} positions={state === "locked" ? [0, 1] : [0, 0.4, 1]} />
      </Circle>
      <Path path={hexagon(c.x, c.y, s * 0.2, 1.1)} color={state === "locked" ? "rgba(140,146,190,0.5)" : "rgba(255,255,255,0.55)"} />
      <Circle cx={c.x} cy={c.y} r={s * 0.37} style="stroke" strokeWidth={1.2} color="rgba(0,0,0,0.35)" />
    </Group>
  );
}

// ---------------------------------------------------------------- plaque --
/** Realm / section title: a fading night band between gold hairlines, glowing Cinzel caps. */
export function Plaque({ title, sub, color = L.goldPale, width = 300 }: { title: string; sub?: string; color?: string; width?: number }) {
  const h = 50;
  return (
    <View style={{ width, alignItems: "center" }}>
      <Canvas style={{ position: "absolute", width, height: h }} pointerEvents="none">
        <Rect x={0} y={4} width={width} height={h - 8}>
          <LinearGradient start={vec(0, 0)} end={vec(width, 0)} colors={["rgba(20,26,61,0)", "rgba(20,26,61,0.95)", "rgba(20,26,61,0.95)", "rgba(20,26,61,0)"]} positions={[0, 0.18, 0.82, 1]} />
        </Rect>
        {[3, h - 4].map((y) => (
          <Rect key={y} x={width * 0.08} y={y} width={width * 0.84} height={1.5}>
            <LinearGradient start={vec(width * 0.08, 0)} end={vec(width * 0.92, 0)} colors={[color + "00", color, color + "00"]} />
          </Rect>
        ))}
        <Path path={diamond(width / 2, 3.5, 4)} color={color} />
        <Path path={diamond(width / 2, h - 3.5, 4)} color={color} />
      </Canvas>
      <Text style={[b.plaque, { color, lineHeight: h }, titleGlow(color, 10)]} numberOfLines={1}>{title}</Text>
      {sub ? <Text style={b.plaqueSub}>{sub}</Text> : null}
    </View>
  );
}

// ----------------------------------------------------------------- text --
export const LuxText = {
  display: (s: string, style?: StyleProp<TextStyle>) => <Text style={[b.display, style]}>{s}</Text>,
  title: (s: string, style?: StyleProp<TextStyle>) => <Text style={[b.title, style]}>{s}</Text>,
  label: (s: string, style?: StyleProp<TextStyle>) => <Text style={[b.label, style]}>{s}</Text>,
  body: (s: string, style?: StyleProp<TextStyle>) => <Text style={[b.body, style]}>{s}</Text>,
};

/** Fade + rise entrance for panels and rows (stagger with `delay`). */
export function Rise({ delay = 0, children, style }: { delay?: number; children: ReactNode; style?: StyleProp<ViewStyle> }) {
  const p = useSharedValue(0);
  useEffect(() => {
    p.value = withSequence(withTiming(0, { duration: delay }), withSpring(1, { damping: 16, stiffness: 140 }));
  }, [delay, p]);
  const st = useAnimatedStyle(() => ({ opacity: p.value, transform: [{ translateY: (1 - p.value) * 18 }, { scale: 0.97 + p.value * 0.03 }] }));
  return <Animated.View style={[st, style]}>{children}</Animated.View>;
}

const b = StyleSheet.create({
  btn: { alignItems: "center", justifyContent: "center" },
  btnRow: { flexDirection: "row", alignItems: "center", gap: 8 },
  btnTxt: { fontFamily: F.display, letterSpacing: 2 },
  capsule: {
    flexDirection: "row", alignItems: "center", gap: 6, paddingLeft: 6, paddingRight: 12, height: 34, borderRadius: 17,
    backgroundColor: "rgba(11,14,36,0.82)", borderWidth: 1, borderColor: "rgba(246,211,138,0.6)",
  },
  capsuleTxt: { color: "#ffffff", fontFamily: F.number, fontSize: 14 },
  plaque: { fontFamily: F.display, fontSize: 18, letterSpacing: 3.5 },
  plaqueSub: { color: L.mist, fontFamily: F.body, fontSize: 11.5, marginTop: -4 },
  display: { color: L.goldLight, fontFamily: F.display, fontSize: 28, letterSpacing: 3, ...titleGlow("#ffcf6a", 16) },
  title: { color: L.ivory, fontFamily: F.title, fontSize: 16, letterSpacing: 1.2 },
  label: { color: L.goldPale, fontFamily: F.title, fontSize: 10, letterSpacing: 2.4 },
  body: { color: L.mist, fontFamily: F.body, fontSize: 13.5, lineHeight: 20 },
});
