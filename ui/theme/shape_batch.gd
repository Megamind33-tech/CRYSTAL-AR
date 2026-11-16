class_name ShapeBatch
extends RefCounted
## Untextured 2D shapes (circles, lines, arcs, polygons, rects) gathered
## into one triangle array: one draw call. Godot draws each draw_circle,
## draw_polyline or draw_colored_polygon as a draw call of its own (only
## rects batch), and a HUD with a minimap makes dozens. The shapes keep
## their order among themselves and are drawn under everything the owning
## CanvasItem draws itself (its text and icons), as a child drawn behind it.

var _item: RID
var _owner: CanvasItem
var _points := PackedVector2Array()
var _colors := PackedColorArray()
var _indices := PackedInt32Array()


func _init(owner: CanvasItem) -> void:
	_owner = owner
	_item = RenderingServer.canvas_item_create()
	RenderingServer.canvas_item_set_parent(_item, owner.get_canvas_item())
	RenderingServer.canvas_item_set_draw_behind_parent(_item, true)
	owner.tree_exiting.connect(func() -> void:
		if _item.is_valid():
			RenderingServer.free_rid(_item)
			_item = RID())


## Starts a frame's shapes (call at the top of _draw).
func begin() -> void:
	_points.clear()
	_colors.clear()
	_indices.clear()


## Sends the frame's shapes (call at the end of _draw).
func flush() -> void:
	if not _item.is_valid():
		return
	RenderingServer.canvas_item_clear(_item)
	if not _indices.is_empty():
		RenderingServer.canvas_item_add_triangle_array(_item, _indices, _points, _colors)


func _tri(a: Vector2, b: Vector2, c: Vector2, col: Color) -> void:
	var i := _points.size()
	_points.append_array([a, b, c])
	_colors.append_array([col, col, col])
	_indices.append_array([i, i + 1, i + 2])


func _quad(a: Vector2, b: Vector2, c: Vector2, d: Vector2, col: Color) -> void:
	var i := _points.size()
	_points.append_array([a, b, c, d])
	_colors.append_array([col, col, col, col])
	_indices.append_array([i, i + 1, i + 2, i, i + 2, i + 3])


func circle(c: Vector2, r: float, col: Color) -> void:
	var n := clampi(int(r * 0.6), 12, 48)
	var i0 := _points.size()
	_points.append(c)
	_colors.append(col)
	for k in n:
		var a := TAU * k / n
		_points.append(c + Vector2(cos(a), sin(a)) * r)
		_colors.append(col)
	for k in n:
		_indices.append_array([i0, i0 + 1 + k, i0 + 1 + (k + 1) % n])


func line(a: Vector2, b: Vector2, col: Color, width: float = -1.0) -> void:
	var d := b - a
	if d.length_squared() < 0.0001:
		return
	var n := Vector2(-d.y, d.x).normalized() * maxf(width, 1.0) * 0.5
	_quad(a - n, b - n, b + n, a + n, col)


func polyline(pts: PackedVector2Array, col: Color, width: float = -1.0) -> void:
	for i in pts.size() - 1:
		line(pts[i], pts[i + 1], col, width)
	# Square joints: a dot at each inner corner keeps thick lines closed.
	if width > 2.0:
		for i in range(1, pts.size() - 1):
			circle(pts[i], width * 0.5, col)


func arc(c: Vector2, r: float, from: float, to: float, points: int, col: Color, width: float = -1.0) -> void:
	var w := maxf(width, 1.0) * 0.5
	for k in points:
		var a0 := from + (to - from) * k / points
		var a1 := from + (to - from) * (k + 1) / points
		var u0 := Vector2(cos(a0), sin(a0))
		var u1 := Vector2(cos(a1), sin(a1))
		_quad(c + u0 * (r - w), c + u1 * (r - w), c + u1 * (r + w), c + u0 * (r + w), col)


func colored_polygon(pts: PackedVector2Array, col: Color) -> void:
	var tri := Geometry2D.triangulate_polygon(pts)
	if tri.is_empty():
		return
	var i0 := _points.size()
	_points.append_array(pts)
	for k in pts.size():
		_colors.append(col)
	for t in tri:
		_indices.append(i0 + t)


func rect(r: Rect2, col: Color, filled: bool = true, width: float = -1.0) -> void:
	if filled:
		_quad(r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y), col)
		return
	var p := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y), r.position])
	polyline(p, col, width)
