extends Node3D
## Gameplay half of Rustwood Yard (THE HUNT): world collision, spawn points,
## pickups and the hunt's treasure spots, vault, trap and extraction zones.
## A dedicated server would load just this scene (PLAN §3.1).


func _ready() -> void:
	var body := StaticBody3D.new()
	body.name = "World"
	body.collision_layer = Sim.LAYER_WORLD
	body.collision_mask = 0
	add_child(body)
	for b in HuntLayout.boxes():
		if not HuntLayout.has_collision(b[0]):
			continue
		var shape := BoxShape3D.new()
		shape.size = b[2]
		var cs := CollisionShape3D.new()
		cs.shape = shape
		cs.position = b[1]
		body.add_child(cs)


func spawn_points() -> Array[Transform3D]:
	return HuntLayout.spawn_points()


func pickup_spots() -> Array:
	return HuntLayout.pickup_spots()


## Free-for-all map: no CTF bases.
func flag_bases() -> Array:
	return []


func hunt_data() -> Dictionary:
	return HuntLayout.hunt_data()
