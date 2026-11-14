extends Node3D
## GONG, the Godot port. This file is the game itself: the rules, the clock and the input.
## It is the live web build (repo AYN-2024/SWAY, commit d6564a2) carried over function by
## function: core.js, player.js, enemies.js, rooms.js, fx.js and the loop from ui.js.
## Every number is the same and the game still runs on its own 60-per-second tick.
## Godot's physics engine is not used for the comet or the enemies, only for loose debris.
##
## view.gd draws the 3D scene, overlay.gd draws the flat marks and the HUD, ui.gd is the screens.

const ViewScript := preload("res://scripts/view.gd")
const OverlayScript := preload("res://scripts/overlay.gd")
const UIScript := preload("res://scripts/ui.gd")

# ---------------------------------------------------------------- palette (COL in core.js)
const C_INK := Color("171a2e")
const C_DEEP := Color("0c0e1c")
const C_LINE := Color("0a0c17")
const C_PAPER := Color("f5f2e9")
const C_MUTED := Color("8d93ad")
const C_TEAL := Color("35d2bb")
const C_CORAL := Color("ff5b61")
const C_AMBER := Color("f2c84b")
const C_GREEN := Color("4dff88")
const C_STONE := Color("8a9ba3")
const C_WOOD := Color("b98a5a")

# ---------------------------------------------------------------- movement (MOVE in core.js)
const DRIVE := 0.81
const CAP := 15.3
const HELD := 0.985
const RELEASED := 0.985 / (2.0 - 0.985)
const REACH := 70.0
const REBOUND := 0.74
const BODY_R := 18.0
const TOP := CAP * 0.95                 # "glowing": only this fast pops anything
const SUPER_COST := 50
const HEAL_POPS := 12
const AREA0 := 290000.0

# ---------------------------------------------------------------- enemies (TY in enemies.js)
const TY_COL := {"b": Color("c8573f"), "z": Color("c8573f"), "s": Color("dd8048"), "d": Color("c9567c"),
	"h": Color("a9423f"), "p": Color("8f76c6"), "B": Color("93372f"), "G": Color("93372f")}
const TY_SP := {"b": 0.95, "z": 0.0, "s": 0.8, "d": 0.6, "h": 0.72, "p": 0.5, "B": 0.42, "G": 0.3}
const TY_K := {"b": 1.0, "z": 1.0, "s": 1.12, "d": 0.9, "h": 1.05, "p": 1.0, "B": 1.0, "G": 1.0}
const TY_MX := {"b": 10, "z": 1, "s": 5, "d": 3, "h": 4, "p": 4, "B": 4, "G": 8}
const KIND_DUST := 6
const BAIT_DUST := 4
const TOUGH := 4
const SHOVE_BASE := 8.0
const SHOVE_PER_RING := 0.8
const SHOVE_RINGS := 4
const SHOVE_GAP := 40
const SPIKE_PUSH := 1.5
const SPIKE_DARK := 60

# ---------------------------------------------------------------- rooms (ROOMS in rooms.js)
const ROOMS := [
	{"name": "First pop", "zoom": 1.0, "grow": 8.0, "max": 3, "sp": 0.7, "waves": [[0, "z1@.5,.3"], [999, "z1@.24,.52 z1@.76,.52"], [999, "b1 b1"], [6, "b1 b2 b1"], [7, "b2 b1 b1"]]},
	{"name": "Split and rush", "zoom": 0.985, "grow": 6.5, "max": 10, "sp": 0.85, "waves": [[0, "s2 b1 b1 b1"], [7, "d1 b1 b1 b2"], [7, "s2 d1 b2 b1"], [7, "d1 s2 b2 b1 b1"]]},
	{"name": "Spikes and shields", "zoom": 0.97, "grow": 6.0, "max": 10, "waves": [[0, "p1 b1 b1 b1"], [6, "h1 b2 b1 b2"], [7, "p2 h1 b2 b1"], [7, "h1 p1 s2 d1 b2"]]},
	{"name": "The walls", "zoom": 0.955, "grow": 5.0, "max": 10, "sp": 1.2, "shrink": [0.18, 58],
		"waves": [[0, "b2 b1 b1 s2 b2"], [5, "d1 b2 b2 h1 b2"], [5, "s2 b1 p1 b2 b2"], [5, "b3 d1 s2 b1 b2"], [5, "h2 b2 d1 b2"]]},
	{"name": "The giant", "zoom": 0.94, "grow": 5.0, "max": 10, "sp": 1.2, "waves": [[0, "G6@.5,.28"], [8, "d1 h1 b2 b2"], [10, "p1 d1 b2 b2"], [10, "h2 d1 s2 b2"], [10, "d1 d1 b3 b2"]]},
	{"name": "Stones", "zoom": 0.92, "grow": 5.5, "max": 10, "sp": 1.1, "stones": [[.25, .24], [.5, .2], [.75, .24], [.2, .5], [.5, .5], [.8, .5], [.25, .76], [.5, .8], [.75, .76]],
		"waves": [[0, "b2 b1 b1 b2"], [6, "s2 b2 d1 p1"], [7, "B2 b1 h1"], [5, "b2 b1 b2 d1 p1"]]},
	{"name": "Crowd", "zoom": 0.905, "grow": 4.5, "max": 10, "sp": 1.25, "stones": [[.3, .3], [.7, .3], [.5, .5], [.3, .7], [.7, .7]],
		"waves": [[0, "b2 b1 b2 s2 d1"], [5, "h1 b2 b2 p1 b1"], [6, "s3 d1 b3 b1 h2"], [6, "B2 b2 b1 s2 p2"], [6, "d1 d1 b3 b2 h1"]]},
	{"name": "Twins", "zoom": 0.89, "grow": 5.0, "max": 10, "sp": 1.2, "waves": [[0, "B2 B2 b1 b2"], [6, "h1 h1 b2 d1 b2"], [6, "B3 s2 p1 b2 b2"], [6, "d1 d1 h2 b2 b1 b2"]]},
	{"name": "The vise", "zoom": 0.875, "grow": 4.5, "max": 10, "sp": 1.25, "shrink": [0.2, 45],
		"waves": [[0, "b2 b2 s2 d1 h1"], [5, "p1 b2 b2 d1 b1"], [5, "s3 h1 b2 p1 b2"], [5, "B2 d1 s2 b2 h1"], [5, "d1 d1 b3 h2 b2"]]},
	{"name": "The giant returns", "zoom": 0.86, "grow": 4.5, "max": 10, "sp": 1.3, "waves": [[0, "G9@.5,.28"], [8, "B2 d1 h1 b2"], [9, "p1 d1 b2 h1"], [9, "h2 d1 s2 b2 B2"], [9, "d1 d1 b3 p2"]]},
]
## New, not in the web build: a quiet room for trying the breakable things. No waves, no gong.
const YARD := {"name": "The yard", "zoom": 0.92, "grow": 8.0, "max": 3, "sp": 0.7, "yard": true,
	"stones": [[.22, .2], [.78, .2], [.5, .12]],
	"fences": [[.5, .34, 9, 0.0], [.26, .5, 6, 1.5708], [.74, .5, 6, 1.5708]],
	"waves": [[0, "z1@.5,.47 z2@.34,.25 z1@.66,.25"]]}
const PERKS := [[10, "start Endless with Super ready"], [20, "a fourth heart in Endless"], [30, "dust comes from twice as far in Endless"]]
const ENDLESS_FIRST := [["b", 1], ["s", 2], ["d", 3], ["B", 4], ["p", 5], ["h", 6]]
const ENDLESS_ZOOM := 0.78


class Player:
	var x := 0.0
	var y := 0.0
	var vx := 0.0
	var vy := 0.0
	var r := 18.0
	var tr := PackedVector2Array()
	var top := false
	var over := 0
	var hearts := 3
	var squish := 0.0
	var pnx := 0.0
	var pny := -1.0
	var inv := 0
	var dust := 0
	var ready := false
	var chain := 0
	var rest := 0
	var shoved := 0
	var heal := 0
	var bonkT := 0
	var tE := 0
	var tS := 0
	var sqMax := 0.0
	var dead := false
	var moved := 0.0
	var maxH := 3
	var reach := 120.0
	var shoveT := 0
	var wr := 18.0
	var by := ""


class Enemy:
	var id := 0
	var type := "b"
	var x := 0.0
	var y := 0.0
	var vx := 0.0
	var vy := 0.0
	var n := 1
	var armor := 0
	var am := 0
	var r := 0.0
	var tr := 0.0
	var st := 0
	var tx := 0.0
	var ty := 0.0
	var grow := 0.0
	var ang := 0.0
	var mode := 0
	var mt := 0
	var cd := 0.0
	var dx := 1.0
	var dy := 0.0
	var stun := 0
	var iv := 0
	var fear := 0.0
	var pulse := 0.0
	var bump := false
	var crown := -999
	var born := 0
	var ph := 0
	var cut := false


class Stone:
	var x := 0.0
	var y := 0.0
	var r := 25.0
	var plank := false      # a fence plank: same rule as a stone, different look
	var ang := 0.0


class Arrival:
	var type := "b"
	var n := 1
	var t := 0
	var r := 0.0
	var x := 0.0
	var y := 0.0
	var tx := 0.0
	var ty := 0.0


class Part:
	var k := 0              # 0 spark, 1 shard, 2 ring
	var x := 0.0
	var y := 0.0
	var vx := 0.0
	var vy := 0.0
	var t := 0
	var m := 0.0
	var z := 0.0
	var z1 := 0.0
	var w := 0.0
	var a := 0.0
	var col := Color.WHITE


class Dust:
	var x := 0.0
	var y := 0.0
	var vx := 0.0
	var vy := 0.0
	var t := 0


class Word:
	var x := 0.0
	var y := 0.0
	var s := ""
	var col := Color.WHITE
	var size := 20.0
	var t := 0
	var m := 60


class Room:
	var i := 0
	var def := {}
	var t := 0
	var wi := 0
	var wt := 0
	var total := 0
	var popped := 0
	var best := 0
	var hurt := false
	var cleared := false
	var duds := 0
	var deadT := 0
	var fin := 0
	var intro := 0
	var c0 := 1.0
	var c1 := 1.0
	var ghost := false
	var res := {}
	var ink := Color.BLACK
	var grid := Color.BLACK
	var wall := Color.BLACK
	var sky := PackedVector2Array()


# ---------------------------------------------------------------- shared state
var VW := 390.0
var VH := 740.0
var S0 := 1.0
var cam := 1.0          # screen pixels per game unit
var OX := 0.0           # where the room's corner sits on screen, set every drawn frame
var OY := 0.0
var draw_sx := 0.0      # this frame's screen shake
var draw_sy := 0.0
var W := 390.0
var H := 740.0
var BL := 0.0
var BT := 0.0
var BR := 390.0
var BB := 740.0
var fr_x := 10.0
var fr_y := 58.0
var fr_w := 370.0
var fr_h := 672.0
var state := "title"    # title | play | pause | dead | end
var P: Player = null
var R: Room = null
var E: Array[Enemy] = []
var ST: Array[Stone] = []
var IN: Array[Arrival] = []
var PT: Array[Part] = []
var DU: Array[Dust] = []
var FL: Array[Word] = []
var tick := 0
var gt := 0.0
var freeze := 0
var slow := 1.0
var slowT := 0
var shake := 0.0
var flash := 0.0
var sacc := 0.0
var slowmo := 1.0       # the "1" key: 0.1 speed, for looking at an effect
var seed32 := 1
var eid := 1
var mode := "rooms"     # rooms | endless | yard
var EW := 0
var EB0 := 0
var hint_s := ""
var hint_t := 0
var save := {"rooms": [], "hints": {}, "mute": false, "endless": {"best": 0}}
var all_open := false   # F2 on the title: every room and Endless open, for testing

var inp_down := false
var inp_touch := false
var inp_pid := -1
var inp_pid2 := -1
var inp_sx := 0.0
var inp_sy := 0.0
var inp_sx2 := 0.0
var inp_sy2 := 0.0
var inp_sup := false
var tap_t := -100000
var tap_x := 0.0
var tap_y := 0.0
const MOUSE_PID := 1000

var view
var overlay
var ui
var test_mode := ""
var test_n := 0
var test_ax := 0.0
var test_ay := 0.0
var test_has_aim := false
var test_last := -1
var test_fixed_size := false


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--trace"):
			test_fixed_size = true       # compare against the web build at one known screen size
	_load()
	_layout()
	view = ViewScript.new()
	view.g = self
	add_child(view)
	var layer := CanvasLayer.new()
	layer.layer = 1
	add_child(layer)
	overlay = OverlayScript.new()
	overlay.g = self
	layer.add_child(overlay)
	ui = UIScript.new()
	ui.g = self
	ui.layer = 2
	add_child(ui)
	get_viewport().size_changed.connect(_on_resize)
	show_screen("title")
	_start_test()


# ---------------------------------------------------------------- small maths

static func hyp(a: float, b: float) -> float:
	return sqrt(a * a + b * b)


static func ease3(t: float) -> float:
	return t * t * (3.0 - 2.0 * t)


static func hsl(h: float, s: float, l: float) -> Color:
	var c := (1.0 - absf(2.0 * l - 1.0)) * s
	var hp := fposmod(h, 360.0) / 60.0
	var x := c * (1.0 - absf(fmod(hp, 2.0) - 1.0))
	var m := l - c / 2.0
	var rgb := Vector3(c, x, 0.0)
	if hp >= 1.0 and hp < 2.0:
		rgb = Vector3(x, c, 0.0)
	elif hp >= 2.0 and hp < 3.0:
		rgb = Vector3(0.0, c, x)
	elif hp >= 3.0 and hp < 4.0:
		rgb = Vector3(0.0, x, c)
	elif hp >= 4.0 and hp < 5.0:
		rgb = Vector3(x, 0.0, c)
	elif hp >= 5.0:
		rgb = Vector3(c, 0.0, x)
	return Color(rgb.x + m, rgb.y + m, rgb.z + m)


## The web build's random number generator, bit for bit, so both builds deal the same rooms from the same seed.
static func _u32(v: int) -> int:
	return v & 0xFFFFFFFF


static func _i32(v: int) -> int:
	v &= 0xFFFFFFFF
	return v - 0x100000000 if v >= 0x80000000 else v


static func _imul(a: int, b: int) -> int:
	a &= 0xFFFFFFFF
	b &= 0xFFFFFFFF
	return _i32(((((a >> 16) * b) & 0xFFFF) << 16) + (a & 0xFFFF) * b)


func rnd() -> float:
	seed32 = _i32(seed32 + 0x6D2B79F5)
	var t := _imul(seed32 ^ (_u32(seed32) >> 15), 1 | seed32)
	t = _i32(_i32(t + _imul(t ^ (_u32(t) >> 7), 61 | t)) ^ t)
	return float(_u32(t ^ (_u32(t) >> 14))) / 4294967296.0


func rr(a: float, b: float) -> float:
	return a + rnd() * (b - a)


func say(s: String, t: int = 150) -> void:
	hint_s = s
	hint_t = t


func buzz(ms: int) -> void:
	if OS.has_feature("mobile"):
		Input.vibrate_handheld(ms)


# ---------------------------------------------------------------- screen and save

func _layout() -> void:
	var size := get_viewport().get_visible_rect().size
	if test_fixed_size:
		size = Vector2(390.0, 740.0)
	VW = size.x
	VH = size.y
	var safe := _safe_pad()
	fr_x = 10.0 + safe.x
	fr_y = 58.0 + safe.y
	fr_w = maxf(120.0, VW - fr_x - 10.0 - safe.z)
	fr_h = maxf(120.0, VH - fr_y - 10.0 - safe.w)
	S0 = clampf(sqrt(fr_w * fr_h / AREA0), 0.6, 3.0)   # every screen holds the same amount of room


## Notch and rounded-corner padding on phones: left, top, right, bottom.
func _safe_pad() -> Vector4:
	if not OS.has_feature("mobile"):
		return Vector4.ZERO
	var win := DisplayServer.window_get_size()
	var sa := DisplayServer.get_display_safe_area()
	if win.x <= 0 or win.y <= 0 or sa.size.x <= 0:
		return Vector4.ZERO
	var kx := VW / float(win.x)
	var ky := VH / float(win.y)
	return Vector4(maxf(0.0, sa.position.x * kx), maxf(0.0, sa.position.y * ky),
		maxf(0.0, (win.x - sa.end.x) * kx), maxf(0.0, (win.y - sa.end.y) * ky))


func room_size(zoom: float) -> PackedFloat64Array:      # camera scale, width, height
	var c := S0 * zoom
	return PackedFloat64Array([c, fr_w / c, fr_h / c])


func _on_resize() -> void:
	_layout()
	if R == null:
		return
	var s := room_size(float(R.def["zoom"]))
	var fx := s[1] / W
	var fy := s[2] / H
	P.x *= fx
	P.y *= fy
	for e in E:
		e.x *= fx
		e.y *= fy
		e.tx *= fx
		e.ty *= fy
	for q in ST:
		q.x *= fx
		q.y *= fy
	for n in IN:
		n.x *= fx
		n.y *= fy
		n.tx *= fx
		n.ty *= fy
	for d in DU:
		d.x *= fx
		d.y *= fy
	for q in PT:
		q.x *= fx
		q.y *= fy
	for q in FL:
		q.x *= fx
		q.y *= fy
	for k in P.tr.size():
		P.tr[k] = Vector2(P.tr[k].x * fx, P.tr[k].y * fy)
	W = s[1]
	H = s[2]
	R.c0 = s[0]
	R.c1 = s[0]
	cam = s[0]
	if R.fin == 0:
		BL = 0.0
		BT = 0.0
		BR = W
		BB = H
	view.clear_debris()


func _load() -> void:
	if not FileAccess.file_exists("user://gong_save.json"):
		return
	var f := FileAccess.open("user://gong_save.json", FileAccess.READ)
	if f == null:
		return
	var data: Variant = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return
	var d: Dictionary = data
	if typeof(d.get("rooms")) == TYPE_ARRAY:
		save["rooms"] = d["rooms"]
	if typeof(d.get("hints")) == TYPE_DICTIONARY:
		save["hints"] = d["hints"]
	if typeof(d.get("endless")) == TYPE_DICTIONARY and typeof(d["endless"].get("best")) in [TYPE_FLOAT, TYPE_INT]:
		save["endless"] = {"best": int(d["endless"]["best"])}


func store() -> void:
	if test_mode != "":
		return
	var f := FileAccess.open("user://gong_save.json", FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(save))


func hint_seen(k: String) -> bool:
	return bool(save["hints"].get(k, false))


func room_stars(i: int) -> int:
	var rooms: Array = save["rooms"]
	if i >= rooms.size() or typeof(rooms[i]) != TYPE_DICTIONARY:
		return 0
	return int(rooms[i].get("s", 0))


func stars() -> int:
	var n := 0
	for i in 10:
		var s := room_stars(i)
		n += (s & 1) + (s >> 1 & 1) + (s >> 2 & 1)
	return n


func done_count() -> int:
	var n := 0
	for i in ROOMS.size():
		if room_stars(i) != 0:
			n += 1
	return n


func endless_open() -> bool:
	return all_open or done_count() >= ROOMS.size()


func best_walls() -> int:
	return int(save["endless"]["best"])


# ---------------------------------------------------------------- effects (fx.js)

func puff(x: float, y: float, col: Color, n: int, pw: float) -> void:
	var i := 0
	while i < n and PT.size() < 300:
		var a := rnd() * TAU
		var s := pw * (0.3 + rnd())
		var q := Part.new()
		q.k = 0
		q.x = x
		q.y = y
		q.vx = cos(a) * s
		q.vy = sin(a) * s
		q.m = 20.0 + rnd() * 24.0
		q.z = 2.0 + rnd() * 3.6
		q.col = col
		PT.append(q)
		i += 1


func ring_fx(x: float, y: float, col: Color, r0: float, r1: float, m: float = 26.0, w: float = 4.0) -> void:
	if PT.size() >= 330:
		return
	var q := Part.new()
	q.k = 2
	q.x = x
	q.y = y
	q.m = m
	q.z = r0
	q.z1 = r1
	q.w = w
	q.col = col
	PT.append(q)


func shard(x: float, y: float, vx: float, vy: float, col: Color) -> void:
	if PT.size() >= 330:
		return
	var q := Part.new()
	q.k = 1
	q.x = x
	q.y = y
	q.vx = vx
	q.vy = vy
	q.m = 50.0 + rnd() * 40.0
	q.z = 5.0 + rnd() * 9.0
	q.a = rnd() * TAU
	q.col = col
	PT.append(q)


func word(x: float, y: float, s: String, col: Color, size: float = 20.0, m: int = 60) -> void:
	var f := Word.new()
	f.x = x
	f.y = y
	f.s = s
	f.col = col
	f.size = size
	f.m = m
	FL.append(f)
	if FL.size() > 8:
		FL.remove_at(0)


func dust_at(x: float, y: float, n: int) -> void:
	var i := 0
	while i < n and DU.size() < 170:
		var a := rnd() * TAU
		var s := 2.0 + rnd() * 4.5
		var d := Dust.new()
		d.x = x
		d.y = y
		d.vx = cos(a) * s
		d.vy = sin(a) * s
		DU.append(d)
		i += 1


func fx_tick() -> void:
	var i := PT.size() - 1
	while i >= 0:
		var q := PT[i]
		q.t += 1
		if q.t >= q.m:
			PT[i] = PT[PT.size() - 1]
			PT.pop_back()
			i -= 1
			continue
		var dd := 0.975 if q.k == 1 else 0.93
		q.x += q.vx
		q.y += q.vy
		q.vx *= dd
		q.vy *= dd
		if q.k == 1:
			q.a += 0.18
		i -= 1
	i = FL.size() - 1
	while i >= 0:
		var f := FL[i]
		f.y -= 0.55
		f.t += 1
		if f.t >= f.m:
			FL.remove_at(i)
		i -= 1
	var p := P
	var all := R.cleared
	var reach := 0.0 if p.dead else (1e5 if all else p.reach)   # dust leans toward the comet; a cleared room hands it all over
	i = DU.size() - 1
	while i >= 0:
		var d := DU[i]
		var dx := p.x - d.x
		var dy := p.y - d.y
		var q2 := hyp(dx, dy)
		if q2 == 0.0:
			q2 = 1.0
		d.t += 1
		if d.t > 8 and q2 < reach:
			var pull := 2.2 if all else 0.7 + (1.0 - q2 / reach) * 1.6
			d.vx += dx / q2 * pull
			d.vy += dy / q2 * pull
		d.vx *= 0.9
		d.vy *= 0.9
		d.x += d.vx
		d.y += d.vy
		if not all:
			d.x = clampf(d.x, BL + 4.0, BR - 4.0)
			d.y = clampf(d.y, BT + 4.0, BB - 4.0)
		var got := q2 < p.r + 12.0 and d.t > 6 and not p.dead
		if got or d.t > 1500:
			DU[i] = DU[DU.size() - 1]
			DU.pop_back()
			if got:
				gain_dust()
		i -= 1
	shake *= 0.86
	if shake < 0.4:
		shake = 0.0
	flash *= 0.82


# ---------------------------------------------------------------- the comet (player.js)

func new_player(x: float, y: float) -> Player:
	var p := Player.new()
	p.x = x
	p.y = y
	return p


## On touch the aim sits above the thumb, never under it.
func aim_x() -> float:
	return test_ax if test_has_aim else (inp_sx - OX) / cam


func aim_y() -> float:
	if test_has_aim:
		return test_ay
	var lift := minf(92.0, VH * 0.13) if inp_touch else 0.0
	return (inp_sy - lift - OY) / cam


func aim_point() -> Vector2:
	return Vector2(aim_x(), aim_y())


func _key(a: Key, b: Key) -> bool:
	return test_mode == "" and (Input.is_physical_key_pressed(a) or Input.is_physical_key_pressed(b))


func player_tick() -> void:
	var p := P
	if R.fin > 0:                       # out: nothing holds it any more
		p.x += p.vx
		p.y += p.vy
		_trail(p)
		return
	var cap := CAP * (1.1 if p.over > 0 else 1.0)
	var drive := DRIVE * (1.2 if p.over > 0 else 1.0)
	var ix := 0.0
	var iy := 0.0
	if _key(KEY_LEFT, KEY_A):
		ix -= 1.0
	if _key(KEY_RIGHT, KEY_D):
		ix += 1.0
	if _key(KEY_UP, KEY_W):
		iy -= 1.0
	if _key(KEY_DOWN, KEY_S):
		iy += 1.0
	var keys := ix != 0.0 or iy != 0.0
	if keys and not inp_down:           # a drag wins over the keys: the two never add
		var kd := hyp(ix, iy)
		p.vx += ix / kd * drive
		p.vy += iy / kd * drive
	if inp_down:
		var dx := aim_x() - p.x
		var dy := aim_y() - p.y
		var d := hyp(dx, dy)
		if d > 2.0:
			var f := minf(d / REACH, 1.0) * drive
			p.vx += dx / d * f
			p.vy += dy / d * f
	var q := HELD if (inp_down or keys) else RELEASED
	p.vx *= q
	p.vy *= q
	var v := hyp(p.vx, p.vy)
	if v > cap:
		p.vx *= cap / v
		p.vy *= cap / v
		v = cap
	p.x += p.vx
	p.y += p.vy
	p.moved += v
	if p.over > 0:
		p.over -= 1
	if p.inv > 0:
		p.inv -= 1
	if p.shoved > 0:
		p.shoved -= 1
	if p.bonkT > 0:
		p.bonkT -= 1
	if p.shoveT > 0:
		p.shoveT -= 1
	p.top = v >= TOP - 1e-6 and p.shoved <= 0     # speed you were handed by a shove does not count
	if v < 0.6:
		p.rest += 1
		if p.rest > 24:
			end_chain()
	else:
		p.rest = 0                                # a chain lives while the comet moves and dies when it rests
	if player_walls():
		return                                    # the wall just rang: a new room has taken over
	_trail(p)


func _trail(p: Player) -> void:
	p.tr.append(Vector2(p.x, p.y))
	if p.tr.size() > 26:
		p.tr.remove_at(0)


func player_walls() -> bool:
	var p := P
	if p.x < BL + p.wr:
		if wall_hit(1.0, 0.0, -p.vx):
			return true
		p.x = BL + p.wr
	elif p.x > BR - p.wr:
		if wall_hit(-1.0, 0.0, p.vx):
			return true
		p.x = BR - p.wr
	if p.y < BT + p.wr:
		if wall_hit(0.0, 1.0, -p.vy):
			return true
		p.y = BT + p.wr
	elif p.y > BB - p.wr:
		if wall_hit(0.0, -1.0, p.vy):
			return true
		p.y = BB - p.wr
	return false


func wall_hit(nx: float, ny: float, vn: float) -> bool:    # (nx,ny) points back into the room, vn is the speed into the wall
	var p := P
	if vn <= 0.0:
		return false
	if R.cleared:
		if p.top and vn >= 6.0:
			gong_now(nx, ny)
			return true
		if vn > 3.0 and p.bonkT <= 0:
			p.bonkT = 20
			ring_fx(p.x, p.y, C_AMBER, 6.0, 46.0, 16.0, 3.0)
			R.duds += 1
			if R.duds > 1:
				say("Faster", 120)
	if nx != 0.0:
		p.vx = -p.vx * REBOUND
	else:
		p.vy = -p.vy * REBOUND
	if vn > 2.0:
		if vn > 9.0:
			shake = maxf(shake, vn * 0.3)
			puff(p.x - nx * p.wr, p.y - ny * p.wr, R.wall, 5, 3.0)
			view.chips(p.x - nx * p.wr, p.y - ny * p.wr, nx, ny, vn)
	return false


func end_chain() -> void:
	if P.chain > R.best:
		R.best = P.chain
	P.chain = 0


func chain_up() -> void:
	var p := P
	p.chain += 1
	if p.chain > R.best:
		R.best = p.chain
	if p.chain > 2:
		word(p.x, p.y - p.r - 16.0, "x%d" % p.chain, C_AMBER, 15.0 + minf(p.chain, 14.0), 36)


func gain_dust() -> void:
	var p := P
	if R.i < 1 or p.dust >= SUPER_COST:      # room 1 has no Super yet
		return
	p.dust += 1
	if p.dust >= SUPER_COST:
		p.ready = true
		ring_fx(p.x, p.y, C_GREEN, 10.0, 70.0, 24.0, 4.0)
		if not hint_seen("sup"):
			say("Double-tap", 600)


## The squeeze: pinned = touching two bodies, or one body and something solid.
## The meter fills in 45 ticks while pinned and empties in 20 once free. Full = one heart.
func squeeze_tick() -> void:
	var p := P
	if p.inv > 0:
		p.squish = maxf(0.0, p.squish - 0.05)
		return
	var wall := p.x <= BL + p.wr + 1.5 or p.x >= BR - p.wr - 1.5 or p.y <= BT + p.wr + 1.5 or p.y >= BB - p.wr - 1.5
	var pinned := p.tE >= 2 or (p.tE >= 1 and (wall or p.tS > 0))
	p.squish = minf(1.0, p.squish + 1.0 / 45.0) if pinned else maxf(0.0, p.squish - 1.0 / 20.0)
	if p.squish > p.sqMax:
		p.sqMax = p.squish
	if p.squish >= 1.0:
		hurt("")
	elif p.squish == 0.0 and p.sqMax > 0.0:
		if p.sqMax > 0.6:
			word(p.x, p.y - p.r - 22.0, "Close!", C_PAPER, 20.0, 46)     # slipped out of a squeeze
		p.sqMax = 0.0


func hurt(by: String) -> void:
	var p := P
	p.by = by if by != "" else "squeeze"
	p.hearts -= 1
	p.squish = 0.0
	p.sqMax = 0.0
	p.inv = 110
	p.heal = 0
	R.hurt = true
	end_chain()
	shake = 24.0
	freeze = 8
	flash = 1.0
	buzz(40)
	ring_fx(p.x, p.y, C_CORAL, 10.0, 240.0, 30.0, 7.0)
	puff(p.x, p.y, C_TEAL, 24, 7.0)
	for e in E:
		var dx := e.x - p.x
		var dy := e.y - p.y
		var d := hyp(dx, dy)
		if d == 0.0:
			d = 1.0
		if d < e.r + p.r + 8.0:
			e.crown = tick                         # the ones that did it get a crown if this was the last heart
		if d < 280.0 + e.r:
			var k := (1.0 - maxf(0.0, d - e.r) / 280.0) * 10.0
			e.vx += dx / d * k
			e.vy += dy / d * k
			e.stun = 70
	if p.hearts <= 0:
		p.dead = true
		R.deadT = 70
		slow = 0.25
		slowT = 70
		puff(p.x, p.y, C_TEAL, 40, 9.0)
		ring_fx(p.x, p.y, C_PAPER, 10.0, 160.0, 36.0, 5.0)
		view.burst(p.x, p.y, p.vx, p.vy, Color("efe6d0"), 10, 9.0, 4.0, 0)


## Super: one blast that clears the space around you, and half a second where nothing can squeeze you.
func fire_super() -> void:
	var p := P
	if not p.ready:
		return
	p.ready = false
	p.dust = 0
	p.inv = maxi(p.inv, 30)
	p.squish = 0.0
	p.sqMax = 0.0
	p.shoved = 0
	slow = 0.4
	slowT = 16
	shake = 18.0
	buzz(30)
	save["hints"]["sup"] = 1
	store()
	if hint_s == "Double-tap":
		hint_t = 0
	ring_fx(p.x, p.y, C_GREEN, 20.0, 230.0, 30.0, 9.0)
	view.shockwave(p.x, p.y, 2.6, 7.0)
	for e: Enemy in E.duplicate():
		var dx := e.x - p.x
		var dy := e.y - p.y
		var d := hyp(dx, dy)
		if d == 0.0:
			d = 1.0
		if d < 190.0 + e.r:
			strike(e, -dx / d, -dy / d, true)
		elif d < 460.0:
			var k := (1.0 - d / 460.0) * 8.0
			e.vx += dx / d * k
			e.vy += dy / d * k
			e.stun = 40
	var i := ST.size() - 1
	while i >= 0:
		if hyp(ST[i].x - p.x, ST[i].y - p.y) < 200.0:
			break_stone(i)
		i -= 1


# ---------------------------------------------------------------- enemies (enemies.js)

static func ring_r(n: int) -> float:
	return 19.0 + 9.5 * (n - 1) + 0.55 * (n - 1) * (n - 1)


static func rings_of(type: String, n: int) -> int:
	return 8 if type == "G" else (4 if type == "B" else n)


func body_r(e: Enemy) -> float:
	var v := ring_r(e.n) * float(TY_K[e.type])
	if e.type == "p" and e.mode == 2:
		v *= 1.6
	if e.type == "G":
		v *= 0.62 + 0.38 * float(e.armor) / float(e.am)
	return v


func mk_enemy(type: String, x: float, y: float, n: int) -> Enemy:
	var big := type == "B" or type == "G"
	var e := Enemy.new()
	e.id = eid
	eid += 1
	e.type = type
	e.x = x
	e.y = y
	e.n = rings_of(type, n)
	e.armor = n if big else 0
	e.am = e.armor
	e.tx = x
	e.ty = y
	e.mt = int(rnd() * 120.0) if type == "p" else 0
	e.cd = rr(110.0, 260.0)
	e.born = tick
	e.ph = int(rnd() * 400.0)
	e.r = body_r(e)
	e.tr = e.r
	e.grow = float(R.def["grow"]) * 60.0 * rr(0.7, 1.3)
	return e


## A spot just outside a wall, and where to slide to. Never right on top of the comet.
func edge_spot(r: float, n: Arrival) -> void:
	for k in 10:
		var side := int(rnd() * 4.0)
		var u := rnd()
		var ix := lerpf(BL + r + 8.0, BR - r - 8.0, u)
		var iy := lerpf(BT + r + 8.0, BB - r - 8.0, u)
		if side == 0:
			n.x = BL - r - 8.0
			n.y = iy
			n.tx = BL + r + 26.0
			n.ty = iy
		elif side == 1:
			n.x = BR + r + 8.0
			n.y = iy
			n.tx = BR - r - 26.0
			n.ty = iy
		elif side == 2:
			n.x = ix
			n.y = BT - r - 8.0
			n.tx = ix
			n.ty = BT + r + 26.0
		else:
			n.x = ix
			n.y = BB + r + 8.0
			n.tx = ix
			n.ty = BB - r - 26.0
		if hyp(n.tx - P.x, n.ty - P.y) > 210.0:
			break


func enemies_tick() -> void:
	var p := P
	var pv := hyp(p.vx, p.vy)
	var f := minf(1.0, pv / CAP)
	var hx := p.vx / pv if pv > 0.5 else 0.0
	var hy := p.vy / pv if pv > 0.5 else 0.0
	var spd := float(R.def.get("sp", 1.0))
	var grow_s := float(R.def["grow"])
	var max_n := int(R.def["max"])
	var area := 0.0
	for e in E:
		area += e.r * e.r
	var full := area * PI > (BR - BL) * (BB - BT) * 0.68          # a packed room stops growing
	var idx := 0
	while idx < E.size():
		var e := E[idx]
		idx += 1
		e.fear *= 0.88
		e.pulse *= 0.9
		if e.iv > 0:
			e.iv -= 1
		if e.st == 0:                                                # sliding in from outside
			var dx := e.tx - e.x
			var dy := e.ty - e.y
			var d := hyp(dx, dy)
			if d == 0.0:
				d = 1.0
			e.vx = dx / d * 2.8
			e.vy = dy / d * 2.8
			if d < 4.0:
				e.st = 1
		elif e.stun > 0 or e.type == "z" or p.dead:
			if e.stun > 0:
				e.stun -= 1
			e.vx *= 0.9
			e.vy *= 0.9
		else:
			brain(e, p, pv, f, hx, hy, spd)
		e.x += e.vx
		e.y += e.vy
		if e.st == 1 and e.type != "z" and e.am == 0:
			e.grow -= 1.0
			if e.grow <= 0.0:
				e.grow = grow_s * 60.0 * rr(0.8, 1.25)
				if e.n < mini(max_n, int(TY_MX[e.type])) and not full:
					e.n += 1
					e.pulse = 1.0
		e.tr = body_r(e)
		e.r += (e.tr - e.r) * 0.12
	var count := E.size()
	for i in count:                                                  # the crowd packs; the lighter body gives way
		var a := E[i]
		for j in range(i + 1, count):
			var b := E[j]
			var dx := b.x - a.x
			var dy := b.y - a.y
			var m := a.r + b.r
			if dx > m or dx < -m or dy > m or dy < -m:
				continue
			var d := hyp(dx, dy)
			if d == 0.0:
				d = 0.01
			if d >= m:
				continue
			var o := (m - d) * 0.6 / d
			var aa := a.r * a.r
			var bb := b.r * b.r
			var wa := bb / (aa + bb)
			var wb := 1.0 - wa
			if a.type == "d" and a.mode == 2:
				wa = 0.0
				wb = 1.0
			elif b.type == "d" and b.mode == 2:
				wb = 0.0
				wa = 1.0
			a.x -= dx * o * wa
			a.y -= dy * o * wa
			b.x += dx * o * wb
			b.y += dy * o * wb
		for s in ST:
			var dx := a.x - s.x
			var dy := a.y - s.y
			var m := a.r + s.r
			var d := hyp(dx, dy)
			if d == 0.0:
				d = 0.01
			if d < m:
				a.x += dx / d * (m - d)
				a.y += dy / d * (m - d)
		a.bump = false
		if a.st == 1:
			var r := minf(a.r, minf((BR - BL) / 2.0 - 1.0, (BB - BT) / 2.0 - 1.0))
			if a.x < BL + r:
				a.x = BL + r
				a.bump = a.vx < 0.0
			elif a.x > BR - r:
				a.x = BR - r
				a.bump = a.vx > 0.0
			if a.y < BT + r:
				a.y = BT + r
				a.bump = a.bump or a.vy < 0.0
			elif a.y > BB - r:
				a.y = BB - r
				a.bump = a.bump or a.vy > 0.0
	if not p.dead and R.fin == 0:
		contact()


func brain(e: Enemy, p: Player, pv: float, f: float, hx: float, hy: float, spd: float) -> void:
	var dx := p.x - e.x
	var dy := p.y - e.y
	var d := hyp(dx, dy)
	if d == 0.0:
		d = 1.0
	var sp := float(TY_SP[e.type]) * spd / (1.0 + 0.1 * (e.n - 1)) * (1.55 - 1.15 * f)    # creep in while the comet is slow
	var ahead := (-dx * hx - dy * hy) / d if pv > 0.5 else 0.0                              # 1 = right in the comet's path
	if ahead < -0.2 and f > 0.3:
		sp *= 1.5                                                                          # bolder behind its back
	var ax := dx / d * sp
	var ay := dy / d * sp
	if p.top and ahead > 0.72 and d < 210.0 + e.r and e.type != "G":                       # faced at full speed: step aside
		var s := 1.0 if dx * hy - dy * hx > 0.0 else -1.0
		ax = -hy * s * 1.15
		ay = hx * s * 1.15
		e.fear = 1.0
	if e.type == "d":
		if e.mode == 0:
			e.cd -= 1.0
			if e.cd <= 0.0 and d < 540.0:
				e.mode = 1
				e.mt = 46
		elif e.mode == 1:
			ax = 0.0
			ay = 0.0
			if e.mt == 16:                                           # the aim locks here; the line shows it
				var lx := dx + p.vx * 7.0
				var ly := dy + p.vy * 7.0
				var l := hyp(lx, ly)
				if l == 0.0:
					l = 1.0
				e.dx = lx / l
				e.dy = ly / l
			e.mt -= 1
			if e.mt <= 0:
				e.mode = 2
				e.mt = 42
		elif e.mode == 2:
			e.vx = e.dx * 9.5
			e.vy = e.dy * 9.5
			e.mt -= 1
			if e.mt <= 0 or e.bump:
				e.mode = 3
				e.mt = 90 if e.bump else 55
				if e.bump:
					shake = maxf(shake, 7.0)
					puff(e.x, e.y, TY_COL["d"], 6, 3.0)
					dust_at(e.x, e.y, BAIT_DUST)
			return
		else:                                                        # dizzy
			ax = 0.0
			ay = 0.0
			e.mt -= 1
			if e.mt <= 0:
				e.mode = 0
				e.cd = rr(130.0, 270.0)
	elif e.type == "h":
		var da := atan2(dy, dx) - e.ang
		da = atan2(sin(da), cos(da))
		e.ang += clampf(da, -0.03, 0.03)
	elif e.type == "p":
		e.mt += 1
		if e.mode == 0 and e.mt > 170:
			e.mode = 1
			e.mt = 0
		elif e.mode == 1 and e.mt > 34:
			e.mode = 2
			e.mt = 0
		elif e.mode == 2 and e.mt > 120:
			e.mode = 0
			e.mt = 0
	elif e.type == "G":
		e.cd -= 1.0
		if e.cd <= 0.0:                                              # the giant makes more
			e.cd = clampf(250.0 - (e.am - e.armor) * 22.0, 120.0, 250.0)
			if E.size() < 12:
				for s: float in [-1.0, 1.0]:
					var a := atan2(dy, dx) + s * 0.9
					var c := mk_enemy("b", e.x + cos(a) * e.r, e.y + sin(a) * e.r, 1)
					c.st = 1
					c.vx = cos(a) * 6.0
					c.vy = sin(a) * 6.0
					c.stun = 24
					E.append(c)
					R.total += 1
	e.vx += (ax - e.vx) * 0.07
	e.vy += (ay - e.vy) * 0.07


## The comet against everything else.
func contact() -> void:
	var p := P
	p.tE = 0
	p.tS = 0
	var i := ST.size() - 1
	while i >= 0:
		var s := ST[i]
		var dx := p.x - s.x
		var dy := p.y - s.y
		var m := s.r + p.r
		var d := hyp(dx, dy)
		if d == 0.0:
			d = 0.01
		if d > m + 1.5:
			i -= 1
			continue
		if d < m:
			if p.top:
				break_stone(i)
				i -= 1
				continue
			var nx := dx / d
			var ny := dy / d
			var vn := p.vx * nx + p.vy * ny
			p.x += nx * (m - d)
			p.y += ny * (m - d)
			if vn < 0.0:
				p.vx -= (1.0 + REBOUND) * vn * nx
				p.vy -= (1.0 + REBOUND) * vn * ny
		p.tS += 1
		i -= 1
	i = E.size() - 1
	while i >= 0:
		var e := E[i]
		var dx := p.x - e.x
		var dy := p.y - e.y
		var m := e.r + p.r
		if dx > m + 2.0 or dx < -m - 2.0 or dy > m + 2.0 or dy < -m - 2.0:
			i -= 1
			continue
		var d := hyp(dx, dy)
		if d == 0.0:
			d = 0.01
		if d > m + 1.5:
			i -= 1
			continue
		var nx := dx / d
		var ny := dy / d
		if d < m:
			if can_strike(e, nx, ny):
				strike(e, nx, ny, false)
				if i >= E.size() or E[i] != e:
					i -= 1
					continue
			else:
				bump_into(e, nx, ny, m - d)
		if e.type != "z":                                            # a sleeper cannot pin you
			p.tE += 1
			p.pnx = nx
			p.pny = ny
		i -= 1
	p.x = clampf(p.x, BL + p.wr, BR - p.wr)
	p.y = clampf(p.y, BT + p.wr, BB - p.wr)


func can_strike(e: Enemy, nx: float, ny: float) -> bool:
	var p := P
	if not p.top or e.iv > 0:
		return false
	if e.type == "p" and e.mode == 2:
		return false                                                 # spikes out
	if e.type == "h" and nx * cos(e.ang) + ny * sin(e.ang) > 0.42:
		return false                                                 # into the shield
	return true


func strike(e: Enemy, nx: float, ny: float, blast: bool) -> void:   # (nx,ny) points from the enemy to the comet
	var p := P
	if e.armor > 0:
		e.armor = maxi(0, e.armor - (2 if blast else 1))
		e.pulse = 1.0
		e.stun = 30
		e.iv = 34
		e.vx -= nx * 3.0
		e.vy -= ny * 3.0
		chain_up()
		if not blast:
			var vn := p.vx * nx + p.vy * ny
			if vn < 0.0:
				p.vx -= 1.8 * vn * nx
				p.vy -= 1.8 * vn * ny
			p.x = e.x + nx * (e.r + p.r + 1.0)
			p.y = e.y + ny * (e.r + p.r + 1.0)
		freeze = maxi(freeze, 5)
		shake = maxf(shake, 15.0)
		buzz(20)
		puff(e.x + nx * e.r, e.y + ny * e.r, C_PAPER, 16, 6.0)
		ring_fx(e.x, e.y, C_PAPER, e.r * 0.8, e.r * 1.5, 20.0, 5.0)
		view.burst(e.x + nx * e.r, e.y + ny * e.r, -nx * 4.0, -ny * 4.0, Color("cfc3a8"), 3, 8.0, 2.5, 0)
		return
	if not blast and e.type == "b" and e.n >= TOUGH and not e.cut:
		e.cut = true
		e.n = ceili(e.n / 2.0)
		e.pulse = 0.0
		e.stun = 30
		e.iv = 34
		e.vx -= nx * 3.0
		e.vy -= ny * 3.0
		chain_up()
		var vn2 := p.vx * nx + p.vy * ny
		if vn2 < 0.0:
			p.vx -= 1.8 * vn2 * nx
			p.vy -= 1.8 * vn2 * ny
		p.x = e.x + nx * (e.r + p.r + 1.0)
		p.y = e.y + ny * (e.r + p.r + 1.0)
		freeze = maxi(freeze, 5)
		shake = maxf(shake, 13.0)
		buzz(20)
		dust_at(e.x, e.y, 4)
		puff(e.x + nx * e.r, e.y + ny * e.r, TY_COL["b"], 18, 6.0)
		ring_fx(e.x, e.y, TY_COL["b"], e.r * 0.8, e.r * 1.5, 20.0, 5.0)
		view.burst(e.x + nx * e.r, e.y + ny * e.r, -nx * 4.0, -ny * 4.0, TY_COL["b"], 6, 8.0, 3.0, 0)
		return
	pop(e)


func pop(e: Enemy) -> void:
	var p := P
	var i := E.find(e)
	if i < 0:
		return
	E.remove_at(i)
	var col: Color = TY_COL[e.type]
	var big := e.n > 2
	R.popped += 1
	chain_up()
	p.over = 30                                                      # a pop never slows you: it gives you a kick
	freeze = maxi(freeze, 4 if big else 2)
	shake = maxf(shake, 5.0 + e.n * 2.4)
	buzz(16 if big else 8)
	puff(e.x, e.y, col, 10 + e.n * 5, 4.0 + e.n)
	ring_fx(e.x, e.y, col, e.r * 0.6, e.r * 1.8, 18.0, 5.0)
	dust_at(e.x, e.y, 3 + e.n * 2 + (KIND_DUST if e.type in ["d", "p", "h"] else 0))
	view.pop_puck(e.x, e.y, e.r, e.n, col, p.vx, p.vy)
	if e.type == "s":                                                # two smaller ones fly out sideways
		var v := hyp(p.vx, p.vy)
		if v == 0.0:
			v = 1.0
		var sx := -p.vy / v
		var sy := p.vx / v
		for s: float in [-1.0, 1.0]:
			var c := mk_enemy("b", e.x + sx * s * e.r * 0.5, e.y + sy * s * e.r * 0.5, maxi(1, e.n - 1))
			c.st = 1
			c.vx = sx * s * 7.0
			c.vy = sy * s * 7.0
			c.stun = 26
			c.iv = 10
			E.append(c)
	if e.type == "G":
		slow = 0.3
		slowT = 60
		shake = 30.0
		dust_at(e.x, e.y, 40)
		puff(e.x, e.y, C_PAPER, 40, 10.0)
		view.burst(e.x, e.y, p.vx, p.vy, col, 26, 13.0, 6.0, 0)
	if p.hearts < p.maxH:
		p.heal += 1
		if p.heal >= HEAL_POPS:
			p.heal = 0
			p.hearts += 1
			word(p.x, p.y - p.r - 30.0, "+1", C_CORAL, 24.0, 50)


## A touch that is not a pop: the body throws you back and the chain ends. It costs no heart.
func bump_into(e: Enemy, nx: float, ny: float, o: float) -> void:
	var p := P
	var vn := p.vx * nx + p.vy * ny
	var en := e.vx * nx + e.vy * ny
	p.x += nx * o
	p.y += ny * o
	if e.type == "p" and e.mode == 2 and p.shoveT <= 0:            # spikes: stopped dead, no glow for a second, and a heart
		p.vx = nx * SPIKE_PUSH
		p.vy = ny * SPIKE_PUSH
		p.shoved = SPIKE_DARK
		p.shoveT = SHOVE_GAP
		p.squish = minf(0.9, p.squish + 0.2)
		end_chain()
		shake = maxf(shake, 14.0)
		buzz(20)
		puff(p.x, p.y, TY_COL["p"], 14, 6.0)
		if p.inv <= 0:
			hurt("spike")
		return
	if e.type == "d" and e.mode == 2:
		p.vx += e.dx * 11.0
		p.vy += e.dy * 11.0
		p.shoved = 18
		p.squish = minf(0.9, p.squish + 0.3)
		e.mode = 3
		e.mt = 60
		end_chain()
		shake = maxf(shake, 14.0)
		return
	if e.iv > 0:                                                     # just struck: solid for a moment, no penalty
		if vn < 0.0:
			p.vx -= 1.7 * vn * nx
			p.vy -= 1.7 * vn * ny
		return
	if e.type != "z" and p.shoveT <= 0:                              # thrown back; bigger bodies throw harder; sleepers never do
		var k := SHOVE_BASE + mini(e.n, SHOVE_RINGS) * SHOVE_PER_RING
		p.vx = nx * k + e.vx
		p.vy = ny * k + e.vy
		p.shoved = 18
		p.shoveT = SHOVE_GAP
		p.bonkT = 14
		e.pulse = 1.0
		end_chain()
		shake = maxf(shake, 9.0)
		buzz(12)
		puff(p.x - nx * p.r, p.y - ny * p.r, TY_COL[e.type], 8, 5.0)
		return
	if vn < 0.0:
		p.vx -= 1.55 * vn * nx
		p.vy -= 1.55 * vn * ny
		p.vx *= 0.3
		p.vy *= 0.3
	var v2 := p.vx * nx + p.vy * ny
	if v2 < en:                                                      # a body that keeps coming carries the comet with it
		p.vx += (en - v2) * nx
		p.vy += (en - v2) * ny
	if vn < -3.0 and p.bonkT <= 0:
		p.bonkT = 14
		shake = maxf(shake, 4.0)
		if e.type == "z" and not hint_seen("pop"):
			say("Faster. Glow to pop.", 200)
	end_chain()
	e.vx -= nx * 0.5
	e.vy -= ny * 0.5


func break_stone(i: int) -> void:
	var s := ST[i]
	ST.remove_at(i)
	freeze = maxi(freeze, 2)
	shake = maxf(shake, 6.0)
	var col := C_WOOD if s.plank else C_STONE
	puff(s.x, s.y, col, 12, 5.0)
	ring_fx(s.x, s.y, col, s.r * 0.5, s.r * 1.6, 16.0, 4.0)
	dust_at(s.x, s.y, 4)
	if s.plank:
		view.burst(s.x, s.y, P.vx, P.vy, C_WOOD, 5, 7.0, 3.0, 1)
		R.popped += 1                 # the yard counts what you broke
	else:
		view.burst(s.x, s.y, P.vx, P.vy, C_STONE, 6, 14.0, 3.0, 2)


# ---------------------------------------------------------------- rooms (rooms.js)

func endless_def(n: int) -> Dictionary:
	var giant := n % 10 == 0
	var twist := ""
	if n % 5 == 0 and not giant:                 # every 5th wall has a twist, every 10th is the giant
		twist = "walls" if ((n / 5) >> 1) & 1 == 1 else "stones"
	var pool: Array[String] = []
	for t in ENDLESS_FIRST:
		if int(t[1]) <= n:
			pool.append(str(t[0]))
	var big := 1 + mini(2, (n - 1) / 4)
	var n_waves := mini(6, 3 + (n - 1) / 3)
	var n_bodies := mini(6, 3 + (n - 1) / 4)
	var gap := maxf(4.0, 7.0 - 0.25 * (n - 1))
	var waves: Array = []
	for w in n_waves:
		var out: PackedStringArray = []
		var seen := {}
		for k in n_bodies:
			var t := "b"
			if not (k < 2 or rnd() < 0.35):
				var idx := 1 + int(rnd() * (pool.size() - 1))
				t = pool[idx] if idx < pool.size() else "b"
			if t != "b" and int(seen.get(t, 0)) >= (2 if t == "d" else 1):
				t = "b"                          # one of each odd kind a wave, two dashers at most
			seen[t] = int(seen.get(t, 0)) + 1
			var r := 1
			if t == "b":
				r = 1 + int(rnd() * big)
			elif t == "s":
				r = 2 + int(rnd() * mini(2, big))
			elif t == "B":
				r = 2
			elif t == "d":
				r = 1
			else:
				r = 1 + int(rnd() * mini(2, big))
			out.append("%s%d" % [t, r])
		waves.append([gap if w > 0 else 0.0, " ".join(out)])
	if giant:
		waves[0] = [0, "G7@.5,.28"]
	var def := {"name": "The giant" if giant else ("The walls" if twist == "walls" else ("Stones" if twist == "stones" else "")),
		"zoom": ENDLESS_ZOOM, "grow": maxf(3.5, 6.0 - 0.2 * (n - 1)), "max": 10, "sp": minf(1.6, 1.0 + 0.05 * (n - 1)), "waves": waves}
	if twist == "stones":
		def["stones"] = [[.3, .3], [.7, .3], [.5, .5], [.3, .7], [.7, .7]]
	if twist == "walls":
		def["shrink"] = [0.25, 58]
	return def


func tokens(s: String) -> Array:
	var out: Array = []
	for t in s.split(" ", false):
		var tok := {"type": t.substr(0, 1), "n": int(t.substr(1, 1)), "fx": -1.0, "fy": 0.0}
		var at := t.find("@")
		if at >= 0:
			var xy := t.substr(at + 1).split(",")
			tok["fx"] = xy[0].to_float()
			tok["fy"] = xy[1].to_float()
		out.append(tok)
	return out


func bodies(def: Dictionary) -> int:
	var n := 0
	for w: Array in def["waves"]:
		for t: Dictionary in tokens(str(w[1])):
			n += 3 if t["type"] == "s" else 1
	return n


## carry = arriving through a broken wall: the comet keeps its speed and the old room stays behind as a ghost.
func start_room(i: int, carry: bool) -> void:
	var def: Dictionary = endless_def(EW + 1) if mode == "endless" else (YARD if mode == "yard" else ROOMS[i])
	var s := room_size(float(def["zoom"]))
	var ox := (s[1] - W) / 2.0 if carry else 0.0
	var oy := (s[2] - H) / 2.0 if carry else 0.0
	var prev := P
	var old_rect := Rect2(ox, oy, W, H)
	var c0 := cam if carry else s[0]
	var res: Dictionary = R.res if carry else {}
	W = s[1]
	H = s[2]
	BL = 0.0
	BT = 0.0
	BR = W
	BB = H
	E.clear()
	IN.clear()
	ST.clear()
	if carry:
		for q in PT:
			q.x += ox
			q.y += oy
		for d in DU:
			d.x += ox
			d.y += oy
		for q in FL:
			q.x += ox
			q.y += oy
	else:
		PT.clear()
		DU.clear()
		FL.clear()
	P = new_player(W / 2.0, H * 0.72)
	if carry:
		P.x = prev.x + ox
		P.y = prev.y + oy
		P.vx = prev.vx
		P.vy = prev.vy
		P.over = 30
		P.tr = prev.tr.duplicate()
		for k in P.tr.size():
			P.tr[k] += Vector2(ox, oy)
		P.hearts = prev.hearts
		P.heal = prev.heal
		if mode == "endless":            # Endless: nothing refills at the wall
			P.maxH = prev.maxH
			P.reach = prev.reach
			P.dust = prev.dust
			P.ready = prev.ready
			P.chain = prev.chain
			P.inv = prev.inv
	elif mode == "endless":              # what the stars bought
		var n := stars()
		if n >= 20:
			P.hearts = 4
			P.maxH = 4
		if n >= 10:
			P.dust = SUPER_COST
			P.ready = true
		if n >= 30:
			P.reach = 240.0
	var hue := 192.0 + (i if i < 40 else 0) * 1.5           # slate; each room drifts a little further along
	R = Room.new()
	R.i = i
	R.def = def
	R.total = bodies(def)
	R.intro = 120 if carry else 36
	R.c0 = c0
	R.c1 = s[0]
	R.ghost = carry
	R.res = res
	R.ink = hsl(hue, 0.22, 0.205)
	R.grid = hsl(hue, 0.2, 0.235)
	R.wall = hsl(hue, 0.18, 0.3)
	for q: Array in def.get("stones", []):
		var st := Stone.new()
		st.x = float(q[0]) * W
		st.y = float(q[1]) * H
		ST.append(st)
	for q: Array in def.get("fences", []):      # a fence is a row of planks; each plank follows the stone rule
		var n_planks := int(q[2])
		var ang := float(q[3])
		for k in n_planks:
			var st := Stone.new()
			var off := (k - (n_planks - 1) / 2.0) * 21.0
			st.x = float(q[0]) * W + cos(ang) * off
			st.y = float(q[1]) * H + sin(ang) * off
			st.r = 11.0
			st.plank = true
			st.ang = ang
			ST.append(st)
		R.total += n_planks
	cam = c0
	hint_t = 0
	if i == 0 and mode == "rooms" and not hint_seen("drag"):
		say("Drag", 1000000)
	if i == 1 and mode == "rooms" and not hint_seen("wall"):
		save["hints"]["wall"] = 1
		store()
		say("Bounce off walls to turn", 300)
	if mode == "yard":
		P.dust = SUPER_COST
		P.ready = true
		say("Glow to break things", 400)
	view.on_room(carry, ox, oy, old_rect)


func room_tick() -> void:
	var r := R
	var d := r.def
	if r.fin > 0:                        # out: the camera lets go; the ten rooms shrink to a dot behind the comet
		r.fin += 1
		cam += (minf(r.c1, minf(fr_w, fr_h) / (hyp(P.x - W / 2.0, P.y - H / 2.0) * 2.3 + maxf(W, H) * 0.9)) - cam) * 0.07
		var v := hyp(P.vx, P.vy)
		if v == 0.0:
			v = 1.0
		var dx := P.vx / v
		var dy := P.vy / v
		for k in r.sky.size():
			var q := r.sky[k]
			if (q.x - P.x) * dx + (q.y - P.y) * dy < -2500.0:
				r.sky[k] = Vector2(q.x + dx * 9000.0, q.y + dy * 9000.0)
		if r.fin == 250:
			state = "end"
			show_screen("end")
		return
	if r.intro > 0:                      # the camera settles
		r.intro -= 1
		cam = lerpf(r.c0, r.c1, ease3(1.0 - r.intro / (120.0 if r.ghost else 36.0)))
		return
	cam = r.c1
	r.t += 1
	r.wt += 1
	var waves: Array = d["waves"]
	if r.wi < waves.size():
		var w: Array = waves[r.wi]
		var alive := E.size() + IN.size()
		if r.wt >= float(w[0]) * 60.0 or (alive <= (0 if r.i < 2 else (1 if r.i < 5 else 2)) and r.wt > 24):
			launch(str(w[1]))
			r.wi += 1
			r.wt = 0
	var i := IN.size() - 1
	while i >= 0:
		var n := IN[i]
		n.t -= 1
		if n.t <= 0:
			IN.remove_at(i)
			var e := mk_enemy(n.type, n.x, n.y, n.n)
			e.tx = n.tx
			e.ty = n.ty
			E.append(e)
		i -= 1
	if d.has("shrink"):                  # the walls themselves close in
		var sh: Array = d["shrink"]
		var k := 0.0 if r.cleared else minf(1.0, r.t / (float(sh[1]) * 60.0)) * float(sh[0])
		BL += (W * k - BL) * 0.1
		BT += (H * k - BT) * 0.1
		BR = W - BL
		BB = H - BT
	if r.cleared:
		r.wt += 1
		if r.wt == 260:
			say("Gong the wall", 220)    # a reminder if you linger
	if not d.has("yard") and not r.cleared and r.wi >= waves.size() and IN.is_empty() and E.is_empty():
		r.cleared = true
		r.wt = 0
		slow = 0.5
		slowT = 20
		shake = maxf(shake, 8.0)
		if hint_seen("gong"):
			hint_t = 0
		else:
			say("Gong the wall", 1000000)


func launch(s: String) -> void:
	var toks := tokens(s)
	for i in toks.size():
		var t: Dictionary = toks[i]
		var type: String = t["type"]
		var n: int = t["n"]
		if float(t["fx"]) >= 0.0:
			var e := mk_enemy(type, BL + float(t["fx"]) * (BR - BL), BT + float(t["fy"]) * (BB - BT), n)
			e.st = 1
			E.append(e)
			ring_fx(e.x, e.y, TY_COL[type], e.r * 1.9, e.r, 20.0, 3.0)
			if type == "G":
				shake = 20.0
		else:
			var a := Arrival.new()
			a.type = type
			a.n = n
			a.t = 56 + i * 16
			a.r = ring_r(rings_of(type, n)) * float(TY_K[type])
			edge_spot(a.r, a)
			IN.append(a)


## The wall is the gong.
func gong_now(nx: float, ny: float) -> void:
	var r := R
	var p := P
	if mode == "endless":                # Endless: one more wall, nothing else to score
		EW += 1
		if EW > best_walls():
			save["endless"]["best"] = EW
		save["hints"]["gong"] = 1
		store()
		r.res = {"e": 1, "n": EW, "s": 0}
	else:
		var s := 1 | (0 if r.hurt else 2) | (4 if r.best >= ceili(r.popped * 0.75) else 0)
		var rooms: Array = save["rooms"]
		while rooms.size() <= r.i:
			rooms.append(null)
		var sv := {"s": 0, "t": 0}
		if typeof(rooms[r.i]) == TYPE_DICTIONARY:
			sv = rooms[r.i]
		sv["s"] = int(sv.get("s", 0)) | s
		var old_t := int(sv.get("t", 0))
		sv["t"] = mini(old_t, r.t) if old_t > 0 else r.t
		rooms[r.i] = sv
		save["hints"]["gong"] = 1
		store()
		r.res = {"i": r.i, "s": s, "t": r.t, "best": r.best, "total": r.popped}
	freeze = 12
	shake = 32.0
	flash = 0.9
	slow = 0.3
	slowT = 46
	buzz(70)
	hint_t = 0
	ring_fx(p.x, p.y, C_AMBER, 12.0, maxf(W, H) * 1.1, 70.0, 12.0)
	ring_fx(p.x, p.y, C_PAPER, 12.0, maxf(W, H) * 0.6, 40.0, 6.0)
	var hit := 0 if nx > 0.0 else (1 if nx < 0.0 else (2 if ny > 0.0 else 3))
	for k in 46:                         # the struck wall goes first
		var u := rnd()
		var side := hit if k < 22 else int(rnd() * 4.0)
		var x := 0.0 if side == 0 else (W if side == 1 else u * W)
		var y := 0.0 if side == 2 else (H if side == 3 else u * H)
		var ax := -1.0 if side == 0 else (1.0 if side == 1 else 0.0)
		var ay := -1.0 if side == 2 else (1.0 if side == 3 else 0.0)
		var svx := ax * rr(2.0, 9.0) + rr(-2.0, 2.0)
		var svy := ay * rr(2.0, 9.0) + rr(-2.0, 2.0)
		shard(x, y, svx, svy, C_AMBER)
	if mode == "endless" or r.i + 1 < ROOMS.size():
		view.gong_hit = hit
		start_room(r.i + 1, true)
	else:                                # the last wall: nothing left to hold it
		r.fin = 1
		r.cleared = false
		BL = -1e7
		BT = -1e7
		BR = 1e7
		BB = 1e7
		IN.clear()
		p.over = 0
		var v := hyp(p.vx, p.vy)
		if v == 0.0:
			v = 1.0
		var dx := p.vx / v
		var dy := p.vy / v
		p.vx = dx * CAP
		p.vy = dy * CAP
		r.sky.clear()
		for k in 150:
			var a := rr(-2500.0, 6500.0)
			var b := rr(-4500.0, 4500.0)
			r.sky.append(Vector2(p.x + dx * a - dy * b, p.y + dy * a + dx * b))
		view.clear_debris()


func hint_tick() -> void:
	var p := P
	var r := R
	if hint_t > 0:
		hint_t -= 1
	if r.i == 0 and mode == "rooms":
		if hint_s == "Drag" and hint_t > 0 and p.moved > 260.0:
			save["hints"]["drag"] = 1
			hint_t = 0
		if not hint_seen("glow") and p.top:
			save["hints"]["glow"] = 1
			word(p.x, p.y - p.r - 22.0, "Glow!", C_AMBER, 22.0, 50)
		if not hint_seen("pop") and r.popped > 0:
			save["hints"]["pop"] = 1
			store()
			say("Pop them all", 170)


# ---------------------------------------------------------------- screens and flow (ui.js)

func show_screen(id: String) -> void:
	ui.show_screen(id)


func begin_endless() -> void:
	mode = "endless"
	EW = 0
	EB0 = best_walls()
	start(ROOMS.size())


func begin(i: int) -> void:
	mode = "rooms"
	start(i)


func begin_yard() -> void:
	mode = "yard"
	start(50)


func replay() -> void:
	if mode == "endless":
		begin_endless()
	elif mode == "yard":
		begin_yard()
	else:
		begin(R.i)


func start(i: int) -> void:
	seed32 = _i32(int(Time.get_unix_time_from_system() * 1000.0) ^ (i * 7919))
	state = "play"
	slow = 1.0
	slowT = 0
	freeze = 0
	shake = 0.0
	flash = 0.0
	sacc = 0.0
	inp_down = false
	inp_sup = false
	inp_pid2 = -1
	start_room(i, false)
	show_screen("")


func pause_game() -> void:
	if state != "play" or R.fin > 0:
		return
	state = "pause"
	inp_down = false
	show_screen("pause")


func resume_game() -> void:
	if state != "pause":
		return
	state = "play"
	show_screen("")


func open_rooms() -> void:
	state = "title"
	show_screen("rooms")


func go_title() -> void:
	state = "title"
	show_screen("title")


## One tick of the game, 60 of them a second.
func update() -> void:
	if freeze > 0:
		freeze -= 1
		return
	tick += 1
	if inp_sup:
		inp_sup = false
		if not P.dead and R.fin == 0 and R.intro <= 0:
			fire_super()
	room_tick()
	if state != "play" and state != "end":
		return
	if not P.dead:
		player_tick()
	enemies_tick()
	if not P.dead and R.fin == 0:
		squeeze_tick()
	fx_tick()
	hint_tick()
	if P.dead:
		R.deadT -= 1
		if R.deadT <= 0:
			state = "dead"
			show_screen("dead")


func _physics_process(_delta: float) -> void:
	if state != "play" and state != "end":
		return
	if test_mode != "":
		_test_tick()
	if slowT > 0:
		slowT -= 1
		if slowT == 0:
			slow = 1.0
	sacc += slow * slowmo
	while sacc >= 1.0 and (state == "play" or state == "end"):
		sacc -= 1.0
		update()


func _process(delta: float) -> void:
	gt += delta * 60.0 * slowmo
	if R == null or state == "title":
		return
	draw_sx = (randf() - 0.5) * shake
	draw_sy = (randf() - 0.5) * shake
	var mx := W / 2.0
	var my := H / 2.0
	var fy := 0.5
	if R.fin > 0:                        # the last shot: halfway between the rooms and the comet
		var q := ease3(minf(1.0, R.fin / 50.0))
		mx = lerpf(mx, (mx + P.x) / 2.0, q)
		my = lerpf(my, (my + P.y) / 2.0, q)
		fy = lerpf(0.5, 0.36, q)
	OX = fr_x + fr_w / 2.0 - mx * cam
	OY = fr_y + fr_h * fy - my * cam


# ---------------------------------------------------------------- input: one thumb

func pointer_down(pid: int, x: float, y: float, is_touch: bool) -> void:
	if state != "play":
		return
	if inp_down and pid != inp_pid:      # a second finger waits: it fires Super if it lifts first, and steers if the first thumb lifts first
		inp_pid2 = pid
		inp_sx2 = x
		inp_sy2 = y
		return
	var now := Time.get_ticks_msec()
	if now - tap_t < 300 and hyp(x - tap_x, y - tap_y) < 60.0:
		inp_sup = true                   # double-tap
	tap_t = now
	tap_x = x
	tap_y = y
	inp_down = true
	inp_pid2 = -1
	inp_touch = is_touch
	inp_pid = pid
	inp_sx = x
	inp_sy = y


func pointer_move(pid: int, x: float, y: float) -> void:
	if not inp_down:
		return
	if pid == inp_pid:
		inp_sx = x
		inp_sy = y
	elif pid == inp_pid2:
		inp_sx2 = x
		inp_sy2 = y


func pointer_up(pid: int, cancelled: bool) -> void:
	if pid == inp_pid2 and inp_pid2 != -1:
		inp_pid2 = -1
		if not cancelled:
			inp_sup = true               # a tap with a second finger: Super
		return
	if pid != inp_pid:
		return
	if inp_pid2 != -1:                   # changing thumbs: the one still on the glass steers
		inp_pid = inp_pid2
		inp_sx = inp_sx2
		inp_sy = inp_sy2
		inp_pid2 = -1
	else:
		inp_down = false


func _unhandled_input(event: InputEvent) -> void:
	if test_mode != "":
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			pointer_down(event.index, event.position.x, event.position.y, true)
		else:
			pointer_up(event.index, event.canceled)
	elif event is InputEventScreenDrag:
		pointer_move(event.index, event.position.x, event.position.y)
	elif event is InputEventMouseButton:
		if event.device == InputEvent.DEVICE_ID_EMULATION or event.button_index != MOUSE_BUTTON_LEFT:
			return
		if event.pressed:
			pointer_down(MOUSE_PID, event.position.x, event.position.y, false)
		else:
			pointer_up(MOUSE_PID, false)
	elif event is InputEventMouseMotion:
		if event.device != InputEvent.DEVICE_ID_EMULATION:
			pointer_move(MOUSE_PID, event.position.x, event.position.y)
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_SPACE:
				if state == "play":
					inp_sup = true
			KEY_ESCAPE, KEY_P:
				if state == "play":
					pause_game()
				else:
					resume_game()
			KEY_R:
				if R != null and (state == "play" or state == "dead"):
					replay()
			KEY_ENTER:
				if R != null and state == "dead":
					replay()
			KEY_1:
				slowmo = 0.1 if slowmo == 1.0 else 1.0
			KEY_F2:
				all_open = not all_open
				if state == "title":
					show_screen(ui.current)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED:
		if state == "play":
			pause_game()
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		inp_down = false


# ---------------------------------------------------------------- test hooks (command line only)
# godot --path . -- --autopilot=3     plays room 4 by itself, for looking at a build with no hands on it
# godot --path . -- --trace           prints the comet and the enemies tick by tick, to compare with the web build

func _start_test() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--autopilot"):
			test_mode = "auto"
			var parts := a.split("=")
			var which := parts[1] if parts.size() > 1 else "0"
			all_open = true
			if which == "yard":
				begin_yard()
			elif which == "endless":
				begin_endless()
			else:
				begin(int(which))
		elif a.begins_with("--trace"):
			test_mode = "trace"
			var parts := a.split("=")
			begin(int(parts[1]) if parts.size() > 1 else 1)
			seed32 = 12345
			test_has_aim = true


func _test_tick() -> void:
	test_n += 1
	if test_mode == "auto":
		inp_down = test_n % 300 < 250
		inp_touch = false
		var a := test_n * 0.085
		inp_sx = OX + (W / 2.0 + cos(a) * W * 0.75) * cam
		inp_sy = OY + (H / 2.0 + sin(a * 0.63) * H * 0.5) * cam
		if P != null and P.ready and test_n % 90 == 0:
			inp_sup = true
		if state == "play" and P != null and P.dead:
			pass
	elif test_mode == "trace":
		var n := tick
		inp_down = n % 200 < 160
		if P.ready and n % 90 == 0:
			inp_sup = true
		var a := n * 0.07
		test_ax = W / 2.0 + cos(a) * W * 0.6
		test_ay = H / 2.0 + sin(a * 0.8) * H * 0.45
		if n % 20 == 0 and n != test_last:
			test_last = n
			var line := "T %d %.6f %.6f %.6f %.6f h%d d%d E%d" % [n, P.x, P.y, P.vx, P.vy, P.hearts, P.dust, E.size()]
			for e in E:
				line += " | %s%d %.4f %.4f" % [e.type, e.n, e.x, e.y]
			print(line)
		if n >= 3000:
			get_tree().quit()
