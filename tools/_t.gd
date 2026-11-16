extends SceneTree
func _initialize():
	for piece in ["shopfront", "districts/spire_a", "life/hab_open", "life/tree"]:
		var st := SurfaceTool.new()
		st.create_from(Comic.kit_mesh(piece), 0)
		st.index()
		for angle in [25.0, 60.0, 180.0]:
			var im := ImporterMesh.new()
			im.add_surface(Mesh.PRIMITIVE_TRIANGLES, st.commit_to_arrays())
			im.generate_lods(angle, 60.0, [])
			var sizes := []
			for l in im.get_surface_lod_count(0):
				sizes.append("%d@%.2f" % [im.get_surface_lod_indices(0, l).size() / 3, im.get_surface_lod_size(0, l)])
			print(piece, " angle ", angle, " base ", st.commit_to_arrays()[Mesh.ARRAY_INDEX].size() / 3, " lods ", sizes)
	quit()
