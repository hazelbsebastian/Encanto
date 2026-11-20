class_name MapBuilder3D
extends RefCounted
## Builds the five Philippine locations as real 3D worlds around a round
## battle arena (radius ARENA, centred on the origin): sky, sun, fog,
## ground and the landmarks each place is known for.
##   banaue          - rice terraces rising in rings, Ifugao houses, pines
##   intramuros      - stone walls + gate, Manila Cathedral, bahay na bato
##   mayon           - the perfect cone with a smoke plume, Cagsawa ruins
##   chocolate_hills - dozens of brown haystack hills, jungle, a tarsier
##   boracay         - white sand, animated sea at sunset, paraw sailboats
## Returns an info Dictionary (ambience track, spawn + jeepney path...).

const ARENA := 21.0
const WATER_SHADER := preload("res://assets/shaders/water.gdshader")
## Week 16: merge static map parts into few meshes (see M3.bake_static).
static var bake_static := true

static func build(root: Node3D, map_id: String) -> Dictionary:
	seed(hash(map_id))
	var info := {
		"ambient": "amb_countryside",
		"spawn": Vector3(0, 0, 7),
		"jeep_from": Vector3(-42, 0, 9),
		"jeep_to": Vector3(-5, 0, 9),
		"jeep_exit": Vector3(45, 0, 9),
		"tree": Vector3(0, 0, -13),
		"kapre": Vector3(-6, 0, -14),
	}
	match map_id:
		"intramuros":
			_intramuros(root, info)
		"mayon":
			_mayon(root, info)
		"chocolate_hills":
			_chocolate_hills(root, info)
		"boracay":
			_boracay(root, info)
		_:
			_banaue(root, info)
	if bake_static:
		info["baked_parts"] = M3.bake_static(root)
	_ground_collider(root)
	randomize()
	return info

# ------------------------------------------------------------- basics --
static func _env(root: Node3D, sky_top: Color, horizon: Color, sun_rot: Vector3, sun_color: Color, sun_energy: float, fog: Color, fog_density: float, ambient: float = 0.6) -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = sky_top
	sky_mat.sky_horizon_color = horizon
	sky_mat.ground_horizon_color = horizon.darkened(0.1)
	sky_mat.ground_bottom_color = horizon.darkened(0.5)
	sky_mat.sun_angle_max = 25.0
	sky_mat.sky_curve = 0.12
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = ambient * 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 0.95
	env.tonemap_white = 6.0
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.18
	env.adjustment_contrast = 1.06
	env.fog_enabled = true
	env.fog_light_color = fog
	env.fog_density = fog_density * 0.5
	env.fog_sky_affect = 0.15
	env.glow_enabled = true
	env.glow_intensity = 0.35
	env.glow_bloom = 0.05
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = sun_rot
	sun.light_color = sun_color
	sun.light_energy = sun_energy * 0.85
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 70.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.shadow_blur = 1.5
	root.add_child(sun)

static func _ground(root: Node3D, mat: Material, size: float = 500.0) -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(size, size)
	var mi := M3.mesh_node(root, plane, mat, Vector3.ZERO)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

static func _ground_collider(root: Node3D) -> void:
	var body := StaticBody3D.new()
	body.name = "GroundBody"
	body.collision_layer = 16
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	cs.shape = WorldBoundaryShape3D.new()
	body.add_child(cs)
	root.add_child(body)

## Soft worn circle marking the arena floor.
static func _arena_floor(root: Node3D, color: Color) -> void:
	var c := M3.cylinder(root, ARENA + 1.0, ARENA + 1.0, 0.04, M3.noise_mat(color, color.lightened(0.12), 0.06, 0.3, 1.0, 5), Vector3(0, 0.01, 0), Vector3.ZERO, 48, false)
	c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

static func _clouds(root: Node3D, count: int, color: Color = Color(1, 1, 1), height: float = 55.0) -> void:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.disable_fog = false
	for i in range(count):
		var a := randf() * TAU
		var r := randf_range(90, 220)
		var c := M3.pivot(root, Vector3(cos(a) * r, height + randf_range(-10, 15), sin(a) * r))
		for k in range(5):
			var s := M3.sphere(c, randf_range(6, 11), m, Vector3(k * 7.0 - 14.0, randf_range(-2, 3), randf_range(-4, 4)), Vector3(1.4, 0.55, 1), 10, false)
			s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

## Many copies of a small mesh in one draw call (rice clumps, grass, flowers).
static func _scatter(root: Node3D, mesh: Mesh, mat: Material, transforms: Array[Transform3D]) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for i in range(transforms.size()):
		mm.set_instance_transform(i, transforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mmi)

static func _grass_tufts(root: Node3D, count: int, r_min: float, r_max: float, color: Color, height: float = 0.5) -> void:
	var blade := CylinderMesh.new()
	blade.top_radius = 0.0
	blade.bottom_radius = 0.045
	blade.height = height * 0.7
	blade.radial_segments = 3
	blade.rings = 1
	var ts: Array[Transform3D] = []
	for i in range(count * 3):
		var a := randf() * TAU
		var r := sqrt(randf_range(r_min * r_min, r_max * r_max))
		var s := randf_range(0.6, 1.3)
		var b := Basis(Vector3.UP, randf() * TAU).rotated(Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized(), randf_range(0, 0.35)).scaled(Vector3(s, s, s))
		ts.append(Transform3D(b, Vector3(cos(a) * r, height * 0.3 * s, sin(a) * r)))
	_scatter(root, blade, M3.mat(color.darkened(0.1)), ts)

static func _mountains(root: Node3D, count: int, color: Color, dist: Vector2 = Vector2(170, 260), height: Vector2 = Vector2(45, 90)) -> void:
	for i in range(count):
		var a := TAU * i / count + randf() * 0.3
		var d := randf_range(dist.x, dist.y)
		var h := randf_range(height.x, height.y)
		M3.cone(root, h * randf_range(1.1, 1.6), h, color.lightened(randf() * 0.1), Vector3(cos(a) * d, h * 0.5 - 2, sin(a) * d), Vector3(0, randf() * 90, 0), 9)

# ============================================================ BANAUE ====
static func _banaue(root: Node3D, info: Dictionary) -> void:
	info["ambient"] = "amb_countryside"
	_env(root, Color(0.3, 0.52, 0.82), Color(0.82, 0.88, 0.9), Vector3(-42, -35, 0), Color(1, 0.94, 0.82), 1.25, Color(0.74, 0.82, 0.86), 0.006)
	_ground(root, M3.noise_mat(Color(0.17, 0.3, 0.1), Color(0.26, 0.4, 0.14), 0.04, 0.2))
	_arena_floor(root, Color(0.2, 0.33, 0.11))
	var paddy_greens := [Color(0.35, 0.6, 0.24), Color(0.45, 0.68, 0.3), Color(0.3, 0.52, 0.2), Color(0.56, 0.72, 0.34)]
	var water := M3.mat(Color(0.62, 0.76, 0.82), 0.08, 0.0, 0.35)
	var wall := M3.noise_mat(Color(0.24, 0.32, 0.12), Color(0.38, 0.42, 0.2), 0.25, 1.0, 0.95, 3)
	var rice_ts: Array[Transform3D] = []
	for i in range(13):
		var r_in := 24.0 + i * 4.4
		var top := 0.6 + i * 1.05
		var mesh := M3.ring_mesh(r_in, r_in + 4.8, top, top + 0.2, 72, 0.07, i)
		var is_water := i % 4 == 1
		var top_mat := (water if is_water else M3.mat(paddy_greens[i % 4])) as StandardMaterial3D
		top_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		wall.cull_mode = BaseMaterial3D.CULL_DISABLED
		mesh.surface_set_material(0, top_mat)
		mesh.surface_set_material(1, wall)
		M3.mesh_raw(root, mesh)
		if not is_water and i < 7:
			for k in range(90):
				var a := randf() * TAU
				var rr := r_in + randf_range(0.5, 4.2)
				rice_ts.append(Transform3D(Basis(Vector3.UP, randf() * TAU), Vector3(cos(a) * rr, top + 0.2, sin(a) * rr)))
	var tuft := CylinderMesh.new()
	tuft.top_radius = 0.18
	tuft.bottom_radius = 0.02
	tuft.height = 0.45
	tuft.radial_segments = 5
	_scatter(root, tuft, M3.mat(Color(0.52, 0.72, 0.3)), rice_ts)
	for spec in [[0.6, 2], [1.4, 3], [2.5, 1], [3.3, 4], [4.3, 2], [5.4, 5], [0.2, 6]]:
		var a: float = spec[0]
		var ring: int = spec[1]
		var r := 24.0 + ring * 4.4 + 2.4
		Models.ifugao_house(root, Vector3(cos(a) * r, 0.6 + ring * 1.05 + 0.2, sin(a) * r), randf_range(0.8, 1.0))
	for k in range(40):
		var a := randf() * TAU
		var ring := randi_range(7, 12)
		var r := 24.0 + ring * 4.4 + randf_range(1.0, 4.0)
		Models.pine(root, Vector3(cos(a) * r, 0.6 + ring * 1.05 + 0.2, sin(a) * r), randf_range(5.0, 8.0))
	_mountains(root, 11, Color(0.3, 0.45, 0.4), Vector2(150, 240), Vector2(60, 110))
	_grass_tufts(root, 500, 4, ARENA + 3, Color(0.26, 0.42, 0.14), 0.45)
	_clouds(root, 10)

# ======================================================== INTRAMUROS ====
static func _intramuros(root: Node3D, info: Dictionary) -> void:
	info["ambient"] = "amb_city"
	info["jeep_from"] = Vector3(-48, 0, 0)
	info["jeep_to"] = Vector3(-7, 0, 0)
	info["jeep_exit"] = Vector3(-48, 0, 0)
	info["spawn"] = Vector3(-3, 0, 3)
	_env(root, Color(0.3, 0.45, 0.78), Color(1.0, 0.8, 0.6), Vector3(-34, 60, 0), Color(1, 0.8, 0.58), 1.3, Color(0.95, 0.78, 0.6), 0.007, 0.55)
	_ground(root, M3.noise_mat(Color(0.42, 0.38, 0.33), Color(0.58, 0.53, 0.46), 0.35, 0.15, 0.95, 9))
	_arena_floor(root, Color(0.46, 0.42, 0.36))
	var stone := M3.noise_mat(Color(0.52, 0.47, 0.38), Color(0.68, 0.62, 0.5), 0.15, 0.5, 0.95, 4)
	var moss := Color(0.3, 0.42, 0.24)
	var W := 27.0
	# four walls with crenellations; the west wall has the Puerta (gate)
	for side in range(4):
		var rot := side * 90.0
		var wall := M3.pivot(root, Vector3.ZERO)
		wall.rotation_degrees.y = rot
		if side == 1:
			for part in [-1, 1]:
				M3.box(wall, Vector3(3.5, 8, 26), stone, Vector3(-W, 4, part * 17.5))
			M3.box(wall, Vector3(4.2, 11, 3), stone, Vector3(-W, 5.5, -5.5))
			M3.box(wall, Vector3(4.2, 11, 3), stone, Vector3(-W, 5.5, 5.5))
			M3.box(wall, Vector3(4.2, 3.5, 14), stone, Vector3(-W, 9.2, 0))
			M3.prism(wall, Vector3(4.4, 2.5, 14.5), stone, Vector3(-W, 12.2, 0), Vector3(0, 90, 0))
			M3.sphere(wall, 0.9, M3.mat(Color(0.85, 0.7, 0.3), 0.3, 0.5, 0.6), Vector3(-W + 2.2, 9.5, 0))
		else:
			M3.box(wall, Vector3(3.5, 8, 60), stone, Vector3(-W, 4, 0))
		for k in range(15):
			M3.box(wall, Vector3(3.6, 1.2, 2.0), stone, Vector3(-W, 8.6, -28 + k * 4.0))
		for k in range(6):
			M3.sphere(wall, randf_range(1.0, 2.2), moss, Vector3(-W + 1.8, randf_range(1, 6), randf_range(-26, 26)), Vector3(0.3, 1, 1.3), 8)
	# Manila Cathedral beyond the east wall
	var cat := M3.pivot(root, Vector3(48, 0, -8))
	cat.rotation_degrees.y = -90
	var cstone := M3.noise_mat(Color(0.72, 0.64, 0.5), Color(0.84, 0.77, 0.62), 0.12, 0.5, 0.95, 6)
	M3.box(cat, Vector3(18, 20, 8), cstone, Vector3(0, 10, 0))
	M3.prism(cat, Vector3(19, 6, 8.5), cstone, Vector3(0, 23, 0))
	M3.cylinder(cat, 2.4, 2.4, 0.3, M3.mat(Color(0.65, 0.8, 0.95), 0.2, 1.2), Vector3(0, 15, -4.1), Vector3(90, 0, 0), 20)
	M3.box(cat, Vector3(4, 7, 0.4), Color(0.3, 0.2, 0.15), Vector3(0, 3.5, -4.1))
	M3.box(cat, Vector3(22, 16, 30), cstone, Vector3(0, 8, 18))
	M3.cylinder(cat, 6, 6, 5, cstone, Vector3(0, 18.5, 22), Vector3.ZERO, 20)
	M3.dome(cat, 6.2, Color(0.32, 0.46, 0.4), Vector3(0, 21, 22), Vector3(1, 1.3, 1), 24)
	M3.cylinder(cat, 0.9, 1.1, 3, cstone, Vector3(0, 30, 22), Vector3.ZERO, 10)
	M3.box(cat, Vector3(0.3, 3, 0.3), Color(0.8, 0.7, 0.3), Vector3(0, 33, 22))
	M3.box(cat, Vector3(1.6, 0.3, 0.3), Color(0.8, 0.7, 0.3), Vector3(0, 33.7, 22))
	var tower := M3.pivot(cat, Vector3(13, 0, 0))
	M3.box(tower, Vector3(6, 28, 6), cstone, Vector3(0, 14, 0))
	for k in range(3):
		M3.box(tower, Vector3(2, 4, 6.2), Color(0.25, 0.18, 0.14), Vector3(0, 8 + k * 7.5, 0))
	M3.cone(tower, 4.2, 6, Color(0.32, 0.46, 0.4), Vector3(0, 31, 0), Vector3(0, 45, 0), 4)
	# bahay na bato around the plaza, windows facing the centre
	for spec in [[0.0, 23.0], [90.0, 23.0], [180.0, 23.0], [45.0, 24.0], [135.0, 24.0], [225.0, 24.0], [315.0, 24.0]]:
		var ang := deg_to_rad(float(spec[0]) + 90.0)
		var r: float = spec[1]
		var pos := Vector3(cos(ang) * r, 0, sin(ang) * r)
		if pos.x < -18:
			continue  # keep the gate clear
		var b := Models.bahay_na_bato(root, pos, 0.0, randf_range(6, 8))
		b.look_at(Vector3(0, 0, 0), Vector3.UP)
	for k in range(8):
		var a := TAU * k / 8.0 + 0.2
		Models.lamp_post(root, Vector3(cos(a) * 20.0, 0, sin(a) * 20.0), k % 2 == 0)
	for spec in [[0.9, 19.0], [2.4, 18.5], [4.0, 19.5], [5.5, 18.5]]:
		var a2: float = spec[0]
		Models.round_tree(root, Vector3(cos(a2) * float(spec[1]), 0, sin(a2) * float(spec[1])), 4.5, Color(0.24, 0.42, 0.22))
	# kalesa parked by the wall
	var kal := M3.pivot(root, Vector3(10, 0, -17))
	M3.box(kal, Vector3(1.6, 1.0, 2.2), Color(0.5, 0.12, 0.1), Vector3(0, 1.2, 0))
	M3.box(kal, Vector3(1.7, 0.1, 2.4), Color(0.15, 0.1, 0.08), Vector3(0, 2.3, 0))
	for side in [-1, 1]:
		M3.torus(kal, 0.5, 0.62, Color(0.2, 0.14, 0.1), Vector3(0.9 * side, 0.62, 0), Vector3(0, 0, 90))
	_clouds(root, 8, Color(1, 0.88, 0.78))

# ============================================================== MAYON ===
static func _mayon(root: Node3D, info: Dictionary) -> void:
	info["ambient"] = "amb_volcano"
	_env(root, Color(0.22, 0.46, 0.85), Color(0.76, 0.86, 0.92), Vector3(-55, 25, 0), Color(1, 0.96, 0.88), 1.35, Color(0.78, 0.86, 0.9), 0.0035)
	_ground(root, M3.noise_mat(Color(0.16, 0.3, 0.1), Color(0.25, 0.4, 0.14), 0.05, 0.2))
	_arena_floor(root, Color(0.2, 0.34, 0.11))
	# the near-perfect cone, built from stacked frustums for the concave shape
	var v := M3.pivot(root, Vector3(0, 0, -260))
	var layers := [[4.0, 22.0, 42.0, Color(0.78, 0.78, 0.8)], [22.0, 52.0, 36.0, Color(0.46, 0.47, 0.5)], [52.0, 95.0, 30.0, Color(0.38, 0.44, 0.38)], [95.0, 170.0, 24.0, Color(0.3, 0.46, 0.28)]]
	var y := 132.0
	for l in layers:
		var h: float = l[2]
		M3.cylinder(v, float(l[0]), float(l[1]), h, M3.noise_mat(Color(l[3]), Color(l[3]).lightened(0.12), 0.08, 0.05, 0.95, int(h)), Vector3(0, y - h * 0.5, 0), Vector3.ZERO, 36)
		y -= h
	# gullies (dark lines) running down the upper cone
	for k in range(14):
		var a := TAU * k / 14.0
		M3.box(v, Vector3(0.8, 70, 0.8), Color(0.3, 0.31, 0.34), Vector3(cos(a) * 30, 95, sin(a) * 30), Vector3(sin(a) * 18, 0, -cos(a) * 18))
	# smoke plume from the summit
	var smoke := CPUParticles3D.new()
	smoke.amount = 40
	smoke.lifetime = 14.0
	smoke.preprocess = 14.0
	var puff := SphereMesh.new()
	puff.radius = 5.0
	puff.height = 10.0
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color(0.9, 0.9, 0.9, 0.55)
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	puff.material = sm
	smoke.mesh = puff
	smoke.direction = Vector3(0.6, 1, 0)
	smoke.spread = 12.0
	smoke.gravity = Vector3(1.5, 0.6, 0)
	smoke.initial_velocity_min = 3.0
	smoke.initial_velocity_max = 5.0
	smoke.scale_amount_min = 0.6
	smoke.scale_amount_max = 1.6
	smoke.position = Vector3(0, 134, 0)
	v.add_child(smoke)
	# Cagsawa ruins belfry + broken church wall
	var ruin_mat := M3.noise_mat(Color(0.34, 0.3, 0.27), Color(0.5, 0.45, 0.4), 0.2, 0.6, 0.95, 8)
	var cag := M3.pivot(root, Vector3(-27, 0, -12))
	cag.rotation_degrees.y = 30
	M3.box(cag, Vector3(4.5, 9, 4.5), ruin_mat, Vector3(0, 4.5, 0))
	M3.box(cag, Vector3(3.6, 5, 3.6), ruin_mat, Vector3(0, 11.5, 0))
	M3.box(cag, Vector3(2.4, 2.4, 2.2), ruin_mat, Vector3(-0.4, 15.2, 0.3), Vector3(0, 0, 8))
	for spec in [[0, 3.5], [0, 7.2], [0, 11.8]]:
		M3.box(cag, Vector3(1.4, 2.2, 4.7), Color(0.12, 0.1, 0.09), Vector3(0, float(spec[1]), 0))
	for k in range(5):
		var hh := randf_range(2.5, 6.5)
		M3.box(cag, Vector3(1.2, hh, 3.4), ruin_mat, Vector3(4 + k * 3.2, hh * 0.5, 2), Vector3(0, 0, randf_range(-6, 6)))
	for k in range(8):
		M3.sphere(cag, randf_range(0.6, 1.3), Color(0.28, 0.42, 0.22), Vector3(randf_range(-2, 16), randf_range(0.5, 6), randf_range(1, 3)), Vector3(1, 0.7, 1), 8)
	# rice paddies + palms
	for k in range(10):
		var a := randf_range(0.2, TAU - 0.2)
		var r := randf_range(28, 60)
		var paddy := M3.box(root, Vector3(randf_range(8, 14), 0.1, randf_range(6, 10)), M3.mat(Color(0.5, 0.66, 0.72), 0.1, 0.0, 0.3) if k % 2 == 0 else M3.mat(Color(0.42, 0.66, 0.26)), Vector3(cos(a) * r, 0.03, sin(a) * r), Vector3(0, randf() * 90, 0), false)
		paddy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for k in range(22):
		var a := randf() * TAU
		var r := randf_range(23, 45)
		Models.palm(root, Vector3(cos(a) * r, 0, sin(a) * r), randf_range(6, 9), Vector3(randf_range(-0.15, 0.15), 0, randf_range(-0.15, 0.15)))
	_mountains(root, 8, Color(0.3, 0.46, 0.34), Vector2(160, 230), Vector2(20, 40))
	_grass_tufts(root, 700, 3, 40, Color(0.24, 0.42, 0.14), 0.55)
	_clouds(root, 9)

# ==================================================== CHOCOLATE HILLS ===
static func _chocolate_hills(root: Node3D, info: Dictionary) -> void:
	info["ambient"] = "amb_countryside"
	_env(root, Color(0.25, 0.5, 0.85), Color(0.8, 0.88, 0.88), Vector3(-48, -60, 0), Color(1, 0.95, 0.85), 1.3, Color(0.78, 0.85, 0.8), 0.0055)
	_ground(root, M3.noise_mat(Color(0.3, 0.5, 0.22), Color(0.44, 0.62, 0.28), 0.05, 0.2))
	_arena_floor(root, Color(0.21, 0.35, 0.12))
	var browns := [Color(0.45, 0.28, 0.12), Color(0.52, 0.34, 0.15), Color(0.4, 0.28, 0.14), Color(0.48, 0.36, 0.17)]
	var placed := 0
	var tries := 0
	var spots: Array[Vector3] = []
	while placed < 55 and tries < 600:
		tries += 1
		var a := randf() * TAU
		var r := randf_range(30, 190)
		var p := Vector3(cos(a) * r, 0, sin(a) * r)
		var size := randf_range(7, 12) * (1.0 + r / 250.0)
		var ok := true
		for q in spots:
			if q.distance_to(p) < size * 1.5:
				ok = false
				break
		if not ok:
			continue
		spots.append(p)
		var col: Color = browns[placed % 4]
		M3.dome(root, size, M3.noise_mat(col, col.lightened(0.18), 0.25, 0.4, 0.95, placed % 4), p, Vector3(1, randf_range(0.95, 1.25), 1), 20)
		placed += 1
	# jungle between the hills
	for k in range(70):
		var a := randf() * TAU
		var r := randf_range(24, 120)
		Models.round_tree(root, Vector3(cos(a) * r, 0, sin(a) * r), randf_range(2.5, 4.5), Color(0.18, 0.4, 0.2))
	for k in range(14):
		var a := randf() * TAU
		var r := randf_range(22, 34)
		Models.palm(root, Vector3(cos(a) * r, 0, sin(a) * r), randf_range(6, 8))
	# viewing deck
	var deck := M3.pivot(root, Vector3(0, 0, 27))
	var wood := Color(0.45, 0.3, 0.18)
	M3.box(deck, Vector3(10, 0.4, 6), wood, Vector3(0, 3, 0))
	for x in [-4.5, 4.5]:
		for z in [-2.5, 2.5]:
			M3.cylinder(deck, 0.2, 0.2, 3, wood.darkened(0.3), Vector3(x, 1.5, z), Vector3.ZERO, 8)
	for k in range(11):
		M3.box(deck, Vector3(0.12, 1.1, 0.12), wood, Vector3(-5 + k, 3.75, -3))
	M3.box(deck, Vector3(10.2, 0.12, 0.2), wood, Vector3(0, 4.3, -3))
	# a tarsier (Bohol's famous big-eyed primate) on a branch at the arena edge
	var tree := Models.round_tree(root, Vector3(-19, 0, -15), 4.0, Color(0.2, 0.44, 0.22))
	M3.limb(tree, Vector3(0, 3.2, 0), Vector3(1.6, 3.4, 0.4), 0.12, Color(0.36, 0.26, 0.18))
	var tar := M3.pivot(tree, Vector3(1.3, 3.6, 0.4))
	tar.look_at(Vector3.ZERO, Vector3.UP)
	M3.sphere(tar, 0.14, Color(0.6, 0.48, 0.36), Vector3(0, 0, 0), Vector3(1, 1.2, 1))
	M3.sphere(tar, 0.13, Color(0.66, 0.53, 0.4), Vector3(0, 0.2, 0))
	for side in [-1, 1]:
		M3.sphere(tar, 0.06, Color(1, 0.85, 0.3), Vector3(0.055 * side, 0.22, -0.1), Vector3.ONE, 10)
		M3.sphere(tar, 0.03, Color(0.05, 0.03, 0.02), Vector3(0.055 * side, 0.22, -0.15), Vector3.ONE, 8)
		M3.sphere(tar, 0.05, Color(0.6, 0.48, 0.36), Vector3(0.12 * side, 0.3, 0), Vector3.ONE, 8)
	_grass_tufts(root, 700, 3, 40, Color(0.24, 0.42, 0.14), 0.5)
	_clouds(root, 12)

# ============================================================ BORACAY ===
static func _boracay(root: Node3D, info: Dictionary) -> void:
	info["ambient"] = "amb_beach"
	info["jeep_from"] = Vector3(-45, 0, -6)
	info["jeep_to"] = Vector3(-6, 0, -6)
	info["jeep_exit"] = Vector3(45, 0, -6)
	info["spawn"] = Vector3(0, 0, -2)
	_env(root, Color(0.22, 0.2, 0.46), Color(1.0, 0.6, 0.42), Vector3(-9, 180, 0), Color(1, 0.66, 0.4), 1.2, Color(0.98, 0.7, 0.55), 0.004, 0.7)
	_ground(root, M3.noise_mat(Color(0.93, 0.89, 0.8), Color(0.99, 0.97, 0.9), 0.12, 0.3, 1.0, 11))
	# the sea (animated shader) beyond the shoreline at +Z
	var sea_mesh := PlaneMesh.new()
	sea_mesh.size = Vector2(700, 400)
	sea_mesh.subdivide_width = 120
	sea_mesh.subdivide_depth = 70
	var sea_mat := ShaderMaterial.new()
	sea_mat.shader = WATER_SHADER
	sea_mat.set_shader_parameter("shore_center", Vector3(0, 0, 0))
	sea_mat.set_shader_parameter("shore_radius", 20.0)
	sea_mat.set_shader_parameter("shore_fade", 90.0)
	var sea := M3.mesh_node(root, sea_mesh, sea_mat, Vector3(0, 0.08, 215))
	sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# wet sand strip + foam line
	var wet := M3.box(root, Vector3(700, 0.02, 4), M3.mat(Color(0.8, 0.76, 0.66), 0.4), Vector3(0, 0.02, 15), Vector3.ZERO, false)
	wet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var foam := M3.box(root, Vector3(700, 0.05, 0.5), M3.mat(Color(1, 1, 1, 0.85), 0.5, 0.3), Vector3(0, 0.1, 17), Vector3.ZERO, false)
	foam.set_meta("dynamic", true)
	foam.create_tween().set_loops().tween_property(foam, "position:z", 16.2, 2.5).set_trans(Tween.TRANS_SINE)
	# low sunset sun over the sea
	M3.sphere(root, 22, M3.mat(Color(1, 0.8, 0.45), 1.0, 3.0), Vector3(40, 18, 420), Vector3.ONE, 24, false)
	# Willy's Rock with its little grotto statue
	var wr := M3.pivot(root, Vector3(-26, 0, 48))
	var rock_mat := M3.noise_mat(Color(0.3, 0.27, 0.25), Color(0.45, 0.4, 0.37), 0.3, 0.6, 0.95, 12)
	M3.sphere(wr, 6.0, rock_mat, Vector3(0, 2, 0), Vector3(1.2, 1.2, 1), 12)
	M3.sphere(wr, 3.5, rock_mat, Vector3(4.5, 1.5, 1), Vector3(1, 1.3, 1), 10)
	for k in range(6):
		M3.sphere(wr, randf_range(0.8, 1.5), Color(0.22, 0.42, 0.22), Vector3(randf_range(-4, 5), randf_range(5, 8), randf_range(-2, 2)), Vector3(1, 0.7, 1), 8)
	M3.capsule(wr, 0.35, 1.6, Color(0.96, 0.96, 0.98), Vector3(0, 9.0, -1.5))
	M3.sphere(wr, 0.3, Color(0.96, 0.96, 0.98), Vector3(0, 10.0, -1.5))
	# paraw sailboats
	var sails := [Color(0.9, 0.3, 0.25), Color(0.98, 0.78, 0.25), Color(0.3, 0.55, 0.85), Color(0.95, 0.95, 0.9)]
	for k in range(6):
		var p := Vector3(randf_range(-90, 90), 0.2, randf_range(45, 150))
		var boat := Models.paraw(root, p, sails[k % 4], randf_range(0, 360))
		boat.set_meta("dynamic", true)
		var bt := boat.create_tween().set_loops()
		bt.tween_property(boat, "position:y", 0.45, randf_range(1.6, 2.4)).set_trans(Tween.TRANS_SINE)
		bt.tween_property(boat, "position:y", 0.05, randf_range(1.6, 2.4)).set_trans(Tween.TRANS_SINE)
	# leaning palms + nipa cottages along the beach
	for k in range(26):
		var x := randf_range(-70, 70)
		var z := randf_range(-40, 12)
		if Vector2(x, z).length() < ARENA + 1.5:
			continue
		Models.palm(root, Vector3(x, 0, z), randf_range(7, 10), Vector3(randf_range(-0.1, 0.1), 0, randf_range(0.15, 0.35)))
	for spec in [[-24, -14, 20], [22, -16, -20], [-34, 2, 60], [33, 4, -70], [0, -30, 0]]:
		Models.nipa_hut(root, Vector3(float(spec[0]), 0, float(spec[1])), float(spec[2]), 1.2)
	# starfish + shells on the sand
	for k in range(30):
		var a := randf() * TAU
		var r := randf_range(3, ARENA)
		var sp := M3.pivot(root, Vector3(cos(a) * r, 0.03, sin(a) * r))
		sp.rotation.y = randf() * TAU
		if k % 2 == 0:
			for arm in range(5):
				M3.box(sp, Vector3(0.08, 0.03, 0.3), Color(0.95, 0.45, 0.3), Vector3(0, 0, -0.15).rotated(Vector3.UP, arm * TAU / 5.0), Vector3(0, rad_to_deg(arm * TAU / 5.0), 0), false)
		else:
			M3.dome(sp, 0.12, Color(1, 0.88, 0.85), Vector3.ZERO, Vector3(1, 0.6, 1.3), 8)
	_clouds(root, 10, Color(1, 0.72, 0.62), 40.0)
