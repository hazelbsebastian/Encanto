class_name M3
extends RefCounted
## Tiny low-poly modelling kit: every 3D character, prop and landmark in
## Encanto is assembled in code from primitive meshes (boxes, spheres,
## capsules, cylinders, cones, prisms) with cached flat-colour materials.
## Keeps the project free of external model files and easy to tweak.

static var _mats: Dictionary = {}

## Shared material per colour (+ options) so hundreds of parts stay cheap.
static func mat(color: Color, roughness: float = 0.85, emission: float = 0.0, metallic: float = 0.0) -> StandardMaterial3D:
	var key := "%s|%.2f|%.2f|%.2f" % [color.to_html(), roughness, emission, metallic]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	if color.a < 0.999:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emission
	_mats[key] = m
	return m

## Material with procedural noise detail - grass, sand, stone, bark...
static func noise_mat(a: Color, b: Color, frequency: float = 0.02, uv_scale: float = 1.0, roughness: float = 0.95, seed: int = 1) -> StandardMaterial3D:
	var key := "noise|%s|%s|%.3f|%.2f|%d" % [a.to_html(), b.to_html(), frequency, uv_scale, seed]
	if _mats.has(key):
		return _mats[key]
	var noise := FastNoiseLite.new()
	noise.seed = seed
	noise.frequency = frequency
	noise.fractal_octaves = 4
	var grad := Gradient.new()
	grad.set_color(0, a)
	grad.set_color(1, b)
	var tex := NoiseTexture2D.new()
	tex.width = 512
	tex.height = 512
	tex.seamless = true
	tex.noise = noise
	tex.color_ramp = grad
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.roughness = roughness
	m.uv1_scale = Vector3(uv_scale, uv_scale, uv_scale)
	m.uv1_triplanar = true
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_mats[key] = m
	return m

static func _add(parent: Node3D, mesh: Mesh, material: Material, pos: Vector3, rot_deg: Vector3, shadows: bool) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi

static func _m(material: Variant) -> Material:
	if material is Material:
		return material
	return mat(Color(material))

# ------------------------------------------------------------- primitives --
static func box(parent: Node3D, size: Vector3, material: Variant, pos: Vector3 = Vector3.ZERO, rot: Vector3 = Vector3.ZERO, shadows: bool = true) -> MeshInstance3D:
	var m := BoxMesh.new()
	m.size = size
	return _add(parent, m, _m(material), pos, rot, shadows)

static func sphere(parent: Node3D, radius: float, material: Variant, pos: Vector3 = Vector3.ZERO, squash: Vector3 = Vector3.ONE, segments: int = 16, shadows: bool = true) -> MeshInstance3D:
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0
	m.radial_segments = segments
	m.rings = maxi(6, int(segments / 2.0))
	var mi := _add(parent, m, _m(material), pos, Vector3.ZERO, shadows)
	mi.scale = squash
	return mi

## Hemisphere (dome), flat side down - hills, domes, hair caps.
static func dome(parent: Node3D, radius: float, material: Variant, pos: Vector3 = Vector3.ZERO, squash: Vector3 = Vector3.ONE, segments: int = 18) -> MeshInstance3D:
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius
	m.is_hemisphere = true
	m.radial_segments = segments
	m.rings = maxi(5, int(segments / 3.0))
	var mi := _add(parent, m, _m(material), pos, Vector3.ZERO, true)
	mi.scale = squash
	return mi

static func capsule(parent: Node3D, radius: float, height: float, material: Variant, pos: Vector3 = Vector3.ZERO, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var m := CapsuleMesh.new()
	m.radius = radius
	m.height = maxf(height, radius * 2.0)
	m.radial_segments = 12
	m.rings = 4
	return _add(parent, m, _m(material), pos, rot, true)

static func cylinder(parent: Node3D, top_r: float, bottom_r: float, height: float, material: Variant, pos: Vector3 = Vector3.ZERO, rot: Vector3 = Vector3.ZERO, sides: int = 16, shadows: bool = true) -> MeshInstance3D:
	var m := CylinderMesh.new()
	m.top_radius = top_r
	m.bottom_radius = bottom_r
	m.height = height
	m.radial_segments = sides
	m.rings = 1
	return _add(parent, m, _m(material), pos, rot, shadows)

## Cone / pyramid (sides = 4 gives the Ifugao-house roof shape).
static func cone(parent: Node3D, radius: float, height: float, material: Variant, pos: Vector3 = Vector3.ZERO, rot: Vector3 = Vector3.ZERO, sides: int = 16) -> MeshInstance3D:
	return cylinder(parent, 0.0, radius, height, material, pos, rot, sides)

static func prism(parent: Node3D, size: Vector3, material: Variant, pos: Vector3 = Vector3.ZERO, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var m := PrismMesh.new()
	m.size = size
	return _add(parent, m, _m(material), pos, rot, true)

static func torus(parent: Node3D, inner: float, outer: float, material: Variant, pos: Vector3 = Vector3.ZERO, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var m := TorusMesh.new()
	m.inner_radius = inner
	m.outer_radius = outer
	m.rings = 24
	m.ring_segments = 8
	return _add(parent, m, _m(material), pos, rot, true)

## A limb/pole from point a to point b (capsule oriented along the segment).
static func limb(parent: Node3D, a: Vector3, b: Vector3, radius: float, material: Variant) -> MeshInstance3D:
	var mid := (a + b) * 0.5
	var length := a.distance_to(b)
	var mi := capsule(parent, radius, length + radius * 2.0, material, mid)
	var dir := (b - a).normalized()
	if dir.length() > 0.001:
		var axis := Vector3.UP.cross(dir)
		if axis.length() < 0.0001:
			axis = Vector3.RIGHT
		mi.quaternion = Quaternion(axis.normalized(), Vector3.UP.angle_to(dir))
	return mi

## A pivot node (joint) to animate groups of parts: hips, shoulders, wings.
static func pivot(parent: Node3D, pos: Vector3, name: String = "") -> Node3D:
	var n := Node3D.new()
	n.position = pos
	if name != "":
		n.name = name
	parent.add_child(n)
	return n

## Rice-terrace ring: surface 0 = flat paddy top, surface 1 = the stone
## retaining wall facing the centre. Assign materials per surface.
static func ring_mesh(r_in: float, r_out: float, top_y: float, wall: float, segments: int = 64, wobble: float = 0.0, seed: int = 0) -> ArrayMesh:
	var noise := FastNoiseLite.new()
	noise.seed = seed
	noise.frequency = 0.9
	var pts_in: Array[Vector3] = []
	var pts_out: Array[Vector3] = []
	for i in range(segments + 1):
		var ang := TAU * float(i % segments) / segments
		var w := 1.0 + noise.get_noise_1d(float(i % segments) * 0.35) * wobble
		var d := Vector3(cos(ang), 0, sin(ang))
		pts_in.append(d * r_in * w + Vector3(0, top_y, 0))
		pts_out.append(d * r_out * w + Vector3(0, top_y, 0))
	var mesh := ArrayMesh.new()
	var top := SurfaceTool.new()
	top.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(segments):
		top.set_normal(Vector3.UP)
		for v in [pts_in[i], pts_out[i + 1], pts_out[i], pts_in[i], pts_in[i + 1], pts_out[i + 1]]:
			top.add_vertex(v)
	top.commit(mesh)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(segments):
		var a := pts_in[i]
		var b := pts_in[i + 1]
		var a2 := a - Vector3(0, wall, 0)
		var b2 := b - Vector3(0, wall, 0)
		st.set_normal(-Vector3(a.x + b.x, 0, a.z + b.z).normalized())
		for v in [a, a2, b2, a, b2, b]:
			st.add_vertex(v)
	st.commit(mesh)
	return mesh

## MeshInstance that keeps the mesh's own per-surface materials.
static func mesh_raw(parent: Node3D, mesh: Mesh, pos: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	parent.add_child(mi)
	return mi

static func mesh_node(parent: Node3D, mesh: Mesh, material: Variant, pos: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	return _add(parent, mesh, _m(material), pos, Vector3.ZERO, true)

## Flash every mesh under `root` (hit feedback) using a material overlay.
static func flash(root: Node, color: Color = Color(1, 0.35, 0.3), time: float = 0.12) -> void:
	var overlay := StandardMaterial3D.new()
	overlay.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	overlay.albedo_color = Color(color.r, color.g, color.b, 0.6)
	overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var meshes: Array[GeometryInstance3D] = []
	_collect(root, meshes)
	for g in meshes:
		g.material_overlay = overlay
	root.get_tree().create_timer(time).timeout.connect(func() -> void:
		for g in meshes:
			if is_instance_valid(g):
				g.material_overlay = null
	)

static func _collect(n: Node, out: Array[GeometryInstance3D]) -> void:
	if n is MeshInstance3D:
		out.append(n)
	for c in n.get_children():
		_collect(c, out)

# ------------------------------------------------------- static batching --
## Week 16 (SA6 bottleneck B1): every primitive above is its own
## MeshInstance3D, so a map is 300-660 draw calls per frame (each shadow
## caster is drawn again in the shadow pass). bake_static() merges the
## static, opaque parts under `root` into one mesh per material, per shadow
## setting and per 64 m grid cell (the cell keeps frustum culling useful).
## Skipped: nodes tagged set_meta("dynamic", true) and their children (tweened
## boats, foam), transparent or shader materials, meshes with per-surface
## materials, bodies, lights, particles, MultiMesh. Returns parts merged.
const BAKE_CELL := 64.0

static func bake_static(root: Node3D) -> int:
	var groups: Dictionary = {}
	var merged: Array[MeshInstance3D] = []
	_bake_collect(root, Transform3D.IDENTITY, groups, merged)
	var n := 0
	for key in groups:
		var g: Dictionary = groups[key]
		if (g["parts"] as Array).size() < 2:
			continue   # nothing to gain - leave the original node alone
		var st := SurfaceTool.new()
		for part in g["parts"]:
			st.append_from(part[0], 0, part[1])
		var mi := MeshInstance3D.new()
		mi.name = "Baked"
		mi.mesh = st.commit()
		mi.material_override = g["mat"]
		mi.cast_shadow = g["shadow"]
		root.add_child(mi)
		for part in g["parts"]:
			(part[2] as Node).queue_free()
			n += 1
	return n

static func _bake_collect(n: Node3D, xform: Transform3D, groups: Dictionary, merged: Array[MeshInstance3D]) -> void:
	for c in n.get_children():
		if not (c is Node3D) or c.has_meta("dynamic") or not (c as Node3D).visible:
			continue
		var t: Transform3D = xform * (c as Node3D).transform
		if c is MeshInstance3D:
			var mi := c as MeshInstance3D
			var m := mi.material_override as StandardMaterial3D
			if m == null or mi.get_child_count() > 0 or mi.mesh == null or mi.mesh.get_surface_count() != 1 \
					or m.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED or mi.material_overlay != null:
				continue
			var cell := Vector2i(floori(t.origin.x / BAKE_CELL), floori(t.origin.z / BAKE_CELL))
			var key := "%d|%d|%s|%d" % [m.get_instance_id(), mi.cast_shadow, mi.mesh.get_class(), cell.x * 1000 + cell.y]
			if not groups.has(key):
				groups[key] = {"mat": m, "shadow": mi.cast_shadow, "parts": []}
			(groups[key]["parts"] as Array).append([mi.mesh, t, mi])
		elif c.get_class() == "Node3D":
			_bake_collect(c, t, groups, merged)
