// LUMINOUS FANTASY design tokens (Figma: "Crystals AR – Game UI" › Luminous v2 › Foundations).
// Deep night-sky glass, gold filigree, crystal light. Premium, playful motion – never childish.

export const L = {
  night900: "#070920",
  night800: "#0b0e24",
  night700: "#141a3d",
  night500: "#1e2352",
  night400: "#2a2f6a",
  violet: "#6a4bc8",
  aether: "#3fb8ff",
  crystal: "#7fe7ff",
  crystalSoft: "#bff4ff",
  goldLight: "#fff1b8",
  goldPale: "#f6d38a",
  gold: "#e0a94a",
  filigree: "#b87a28",
  goldDeep: "#8a5518",
  rose: "#ff7ad9",
  ember: "#ff9a5a",
  ivory: "#f5eedc",
  mist: "#b8b3d0",
  mistDim: "rgba(184,179,208,0.6)",
  ink: "#2a1606",
  danger: "#ff6a7a",
} as const;

/** Per-realm crystal light: [bright, deep]. */
export const REALM_LIGHT: Record<string, [string, string]> = {
  verdant: ["#8cf5a0", "#16703a"], canyon: ["#ffc98a", "#b8501e"], tide: ["#8ae8ff", "#1f6ab8"], sky: ["#fff2b8", "#b8841e"],
  hollow: ["#ffa8ec", "#8a2aa8"], caverns: ["#c0ccff", "#3a4ac0"], frozen: ["#e0f6ff", "#3a88c0"], solar: ["#ffe08a", "#c0700a"],
  ember: ["#ffab7a", "#b8281a"], void: ["#d8b0ff", "#5a2ab0"], eclipse: ["#c8b0ff", "#3a2a80"], signal: ["#d8f4ff", "#2a78b0"],
};

export const F = {
  display: "CinzelBlack",
  title: "CinzelBold",
  body: "PoppinsMedium",
  bodyStrong: "PoppinsSemiBold",
  bold: "PoppinsBold",
  number: "PoppinsExtraBold",
} as const;

/** Soft glow for Cinzel titles (RN text shadow). */
export const titleGlow = (c: string = L.gold, r = 12) => ({ textShadowColor: c, textShadowRadius: r, textShadowOffset: { width: 0, height: 0 } });
