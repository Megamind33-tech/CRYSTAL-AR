class_name Balance
extends RefCounted
## The balance configuration files, loaded once. Weapons have their own
## files (data/weapons, Weapons), as does movement (data/movement_config.tres)
## and the bots (data/bots.tres, BotBrain.CONFIG).

## A static var, not a const: HuntCombat changes some values at runtime, and
## const resources have their property reads folded in at compile time.
static var PLAYER: PlayerConfig = preload("res://data/player.tres")
const MODES: ModeConfig = preload("res://data/modes.tres")
