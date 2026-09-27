// Viro material + animation registration. Animations with absolute targets are registered lazily
// (the web bridge ignores relative "+=" values), keyed by target so the set stays bounded.
import { ViroAnimations, ViroMaterials } from "@reactvision/react-viro";
import { TEXTURES } from "./assets";

let materialsReady = false;
export function registerMaterials() {
  if (materialsReady) return;
  materialsReady = true;
  ViroMaterials.createMaterials({
    cellPad: {
      lightingModel: "Constant",
      diffuseColor: "rgba(255,255,255,0.0)",
      blendMode: "Alpha",
      writesToDepthBuffer: false,
    },
    cellSelected: {
      lightingModel: "Constant",
      diffuseColor: "rgba(170,240,255,0.35)",
      blendMode: "Add",
      writesToDepthBuffer: false,
    },
    placementGlow: {
      lightingModel: "Constant",
      diffuseColor: "rgba(150,235,255,0.22)",
      blendMode: "Alpha",
      writesToDepthBuffer: false,
    },
    tableMock: { lightingModel: "Lambert", diffuseColor: "#8a6a4f" },
    floorMock: { lightingModel: "Lambert", diffuseColor: "#3a3f47" },
    backdropMock: { lightingModel: "Constant", diffuseColor: "#1c2127" },
    shockRing: {
      lightingModel: "Constant",
      diffuseTexture: TEXTURES.ringGlow,
      diffuseColor: "#bff4ff",
      blendMode: "Add",
      writesToDepthBuffer: false,
    },
    shadowCatcher: { lightingModel: "Lambert", diffuseColor: "#ffffff", writesToDepthBuffer: true },
  });

  ViroAnimations.registerAnimations({
    pop: { properties: { scaleX: 0, scaleY: 0, scaleZ: 0 }, duration: 230, easing: "EaseIn" },
    forge: { properties: { scaleX: 1, scaleY: 1, scaleZ: 1 }, duration: 280, easing: "Bounce" },
    spinSlow: { properties: { rotateY: 360 }, duration: 5200, easing: "Linear" },
    spinFast: { properties: { rotateY: 360 }, duration: 1300, easing: "Linear" },
    shockwave: { properties: { scaleX: 6, scaleY: 6, scaleZ: 6, opacity: 0 }, duration: 800, easing: "EaseOut" },
    shockwaveBig: { properties: { scaleX: 10, scaleY: 10, scaleZ: 10, opacity: 0 }, duration: 950, easing: "EaseOut" },
    spinPortal: { properties: { rotateZ: 360 }, duration: 9000, easing: "Linear" },
    spinPortalFast: { properties: { rotateZ: 360 }, duration: 2200, easing: "Linear" },
    materialize: { properties: { scaleX: 1, scaleY: 1, scaleZ: 1 }, duration: 1100, easing: "EaseOut" },
  });
}

const registered = new Set<string>();

/** Moves a node to an absolute board-local position (optionally scaling to 1). */
export function moveAnim(to: [number, number, number], ms: number, spawn = false): string {
  const name = `${spawn ? "sp" : "mv"}_${to.map((v) => v.toFixed(4)).join("_")}_${Math.round(ms)}`;
  if (!registered.has(name)) {
    registered.add(name);
    ViroAnimations.registerAnimations({
      [name]: {
        properties: {
          positionX: to[0],
          positionY: to[1],
          positionZ: to[2],
          ...(spawn ? { scaleX: 1, scaleY: 1, scaleZ: 1 } : {}),
        },
        duration: Math.round(ms),
        easing: spawn ? "EaseOut" : "EaseInEaseOut",
      },
    });
  }
  return name;
}

/** Scales a node uniformly to `s` – used for pulses and world growth. */
export function scaleAnim(s: number, ms: number, easing: "EaseOut" | "Bounce" | "EaseInEaseOut" | "EaseIn" = "EaseOut"): string {
  const name = `sc_${s.toFixed(3)}_${ms}_${easing}`;
  if (!registered.has(name)) {
    registered.add(name);
    ViroAnimations.registerAnimations({
      [name]: { properties: { scaleX: s, scaleY: s, scaleZ: s }, duration: ms, easing },
    });
  }
  return name;
}

/** Non-uniform scale target, e.g. waterfall surge (Y only). */
export function scale3Anim(s: [number, number, number], ms: number): string {
  const name = `s3_${s.map((v) => v.toFixed(3)).join("_")}_${ms}`;
  if (!registered.has(name)) {
    registered.add(name);
    ViroAnimations.registerAnimations({
      [name]: { properties: { scaleX: s[0], scaleY: s[1], scaleZ: s[2] }, duration: ms, easing: "EaseInEaseOut" },
    });
  }
  return name;
}
