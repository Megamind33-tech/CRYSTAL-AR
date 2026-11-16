class_name SimVehicle
extends RefCounted
## A rover in the world (VehicleSim): where it stands, which way it faces,
## and who drives it (0: nobody). Parked rovers stay where they were left.

var position := Vector3.ZERO
var yaw: float = 0.0
var driver: int = 0
## Whose it is (0: nobody's; < 0: a faction's) and what's in its hold
## ({item: count}; the local player's own rover shares the career's dict).
var owner: int = 0
var model: int = 0  ## VehicleSim.MODELS index
var cargo: Dictionary = {}
## Fuel and condition, 0..100 (VehicleSim.wear: free roam only).
var fuel: float = 100.0
var condition: float = 100.0
var last_speed: float = 0.0
