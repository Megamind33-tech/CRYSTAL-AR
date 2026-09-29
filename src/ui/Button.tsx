import type { ViewStyle } from "react-native";
import { LuxButton } from "./lux/Lux";

type Props = {
  label: string;
  onPress: () => void;
  variant?: "primary" | "ghost";
  style?: ViewStyle;
  testID?: string;
};

/** Full-width action: primary = gold crystal (light sweep), ghost = aether glass. */
export function Button({ label, onPress, variant = "ghost", style, testID }: Props) {
  return <LuxButton label={label} onPress={onPress} variant={variant === "primary" ? "gold" : "glass"} hero={variant === "primary"} style={style} testID={testID} />;
}
