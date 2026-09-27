import { useEffect } from "react";
import { ViroCamera, ViroQuad, ViroScene } from "@reactvision/react-viro";
import { GameWorld } from "../render/GameWorld";
import { SanctuaryWorld } from "../render/SanctuaryWorld";
import { registerMaterials } from "../render/registry";
import { MOCK_CAMERA } from "./mockPicking";
import { arSession } from "../state/arSession";
import { useStore } from "../state/store";

registerMaterials();

/**
 * DEV_AR_MOCK: a fixed horizontal "table" plane standing in for the AR anchor.
 * Renders the exact same GameWorld / board / engine as production AR – only the anchor differs.
 * Not a production path: used for cloud iteration, screenshots and CI.
 */
export default function MockScene() {
  const phase = useStore(arSession, (s) => s.phase);
  const world = useStore(arSession, (s) => s.world);

  useEffect(() => {
    arSession.set({ tracking: "mock", planes: 1 });
  }, []);

  return (
    <ViroScene>
      {/* framed like a phone held above the table; web renderer uses a fixed 90° vertical FOV */}
      <ViroCamera position={MOCK_CAMERA.position} rotation={[MOCK_CAMERA.pitchDeg, 0, 0]} fieldOfView={MOCK_CAMERA.fovYDeg} active />
      {/* backdrop (skybox colour is not supported by the web renderer) */}
      <ViroQuad position={[0, 0.2, -2.5]} width={12} height={8} materials={["backdropMock"]} />
      {/* the simulated table surface */}
      <ViroQuad position={[0, -0.001, 0]} rotation={[-90, 0, 0]} width={2.2} height={1.5} materials={["tableMock"]} />
      <ViroQuad position={[0, -0.75, 0]} rotation={[-90, 0, 0]} width={8} height={8} materials={["floorMock"]} />
      {phase === "placed" && (world === "sanctuary" ? <SanctuaryWorld ambientIntensity={1100} ambientColor="#ffffff" /> : <GameWorld ambientIntensity={1100} ambientColor="#ffffff" />)}
    </ViroScene>
  );
}
