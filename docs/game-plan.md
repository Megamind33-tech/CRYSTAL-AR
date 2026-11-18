# THE HUNT: the game plan (Nov 2026)

Written after a playtest on the phone. It says what the game is about, how a
session plays from the first minute, and what we build in which order. The
technical plan stays in PLAN.md; this is the design.

## 1. What the playtest showed

| What we saw | Why it happens (from the code) |
|---|---|
| Moving feels very slow | Dig runs walk at 5 m/s, sprint 8.4 m/s (`data/hunt_movement.tres`), with Mars gravity and no slide or double jump. On the phone a low frame rate makes it feel worse (the budget work in `docs/perf` is part of the fix) |
| No other way up a cliff | Mantling reaches 1.8 m. The jetpack exists but only if you carry one. No climbable faces, ladders, lifts or ziplines |
| You carry one thing at a time, with no choice | `HuntRules`: one treasure in your hands, floating above you |
| It's just move, extract, get shot, go back | The dig run is the only loop the game teaches. The rest (jobs, heists, trade, homes, gangs, bounties, events, MarsNet) is there but never shown |
| New players don't know what to do in the city | The only guidance is one hint line: "Contracts: Tharsis Gate board, the dig is east" |
| You can't tell who is with you | Everyone wears the same suits. Alliances exist (`HuntSocial`: propose, accept, betray) but only in a dig run, through a menu, one ally at a time, with a small marker |

The good news: most of the systems the story needs already exist. The work
is mostly giving them a purpose, a face and an order.

### Carrying one thing at a time: strength or weakness?

A strength, as long as the player gets to choose. A carrier you can see makes
the best moments: everyone knows who has the prize, you can chase and steal
it, and a carrier can't also fight at full strength. It's a weakness now
because it's the only option, so every run feels the same. Keep it for the
big prizes and add choices beside it (section 4).

## 2. The story

Earth's nations have sent expeditions to Mars. The planet holds rare
minerals that power the next century, and every nation wants control of the
deposits. You arrive on the shuttle as a recruit of your nation's
expedition.

- **Your nation is your side.** You wear its colours, its base is your home,
  and its standing on Mars rises with what you deliver.
- **Control is the war.** The Kasei Valley is split into zones. Nations fight
  for them by mining, delivering and holding ground, not only by shooting.
- **Minerals, not money, come out of the ground.** You find a deposit, mine
  it, haul it out and take it to a **Resource Exchange**. Only there does it
  become money, standing and territory.
- **Everyone is armed and anyone can shoot anyone.** Shooting has
  consequences: your own nation punishes friendly fire, and the Marshals
  punish killings inside the lawful districts.
- **The corporations are still there.** Tharsis Mining, Kasei Freight and the
  Crimson Ledger become companies every nation trades with. They post the
  contracts and run the black market.

**Real or invented nations?** We recommend invented blocs with their own
names, flags and colours (for example four blocs). Real countries in a
shooter bring rating, store and political trouble, and make it awkward when
a player's own country loses a war.

## 3. Who is who

The rule: **you never have to guess.** Before you shoot you should know in
half a second whether that person is a friend.

| Who | How you see it |
|---|---|
| Your squad (your party) | Green outline through walls within 60 m, name in green, on the minimap |
| Your nation | Suit panels and helmet stripe in the nation colour, flag patch on the shoulder, name in that colour |
| Other nations | Their own colour (each nation has one strong colour) and flag, plus a small nation icon over the head within 40 m |
| A nation you're allied with (a pact) | Their colour with a handshake icon. The pact shows in the HUD with its time left |
| Wanted (a bounty on them) | A red skull over the head, on the minimap as a last-known area |
| Marshals and townsfolk | Uniforms and civilian suits, no flag. Shooting them is a crime |

The ways to group up:

1. **Nation.** Automatic, chosen once at the start. It can be changed later
   for a cost (a visa and lost standing). This is the big team.
2. **Squad.** Up to 4 players or AI crew you invite, from any nation. You
   share map pings, can revive each other and can't hurt each other. This
   grows from today's mercenary contract and the alliance proposal.
3. **Pacts.** Temporary truces between nations for one operation (the
   existing propose, accept and betray rules, shown properly). Betrayal stays
   possible and stays costly.

Friendly fire stays on (you can shoot anyone), but hitting your own nation or
squad costs standing, and repeat offenders get a bounty from their own side.

## 4. The core loop: find, mine, haul, deliver

One run should take 10 to 15 minutes and have choices at every step.

1. **Prepare at your nation's base**: take an operation (a contract), pick
   gear, choose how you'll haul (on foot, pack, rover).
2. **Find**: the scanner shows deposit signals. Rarer minerals give weaker,
   fuzzier signals and lie in harder places (cliff ledges, caves, contested
   zones).
3. **Mine**: mining takes time and makes noise and a dust plume that others
   can see. Drills mine faster and are louder.
4. **Haul**, with a real choice:
   - **Hands**: one big prize (a crystal core, a vault relic) floating over
     you. It's worth the most and everyone sees it. This is today's carry
     rule, kept for the prizes.
   - **Pack**: small samples by weight (for example 6 slots). The heavier the
     pack, the slower you move and the less you can jump. You can drop part
     of it to run.
   - **Rover or hauler**: bulk loads, fast on roads, loud and easy to ambush.
     The cargo bed already exists.
5. **Deliver** to a Resource Exchange: one in each nation's base and a few
   neutral ones in the outlands (closer, riskier, worse prices). Delivery
   takes a few seconds on the pad, like extraction today.
6. **Get paid**: money, nation standing, and **zone control** for your
   nation. Prices change with what each nation is short of.

The minerals (data, like `HuntResources` today):

| Mineral | Where | Why it matters |
|---|---|---|
| Water ice | Common, shallow | Oxygen and water (survival) |
| Iron-nickel ore | Common | Building and repairs |
| Rare earth ore | Cliffs and canyons | Good money |
| Helium-3 | Dust flats, needs a drill | Nation energy, big standing |
| Sky crystal | Very rare, one at a time, in hands | The prize: huge value, everyone hunts the carrier |

## 5. Moving around

- **Faster base movement**: walk 6 to 6.5 m/s, sprint 9 to 10 m/s on foot,
  slower only when carrying weight. Test it on the phone at a steady frame
  rate before tuning further.
- **Routes up cliffs**, each a choice with a cost:
  - climbable faces (visible handholds) for a slow, quiet climb;
  - ladders and lift heads at outposts (lift heads already exist in the kit);
  - ziplines between high points;
  - the jetpack as standard kit with limited fuel, upgradable;
  - a grappling hook as gear you buy.
- **Vehicles stay the fast way between areas** (rovers, aircraft), and the
  monorail between districts.
- Every important deposit has at least two ways in and two ways out, so an
  ambush on one road doesn't decide the run.

## 6. Reasons to come back

Repetition comes from doing the same run for the same reward. Each layer
below changes what a run means:

1. **The war map.** Zone control moves with every delivery from every
   player and AI expedition. A zone your nation holds gives cheaper gear,
   a safe Exchange and a spawn point. Losing it hurts. Checked daily.
2. **Operations that change.** Every day new operations: escort a convoy,
   hold a drill site for 5 minutes, raid another nation's depot, recover a
   crashed probe. The existing world events (supply pods, meteor falls,
   stranded convoys) and heists become operations.
3. **Deposits move.** Rich deposits deplete and new ones open somewhere
   else (seeded per day), so the map is never solved.
4. **Rank and base.** Your rank in your nation unlocks gear, vehicles and
   base rooms. The nation's base grows when its players deliver.
5. **Weekly season.** Each week a mineral is in high demand and one zone is
   the front line.
6. **People.** Squads, rivals with names (the Most Wanted list), and the
   city life already built (homes, MarsNet, Rhea), opened up as you rank up.

## 7. The first 15 minutes

The goal: in 15 minutes a new player has done the whole loop once, knows
who their side is, and knows what to do next.

1. **Arrival** (1 min): the shuttle lands. Pick your nation (flag, colour,
   one line on each). Pick your look.
2. **Briefing** (30 s): your nation's commander, one character with a voice
   and a face, says in three short lines what we're here for and what to do
   first.
3. **First run, guided** (8 min): scan, find a water ice deposit, mine it,
   carry it, meet one hostile (an AI from another nation, shown in its
   colour), deliver it to the Exchange, get paid. One instruction on screen
   at a time.
4. **Back at base** (3 min): spend the money on the first upgrade, take the
   first real operation, see the war map and your nation's zones.
5. **From then on**: an **objective tracker** is always on screen (top
   right): the current goal, the distance, the next step. Tap it for a
   waypoint.

City systems open one by one as you rank up, each with a one-screen
introduction: jobs and the market first, then bounties, then homes, then
heists, gangs and the black market. Nothing new opens more than once a
session.

## 8. What we build, in order

| Phase | What | Why first |
|---|---|---|
| 1. Clarity | Objective tracker, the guided first run, nation colours on suits and names, squad and ally outlines | Players can't enjoy what they can't understand or see. Mostly reuses what's built |
| 2. The loop | Minerals and deposits with scanning and mining, pack carry with weight, Resource Exchanges, delivery and payment | The heart of the story |
| 3. Movement | Faster tuning, climbable faces, ladders, ziplines, jetpack as standard | Fixes "slow" and "one way up" |
| 4. Sides | Nations and their bases, squads (up to 4), pacts, friendly-fire rules | Turns "everyone looks the same" into teams |
| 5. Reasons to return | War map and zone control, daily operations, moving deposits, ranks | The fight against repetition |
| 6. Opening the city | Gradual unlocks with introductions for the existing city systems | Brings back what's already built, in order |

Each phase ships on its own and is played on the phone before the next one.

## 9. Decisions (agreed 17 Nov 2026)

1. **Nations**: four invented nations (section 2), no real countries.
2. **AI first**: the other expeditions are AI. Every phase has to be proven
   playable with AI alone (automated runs: it completes, nobody gets stuck,
   the pacing numbers hold) and then judged for fun on the phone, before
   online play is considered.
3. **Turning on people**: anyone can shoot anyone. You can turn on your
   squad and any member can turn on you. It must never become a pattern:
   AI members turn only for a reason that fits who they are (their
   personality and what you did to them before), betrayals are paced across
   runs, and they take different forms.
4. **Death**: you're robbed. You lose what you carry, your pack, your weapons
   and your gear upgrades, and keep your clothes and helmet. Your nation
   re-issues the basic sidearm. What's in your home locker, your wallet and
   your rover stay yours.
5. **The city's systems** stay and open gradually as you rank up.

## 10. The full game (17 Nov 2026): Saturn expanded

**The fantasy.** You register, choose one of four nations by its flag, and
land in that nation's colony on Titan. There you choose a life: serve your
government (salaried posts, missions, protection, rank) or go freelance
(contracts for anyone, bigger risks, your own rules). Everyone lives off
Titan: expeditions and extractions in the wild, fights over what's found,
trade, land, and power.

**Pillars, each a system the player can live in:**

| Pillar | What you do |
|---|---|
| Expeditions and extraction | Scan, mine, haul, survive the haze; alone or with a squad (some missions need a squad) |
| Combat | Real gunfights and hand-to-hand; the underground fight club (bet your earnings on bouts, or fight in them) |
| Government or freelance | Posts, salary and missions for your nation; or contracts on the open board |
| Land and building | Buy plots, build homes, shops and depots, rent them to bots or players |
| Politics | Standing in your nation, councils and elections for colony offices (later) |
| Economy | Credits for everyday trade; rubies (rare, found or earned) for land, licences, upgrades and the club's big bets |
| People | Bots with memory and character you can talk to properly, ally with, be protected by, and betray or be betrayed by |

**The first five minutes.** Register, choose a nation by its flag, land in its
colony, meet your nation's officer (a bot you talk to), who explains the two
paths and gives the first task; the tracker shows every step.

**Roadmap (in order; each ships playable and tested):**

1. Foundations: movement controls (walk, jog, run, crouch buttons), footsteps,
   bots that move like people, nothing passes through buildings or secured
   areas, proper gates and security, pickups into your pack, the HUD without
   overlaps, readable boards, comic weather and looks
2. Arrival: registration, nation by flag, a colony per nation, the officer,
   the government or freelance choice
3. People: conversations with memory, alliances and companions who protect
   you, missions that need a squad
4. Combat: hand-to-hand moves, the underground fight club with betting
5. Economy and land: rubies, buying land, building, renting
6. Politics: offices and elections

**How it's built:** in parallel by focused agents, each owning its own files
(docs/handoff/agents.md), reporting to the director, who integrates the shared
files (CityMode, Match, the strings table) and runs the full checks.
