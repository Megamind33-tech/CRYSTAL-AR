import { memo, useEffect, useState } from "react";
import { ViroNode } from "@reactvision/react-viro";
import type { CoverKind } from "../game/types";
import type { CrystalView } from "../state/game";
import { GlowPad } from "./GemFx";
import { GEM_NAMES, GemMesh, useMeshyStyle } from "./GemMesh";
import { cellToLocal, GEM_SCALE, GEM_TILT_DEG, spawnGate } from "./layout";
import { moveAnim, popSteps } from "./registry";
import { IDLE_MOTION, impactAnimation, useAlternate, useImpact } from "./useMotion";

/** classic plate */
const AURA_SCALE: [number, number, number] = [GEM_SCALE * 0.9, GEM_SCALE * 0.9, GEM_SCALE * 0.9];
/**
 * The Meshy ring is 1.84 units across. At 0.66 x GEM_SCALE it is ~4.4 cm, 0.85 of a 5.2 cm cell, so a ring
 * (even tilted or mid-swell in place) stays inside its own cell and never reaches a neighbour.
 */
const RING_SCALE: [number, number, number] = [GEM_SCALE * 0.66, GEM_SCALE * 0.66, GEM_SCALE * 0.66];
const SWEEP_SCALE: [number, number, number] = [GEM_SCALE * 0.4, GEM_SCALE * 0.4, GEM_SCALE * 0.4];
/** how far the ring leans from flat, like a planet's ring seen at an angle */
const RING_TILT = 24;

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
  // a spawned crystal stays hidden in the chute until it reaches the gate, then materialises there (see spawnGate)
  const [emerged, setEmerged] = useState(0);
  const active = anim && anim.seq !== settled ? anim : undefined;
  const gate = active?.kind === "spawn" ? spawnGate(active.fromX, active.fromY, x, y) : null;
  const leadMs = gate && active?.kind === "spawn" ? Math.round((active.ms * gate.lead) / gate.len) : 0;
  const popping = active?.kind === "pop";
  const pop = popping ? popSteps(special, active.ms) : undefined;

  // Timer fallbacks in case a platform drops onFinish.
  useEffect(() => {
    if (!active) return;
    if (active.kind === "pop") {
      const t = setTimeout(() => setVanishing(active.seq), (pop?.swellMs ?? 70) + 40);
      return () => clearTimeout(t);
    }
    if (active.kind === "spawn" && leadMs > 0) {
      const e = setTimeout(() => setEmerged(active.seq), leadMs);
      const t = setTimeout(() => setSettled(active.seq), active.ms + 80);
      return () => {
        clearTimeout(e);
        clearTimeout(t);
      };
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
        if (!gate) {
          // no flow (a reshuffle spawn): grows in place
          position = cellToLocal(active.fromX, active.fromY);
          scale = [0.25, 0.25, 0.25];
          animation = { name: moveAnim(target, active.ms, true), run: true, onFinish: done };
        } else if (leadMs > 0 && emerged !== active.seq) {
          // still in the chute behind the gate: invisible
          position = cellToLocal(gate.gx, gate.gy);
          scale = [0.001, 0.001, 0.001];
        } else {
          // out of the gate: small and glowing, growing to full size as it falls into its cell
          position = cellToLocal(gate.gx, gate.gy);
          scale = [0.3, 0.3, 0.3];
          animation = { name: moveAnim(target, Math.max(60, active.ms - leadMs), true), run: true, onFinish: done };
        }
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

  // aura, pointed along the clear in code. Classic plate: long axis X, so horizontal = no yaw. Meshy ring: it
  // circles the gem like a planet's ring and leans toward the clear direction (below); the small comet rings
  // that fly out on activation are yawed so their local Z is the clear axis (horizontal = along board X).
  const meshy = useMeshyStyle();
  const horizontal = special === "surgeH";
  const auraYaw = meshy ? (horizontal ? 90 : 0) : horizontal ? 0 : 90;
  const auraAnim = popping
    ? meshy ? undefined : { name: "auraBlast", run: true, interruptible: true }
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
      <GlowPad type={type} boost={selected ? 2 : isSpecial ? 1 : 0} />
      <ViroNode position={[0, lift, 0]} animation={liftAnim}>
        {/* rotation flips between two values so that stopping a spin re-applies a clean facing */}
        <ViroNode rotation={[0, spin ? 0 : 0.001, 0]} animation={spin ? { name: spin, run: true, loop: spinLoops, interruptible: true } : undefined}>
          <GemMesh name={gem} scale={[GEM_SCALE, GEM_SCALE, GEM_SCALE]} rotation={[isPrism || isRelic ? 0 : GEM_TILT_DEG, 0, 0]} />
        </ViroNode>
      </ViroNode>
      {isSurge && !meshy && (
        <ViroNode position={[0, lift, 0]} rotation={[0, auraYaw, 0]} animation={auraAnim}>
          <GemMesh name="surge_aura" scale={AURA_SCALE} />
        </ViroNode>
      )}
      {isSurge && meshy && (
        <ViroNode position={[0, lift, 0]}>
          {/* the ring: flat around the gem, leaning about the clear axis so its long side points along the row or
              column; it turns in place and swells outward when the gem fires */}
          <ViroNode rotation={horizontal ? [RING_TILT, 0, 0] : [0, 0, RING_TILT]} animation={auraAnim}>
            <ViroNode rotation={[-90, 0, 0]} animation={popping ? { name: "auraExpand", run: true, interruptible: true } : undefined}>
              <ViroNode animation={IDLE_MOTION ? { name: "auraSpin", run: true, loop: true } : undefined}>
                <GemMesh name="surge_aura" scale={RING_SCALE} />
              </ViroNode>
            </ViroNode>
          </ViroNode>
          {/* on activation two small rings fly out along the clear, ahead of the line that is about to clear */}
          {popping && (
            <ViroNode rotation={[0, auraYaw, 0]}>
              <ViroNode animation={{ name: "auraSweepA", run: true, interruptible: true }}>
                <GemMesh name="surge_aura" scale={SWEEP_SCALE} />
              </ViroNode>
              <ViroNode animation={{ name: "auraSweepB", run: true, interruptible: true }}>
                <GemMesh name="surge_aura" scale={SWEEP_SCALE} />
              </ViroNode>
            </ViroNode>
          )}
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
