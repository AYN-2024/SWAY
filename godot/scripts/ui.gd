extends CanvasLayer
## The screens: title, rooms, pause, dead, end, and the pause button. Ported from index.html and ui.js.

var g
var current := ""
var map_on := false

var holder: Control
var dim: ColorRect
var screens := {}
var slot: Control
var pause_btn: Button
var play_btn: Button
var endless_btn: Button
var grid: GridContainer
var perk_note: Label
var restart_btn: Button
var dead_title: Label
var dead_tag: Label
var dead_stats: Label
var end_stats: Label
var caps: Font
var body_font: Font

const C_CREAM := Color("efe6d0")
const C_SLATE := Color("2a3d44")
const C_SLATE_UP := Color("3a5059")
const C_CLAY := Color("c8573f")
const C_MUTED := Color("93a3aa")


class StarRow:
	extends Control
	var bits := 0

	func _draw() -> void:
		for b in 3:
			var on := (bits >> b & 1) == 1
			var c := Vector2(size.x / 2.0 + (b - 1) * 13.0, size.y / 2.0)
			var pts := PackedVector2Array()
			for i in 10:
				var a := -PI / 2.0 + i * PI / 5.0
				var q := 2.5 if (i & 1) == 1 else 5.5
				pts.append(c + Vector2(cos(a), sin(a)) * q)
			draw_colored_polygon(pts, Color("f2c84b") if on else Color(1, 1, 1, 0.16))


func _ready() -> void:
	var c := SystemFont.new()
	c.font_names = PackedStringArray(["Bahnschrift Condensed", "Bahnschrift", "DIN Condensed", "Oswald", "Arial Narrow", "Segoe UI", "sans-serif"])
	c.font_weight = 600
	c.font_stretch = 75
	var cv := FontVariation.new()
	cv.base_font = c
	cv.spacing_glyph = 2
	caps = cv
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["Segoe UI", "Nunito", "Helvetica Neue", "sans-serif"])
	f.font_weight = 600
	body_font = f

	holder = Control.new()
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)
	dim = ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.add_child(dim)

	# title
	var t := _screen("title")
	_text(t, "GONG", 92, C_CREAM, caps)
	slot = Control.new()
	slot.custom_minimum_size = Vector2(0, 190)
	slot.size_flags_vertical = Control.SIZE_EXPAND_FILL
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.add_child(slot)
	_text(t, "POP THEM ALL. GONG THE WALL.", 22, C_CREAM, caps)
	play_btn = _button(t, "PLAY", 0, func() -> void:
		var d: int = g.done_count()
		g.begin(0 if d >= g.ROOMS.size() else d))
	endless_btn = _button(t, "ENDLESS", 1, func() -> void: g.begin_endless())
	_button(t, "ROOMS", 2, func() -> void: g.open_rooms())
	_button(t, "THE YARD  ·  BREAK THINGS", 2, func() -> void: g.begin_yard())
	_text(t, "Drag to fly. Let go to coast. When you turn green, double-tap.", 14, C_MUTED, body_font)

	# rooms
	var r := _screen("rooms")
	_text(r, "TEN ROOMS", 46, C_CREAM, caps)
	_text(r, "One star for getting out. One for no lost hearts. One for a long chain.", 14, C_MUTED, body_font)
	grid = GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	r.add_child(grid)
	perk_note = _text(r, "", 14, C_MUTED, body_font)
	_button(r, "BACK", 2, func() -> void: g.go_title())

	# pause
	var p := _screen("pause")
	_text(p, "PAUSED", 46, C_CREAM, caps)
	_button(p, "KEEP GOING", 0, func() -> void: g.resume_game())
	restart_btn = _button(p, "RESTART ROOM", 2, func() -> void: g.replay())
	_button(p, "ROOMS", 2, func() -> void: g.open_rooms())

	# dead
	var d := _screen("dead")
	dead_title = _text(d, "SQUISHED", 50, C_CREAM, caps)
	dead_tag = _text(d, "If you stop, you die.", 20, C_CREAM, body_font)
	dead_stats = _text(d, "", 14, C_MUTED, body_font)
	_button(d, "TRY AGAIN", 0, func() -> void: g.replay())
	_button(d, "ROOMS", 2, func() -> void: g.open_rooms())

	# end
	var e := _screen("end")
	_text(e, "OUT.", 56, C_CREAM, caps)
	_text(e, "You rang all ten.", 20, C_CREAM, body_font)
	end_stats = _text(e, "", 14, C_MUTED, body_font)
	_button(e, "ENDLESS", 1, func() -> void: g.begin_endless())
	_button(e, "PLAY AGAIN", 2, func() -> void: g.begin(0))
	_button(e, "ROOMS", 2, func() -> void: g.open_rooms())

	pause_btn = Button.new()
	pause_btn.text = "II"
	pause_btn.focus_mode = Control.FOCUS_NONE
	pause_btn.add_theme_font_override("font", caps)
	pause_btn.add_theme_font_size_override("font_size", 20)
	pause_btn.add_theme_color_override("font_color", C_CREAM)
	for st in ["normal", "hover", "pressed"]:
		pause_btn.add_theme_stylebox_override(st, _box(Color(0, 0, 0, 0), Color(C_CREAM, 0.35), 10, 2))
	pause_btn.pressed.connect(func() -> void: g.pause_game())
	holder.add_child(pause_btn)


func _process(_delta: float) -> void:
	pause_btn.visible = g.state == "play" and g.R != null and g.R.fin == 0
	pause_btn.position = Vector2(g.fr_x + g.fr_w - 42.0, g.fr_y - 50.0)
	pause_btn.size = Vector2(40.0, 40.0)


func _box(bg: Color, border: Color, radius: int, bw: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	return s


func _screen(id: String) -> VBoxContainer:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_top", 26)
	margin.add_theme_constant_override("margin_bottom", 26)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(margin)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_END if id == "end" else BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 12)
	v.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.custom_minimum_size = Vector2(300, 0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(v)
	screens[id] = margin
	return v


func _text(parent: Control, s: String, size: int, col: Color, f: Font) -> Label:
	var l := Label.new()
	l.text = s
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(300, 0)
	l.add_theme_font_override("font", f)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


## kind 0 = the main button (clay), 1 = gold, 2 = quiet.
func _button(parent: Control, s: String, kind: int, action: Callable) -> Button:
	var b := Button.new()
	b.text = s
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(300, 56 if kind < 2 else 48)
	b.add_theme_font_override("font", caps)
	b.add_theme_font_size_override("font_size", 24 if kind < 2 else 19)
	var bg := C_CLAY if kind == 0 else (Color("e0b33e") if kind == 1 else C_SLATE_UP)
	var fg := C_CREAM if kind != 1 else Color("2a2412")
	for st in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(st, fg)
	b.add_theme_stylebox_override("normal", _box(bg, bg.darkened(0.35), 14, 2))
	b.add_theme_stylebox_override("hover", _box(bg.lightened(0.07), bg.darkened(0.35), 14, 2))
	b.add_theme_stylebox_override("pressed", _box(bg.darkened(0.18), bg.darkened(0.45), 14, 2))
	b.pressed.connect(action)
	parent.add_child(b)
	return b


func slot_rect() -> Rect2:
	return slot.get_global_rect()


func show_screen(id: String) -> void:
	current = id
	for k: String in screens:
		screens[k].visible = k == id
	map_on = id == "title"
	dim.visible = id != ""
	dim.color = Color(0, 0, 0, 0) if id == "title" else (Color(0.11, 0.16, 0.18, 0.35) if id == "end" else Color(0.11, 0.16, 0.18, 0.8))
	dim.mouse_filter = Control.MOUSE_FILTER_STOP if id != "" else Control.MOUSE_FILTER_IGNORE
	if id == "title":
		var d: int = g.done_count()
		var b: int = g.best_walls()
		play_btn.text = "PLAY" if d == 0 else ("PLAY AGAIN" if d >= g.ROOMS.size() else "PLAY ROOM %d" % (d + 1))
		endless_btn.visible = g.endless_open()
		endless_btn.text = "ENDLESS  ·  BEST %d" % b if b > 0 else "ENDLESS"
	elif id == "rooms":
		_fill_rooms()
	elif id == "pause":
		restart_btn.text = "RESTART RUN" if g.mode == "endless" else "RESTART ROOM"
	elif id == "dead":
		var spiked: bool = g.P != null and g.P.by == "spike"
		dead_title.text = "SPIKED" if spiked else "SQUISHED"
		dead_tag.text = "Leave it alone while it is spiky." if spiked else "If you stop, you die."
		dead_stats.visible = g.mode == "endless"
		if g.mode == "endless":
			dead_stats.text = "You rang %d %s. %s" % [g.EW, "wall" if g.EW == 1 else "walls",
				"New best." if g.EW > g.EB0 else "Best %d." % g.best_walls()]
	elif id == "end":
		end_stats.text = "%d of 30 stars." % g.stars()


func _fill_rooms() -> void:
	for c in grid.get_children():
		c.queue_free()
	var open: int = g.ROOMS.size() if g.all_open else mini(g.ROOMS.size(), g.done_count() + 1)
	for i in g.ROOMS.size():
		var b := Button.new()
		b.text = str(i + 1)
		b.focus_mode = Control.FOCUS_NONE
		b.disabled = i >= open
		b.custom_minimum_size = Vector2(60, 64)
		b.add_theme_font_override("font", caps)
		b.add_theme_font_size_override("font_size", 24)
		b.add_theme_color_override("font_color", C_CREAM)
		b.add_theme_color_override("font_hover_color", C_CREAM)
		b.add_theme_color_override("font_disabled_color", Color(C_CREAM, 0.3))
		b.add_theme_stylebox_override("normal", _box(C_SLATE_UP, C_SLATE_UP.lightened(0.15), 12, 2))
		b.add_theme_stylebox_override("hover", _box(C_SLATE_UP.lightened(0.08), C_SLATE_UP.lightened(0.2), 12, 2))
		b.add_theme_stylebox_override("pressed", _box(C_SLATE_UP.darkened(0.2), C_SLATE_UP, 12, 2))
		b.add_theme_stylebox_override("disabled", _box(Color(C_SLATE_UP, 0.35), Color(C_SLATE_UP, 0.5), 12, 2))
		var row := StarRow.new()
		row.bits = g.room_stars(i)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		row.offset_top = -18
		row.offset_bottom = -4
		b.add_child(row)
		var idx: int = i
		b.pressed.connect(func() -> void: g.begin(idx))
		grid.add_child(b)
	var st: int = g.stars()
	var txt := "%d of 30 stars. All three Endless perks are on." % st
	for pk: Array in g.PERKS:
		if st < int(pk[0]):
			txt = "%d of 30 stars. %d more: %s." % [st, int(pk[0]) - st, pk[1]]
			break
	perk_note.text = txt
