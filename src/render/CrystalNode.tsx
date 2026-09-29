import { memo, useEffect, useState } from "react";
import { ViroNode } from "@reactvision/react-viro";
import type { CoverKind } from "../game/types";
import type { CrystalView } from "../state/game";
import { GEM_NAMES, GemMesh } from "./GemMesh";
import { cellToLocal, GEM_SCALE, GEM_TILT_DEG } from "./layout";
import { moveAnim, popSteps } from "./registry";
import { IDLE_MOTION, impactAnimation, useAlternate, useImpact } from "./useMotion";

type Props = {
  crystal: CrystalView;
  selected: boolean;
};

/**
 * One crystal. Hierarchy: cell node (cell motion, clear pop) → lift node (special bob / selection pulse)
 * → spin node (special spin, activation twist) → tilted model; plus an aura node (surge) and a cover node.
 * The controller supplies `anim`; once it has played, the node settles at its logical cell.
 * Motion is transform-only on ViroNode wrappers – the meshes, materials and pivots are never touched.
 */
function CrystalNodeImpl({ crystal, selected }: Props) {
  const { anim, x, y, special, type } = crystal;
  const [settled, setSettled] = useState(0);
  // clear pop runs in two steps (swell → vanish); `vanishing` is the seq whose swell has finished
  const [vanishing, setVanishing] = useState(0);
  const active = anim && anim.seq !== settled ? anim : undefined;
  const popping = active?.kind === "pop";
  const pop = popping ? popSteps(special, active.ms) : undefined;

  // Timer fallbacks in case a platform drops onFinish.
  useEffect(() => {
    if (!active) return;
    if (active.kind === "pop") {
      const t = setTimeout(() => setVanishing(active.seq), (pop?.swellMs ?? 70) + 40);
      return () => clearTimeout(t);
    }
    const t = setTimeout(() => setSettled(active.seq), active.ms + 80);
    return () => clearTimeout(t);
  }, [active]); // eslint-disable-line react-hooks/exhaustive-deps

  const target = cellToLocal(x, y);
  let position = target;
  let scale: [number, number, number] = [1, 1, 1];
  let animation: { name: string; run: boolean; interruptible?: boolean; onFinish?: () => void } | undefined;

  if (active) {
    const done = () => setSettled(active.seq);
    switch (active.kind) {
      case "move":
        position = cellToLocal(active.fromX, active.fromY);
        animation = { name: moveAnim(target, active.ms), run: true, onFinish: done };
        break;
      case "spawn":
        position = cellToLocal(active.fromX, active.fromY);
        scale = [0.25, 0.25, 0.25];
        animation = { name: moveAnim(target, active.ms, true), run: true, onFinish: done };
        break;
      case "pop":
        // swell first, then shrink away; the controller removes the node after TIMING.pop as before
        animation =
          vanishing === active.seq
            ? { name: pop!.vanish, run: true, interruptible: true }
            : { name: pop!.swell, run: true, interruptible: true, onFinish: () => setVanishing(active.seq) };
        break;
      case "forge":
        scale = [0.1, 0.1, 0.1];
        animation = { name: "forge", run: true, onFinish: done };
        break;
      case "crack":
        // a cover chipped or crept on: handled by the cover's own impact sequence (see below)
        break;
    }
  }

  const isPrism = special === "prism";
  const isRelic = special === "relic";
  const isSurge = special === "surgeH" || special === "surgeV";
  const isSpecial = special !== "none";
  const lift = selected ? 0.014 : 0;

  // ambient motion – restrained, and never while the crystal is mid-clear: only specials bob and spin
  // (so plain gems keep a perfectly readable silhouette); a selected crystal gets a soft scale pulse
  const bob = useAlternate(IDLE_MOTION && isSpecial && !selected && !popping, 900);
  const pulse = useAlternate(IDLE_MOTION && selected && !popping, 420);
  const breath = useAlternate(IDLE_MOTION && isSurge && !popping, 800);

  const liftAnim = selected && !popping
    ? { name: pulse.up ? "selUp" : "selDown", run: true, interruptible: true, onFinish: pulse.flip }
    : isSpecial && !popping && IDLE_MOTION
      ? { name: bob.up ? "bobUp" : "bobDown", run: true, interruptible: true, onFinish: bob.flip }
      : undefined;

  // spin node: specials turn slowly; on activation a prism whirls and a relic flips over
  const spin = popping ? (isPrism ? "spinFast" : isRelic ? "relicFlip" : undefined) : isSpecial ? "spinSlow" : undefined;
  const spinLoops = spin === "spinFast" || spin === "spinSlow";

  // aura: yawed in code (0° horizontal, 90° vertical); breathes gently, stretches along its axis on activation
  const auraAnim = popping
    ? { name: "auraBlast", run: true, interruptible: true }
    : IDLE_MOTION
      ? { name: breath.up ? "auraBreathUp" : "auraBreathDown", run: true, interruptible: true, onFinish: breath.flip }
      : undefined;

  // cover (ice / vine / chain / ember): keeps its old mesh for a brief rattle, then drops to the lower state
  const cover = crystal.cover;
  const impact = useImpact(cover ? cover.hp : 0, cover?.kind ?? "");
  const coverAnim = impactAnimation(impact.phase, impact.advance);
  const gem = isPrism ? "gem_prism" : isRelic ? "gem_relic" : GEM_NAMES[type];

  return (
    <ViroNode position={position} scale={scale} animation={animation}>
      <ViroNode position={[0, lift, 0]} animation={liftAnim}>
        {/* rotation flips between two values so that stopping a spin re-applies a clean facing */}
        <ViroNode rotation={[0, spin ? 0 : 0.001, 0]} animation={spin ? { name: spin, run: true, loop: spinLoops, interruptible: true } : undefined}>
          <GemMesh name={gem} scale={[GEM_SCALE, GEM_SCALE, GEM_SCALE]} rotation={[isPrism || isRelic ? 0 : GEM_TILT_DEG, 0, 0]} />
        </ViroNode>
      </ViroNode>
      {isSurge && (
        <ViroNode position={[0, lift, 0]} rotation={[0, special === "surgeV" ? 90 : 0, 0]} animation={auraAnim}>
          <GemMesh name="surge_aura" scale={[GEM_SCALE * 0.9, GEM_SCALE * 0.9, GEM_SCALE * 0.9]} />
        </ViroNode>
      )}
      {impact.shown > 0 && impact.tag !== "" && (
        <ViroNode scale={impact.phase === "grow" ? [0.1, 0.1, 0.1] : [1, 1, 1]} animation={coverAnim}>
          <GemMesh name={coverMesh(impact.tag as CoverKind, impact.shown)} scale={[GEM_SCALE, GEM_SCALE, GEM_SCALE]} />
        </ViroNode>
      )}
    </ViroNode>
  );
}

/** Mesh for a cover at its remaining strength (thicker ice, a second vine, a second chain…). */
export function coverMesh(kind: CoverKind, hp: number): string {
  return `ob_${kind}${Math.min(2, Math.max(1, hp))}`;
}

export const CrystalNode = memo(CrystalNodeImpl);
