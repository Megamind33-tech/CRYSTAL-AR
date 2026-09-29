// Armory item art, painted with Skia: a lit display case with a faceted crystal imbued with the boost's emblem,
// a glowing pedestal, drifting sparkles, god-rays on the rare pieces and a foil sweep across the glass.
import { memo, useMemo } from "react";
import { BlurMask, Canvas, Circle, Group, LinearGradient, Path, RadialGradient, RoundedRect, Skia, rect, rrect, vec, type SkPath } from "@shopify/react-native-skia";
import { useDerivedValue } from "react-native-reanimated";
import type { Boost, BoostArt as ArtKind } from "@/src/game/boosts";
import { L } from "./lux/tokens";
import { useLoop } from "./lux/Lux";

type Pal = { hi: string; mid: string; deep: string; glow: string };

/** Case colour by rarity. */
export const RARITY_PAL: Record<Boost["rarity"], Pal> = {
  common: { hi: "#c6fbd6", mid: "#3fbf7a", deep: "#0e3a2c", glow: "#5cf0a0" },
  uncommon: { hi: "#cfe9ff", mid: "#4aa3ff", deep: "#0f2860", glow: "#5cc2ff" },
  rare: { hi: "#fff0c4", mid: "#f0a83a", deep: "#4a2a0c", glow: "#ffc25c" },
};

/** Crystal colour by emblem: [highlight, body, shadow]. */
const GEM: Record<ArtKind, [string, string, string]> = {
  moves: ["#eafeff", "#3fd0ff", "#0b5c9a"],
  score: ["#fff8d6", "#ffc93c", "#a85f0a"],
  surge: ["#f6e8ff", "#b06bff", "#4a1a9a"],
  prep: ["#e4ffec", "#3fe08a", "#0d6a3c"],
  charge: ["#ffe8f8", "#ff6ac8", "#8a1a68"],
};

const poly = (pts: [number, number][]) => {
  const p = Skia.Path.Make();
  pts.forEach(([x, y], i) => (i ? p.lineTo(x, y) : p.moveTo(x, y)));
  p.close();
  return p;
};

const star4 = (cx: number, cy: number, r: number, k = 0.22) =>
  poly([[cx, cy - r], [cx + r * k, cy - r * k], [cx + r, cy], [cx + r * k, cy + r * k], [cx, cy + r], [cx - r * k, cy + r * k], [cx - r, cy], [cx - r * k, cy - r * k]]);

/** The emblem set into the crystal, drawn around (50, 50). */
function glyph(kind: ArtKind): { fill?: SkPath; stroke?: SkPath } {
  switch (kind) {
    case "moves": {
      return { fill: poly([[46, 38], [54, 38], [54, 46], [62, 46], [62, 54], [54, 54], [54, 62], [46, 62], [46, 54], [38, 54], [38, 46], [46, 46]]) };
    }
    case "score":
      return { fill: star4(50, 50, 15, 0.3) };
    case "surge":
      return { fill: poly([[54, 36], [42, 53], [49, 53], [45, 66], [59, 48], [52, 48]]) };
    case "prep": {
      const p = Skia.Path.Make();
      p.moveTo(38, 51); p.lineTo(44, 57); p.lineTo(52, 44);
      p.moveTo(50, 57); p.lineTo(53, 60); p.lineTo(62, 45);
      return { stroke: p };
    }
    case "charge": {
      const p = Skia.Path.Make();
      p.addCircle(50, 51, 11);
      p.moveTo(50, 40); p.lineTo(50, 34);
      return { stroke: p };
    }
  }
}

const SPARKS: [number, number, number, number][] = [
  [22, 24, 4.5, 0], [78, 30, 3.5, 0.33], [70, 62, 3, 0.66], [30, 66, 3.2, 0.5], [50, 14, 3, 0.15],
];

function BoostArtImpl({ boost, size, animate = true }: { boost: Boost; size: number; animate?: boolean }) {
  const pal = RARITY_PAL[boost.rarity];
  const [gHi, gMid, gDeep] = GEM[boost.art];
  const rare = boost.rarity === "rare";
  const t = useLoop(rare ? 5200 : 6400, boost.tier * 300);
  const phase = (off: number) => useDerivedValue(() => (animate ? 0.15 + Math.max(0, Math.sin((t.value + off) * Math.PI * 2)) * 0.85 : 0.5));

  const shapes = useMemo(() => ({
    crownL: poly([[22, 42], [36, 26], [50, 42]]),
    crownC: poly([[36, 26], [64, 26], [50, 42]]),
    crownR: poly([[64, 26], [78, 42], [50, 42]]),
    pavL: poly([[22, 42], [50, 42], [50, 80]]),
    pavR: poly([[50, 42], [78, 42], [50, 80]]),
    glint: poly([[38, 29], [55, 29], [47, 38], [32, 40]]),
    ray: poly([[50, 46], [46, -30], [54, -30]]),
    glyph: glyph(boost.art),
    ring: (() => { const p = Skia.Path.Make(); p.addOval({ x: 24, y: 78, width: 52, height: 12 }); return p; })(),
  }), [boost.art]);

  const s1 = phase(0.0), s2 = phase(0.33), s3 = phase(0.66), s4 = phase(0.5), s5 = phase(0.15);
  const sparkOp = [s1, s2, s3, s4, s5];
  const rot = useDerivedValue(() => [{ rotate: animate ? t.value * Math.PI * 2 : 0 }]);
  const bob = useDerivedValue(() => [{ translateY: animate ? Math.sin(t.value * Math.PI * 2 * 2) * 1.6 : 0 }]);
  const sweep = useDerivedValue(() => [{ translateX: -60 + t.value * 240 }, { rotate: 0.45 }]);
  const rays = rare || boost.tier === 3;
  const shards = boost.tier - 1;

  return (
    <Canvas style={{ width: size, height: size }} pointerEvents="none">
      <Group transform={[{ scale: size / 100 }]}>
        <Group clip={rrect(rect(0, 0, 100, 100), 14, 14)}>
          {/* backplate: rarity-tinted night with a bright well behind the crystal */}
          <RoundedRect x={0} y={0} width={100} height={100} r={14}>
            <LinearGradient start={vec(0, 0)} end={vec(0, 100)} colors={[pal.deep, "#0a0c24", "#060818"]} positions={[0, 0.55, 1]} />
          </RoundedRect>
          <Circle cx={50} cy={48} r={58}>
            <RadialGradient c={vec(50, 48)} r={58} colors={[pal.glow + "aa", pal.mid + "33", "transparent"]} positions={[0, 0.45, 1]} />
          </Circle>

          {rays && (
            <Group opacity={0.32} transform={rot} origin={vec(50, 46)}>
              {[0, 36, 72, 108, 144, 180, 216, 252, 288, 324].map((deg) => (
                <Group key={deg} transform={[{ rotate: (deg * Math.PI) / 180 }]} origin={vec(50, 46)}>
                  <Path path={shapes.ray}>
                    <LinearGradient start={vec(50, 46)} end={vec(50, -20)} colors={[pal.hi, "transparent"]} />
                  </Path>
                </Group>
              ))}
            </Group>
          )}

          {/* pedestal: a lit dais with a bright rim, and a soft beam of light rising from it */}
          <Path path={poly([[36, 82], [64, 82], [78, 18], [22, 18]])} opacity={0.14}>
            <LinearGradient start={vec(0, 82)} end={vec(0, 18)} colors={[pal.glow, "transparent"]} />
          </Path>
          <Path path={shapes.ring}>
            <RadialGradient c={vec(50, 84)} r={28} colors={[pal.glow, pal.deep, "transparent"]} positions={[0, 0.6, 1]} />
          </Path>
          <Path path={shapes.ring} style="stroke" strokeWidth={1} color={pal.hi} opacity={0.8} />

          {/* the crystal, floating over its dais */}
          <Group transform={bob}>
            <Path path={shapes.crownC} color={gMid} opacity={0.55}>
              <BlurMask blur={12} style="normal" />
            </Path>
            <Path path={shapes.pavL}><LinearGradient start={vec(22, 42)} end={vec(50, 80)} colors={[gMid, gDeep]} /></Path>
            <Path path={shapes.pavR}><LinearGradient start={vec(78, 42)} end={vec(50, 80)} colors={[gDeep, "#05061a"]} /></Path>
            <Path path={shapes.crownL}><LinearGradient start={vec(22, 42)} end={vec(50, 30)} colors={[gMid, gHi]} /></Path>
            <Path path={shapes.crownC}><LinearGradient start={vec(36, 26)} end={vec(60, 42)} colors={[gHi, gMid]} /></Path>
            <Path path={shapes.crownR}><LinearGradient start={vec(64, 26)} end={vec(60, 42)} colors={[gMid, gDeep]} /></Path>
            <Path path={shapes.glint} color="#ffffff" opacity={0.42} />
            {[shapes.crownL, shapes.crownC, shapes.crownR, shapes.pavL, shapes.pavR].map((p, i) => (
              <Path key={i} path={p} style="stroke" strokeWidth={0.9} color="rgba(255,255,255,0.65)" />
            ))}
            {/* emblem: dark halo for legibility, then bright inlay */}
            {shapes.glyph.fill && (
              <>
                <Path path={shapes.glyph.fill} color="#04051a" opacity={0.55}><BlurMask blur={2.5} style="normal" /></Path>
                <Path path={shapes.glyph.fill} color="#ffffff" />
                <Path path={shapes.glyph.fill} style="stroke" strokeWidth={0.8} color={gHi} />
              </>
            )}
            {shapes.glyph.stroke && (
              <>
                <Path path={shapes.glyph.stroke} style="stroke" strokeWidth={5} strokeCap="round" strokeJoin="round" color="#04051a" opacity={0.5}><BlurMask blur={2} style="normal" /></Path>
                <Path path={shapes.glyph.stroke} style="stroke" strokeWidth={3.4} strokeCap="round" strokeJoin="round" color="#ffffff" />
              </>
            )}
          </Group>

          {/* higher tiers gather shards around the crystal */}
          {Array.from({ length: shards * 2 }, (_, i) => {
            const a = (i / (shards * 2)) * Math.PI * 2 + 0.6;
            const cx = 50 + Math.cos(a) * 36, cy = 46 + Math.sin(a) * 26;
            return <Path key={i} path={poly([[cx, cy - 4.5], [cx + 3, cy], [cx, cy + 4.5], [cx - 3, cy]])} color={gHi} opacity={0.85} />;
          })}

          {SPARKS.map(([x, y, r], i) => (
            <Group key={i} opacity={sparkOp[i]}>
              <Path path={star4(x, y, r * 2.2)} color={pal.glow} opacity={0.5}><BlurMask blur={3} style="normal" /></Path>
              <Path path={star4(x, y, r * 1.5)} color="#ffffff" />
            </Group>
          ))}

          {/* foil sweep across the glass */}
          {animate && (
            <Group transform={sweep} origin={vec(50, 50)} opacity={rare ? 0.3 : 0.16}>
              <Path path={poly([[-6, -60], [6, -60], [6, 160], [-6, 160]])} color="#ffffff"><BlurMask blur={5} style="normal" /></Path>
            </Group>
          )}
          <RoundedRect x={0} y={0} width={100} height={38} r={14}>
            <LinearGradient start={vec(0, 0)} end={vec(0, 38)} colors={["rgba(255,255,255,0.14)", "rgba(255,255,255,0)"]} />
          </RoundedRect>
        </Group>

        {/* frame: gold-and-rarity bezel, inner keyline, corner studs */}
        <RoundedRect x={1.5} y={1.5} width={97} height={97} r={13} style="stroke" strokeWidth={3}>
          <LinearGradient start={vec(0, 0)} end={vec(100, 100)} colors={[L.goldLight, pal.mid, L.filigree, pal.hi, L.goldDeep]} />
        </RoundedRect>
        <RoundedRect x={4.5} y={4.5} width={91} height={91} r={10.5} style="stroke" strokeWidth={0.8} color="rgba(255,255,255,0.28)" />
        {[[9, 9], [91, 9], [9, 91], [91, 91]].map(([x, y], i) => (
          <Path key={i} path={poly([[x, y - 4], [x + 3, y], [x, y + 4], [x - 3, y]])} color={pal.hi} />
        ))}
        {[1, 2, 3].map((n) => (
          <Path key={n} path={poly([[50 + (n - 2) * 9, 92], [50 + (n - 2) * 9 + 2.6, 94.6], [50 + (n - 2) * 9, 97.2], [50 + (n - 2) * 9 - 2.6, 94.6]])}
            color={n <= boost.tier ? pal.hi : "rgba(255,255,255,0.18)"} />
        ))}
      </Group>
    </Canvas>
  );
}

export const BoostArt = memo(BoostArtImpl);
