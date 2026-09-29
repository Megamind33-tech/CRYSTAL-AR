import { useEffect, useRef } from "react";
import { Animated, StyleSheet } from "react-native";
import { LEVELS } from "../game/level";
import { WEATHER } from "../render/island/biomes";
import { gameEvents, gameStore } from "../state/game";
import { useStore } from "../state/store";

/**
 * Storm realms throw lightning: a double flicker that lights the whole sky for an instant, then a
 * delayed rumble (felt as a light haptic). Purely atmospheric; it never covers input.
 */
export function Lightning() {
  const realm = useStore(gameStore, (s) => (s.session?.level ?? LEVELS[s.levelIndex]).realm ?? "verdant");
  const flash = useRef(new Animated.Value(0)).current;

  useEffect(() => {
    if (!WEATHER[realm]?.lightning) return;
    let t: ReturnType<typeof setTimeout>;
    const strike = () => {
      Animated.sequence([
        Animated.timing(flash, { toValue: 0.55, duration: 50, useNativeDriver: true }),
        Animated.timing(flash, { toValue: 0.08, duration: 90, useNativeDriver: true }),
        Animated.timing(flash, { toValue: 0.4, duration: 60, useNativeDriver: true }),
        Animated.timing(flash, { toValue: 0, duration: 520, useNativeDriver: true }),
      ]).start();
      // thunder arrives after the light, as it would from a distant storm
      setTimeout(() => gameEvents.emit({ type: "haptic", kind: "light" }), 700 + Math.random() * 900);
      t = setTimeout(strike, 18000 + Math.random() * 27000);
    };
    t = setTimeout(strike, 6000 + Math.random() * 10000);
    return () => clearTimeout(t);
  }, [realm, flash]);

  return <Animated.View pointerEvents="none" style={[StyleSheet.absoluteFill, { backgroundColor: "#e8f2ff", opacity: flash }]} />;
}
