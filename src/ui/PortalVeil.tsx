import { useEffect, useRef, useState } from "react";
import { Animated, StyleSheet, Text } from "react-native";
import { gameStore } from "../state/game";
import { useStore } from "../state/store";
import { font } from "./theme";

/**
 * The light inside the portal. It swells as the world rushes toward the gate, hides the swap to the
 * next island, and clears as the new island rises – there is no loading screen.
 */
export function PortalVeil() {
  const travel = useStore(gameStore, (s) => s.travel);
  const glow = useRef(new Animated.Value(0)).current;
  const [to, setTo] = useState("");

  useEffect(() => {
    // never stop a running fade from a cleanup: a cancelled fade-out left the screen stuck white.
    // Each phase simply animates toward its own target; when travel ends the veil always clears.
    if (!travel) {
      Animated.timing(glow, { toValue: 0, duration: 350, useNativeDriver: true }).start();
      return;
    }
    setTo(travel.to);
    if (travel.phase === "dive") Animated.sequence([Animated.delay(500), Animated.timing(glow, { toValue: 1, duration: 650, useNativeDriver: true })]).start();
    else Animated.sequence([Animated.delay(250), Animated.timing(glow, { toValue: 0, duration: 800, useNativeDriver: true })]).start();
  }, [travel?.phase, travel?.seq]); // eslint-disable-line react-hooks/exhaustive-deps

  return (
    <Animated.View pointerEvents={travel ? "auto" : "none"} style={[StyleSheet.absoluteFill, s.veil, { opacity: glow }]}>
      <Animated.View style={[s.core, { transform: [{ scale: glow.interpolate({ inputRange: [0, 1], outputRange: [0.2, 3.2] }) }] }]} />
      {to ? <Text style={s.to}>{to}</Text> : null}
    </Animated.View>
  );
}

const s = StyleSheet.create({
  veil: { backgroundColor: "rgba(200,244,255,0.94)", alignItems: "center", justifyContent: "center" },
  core: { position: "absolute", width: 260, height: 260, borderRadius: 130, backgroundColor: "#ffffff" },
  to: { color: "#1b3a48", fontFamily: font.display, fontStyle: "italic", fontSize: 22, letterSpacing: 0.5, textAlign: "center", paddingHorizontal: 30 },
});
