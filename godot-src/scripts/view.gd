extends Node3D
## The 3D picture. Clay pucks on a slate floor, a cream ball, pieces that break off and stay.
## Nothing in here decides anything: it only shows what game.gd says, plus loose debris,
## which is the one place Godot's physics engine is used.
##
## The camera looks straight down, so a point on the floor is exactly where the thumb is.
## Everything is leaned toward the viewer by LEAN (an oblique view) so the pucks show their sides.

var g

const U := 0.01                 # one game unit = 1 cm
const LEAN := 0.5               # how far a thing's height slides up the screen
const WALL_H := 10.0
const MAX_DEBRIS := 140
const DEBRIS_LIFE := 2.2        # seconds a broken piece lies there
const DEBRIS_FADE := 0.5        # then it shrinks away over this long

const C_FLOOR_OUT := Color("1c282e")
const C_CREAM := Color("efe6d0")
const C_GROOVE := Color(0.16, 0.07, 0.06)
const C_BAND := Color("e9dcc0")
const C_ROCK := Color("6d8089")
const C_WOOD := Color("b98a5a")
const C_BREAK := Color("ecd9b8")   # the pale inside of a broken piece

var gong_hit := -1

var root: Node3D                # leaned; everything you see hangs here
var phys: Node3D                # not leaned; the debris bodies live here
var camera: Camera3D
var sun: DirectionalLight3D
var floor_mi: MeshInstance3D
var floor_mat: ShaderMaterial
var wall_mi: Array[MeshInstance3D] = []
var wall_mat: StandardMaterial3D
var wall_body: Array[StaticBody3D] = []
var wall_key := ""
var comet: MeshInstance3D
var comet_mat: StandardMaterial3D
var lamp: OmniLight3D
var tail_im: ImmediateMesh
var dust_mm: MultiMesh
var pusher: AnimatableBody3D
var eviews := {}                # enemy id -> Dictionary of nodes
var sviews := {}                # stone instance id -> Node3D
var debris: Array = []          # [RigidBody3D, MeshInstance3D]
var mats := {}                  # colour -> shared material

var m_puck: CylinderMesh
var m_ring: TorusMesh
var m_ball: SphereMesh
var m_cone: CylinderMesh
var m_box: BoxMesh
var m_rock: SphereMesh
var mat_groove: StandardMaterial3D
var mat_band: StandardMaterial3D
var mat_eye: StandardMaterial3D
var mat_debris: StandardMaterial3D

const FLOOR_SHADER := """
shader_type spatial;
uniform vec3 ink : source_color;
uniform vec3 grid : source_color;
uniform vec2 centre;
uniform float cell = 0.56;
varying vec3 wp;
void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	vec2 q = abs(fract((wp.xz - centre) / cell + 0.5) - 0.5) * cell;
	float line = 1.0 - smoothstep(0.003, 0.008, min(q.x, q.y));
	ALBEDO = mix(ink, grid, line * 0.4);
	ROUGHNESS = 1.0;
	SPECULAR = 0.1;
}
"""


func _ready() -> void:
	_meshes()
	_scene()


func _mat(col: Color, rough: float = 0.9) -> StandardMaterial3D:
	var key := col.to_html()
	if mats.has(key):
		return mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	m.metallic_specular = 0.2
	mats[key] = m
	return m


func _meshes() -> void:
	m_puck = CylinderMesh.new()
	m_puck.top_radius = 0.965
	m_puck.bottom_radius = 1.0
	m_puck.height = 1.0
	m_puck.radial_segments = 48
	m_puck.rings = 1
	m_ring = TorusMesh.new()
	m_ring.inner_radius = 0.955
	m_ring.outer_radius = 1.0
	m_ring.rings = 48
	m_ring.ring_segments = 6
	m_ball = SphereMesh.new()
	m_ball.radius = 1.0
	m_ball.height = 2.0
	m_ball.radial_segments = 32
	m_ball.rings = 16
	m_cone = CylinderMesh.new()
	m_cone.top_radius = 0.0
	m_cone.bottom_radius = 1.0
	m_cone.height = 1.0
	m_cone.radial_segments = 10
	m_cone.rings = 1
	m_box = BoxMesh.new()
	m_rock = SphereMesh.new()
	m_rock.radius = 1.0
	m_rock.height = 2.0
	m_rock.radial_segments = 7
	m_rock.rings = 4
	mat_groove = StandardMaterial3D.new()
	mat_groove.albedo_color = C_GROOVE
	mat_groove.roughness = 1.0
	mat_groove.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_groove.albedo_color.a = 0.42
	mat_band = _mat(C_BAND)
	mat_eye = StandardMaterial3D.new()
	mat_eye.albedo_color = Color(0.1, 0.06, 0.06)
	mat_eye.roughness = 0.6
	mat_debris = StandardMaterial3D.new()
	mat_debris.vertex_color_use_as_albedo = true
	mat_debris.roughness = 0.95
	mat_debris.cull_mode = BaseMaterial3D.CULL_DISABLED


func _scene() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = C_FLOOR_OUT
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.92, 0.94, 0.94)
	env.ambient_light_energy = 0.34
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-56.0, -135.0, 0.0)     # light from the upper left: shadows fall down and to the right
	sun.light_color = Color(1.0, 0.95, 0.88)
	sun.light_energy = 0.64
	sun.shadow_enabled = true
	sun.shadow_blur = 2.2
	sun.shadow_opacity = 0.8
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 40.0
	add_child(sun)

	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	camera.near = 0.1
	camera.far = 60.0
	add_child(camera)

	root = Node3D.new()
	root.transform = Transform3D(Basis(Vector3(1, 0, 0), Vector3(0, 1, -LEAN), Vector3(0, 0, 1)), Vector3.ZERO)
	add_child(root)
	phys = Node3D.new()
	add_child(phys)

	floor_mi = MeshInstance3D.new()
	floor_mi.mesh = PlaneMesh.new()
	var sh := Shader.new()
	sh.code = FLOOR_SHADER
	floor_mat = ShaderMaterial.new()
	floor_mat.shader = sh
	floor_mi.material_override = floor_mat
	floor_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(floor_mi)

	wall_mat = StandardMaterial3D.new()
	wall_mat.roughness = 0.95
	wall_mat.emission_enabled = true
	wall_mat.emission_energy_multiplier = 0.0
	for i in 4:
		var w := MeshInstance3D.new()
		w.mesh = BoxMesh.new()
		w.material_override = wall_mat
		root.add_child(w)
		wall_mi.append(w)
		var sb := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		cs.shape = BoxShape3D.new()
		sb.add_child(cs)
		phys.add_child(sb)
		wall_body.append(sb)

	var ground := StaticBody3D.new()
	var gs := CollisionShape3D.new()
	gs.shape = WorldBoundaryShape3D.new()
	ground.add_child(gs)
	var pm := PhysicsMaterial.new()
	pm.friction = 0.9
	pm.bounce = 0.1
	ground.physics_material_override = pm
	phys.add_child(ground)

	pusher = AnimatableBody3D.new()
	pusher.sync_to_physics = false
	var ps := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 18.0 * U
	ps.shape = sph
	pusher.add_child(ps)
	phys.add_child(pusher)

	comet = MeshInstance3D.new()
	comet.mesh = m_ball
	comet_mat = StandardMaterial3D.new()
	comet_mat.albedo_color = C_CREAM
	comet_mat.roughness = 0.7
	comet_mat.emission_enabled = true
	comet_mat.emission_energy_multiplier = 0.0
	comet.material_override = comet_mat
	root.add_child(comet)

	lamp = OmniLight3D.new()
	lamp.omni_range = 1.9
	lamp.light_energy = 0.0
	root.add_child(lamp)

	tail_im = ImmediateMesh.new()
	var tm := MeshInstance3D.new()
	tm.mesh = tail_im
	var tmat := StandardMaterial3D.new()
	tmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tmat.vertex_color_use_as_albedo = true
	tmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	tmat.cull_mode = BaseMaterial3D.CULL_DISABLED
	tm.material_override = tmat
	tm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(tm)

	dust_mm = MultiMesh.new()
	dust_mm.transform_format = MultiMesh.TRANSFORM_3D
	var db := BoxMesh.new()
	db.size = Vector3.ONE
	dust_mm.mesh = db
	dust_mm.instance_count = 170
	dust_mm.visible_instance_count = 0
	var dm := MultiMeshInstance3D.new()
	dm.multimesh = dust_mm
	var dmat := StandardMaterial3D.new()
	dmat.albedo_color = Color("f2c84b")
	dmat.emission_enabled = true
	dmat.emission = Color("f2c84b")
	dmat.emission_energy_multiplier = 0.35
	dm.material_override = dmat
	dm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(dm)


# ---------------------------------------------------------------- every drawn frame

func _process(delta: float) -> void:
	var on: bool = g.R != null and g.state != "title"
	visible = on
	if not on:
		return
	var R = g.R
	var P = g.P
	var cam: float = g.cam
	var cx: float = (g.VW / 2.0 - g.OX - g.draw_sx) / cam
	var cy: float = (g.VH / 2.0 - g.OY - g.draw_sy) / cam
	camera.position = Vector3(cx * U, 20.0, cy * U)
	camera.size = g.VH / cam * U

	var fin: bool = R.fin > 0
	floor_mi.visible = not fin
	for w in wall_mi:
		w.visible = not fin
	if not fin:
		(floor_mi.mesh as PlaneMesh).size = Vector2(g.W * U, g.H * U)
		floor_mi.position = Vector3(g.W / 2.0 * U, 0.0, g.H / 2.0 * U)
		floor_mat.set_shader_parameter("ink", R.ink)
		floor_mat.set_shader_parameter("grid", R.grid)
		floor_mat.set_shader_parameter("centre", Vector2(g.W / 2.0 * U, g.H / 2.0 * U))
		_walls(R)
	_comet(P, R)
	_tail(P, R)
	_enemies(P)
	_stones()
	_dust()
	var aging: bool = g.state == "play" or g.state == "end"
	var i := debris.size() - 1
	while i >= 0:                    # pieces lie there a moment, then shrink away
		var body: RigidBody3D = debris[i][0]
		var bp := body.position
		if aging:
			debris[i][2] += delta * g.slowmo
		var age: float = debris[i][2]
		var out: bool = bp.x < -0.5 or bp.z < -0.5 or bp.x > g.W * U + 0.5 or bp.z > g.H * U + 0.5 or bp.y < -1.0
		if age >= DEBRIS_LIFE + DEBRIS_FADE or (out and not fin):
			body.queue_free()
			debris[i][1].queue_free()
			debris.remove_at(i)
		else:
			var xf := body.transform
			if age > DEBRIS_LIFE:
				var k := 1.0 - (age - DEBRIS_LIFE) / DEBRIS_FADE
				xf.basis = xf.basis.scaled(Vector3(k, k, k))
			debris[i][1].transform = xf
		i -= 1


func _physics_process(_delta: float) -> void:
	if g.P != null and g.R != null:
		pusher.position = Vector3(g.P.x * U, 18.0 * U, g.P.y * U)


func _walls(R) -> void:
	var t := 14.0
	var bl: float = g.BL
	var bt: float = g.BT
	var br: float = g.BR
	var bb: float = g.BB
	# left, right, top, bottom. A closing wall grows into a slab.
	var rects := [Rect2(-t, -t, bl + t, g.H + 2.0 * t), Rect2(br, -t, g.W - br + t, g.H + 2.0 * t),
		Rect2(bl, -t, br - bl, bt + t), Rect2(bl, bb, br - bl, g.H - bb + t)]
	var key := "%.1f %.1f %.1f %.1f" % [bl, bt, g.W, g.H]
	for i in 4:
		var rc: Rect2 = rects[i]
		(wall_mi[i].mesh as BoxMesh).size = Vector3(rc.size.x * U, WALL_H * U, rc.size.y * U)
		wall_mi[i].position = Vector3((rc.position.x + rc.size.x / 2.0) * U, WALL_H * U / 2.0, (rc.position.y + rc.size.y / 2.0) * U)
		if key != wall_key:
			var cs: CollisionShape3D = wall_body[i].get_child(0)
			(cs.shape as BoxShape3D).size = Vector3(rc.size.x * U, 1.2, rc.size.y * U)
			wall_body[i].position = Vector3((rc.position.x + rc.size.x / 2.0) * U, 0.6, (rc.position.y + rc.size.y / 2.0) * U)
	wall_key = key
	if R.cleared:                    # gold: ring it
		var pu := 0.5 + 0.5 * sin(g.gt * 0.16)
		wall_mat.albedo_color = g.C_AMBER
		wall_mat.emission = g.C_AMBER
		wall_mat.emission_energy_multiplier = 0.5 + 0.9 * pu
	else:
		wall_mat.albedo_color = R.wall
		wall_mat.emission_energy_multiplier = 0.0


func _comet(P, R) -> void:
	comet.visible = not P.dead
	lamp.visible = not P.dead
	if P.dead:
		return
	var fk: float = R.c1 / g.cam if R.fin > 0 else 1.0      # it keeps its size on screen while the camera pulls away
	var q: float = P.squish if P.squish > 0.02 else 0.0
	var b := 1.0
	if q > 0.0:                      # squeezed: it swells toward you
		b = 1.0 + 0.5 * q + 0.12 * q * sin(g.gt * (0.25 + 0.55 * q))
	var r: float = P.r * fk * b
	comet.position = Vector3(P.x * U, (r + 16.0 * q) * U, P.y * U)
	comet.scale = Vector3.ONE * r * U
	var blink: bool = P.inv > 0 and (g.tick & 4) != 0
	var base: Color = g.C_GREEN if P.ready else C_CREAM
	comet_mat.albedo_color = base.darkened(0.45) if blink else base
	var v: float = g.hyp(P.vx, P.vy)
	var k := clampf(v / g.CAP, 0.0, 1.0)
	lamp.position = Vector3(P.x * U, (P.r * 1.6) * U, P.y * U)
	if P.top:
		var hot := Color.from_hsv(fmod(g.gt * 9.0, 360.0) / 360.0, 0.4, 1.0)
		comet_mat.emission = hot
		comet_mat.emission_energy_multiplier = 0.9
		lamp.light_color = hot
		lamp.light_energy = 1.3 + sin(g.gt * 0.4) * 0.15
	else:
		comet_mat.emission = base
		comet_mat.emission_energy_multiplier = 0.25 if P.ready else 0.05
		lamp.light_color = base
		lamp.light_energy = k * k * 0.9


## The tail: one ribbon that narrows to nothing. It lies on the floor.
func _tail(P, R) -> void:
	tail_im.clear_surfaces()
	if P.dead:
		return
	var tr: PackedVector2Array = P.tr
	var n := tr.size()
	if n < 2:
		return
	var fk: float = R.c1 / g.cam if R.fin > 0 else 1.0
	var started := false
	var y := 2.0 * U
	for i in range(1, n):
		var p0 := tr[i - 1]
		var p1 := tr[i]
		var d := p0.distance_to(p1)
		if d < 0.05:
			continue
		if not started:
			tail_im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
			started = true
		var nrm := Vector2(-(p1.y - p0.y) / d, (p1.x - p0.x) / d)
		var w0: float = P.r * 0.5 * float(i - 1) / float(n) * fk
		var w1: float = P.r * 0.5 * float(i) / float(n) * fk
		var col := C_CREAM
		if P.top:
			col = Color.from_hsv(fmod(i * 13.0 + g.gt * 9.0, 360.0) / 360.0, 0.6, 1.0)
		col.a = float(i) / float(n) * (0.8 if P.top else 0.5)
		var a := _v(p0 + nrm * w0, y)
		var b := _v(p1 + nrm * w1, y)
		var c := _v(p1 - nrm * w1, y)
		var e := _v(p0 - nrm * w0, y)
		for vtx: Vector3 in [a, b, c, a, c, e]:
			tail_im.surface_set_color(col)
			tail_im.surface_add_vertex(vtx)
	if started:
		tail_im.surface_end()


func _v(p: Vector2, y: float) -> Vector3:
	return Vector3(p.x * U, y, p.y * U)


# ---------------------------------------------------------------- enemies: clay pucks

func puck_h(br: float) -> float:
	return clampf(br * 0.42, 9.0, 36.0)


func _mi(mesh: Mesh, mat: Material, parent: Node3D, shadow: bool = false) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = mat
	if not shadow:
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(m)
	return m


func _new_eview(e) -> Dictionary:
	var node := Node3D.new()
	root.add_child(node)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = g.TY_COL[e.type]
	mat.roughness = 0.92
	mat.metallic_specular = 0.15
	var v := {"node": node, "mat": mat, "body": _mi(m_puck, mat, node, true), "rings": [], "bands": [], "eyes": [], "extra": []}
	for k in 2:
		v["eyes"].append(_mi(m_ball, mat_eye, node))
	if e.type == "p":
		for k in 12:
			v["extra"].append(_mi(m_cone, mat, node, true))
	elif e.type == "d":
		v["extra"].append(_mi(m_cone, mat, node, true))
	elif e.type == "h":
		for k in 7:
			v["extra"].append(_mi(m_box, mat_band, node, true))
	elif e.type == "s":
		v["extra"].append(_mi(m_box, mat_groove, node))
	return v


func _enemies(P) -> void:
	var seen := {}
	for e in g.E:
		seen[e.id] = true
		if not eviews.has(e.id):
			eviews[e.id] = _new_eview(e)
		_enemy(eviews[e.id], e, P)
	for id in eviews.keys():
		if not seen.has(id):
			eviews[id]["node"].queue_free()
			eviews.erase(id)


func _enemy(v: Dictionary, e, P) -> void:
	var node: Node3D = v["node"]
	var age: int = g.tick - e.born
	var sc: float = g.ease3(age / 14.0) if age < 14 else 1.0
	var r: float = e.r * (1.0 + e.pulse * 0.14)
	var wob := 1.0 + sin((g.tick + e.ph) * 0.12) * 0.035
	var jx := (randf() - 0.5) * 4.0 if (e.type == "d" and e.mode == 1) else 0.0
	node.position = Vector3((e.x + jx) * U, 0.0, e.y * U)
	node.scale = Vector3(sc * wob, sc, sc / wob)
	var br := r
	var tip := r
	if e.type == "p":
		var big: bool = e.mode == 2
		tip = r if big else r * 1.1
		br = r * 0.7 if big else r * 0.94
	var h := puck_h(br)
	var body: MeshInstance3D = v["body"]
	body.scale = Vector3(br * U, h * U, br * U)
	body.position = Vector3(0.0, h * U / 2.0, 0.0)
	var mat: StandardMaterial3D = v["mat"]
	var col: Color = g.TY_COL[e.type]
	if e.type == "p" and e.mode == 1 and (int(g.gt) & 4) != 0:
		col = C_CREAM                    # about to puff: it flashes
	mat.albedo_color = col
	var top := (h + 0.3) * U

	# rings: one engraved line per ring of size
	var rings: Array = v["rings"]
	var want: int = e.n - 1 if e.am == 0 else 0
	while rings.size() < want:
		rings.append(_mi(m_ring, mat_groove, node))
	for k in rings.size():
		var ring: MeshInstance3D = rings[k]
		ring.visible = k < want
		if k < want:
			var rr: float = br * 0.965 * g.ring_r(k + 1) / g.ring_r(e.n)
			ring.scale = Vector3(rr * U, 0.02, rr * U)
			ring.position = Vector3(0.0, top, 0.0)

	# armour: pale raised bands, one per hit left
	var bands: Array = v["bands"]
	var nb: int = e.armor
	if nb == 0 and e.type == "b" and e.n >= g.TOUGH and not e.cut:
		nb = 1
	while bands.size() < nb:
		bands.append(_mi(m_ring, mat_band, node))
	for k in bands.size():
		var band: MeshInstance3D = bands[k]
		band.visible = k < nb
		if k < nb:
			var rb: float = br - 5.0 - k * 8.0
			band.scale = Vector3(rb * U, 0.09, rb * U)
			band.position = Vector3(0.0, top, 0.0)

	# eyes: two dark ovals, on the side of the puck that faces the comet
	var dx: float = P.x - e.x
	var dy: float = P.y - e.y
	var d: float = g.hyp(dx, dy)
	if d == 0.0:
		d = 1.0
	dx /= d
	dy /= d
	var f := clampf(br * 0.5, 10.0, 30.0)
	var er := f * 0.3
	var scared: bool = e.fear > 0.3
	var out: bool = e.stun > 0 or (e.type == "d" and e.mode == 3)
	var asleep: bool = e.type == "z"
	var ecx := dx * br * 0.5
	var ecy := dy * br * 0.5
	var eyes: Array = v["eyes"]
	for k in 2:
		var s := -1.0 if k == 0 else 1.0
		var eye: MeshInstance3D = eyes[k]
		var px := ecx - dy * s * f * 0.42
		var py := ecy + dx * s * f * 0.42
		eye.position = Vector3(px * U, top, py * U)
		var facing := atan2(dy, dx)
		if asleep:                       # closed
			eye.rotation = Vector3(0.0, -facing, 0.0)
			eye.scale = Vector3(er * 0.25 * U, 0.004, er * 1.1 * U)
		elif out:                        # knocked silly
			eye.rotation = Vector3(0.0, -facing + s * 0.8, 0.0)
			eye.scale = Vector3(er * 1.2 * U, 0.004, er * 0.28 * U)
		elif scared:                     # wide
			eye.rotation = Vector3(0.0, -facing, 0.0)
			eye.scale = Vector3(er * 1.15 * U, 0.004, er * 1.15 * U)
		else:
			eye.rotation = Vector3(0.0, -facing, 0.0)
			eye.scale = Vector3(er * U, 0.004, er * 0.72 * U)

	var extra: Array = v["extra"]
	if e.type == "p":                    # puffer: nubs, or real spikes
		var base := br * 0.82
		var ln := maxf(1.0, tip - base)
		for k in 12:
			var a: float = k * TAU / 12.0 + e.ph
			_radial(extra[k], a, base + ln / 2.0, ln, br * 0.2, h * 0.42, h * 0.5)
	elif e.type == "d":                  # dasher: a nose that points where it will go
		var a: float = atan2(dy, dx) if (e.mode == 0 or (e.mode == 1 and e.mt > 16)) else atan2(e.dy, e.dx)
		_radial(extra[0], a, r * 0.95, r * 1.1, r * 0.7, h * 0.5, h * 0.5)
	elif e.type == "h":                  # shield: a pale wall on the side it guards
		for k in 7:
			var a: float = e.ang - 1.13 + 2.26 * k / 6.0
			var seg: MeshInstance3D = extra[k]
			var rad := br + 5.0
			seg.position = Vector3(cos(a) * rad * U, (h + 5.0) * U / 2.0, sin(a) * rad * U)
			seg.rotation = Vector3(0.0, -a, 0.0)
			seg.scale = Vector3(7.0 * U, (h + 5.0) * U, rad * 2.26 / 6.0 * 1.12 * U)
	elif e.type == "s":                  # splitter: a crack across the top
		var crack: MeshInstance3D = extra[0]
		crack.position = Vector3(0.0, top, 0.0)
		crack.scale = Vector3(2.4 * U, 0.004, br * 1.9 * U)


## Lays a cone on its side, pointing outward at angle a.
func _radial(m: MeshInstance3D, a: float, dist: float, length: float, half_w: float, half_h: float, y: float) -> void:
	var dir := Vector3(cos(a), 0.0, sin(a))
	var side := Vector3(-sin(a), 0.0, cos(a))
	m.transform = Transform3D(Basis(side * half_w * U, dir * length * U, Vector3(0, half_h * U, 0)), Vector3(dir.x * dist * U, y * U, dir.z * dist * U))


# ---------------------------------------------------------------- stones, planks, dust

func _stones() -> void:
	var seen := {}
	for s in g.ST:
		var id: int = s.get_instance_id()
		seen[id] = true
		if not sviews.has(id):
			var m: MeshInstance3D
			if s.plank:
				m = _mi(m_box, _mat(C_WOOD), root, true)
				m.scale = Vector3(18.0 * U, 30.0 * U, 6.0 * U)
				m.rotation = Vector3(0.0, -s.ang, randf_range(-0.05, 0.05))
			else:
				m = _mi(m_rock, _mat(C_ROCK), root, true)
				m.scale = Vector3(s.r * U, s.r * 0.62 * U, s.r * U)
				m.rotation = Vector3(0.0, randf() * TAU, 0.0)
			sviews[id] = m
		var node: MeshInstance3D = sviews[id]
		node.position = Vector3(s.x * U, (15.0 if s.plank else s.r * 0.3) * U, s.y * U)
	for id in sviews.keys():
		if not seen.has(id):
			sviews[id].queue_free()
			sviews.erase(id)


func _dust() -> void:
	var n: int = mini(g.DU.size(), 170)
	dust_mm.visible_instance_count = n
	for i in n:
		var d = g.DU[i]
		var z := (3.2 + sin((d.t + d.x) * 0.3)) * 1.25 * U
		var b := Basis(Vector3.UP, d.t * 0.2).scaled(Vector3(z, z, z))
		dust_mm.set_instance_transform(i, Transform3D(b, Vector3(d.x * U, 5.0 * U, d.y * U)))


# ---------------------------------------------------------------- debris: broken pieces, which lie there a moment

func clear_debris() -> void:
	for d in debris:
		d[0].queue_free()
		d[1].queue_free()
	debris.clear()


func on_room(carry: bool, ox: float, oy: float, old_rect: Rect2) -> void:
	wall_key = ""
	if not carry:
		clear_debris()
		return
	var shift := Vector3(ox * U, 0.0, oy * U)      # the old room now sits inside the new one
	for d in debris:
		var body: RigidBody3D = d[0]
		var xf := body.global_transform
		xf.origin += shift
		PhysicsServer3D.body_set_state(body.get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM, xf)
	if gong_hit >= 0:                              # the wall you rang breaks outward
		var col: Color = g.R.wall
		for k in 20:
			var u := randf()
			var x := old_rect.position.x + (0.0 if gong_hit == 0 else (old_rect.size.x if gong_hit == 1 else u * old_rect.size.x))
			var y := old_rect.position.y + (0.0 if gong_hit == 2 else (old_rect.size.y if gong_hit == 3 else u * old_rect.size.y))
			var ax := -1.0 if gong_hit == 0 else (1.0 if gong_hit == 1 else 0.0)
			var ay := -1.0 if gong_hit == 2 else (1.0 if gong_hit == 3 else 0.0)
			_chunk(x, y, 6.0, Vector3(randf_range(8, 18), randf_range(6, 11), randf_range(8, 18)),
				Vector3(ax * randf_range(2, 7) + randf_range(-1.5, 1.5), randf_range(1.5, 4.5), ay * randf_range(2, 7) + randf_range(-1.5, 1.5)), col, col)
	gong_hit = -1


func _add(body: RigidBody3D, mesh: Mesh, mat: Material) -> void:
	var pm := PhysicsMaterial.new()
	pm.friction = 0.85
	pm.bounce = 0.18
	body.physics_material_override = pm
	body.linear_damp = 0.7
	body.angular_damp = 1.4
	phys.add_child(body)
	var vis := MeshInstance3D.new()
	vis.mesh = mesh
	vis.material_override = mat
	vis.transform = body.transform
	root.add_child(vis)
	debris.append([body, vis, 0.0])
	while debris.size() > MAX_DEBRIS:
		var old: Array = debris.pop_front()
		old[0].queue_free()
		old[1].queue_free()


## A loose block. Sizes in game units, velocity in metres per second.
func _chunk(x: float, y: float, height: float, size: Vector3, vel: Vector3, col: Color, _inner: Color) -> void:
	var body := RigidBody3D.new()
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size * U
	cs.shape = box
	body.add_child(cs)
	body.mass = maxf(0.05, size.x * size.y * size.z * 0.0004)
	body.position = Vector3(x * U, height * U, y * U)
	body.rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)
	body.linear_velocity = vel
	body.angular_velocity = Vector3(randf_range(-9, 9), randf_range(-9, 9), randf_range(-9, 9))
	var bm := BoxMesh.new()
	bm.size = size * U
	_add(body, bm, _mat(col))


## Generic burst. vx,vy are the comet's speed in game units per tick. kind 1 = wood splinters.
func burst(x: float, y: float, vx: float, vy: float, col: Color, n: int, size: float, power: float, kind: int) -> void:
	for i in n:
		var a := randf() * TAU
		var sp := power * randf_range(0.3, 1.0)
		var vel := Vector3(vx * 0.3 + cos(a) * sp, randf_range(1.5, 4.0), vy * 0.3 + sin(a) * sp)
		var s := size * randf_range(0.45, 1.0)
		var dim := Vector3(s, s * randf_range(0.5, 0.9), s * randf_range(0.6, 1.0))
		var c := col
		if kind == 1:                    # wood splinters
			dim = Vector3(randf_range(3.0, 5.0), randf_range(12.0, 24.0), randf_range(3.0, 6.0))
		elif kind == 2:                  # rock
			c = C_ROCK.darkened(randf() * 0.15)
		_chunk(x + cos(a) * 4.0, y + sin(a) * 4.0, 8.0 + randf() * 8.0, dim, vel, c, c)


## A wall hit hard enough knocks chips off the wall.
func chips(x: float, y: float, nx: float, ny: float, vn: float) -> void:
	if vn < 12.0:
		return
	var col: Color = g.R.wall
	for i in 2:
		_chunk(x + nx * 8.0, y + ny * 8.0, WALL_H, Vector3.ONE * randf_range(2.5, 5.0),
			Vector3(nx * randf_range(0.5, 2.5) + randf_range(-1, 1), randf_range(1.0, 3.0), ny * randf_range(0.5, 2.5) + randf_range(-1, 1)) * (0.6 + vn / 30.0), col, col)


## A popped puck breaks into the arcs it was made of, plus crumbs.
func pop_puck(x: float, y: float, r: float, n: int, col: Color, vx: float, vy: float) -> void:
	var h := puck_h(r)
	var bands := clampi(n, 1, 3)
	var r_in := r * (0.0 if bands == 1 else 0.22)
	var a_off := randf() * TAU
	for b in bands:
		var r0 := lerpf(r_in, r, float(b) / bands)
		var r1 := lerpf(r_in, r, float(b + 1) / bands)
		var pieces := 3 + b + (1 if r > 40.0 else 0)
		if bands == 1:
			pieces = 4
			r0 = r * 0.28
		for k in pieces:
			var gap := 0.06
			var a0 := a_off + TAU * k / pieces + gap
			var a1 := a_off + TAU * (k + 1) / pieces - gap
			_arc(x, y, r0, r1, a0, a1, h, col, vx, vy)
	for k in 5:
		var a := randf() * TAU
		var s := randf_range(2.0, 4.5)
		_chunk(x + cos(a) * r * 0.5, y + sin(a) * r * 0.5, h, Vector3(s, s, s),
			Vector3(vx * 0.35 + cos(a) * randf_range(1, 4), randf_range(2, 5), vy * 0.35 + sin(a) * randf_range(1, 4)), col, col)


func _arc(x: float, y: float, r0: float, r1: float, a0: float, a1: float, h: float, col: Color, vx: float, vy: float) -> void:
	var mid := (a0 + a1) / 2.0
	var half := (a1 - a0) / 2.0
	var rc := (r0 + r1) / 2.0 * (sin(half) / half if half > 0.001 else 1.0)    # roughly the piece's centre
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var steps := maxi(2, int(ceil((a1 - a0) / 0.22)))
	var top := h / 2.0 * U
	var pts: Array = []                  # per step: inner xz, outer xz, in the piece's own frame (it points along +x)
	for i in steps + 1:
		var a := -half + (a1 - a0) * i / steps
		pts.append([Vector2((cos(a) * r0 - rc) * U, sin(a) * r0 * U), Vector2((cos(a) * r1 - rc) * U, sin(a) * r1 * U)])
	for i in steps:
		var i0: Vector2 = pts[i][0]
		var o0: Vector2 = pts[i][1]
		var i1: Vector2 = pts[i + 1][0]
		var o1: Vector2 = pts[i + 1][1]
		_quad(st, Vector3(i0.x, top, i0.y), Vector3(o0.x, top, o0.y), Vector3(o1.x, top, o1.y), Vector3(i1.x, top, i1.y), col)
		_quad(st, Vector3(i0.x, -top, i0.y), Vector3(i1.x, -top, i1.y), Vector3(o1.x, -top, o1.y), Vector3(o0.x, -top, o0.y), col.darkened(0.15))
		_quad(st, Vector3(o0.x, top, o0.y), Vector3(o0.x, -top, o0.y), Vector3(o1.x, -top, o1.y), Vector3(o1.x, top, o1.y), col.darkened(0.06))
		_quad(st, Vector3(i0.x, top, i0.y), Vector3(i1.x, top, i1.y), Vector3(i1.x, -top, i1.y), Vector3(i0.x, -top, i0.y), col.darkened(0.06))
	for e: int in [0, steps]:            # the two broken ends are pale inside
		var ii: Vector2 = pts[e][0]
		var oo: Vector2 = pts[e][1]
		_quad(st, Vector3(ii.x, top, ii.y), Vector3(ii.x, -top, ii.y), Vector3(oo.x, -top, oo.y), Vector3(oo.x, top, oo.y), C_BREAK)
	st.generate_normals()
	var mesh := st.commit()

	var body := RigidBody3D.new()
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(maxf(4.0, r1 - r0), h, maxf(4.0, 2.0 * sin(half) * rc)) * U
	cs.shape = box
	body.add_child(cs)
	body.mass = maxf(0.2, (r1 - r0) * h * rc * half * 0.002)
	body.position = Vector3((x + cos(mid) * rc) * U, (h / 2.0 + 2.0) * U, (y + sin(mid) * rc) * U)
	body.rotation = Vector3(0.0, -mid, 0.0)
	var out := randf_range(1.2, 3.2)
	body.linear_velocity = Vector3(vx * 0.42 + cos(mid) * out, randf_range(0.3, 1.2), vy * 0.42 + sin(mid) * out)
	body.angular_velocity = Vector3(randf_range(-0.8, 0.8), randf_range(-4, 4), randf_range(-0.8, 0.8))
	_add(body, mesh, mat_debris)


func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color) -> void:
	for v: Vector3 in [a, b, c, a, c, d]:
		st.set_color(col)
		st.add_vertex(v)


## Super throws the loose pieces away from the comet.
func shockwave(x: float, y: float, radius_m: float, power: float) -> void:
	var c := Vector3(x * U, 0.1, y * U)
	for d in debris:
		var body: RigidBody3D = d[0]
		var off := body.position - c
		var dist := off.length()
		if dist < radius_m and dist > 0.001:
			body.sleeping = false
			body.apply_central_impulse((off / dist + Vector3.UP * 0.6) * power * (1.0 - dist / radius_m) * body.mass)
