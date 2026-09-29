// Dev-only comparison (not linked from the UI): open /dev/models in the web preview.
// Top row: the optimised Meshy GLB files. Middle row: the same models baked to the in-memory game LOD. Bottom
// row: the classic in-memory meshes. Same lighting as the game, and the Meshy models load through the same one-at-a-time queue.
import { useEffect, useState } from "react";
import { View } from "react-native";
import { useLocalSearchParams } from "expo-router";
import { Viro3DSceneNavigator, ViroAmbientLight, ViroCamera, ViroDirectionalLight, ViroNode, ViroScene } from "@reactvision/react-viro";
import { ClassicGem, MESHY_NAMES, MeshyGem, registerGemMaterials, registerMeshyMaterial } from "@/src/render/GemMesh";
import { LightingEnvironment, Model } from "@/src/render/LoadQueue";
import { MESHY_MODELS, TEXTURES } from "@/src/render/assets";
import { registerMaterials } from "@/src/render/registry";

registerMaterials();
registerGemMaterials();
MESHY_NAMES.forEach(registerMeshyMaterial);

const NAMES = ["gem_red", "gem_blue", "gem_green", "gem_purple", "gem_gold", "gem_prism", "gem_relic", "surge_aura"] as const;
const X0 = -0.63, DX = 0.18, S = 0.14;

function Scene() {
  // spin slowly so every side is visible in a still frame taken at any moment
  const { yaw } = useLocalSearchParams<{ yaw?: string }>();
  const [ready, setReady] = useState(false);
  useEffect(() => setReady(true), []);
  const r = Number(yaw ?? 0);
  return (
    <ViroScene>
      <ViroCamera position={[0, 0, 0.9]} active={ready} fieldOfView={90} />
      <LightingEnvironment source={TEXTURES.environment} />
      <ViroAmbientLight color="#ffffff" intensity={700} />
      <ViroDirectionalLight color="#fff4e0" direction={[-0.45, -1, -0.5]} intensity={1100} />
      {NAMES.map((n, i) => (
        <ViroNode key={n} position={[X0 + i * DX, 0.2, 0]} rotation={[0, r, 0]}>
          <Model source={MESHY_MODELS[n]} scale={[S, S, S]} rotation={[n === "gem_prism" || n === "gem_relic" || n === "surge_aura" ? 0 : -28, 0, 0]} />
        </ViroNode>
      ))}
      {NAMES.map((n, i) => (
        <ViroNode key={"m" + n} position={[X0 + i * DX, 0, 0]} rotation={[0, r, 0]}>
          <MeshyGem name={n} scale={[S, S, S]} rotation={[n === "gem_prism" || n === "gem_relic" || n === "surge_aura" ? 0 : -28, 0, 0]} />
        </ViroNode>
      ))}
      {NAMES.map((n, i) => (
        <ViroNode key={"g" + n} position={[X0 + i * DX, -0.2, 0]} rotation={[0, r, 0]}>
          <ClassicGem name={n} scale={[S, S, S]} rotation={[n === "gem_prism" || n === "gem_relic" || n === "surge_aura" ? 0 : -28, 0, 0]} />
        </ViroNode>
      ))}
    </ViroScene>
  );
}

export default function ModelCompare() {
  return (
    <View style={{ flex: 1, backgroundColor: "#22283a" }}>
      <Viro3DSceneNavigator initialScene={{ scene: Scene as never }} style={{ flex: 1 }} />
    </View>
  );
}
