import { useEffect, useState } from "react";
import { StyleSheet, Text, View } from "react-native";
import { arSession } from "../state/arSession";
import { currentBoardHash, gameStore } from "../state/game";
import { settingsStore } from "../state/settings";
import { useStore } from "../state/store";

/** Static scene nodes outside the board: island, shadow, waterfall, portal, 2 vines, 7 blooms, 3 clusters, emitters. */
const STATIC_OBJECTS = 20;

/** Developer overlay – hidden unless Settings › Diagnostics is on. */
export function Diagnostics({ mock }: { mock: boolean }) {
  // release builds never show the developer overlay, whatever an older debug build saved
  const enabled = useStore(settingsStore, (s) => __DEV__ && s.diagnostics);
  const ar = useStore(arSession, (s) => s);
  const crystals = useStore(gameStore, (s) => s.crystals.length);
  const bursts = useStore(gameStore, (s) => s.bursts.length);
  const lastMatch = useStore(gameStore, (s) => s.lastMatch);
  const moves = useStore(gameStore, (s) => s.moveCount);
  const [fps, setFps] = useState(0);

  useEffect(() => {
    if (!enabled) return;
    let frames = 0;
    let raf = 0;
    let last = Date.now();
    const tick = () => {
      frames++;
      const now = Date.now();
      if (now - last >= 1000) {
        setFps(Math.round((frames * 1000) / (now - last)));
        frames = 0;
        last = now;
      }
      raf = requestAnimationFrame(tick);
    };
    raf = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(raf);
  }, [enabled]);

  if (!enabled) return null;
  const lines = [
    `mode ${mock ? (ar.tracking === "camera" ? "TABLETOP" : "DEV_AR_MOCK") : "AR"}  js-fps ${fps}`,
    `tracking ${ar.tracking}${ar.trackingReason ? ` (${ar.trackingReason})` : ""}  planes ${ar.planes}`,
    `anchor ${ar.anchorId ?? "-"}  yaw ${ar.yaw.toFixed(0)}°  scale ${ar.worldScale}`,
    `objects ${crystals + STATIC_OBJECTS}  gems ${crystals}  bursts ${bursts}`,
    `board ${currentBoardHash()}  moves ${moves}`,
    `last ${lastMatch}`,
    `light ${Math.round(ar.lightIntensity)} ${ar.lightColor}`,
    `error ${ar.lastError || "-"}`,
  ];
  return (
    <View pointerEvents="none" style={s.box}>
      {lines.map((l) => (
        <Text key={l} style={s.t}>
          {l}
        </Text>
      ))}
    </View>
  );
}

const s = StyleSheet.create({
  box: { position: "absolute", left: 8, bottom: 84, padding: 8, borderRadius: 8, backgroundColor: "rgba(0,0,0,0.55)" },
  t: { color: "#9cf29c", fontSize: 10, fontFamily: "monospace" },
});
