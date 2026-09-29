import { StyleSheet } from "react-native";
import { F, L } from "./lux/tokens";

// Legacy palette names, now mapped onto the LUMINOUS FANTASY tokens (src/ui/lux/tokens.ts) so every
// screen that still uses `C` harmonises with the new look.
export const C = {
  ink: L.ivory,
  inkDim: "rgba(245,238,220,0.78)",
  inkFaint: "rgba(184,179,208,0.7)",
  glass: "rgba(20,26,61,0.72)",
  glassStrong: "rgba(11,14,36,0.9)",
  line: "rgba(246,211,138,0.28)",
  gold: L.goldPale,
  goldDeep: L.gold,
  portal: L.crystal,
  danger: L.danger,
  bg: L.night900,
};

export const font = {
  display: F.title,
  body: F.body,
  /** legacy alias from the saga-map pass (Lilita One) – now the Cinzel display face */
  candy: F.display,
};

export const ui = StyleSheet.create({
  glass: {
    backgroundColor: C.glass,
    borderColor: C.line,
    borderWidth: 1,
    borderRadius: 16,
  },
  label: { color: C.gold, fontSize: 11, letterSpacing: 2, fontFamily: F.title, textTransform: "uppercase" },
  value: { color: C.ink, fontSize: 18, fontFamily: F.number },
});
