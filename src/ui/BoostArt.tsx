// Armory item art: a rendered 3D icon (real Meshy crystals, studio-lit; see tools/asset-pipeline/render-icons.mjs) under a
// gold-and-rarity bezel, with a foil sweep and drifting sparkles painted over the top.
import { memo, useMemo } from "react";
import { Image, View } from "react-native";
import { BlurMask, Canvas, Group, Path, Skia, rect, rrect, vec } from "@shopify/react-native-skia";
import { useDerivedValue } from "react-native-reanimated";
import type { Boost } from "@/src/game/boosts";
import { BOOST_ICONS, FRAMES } from "./boostIcons";
import { useLoop } from "./lux/Lux";

type Pal = { hi: string; mid: string; deep: string; glow: string; top: string; bottom: string; card: string };

/** Case colours by rarity: jade, sapphire and amber. The backdrop is lit colour, never black. */
export const RARITY_PAL: Record<Boost["rarity"], Pal> = {
  common: { hi: "#c6fbd6", mid: "#3fbf7a", deep: "#0e3a2c", glow: "#5cf0a0", top: "#25a58a", bottom: "#0a4038", card: "#0b3336" },
  uncommon: { hi: "#cfe9ff", mid: "#4aa3ff", deep: "#0f2860", glow: "#6cc8ff", top: "#3a7cf0", bottom: "#102a72", card: "#0e2258" },
  rare: { hi: "#fff0c4", mid: "#f0a83a", deep: "#4a2a0c", glow: "#ffc25c", top: "#e8a038", bottom: "#5a220e", card: "#48200e" },
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
  const inset = size * 0.035;
  const pip = Math.max(4, size * 0.028);

  return (
    <View style={{ width: size, height: size }}>
      {/* lit backdrop + gold bezel, baked to an image so it is there the instant the card is */}
      <Image source={FRAMES[boost.rarity]} style={{ position: "absolute", left: 0, top: 0, width: size, height: size }} />
      <View style={{ position: "absolute", left: inset, top: inset, right: inset, bottom: inset, borderRadius: size * 0.09, overflow: "hidden" }}>
        <Image source={BOOST_ICONS[boost.id]} style={{ width: "100%", height: "100%" }} resizeMode="cover" />
      </View>
      {/* animated sparkle and foil sweep on top; purely decorative, so it may mount late */}
      {animate && (
        <Canvas style={{ position: "absolute", left: 0, top: 0, width: size, height: size }} pointerEvents="none">
          <Group transform={[{ scale: size / 100 }]}>
            <Group clip={rrect(rect(4, 4, 92, 92), 10, 10)}>
              <Group transform={sweep} origin={vec(50, 50)} opacity={rare ? 0.22 : 0.1}>
                <Path path={band} color="#ffffff"><BlurMask blur={5} style="normal" /></Path>
              </Group>
              {SPARKS.map(([x, y, r], i) => (
                <Group key={i} opacity={sparkOp[i]}>
                  <Path path={star4(x, y, r * 1.6)} color="#ffffff" />
                </Group>
              ))}
            </Group>
          </Group>
        </Canvas>
      )}
      <View style={{ position: "absolute", left: 0, right: 0, bottom: size * 0.03, flexDirection: "row", justifyContent: "center", gap: pip * 0.9 }} pointerEvents="none">
        {[1, 2, 3].map((n) => (
          <View key={n} style={{ width: pip, height: pip, transform: [{ rotate: "45deg" }], backgroundColor: n <= boost.tier ? pal.hi : "rgba(255,255,255,0.25)" }} />
        ))}
      </View>
    </View>
  );
}

export const BoostArt = memo(BoostArtImpl);
