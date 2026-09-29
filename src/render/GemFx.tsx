// Crystal effects: light pooled under each gem, twinkles, and the break effects (shards + flash ring).
// Everything is either a flat sprite quad or a pooled particle emitter mounted once (creating an emitter
// loads its texture on a Viro background task, and doing that per match raced Viro's scheduler on phones).
import { memo, useEffect, useRef, useState } from "react";
import { ViroNode, ViroParticleEmitter, ViroQuad } from "@reactvision/react-viro";
import { gameStore, type Burst } from "../state/game";
import { useStore } from "../state/store";
import { CRYSTAL_COLORS, TEXTURES } from "./assets";
import { Gated } from "./LoadQueue";
import { BOARD_SIZE, cellToLocal, CELL, spawnGate } from "./layout";

/** Light pooled on the tile under a crystal, tinted to its colour (a child of the crystal's cell node). */
export const GlowPad = memo(function GlowPad({ type, boost }: { type: number; boost: 0 | 1 | 2 }) {
  const k = boost === 2 ? 1.3 : boost === 1 ? 1.15 : 1;
  return (
    <ViroQuad
      position={[0, -0.0015, 0]}
      rotation={[-90, 0, 0]}
      width={CELL * 1.12}
      height={CELL * 1.12}
      scale={[k, k, k]}
      materials={[`fxGlow${type}`]}
      ignoreEventHandling
    />
  );
});

// ------------------------------------------------------------------ shards --
const SHARD_POOL = 8;
const SHARD_MS = 200;

const ShardEmitter = memo(function ShardEmitter({ burst }: { burst: Burst | undefined }) {
  const [on, setOn] = useState(false);
  const [last, setLast] = useState<Burst | undefined>(burst);
  useEffect(() => {
    if (!burst) return;
    setLast(burst);
    setOn(true);
    const t = setTimeout(() => setOn(false), SHARD_MS);
    return () => clearTimeout(t);
  }, [burst]);
  const b = last;
  const [x, y, z] = b ? cellToLocal(b.x, b.y) : [0, -1, 0];
  const color = CRYSTAL_COLORS[b?.type ?? 0];
  return (
    <Gated>
      <ViroParticleEmitter
        position={[x, y, z]}
        run={on}
        loop
        fixedToEmitter={false}
        image={{ source: TEXTURES.fxShard, height: 0.016, width: 0.011, bloomThreshold: 0.0 }}
        spawnBehavior={{
          particleLifetime: [480, 900],
          emissionRatePerSecond: b?.big ? [110, 140] : [50, 70],
          maxParticles: b?.big ? 24 : 10,
          spawnVolume: { shape: "sphere", params: [0.012], spawnOnSurface: false },
        }}
        particleAppearance={{
          opacity: { initialRange: [1, 1], factor: "Time", interpolation: [{ endValue: 0, interval: [380, 900] }] },
          scale: { initialRange: [[0.8, 0.8, 0.8], [1.5, 1.5, 1.5]], factor: "Time", interpolation: [{ endValue: [0.3, 0.3, 0.3], interval: [0, 900] }] },
          color: { initialRange: [color, color] },
        }}
        particlePhysics={{
          velocity: { initialRange: [[-0.2, 0.1, -0.2], [0.2, 0.34, 0.2]] },
          acceleration: { initialRange: [[0, -1.2, 0], [0, -1.2, 0]] },
        }}
      />
    </Gated>
  );
});

/** A fixed pool of shard emitters; each break is aimed at the slot its id maps to (newest wins). */
export function ShardPool({ bursts }: { bursts: Burst[] }) {
  const slots: (Burst | undefined)[] = Array.from({ length: SHARD_POOL });
  for (const b of bursts) slots[b.id % SHARD_POOL] = b;
  return (
    <>
      {slots.map((b, i) => (
        <ShardEmitter key={i} burst={b} />
      ))}
    </>
  );
}

// ------------------------------------------------------------------- flash --
/** A ring of light that swells out of a breaking crystal (one flat quad per recent break, animated once). */
export const FlashRings = memo(function FlashRings({ bursts }: { bursts: Burst[] }) {
  return (
    <>
      {bursts.slice(-10).map((b) => {
        const [x, y, z] = cellToLocal(b.x, b.y);
        return (
          <ViroQuad
            key={b.id}
            position={[x, y - 0.0012, z]}
            rotation={[-90, 0, 0]}
            width={CELL * (b.big ? 0.8 : 0.6)}
            height={CELL * (b.big ? 0.8 : 0.6)}
            materials={[`fxFlash${b.type}`]}
            ignoreEventHandling
            animation={{ name: "fxFlash", run: true }}
          />
        );
      })}
    </>
  );
});

// ---------------------------------------------------------------- twinkle --
/** Now and then a resting crystal catches the light: a small star flares at its shoulder and fades. */
export const Twinkles = memo(function Twinkles() {
  const [tw, setTw] = useState<{ id: number; x: number; y: number }[]>([]);
  const n = useRef(0);
  useEffect(() => {
    const t = setInterval(() => {
      const s = gameStore.get();
      if (s.busy || s.result || !s.crystals.length) return;
      const c = s.crystals[Math.floor(Math.random() * s.crystals.length)];
      if (c.anim) return;
      const id = ++n.current;
      setTw((w) => [...w.slice(-2), { id, x: c.x, y: c.y }]);
    }, 750);
    return () => clearInterval(t);
  }, []);
  return (
    <>
      {tw.map((t) => {
        const [x, y, z] = cellToLocal(t.x, t.y);
        return (
          <ViroNode key={t.id} position={[x + 0.011, y + 0.014, z - 0.004]} scale={[0.2, 0.2, 0.2]} transformBehaviors={["billboard"]} animation={{ name: "fxTwinkle", run: true }} ignoreEventHandling>
            <ViroQuad width={0.022} height={0.022} materials={["fxTwinkle"]} ignoreEventHandling />
          </ViroNode>
        );
      })}
    </>
  );
});

// ------------------------------------------------------------------ gates --
/**
 * The source of new crystals: a glowing gate on every lane of the edge the refill enters from (top for normal
 * gravity, a side while the tabletop is turned). New crystals stay hidden in the chute and materialise at their
 * gate (CrystalNode + spawnGate), so nothing pops into existence mid-air. A gate blooms when it feeds a crystal.
 */
export const SpawnGates = memo(function SpawnGates() {
  const gravity = useStore(gameStore, (s) => s.gravity);
  // newest spawn seq per lane, as one string so the selector compares by value
  const seqs = useStore(gameStore, (s) => {
    const lanes = Array<number>(BOARD_SIZE).fill(0);
    for (const c of s.crystals) {
      if (c.anim?.kind !== "spawn") continue;
      const g = spawnGate(c.anim.fromX, c.anim.fromY, c.x, c.y);
      if (!g) continue;
      const lane = g.gy === -1 ? g.gx : g.gy;
      if (lane >= 0 && lane < BOARD_SIZE) lanes[lane] = Math.max(lanes[lane], c.anim.seq);
    }
    return lanes.join(",");
  });
  const lane = seqs.split(",").map(Number);
  const gates = [];
  for (let i = 0; i < BOARD_SIZE; i++) {
    const [gx, gy] = gravity === "down" ? [i, -1] : gravity === "left" ? [BOARD_SIZE, i] : [-1, i];
    const [px, , pz] = cellToLocal(gx, gy);
    const fed = lane[i] > 0;
    // the gate itself never remounts (remounting its quads reads as flicker); only a fading halo is keyed to the feed
    gates.push(
      <ViroNode key={`${gravity}_${i}`} position={[px, 0.03, pz]} ignoreEventHandling>
        <ViroQuad rotation={[-90, 0, 0]} width={CELL * 1.5} height={CELL * 1.5} materials={["fxGateCore"]} ignoreEventHandling />
        <ViroQuad position={[0, 0.0006, 0]} rotation={[-90, 0, 0]} width={CELL * 1.05} height={CELL * 1.05} materials={["fxGate"]} ignoreEventHandling />
        {fed && (
          <ViroNode key={lane[i]} scale={[1.7, 1.7, 1.7]} animation={{ name: "fxGateBloom", run: true }} ignoreEventHandling>
            <ViroQuad position={[0, 0.0012, 0]} rotation={[-90, 0, 0]} width={CELL * 1.05} height={CELL * 1.05} materials={["fxGate"]} ignoreEventHandling />
          </ViroNode>
        )}
      </ViroNode>,
    );
  }
  return <>{gates}</>;
});
