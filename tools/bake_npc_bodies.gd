extends SceneTree
## Bakes the character body's detail levels (the importer's LOD index lists
## and their edge lengths) to a resource: CivilianRig rebuilds the body mesh
## at runtime (rest heights for the suit shader) and hands these back, so
## characters switch to lighter versions with distance. The dummy renderer
## (headless) keeps LOD data readable:
##   godot --headless -s res://tools/bake_npc_bodies.gd

const SRCS := ["res://art/characters/ubc/Superhero_Male_FullBody.gltf", "res://art/characters/ubc/Superhero_Female_FullBody.gltf"]
const OUT := "res://art/characters/ubc/body_lods.res"
## Only the first levels (half, a quarter, an eighth): the coarser ones are
## near-empty shells some phone GPUs would draw as nothing.
const KEEP_LEVELS := 3


func _initialize() -> void:
	var data := Resource.new()
	for src_path: String in SRCS:
		_bake((load(src_path) as PackedScene).instantiate(), data)
	ResourceSaver.save(data, OUT)
	quit()


func _bake(scene: Node, data: Resource) -> void:
	for mi: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
		if not str(mi.name).begins_with("Super"):
			continue  # the bodies only (the rig rebuilds those)
		var src := mi.mesh as ArrayMesh
		var surfaces := []
		for si in src.get_surface_count():
			var info: Dictionary = RenderingServer.mesh_get_surface(src.get_rid(), si)
			var wide := (src.surface_get_arrays(si)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() > 65535
			var levels := []
			for l: Dictionary in (info.get("lods", []) as Array).slice(0, KEEP_LEVELS):
				var raw: PackedByteArray = l.index_data
				var n := raw.size() / (4 if wide else 2)
				var idx := PackedInt32Array()
				idx.resize(n)
				for i in n:
					idx[i] = raw.decode_u32(i * 4) if wide else raw.decode_u16(i * 2)
				levels.append([float(l.edge_length), idx])
			surfaces.append(levels)
			print("BODY LODS %s s%d: %s" % [mi.name, si, levels.map(func(v: Array) -> int: return (v[1] as PackedInt32Array).size() / 3)])
		data.set_meta(str(mi.name), surfaces)
