// World content: realms, islands, portals, story, Heart Shards and Memory Crystals.
// The ten campaign realms and their 200 islands are derived from src/game/campaign.ts; the
// hand-written islands (the first story beats, discovery / seasonal / expedition portals) keep
// their original ids so existing saves stay valid.
import { CAMPAIGN_REALMS, LEVELS_PER_REALM } from "../../game/campaign.ts";
import { CAMPAIGN, LEVELS } from "../../game/level.ts";
import type { HeartShard, Island, MemoryCrystal, Realm, Reward, StoryChapter } from "../types.ts";

const REALM_BLURBS: Record<string, string> = {
  verdant: "Moss-wrapped ruins where the first Heart Shard fell. Its Lumins have gone quiet.",
  canyon: "Cliffs split by the Shattering. Turn the world itself and the crystals follow.",
  tide: "Sea caves where the tide froze mid-breath. Its crystals sleep under ice.",
  sky: "Temples adrift above the clouds, sealed behind cracked stone.",
  hollow: "A glowing hollow of giant fungi. The vines here are hungry.",
  caverns: "Crystal-veined caves. The old Keepers buried their runes beneath the floor.",
  frozen: "A signal from ice that remembers the Heart whole. Its crystals are bound in chains.",
  solar: "A sun-bleached plateau of dials and obelisks. Its relics must return to the earth.",
  ember: "A volcanic realm whose gate still glows. Its crystals run hot and unstable.",
  void: "Where the Heart broke. Every lesson the realms taught, all at once.",
};

const CAMPAIGN_REALM_LIST: Realm[] = CAMPAIGN_REALMS.map((r, i) => ({
  id: r.id,
  name: r.name,
  blurb: REALM_BLURBS[r.id],
  order: i + 1,
  minKeeperLevel: 1 + i,
  requiresShards: i,
  islands: [],
}));

export const REALMS: Realm[] = [
  ...CAMPAIGN_REALM_LIST,
  {
    id: "eclipse",
    name: "The Eclipse Realm",
    blurb: "A realm that should not exist, drifting across the others. Its light is borrowed.",
    order: 11,
    minKeeperLevel: 4,
    requiresShards: 1,
    islands: ["eclipse-threshold"],
    seasonal: "s01-eclipse",
  },
  {
    id: "signal",
    name: "The Frozen Signal",
    blurb: "A signal from ice that remembers the Heart whole. It will not stay open long.",
    order: 12,
    minKeeperLevel: 5,
    requiresShards: 1,
    islands: ["frostbound-signal"],
  },
];

/** Hand-written campaign islands (original ids and rewards). */
const AUTHORED_ISLANDS: Record<number, Omit<Island, "levelIndex" | "after">> = {
  1: {
    id: "waking-stones",
    realm: "verdant",
    name: "Waking Stones",
    portal: "story",
    firstRestore: { prismDust: 120, keeperXp: 80, lumins: ["mossling"], memories: ["mem-first-light"], passXp: 60 },
    replay: { prismDust: 25, keeperXp: 15, passXp: 15 },
    storyChapter: "ch1-waking",
  },
  20: {
    id: "heart-of-the-falls",
    realm: "verdant",
    name: "Heart of the Falls",
    portal: "story",
    firstRestore: {
      prismDust: 220, keeperXp: 140, aether: 20, heartShards: ["shard-verdant"], lumins: ["fallsprite"],
      memories: ["mem-shard-in-water"], items: { portalFragment: 2, sanctuaryStone: 6 }, passXp: 90,
    },
    replay: { prismDust: 35, keeperXp: 25, passXp: 25 },
    storyChapter: "ch3-falls",
  },
  21: {
    id: "emerald-canopy",
    realm: "canyon",
    name: "Emerald Canyon",
    portal: "story",
    firstRestore: { prismDust: 160, keeperXp: 100, relics: ["oracle-stone"], memories: ["mem-canopy-sang"], items: { sanctuaryStone: 4 }, passXp: 70 },
    replay: { prismDust: 30, keeperXp: 20, passXp: 20 },
    storyChapter: "ch2-canopy",
  },
};

/** Heart Shard returned by each realm's final island. */
export const shardForRealm = (realm: string) => `shard-${realm}`;

/** Campaign island id for a level number (1..200). */
export function campaignIslandId(n: number): string {
  const authored = AUTHORED_ISLANDS[n];
  if (authored) return authored.id;
  const realm = CAMPAIGN_REALMS[Math.floor((n - 1) / LEVELS_PER_REALM)];
  return `${realm.id}-${String(((n - 1) % LEVELS_PER_REALM) + 1).padStart(2, "0")}`;
}

function campaignIsland(n: number): Island {
  const levelIndex = CAMPAIGN[n - 1];
  const after = n > 1 ? campaignIslandId(n - 1) : undefined;
  const authored = AUTHORED_ISLANDS[n];
  if (authored) return { ...authored, levelIndex, ...(after ? { after } : {}) };
  const realmIndex = Math.floor((n - 1) / LEVELS_PER_REALM);
  const step = (n - 1) % LEVELS_PER_REALM;
  const realm = CAMPAIGN_REALMS[realmIndex];
  const finale = step === LEVELS_PER_REALM - 1;
  const firstRestore: Reward = {
    prismDust: Math.min(700, 90 + n * 3),
    keeperXp: 60 + Math.round(n * 0.9),
    passXp: 50 + Math.round(n / 4),
  };
  if (step % 5 === 4) firstRestore.items = { sanctuaryStone: 2 };
  if (finale) {
    firstRestore.aether = 20;
    firstRestore.heartShards = [shardForRealm(realm.id)];
    firstRestore.items = { portalFragment: 2, sanctuaryStone: 6 };
  }
  return {
    id: campaignIslandId(n),
    realm: realm.id,
    name: LEVELS[levelIndex].name,
    portal: "story",
    levelIndex,
    after,
    firstRestore,
    replay: { prismDust: 20 + Math.round(n / 8), keeperXp: 12 + Math.round(n / 20), passXp: 12 },
    ...(step === 0 && realmIndex >= 2 ? { storyChapter: `ch-${realm.id}` } : {}),
  };
}

export const ISLANDS: Island[] = [
  ...Array.from({ length: CAMPAIGN.length }, (_, i) => campaignIsland(i + 1)),
  {
    id: "hollow-of-lanterns",
    realm: "verdant",
    name: "Hollow of Lanterns",
    portal: "discovery",
    levelIndex: 3,
    after: "heart-of-the-falls",
    unlockCost: { portalFragment: 5 },
    firstRestore: { prismDust: 200, keeperXp: 120, lumins: ["lanternmoth"], relics: ["chrono-crystal"], memories: ["mem-keepers-oath"], passXp: 80 },
    replay: { prismDust: 35, keeperXp: 25, passXp: 25 },
  },
  {
    id: "eclipse-threshold",
    realm: "eclipse",
    name: "Eclipse Threshold",
    portal: "story",
    levelIndex: 4,
    after: "heart-of-the-falls",
    firstRestore: { prismDust: 240, keeperXp: 160, lumins: ["umbrafin"], memories: ["mem-borrowed-light"], items: { starKey: 1 }, passXp: 120 },
    replay: { prismDust: 40, keeperXp: 30, passXp: 30 },
    storyChapter: "ch4-eclipse",
  },
  {
    id: "frostbound-signal",
    realm: "signal",
    name: "Frostbound Signal",
    portal: "expedition",
    levelIndex: 5,
    after: "heart-of-the-falls",
    expedition: { aether: 120, signalHours: 72 },
    firstRestore: { prismDust: 260, keeperXp: 140, lumins: ["rimeback"], memories: ["mem-ice-remembers"], cosmetics: ["portal-effect-frost"], passXp: 100 },
    replay: { prismDust: 40, keeperXp: 25, passXp: 25 },
  },
];

// every realm lists its islands in play order
for (const island of ISLANDS) {
  const realm = REALMS.find((r) => r.id === island.realm)!;
  if (!realm.islands.includes(island.id)) realm.islands.push(island.id);
}

export const STORY: StoryChapter[] = [
  { id: "ch1-waking", title: "Waking Stones", realm: "verdant", beats: [
    "The portal shudders open. A small light tumbles out – a Lumin, frightened and dim.",
    "It hums as you approach. The stones answer. You are not the first Keeper to stand here.",
  ] },
  { id: "ch2-canopy", title: "The Canopy Sang", realm: "verdant", beats: [
    "The trees of the Reach once sang to the Prism Heart each dawn.",
    "Tonight, for the first time in an age, one of them hums back.",
  ] },
  { id: "ch3-falls", title: "A Shard in the Water", realm: "verdant", beats: [
    "Beneath the falls you find it: a sliver of the Prism Heart, still warm.",
    "Far away, something shifts. A second signal flickers at the edge of the world.",
  ] },
  { id: "ch4-eclipse", title: "Borrowed Light", realm: "eclipse", beats: [
    "This realm casts no shadow of its own. Its light is borrowed from the Heart.",
    "Whatever the Heart once held back, it is closer here.",
  ] },
  { id: "ch-tide", title: "The Held Breath", realm: "tide", beats: [
    "The grotto froze the instant the Heart broke. The waves are still standing where they stopped.",
    "Under the ice, the crystals glow like held breath. Melt them gently.",
  ] },
  { id: "ch-sky", title: "Above the Clouds", realm: "sky", beats: [
    "The old Keepers sealed these temples with stone and let them drift away.",
    "Whatever they were keeping out has been gone a long time. Or has learned to wait.",
  ] },
  { id: "ch-hollow", title: "The Hungry Hollow", realm: "hollow", beats: [
    "The fungi light the dark, and the vines follow the light.",
    "Leave them long enough and they will cover everything you mean to save.",
  ] },
  { id: "ch-caverns", title: "What the Keepers Buried", realm: "caverns", beats: [
    "Runes line the cavern floor, carved by hands that knew the Heart would break.",
    "They buried instructions. Dig carefully, and you might learn what they were.",
  ] },
  { id: "ch-frozen", title: "Bound in Ice", realm: "frozen", beats: [
    "Every crystal here has been chained. Not by the cold, but by Keepers.",
    "Someone was very afraid of what these crystals remember.",
  ] },
  { id: "ch-solar", title: "Relics of the Sun", realm: "solar", beats: [
    "The Solar relics were lifted from the earth to power the old dials.",
    "Return them, and the plateau will remember how to tell time again.",
  ] },
  { id: "ch-ember", title: "The Burning Gate", realm: "ember", beats: [
    "The Ember Deep never stopped burning after the Shattering.",
    "Its fire spreads to anything left alone too long. Keep moving.",
  ] },
  { id: "ch-void", title: "Where It Broke", realm: "void", beats: [
    "Every realm has led you here, to the place where the Prism Heart shattered.",
    "Something is waiting in the silence between the shards. It knows your name.",
  ] },
];

/** The Prism Heart has twelve facets; each realm returns one or more Heart Shards (never sold). */
export const HEART_SHARDS: HeartShard[] = [
  { id: "shard-verdant", name: "Verdant Facet", realm: "verdant", facet: 0 },
  { id: "shard-eclipse", name: "Umbral Facet", realm: "eclipse", facet: 1 },
  { id: "shard-frozen", name: "Rime Facet", realm: "frozen", facet: 2 },
  { id: "shard-ember", name: "Cinder Facet", realm: "ember", facet: 3 },
  { id: "shard-canyon", name: "Canyon Facet", realm: "canyon", facet: 4 },
  { id: "shard-tide", name: "Tidal Facet", realm: "tide", facet: 5 },
  { id: "shard-sky", name: "Zenith Facet", realm: "sky", facet: 6 },
  { id: "shard-hollow", name: "Spore Facet", realm: "hollow", facet: 7 },
  { id: "shard-caverns", name: "Geode Facet", realm: "caverns", facet: 8 },
  { id: "shard-solar", name: "Solar Facet", realm: "solar", facet: 9 },
  { id: "shard-void", name: "Null Facet", realm: "void", facet: 10 },
];
export const HEART_FACETS = 12;

export const MEMORIES: MemoryCrystal[] = [
  { id: "mem-first-light", title: "First Light", chapter: "heart",
    text: "When the Prism Heart broke, its light did not vanish. It scattered – into stone, into water, into you." },
  { id: "mem-canopy-sang", title: "The Canopy Sang", chapter: "realms",
    text: "Every realm once turned toward the Heart the way flowers turn toward the sun. Distance was only a matter of song." },
  { id: "mem-shard-in-water", title: "A Shard in the Water", chapter: "heart",
    text: "A Heart Shard remembers the shape of the whole. Hold it near another and it will point the way." },
  { id: "mem-keepers-oath", title: "The Keepers' Oath", chapter: "keepers",
    text: "\"We tend what we did not make. We mend what we did not break.\" – carved above every Sanctuary door." },
  { id: "mem-borrowed-light", title: "Borrowed Light", chapter: "architect", seasonal: "s01-eclipse",
    text: "The Architect built the Heart as a lens. Lenses focus light. They can also hold something in place." },
  { id: "mem-ice-remembers", title: "The Ice Remembers", chapter: "shattering",
    text: "The night of the Shattering, the Keepers did not flee. They were ordered to strike the first blow." },
  { id: "mem-what-waits", title: "What Waits Beneath", chapter: "imprisoned", seasonal: "s01-eclipse",
    text: "Under the eclipse, the Lumins go silent all at once – listening to something none of them will name." },
];
