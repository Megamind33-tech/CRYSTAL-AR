import { ViroAmbientLight, ViroDirectionalLight, ViroNode } from "@reactvision/react-viro";
import { Model, LightingEnvironment } from "./LoadQueue";
import { arSession } from "../state/arSession";
import { useStore } from "../state/store";
import { MODELS, TEXTURES } from "./assets";
import { BoardView } from "./BoardView";
import { Dragons } from "./Dragon";
import { gameStore } from "../state/game";
import { IslandWorld, useBiomeLight } from "./island/IslandWorld";

/**
 * The miniature world, identical in AR and mock mode.
 * Hierarchy: anchor (provided by caller) → yaw/scale → materialize → island, world props, board.
 */
export function GameWorld({ ambientIntensity, ambientColor }: { ambientIntensity: number; ambientColor: string }) {
  const yaw = useStore(arSession, (s) => s.yaw);
  const worldScale = useStore(arSession, (s) => s.worldScale);
  const light = useBiomeLight();
  const travel = useStore(gameStore, (s) => s.travel);
  // portal traversal: dive toward the portal, then the next island rises from below the light
  const dive = travel?.phase === "dive";
  const emerge = travel?.phase === "emerge";
  // Keep the diorama readable in dim rooms while still following the room's light level.
  const ambient = Math.min(900, Math.max(320, ambientIntensity * 0.55));
  const sun = Math.min(1400, Math.max(650, ambientIntensity * 0.9)) * light.sunScale;

  return (
    <ViroNode rotation={[0, yaw, 0]} scale={[worldScale, worldScale, worldScale]}>
     <ViroNode
      position={emerge ? [0, -0.18, 0] : [0, 0, 0]}
      scale={emerge ? [0.45, 0.45, 0.45] : [1, 1, 1]}
      animation={dive ? { name: "portalDive", run: true } : emerge ? { name: "portalEmerge", run: true } : undefined}
     >
      {/* image-based lighting: gives crystal facets their glints */}
      <LightingEnvironment source={TEXTURES.environment} />
      {/* tabletop view mixes the room light with the realm mood; AR follows the real room */}
      <ViroAmbientLight color={ambientColor === "#ffffff" ? light.ambient : ambientColor} intensity={ambient} />
      <ViroDirectionalLight
        color={light.sun}
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
        <IslandWorld />
        <BoardView />
      </ViroNode>
      <Dragons />
     </ViroNode>
    </ViroNode>
  );
}
