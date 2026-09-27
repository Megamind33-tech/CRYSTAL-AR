import { ViroAmbientLight, ViroDirectionalLight, ViroNode } from "@reactvision/react-viro";
import { Model, LightingEnvironment } from "./LoadQueue";
import { arSession } from "../state/arSession";
import { useStore } from "../state/store";
import { MODELS, TEXTURES } from "./assets";
import { BoardView } from "./BoardView";
import { ForestWorld } from "./ForestWorld";

/**
 * The miniature world, identical in AR and mock mode.
 * Hierarchy: anchor (provided by caller) → yaw/scale → materialize → island, world props, board.
 */
export function GameWorld({ ambientIntensity, ambientColor }: { ambientIntensity: number; ambientColor: string }) {
  const yaw = useStore(arSession, (s) => s.yaw);
  const worldScale = useStore(arSession, (s) => s.worldScale);
  // Keep the diorama readable in dim rooms while still following the room's light level.
  const ambient = Math.min(900, Math.max(320, ambientIntensity * 0.55));
  const sun = Math.min(1400, Math.max(650, ambientIntensity * 0.9));

  return (
    <ViroNode rotation={[0, yaw, 0]} scale={[worldScale, worldScale, worldScale]}>
      {/* image-based lighting: gives crystal facets their glints */}
      <LightingEnvironment source={TEXTURES.environment} />
      <ViroAmbientLight color={ambientColor} intensity={ambient} />
      <ViroDirectionalLight
        color="#fff1d8"
        direction={[-0.45, -1, -0.5]}
        intensity={sun}
        castsShadow
        shadowOpacity={0.55}
        shadowOrthographicSize={0.9}
        shadowOrthographicPosition={[0, 0.8, 0]}
        shadowMapSize={2048}
        shadowNearZ={0.05}
        shadowFarZ={2.5}
        shadowBias={0.0015}
      />
      <ViroNode scale={[0.02, 0.02, 0.02]} animation={{ name: "materialize", run: true }}>
        <Model source={MODELS.groundShadow} position={[0.02, 0.001, 0.02]} renderingOrder={-1} ignoreEventHandling />
        <ForestWorld />
        <BoardView />
      </ViroNode>
    </ViroNode>
  );
}
