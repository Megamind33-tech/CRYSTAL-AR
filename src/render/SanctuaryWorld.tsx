import { Viro3DObject, ViroAmbientLight, ViroDirectionalLight, ViroLightingEnvironment, ViroNode } from "@reactvision/react-viro";
import { HEART_FACETS } from "../meta/config/world";
import { arSession } from "../state/arSession";
import { metaStore } from "../state/meta";
import { useStore } from "../state/store";
import { MODELS, TEXTURES } from "./assets";
import { SURFACE_Y } from "./layout";

/** Which crystal model stands in for each Lumin until bespoke creature models exist. */
const LUMIN_GEM: Record<string, number | "prism"> = { mossling: 2, mossward: 2, fallsprite: 1, lanternmoth: 4, umbrafin: 3, rimeback: 1, heartwarden: "prism" };

const ring = (i: number, n: number, r: number, y: number): [number, number, number] => {
  const a = (i / n) * Math.PI * 2;
  return [Math.cos(a) * r, y, Math.sin(a) * r];
};

/**
 * The Keeper's Sanctuary as a tabletop diorama. It begins nearly bare and fills in from real
 * progress: Heart Shards, housed Lumins, relics, and restored structures.
 */
export function SanctuaryWorld({ ambientIntensity, ambientColor }: { ambientIntensity: number; ambientColor: string }) {
  const p = useStore(metaStore, (m) => m.player);
  const yaw = useStore(arSession, (s) => s.yaw);
  const scale = useStore(arSession, (s) => s.worldScale);
  if (!p) return null;
  const lvl = (id: string) => p.sanctuary.items[id] ?? 0;
  const relics = Object.keys(p.relics);
  const altarY = SURFACE_Y + 0.012;

  return (
    <ViroNode rotation={[0, yaw, 0]} scale={[scale, scale, scale]}>
      <ViroLightingEnvironment source={TEXTURES.environment} />
      <ViroAmbientLight color={ambientColor} intensity={Math.min(900, Math.max(320, ambientIntensity * 0.55))} />
      <ViroDirectionalLight color="#fff1d8" direction={[-0.45, -1, -0.5]} intensity={900} castsShadow shadowOrthographicSize={0.9} shadowOrthographicPosition={[0, 0.8, 0]} shadowMapSize={1024} shadowNearZ={0.05} shadowFarZ={2.5} shadowOpacity={0.5} />
      <ViroNode scale={[0.02, 0.02, 0.02]} animation={{ name: "materialize", run: true }}>
        <Viro3DObject source={MODELS.groundShadow} type="GLB" position={[0.02, 0.001, 0.02]} renderingOrder={-1} ignoreEventHandling />
        <Viro3DObject source={MODELS.terrain} type="GLB" ignoreEventHandling />
        {/* restored areas appear as their structures come back */}
        {lvl("keepers-study") > 0 && <Viro3DObject source={MODELS.propsBack} type="GLB" ignoreEventHandling />}
        {lvl("lumin-grove") > 0 && <Viro3DObject source={MODELS.propsLeft} type="GLB" ignoreEventHandling />}
        {lvl("moonpetal-garden") > 0 && <Viro3DObject source={MODELS.propsRight} type="GLB" ignoreEventHandling />}

        {/* Heart Altar: one floating facet per recovered Heart Shard around the dormant heart */}
        <Viro3DObject source={MODELS.glowCluster} type="GLB" position={[0, altarY - 0.004, 0]} scale={[2.4, 1.6, 2.4]} ignoreEventHandling />
        {/* the dormant heart faces the Keeper and brightens as facets return */}
        <Viro3DObject
          source={MODELS.portalCore}
          type="GLB"
          position={[0, altarY + 0.1, 0]}
          scale={[0.4 + (p.heartShards.length / HEART_FACETS) * 0.8, 0.4 + (p.heartShards.length / HEART_FACETS) * 0.8, 1]}
          ignoreEventHandling
        />
        <ViroNode position={[0, altarY + 0.1, 0]} animation={{ name: "spinSlow", run: true, loop: true }}>
          {p.heartShards.map((id, i) => (
            <Viro3DObject key={id} source={MODELS.prism} type="GLB" position={ring(i, HEART_FACETS, 0.075, 0)} scale={[0.03, 0.03, 0.03]} ignoreEventHandling />
          ))}
        </ViroNode>

        {/* Lumin Grove: housed Lumins drift around the altar */}
        <ViroNode position={[0, altarY + 0.06, 0]} animation={{ name: "spinSlow", run: true, loop: true }}>
          {p.sanctuary.housed.map((id, i) => {
            const gem = LUMIN_GEM[id] ?? 2;
            return (
              <ViroNode key={id} position={ring(i, Math.max(3, p.sanctuary.housed.length), 0.17, 0.02 * (i % 2))}>
                <Viro3DObject source={gem === "prism" ? MODELS.prism : MODELS.gems[gem]} type="GLB" scale={[0.034, 0.034, 0.034]} ignoreEventHandling />
                <Viro3DObject source={MODELS.bloom} type="GLB" position={[0, -0.05, 0]} scale={[0.8, 0.8, 0.8]} ignoreEventHandling />
              </ViroNode>
            );
          })}
        </ViroNode>

        {/* Resonance Well */}
        {lvl("resonance-well") > 0 && (
          <Viro3DObject source={MODELS.portalCore} type="GLB" position={[-0.2, SURFACE_Y + 0.006, 0.12]} rotation={[-90, 0, 0]} scale={[0.5 + lvl("resonance-well") * 0.15, 0.5 + lvl("resonance-well") * 0.15, 1]} ignoreEventHandling />
        )}
        {/* Relic Hall: one glowing outcrop per relic recovered */}
        {lvl("relic-hall") > 0 &&
          relics.map((id, i) => (
            <Viro3DObject key={id} source={MODELS.glowCluster} type="GLB" position={[-0.15 + i * 0.06, SURFACE_Y, -0.2]} ignoreEventHandling />
          ))}
        {/* Moonpetal Garden */}
        {Array.from({ length: lvl("moonpetal-garden") * 3 }, (_, i) => (
          <Viro3DObject key={i} source={MODELS.bloom} type="GLB" position={ring(i, 9, 0.27, SURFACE_Y)} scale={[1.2, 1.2, 1.2]} ignoreEventHandling />
        ))}
      </ViroNode>
    </ViroNode>
  );
}
