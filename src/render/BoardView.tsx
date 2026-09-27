import { memo } from "react";
import { Viro3DObject, ViroNode, ViroParticleEmitter, ViroQuad } from "@reactvision/react-viro";
import { DEV_AR_MOCK, JS_PICKING } from "../config";
import { gameStore, pressCell, releaseCell, type Burst } from "../state/game";
import { useStore } from "../state/store";
import { CRYSTAL_COLORS, MODELS, TEXTURES } from "./assets";
import { CrystalNode } from "./CrystalNode";
import { BOARD_OFFSET, BOARD_SIZE, BOARD_TILT_DEG, CELL, cellToLocal } from "./layout";

const CLICK_DOWN = 1;
const PAD_Y = 0.016;
const CLICK_UP = 2;

const onCell = (x: number, y: number) => (state: number, position?: number[]) => {
  if (DEV_AR_MOCK) ((globalThis as Record<string, unknown>).__hits as unknown[] | undefined)?.push({ x, y, state, position });
  if (state === CLICK_DOWN) pressCell({ x, y });
  else if (state === CLICK_UP) releaseCell({ x, y });
};

/** Invisible per-cell touch pads: native hit-testing resolves which cell a finger is on. */
const CellPads = memo(function CellPads({ selKey }: { selKey: string }) {
  const pads = [];
  for (let y = 0; y < BOARD_SIZE; y++)
    for (let x = 0; x < BOARD_SIZE; x++) {
      const [px, , pz] = cellToLocal(x, y);
      pads.push(
        <ViroQuad
          key={`${x}_${y}`}
          // above the platform border AABB (tops out ~0.013) so pads win the bounding-box hit test
          position={[px, PAD_Y, pz]}
          rotation={[-90, 0, 0]}
          width={CELL * 0.98}
          height={CELL * 0.98}
          materials={selKey === `${x}_${y}` ? ["cellSelected"] : ["cellPad"]}
          onClickState={JS_PICKING ? undefined : onCell(x, y)}
        />,
      );
    }
  return <>{pads}</>;
});

const BurstFx = memo(function BurstFx({ burst }: { burst: Burst }) {
  const [x, y, z] = cellToLocal(burst.x, burst.y);
  const color = CRYSTAL_COLORS[burst.type];
  return (
    <ViroParticleEmitter
      position={[x, y, z]}
      duration={220}
      run
      loop={false}
      fixedToEmitter={false}
      image={{ source: TEXTURES.spark, height: 0.012, width: 0.012, bloomThreshold: 0.0 }}
      spawnBehavior={{
        particleLifetime: [450, 850],
        emissionRatePerSecond: burst.big ? [140, 180] : [60, 80],
        maxParticles: burst.big ? 36 : 16,
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
  );
});

export function BoardView() {
  const crystals = useStore(gameStore, (s) => s.crystals);
  const selected = useStore(gameStore, (s) => s.selected);
  const bursts = useStore(gameStore, (s) => s.bursts);
  const selKey = selected ? `${selected.x}_${selected.y}` : "";

  return (
    <ViroNode position={BOARD_OFFSET} rotation={[BOARD_TILT_DEG, 0, 0]}>
      <Viro3DObject source={MODELS.platform} type="GLB" ignoreEventHandling />
      <CellPads selKey={selKey} />
      {crystals.map((c) => (
        <ViroNode key={c.id} onClickState={JS_PICKING ? undefined : onCell(c.x, c.y)}>
          <CrystalNode crystal={c} selected={!!selected && selected.x === c.x && selected.y === c.y} />
        </ViroNode>
      ))}
      {bursts.map((b) => (
        <BurstFx key={b.id} burst={b} />
      ))}
    </ViroNode>
  );
}
