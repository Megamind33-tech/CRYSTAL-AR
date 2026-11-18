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

- **Camps** (`sim/hunt_camps.gd`): every side in a war has a camp core.
  Each hunter spends run credits from the phone's CAMP app on six sockets
  round it, plus a wall ring with a gate facing the middle. Everything is
  solid: it stops people, shots and turret sight. The modules:
  - **Turret:** shoots enemies it can see, credited to its builder.
  - **Med bay:** heals your side nearby.
  - **Barracks:** brings fallen squad teammates back.
  - **Comms mast:** reveals enemies near the camp.
  - **Refinery:** earns credits.

  Bots build for their side. The models are existing kit pieces sized to
  each collision box (the turret is built in code).

- **Armies** (`sim/hunt_army.gd`, Career): units unlocked by rank, counted
  and upgraded, deployed within command points. Called in from the ARMY
  app, or driven (the tank, crawler and bastion). Extraction machines are
  needed at the pad for heavy loads. Rival AI hunters bring small armies.
- **Air defence:** air units have health. The flak battery (every nation),
  Meridian's Aegis battery and Halden's Bastion tank shoot them down; a
  jet downed during its run-up never strikes.
- **Nations' arsenals** (`sim/nation_arsenal.gd`): each nation has a
  doctrine of strengths and weaknesses over units and defences, plus its
  own unit:
  - **Aurora:** drones; the drone swarm.
  - **Meridian:** shields; the Aegis battery.
  - **Vesper:** strikes; the Raptor, which strafes twice.
  - **Halden:** armour; the Bastion.

## Next

1. **Camps, next:** a rotorcraft pad (fast travel); upgrades (turret range,
   thicker walls); repairing damage; enemies destroying modules (today
   only the core can be sabotaged); purpose-made models.
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
