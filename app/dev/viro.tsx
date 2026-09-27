// Dev-only renderer smoke test (not linked from the UI): one lit box + one GLB crystal.
import { View } from "react-native";
import { Viro3DObject, Viro3DSceneNavigator, ViroAmbientLight, ViroBox, ViroCamera, ViroScene, ViroSkyBox } from "@reactvision/react-viro";
import { MODELS } from "@/src/render/assets";

function SmokeScene() {
  return (
    <ViroScene>
      <ViroCamera position={[0, 0, 1]} active />
      <ViroSkyBox color="#224466" />
      <ViroAmbientLight color="#ffffff" intensity={800} />
      <ViroBox position={[-0.2, 0, 0]} scale={[0.15, 0.15, 0.15]} onClickState={(st, pos) => console.log("BOXCLICK", st, JSON.stringify(pos))} onClick={() => console.log("BOXCLICKED")} />
      <Viro3DObject source={MODELS.gems[0]} type="GLB" position={[0.2, 0, 0]} scale={[0.2, 0.2, 0.2]} />
    </ViroScene>
  );
}

export default function ViroSmoke() {
  return (
    <View style={{ flex: 1 }}>
      <Viro3DSceneNavigator initialScene={{ scene: SmokeScene as never }} style={{ flex: 1 }} />
    </View>
  );
}
