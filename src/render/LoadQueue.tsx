// Serialises every Viro asset load (GLB models, particle textures, HDR environment).
// Why: on a Tecno Camon 19 Viro 3.0 aborts in VROPlatformRunTask (SIGSEGV on a pool thread) when
// many background load tasks run at once. One-at-a-time loading avoids that race entirely.
import { useEffect, useRef, type ReactElement, type ReactNode } from "react";
import { Viro3DObject, ViroLightingEnvironment } from "@reactvision/react-viro";
import { createStore, useStore } from "../state/store";

const queue = createStore({ granted: 1 });
let issued = 0;
/** Safety net: a load that never reports back must not stall the queue forever. */
const MAX_WAIT_MS = 5000;

const abandoned = new Set<number>();
/** Hand the turn to the next ticket, skipping any that unmounted before their turn came. */
function advance(from: number) {
  queue.set((s) => {
    if (from < s.granted) return {};
    let next = from + 1;
    while (abandoned.delete(next)) next++;
    return { granted: next };
  });
}

function useTicket() {
  const ticket = useRef(0);
  if (ticket.current === 0) ticket.current = ++issued;
  const granted = useStore(queue, (s) => s.granted);
  const released = useRef(false);
  const release = () => {
    if (released.current) return;
    released.current = true;
    if (ticket.current <= queue.get().granted) advance(ticket.current);
    else abandoned.add(ticket.current);
  };
  // unmounting before finishing hands the turn on (or marks the ticket to be skipped)
  useEffect(() => release, []); // eslint-disable-line react-hooks/exhaustive-deps
  return { turn: ticket.current <= granted, release };
}

function useWatchdog(turn: boolean, release: () => void, ms: number) {
  useEffect(() => {
    if (!turn) return;
    const t = setTimeout(release, ms);
    return () => clearTimeout(t);
  }, [turn]); // eslint-disable-line react-hooks/exhaustive-deps
}

type ModelProps = Omit<React.ComponentProps<typeof Viro3DObject>, "type" | "onLoadEnd" | "onError"> & { type?: "GLB" };

/** Drop-in for <Viro3DObject type="GLB"> that waits its turn in the load queue. */
export function Model(props: ModelProps) {
  const { turn, release } = useTicket();
  useWatchdog(turn, release, MAX_WAIT_MS);
  if (!turn) return null;
  return <Viro3DObject {...props} type="GLB" onLoadEnd={release} onError={release} />;
}

/** Gate for things without a load callback (particle emitters): mount, then release after a short settle. */
export function Gated({ children, settleMs = 120 }: { children: ReactNode; settleMs?: number }) {
  const { turn, release } = useTicket();
  useWatchdog(turn, release, settleMs);
  return turn ? (children as ReactElement) : null;
}

export function LightingEnvironment({ source }: { source: number }) {
  const { turn, release } = useTicket();
  useWatchdog(turn, release, MAX_WAIT_MS);
  if (!turn) return null;
  return <ViroLightingEnvironment source={source} onLoadEnd={release} onError={release} />;
}

/** Loads still waiting or in flight – drives the "island is rising" overlay. */
export function useLoadProgress() {
  const granted = useStore(queue, (s) => s.granted);
  const done = Math.max(0, granted - 1 - abandoned.size);
  return { done: Math.min(done, issued), total: issued, pending: Math.max(0, issued - (granted - 1)) };
}
