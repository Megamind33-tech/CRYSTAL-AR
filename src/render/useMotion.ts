// Small JS-side sequencers for the crystal/obstacle motion. Viro animation *chains* are silently dropped
// by the web renderer and a looped to-value animation snaps back on every cycle, so multi-step motion
// is stepped here: each step is a named animation from registry.ts whose onFinish (with a timer as a
// safety net, the same convention CrystalNode already uses) moves on to the next.
import { useEffect, useState } from "react";

/** Master switch for ambient (non-gameplay) motion, should a low-end phone ever need it off. */
export const IDLE_MOTION = true;

/**
 * Alternates `up` while `active`: used for bob / breath / pulse, which need an up step and a down step
 * (a looped single animation would jump back to its start each cycle). `flip` is safe to call from both
 * onFinish and the timer: a stale call for an already-advanced step is ignored.
 */
export function useAlternate(active: boolean, ms: number) {
  const [up, setUp] = useState(false);
  useEffect(() => {
    if (!active) return;
    const t = setTimeout(() => setUp((u) => !u), ms + 60);
    return () => clearTimeout(t);
  }, [active, up, ms]);
  const flip = () => setUp((u) => (u === up ? !u : u));
  return { up: active && up, flip };
}

export type ImpactPhase = "idle" | "hitA" | "hitB" | "rest" | "vanish" | "grow";
interface Impact {
  n: number;
  phase: ImpactPhase;
  /** hp shown right now (the old strength while the layer rattles, the new one afterwards) */
  shown: number;
  /** tag (e.g. cover kind) of the last layer that had hp > 0, so a breaking layer keeps its mesh */
  tag: string;
  /** hp this hit is heading to */
  to: number;
}

/** Step lengths (ms) – they match the animations of the same name in registry.ts. */
export const IMPACT_MS = { hitA: 50, hitB: 60, rest: 120, vanish: 130, grow: 280 };

/**
 * Damage feedback for one obstacle layer (a gem's ice/vine/chain/ember cover, a stone, a rune).
 * The game logic still owns hp; this only delays the *visual* swap: when hp drops the layer keeps its old
 * mesh for a brief rattle (hitA → hitB), then swaps to the lower state (rest) or shrinks away (vanish).
 * A rise from 0 grows in. A new change while one is playing simply restarts the sequence.
 */
export function useImpact(hp: number, tag: string) {
  const [seen, setSeen] = useState(hp);
  const [st, setSt] = useState<Impact>({ n: 0, phase: "idle", shown: hp, tag, to: hp });

  // derive from props during render (React's supported "adjust state on prop change" pattern)
  if (hp !== seen) {
    setSeen(hp);
    if (hp < seen) setSt((s) => ({ n: s.n + 1, phase: "hitA", shown: seen, tag: s.tag, to: hp }));
    else setSt((s) => ({ n: s.n + 1, phase: seen === 0 ? "grow" : "rest", shown: hp, tag, to: hp }));
  } else if (hp > 0 && tag !== st.tag && st.phase === "idle") {
    setSt((s) => ({ ...s, tag, shown: hp }));
  }

  const { n, phase, to } = st;
  const next = (from: ImpactPhase): Partial<Impact> | null =>
    from === "hitA" ? { phase: "hitB" }
    : from === "hitB" ? (to > 0 ? { phase: "rest", shown: to } : { phase: "vanish" })
    : from === "rest" || from === "grow" ? { phase: "idle" }
    : from === "vanish" ? { phase: "idle", shown: 0 }
    : null;
  const advance = (from: ImpactPhase) => setSt((s) => (s.n === n && s.phase === from ? { ...s, ...(next(from) ?? {}) } : s));

  useEffect(() => {
    if (phase === "idle") return;
    const t = setTimeout(() => advance(phase), IMPACT_MS[phase] + 40);
    return () => clearTimeout(t);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [n, phase]);

  return { phase, shown: st.shown, tag: st.tag, advance };
}

/** Animation prop for an impact phase (undefined when at rest). */
export function impactAnimation(phase: ImpactPhase, advance: (p: ImpactPhase) => void) {
  const name = phase === "hitA" ? "impactA" : phase === "hitB" ? "impactB" : phase === "rest" ? "impactRest" : phase === "vanish" ? "impactVanish" : phase === "grow" ? "forge" : null;
  return name ? { name, run: true, interruptible: true, onFinish: () => advance(phase) } : undefined;
}
