// The living environment: creatures lapping the island, drifting mist, and a slow day/night light. Everything is a
// sprite or an empty node driven by a native loop animation (no per-frame JS), the materials are registered at boot
// (registry.ts), and nothing loads a file while playing.
import { memo, useEffect, useMemo, useState } from "react";
import { ViroDirectionalLight, ViroNode, ViroQuad } from "@reactvision/react-viro";
import { gameStore } from "../../state/game";
import { settingsStore } from "../../state/settings";
import { createStore, useStore } from "../../state/store";
import { EXCITED_MS, lifeMaterial, placeCritters, type Placed } from "./lifeData";

// ------------------------------------------------------------- shared beats --
// A creature that flaps or bobs needs an "up" and a "down" step (a looped to-value animation snaps back). Rather than
// a timer per creature, a few shared beats toggle and every creature listens: ~25 tiny re-renders a second at most.
function makeBeat(ms: number) {
  const store = createStore({ up: false });
  let users = 0, timer: ReturnType<typeof setInterval> | undefined;
  const use = () => {
    useEffect(() => {
      if (users++ === 0) timer = setInterval(() => store.set((s) => ({ up: !s.up })), ms);
      return () => {
        if (--users === 0 && timer) clearInterval(timer);
      };
    }, []);
    return useStore(store, (s) => s.up);
  };
  return use;
}
const useFlapBeat = makeBeat(240);   // wing beats
export const usePulseBeat = makeBeat(1450); // bells and glows breathing
const useDriftBeat = makeBeat(2700); // slow bobbing

const isFlat = (s: Placed["sprite"]) => s === "bird" || s === "butterfly" || s === "manta" || s === "shard";

/** One creature: orbit node (laps the island) → radius node → bob node → sprite node (flap / pulse) → quad. */
const Creature = memo(function Creature({ c, lap }: { c: Placed; lap: number }) {
  const flapUp = useFlapBeat();
  const pulseUp = usePulseBeat();
  const driftUp = useDriftBeat();
  const flat = isFlat(c.sprite);
  const flying = c.sprite === "butterfly";
  const soft = c.sprite === "jelly" || c.sprite === "wisp";
  const sprite =
    flying && c.flap ? { name: flapUp ? "flapIn" : "flapOut", run: true, interruptible: true }
    : soft && c.flap ? { name: pulseUp ? "pulseIn" : "pulseOut", run: true, interruptible: true }
    : c.sprite === "shard" ? { name: "spinSlow", run: true, loop: true }
    : undefined;
  const bob = flat && !flying ? undefined : { name: driftUp ? "driftUp" : "driftDown", run: true, interruptible: true };
  return (
    <ViroNode position={[0, c.y, 0]} animation={{ name: `orbit${lap}`, run: true, loop: true, delay: c.delay }} ignoreEventHandling>
      <ViroNode position={[c.r, 0, 0]} ignoreEventHandling>
        <ViroNode animation={bob} ignoreEventHandling>
          <ViroNode animation={sprite} transformBehaviors={flat ? undefined : ["billboard"]} ignoreEventHandling>
            <ViroQuad
              rotation={flat ? [-90, 0, 0] : [0, 0, 0]}
              width={c.size}
              height={c.size}
              materials={[lifeMaterial(c.sprite, c.tint)]}
              ignoreEventHandling
            />
          </ViroNode>
        </ViroNode>
      </ViroNode>
    </ViroNode>
  );
});

/**
 * The realm's creatures. A big cascade, a special gem or a finished level excites them: for a few seconds they lap
 * faster (the animation name changes, which restarts the loop at the new speed).
 */
export function Life({ realm }: { realm: string }) {
  const classic = useStore(settingsStore, (s) => s.classicGems);
  const kicks = useStore(gameStore, (s) => s.reactions.CASCADE_3 + s.reactions.CASCADE_4_PLUS + s.reactions.SPECIAL_ACTIVATED + s.reactions.LEVEL_COMPLETE);
  const [excited, setExcited] = useState(false);
  useEffect(() => {
    if (!kicks) return;
    setExcited(true);
    const t = setTimeout(() => setExcited(false), 4500);
    return () => clearTimeout(t);
  }, [kicks]);
  const critters = useMemo(() => placeCritters(realm), [realm]);
  if (classic) return null;
  return (
    <ViroNode ignoreEventHandling>
      {critters.map((c) => (
        <Creature key={c.key} c={c} lap={excited ? EXCITED_MS[c.lap] : c.lap} />
      ))}
    </ViroNode>
  );
}

// -------------------------------------------------------------------- mist --
/**
 * Slow cloud discs around and under the island: they hide the crumpled front and underside of the models and make the
 * island feel like it floats in weather. A disc of cloud texture turning about the island's centre reads as clouds
 * drifting, and the loop is seamless.
 */
export const Mist = memo(function Mist() {
  const classic = useStore(settingsStore, (s) => s.classicGems);
  if (classic) return null;
  const discs: { y: number; size: number; anim: string }[] = [
    { y: -0.03, size: 1.7, anim: "mistSpinA" },
    { y: -0.11, size: 2.0, anim: "mistSpinB" },
  ];
  return (
    <>
      {discs.map((d, i) => (
        <ViroNode key={i} position={[0, d.y, 0.02]} animation={{ name: d.anim, run: true, loop: true }} ignoreEventHandling>
          <ViroQuad rotation={[-90, 0, 0]} width={d.size} height={d.size} materials={["mistDisc"]} ignoreEventHandling />
        </ViroNode>
      ))}
    </>
  );
});

// ------------------------------------------------------------------- light --
/**
 * The sun crosses the sky slowly: over a couple of minutes the light warms and cools and the shadows swing across
 * the board and island. It lives in its own component so only this re-renders (every 5 s).
 */
export function DayLight({ color, intensity, shadow }: { color: string; intensity: number; shadow: boolean }) {
  const classic = useStore(settingsStore, (s) => s.classicGems);
  const [t, setT] = useState(0);
  useEffect(() => {
    if (classic) return;
    const id = setInterval(() => setT(Date.now() / 1000), 5000);
    return () => clearInterval(id);
  }, [classic]);
  const phase = classic ? 0 : (t % 150) / 150;
  const swing = Math.sin(phase * Math.PI * 2);
  return (
    <ViroDirectionalLight
      color={color}
      direction={[-0.45 + swing * 0.3, -1, -0.5 + Math.cos(phase * Math.PI * 2) * 0.12]}
      intensity={intensity * (1 + swing * 0.05)}
      castsShadow={shadow}
      shadowOpacity={0.55}
      shadowOrthographicSize={0.9}
      shadowOrthographicPosition={[0, 0.8, 0]}
      shadowMapSize={2048}
      shadowNearZ={0.05}
      shadowFarZ={2.5}
      shadowBias={0.0015}
    />
  );
}
