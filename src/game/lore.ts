// Island arrival passages: every island tells a small piece of the Fracture's story. Lines are
// composed from realm-specific fragments by the island's seed, so no two islands read alike. When an
// island hides a secret, a quiet hint is woven in (where, and what kind of light answers it).
import { createRng, nextInt } from "./rng.ts";
import type { Secret } from "./twists.ts";

const OPENINGS: Record<string, string[]> = {
  verdant: [
    "Roots have grown through the old Keeper stones here.",
    "A stream runs uphill on this island, back toward the portal.",
    "The moss still holds the shape of someone who slept here long ago.",
    "Birdsong stops the moment you arrive, then slowly returns.",
    "Half the trees here are made of crystal, and they are dying.",
    "A broken bridge points toward an island that is no longer there.",
  ],
  canyon: [
    "The canyon walls are carved with arrows, all pointing down.",
    "Stones here fall sideways when no one is watching.",
    "Wind moans through a gap shaped like an open door.",
    "An old rope bridge sways over nothing at all.",
    "Emerald dust glitters in every crack of the cliff.",
    "Someone stacked cairns on the ledges, each one taller than the last.",
  ],
  tide: [
    "The waves froze here mid-crash, a glass wall of water.",
    "Shells hum when the wind passes over them.",
    "A tide pool reflects a sky that is not this one.",
    "Coral has grown around a Keeper's lantern, still faintly lit.",
    "The sand is warm, though no sun reaches this grotto.",
    "Something beneath the ice is breathing, very slowly.",
  ],
  sky: [
    "Columns stand in a circle, holding up a roof that fell away.",
    "The clouds below part, just for a moment, and close again.",
    "A bell tolls here once each hour, though there is no bell.",
    "Temple steps lead up to open air.",
    "Feathers of an enormous bird lie across the courtyard.",
    "The stones remember footsteps; you can hear them if you are still.",
  ],
  hollow: [
    "The mushrooms dim as you pass, then brighten behind you.",
    "Spores drift upward here, as if the island is exhaling.",
    "The vines have braided themselves into the shape of a door.",
    "A ring of caps marks where something once danced.",
    "The air tastes of rain and old honey.",
    "Every glowing cap turns slowly to face the portal.",
  ],
  caverns: [
    "Your footsteps echo a heartbeat later than they should.",
    "Runes are carved into the floor, then carved over again, and again.",
    "A geode the size of a house has been split cleanly in two.",
    "The crystals here sing a single held note.",
    "Old Keeper tools lie where they were dropped, mid-work.",
    "One tunnel leads down. The draught from it is warm.",
  ],
  frozen: [
    "Chains hang from the ice, their ends snapped.",
    "The frost here forms letters, then melts before you can read them.",
    "A Keeper's cloak is frozen upright, as if still worn.",
    "The aurora above flickers in the rhythm of a signal.",
    "Snow falls upward near the portal.",
    "Every crystal here was bound on purpose, and carefully.",
  ],
  solar: [
    "The sundials all point to an hour that no longer exists.",
    "Heat shimmers above an obelisk even at dusk.",
    "Sand has buried a road that once led to the Heart.",
    "Golden dust gathers into the shape of a sun, then scatters.",
    "An empty relic plinth waits at the edge of the mesa.",
    "The shadows here fall toward the light.",
  ],
  ember: [
    "The ground ticks as it cools, then heats again.",
    "Ash drifts down like grey snow, spelling nothing.",
    "A great scorch mark runs straight across the island.",
    "Something enormous has slept on these stones; they are still warm.",
    "Lava threads glow beneath a crust of black glass.",
    "The embers leap toward crystals as if hungry.",
  ],
  void: [
    "Nothing here casts a shadow.",
    "Fragments of other islands drift past, too close.",
    "The portal hums a note you felt before you heard it.",
    "Your own footsteps arrive just before you do.",
    "The stars here are the wrong colours.",
    "Something watches from the gap between the shards.",
  ],
};

const CLOSINGS = [
  "The portal is waiting.",
  "The crystals are restless.",
  "Restore what you can.",
  "Something here does not want to be found.",
  "Listen to the stones.",
  "The Fracture is closer than it looks.",
  "Other Keepers came this way. None returned.",
  "The island is holding its breath.",
];

const COL = ["western edge", "western stones", "centre", "centre", "eastern stones", "eastern edge"];
const ROW = ["far", "far", "middle", "middle", "near", "near"];
const NEED = {
  cascade: "only falling light can wake it",
  special: "it answers to a surge of power",
  five: "only a perfect five can reach it",
} as const;

/** The island's arrival passage (with a hidden hint when a secret is buried). */
export function islandStory(realm: string, seed: number, secret?: Secret): string {
  const r = createRng((seed * 1597334677) ^ 0x2545f491);
  const lines = OPENINGS[realm] ?? OPENINGS.verdant;
  const opening = lines[nextInt(r, lines.length)];
  if (secret) {
    const where = `${ROW[secret.y]} ${COL[secret.x]}`.replace("middle centre", "very heart of the ruins");
    return `${opening} Something is buried near the ${where}; ${NEED[secret.need]}.`;
  }
  return `${opening} ${CLOSINGS[nextInt(r, CLOSINGS.length)]}`;
}
