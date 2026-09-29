// A carved rune line around the visible rim of the board's stone dais, glowing in the realm's colour. It is a row of
// short dashes (so it reads as runes cut into stone, not a bar of light) with a lit stud at each corner. It breathes on
// the shared slow beat, and flares while the world is excited by a big cascade, a special gem or a finished level.
import { memo, useEffect, useState } from "react";
import { ViroNode, ViroQuad } from "@reactvision/react-viro";
import { gameStore } from "../../state/game";
import { useStore } from "../../state/store";
import { SURFACE_Y } from "./buildIsland";
import { trimDashes } from "./daisTrimLayout";
import { usePulseBeat } from "./Life";

const Y = SURFACE_Y + 0.002;

export const DaisTrim = memo(function DaisTrim({ material }: { material: string }) {
  const up = usePulseBeat();
  const kicks = useStore(gameStore, (s) => s.reactions.CASCADE_3 + s.reactions.CASCADE_4_PLUS + s.reactions.SPECIAL_ACTIVATED + s.reactions.LEVEL_COMPLETE);
  const [flare, setFlare] = useState(false);
  useEffect(() => {
    if (!kicks) return;
    setFlare(true);
    const t = setTimeout(() => setFlare(false), 1800);
    return () => clearTimeout(t);
  }, [kicks]);
  const { dashes, studs } = trimDashes();
  // dashes swell a little on the beat and a lot on a flare (scale in the thin direction only would need per-axis
  // animations; a uniform breath on the whole group is enough and costs one node)
  const k = flare ? 1.45 : up ? 1.12 : 1;
  return (
    <ViroNode position={[0, Y, 0]} scale={[1, 1, 1]} ignoreEventHandling>
      {dashes.map((d, i) => (
        <ViroQuad key={i} position={[d.x, 0, d.z]} rotation={[-90, 0, 0]} width={d.w * 2.1 * k} height={d.h * 3.6 * k} materials={[material]} ignoreEventHandling />
      ))}
      {studs.map(([x, z], i) => (
        <ViroQuad key={`s${i}`} position={[x, 0.001, z]} rotation={[-90, 0, 0]} width={0.055 * k} height={0.055 * k} materials={[material]} ignoreEventHandling />
      ))}
    </ViroNode>
  );
});
