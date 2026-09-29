import { useEffect, useRef, useState } from "react";
import { ViroNode, ViroParticleEmitter } from "@reactvision/react-viro";
import { DEV_AR_MOCK } from "../config";
import { LEVELS } from "../game/level";
import { gameStore } from "../state/game";
import { useStore } from "../state/store";
import { MODELS, TEXTURES } from "./assets";
import { Gated, Model } from "./LoadQueue";
import { BOARD_OFFSET, CELL } from "./layout";
import { moveAnim } from "./registry";

type V3 = [number, number, number];
type Breed = "red" | "green";
interface Flight {
  from: V3;
  to: V3;
  ms: number;
  /** wingspan in metres */
  span: number;
  breed: Breed;
}

/**
 * The two dragon models (CC-BY 3.0, Poly Pizza – see ASSET_LICENSES.md):
 *  red   – "Red Dragon" by Tomek Zamojski: wingspan ≈ 17 units, body along Z
 *  green – "Dragon Rigged" by na3ee1: wingspan ≈ 22 units (after its node scale), body along Z
 * `yaw` turns the model so its head leads along +X; `lift` recentres it vertically.
 */
const BREEDS: Record<Breed, { source: number; wingspan: number; yaw: number }> = {
  red: { source: MODELS.dragonRed, wingspan: 17, yaw: 90 },
  green: { source: MODELS.dragonGreen, wingspan: 22, yaw: 90 },
};

/** Realms whose skies dragons cross on their own, and which breed lives there. */
const SKY_BREED: Record<string, Breed> = { canyon: "red", sky: "red", solar: "red", ember: "red", void: "red", frozen: "green", hollow: "green", verdant: "green" };
const HIDDEN: V3 = [0, -40, 0];

/**
 * Dragons of the Fracture. Both models are loaded once, when the world is placed, and parked out of
 * sight; a flight moves one across the sky (loading models mid-game raced Viro's loader on the
 * Tecno Camon 19). A Dragon Fire twist sends the red dragon low over the board, breathing fire on
 * the row it crosses; in dragon realms one crosses the horizon every so often.
 */
export function Dragons() {
  const call = useStore(gameStore, (s) => s.dragon);
  const realm = useStore(gameStore, (s) => (s.session?.level ?? LEVELS[s.levelIndex]).realm ?? "verdant");
  const [flight, setFlight] = useState<(Flight & { seq: number }) | null>(null);
  const [fire, setFire] = useState<{ on: boolean; z: number }>({ on: false, z: 0 });
  const busy = useRef(false);
  const seq = useRef(1);

  const launch = (input: Flight) => {
    // preview-only slow motion so screenshots of the software renderer can catch a pass
    const slow = DEV_AR_MOCK ? Number((globalThis as Record<string, unknown>).__dragonSlow ?? 1) : 1;
    const f = { ...input, ms: input.ms * slow, seq: seq.current++ };
    busy.current = true;
    setFlight(f);
    setTimeout(() => {
      busy.current = false;
      setFlight(null);
    }, f.ms + 150);
  };

  // a twist summons a low pass with fire breath
  useEffect(() => {
    if (!call) return;
    const rowZ = BOARD_OFFSET[2] + (call.row - 2.5) * CELL;
    const dir = call.seq % 2 ? 1 : -1;
    launch({ from: [-0.8 * dir, 0.3, rowZ - 0.08], to: [0.8 * dir, 0.26, rowZ - 0.08], ms: 2800, span: 0.26, breed: "red" });
    const t1 = setTimeout(() => setFire({ on: true, z: rowZ }), 1000);
    const t2 = setTimeout(() => setFire((f) => ({ ...f, on: false })), 1900);
    return () => {
      clearTimeout(t1);
      clearTimeout(t2);
    };
  }, [call?.seq]); // eslint-disable-line react-hooks/exhaustive-deps

  // ambient flights across the horizon in dragon realms
  useEffect(() => {
    const breed = SKY_BREED[realm];
    if (!breed) return;
    let t: ReturnType<typeof setTimeout>;
    const schedule = (first: boolean) => {
      t = setTimeout(() => {
        if (!busy.current) {
          const dir = Math.random() < 0.5 ? 1 : -1;
          const h = 0.3 + Math.random() * 0.3, z = -1.3 - Math.random() * 0.6;
          launch({ from: [-2.4 * dir, h, z], to: [2.4 * dir, h + 0.12, z + 0.2], ms: 8000, span: 0.9, breed });
        }
        schedule(false);
      }, (first ? 8000 : 35000) + Math.random() * 40000);
    };
    schedule(true);
    return () => clearTimeout(t);
  }, [realm]); // eslint-disable-line react-hooks/exhaustive-deps

  return (
    <ViroNode ignoreEventHandling>
      {(["red", "green"] as Breed[]).map((breed) => {
        const b = BREEDS[breed];
        const active = flight?.breed === breed ? flight : null;
        const s = (active?.span ?? 0.5) / b.wingspan;
        const heading = active && active.to[0] < active.from[0] ? 180 : 0;
        return (
          <ViroNode
            key={breed}
            position={active ? active.from : HIDDEN}
            rotation={[0, heading, 0]}
            animation={active ? { name: moveAnim(active.to, active.ms), run: true } : undefined}
            ignoreEventHandling
          >
            <ViroNode rotation={[0, b.yaw, 0]} scale={[s, s, s]}>
              <Model source={b.source} ignoreEventHandling />
            </ViroNode>
          </ViroNode>
        );
      })}
      {/* dragon fire falling across the row the dragon sweeps */}
      <Gated>
        <ViroParticleEmitter
          position={[0, BOARD_OFFSET[1] + 0.12, fire.z]}
          run={fire.on}
          loop
          image={{ source: TEXTURES.spark, width: 0.016, height: 0.016, bloomThreshold: 0.5 }}
          spawnBehavior={{ particleLifetime: [500, 900], emissionRatePerSecond: [180, 240], maxParticles: 160, spawnVolume: { shape: "box", params: [0.34, 0.02, 0.03] } }}
          particleAppearance={{
            opacity: { initialRange: [1, 1], factor: "Time", interpolation: [{ endValue: 0, interval: [400, 900] }] },
            scale: { initialRange: [[1, 1, 1], [1.6, 1.6, 1.6]], factor: "Time", interpolation: [{ endValue: [3, 3, 3], interval: [0, 900] }] },
            color: { initialRange: ["#ffd070", "#ff6a1a"], factor: "Time", interpolation: [{ endValue: "#3a2a24", interval: [450, 900] }] },
          }}
          particlePhysics={{ velocity: { initialRange: [[-0.03, -0.22, -0.02], [0.03, -0.12, 0.02]] } }}
        />
      </Gated>
    </ViroNode>
  );
}
