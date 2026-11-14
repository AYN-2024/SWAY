extends Control
## The flat layer on top of the 3D picture: sparks, rings, floating words, warnings, the comet's face,
## hints, the room cards and the HUD. Ported from render.js, restyled to the clay look.

var g
var font: Font
var caps: Font
var vig: GradientTexture2D

const LEAN := 0.5
const C_CREAM := Color("efe6d0")
const C_DARK := Color(0.1, 0.07, 0.07)


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["Arial Rounded MT Bold", "Nunito", "Segoe UI", "Helvetica Neue", "sans-serif"])
	f.font_weight = 800
	font = f
	var c := SystemFont.new()
	c.font_names = PackedStringArray(["Bahnschrift Condensed", "Bahnschrift", "DIN Condensed", "Oswald", "Arial Narrow", "Segoe UI", "sans-serif"])
	c.font_weight = 600
	c.font_stretch = 75
	var cv := FontVariation.new()
	cv.base_font = c
	cv.spacing_glyph = 2
	caps = cv
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 0.36, 0.38, 0.0))
	grad.set_color(1, Color(1.0, 0.36, 0.38, 0.9))
	grad.set_offset(0, 0.45)
	grad.set_offset(1, 1.0)
	vig = GradientTexture2D.new()
	vig.gradient = grad
	vig.fill = GradientTexture2D.FILL_RADIAL
	vig.fill_from = Vector2(0.5, 0.5)
	vig.fill_to = Vector2(1.0, 1.0)
	vig.width = 128
	vig.height = 128


func _process(_delta: float) -> void:
	queue_redraw()


func label(s: String, x: float, y: float, size: float, col: Color, a: float = 1.0, f: Font = null) -> void:
	var fs := int(round(size))
	if fs < 2 or a <= 0.0:
		return
	if f == null:
		f = font
	var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var pos := Vector2(x - w / 2.0, y + fs * 0.35)
	draw_string_outline(f, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, int(ceil(fs * 0.16)), Color(g.C_LINE, a * 0.85))
	draw_string(f, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(col, a))


func ring(c: Vector2, r: float, col: Color, w: float, a0: float = 0.0, a1: float = TAU) -> void:
	if r <= 0.0:
		return
	draw_arc(c, r, a0, a1, clampi(int(r * 0.6) + 12, 12, 96), col, w, true)


func outline(rc: Rect2, col: Color, w: float) -> void:
	draw_rect(rc, col, false, w)


## The map: ten rooms, each inside the next.
func nest(cx: float, cy: float, size: float, done: int, cur: int, a: float) -> void:
	for k in range(9, -1, -1):
		var s := size * (k + 1.7) / 10.7
		var lit := k < done
		var col: Color = g.C_AMBER if lit else (C_CREAM if k == cur else g.C_MUTED)
		col.a = a * (1.0 if lit else (0.9 if k == cur else 0.35))
		outline(Rect2(cx - s / 2.0, cy - s / 2.0, s, s), col, maxf(1.5, size / 90.0) * (1.5 if (lit or k == cur) else 1.0))


func star(x: float, y: float, r: float, on: bool, a: float = 1.0) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var ang := -PI / 2.0 + i * PI / 5.0
		var q := r * 0.45 if (i & 1) == 1 else r
		pts.append(Vector2(x + cos(ang) * q, y + sin(ang) * q))
	var col: Color = g.C_AMBER if on else Color(0.55, 0.58, 0.68, 0.3)
	col.a *= a
	draw_colored_polygon(pts, col)


func heart(x: float, y: float, s: float, col: Color, filled: bool) -> void:
	var pts := PackedVector2Array()
	for i in 28:
		var t := i * TAU / 28.0
		pts.append(Vector2(x + 16.0 * pow(sin(t), 3.0) * s, y - (13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t)) * s))
	if filled:
		draw_colored_polygon(pts, col)
	else:
		pts.append(pts[0])
		draw_polyline(pts, col, 1.6, true)


func _draw() -> void:
	if g.R == null or g.state == "title":
		draw_rect(Rect2(0, 0, size.x, size.y), Color("1c282e"))
		if g.ui.map_on:              # the title: the ten rooms, and where you are in them
			var b: Rect2 = g.ui.slot_rect()
			var s := minf(b.size.x, b.size.y) * 0.96
			if s > 70.0:
				var d: int = g.done_count()
				var cur := mini(d, 9)
				var c := b.get_center()
				var o := s * (cur + 1.7) / 10.7 * 0.27
				var a: float = g.gt * 0.035
				nest(c.x, c.y, s, d, cur, 1.0)
				draw_circle(c + Vector2(cos(a), sin(a)) * o, maxf(3.5, s / 60.0), C_CREAM)
		return
	var R = g.R
	var P = g.P
	var cam: float = g.cam
	var o := Vector2(g.OX + g.draw_sx, g.OY + g.draw_sy)
	draw_set_transform(o, 0.0, Vector2(cam, cam))

	if R.fin > 0:                    # out: the ten rooms, one inside the other, fall away
		var z := 2.6 / cam
		for q: Vector2 in R.sky:
			draw_rect(Rect2(q.x, q.y, z, z), Color(C_CREAM, 0.7))
		for k in 10:
			var s := pow(0.8, k)
			outline(Rect2(g.W / 2.0 - g.W * s / 2.0, g.H / 2.0 - g.H * s / 2.0, g.W * s, g.H * s), Color(g.C_AMBER, 0.95 - k * 0.07), 3.0 / cam)
	else:
		for n in g.IN:
			_warn(n)
		for e in g.E:
			if e.type == "d" and (e.mode == 2 or (e.mode == 1 and e.mt <= 16)):
				draw_dashed_line(Vector2(e.x, e.y), Vector2(e.x + e.dx * 540.0, e.y + e.dy * 540.0),
					Color(g.TY_COL["d"], 0.25 if e.mode == 2 else 0.7), 3.0, 9.0)
	if not P.dead:
		_comet(P, R)
	_parts()
	if R.fin == 0 and R.ghost and R.intro > 0:
		outline(Rect2(g.BL, g.BT, g.BR - g.BL, g.BB - g.BT), Color(C_CREAM, R.intro / 120.0), 7.0 / cam * 1.6)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for f in g.FL:
		label(f.s, o.x + f.x * cam, o.y + f.y * cam, f.size * cam, f.col, minf(1.0, (f.m - f.t) / 14.0))
	if R.fin == 0:
		for e in g.E:
			_enemy_marks(e, o, cam, P)
	_over(P, R)
	_hud(P, R)


func _warn(n) -> void:               # something is about to come through here
	if n.t > 56:
		return
	var k: float = 1.0 - n.t / 56.0
	var w := Vector2(clampf(n.x, g.BL, g.BR), clampf(n.y, g.BT, g.BB))
	var col: Color = g.TY_COL[n.type]
	var r: float = n.r * (0.3 + 0.7 * k)
	draw_circle(w, r, Color(col, 0.22 + 0.3 * k))
	ring(w, r + 6.0, Color(col, 0.45 + 0.45 * sin(g.gt * 0.5)), 3.0)


func _comet(P, R) -> void:
	var fk: float = R.c1 / g.cam if R.fin > 0 else 1.0
	var q: float = P.squish if P.squish > 0.02 else 0.0
	var b := 1.0
	if q > 0.0:
		b = 1.0 + 0.5 * q + 0.12 * q * sin(g.gt * (0.25 + 0.55 * q))
	var r: float = P.r * fk * b
	var al := 0.45 if (P.inv > 0 and (g.tick & 4) != 0) else 1.0
	var c := Vector2(P.x, P.y - LEAN * (r + 16.0 * q))      # where the ball sits on screen once it is leaned
	if g.inp_down and g.inp_touch and R.fin == 0:
		ring(g.aim_point(), 9.0, Color(C_CREAM, 0.3), 2.0)
	if R.i > 0 and P.dust > 0 and R.fin == 0:              # the only ring: dust, filling toward Super
		var col: Color = g.C_GREEN if P.ready else g.C_AMBER
		ring(c, r + 7.0, Color(col, al), (5.0 + sin(g.gt * 0.3) * 1.5) if P.ready else 4.0, -PI / 2.0, -PI / 2.0 + TAU * P.dust / float(g.SUPER_COST))
	if P.hearts == 1:                                      # the last heart: a coral outline that beats
		var beat := 0.5 + 0.5 * sin(g.gt * 0.1)
		ring(c, r + 1.0, Color(g.C_CORAL, al), 3.0 + 1.5 * beat)
	var v: float = g.hyp(P.vx, P.vy)
	var lx: float = P.vx / v if v > 1.0 else 0.0
	var ly: float = P.vy / v if v > 1.0 else 0.0
	var er := r * 0.3
	var ink := Color(C_DARK, al)
	for s: float in [-1.0, 1.0]:
		var e := c + Vector2(s * r * 0.36 + lx * er * 0.5, -r * 0.14 + ly * er * 0.5)
		draw_circle(e, er * (0.62 if P.squish > 0.3 else 0.45), ink)
	var m := c + Vector2(lx * er * 0.4, ly * er * 0.4)
	if P.top:                                              # glowing: mouth wide open
		var pts := PackedVector2Array()
		for i in 13:
			var ang := i * PI / 12.0
			pts.append(m + Vector2(cos(ang), sin(ang)) * r * 0.3 + Vector2(0, r * 0.26))
		draw_colored_polygon(pts, ink)
	else:
		draw_arc(m + Vector2(0, r * 0.2), r * 0.3, 0.15 * PI, 0.85 * PI, 12, ink, 2.2, true)


func _parts() -> void:
	for p in g.PT:
		var k: float = 1.0 - p.t / p.m
		if p.k == 2:
			ring(Vector2(p.x, p.y), lerpf(p.z, p.z1, g.ease3(p.t / p.m)), Color(p.col, k), p.w * k + 1.0)
		elif p.k == 1:
			draw_set_transform_matrix(Transform2D(0.0, Vector2(g.cam, g.cam), 0.0, Vector2(g.OX + g.draw_sx, g.OY + g.draw_sy)) * Transform2D(p.a, Vector2(p.x, p.y)))
			draw_rect(Rect2(-p.z, -p.z * 0.35, p.z * 2.0, p.z * 0.7), Color(p.col, minf(1.0, k * 2.0)))
			draw_set_transform(Vector2(g.OX + g.draw_sx, g.OY + g.draw_sy), 0.0, Vector2(g.cam, g.cam))
		else:
			var z: float = p.z * (0.4 + 0.6 * k)
			draw_rect(Rect2(p.x - z, p.y - z, z * 2.0, z * 2.0), Color(p.col, k))


## Marks that sit on top of a puck: the sleeper's z, and the crown on whoever squished you.
func _enemy_marks(e, o: Vector2, cam: float, P) -> void:
	var h: float = g.view.puck_h(e.r)
	var c := o + Vector2(e.x, e.y - LEAN * h) * cam
	if e.type == "z":
		var f := clampf(e.r * 0.5, 10.0, 30.0)
		label("z", c.x + f * 1.3 * cam, c.y - (f * 1.5 + sin(g.gt * 0.05) * 3.0) * cam, f * 0.9 * cam, C_CREAM, 0.85)
	if P.dead and g.tick - e.crown < 600:
		var w := clampf(e.r, 14.0, 26.0) * cam
		var y: float = c.y - e.r * cam * 0.2
		var pts := PackedVector2Array([Vector2(c.x - w * 0.6, y), Vector2(c.x - w * 0.6, y - w * 0.55), Vector2(c.x - w * 0.3, y - w * 0.3),
			Vector2(c.x, y - w * 0.7), Vector2(c.x + w * 0.3, y - w * 0.3), Vector2(c.x + w * 0.6, y - w * 0.55), Vector2(c.x + w * 0.6, y)])
		draw_colored_polygon(pts, g.C_AMBER)


## Screen-space layer: the squeeze closing in, hints, the room card, the stars.
func _over(P, R) -> void:
	var cx: float = g.fr_x + g.fr_w / 2.0
	var full := Rect2(0, 0, g.VW, g.VH)
	if P.squish > 0.02 and not P.dead:
		draw_texture_rect(vig, full, false, Color(1, 1, 1, P.squish * 0.6))
	if g.flash > 0.03:
		draw_rect(full, Color(C_CREAM, g.flash * 0.5))
	if R.fin > 0:
		return
	if g.hint_t > 0 and g.hint_s == "Drag":            # a ghost thumb shows the drag
		var k: float = fmod(g.gt, 120.0) / 120.0
		var a := k * 10.0 if k < 0.1 else ((1.0 - k) * 5.0 if k > 0.8 else 1.0)
		var q: float = g.ease3(minf(1.0, k * 1.4))
		var pos := Vector2(lerpf(g.OX + P.x * g.cam, cx, q), lerpf(g.OY + P.y * g.cam + 70.0, g.OY + g.H * 0.3 * g.cam + 120.0, q))
		draw_circle(pos, 26.0, Color(C_CREAM, 0.16 * a))
		ring(pos, 26.0, Color(C_CREAM, 0.6 * a), 3.0)
	if g.hint_t > 0 and g.hint_s != "":
		label(g.hint_s, cx, g.fr_y + g.fr_h * 0.86, 24.0, C_CREAM, minf(1.0, g.hint_t / 20.0))
	var res: Dictionary = R.res
	if not res.is_empty() and res.has("e") and R.intro > 0:      # Endless: how many walls so far
		var n: int = 120 - R.intro
		var a := minf(1.0, minf(n / 10.0, R.intro / 14.0))
		var y: float = g.fr_y + g.fr_h * 0.26
		label(str(res["n"]), cx, y, 84.0, g.C_AMBER, a, caps)
		label("WALL RUNG" if int(res["n"]) == 1 else "WALLS RUNG", cx, y + 62.0, 18.0, C_CREAM, a, caps)
		if int(res["n"]) > g.EB0 and g.EB0 > 0:
			label("NEW BEST", cx, y + 90.0, 15.0, g.C_MUTED, a, caps)
	elif not res.is_empty() and R.intro > 0:                     # the room you just rang
		var n: int = 120 - R.intro
		var a := minf(1.0, minf(n / 10.0, R.intro / 14.0))
		var y: float = g.fr_y + g.fr_h * 0.28
		var qi: int = res["i"]
		nest(cx, y, 96.0, qi + 1, qi + 1, a)
		var cap := ["out", "no hit", "chain %d+" % ceili(int(res["total"]) * 0.75)]
		for b in 3:
			var on := (int(res["s"]) >> b & 1) == 1
			var tt := n - (24 + b * 16)
			var x := cx + (b - 1) * 62.0
			if tt < 0:
				continue
			star(x, y + 94.0, (20.0 if on else 15.0) * ((1.5 - tt / 16.0) if tt < 8 else 1.0), on, a)
			label(cap[b], x, y + 124.0, 12.0, C_CREAM if on else g.C_MUTED, a)
		label("ROOM %d DONE" % (qi + 1), cx, y + 158.0, 20.0, C_CREAM, a, caps)
		label("best chain %d" % int(res["best"]), cx, y + 183.0, 14.0, g.C_MUTED, a)
	elif R.intro > 0 or R.t < 90:
		var a: float = 1.0 if R.intro > 0 else 1.0 - R.t / 90.0
		var head := "WALL %d" % (g.EW + 1) if g.mode == "endless" else ("TEST" if g.mode == "yard" else "ROOM %d" % (R.i + 1))
		label(head, cx, g.fr_y + g.fr_h * 0.09, 16.0, g.C_MUTED, a, caps)
		label(str(R.def["name"]).to_upper(), cx, g.fr_y + g.fr_h * 0.09 + 32.0, 36.0, C_CREAM, a, caps)


func _hud(P, R) -> void:
	if g.state == "end" or R.fin > 0:
		return
	var y: float = g.fr_y - 30.0
	var x: float = g.fr_x + 16.0
	for i in P.maxH:
		if i < P.hearts:
			heart(x + i * 30.0, y, 0.72, C_CREAM, true)
		else:
			heart(x + i * 30.0, y, 0.58, Color(C_CREAM, 0.35), false)
	var cx: float = g.fr_x + g.fr_w / 2.0
	var left: int = maxi(0, R.total - R.popped)
	if R.cleared:
		ring(Vector2(cx, y), 11.0, g.C_AMBER, 4.5)
	else:
		draw_circle(Vector2(cx - 20.0, y), 7.5, g.TY_COL["b"])
		label(str(left), cx + 8.0, y, 28.0, C_CREAM, 1.0, caps)
	var txt := "WALLS %02d" % g.EW if g.mode == "endless" else ("YARD" if g.mode == "yard" else "%02d/%d" % [R.i + 1, g.ROOMS.size()])
	var fs := 20
	var w := caps.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(caps, Vector2(g.fr_x + g.fr_w - 54.0 - w, y + fs * 0.35), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, C_CREAM)
	if g.slowmo < 1.0:
		label("x0.1", cx, g.fr_y + 16.0, 13.0, g.C_MUTED, 1.0, caps)
