import { useEffect, useRef } from "react";
import { ViroARPlaneSelector, ViroARScene, ViroAmbientLight } from "@reactvision/react-viro";
import type { ViroAnchor } from "@reactvision/react-viro/dist/components/Types/ViroEvents";
import { GameWorld } from "../render/GameWorld";
import { SanctuaryWorld } from "../render/SanctuaryWorld";
import { registerMaterials } from "../render/registry";
import { arSession } from "../state/arSession";
import { gameEvents } from "../state/game";
import { useStore } from "../state/store";
import { arLog } from "../dev/log";

registerMaterials();

const TRACKING = { 1: "unavailable", 2: "limited", 3: "normal" } as const;
const REASON = { 1: "", 2: "Moving too fast", 3: "Not enough surface detail" } as const;

/**
 * Production AR scene: detect horizontal surfaces, let the player tap one, and anchor the
 * whole miniature world to that plane. Children of the selector live in plane-local space.
 */
export default function ARGameScene() {
  const sceneRef = useRef<ViroARScene>(null);
  const selectorRef = useRef<ViroARPlaneSelector>(null);
  const resetRequest = useStore(arSession, (s) => s.resetRequest);
  const lightIntensity = useStore(arSession, (s) => s.lightIntensity);
  const lightColor = useStore(arSession, (s) => s.lightColor);
  const world = useStore(arSession, (s) => s.world);

  useEffect(() => {
    if (resetRequest > 0) selectorRef.current?.reset();
  }, [resetRequest]);

  const onPlaneSelected = async (plane: ViroAnchor, tapPosition?: [number, number, number]) => {
    let yaw = 0;
    try {
      const cam = await sceneRef.current?.getCameraOrientationAsync();
      const sel = selectorRef.current;
      if (cam && sel) {
        const camLocal = sel._worldToLocal(cam.position as [number, number, number], plane.position, plane.rotation);
        const tapLocal = tapPosition ? sel._worldToLocal(tapPosition, plane.position, plane.rotation) : [0, 0, 0];
        // turn the world's front (+Z) toward the player
        yaw = (Math.atan2(camLocal[0] - tapLocal[0], camLocal[2] - tapLocal[2]) * 180) / Math.PI;
      }
    } catch (e) {
      arSession.set({ lastError: `yaw: ${String(e)}` });
      arLog("error", { where: "yaw", error: String(e) });
    }
    arSession.set({ phase: "placed", anchorId: plane.anchorId, yaw });
    arLog("placed", { anchor: plane.anchorId, yaw: Math.round(yaw), tap: tapPosition, planeW: plane.width, planeH: plane.height });
    gameEvents.emit({ type: "sfx", name: "place" });
    gameEvents.emit({ type: "haptic", kind: "success" });
  };

  return (
    <ViroARScene
      ref={sceneRef}
      anchorDetectionTypes={["PlanesHorizontal"]}
      onAnchorFound={(a) => {
        selectorRef.current?.handleAnchorFound(a);
        if (a.type === "plane") {
          arLog("planeFound", { id: a.anchorId, w: a.width, h: a.height, alignment: a.alignment });
          arSession.set((s) => ({ planes: s.planes + 1, phase: s.phase === "scanning" ? "surfaceFound" : s.phase }));
        }
      }}
      onAnchorUpdated={(a) => selectorRef.current?.handleAnchorUpdated(a)}
      onAnchorRemoved={(a) => {
        if (!a) return;
        selectorRef.current?.handleAnchorRemoved(a);
        arSession.set((s) => ({ planes: Math.max(0, s.planes - 1) }));
      }}
      onTrackingUpdated={(state, reason) => {
        arLog("tracking", { state: TRACKING[state as 1 | 2 | 3], reason: REASON[reason as 1 | 2 | 3] });
        arSession.set({
          tracking: TRACKING[state as 1 | 2 | 3] ?? "unavailable",
          trackingReason: REASON[reason as 1 | 2 | 3] ?? "",
        });
      }}
      onAmbientLightUpdate={(info) => {
        // throttle: only store meaningful changes to avoid re-rendering the world every frame
        const s = arSession.get();
        if (Math.abs(info.intensity - s.lightIntensity) > 60 || info.color !== s.lightColor) {
          arSession.set({ lightIntensity: info.intensity, lightColor: info.color });
        }
      }}
    >
      <ViroAmbientLight color="#ffffff" intensity={400} />
      <ViroARPlaneSelector
        ref={selectorRef}
        alignment="HorizontalUpward"
        minWidth={0.2}
        minHeight={0.2}
        material="placementGlow"
        onPlaneSelected={onPlaneSelected}
        onPlaneRemoved={(id) => {
          // ARCore removes planes it merges into others; only the selected one matters
          const selected = arSession.get().anchorId;
          arLog("planeRemoved", { id, selected: id === selected });
          if (id === selected) arSession.set({ phase: "scanning", anchorId: null });
        }}
      >
        {world === "sanctuary" ? (
          <SanctuaryWorld ambientIntensity={lightIntensity} ambientColor={lightColor} />
        ) : (
          <GameWorld ambientIntensity={lightIntensity} ambientColor={lightColor} />
        )}
      </ViroARPlaneSelector>
    </ViroARScene>
  );
}
