import { useEffect, useState } from "react";
import { ViroCamera, ViroQuad, ViroScene } from "@reactvision/react-viro";
import { GameWorld } from "../render/GameWorld";
import { DistantIslands } from "../render/island/IslandWorld";
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
  // Tabletop View (phones without ARCore) reuses this scene. Note: ViroCameraTexture cannot be used –
  // Viro 3.0.0 ships it without its native implementation on Android (UnsatisfiedLinkError).
  const tabletop = useStore(arSession, (s) => s.tracking === "camera");
  const phase = useStore(arSession, (s) => s.phase);
  const world = useStore(arSession, (s) => s.world);

  useEffect(() => {
    if (!tabletop) arSession.set({ tracking: "mock", planes: 1 });
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  // Android Viro can drop `active` when the camera mounts before the scene is attached, leaving the
  // default camera at the island's centre (the view "starts under the island"). Activate the table
  // camera once the scene is up, and again on every placement.
  const [camOn, setCamOn] = useState(false);
  useEffect(() => {
    setCamOn(false);
    const t = setTimeout(() => setCamOn(true), 120);
    return () => clearTimeout(t);
  }, [phase]);

  return (
    <ViroScene>
      {/* framed like a phone held above the table; web renderer uses a fixed 90° vertical FOV */}
      <ViroCamera key={`cam-${phase}`} position={MOCK_CAMERA.position} rotation={[MOCK_CAMERA.pitchDeg, 0, 0]} fieldOfView={MOCK_CAMERA.fovYDeg} active={camOn} />
      {/* the sky universe: no table – the island floats among clouds with others on the horizon */}
      <ViroQuad position={[0, -2.0, -2.8]} width={14} height={9} materials={["skyMock"]} />
      <ViroQuad position={[0, -0.42, -0.6]} rotation={[-90, 0, 0]} width={6} height={6} materials={["cloudSea"]} />
      <ViroQuad position={[0.8, -0.7, -1.4]} rotation={[-90, 0, 40]} width={7} height={7} materials={["cloudSea"]} />
      {phase === "placed" && world === "game" && <DistantIslands />}
      {phase === "placed" && (world === "sanctuary" ? <SanctuaryWorld ambientIntensity={1100} ambientColor="#ffffff" /> : <GameWorld ambientIntensity={1100} ambientColor="#ffffff" />)}
    </ViroScene>
  );
}
