import { memo, useEffect, useRef, useState, type ReactNode } from "react";
import { ViroNode, ViroParticleEmitter, ViroQuad } from "@reactvision/react-viro";
import { Model, Gated } from "./LoadQueue";
import type { WorldStage } from "../game/reactions";
import { gameStore } from "../state/game";
import { useStore } from "../state/store";
import { GemMesh } from "./GemMesh";
import { MODELS, TEXTURES } from "./assets";
import { SURFACE_Y } from "./layout";
import { scale3Anim } from "./registry";

type V3 = [number, number, number];

/**
 * A world prop that (a) grows smoothly when its stage-driven base scale changes and
 * (b) pulses to base × peak whenever `trigger` increments.
 */
function Reactive({ position, rotation, base, trigger, peak = [1.2, 1.2, 1.2], children }: {
  position?: V3;
  rotation?: V3;
  base: V3;
  trigger: number;
  peak?: V3;
  children: ReactNode;
}) {
  const [shown, setShown] = useState<V3>(base);
  const [anim, setAnim] = useState<{ name: string; key: number } | null>(null);
  const k = useRef(0);
  const baseKey = base.join();

  // stage growth: animate to the new base, then commit it as the resting prop
  useEffect(() => {
    if (baseKey === shown.join()) return;
    setAnim({ name: scale3Anim(base, 900), key: ++k.current });
    const t = setTimeout(() => {
      setShown(base);
      setAnim(null);
    }, 950);
    return () => clearTimeout(t);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [baseKey]);

  // reaction pulse: up, then settle back
  useEffect(() => {
    if (trigger === 0) return;
    const up: V3 = [base[0] * peak[0], base[1] * peak[1], base[2] * peak[2]];
    setAnim({ name: scale3Anim(up, 160), key: ++k.current });
    const t1 = setTimeout(() => setAnim({ name: scale3Anim(base, 380), key: ++k.current }), 170);
    const t2 = setTimeout(() => {
      setShown(base);
      setAnim(null);
    }, 600);
    return () => {
      clearTimeout(t1);
      clearTimeout(t2);
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [trigger]);

  return (
    <ViroNode ignoreEventHandling position={position} rotation={rotation} scale={shown} animation={anim ? { name: anim.name, run: true } : undefined}>
      {children}
    </ViroNode>
  );
}

/** Expanding ring of light across the terrain – fired by big cascades and special crystals. */
const Shockwave = memo(function Shockwave({ trigger, strength }: { trigger: number; strength: number }) {
  const [waves, setWaves] = useState<number[]>([]);
  useEffect(() => {
    if (trigger === 0) return;
    setWaves((w) => [...w, trigger]);
    const t = setTimeout(() => setWaves((w) => w.filter((x) => x !== trigger)), 1000);
    return () => clearTimeout(t);
  }, [trigger]);
  return (
    <>
      {waves.map((id) => (
        <ViroQuad
          key={id}
          position={[0, SURFACE_Y + 0.004, 0.02]}
          rotation={[-90, 0, 0]}
          width={0.1}
          height={0.1}
          scale={[1, 1, 1]}
          materials={["shockRing"]}
          ignoreEventHandling
          animation={{ name: strength > 1 ? "shockwaveBig" : "shockwave", run: true }}
        />
      ))}
    </>
  );
});

const stageValue = <T,>(stage: WorldStage, values: [T, T, T, T, T]) => values[stage];

const BLOOMS: V3[] = [[0.2, SURFACE_Y, 0.2], [-0.17, SURFACE_Y, 0.25], [0.28, SURFACE_Y, 0.05], [-0.31, SURFACE_Y, 0.16], [0.12, SURFACE_Y, -0.12], [-0.12, SURFACE_Y, -0.16], [0.02, SURFACE_Y, 0.29]];
const CLUSTERS: V3[] = [[0.23, SURFACE_Y, -0.08], [-0.2, SURFACE_Y, -0.02], [0.08, SURFACE_Y, -0.29]];
const PORTAL_CENTER: V3 = [0, SURFACE_Y + 0.105, -0.232];

export function ForestWorld() {
  const stage = useStore(gameStore, (s) => s.stage);
  const r = useStore(gameStore, (s) => s.reactions);

  const bloomBase = stageValue(stage, [0.08, 0.7, 1, 1.1, 1.25]);
  const vineBase = stageValue(stage, [0.35, 0.7, 0.9, 1.05, 1.2]);
  const fallBase = stageValue(stage, [0.55, 0.75, 1, 1.1, 1.2]);
  const portalBase = stageValue(stage, [0.22, 0.4, 0.62, 0.85, 1.12]);
  const clusterBase = stageValue(stage, [0.8, 0.9, 1, 1.15, 1.3]);

  const plantPulse = r.MATCH_3 + r.MATCH_4 + r.MATCH_5;
  const vinePulse = r.MATCH_4 + r.MATCH_5 + r.SPECIAL_CREATED;
  const waterPulse = r.MATCH_5 + r.CASCADE_3 + r.CASCADE_4_PLUS + r.COMBO;
  const portalPulse = r.MATCH_4 + r.MATCH_5 + r.SPECIAL_ACTIVATED + r.LEVEL_COMPLETE + r.CASCADE_2;
  const shock = r.CASCADE_3 + r.CASCADE_4_PLUS + r.SPECIAL_ACTIVATED + r.COMBO + r.LEVEL_COMPLETE;

  return (
    <>
      <Model source={MODELS.terrain} ignoreEventHandling />
      <Model source={MODELS.propsBack} ignoreEventHandling />
      <Model source={MODELS.propsLeft} ignoreEventHandling />
      <Model source={MODELS.propsRight} ignoreEventHandling />

      {/* waterfall off the back-left cliff */}
      <Reactive position={[-0.25, SURFACE_Y + 0.17, -0.155]} base={[1, fallBase, 1]} trigger={waterPulse} peak={[1.5, 1.1, 1.6]}>
        <Model source={MODELS.waterfall} ignoreEventHandling />
      </Reactive>
      <Gated>
<ViroParticleEmitter
        position={[-0.25, SURFACE_Y + 0.005, -0.13]}
        run
        loop
        image={{ source: TEXTURES.spark, width: 0.008, height: 0.008, bloomThreshold: 1 }}
        spawnBehavior={{ particleLifetime: [600, 1100], emissionRatePerSecond: [8 + stage * 6, 12 + stage * 8], maxParticles: 40, spawnVolume: { shape: "box", params: [0.04, 0.005, 0.02] } }}
        particleAppearance={{ opacity: { initialRange: [0.7, 0.9], factor: "Time", interpolation: [{ endValue: 0, interval: [300, 1100] }] }, color: { initialRange: ["#e8fbff", "#bfefff"] } }}
        particlePhysics={{ velocity: { initialRange: [[-0.01, 0.02, 0], [0.01, 0.05, 0.02]] } }}
      />
</Gated>

      {/* portal: dormant → awakening → open */}
      <Reactive position={PORTAL_CENTER} base={[portalBase, portalBase, 1]} trigger={portalPulse} peak={[1.25, 1.25, 1]}>
        <ViroNode animation={{ name: stage >= 4 ? "spinPortalFast" : "spinPortal", run: true, loop: true }}>
          <GemMesh name="portal_core" />
        </ViroNode>
      </Reactive>
      {stage >= 2 && (
        <Gated>
<ViroParticleEmitter
          position={PORTAL_CENTER}
          run
          loop
          image={{ source: TEXTURES.spark, width: 0.01, height: 0.01, bloomThreshold: 1 }}
          spawnBehavior={{ particleLifetime: [900, 1600], emissionRatePerSecond: stage >= 4 ? [60, 80] : [6 * stage, 10 * stage], maxParticles: 120, spawnVolume: { shape: "sphere", params: [0.06], spawnOnSurface: true } }}
          particleAppearance={{ opacity: { initialRange: [0.9, 1], factor: "Time", interpolation: [{ endValue: 0, interval: [500, 1600] }] }, color: { initialRange: ["#9ff0ff", "#ffffff"] } }}
          particlePhysics={{ velocity: { initialRange: stage >= 4 ? [[-0.08, 0.05, 0.02], [0.08, 0.2, 0.12]] : [[-0.01, 0.01, 0.0], [0.01, 0.04, 0.02]] } }}
        />
</Gated>
      )}

      {/* vines on the tall pillar and the wall fragment */}
      <Reactive position={[-0.14, SURFACE_Y + 0.17, -0.214]} base={[1, vineBase, 1]} trigger={vinePulse} peak={[1.1, 1.3, 1.1]}>
        <GemMesh name="vines" />
      </Reactive>
      <Reactive position={[-0.1, SURFACE_Y + 0.054, -0.286]} base={[1.2, vineBase * 0.7, 1]} trigger={vinePulse} peak={[1.1, 1.3, 1.1]}>
        <GemMesh name="vines" />
      </Reactive>

      {/* flowers awaken with progress and pulse on every match */}
      {BLOOMS.map((p, i) => (
        <Reactive key={i} position={p} rotation={[0, i * 47, 0]} base={[bloomBase, bloomBase, bloomBase]} trigger={plantPulse} peak={[1.3, 1.45, 1.3]}>
          <GemMesh name="bloom" />
        </Reactive>
      ))}

      {/* glowing crystal outcrops */}
      {CLUSTERS.map((p, i) => (
        <Reactive key={i} position={p} rotation={[0, i * 70, 0]} base={[clusterBase, clusterBase, clusterBase]} trigger={portalPulse + plantPulse} peak={[1.15, 1.35, 1.15]}>
          <GemMesh name="glow_cluster" />
        </Reactive>
      ))}

      {/* drifting fireflies – kept behind the board: emitter volumes take part in hit-testing */}
      <Gated>
<ViroParticleEmitter
        position={[0, SURFACE_Y + 0.13, -0.25]}
        run
        loop
        image={{ source: TEXTURES.spark, width: 0.006, height: 0.006, bloomThreshold: 1 }}
        spawnBehavior={{ particleLifetime: [2500, 4000], emissionRatePerSecond: [3 + stage * 2, 5 + stage * 3], maxParticles: 40, spawnVolume: { shape: "box", params: [0.6, 0.12, 0.12] } }}
        particleAppearance={{ opacity: { initialRange: [0, 0], factor: "Time", interpolation: [{ endValue: 1, interval: [0, 800] }, { endValue: 0, interval: [2000, 4000] }] }, color: { initialRange: ["#fff6b0", "#c8ffd8"] } }}
        particlePhysics={{ velocity: { initialRange: [[-0.01, -0.004, -0.01], [0.01, 0.01, 0.01]] } }}
      />
</Gated>

      <Shockwave trigger={shock} strength={r.CASCADE_4_PLUS + r.LEVEL_COMPLETE > 0 ? 2 : 1} />
    </>
  );
}
