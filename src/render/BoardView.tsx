import { memo, useEffect, useState, type ReactNode } from "react";
import { ViroNode, ViroParticleEmitter, ViroQuad } from "@reactvision/react-viro";
import { Model, Gated } from "./LoadQueue";
import { DEV_AR_MOCK, JS_PICKING } from "../config";
import { gameStore, pressCell, releaseCell, type Burst } from "../state/game";
import { useStore } from "../state/store";
import { CRYSTAL_COLORS, MODELS, TEXTURES } from "./assets";
import { CrystalNode } from "./CrystalNode";
import { BOARD_OFFSET, BOARD_SIZE, BOARD_TILT_DEG, CELL, cellToLocal, rollFor } from "./layout";
import { GemMesh } from "./GemMesh";

const CLICK_DOWN = 1;
const PAD_Y = 0.016;
const CLICK_UP = 2;

const onCell = (x: number, y: number) => (state: number, position?: number[]) => {
  if (DEV_AR_MOCK) ((globalThis as Record<string, unknown>).__hits as unknown[] | undefined)?.push({ x, y, state, position });
  if (state === CLICK_DOWN) pressCell({ x, y });
  else if (state === CLICK_UP) releaseCell({ x, y });
};

/** Invisible per-cell touch pads: native hit-testing resolves which cell a finger is on. */
const CellPads = memo(function CellPads({ selKey, hintKey, voids }: { selKey: string; hintKey: string; voids: string }) {
  const pads = [];
  for (let y = 0; y < BOARD_SIZE; y++)
    for (let x = 0; x < BOARD_SIZE; x++) {
      if (voids[y * BOARD_SIZE + x] === "1") continue;
      const [px, , pz] = cellToLocal(x, y);
      pads.push(
        <ViroQuad
          key={`${x}_${y}`}
          // above the platform border AABB (tops out ~0.013) so pads win the bounding-box hit test
          position={[px, PAD_Y, pz]}
          rotation={[-90, 0, 0]}
          width={CELL * 0.98}
          height={CELL * 0.98}
          materials={selKey === `${x}_${y}` ? ["cellSelected"] : hintKey.includes(`|${x}_${y}|`) ? ["cellHint"] : ["cellPad"]}
          onClickState={JS_PICKING ? undefined : onCell(x, y)}
        />,
      );
    }
  return <>{pads}</>;
});

/**
 * Spark bursts come from a fixed pool of emitters mounted once. Creating an emitter loads its
 * texture on a Viro background task; doing that on every match raced Viro's task scheduler on
 * mid-range phones. Each slot is re-aimed at a new cell and switched on briefly.
 */
const POOL = 8;
const EMIT_MS = 240;

const PooledEmitter = memo(function PooledEmitter({ burst }: { burst: Burst | undefined }) {
  const [on, setOn] = useState(false);
  const [last, setLast] = useState<Burst | undefined>(burst);
  useEffect(() => {
    if (!burst) return;
    setLast(burst);
    setOn(true);
    const t = setTimeout(() => setOn(false), EMIT_MS);
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
      image={{ source: TEXTURES.spark, height: 0.012, width: 0.012, bloomThreshold: 0.0 }}
      spawnBehavior={{
        particleLifetime: [450, 850],
        emissionRatePerSecond: b?.big ? [140, 180] : [60, 80],
        maxParticles: b?.big ? 36 : 16,
        spawnVolume: { shape: "sphere", params: [0.01], spawnOnSurface: false },
      }}
      particleAppearance={{
        opacity: { initialRange: [1, 1], factor: "Time", interpolation: [{ endValue: 0, interval: [350, 850] }] },
        scale: { initialRange: [[1, 1, 1], [1.6, 1.6, 1.6]], factor: "Time", interpolation: [{ endValue: [0.2, 0.2, 0.2], interval: [0, 850] }] },
        color: { initialRange: [color, "#ffffff"] },
      }}
      particlePhysics={{
        velocity: { initialRange: [[-0.12, 0.08, -0.12], [0.12, 0.26, 0.12]] },
        acceleration: { initialRange: [[0, -0.45, 0], [0, -0.45, 0]] },
      }}
    />
</Gated>
  );
});

function BurstPool({ bursts }: { bursts: Burst[] }) {
  const slots: (Burst | undefined)[] = Array.from({ length: POOL });
  for (const b of bursts) slots[b.id % POOL] = b; // newest burst wins its slot
  return (
    <>
      {slots.map((b, i) => (
        <PooledEmitter key={i} burst={b} />
      ))}
    </>
  );
}

/** One carved stone column per playable cell – void cells are real gaps in the ruins. */
const Sockets = memo(function Sockets({ voids }: { voids: string }) {
  const out = [];
  for (let y = 0; y < BOARD_SIZE; y++)
    for (let x = 0; x < BOARD_SIZE; x++) {
      if (voids[y * BOARD_SIZE + x] === "1") continue;
      const [px, , pz] = cellToLocal(x, y);
      out.push(<GemMesh key={x + "_" + y} name={(x + y) % 2 ? "socket_a" : "socket_b"} position={[px, 0, pz]} />);
    }
  return <>{out}</>;
});

/** Cracked stone standing in its socket, and glowing runes buried in socket tops. */
const Obstacles = memo(function Obstacles({ blocks, floor }: { blocks: string; floor: string }) {
  const out = [];
  for (let i = 0; i < BOARD_SIZE * BOARD_SIZE; i++) {
    const x = i % BOARD_SIZE, y = Math.floor(i / BOARD_SIZE);
    const [px, , pz] = cellToLocal(x, y);
    const b = Number(blocks[i] ?? 0), f = Number(floor[i] ?? 0);
    if (b > 0) out.push(<GemMesh key={`s${i}_${b}`} name={`ob_stone${Math.min(3, b)}`} position={[px, 0, pz]} />);
    if (f > 0) out.push(<GemMesh key={`r${i}_${f}`} name={`ob_rune${Math.min(2, f)}`} position={[px, 0, pz]} />);
  }
  return <>{out}</>;
});

/** Board group: tilted toward the player, and rolled toward the current gravity. */
function TiltingBoard({ children }: { children: ReactNode }) {
  const gravity = useStore(gameStore, (s) => s.gravity);
  const [shown, setShown] = useState(gravity);
  const [anim, setAnim] = useState<string | null>(null);
  useEffect(() => {
    if (gravity === shown) return;
    setAnim("tilt" + gravity);
    const t = setTimeout(() => {
      setShown(gravity);
      setAnim(null);
    }, 420);
    return () => clearTimeout(t);
  }, [gravity]); // eslint-disable-line react-hooks/exhaustive-deps
  return (
    <ViroNode position={BOARD_OFFSET} rotation={[BOARD_TILT_DEG, 0, rollFor(shown)]} animation={anim ? { name: anim, run: true } : undefined}>
      {children}
    </ViroNode>
  );
}

export function BoardView() {
  const crystals = useStore(gameStore, (s) => s.crystals);
  const selected = useStore(gameStore, (s) => s.selected);
  const bursts = useStore(gameStore, (s) => s.bursts);
  const hint = useStore(gameStore, (s) => s.hint);
  const hintKey = hint ? `|${hint[0].x}_${hint[0].y}|${hint[1].x}_${hint[1].y}|` : "";
  const selKey = selected ? `${selected.x}_${selected.y}` : "";
  const voids = useStore(gameStore, (s) => (s.session?.engine.board.void ?? []).map((v) => (v ? "1" : "0")).join(""));
  // hp per cell as digit strings: cheap to compare, so obstacles only re-render when they change
  const blocks = useStore(gameStore, (s) => (s.blocks ?? []).map((v) => Math.min(9, v)).join(""));
  const floor = useStore(gameStore, (s) => (s.floor ?? []).map((v) => Math.min(9, v)).join(""));

  return (
    <TiltingBoard>
      <Sockets voids={voids} />
      <Obstacles blocks={blocks} floor={floor} />
      <CellPads selKey={selKey} hintKey={hintKey} voids={voids} />
      {crystals.map((c) => (
        <ViroNode key={c.id} onClickState={JS_PICKING ? undefined : onCell(c.x, c.y)}>
          <CrystalNode crystal={c} selected={!!selected && selected.x === c.x && selected.y === c.y} />
        </ViroNode>
      ))}
      <BurstPool bursts={bursts} />
    </TiltingBoard>
  );
}
