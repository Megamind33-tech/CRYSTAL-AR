// World content: realms, islands, portals, story, Heart Shards and Memory Crystals.
import type { HeartShard, Island, MemoryCrystal, Realm, StoryChapter } from "../types.ts";

export const REALMS: Realm[] = [
  {
    id: "verdant",
    name: "The Verdant Reach",
    blurb: "Moss-wrapped ruins where the first Heart Shard fell. Its Lumins have gone quiet.",
    order: 1,
    minKeeperLevel: 1,
    requiresShards: 0,
    islands: ["waking-stones", "emerald-canopy", "heart-of-the-falls", "hollow-of-lanterns"],
  },
  {
    id: "eclipse",
    name: "The Eclipse Realm",
    blurb: "A realm that should not exist, drifting across the others. Its light is borrowed.",
    order: 2,
    minKeeperLevel: 4,
    requiresShards: 1,
    islands: ["eclipse-threshold"],
    seasonal: "s01-eclipse",
  },
  {
    id: "frozen",
    name: "The Frozen Verge",
    blurb: "A signal from ice that remembers the Heart whole. It will not stay open long.",
    order: 3,
    minKeeperLevel: 5,
    requiresShards: 1,
    islands: ["frostbound-signal"],
  },
  {
    id: "ember",
    name: "The Ember Deep",
    blurb: "A volcanic realm whose gate still glows. Its crystals run hot and unstable.",
    order: 4,
    minKeeperLevel: 8,
    requiresShards: 3,
    islands: [],
  },
];

export const ISLANDS: Island[] = [
  {
    id: "waking-stones",
    realm: "verdant",
    name: "Waking Stones",
    portal: "story",
    levelIndex: 0,
    firstRestore: { prismDust: 120, keeperXp: 80, lumins: ["mossling"], memories: ["mem-first-light"], passXp: 60 },
    replay: { prismDust: 25, keeperXp: 15, passXp: 15 },
    storyChapter: "ch1-waking",
  },
  {
    id: "emerald-canopy",
    realm: "verdant",
    name: "Emerald Canopy",
    portal: "story",
    levelIndex: 1,
    after: "waking-stones",
    firstRestore: { prismDust: 160, keeperXp: 100, relics: ["oracle-stone"], memories: ["mem-canopy-sang"], items: { sanctuaryStone: 4 }, passXp: 70 },
    replay: { prismDust: 30, keeperXp: 20, passXp: 20 },
    storyChapter: "ch2-canopy",
  },
  {
    id: "heart-of-the-falls",
    realm: "verdant",
    name: "Heart of the Falls",
    portal: "story",
    levelIndex: 2,
    after: "emerald-canopy",
    firstRestore: {
      prismDust: 220, keeperXp: 140, aether: 20, heartShards: ["shard-verdant"], lumins: ["fallsprite"],
      memories: ["mem-shard-in-water"], items: { portalFragment: 2, sanctuaryStone: 6 }, passXp: 90,
    },
    replay: { prismDust: 35, keeperXp: 25, passXp: 25 },
    storyChapter: "ch3-falls",
  },
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
    realm: "frozen",
    name: "Frostbound Signal",
    portal: "expedition",
    levelIndex: 5,
    after: "heart-of-the-falls",
    expedition: { aether: 120, signalHours: 72 },
    firstRestore: { prismDust: 260, keeperXp: 140, lumins: ["rimeback"], memories: ["mem-ice-remembers"], cosmetics: ["portal-effect-frost"], passXp: 100 },
    replay: { prismDust: 40, keeperXp: 25, passXp: 25 },
  },
];

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
];

/** The Prism Heart has twelve facets; each realm returns one or more Heart Shards (never sold). */
export const HEART_SHARDS: HeartShard[] = [
  { id: "shard-verdant", name: "Verdant Facet", realm: "verdant", facet: 0 },
  { id: "shard-eclipse", name: "Umbral Facet", realm: "eclipse", facet: 1 },
  { id: "shard-frozen", name: "Rime Facet", realm: "frozen", facet: 2 },
  { id: "shard-ember", name: "Cinder Facet", realm: "ember", facet: 3 },
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
