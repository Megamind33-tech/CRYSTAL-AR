class_name SurvivalHud
extends RefCounted
## THE HUNT's survival readout (ComicUI), drawn by the open-world and run
## HUDs: the suit's oxygen (a cyan gauge, minutes left, spare canisters;
## red and pulsing when low, a SUFFOCATING warning when empty), stamina
## while it's down, and fatigue (TIRED / EXHAUSTED: sleep in a bunk).


static func draw(ci: CanvasItem, s: PlayerSimState, at: Vector2, scale: float) -> void:
	if not Survival.enabled or s == null or not s.alive:
		return
	var t := Time.get_ticks_msec() / 1000.0
	var low := s.oxygen < 25.0
	var col := ComicUI.CYAN if not low else Color(ComicUI.RED, 0.6 + 0.4 * sin(t * 8.0))
	var w := 200.0 * scale
	var r := Rect2(at, Vector2(w, 16 * scale))
	ComicUI.draw_panel(ci, r, Color(ComicUI.INK, 0.8), ComicUI.INK, 3.0 * scale, 8 * scale)
	var f := clampf(s.oxygen / 100.0, 0.0, 1.0)
	if f > 0.0:
		var fill := Rect2(r.position + Vector2(3, 3) * scale, Vector2((r.size.x - 6 * scale) * f, r.size.y - 6 * scale))
		ci.draw_colored_polygon(ComicUI.quad(fill, 6 * scale), col)
	var in_dome := Survival.in_air(s.position)
	var secs := int(s.oxygen / 100.0 * Survival.TANK_SECONDS)
	var label := "O₂ %d%%" % roundi(s.oxygen)
	if in_dome:
		label += "  ·  " + TranslationServer.translate("SURV_DOME")
	else:
		label += "  ·  %d:%02d" % [secs / 60, secs % 60]
	if s.o2_spares > 0:
		label += "  ·  +%d" % s.o2_spares
	ComicUI.draw_text(ci, Vector2(r.end.x + 14 * scale, r.end.y), label, UiStyle.font_hud_bold, roundi(20 * scale), col, 0,
			roundi(4 * scale))
	var y := at.y - 26 * scale
	var dry := s.water <= 0.0
	var wcol := Color(0.45, 0.7, 1.0) if s.water >= 20.0 else Color(ComicUI.RED, 0.6 + 0.4 * sin(t * 8.0))
	var wtext := "H₂O %d%%" % roundi(s.water) + ("  ·  +%d" % s.water_spares if s.water_spares > 0 else "")
	if dry:
		wtext += "  ·  " + TranslationServer.translate("SURV_DRY")
	ComicUI.draw_text(ci, Vector2(at.x, y + 6 * scale), wtext, UiStyle.font_hud_bold, roundi(20 * scale), wcol, 0, roundi(4 * scale))
	y -= 26 * scale
	var hungry := s.food < Survival.HUNGRY
	var fcol := Color(0.95, 0.72, 0.4) if not hungry else Color(ComicUI.RED, 0.8 + 0.2 * sin(t * 8.0))
	var ftext := TranslationServer.translate("SURV_FOOD") % roundi(s.food)
	if s.food <= 0.0:
		ftext += "  ·  " + TranslationServer.translate("SURV_STARVING")
	elif hungry:
		ftext += "  ·  " + TranslationServer.translate("SURV_HUNGRY")
	ComicUI.draw_text(ci, Vector2(at.x, y + 6 * scale), ftext, UiStyle.font_hud_bold, roundi(20 * scale), fcol, 0, roundi(4 * scale))
	y -= 26 * scale
	if s.oxygen <= 0.0:
		ComicUI.draw_text(ci, Vector2(at.x, y), TranslationServer.translate("SURV_SUFFOCATING"), UiStyle.font_hud_big,
				roundi(26 * scale), Color(ComicUI.RED, 0.6 + 0.4 * sin(t * 10.0)), 0, roundi(5 * scale))
		y -= 30 * scale
	if s.stamina < 99.0:
		var sr := Rect2(Vector2(at.x, y + 8 * scale), Vector2(120 * scale, 8 * scale))
		ci.draw_rect(sr, Color(ComicUI.INK, 0.7))
		ci.draw_rect(Rect2(sr.position, Vector2(sr.size.x * s.stamina / 100.0, sr.size.y)),
				ComicUI.RED if s.winded else ComicUI.YELLOW)
		ComicUI.draw_text(ci, Vector2(sr.end.x + 10 * scale, sr.end.y + 2 * scale), TranslationServer.translate(
				"SURV_WINDED" if s.winded else "SURV_STAMINA"), UiStyle.font_hud_bold, roundi(17 * scale), ComicUI.PAPER, 0,
				roundi(3 * scale))
		y -= 22 * scale
	if s.jetpack and s.jet_fuel < 99.5:
		var jr := Rect2(Vector2(at.x, y + 8 * scale), Vector2(120 * scale, 8 * scale))
		ci.draw_rect(jr, Color(ComicUI.INK, 0.7))
		ci.draw_rect(Rect2(jr.position, Vector2(jr.size.x * s.jet_fuel / 100.0, jr.size.y)),
				Color(1.0, 0.6, 0.2) if s.jet_fuel > 20.0 else Color(ComicUI.RED, 0.6 + 0.4 * sin(t * 8.0)))
		ComicUI.draw_text(ci, Vector2(jr.end.x + 10 * scale, jr.end.y + 2 * scale), TranslationServer.translate(
				"CITY_JET") % roundi(s.jet_fuel), UiStyle.font_hud_bold, roundi(17 * scale), ComicUI.PAPER, 0,
				roundi(3 * scale))
		y -= 22 * scale
	if s.fatigue >= Survival.TIRED:
		var key := "SURV_EXHAUSTED" if s.fatigue >= Survival.EXHAUSTED else "SURV_TIRED"
		ComicUI.draw_text(ci, Vector2(at.x, y + 4 * scale), TranslationServer.translate(key), UiStyle.font_hud_bold,
				roundi(20 * scale), ComicUI.YELLOW, 0, roundi(4 * scale))
