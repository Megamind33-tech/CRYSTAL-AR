import { useEffect, useRef, useState } from "react";
import { Animated, StyleSheet, Text } from "react-native";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import { gameStore } from "../state/game";
import { useStore } from "../state/store";
import { C, font } from "./theme";

const HOLD = { story: 6500, twist: 2600, secret: 3800 } as const;
const ACCENT = { story: C.inkDim, twist: "#ffb070", secret: C.gold } as const;

/**
 * The island speaks: its arrival passage when you land, a line when a hidden twist strikes, and a
 * glint when a secret is found. Quiet, in-world, and gone on its own.
 */
export function Announce() {
  const insets = useSafeAreaInsets();
  const msg = useStore(gameStore, (s) => s.announce);
  const [shown, setShown] = useState(msg);
  const fade = useRef(new Animated.Value(0)).current;

  useEffect(() => {
    if (!msg) return;
    setShown(msg);
    fade.setValue(0);
    const anim = Animated.sequence([
      Animated.timing(fade, { toValue: 1, duration: 420, useNativeDriver: true }),
      Animated.delay(HOLD[msg.tone]),
      Animated.timing(fade, { toValue: 0, duration: 600, useNativeDriver: true }),
    ]);
    anim.start();
    return () => anim.stop();
  }, [msg?.seq]); // eslint-disable-line react-hooks/exhaustive-deps

  if (!shown) return null;
  return (
    <Animated.View
      pointerEvents="none"
      style={[s.wrap, { top: insets.top + 118, opacity: fade, borderColor: ACCENT[shown.tone], transform: [{ translateY: fade.interpolate({ inputRange: [0, 1], outputRange: [-8, 0] }) }] }]}
    >
      {shown.tone !== "story" && <Text style={[s.tag, { color: ACCENT[shown.tone] }]}>{shown.tone === "twist" ? "THE ISLAND STIRS" : "SECRET FOUND"}</Text>}
      <Text style={[s.text, shown.tone === "story" && { fontStyle: "italic" }]}>{shown.text}</Text>
    </Animated.View>
  );
}

const s = StyleSheet.create({
  wrap: {
    position: "absolute", left: 22, right: 22, paddingHorizontal: 16, paddingVertical: 10, borderRadius: 14,
    backgroundColor: "rgba(12,15,19,0.72)", borderWidth: StyleSheet.hairlineWidth, gap: 3,
  },
  tag: { fontSize: 10, letterSpacing: 2, fontWeight: "800" },
  text: { color: C.ink, fontSize: 14, lineHeight: 20, fontFamily: font.display, textAlign: "center" },
});
