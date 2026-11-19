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

## Next (status)

1. Camps: rotorcraft pad, upgrades, module health, repair. **Done.**
2. More rules per match: king of the vault, convoy, territory, last standing, resource race. **Done.**
3. Command upgrades: mark target, map orders, more plans, leader abilities. **Done.**
4. Match modifiers deck, including players' own JSON mods. **Done.**
5. Four-way wars and duels, with alliances and betrayals. **Done.**
6. Online, in steps:
   1. **Done:** the network carries THE HUNT. A host can pick it in the
      lobby (the city stays single player); everyone loads the hunt map;
      every HUNT event goes to clients whole (`Protocol.Event.HUNT`, plain
      data, at most 4 KB, never objects); client-side match code no longer
      touches the host-only HUNT state. Checked with a headless host and a
      joined client: 35 events of 14 kinds arrived, no script errors.
   2. **Done:** the host sends the war's state once a second
      (`HuntWar.to_state`: objective, scores, every hunter's side, camps
      and what's built at them). Clients keep a mirror (`apply_state`) that
      drives the war objective line and the war markers, camps, walls and
      buildings. Networked runs are now fought at the valley's battlegrounds:
      the map id carries the site (`city@crater`), so everyone loads the
      same one. Checked live: a client at Rustwood got 175 updates in three
      minutes (a king war, 4 camps, 6 buildings), no script errors.
      Not mirrored yet: army units in the air, flak aiming, fog of war.
   3. **Done:** clients send their orders to the host
      (`Protocol.Msg.HUNT_REQUEST`: an action from
      `HuntRules.REMOTE_ACTIONS` and plain-value arguments; the host runs it
      through `HuntRules.request`, which checks everything as it does for
      bots). Each player also gets their own state once a second
      (`private_state`: credits, army left, hired gun, squad, alliance
      offers, abilities ready), so their phone menu enables the right rows.
      Someone joining mid-war gets a free camp spot, or joins the side with
      the fewest players. Checked live: a client asked to build walls, the
      host built them (`--test-hunt-request`, dev only).
      Limits: a client's own army and squad don't come with them yet (they
      only have what the host's run gives them), and `_mark` (aim at a
      hunter) returns nobody on a client.
   4. **Done:** squads of people. From the phone's squad tab you invite
      the nearest person in the match; they join or turn it down (30 s).
      Squad mates never hurt each other and, in a war, fight on the leader's
      side and camp. A leader's squad orders (and plans) reach the human
      members as an instruction on screen and in the feed, while AI
      teammates obey them as before. Up to 3 people with one leader; leaving
      or disconnecting breaks the tie. Checked live with a host and two
      clients (`--test-squad`, dev only): invite, join, and the leader's
      HOLD orders arrived at the member, no script errors.
   5. **Done:** the rest of the field on clients. The host also sends the
      cargo cases and the army in the air once a second
      (`HuntRules.field_state`); a client's mirror is set up from the
      battleground's own map data (pads, vault) and drives the full HUNT
      visuals (cases, beams, pads, aircraft, flak aiming). A client brings
      its career army and squad (`bring_kit`, once a run; the host keeps a
      few of each unit, within the top rank's command points, no other
      nation's unique units, known roles only). Aiming at a hunter marks
      them on a client too. Checked live: kit accepted, a rendered client
      shows the cargo it carries, no script errors.
   6. **Done:** smoother and sharper online. Cargo and army updates go 4
      times a second (`ServerSession.FIELD_RATE`), and cases on the ground
      glide between updates (`HuntVisuals.smooth_cargo`; over 12 m they
      jump: a case gone home, a new one). A client's squad orders send its
      aim (`target: MARK_BY_AIM`, `aim_dir`) and the host marks the hunter
      on that line from everyone's real positions (`HuntRules.mark_along`),
      so hunters out of the client's view can be marked. Cost: about 8 kB/s
      more per client.

7. Campaign: `Career.d.territory` maps each site to a nation. The winning
   nation of a war takes the site, an AI nation takes another, and every site
   your nation holds pays $80 a run. Shown at the army depot. **Done.**
8. More battlegrounds: the Anvil's flat top, the wreck field (open ground
   between Galleria and Skyport) and Deep Furrow underground: a duel in the
   farm's long hall (cargo among the beds, pads at both ends and the middle,
   a camp in each corner, breathable air). 9 sites in the rotation, each
   checked in a rendered run. **Done.** Note: army aircraft can still be
   called at Deep Furrow; they fly above the ground, not in the hall.

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
