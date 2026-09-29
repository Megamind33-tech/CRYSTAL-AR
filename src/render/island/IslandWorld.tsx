import { memo, useMemo } from "react";
import { ViroGeometry, ViroMaterials, ViroNode, ViroParticleEmitter } from "@reactvision/react-viro";
import { LEVELS } from "../../game/level";
import { gameStore } from "../../state/game";
import { settingsStore } from "../../state/settings";
import { useStore } from "../../state/store";
import { PBR, TEXTURES } from "../assets";
import { Reactive, Shockwave } from "../ForestWorld";
import { GemMesh } from "../GemMesh";
import { Gated, Model } from "../LoadQueue";
import { materialsStore } from "../materialsStore";
import { MODELS } from "../assets";
import { BIOMES, biomeFor, WEATHER, type Biome, type Surface } from "./biomes";
import { buildDais, buildIsland, PORTAL_CENTER, SURFACE_Y, type MeshPart, type Slot } from "./buildIsland";
import { MeshyIslandMesh, useMeshyIsland } from "./MeshyIsland";
import { Life, Mist } from "./Life";
import { DaisTrim } from "./DaisTrim";

/**
 * Normal maps give the CC0 surfaces their relief. Viro derives tangents for custom geometry on
 * Android; flip this off if a device shows faceted/black lighting on the terrain.
 */
const USE_NORMAL_MAPS = false;

const registered = new Set<string>();
const matName = (biome: Biome, slot: Slot) => `isl_${biome.id}_${slot}`;
export const trimMat = (biome: Biome) => `isl_${biome.id}_trim`;

function surface(s: Surface, extra: object = {}) {
  return {
    lightingModel: "PBR",
    diffuseTexture: PBR[s.tex].c,
    ...(USE_NORMAL_MAPS ? { normalTexture: PBR[s.tex].n } : {}),
    diffuseColor: s.tint,
    roughness: s.roughness ?? 0.92,
    metalness: 0,
    wrapS: "Repeat",
    wrapT: "Repeat",
    ...extra,
  };
}

/** Viro materials for one biome, registered the first time that biome is shown. */
export function registerBiome(b: Biome) {
  if (registered.has(b.id)) return;
  registered.add(b.id);
  const flat = (color: string, roughness = 0.8) => ({ lightingModel: "PBR", diffuseColor: color, roughness, metalness: 0 });
  const defs: Record<Slot, object> = {
    top: surface(b.top),
    cliff: surface(b.cliff),
    stone: surface(b.stone),
    bark: surface({ tex: "bark", tint: b.id === "ember" ? "#4a3a34" : "#c8b8a8", tile: 30 }),
    leaf: flat(b.leaf),
    leafDark: flat(b.leafDark),
    accent: flat(b.accent, 0.6),
    stem: flat("#e8dfcf", 0.7),
    glow: { lightingModel: "Constant", diffuseColor: b.glow },
    lava: { lightingModel: "Constant", diffuseTexture: PBR.lava.c, diffuseColor: "#ffffff", wrapS: "Repeat", wrapT: "Repeat" },
    // glassy pale ice (the photo texture reads as dark navy at this size)
    ice: { lightingModel: "PBR", diffuseColor: "rgba(214,238,255,0.86)", roughness: 0.08, metalness: 0.15, blendMode: "Alpha" },
    water: { lightingModel: "PBR", diffuseColor: "rgba(70,160,210,0.72)", roughness: 0.05, metalness: 0.1, blendMode: "Alpha" },
  };
  ViroMaterials.createMaterials(Object.fromEntries(Object.entries(defs).map(([slot, d]) => [matName(b, slot as Slot), d])) as never);
  // the glowing rune line on the dais rim (DaisTrim): the realm's glow colour, soft-edged, unlit
  ViroMaterials.createMaterials({
    [trimMat(b)]: { lightingModel: "Constant", diffuseTexture: TEXTURES.fxGlow, diffuseColor: b.glow, blendMode: "Alpha", writesToDepthBuffer: false },
  } as never);
}


const IslandPart = memo(function IslandPart({ part, material }: { part: MeshPart; material: string }) {
  return (
    <Gated settleMs={160}>
      <ViroGeometry
        vertices={part.vertices}
        normals={part.normals}
        texcoords={part.texcoords}
        triangleIndices={part.indices}
        materials={[material]}
        ignoreEventHandling
      />
    </Gated>
  );
});

/** turret stands beside and behind the board, turned toward it: [x, z, yaw°] */
const TURRETS: [number, number, number][] = [[-0.27, -0.1, 55], [0.28, -0.04, -60]];
/** on a Meshy island the turrets stand on the dais rim instead */
const DAIS_TURRETS: [number, number, number][] = [[-0.225, -0.12, 55], [0.225, -0.12, -55]];

const stageValue = <T,>(stage: number, values: [T, T, T, T, T]) => values[stage];

/** Reactive crystal outcrops on the dais rim (a Meshy island has no procedural anchors): [x, z] */
const DAIS_CLUSTERS: [number, number][] = [[0.215, -0.1], [-0.215, -0.03], [0.215, 0.16]];

/**
 * The level's island: generated terrain, underside, portal arch and props for its realm, plus the
 * reactive portal, outcrops, blooms and particles that answer the player's matches.
 */
export function IslandWorld() {
  const level = useStore(gameStore, (s) => s.session?.level ?? LEVELS[s.levelIndex]);
  const biome = biomeFor(level.realm);
  const seed = level.islandSeed ?? level.seed;
  // a Meshy island under the board (fitted with a stone dais), or the procedural one when off / not yet registered
  const meshy = useMeshyIsland(biome.id);
  const island = useMemo(() => buildIsland(biome, seed), [biome, seed]);
  const dais = useMemo(() => (meshy ? buildDais(biome, seed, meshy.bottomY) : null), [meshy, biome, seed]);
  // materials are registered ahead of time (materialsBoot); draw the ground once this realm is ready
  const ready = useStore(materialsStore, (m) => m.realms.includes(biome.id));
  const key = `${biome.id}_${seed}`;

  const stage = useStore(gameStore, (s) => s.stage);
  const r = useStore(gameStore, (s) => s.reactions);
  const bloomBase = stageValue(stage, [0.08, 0.7, 1, 1.1, 1.25]);
  const portalBase = stageValue(stage, [0.22, 0.4, 0.62, 0.85, 1.12]);
  const clusterBase = stageValue(stage, [0.8, 0.9, 1, 1.15, 1.3]);
  const plantPulse = r.MATCH_3 + r.MATCH_4 + r.MATCH_5;
  const portalPulse = r.MATCH_4 + r.MATCH_5 + r.SPECIAL_ACTIVATED + r.LEVEL_COMPLETE + r.CASCADE_2;
  const shock = r.CASCADE_3 + r.CASCADE_4_PLUS + r.SPECIAL_ACTIVATED + r.COMBO + r.LEVEL_COMPLETE;
  const p = biome.particles;
  const weather = WEATHER[biome.id] ?? WEATHER.verdant;

  return (
    <ViroNode ignoreEventHandling>
      {meshy && ready ? (
        <>
          <MeshyIslandMesh realm={biome.id} lod="hero" />
          <DaisTrim material={trimMat(biome)} />
          {dais!.map((part) => (
            <IslandPart key={`${key}_dais`} part={part} material={matName(biome, part.slot)} />
          ))}
        </>
      ) : (
        ready && island.parts.map((part) => (
          <IslandPart key={`${key}_${part.slot}`} part={part} material={matName(biome, part.slot)} />
        ))
      )}

      {/* portal: dormant → awakening → open */}
      <Reactive position={PORTAL_CENTER} base={[portalBase, portalBase, 1]} trigger={portalPulse} peak={[1.25, 1.25, 1]}>
        <ViroNode animation={{ name: stage >= 4 ? "spinPortalFast" : "spinPortal", run: true, loop: true }}>
          <GemMesh name="portal_core" />
        </ViroNode>
      </Reactive>
      {stage >= 2 && (
        <Gated>
          <ViroParticleEmitter
            position={PORTAL_CENTER}
            run
            loop
            image={{ source: TEXTURES.spark, width: 0.01, height: 0.01, bloomThreshold: 1 }}
            spawnBehavior={{ particleLifetime: [900, 1600], emissionRatePerSecond: stage >= 4 ? [60, 80] : [6 * stage, 10 * stage], maxParticles: 120, spawnVolume: { shape: "sphere", params: [0.06], spawnOnSurface: true } }}
            particleAppearance={{ opacity: { initialRange: [0.9, 1], factor: "Time", interpolation: [{ endValue: 0, interval: [500, 1600] }] }, color: { initialRange: ["#9ff0ff", "#ffffff"] } }}
            particlePhysics={{ velocity: { initialRange: stage >= 4 ? [[-0.08, 0.05, 0.02], [0.08, 0.2, 0.12]] : [[-0.01, 0.01, 0.0], [0.01, 0.04, 0.02]] } }}
          />
        </Gated>
      )}

      {/* glowing crystal outcrops answer every match */}
      {(meshy ? DAIS_CLUSTERS.map(([x, z]) => [x, SURFACE_Y + 0.006, z] as [number, number, number]) : island.anchors.clusters).map((pos, i) => (
        <Reactive key={`${key}_c${i}`} position={pos} rotation={[0, i * 70, 0]} base={[clusterBase, clusterBase, clusterBase]} trigger={portalPulse + plantPulse} peak={[1.15, 1.35, 1.15]}>
          <GemMesh name="glow_cluster" />
        </Reactive>
      ))}
      {biome.blooms && !meshy &&
        island.anchors.blooms.map((pos, i) => (
          <Reactive key={`${key}_b${i}`} position={pos} rotation={[0, i * 47, 0]} base={[bloomBase, bloomBase, bloomBase]} trigger={plantPulse} peak={[1.3, 1.45, 1.3]}>
            <GemMesh name="bloom" />
          </Reactive>
        ))}

      {/* Ember Deep: flamethrower turrets (CC-BY 3.0, Zsky) guard the burning ruins */}
      {biome.id === "ember" &&
        (meshy ? DAIS_TURRETS : TURRETS).map(([x, z, yaw], i) => (
          <ViroNode key={`${key}_t${i}`} position={[x, (meshy ? SURFACE_Y : island.heightAt(x, z)) - 0.002, z]} rotation={[0, yaw, 0]} scale={[0.014, 0.014, 0.014]} ignoreEventHandling>
            <Model source={MODELS.flameTurret} ignoreEventHandling />
          </ViroNode>
        ))}

      {/* realm air: fireflies, bubbles, snow, embers, spores… kept behind the board (emitters hit-test) */}
      <Gated>
        <ViroParticleEmitter
          position={[0, PORTAL_CENTER[1] + 0.02, -0.25]}
          run
          loop
          image={{ source: TEXTURES.spark, width: 0.006, height: 0.006, bloomThreshold: 1 }}
          spawnBehavior={{ particleLifetime: [2500, 4000], emissionRatePerSecond: [(3 + stage * 2) * p.rate, (5 + stage * 3) * p.rate], maxParticles: 50, spawnVolume: { shape: "box", params: [0.6, 0.12, 0.12] } }}
          particleAppearance={{ opacity: { initialRange: [0, 0], factor: "Time", interpolation: [{ endValue: 1, interval: [0, 800] }, { endValue: 0, interval: [2000, 4000] }] }, color: { initialRange: p.colors } }}
          particlePhysics={{ velocity: { initialRange: [[-0.01, p.rise - 0.006, -0.01], [0.01, p.rise + 0.008, 0.01]] } }}
        />
      </Gated>

      {/* realm weather over the whole island: leaves, dust, spray, snow, ash… (one emitter, re-tuned per realm) */}
      <Gated>
        <ViroParticleEmitter
          position={[0, 0.42, -0.02]}
          run
          loop
          image={{ source: TEXTURES.spark, width: weather.size, height: weather.size, bloomThreshold: 1 }}
          spawnBehavior={{ particleLifetime: weather.life, emissionRatePerSecond: [weather.rate * 0.8, weather.rate], maxParticles: 160, spawnVolume: { shape: "box", params: [0.8, 0.05, 0.7] } }}
          particleAppearance={{ opacity: { initialRange: [0, 0], factor: "Time", interpolation: [{ endValue: 0.9, interval: [0, 600] }, { endValue: 0, interval: [weather.life[0] - 800, weather.life[0]] }] }, color: { initialRange: weather.colors } }}
          particlePhysics={{ velocity: { initialRange: weather.velocity } }}
        />
      </Gated>

      <Mist />
      <Life realm={biome.id} />

      <Shockwave trigger={shock} strength={r.CASCADE_4_PLUS + r.LEVEL_COMPLETE > 0 ? 2 : 1} />
    </ViroNode>
  );
}

const HORIZON: { pos: [number, number, number]; scale: number; yaw: number }[] = [
  // within the portrait tabletop camera's view (≈ ±0.45 × distance sideways), above the cloud sea
  { pos: [-0.62, 0.0, -1.45], scale: 0.5, yaw: 30 },
  { pos: [0.68, 0.1, -1.9], scale: 0.42, yaw: -40 },
  { pos: [0.08, 0.2, -2.35], scale: 0.3, yaw: 75 },
];
const REALM_ORDER = Object.keys(BIOMES);

/**
 * Other islands of the universe, drifting on the horizon: the rest of this realm, the realm that
 * comes next, and one further away. Low detail – silhouettes with real surfaces.
 */
export function DistantIslands() {
  const realmsReady = useStore(materialsStore, (m) => m.realms);
  const islandsReady = useStore(materialsStore, (m) => m.islands);
  const classic = useStore(settingsStore, (s) => s.classicGems);
  const level = useStore(gameStore, (s) => s.session?.level ?? LEVELS[s.levelIndex]);
  const here = Math.max(0, REALM_ORDER.indexOf(level.realm ?? "verdant"));
  const seed = level.islandSeed ?? level.seed;
  const islands = useMemo(
    () =>
      HORIZON.map((h, i) => {
        const biome = BIOMES[REALM_ORDER[Math.min(REALM_ORDER.length - 1, here + i)]];
        return { ...h, biome, mesh: buildIsland(biome, seed * 7 + i * 101, true) };
      }),
    [here, seed],
  );
  return (
    <ViroNode ignoreEventHandling>
      {islands.map((isl, i) => (
        <ViroNode key={`${seed}_${i}`} position={isl.pos} scale={[isl.scale, isl.scale, isl.scale]} rotation={[0, isl.yaw, 0]} ignoreEventHandling>
          {!classic && islandsReady.includes(isl.biome.id) ? (
            // Meshy islands are wider than the procedural ones, so they are drawn smaller on the horizon
            <ViroNode scale={[0.66, 0.66, 0.66]} ignoreEventHandling>
              <MeshyIslandMesh realm={isl.biome.id} lod="far" />
            </ViroNode>
          ) : (
            realmsReady.includes(isl.biome.id) && isl.mesh.parts.map((part) => (
              <IslandPart key={part.slot} part={part} material={matName(isl.biome, part.slot)} />
            ))
          )}
        </ViroNode>
      ))}
    </ViroNode>
  );
}

/** Light colours for the current level's realm (used by GameWorld). */
export function useBiomeLight() {
  const level = useStore(gameStore, (s) => s.session?.level ?? LEVELS[s.levelIndex]);
  return biomeFor(level.realm).light;
}
