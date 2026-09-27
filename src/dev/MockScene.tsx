import { useEffect } from "react";
import { ViroCamera, ViroCameraTexture, ViroQuad, ViroScene } from "@reactvision/react-viro";
import { GameWorld } from "../render/GameWorld";
import { SanctuaryWorld } from "../render/SanctuaryWorld";
import { registerMaterials } from "../render/registry";
import { MOCK_CAMERA } from "./mockPicking";
import { arSession } from "../state/arSession";
import { useStore } from "../state/store";

registerMaterials();

/** Quad 3 m along the camera's view direction, sized to cover a 90° vertical FOV on a tall phone. */
const FEED_DIST = 3;
const pitch = (MOCK_CAMERA.pitchDeg * Math.PI) / 180;
const FEED_QUAD = {
  position: [0, MOCK_CAMERA.position[1] + Math.sin(pitch) * FEED_DIST, MOCK_CAMERA.position[2] - Math.cos(pitch) * FEED_DIST] as [number, number, number],
  rotation: [MOCK_CAMERA.pitchDeg, 0, 0] as [number, number, number],
  height: 2 * FEED_DIST * Math.tan(((MOCK_CAMERA.fovYDeg / 2) * Math.PI) / 180),
  width: 2 * FEED_DIST * Math.tan(((MOCK_CAMERA.fovYDeg / 2) * Math.PI) / 180) * 0.75,
};

/**
 * DEV_AR_MOCK: a fixed horizontal "table" plane standing in for the AR anchor.
 * Renders the exact same GameWorld / board / engine as production AR – only the anchor differs.
 * Not a production path: used for cloud iteration, screenshots and CI.
 */
export default function MockScene() {
  // Camera View (phones without ARCore) reuses this scene with the live camera feed as backdrop.
  const cameraFeed = useStore(arSession, (s) => s.tracking === "camera");
  const phase = useStore(arSession, (s) => s.phase);
  const world = useStore(arSession, (s) => s.world);

  useEffect(() => {
    if (!cameraFeed) arSession.set({ tracking: "mock", planes: 1 });
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  return (
    <ViroScene>
      {/* framed like a phone held above the table; web renderer uses a fixed 90° vertical FOV */}
      <ViroCamera position={MOCK_CAMERA.position} rotation={[MOCK_CAMERA.pitchDeg, 0, 0]} fieldOfView={MOCK_CAMERA.fovYDeg} active />
      {cameraFeed ? (
        <>
          {/* live camera image on a screen-filling quad perpendicular to the view, drawn first */}
          <ViroCameraTexture material="cameraFeed" cameraPosition="back" />
          <ViroQuad {...FEED_QUAD} materials={["cameraFeed"]} renderingOrder={-10} ignoreEventHandling />
        </>
      ) : (
        <>
          {/* backdrop (skybox colour is not supported by the web renderer) */}
          <ViroQuad position={[0, 0.2, -2.5]} width={12} height={8} materials={["backdropMock"]} />
          {/* the simulated table surface */}
          <ViroQuad position={[0, -0.001, 0]} rotation={[-90, 0, 0]} width={2.2} height={1.5} materials={["tableMock"]} />
          <ViroQuad position={[0, -0.75, 0]} rotation={[-90, 0, 0]} width={8} height={8} materials={["floorMock"]} />
        </>
      )}
      {phase === "placed" && (world === "sanctuary" ? <SanctuaryWorld ambientIntensity={1100} ambientColor="#ffffff" /> : <GameWorld ambientIntensity={1100} ambientColor="#ffffff" />)}
    </ViroScene>
  );
}
