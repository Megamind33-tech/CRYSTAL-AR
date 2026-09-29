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
    cellHint: {
      lightingModel: "Constant",
      diffuseColor: "rgba(255,214,120,0.30)",
      blendMode: "Add",
      writesToDepthBuffer: false,
    },
    placementGlow: {
      lightingModel: "Constant",
      diffuseColor: "rgba(150,235,255,0.22)",
      blendMode: "Alpha",
      writesToDepthBuffer: false,
    },
    tableMock: { lightingModel: "Lambert", diffuseTexture: TEXTURES.tableWood, diffuseColor: "#ffffff" },
    floorMock: { lightingModel: "Lambert", diffuseColor: "#3a3f47" },
    backdropMock: { lightingModel: "Constant", diffuseTexture: TEXTURES.roomBackdrop, diffuseColor: "#ffffff" },
    skyMock: { lightingModel: "Constant", diffuseTexture: TEXTURES.sky, diffuseColor: "#ffffff" },
    cloudSea: { lightingModel: "Constant", diffuseTexture: TEXTURES.cloudSea, diffuseColor: "#ffffff", blendMode: "Alpha", writesToDepthBuffer: false },
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
    tiltleft: { properties: { rotateX: 10, rotateZ: 8 }, duration: 380, easing: "EaseInEaseOut" },
    tiltright: { properties: { rotateX: 10, rotateZ: -8 }, duration: 380, easing: "EaseInEaseOut" },
    tiltdown: { properties: { rotateX: 10, rotateZ: 0 }, duration: 380, easing: "EaseInEaseOut" },
    materialize: { properties: { scaleX: 1, scaleY: 1, scaleZ: 1 }, duration: 1100, easing: "EaseOut" },
    // --- crystal motion (transform-only, absolute targets; stepped from JS, see useMotion.ts) ---
    // clear: a quick swell then a shrink-away (70 + 160 ≈ TIMING.pop; the Slow pair covers the 2× pops)
    popSwell: { properties: { scaleX: 1.22, scaleY: 1.22, scaleZ: 1.22 }, duration: 70, easing: "EaseOut" },
    popVanish: { properties: { scaleX: 0, scaleY: 0, scaleZ: 0 }, duration: 160, easing: "EaseIn" },
    popSwellSlow: { properties: { scaleX: 1.22, scaleY: 1.22, scaleZ: 1.22 }, duration: 150, easing: "EaseOut" },
    popVanishSlow: { properties: { scaleX: 0, scaleY: 0, scaleZ: 0 }, duration: 310, easing: "EaseIn" },
    // special activation: each flavour swells differently, all end in the same shrink-away
    flarePrism: { properties: { scaleX: 1.75, scaleY: 1.75, scaleZ: 1.75 }, duration: 90, easing: "EaseOut" },
    flareRelic: { properties: { scaleX: 1.45, scaleY: 1.45, scaleZ: 1.45 }, duration: 90, easing: "EaseOut" },
    flareSurge: { properties: { scaleX: 1.3, scaleY: 1.3, scaleZ: 1.3 }, duration: 90, easing: "EaseOut" },
    flareVanish: { properties: { scaleX: 0, scaleY: 0, scaleZ: 0 }, duration: 140, easing: "EaseIn" },
    relicFlip: { properties: { rotateY: 180 }, duration: 230, easing: "EaseOut" },
    // surge_aura is a flat plate whose long axis is local X: the parent is yawed 0°/90° in code for a
    // horizontal/vertical clear, so one stretch along local X serves both directions
    auraBlast: { properties: { scaleX: 2.6, scaleY: 0.7, scaleZ: 1 }, duration: 230, easing: "EaseOut" },
    auraBreathUp: { properties: { scaleX: 1.07, scaleY: 1.07, scaleZ: 1.07 }, duration: 800, easing: "EaseInEaseOut" },
    auraBreathDown: { properties: { scaleX: 1, scaleY: 1, scaleZ: 1 }, duration: 800, easing: "EaseInEaseOut" },
    // idle bob of special gems (~5 mm) and the restrained selection pulse
    bobUp: { properties: { positionY: 0.005 }, duration: 900, easing: "EaseInEaseOut" },
    bobDown: { properties: { positionY: 0 }, duration: 900, easing: "EaseInEaseOut" },
    selUp: { properties: { scaleX: 1.1, scaleY: 1.1, scaleZ: 1.1 }, duration: 420, easing: "EaseInEaseOut" },
    selDown: { properties: { scaleX: 1, scaleY: 1, scaleZ: 1 }, duration: 420, easing: "EaseInEaseOut" },
    // obstacle damage: a brief yaw rattle around the layer's own centre (no pivot or geometry change),
    // then the rest pose (the lower-strength mesh is swapped in by the game state) or a shrink-away
    impactA: { properties: { rotateY: 9, scaleX: 1.1, scaleY: 1.1, scaleZ: 1.1 }, duration: 50, easing: "EaseOut" },
    impactB: { properties: { rotateY: -7, scaleX: 0.95, scaleY: 0.95, scaleZ: 0.95 }, duration: 60, easing: "EaseInEaseOut" },
    impactRest: { properties: { rotateY: 0, scaleX: 1, scaleY: 1, scaleZ: 1 }, duration: 120, easing: "EaseOut" },
    impactVanish: { properties: { rotateY: 0, scaleX: 0, scaleY: 0, scaleZ: 0 }, duration: 130, easing: "EaseIn" },
    // PORTAL TRAVERSAL: the world rushes toward the camera until the portal fills the view…
    portalDive: { properties: { positionY: 0.06, positionZ: 0.88, scaleX: 2.5, scaleY: 2.5, scaleZ: 2.5 }, duration: 1150, easing: "EaseIn" },
    // …and the next island rises out of the light
    portalEmerge: { properties: { positionY: 0, positionZ: 0, scaleX: 1, scaleY: 1, scaleZ: 1 }, duration: 1000, easing: "EaseOut" },
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

/** Swell/vanish animation names and swell length (ms) for clearing a crystal, by kind of special. */
export function popSteps(special: string, ms: number): { swell: string; swellMs: number; vanish: string } {
  if (special === "prism") return { swell: "flarePrism", swellMs: 90, vanish: "flareVanish" };
  if (special === "relic") return { swell: "flareRelic", swellMs: 90, vanish: "flareVanish" };
  if (special === "surgeH" || special === "surgeV") return { swell: "flareSurge", swellMs: 90, vanish: "flareVanish" };
  return ms >= 400 ? { swell: "popSwellSlow", swellMs: 150, vanish: "popVanishSlow" } : { swell: "popSwell", swellMs: 70, vanish: "popVanish" };
}
