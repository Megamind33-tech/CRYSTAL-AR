import { L } from "./lux/tokens";

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
