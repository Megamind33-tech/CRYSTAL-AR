import { Platform, StyleSheet } from "react-native";

export const C = {
  ink: "#f4efe4",
  inkDim: "rgba(244,239,228,0.72)",
  inkFaint: "rgba(244,239,228,0.45)",
  glass: "rgba(14,18,22,0.58)",
  glassStrong: "rgba(12,15,19,0.86)",
  line: "rgba(255,241,210,0.18)",
  gold: "#f2c46b",
  goldDeep: "#c8913a",
  portal: "#8fe9ff",
  danger: "#ff8a7a",
  bg: "#0d1014",
};

export const font = {
  display: Platform.select({ ios: "Georgia", android: "serif", default: "Georgia, 'Times New Roman', serif" }),
  body: Platform.select({ ios: "System", android: "sans-serif", default: "system-ui, sans-serif" }),
};

export const ui = StyleSheet.create({
  glass: {
    backgroundColor: C.glass,
    borderColor: C.line,
    borderWidth: StyleSheet.hairlineWidth,
    borderRadius: 16,
  },
  label: { color: C.inkDim, fontSize: 11, letterSpacing: 1.6, fontFamily: font.body, textTransform: "uppercase" },
  value: { color: C.ink, fontSize: 18, fontWeight: "700", fontFamily: font.body },
});
