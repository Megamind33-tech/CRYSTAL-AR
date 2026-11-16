extends GutTest
## What the game loads at runtime must be in the exports: the export
## presets' exclude filters (inherited from IONFALL) once left out the UBC
## bodies and the UAL animations, so on phones every character of THE HUNT
## was invisible while it all worked from the editor.

const RUNTIME := [ArmoredRig.SCENE, ArmoredRig.ANIM_SOURCE, CivilianRig.LODS, CivilianRig.SCENE_FEMALE]


func _excludes() -> PackedStringArray:
	var out := PackedStringArray()
	var cfg := ConfigFile.new()
	assert_eq(cfg.load("res://export_presets.cfg"), OK)
	for section in cfg.get_sections():
		if cfg.has_section_key(section, "exclude_filter"):
			for pattern: String in str(cfg.get_value(section, "exclude_filter")).split(","):
				if not pattern.strip_edges().is_empty():
					out.append(pattern.strip_edges())
	return out


func test_characters_ship_in_every_export() -> void:
	var excludes := _excludes()
	assert_gt(excludes.size(), 0)
	for path: String in RUNTIME:
		var rel := path.trim_prefix("res://")
		assert_true(ResourceLoader.exists(path), "%s exists" % path)
		for pattern: String in excludes:
			assert_false(rel.match(pattern), "%s is excluded from an export by '%s'" % [rel, pattern])
