// GLASS ORB — the in-game secondary control (gravity turns, world turn/size). Plain RN views + Reanimated
// so any number of them can float over the 3D world without costing a Skia/WebGL context each.
// Night-glass core, gold filigree ring, cyan rim light, a breathing halo and a springy press flash.
import type { ReactNode } from "react";
import { Pressable, StyleSheet, Text, View } from "react-native";
import Animated, { useAnimatedStyle, useSharedValue, withSequence, withSpring, withTiming } from "react-native-reanimated";
import { useLoop } from "./Lux";
import { F, L, titleGlow } from "./tokens";

export function GlassOrb({ glyph, size = 48, tone = L.crystal, onPress, disabled, testID, accessibilityLabel, breathe = true, children }: {
  glyph?: string; size?: number; tone?: string; onPress?: () => void; disabled?: boolean; testID?: string; accessibilityLabel?: string;
  breathe?: boolean; children?: ReactNode;
}) {
  const press = useSharedValue(0);
  const flash = useSharedValue(0);
  const t = useLoop(2800);
  const off = disabled || !onPress;
  const body = useAnimatedStyle(() => ({ transform: [{ scale: 1 - press.value * 0.12 }] }));
  const halo = useAnimatedStyle(() => ({
    opacity: off ? 0 : (breathe ? 0.22 + Math.sin(t.value * Math.PI * 2) * 0.14 : 0.18) + flash.value * 0.6,
    transform: [{ scale: 1 + flash.value * 0.35 }],
  }));
  const r = size / 2;
  return (
    <Pressable
      testID={testID}
      accessibilityRole="button"
      accessibilityLabel={accessibilityLabel}
      disabled={off}
      onPress={onPress}
      onPressIn={() => (press.value = withSpring(1, { damping: 12, stiffness: 520 }))}
      onPressOut={() => {
        press.value = withSpring(0, { damping: 6, stiffness: 300 });
        flash.value = withSequence(withTiming(1, { duration: 90 }), withTiming(0, { duration: 420 }));
      }}
      style={{ width: size + 8, height: size + 8, alignItems: "center", justifyContent: "center", opacity: off ? 0.42 : 1 }}
    >
      <Animated.View pointerEvents="none" style={[o.halo, { width: size + 6, height: size + 6, borderRadius: r + 3, backgroundColor: tone, shadowColor: tone }, halo]} />
      <Animated.View style={[o.ring, { width: size, height: size, borderRadius: r }, body]}>
        <View style={[o.core, { borderRadius: r - 2.5 }]}>
          <View pointerEvents="none" style={[o.sheen, { borderTopLeftRadius: r, borderTopRightRadius: r, height: size * 0.42 }]} />
          <View pointerEvents="none" style={[o.rim, { borderRadius: r - 4, borderColor: tone + "55" }]} />
          {children ?? <Text style={[o.glyph, { color: tone, fontSize: size * 0.44, lineHeight: size * 0.56 }, titleGlow(tone, 8)]}>{glyph}</Text>}
        </View>
      </Animated.View>
    </Pressable>
  );
}

const o = StyleSheet.create({
  halo: { position: "absolute", shadowRadius: 14, shadowOpacity: 1, shadowOffset: { width: 0, height: 0 } },
  ring: {
    padding: 2.5, backgroundColor: L.gold, borderWidth: 1, borderTopColor: L.goldLight, borderLeftColor: L.goldPale,
    borderRightColor: L.filigree, borderBottomColor: L.goldDeep,
    shadowColor: "#02030f", shadowOpacity: 0.6, shadowRadius: 8, shadowOffset: { width: 0, height: 4 }, elevation: 6,
  },
  core: { flex: 1, backgroundColor: "rgba(16,21,56,0.94)", alignItems: "center", justifyContent: "center", overflow: "hidden" },
  sheen: { position: "absolute", left: 0, right: 0, top: 0, backgroundColor: "rgba(255,255,255,0.12)" },
  rim: { position: "absolute", left: 2, right: 2, top: 2, bottom: 2, borderWidth: 1 },
  glyph: { fontFamily: F.bold, textAlign: "center" },
});
