extends SceneTree
## Dumps every placed thing in Kasei Valley (WorldLayout, CityLayout) to JSON,
## for tools/plot_world_map.py:
##   godot --headless -s tools/dump_world_layout.gd -- <out.json>

func _v(v) -> Array:
	if v is Vector3:
		return [v.x, v.z]
	if v is Vector2:
		return [v.x, v.y]
	return []


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var path: String = args[0] if args.size() > 0 else "user://world_layout.json"
	var d := {}
	# The ground every 10 m: [half size, step, rows of heights].
	var hs := []
	var half := WorldTerrain.SIZE * 0.5
	var z := -half
	while z <= half:
		var row := []
		var x := -half
		while x <= half:
			row.append(snappedf(WorldTerrain.height(x, z), 0.1))
			x += 10.0
		hs.append(row)
		z += 10.0
	d["terrain"] = [half, 10.0, hs]
	d["roads"] = WorldLayout.roads().map(func(r): return r.map(func(p): return _v(p)))
	d["regions"] = WorldLayout.REGIONS.map(func(r): return [r[0], _v(r[1]), r[2]])
	d["landmarks"] = WorldLayout.LANDMARKS.map(func(r): return [r[0], _v(r[1]), r[2]])
	d["pieces"] = WorldLayout.pieces().map(func(p): return [p[0], p[1], p[2]])
	d["city"] = CityLayout.pieces().map(func(p): return [p[0], p[1].x, p[1].z])
	var misc := {}
	misc["shops"] = WorldLayout.shops().map(func(s): return _v(s[1]))
	misc["trees"] = WorldLayout.trees().map(func(t): return _v(t[1]))
	misc["residences"] = WorldLayout.residences().map(func(r): return _v(r[1]))
	misc["monorail"] = WorldLayout.monorail().map(func(p): return _v(p))
	misc["rigs"] = WorldLayout.RIGS.map(func(r): return _v(r[1]))
	misc["garage"] = [_v(WorldLayout.GARAGE)]
	misc["factory"] = [_v(WorldLayout.FACTORY)]
	misc["lift"] = [_v(WorldLayout.LIFT)]
	misc["convoy"] = [_v(WorldLayout.convoy_spot()[0])]
	d["misc"] = misc
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(d))
	print("wrote ", path)
	quit()
