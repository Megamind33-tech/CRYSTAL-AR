// Armory item art: a rendered 3D icon (real Meshy crystals, studio-lit; see tools/asset-pipeline/render-icons.mjs) under a
// gold-and-rarity bezel, with a foil sweep and drifting sparkles painted over the top.
import { memo, useMemo } from "react";
import { Image, View } from "react-native";
import { BlurMask, Canvas, Group, LinearGradient, Path, RoundedRect, Skia, rect, rrect, vec } from "@shopify/react-native-skia";
import { useDerivedValue } from "react-native-reanimated";
import type { Boost } from "@/src/game/boosts";
import { BOOST_ICONS } from "./boostIcons";
import { L } from "./lux/tokens";
import { useLoop } from "./lux/Lux";

type Pal = { hi: string; mid: string; deep: string; glow: string };

/** Case colour by rarity. */
export const RARITY_PAL: Record<Boost["rarity"], Pal> = {
  common: { hi: "#c6fbd6", mid: "#3fbf7a", deep: "#0e3a2c", glow: "#5cf0a0" },
  uncommon: { hi: "#cfe9ff", mid: "#4aa3ff", deep: "#0f2860", glow: "#5cc2ff" },
  rare: { hi: "#fff0c4", mid: "#f0a83a", deep: "#4a2a0c", glow: "#ffc25c" },
};

const poly = (pts: [number, number][]) => {
  const p = Skia.Path.Make();
  pts.forEach(([x, y], i) => (i ? p.lineTo(x, y) : p.moveTo(x, y)));
  p.close();
  return p;
};

const star4 = (cx: number, cy: number, r: number, k = 0.22) =>
  poly([[cx, cy - r], [cx + r * k, cy - r * k], [cx + r, cy], [cx + r * k, cy + r * k], [cx, cy + r], [cx - r * k, cy + r * k], [cx - r, cy], [cx - r * k, cy - r * k]]);

const SPARKS: [number, number, number, number][] = [
  [22, 24, 4.5, 0], [78, 30, 3.5, 0.33], [70, 62, 3, 0.66], [30, 66, 3.2, 0.5], [50, 14, 3, 0.15],
];

function BoostArtImpl({ boost, size, animate = true }: { boost: Boost; size: number; animate?: boolean }) {
  const pal = RARITY_PAL[boost.rarity];
  const rare = boost.rarity === "rare";
  const t = useLoop(rare ? 5200 : 7000, boost.tier * 300);
  const phase = (off: number) => useDerivedValue(() => (animate ? 0.1 + Math.max(0, Math.sin((t.value + off) * Math.PI * 2)) * 0.9 : 0));
  const sparkOp = [phase(0), phase(0.33), phase(0.66), phase(0.5), phase(0.15)];
  const sweep = useDerivedValue(() => [{ translateX: -60 + t.value * 240 }, { rotate: 0.45 }]);
  const band = useMemo(() => poly([[-6, -60], [6, -60], [6, 160], [-6, 160]]), []);

  return (
    <View style={{ width: size, height: size }}>
      <View style={{ position: "absolute", left: size * 0.02, top: size * 0.02, right: size * 0.02, bottom: size * 0.02, borderRadius: size * 0.12, overflow: "hidden" }}>
        <Image source={BOOST_ICONS[boost.id]} style={{ width: "100%", height: "100%" }} resizeMode="cover" />
      </View>
      <Canvas style={{ position: "absolute", left: 0, top: 0, width: size, height: size }} pointerEvents="none">
        <Group transform={[{ scale: size / 100 }]}>
          {animate && (
            <Group clip={rrect(rect(2, 2, 96, 96), 12, 12)}>
              <Group transform={sweep} origin={vec(50, 50)} opacity={rare ? 0.22 : 0.1}>
                <Path path={band} color="#ffffff"><BlurMask blur={5} style="normal" /></Path>
              </Group>
              {SPARKS.map(([x, y, r], i) => (
                <Group key={i} opacity={sparkOp[i]}>
                  <Path path={star4(x, y, r * 1.6)} color="#ffffff" />
                </Group>
              ))}
            </Group>
          )}
          <RoundedRect x={0.5} y={0.5} width={99} height={40} r={13} opacity={0.6}>
            <LinearGradient start={vec(0, 0)} end={vec(0, 40)} colors={["rgba(255,255,255,0.10)", "rgba(255,255,255,0)"]} />
          </RoundedRect>
          {/* bezel: gold-and-rarity gradient, inner keyline, corner studs, tier pips */}
          <RoundedRect x={1.5} y={1.5} width={97} height={97} r={13} style="stroke" strokeWidth={3}>
            <LinearGradient start={vec(0, 0)} end={vec(100, 100)} colors={[L.goldLight, pal.mid, L.filigree, pal.hi, L.goldDeep]} />
          </RoundedRect>
          <RoundedRect x={4.5} y={4.5} width={91} height={91} r={10.5} style="stroke" strokeWidth={0.8} color="rgba(255,255,255,0.22)" />
          {[[8, 8], [92, 8], [8, 92], [92, 92]].map(([x, y], i) => (
            <Path key={i} path={poly([[x, y - 4], [x + 3, y], [x, y + 4], [x - 3, y]])} color={pal.hi} />
          ))}
          {[1, 2, 3].map((n) => {
            const cx = 50 + (n - 2) * 9;
            return <Path key={n} path={poly([[cx, 92], [cx + 2.6, 94.6], [cx, 97.2], [cx - 2.6, 94.6]])} color={n <= boost.tier ? pal.hi : "rgba(255,255,255,0.22)"} />;
          })}
        </Group>
      </Canvas>
    </View>
  );
}

export const BoostArt = memo(BoostArtImpl);
