import { Pressable, StyleSheet, Text, type ViewStyle } from "react-native";
import { C, font } from "./theme";

type Props = {
  label: string;
  onPress: () => void;
  variant?: "primary" | "ghost";
  style?: ViewStyle;
  testID?: string;
};

export function Button({ label, onPress, variant = "ghost", style, testID }: Props) {
  const primary = variant === "primary";
  return (
    <Pressable
      testID={testID}
      accessibilityRole="button"
      accessibilityLabel={label}
      onPress={onPress}
      style={({ pressed }) => [s.base, primary ? s.primary : s.ghost, pressed && { opacity: 0.75, transform: [{ scale: 0.98 }] }, style]}
    >
      <Text style={[s.text, primary && { color: "#20160a" }]}>{label}</Text>
    </Pressable>
  );
}

const s = StyleSheet.create({
  base: { minHeight: 52, borderRadius: 26, paddingHorizontal: 28, alignItems: "center", justifyContent: "center" },
  primary: { backgroundColor: C.gold, shadowColor: C.gold, shadowOpacity: 0.45, shadowRadius: 14, elevation: 6 },
  ghost: { backgroundColor: "rgba(255,255,255,0.06)", borderWidth: StyleSheet.hairlineWidth, borderColor: C.line },
  text: { color: C.ink, fontSize: 15, fontWeight: "700", letterSpacing: 2.2, fontFamily: font.body },
});
