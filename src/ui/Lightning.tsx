import { useEffect } from "react";
import { StyleSheet } from "react-native";
import Animated, { useAnimatedStyle, useSharedValue, withSequence, withTiming } from "react-native-reanimated";
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
  const flash = useSharedValue(0);
  const st = useAnimatedStyle(() => ({ opacity: flash.value }));

  useEffect(() => {
    if (!WEATHER[realm]?.lightning) return;
    let t: ReturnType<typeof setTimeout>;
    const strike = () => {
      flash.value = withSequence(
        withTiming(0.55, { duration: 50 }),
        withTiming(0.08, { duration: 90 }),
        withTiming(0.4, { duration: 60 }),
        withTiming(0, { duration: 520 }),
      );
      // thunder arrives after the light, as it would from a distant storm
      setTimeout(() => gameEvents.emit({ type: "haptic", kind: "light" }), 700 + Math.random() * 900);
      t = setTimeout(strike, 18000 + Math.random() * 27000);
    };
    t = setTimeout(strike, 6000 + Math.random() * 10000);
    return () => clearTimeout(t);
  }, [realm, flash]);

  return <Animated.View pointerEvents="none" style={[StyleSheet.absoluteFill, { backgroundColor: "#e6ecff" }, st]} />;
}
