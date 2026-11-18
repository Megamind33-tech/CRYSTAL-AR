# Plan: Faction War, many battlegrounds, varied rules

A game that doesn't repeat: wars between 2 or 4 sides (the nations), fought
at many sites round the valley, each match won a different way. You lead
your squad and fight in it. Everything else the game has (the city, the
underground matches, politics, looting other players, heists, gangs)
stays, and grows alongside.

## Built (first slice)

- **Battlegrounds** (`maps/world/battlegrounds.gd`): six sites. The Rustwood
  Dig, the crater, the far mesa, the south-east outback, Sinlap's shore and
  the north dunes. Each site's cargo spots, pads, vault, control point,
  four camps, spawns and pickups are laid on rings from its centre and
  checked: level ground, outside every lawful district, inside the bots'
  navigation. Runs come round every site in turn
  (`Battlegrounds.for_run`).
- **War objectives** (`sim/hunt_war.gd`): each run rolls what wins it, out
  of 10 runs:
  - **Extract** (4 in 10): as before.
  - **Hold the point** (2 in 10): a side alone on it builds its time;
    5 minutes held in all wins.
  - **Supply drops** (2 in 10): minerals land every 90 s; 6 extracted
    wins.
  - **Camp war** (2 in 10): sabotage enemy camp cores by holding interact
    for 5 s with no defender near; 3 charges each; the last camp standing
    wins.

  A side is a nation; your squad fights for you. A win ends the match
  early, and the winners score +300. Announced at the start, with a HUD
  line, a feed and markers.
- **Pit conditions** (`HuntRules.PitRule`): standard, ore seam, cave-in
  (one pad), failing vault lock.
- **Squads** (`sim/hunt_squad.gd`): up to 3 AI teammates with roles,
  orders, rules of engagement and one-tap plans.

## Next

1. **Camps you build.** Sockets round each camp core; spend the side's
   credits on walls and gates, turrets, a med bay, barracks (bigger squad,
   respawns), a comms mast (enemy squads on the map), a refinery and a
   rotorcraft pad. Camp cores and modules get real collision and models.
   The AI leader builds too.
2. **More rules per match.** King of the vault (the relic scores while you
   hold it), escort the convoy across the site, a territory war (several
   points, the most held over time), last squad standing, and a timed
   resource race.
3. **Command upgrades.** Several squads per side, orders on the minimap,
   mark a target by aiming, new plans (raid camp, hold point, gather), and
   leader abilities (a rotorcraft drop, a supply crate, a scan).
4. **Match modifiers ("mods").** One or two drawn per match (a lobby vote
   online): methane storm (low visibility, pads shift), low gravity surge,
   gold rush, blackout (no minimap), hardcore (no shields, losses stay),
   mercenary market, fog of war. Later, modifiers as data files players
   write themselves.
5. **Four-way wars** with all four nations, alliances and betrayals between
   sides (HuntSocial).
6. **Online:** human leaders and squad members.
7. **Campaign:** the battlegrounds become territory. Nations hold sites
   between matches, and holding a site pays every run.
8. **More battlegrounds:** Deep Furrow's halls underground, the Anvil's top,
   the old freighter wreck, the Skyport's outer apron at night, and new
   ground past the basin's rim.

## Keep and grow (the other ways to play)

- **Underground matches:** brought into the war as battlegrounds
  (Deep Furrow), with their own rules (close quarters, no rotorcraft).
- **Politics:** the war's results feed nation standing and the city's
  news. Nations offer war contracts, and the Marshals' law shapes what you
  can do in town.
- **Looting other players:** carriers can still be robbed in a war;
  sabotage and theft pay; bounties follow the worst offenders between
  matches.
- **The city:** heists, gangs, estates, jobs and the market carry on.
  Credits and gear won in wars come home.

## Constraints

- New buildings for camps need models. Big binary assets can't be pushed
  from the cloud sessions (LFS uploads are refused), so they're pushed
  from a local machine, or built from existing kit pieces first.
- Phones: up to four AI squads, plus turrets, plus camps need a frame
  budget. Measure with `city_walk --budget` before going wider.
