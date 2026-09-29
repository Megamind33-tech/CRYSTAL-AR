import { memo, useEffect, useState } from "react";
import { ViroNode } from "@reactvision/react-viro";
import type { CoverKind } from "../game/types";
import type { CrystalView } from "../state/game";
import { GEM_NAMES, GemMesh } from "./GemMesh";
import { cellToLocal, GEM_SCALE, GEM_TILT_DEG } from "./layout";
import { moveAnim } from "./registry";

type Props = {
  crystal: CrystalView;
  selected: boolean;
};

/**
 * One crystal. Hierarchy: position node (cell motion) → spin node → tilted model.
 * The controller supplies `anim`; once it has played, the node settles at its logical cell.
 */
function CrystalNodeImpl({ crystal, selected }: Props) {
  const { anim, x, y, special, type } = crystal;
  const [settled, setSettled] = useState(0);
  const active = anim && anim.seq !== settled ? anim : undefined;

  // Timer fallback in case a platform drops onFinish.
  useEffect(() => {
    if (!active || active.kind === "pop") return;
    const t = setTimeout(() => setSettled(active.seq), active.ms + 80);
    return () => clearTimeout(t);
  }, [active]);

  const target = cellToLocal(x, y);
  let position = target;
  let scale: [number, number, number] = [1, 1, 1];
  let animation: { name: string; run: boolean; onFinish?: () => void } | undefined;

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
        animation = { name: "pop", run: true };
        break;
      case "forge":
        scale = [0.1, 0.1, 0.1];
        animation = { name: "forge", run: true, onFinish: done };
        break;
      case "crack":
        // a cover chipped or crept on: a short squash on the cover only (see below)
        break;
    }
  }

  const lift = selected ? 0.014 : 0;
  const isPrism = special === "prism";
  const isRelic = special === "relic";
  const isSurge = special === "surgeH" || special === "surgeV";
  const spin = selected ? "spinFast" : special !== "none" ? "spinSlow" : undefined;
  const cover = crystal.cover;
  const cracking = active?.kind === "crack";
  const gem = isPrism ? "gem_prism" : isRelic ? "gem_relic" : GEM_NAMES[type];

  return (
    <ViroNode position={position} scale={scale} animation={animation}>
      {/* rotation flips between two values so that stopping a spin re-applies a clean facing */}
      <ViroNode position={[0, lift, 0]} rotation={[0, spin ? 0 : 0.001, 0]} animation={spin ? { name: spin, run: true, loop: true } : undefined}>
        <GemMesh name={gem} scale={[GEM_SCALE, GEM_SCALE, GEM_SCALE]} rotation={[isPrism || isRelic ? 0 : GEM_TILT_DEG, 0, 0]} />
      </ViroNode>
      {isSurge && (
        <GemMesh name="surge_aura" scale={[GEM_SCALE * 0.9, GEM_SCALE * 0.9, GEM_SCALE * 0.9]} position={[0, lift, 0]} rotation={[0, special === "surgeV" ? 90 : 0, 0]} />
      )}
      {cover && (
        <ViroNode key={`${cover.kind}${cover.hp}`} scale={cracking ? [1.18, 0.86, 1.18] : [1, 1, 1]} animation={cracking ? { name: "forge", run: true } : undefined}>
          <GemMesh name={coverMesh(cover.kind, cover.hp)} scale={[GEM_SCALE, GEM_SCALE, GEM_SCALE]} />
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
