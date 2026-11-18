class_name Models
extends RefCounted
## Low-poly 3D models for every character and reusable prop, built with M3.
## Characters face -Z (Godot's forward). Builders return a Dictionary of the
## joint pivots so scripts can animate limbs procedurally.

const INK := Color(0.12, 0.08, 0.07)
const SKIN := Color(0.78, 0.55, 0.39)
const HAIR := Color(0.12, 0.09, 0.08)

# ================================================================ FARMER ===
static func farmer(root: Node3D, shirt: StandardMaterial3D, pants: StandardMaterial3D) -> Dictionary:
	var j := {}
	var body := M3.pivot(root, Vector3(0, 0, 0), "Body")
	j["body"] = body
	# legs (hip pivots so they can swing)
	for side in [-1, 1]:
		var hip := M3.pivot(body, Vector3(0.12 * side, 0.9, 0))
		M3.capsule(hip, 0.11, 0.62, pants, Vector3(0, -0.3, 0))
		M3.capsule(hip, 0.085, 0.36, SKIN, Vector3(0, -0.66, 0))  # rolled-up pants, bare shin
		M3.box(hip, Vector3(0.16, 0.08, 0.28), Color(0.28, 0.19, 0.13), Vector3(0, -0.86, -0.05))  # sandal
		j["hip_l" if side < 0 else "hip_r"] = hip
	var torso := M3.pivot(body, Vector3(0, 0.9, 0), "Torso")
	j["torso"] = torso
	M3.capsule(torso, 0.24, 0.72, shirt, Vector3(0, 0.34, 0))  # loose camisa
	M3.cylinder(torso, 0.25, 0.25, 0.1, pants, Vector3(0, 0.04, 0))  # waist
	M3.torus(torso, 0.08, 0.14, Color(0.8, 0.2, 0.18), Vector3(0, 0.66, 0))  # red bandana
	M3.prism(torso, Vector3(0.12, 0.16, 0.04), Color(0.8, 0.2, 0.18), Vector3(0.06, 0.58, 0.13), Vector3(0, 0, 180))
	# head
	var head := M3.pivot(torso, Vector3(0, 0.84, 0), "Head")
	j["head"] = head
	M3.sphere(head, 0.17, SKIN, Vector3.ZERO, Vector3(1, 1.05, 1))
	M3.dome(head, 0.18, HAIR, Vector3(0, 0.02, 0.01), Vector3(1, 0.9, 1.02))
	M3.box(head, Vector3(0.3, 0.06, 0.08), HAIR, Vector3(0, 0.08, -0.13))  # fringe
	for side in [-1, 1]:
		M3.sphere(head, 0.026, INK, Vector3(0.065 * side, 0.02, -0.155))
		M3.sphere(head, 0.035, SKIN, Vector3(0.17 * side, 0.0, 0.0))  # ears
	M3.sphere(head, 0.03, Color(0.72, 0.48, 0.33), Vector3(0, -0.03, -0.17))  # nose
	M3.box(head, Vector3(0.07, 0.012, 0.01), Color(0.45, 0.2, 0.18), Vector3(0, -0.085, -0.155))
	# arms (shoulder pivots)
	for side in [-1, 1]:
		var sh := M3.pivot(torso, Vector3(0.3 * side, 0.62, 0))
		M3.capsule(sh, 0.085, 0.3, shirt, Vector3(0, -0.12, 0))
		M3.capsule(sh, 0.065, 0.36, SKIN, Vector3(0, -0.38, 0))
		M3.sphere(sh, 0.075, SKIN, Vector3(0, -0.58, 0))
		j["sh_l" if side < 0 else "sh_r"] = sh
	# sumpak (bamboo air-gun) held in the right hand
	var gun := M3.pivot(j["sh_r"], Vector3(0, -0.58, 0), "Sumpak")
	M3.cylinder(gun, 0.045, 0.045, 0.7, Color(0.62, 0.48, 0.24), Vector3(0, 0, -0.22), Vector3(90, 0, 0), 10)
	for z in [-0.05, -0.3]:
		M3.cylinder(gun, 0.05, 0.05, 0.03, Color(0.42, 0.3, 0.15), Vector3(0, 0, z), Vector3(90, 0, 0), 10)
	gun.rotation_degrees = Vector3(80, 0, 0)
	j["gun"] = gun
	var muzzle := M3.pivot(gun, Vector3(0, 0, -0.6), "Muzzle")
	j["muzzle"] = muzzle
	# accessory slot
	j["hat"] = M3.pivot(head, Vector3(0, 0.12, 0), "Hat")
	return j

static func salakot(parent: Node3D) -> void:
	M3.cone(parent, 0.42, 0.22, Color(0.8, 0.64, 0.36), Vector3(0, 0.08, 0), Vector3.ZERO, 20)
	M3.sphere(parent, 0.04, Color(0.55, 0.4, 0.2), Vector3(0, 0.2, 0))

static func kerchief(parent: Node3D) -> void:
	M3.dome(parent, 0.19, Color(0.85, 0.2, 0.2), Vector3(0, -0.06, 0), Vector3(1, 0.7, 1))

# ================================================================ TYANAK ===
static func tyanak(root: Node3D) -> Dictionary:
	var j := {}
	var skin := Color(0.3, 0.4, 0.24)
	var dark := Color(0.22, 0.3, 0.17)
	var body := M3.pivot(root, Vector3(0, 0.3, 0), "Body")
	j["body"] = body
	M3.sphere(body, 0.26, skin, Vector3(0, 0, 0.08), Vector3(1, 0.8, 1.25))
	M3.sphere(body, 0.2, Color(0.86, 0.82, 0.72), Vector3(0, -0.04, 0.24), Vector3(1.1, 0.9, 0.8))  # cloth wrap
	var head := M3.pivot(body, Vector3(0, 0.14, -0.3), "Head")
	j["head"] = head
	M3.sphere(head, 0.25, skin)
	for side in [-1, 1]:
		M3.sphere(head, 0.06, Color(0.95, 0.12, 0.1), Vector3(0.09 * side, 0.05, -0.2), Vector3.ONE, 10)
		M3.sphere(head, 0.02, Color(1, 0.9, 0.8), Vector3(0.1 * side, 0.07, -0.25), Vector3.ONE, 6)
		M3.sphere(head, 0.07, skin, Vector3(0.24 * side, 0.02, 0), Vector3(0.6, 1, 1), 8)  # ears
	M3.box(head, Vector3(0.16, 0.05, 0.05), Color(0.3, 0.05, 0.05), Vector3(0, -0.09, -0.21))
	for x in [-0.05, 0.0, 0.05]:
		M3.cone(head, 0.015, 0.05, Color(1, 1, 0.95), Vector3(x, -0.08, -0.23), Vector3(180, 0, 0), 6)
	for k in range(4):
		M3.cylinder(head, 0.006, 0.01, 0.1, INK, Vector3(-0.06 + k * 0.04, 0.26, 0), Vector3(randf_range(-20, 20), 0, randf_range(-20, 20)), 4)
	var limbs := []
	for spec in [[-1, -0.18], [1, -0.18], [-1, 0.24], [1, 0.24]]:
		var p := M3.pivot(body, Vector3(0.18 * spec[0], -0.02, spec[1]))
		M3.capsule(p, 0.07, 0.3, dark, Vector3(0, -0.13, 0))
		M3.sphere(p, 0.07, skin, Vector3(0, -0.27, -0.03))
		limbs.append(p)
	j["limbs"] = limbs
	return j

# =========================================================== MANANANGGAL ===
const MN_SKIN := Color(0.88, 0.75, 0.7)
const MN_WING := Color(0.36, 0.08, 0.14)
const MN_DRESS := Color(0.5, 0.12, 0.18)

static func manananggal_upper(root: Node3D) -> Dictionary:
	var j := {}
	var body := M3.pivot(root, Vector3.ZERO, "Upper")
	j["body"] = body
	M3.capsule(body, 0.2, 0.62, MN_DRESS, Vector3(0, 0, 0))
	# ragged end of the severed torso
	for k in range(6):
		var a := TAU * k / 6.0
		M3.cone(body, 0.08, 0.26, MN_DRESS.darkened(0.3), Vector3(cos(a) * 0.12, -0.36, sin(a) * 0.12), Vector3(180, 0, 0), 5)
	M3.sphere(body, 0.19, MN_SKIN, Vector3(0, 0.25, -0.02), Vector3(1, 0.5, 0.9))  # shoulders
	var head := M3.pivot(body, Vector3(0, 0.5, 0), "Head")
	j["head"] = head
	M3.sphere(head, 0.16, MN_SKIN, Vector3.ZERO, Vector3(0.95, 1.1, 1))
	M3.dome(head, 0.18, HAIR, Vector3(0, 0.02, 0.02))
	M3.box(head, Vector3(0.36, 0.6, 0.14), HAIR, Vector3(0, -0.22, 0.1))  # long hair down the back
	for side in [-1, 1]:
		M3.box(head, Vector3(0.07, 0.03, 0.02), Color(1, 0.15, 0.1), Vector3(0.06 * side, 0.02, -0.15), Vector3(0, 0, -15 * side))
	M3.box(head, Vector3(0.08, 0.03, 0.02), Color(0.4, 0.05, 0.08), Vector3(0, -0.07, -0.15))
	for x in [-0.025, 0.025]:
		M3.cone(head, 0.01, 0.04, Color(1, 1, 0.95), Vector3(x, -0.08, -0.155), Vector3(180, 0, 0), 5)
	# clawed arms reaching forward
	for side in [-1, 1]:
		var sh := M3.pivot(body, Vector3(0.22 * side, 0.22, 0))
		M3.limb(sh, Vector3.ZERO, Vector3(0.08 * side, -0.1, -0.4), 0.05, MN_SKIN)
		for k in range(3):
			M3.cone(sh, 0.012, 0.09, INK, Vector3(0.08 * side + (k - 1) * 0.025, -0.12, -0.47), Vector3(-90, 0, 0), 4)
	# bat wings on shoulder pivots (flap by rotating z)
	var wings := []
	for side in [-1, 1]:
		var w := M3.pivot(body, Vector3(0.12 * side, 0.2, 0.12))
		var mem := M3.pivot(w, Vector3.ZERO)
		mem.scale = Vector3(side, 1, 1)
		for k in range(4):
			var ang := 20.0 - k * 22.0
			var L := 0.85 - k * 0.1
			M3.box(mem, Vector3(L, 0.02, 0.26), MN_WING, Vector3(L * 0.5, -k * 0.08, 0), Vector3(0, 0, ang))
			M3.limb(mem, Vector3.ZERO, Vector3(cos(deg_to_rad(ang)) * L, sin(deg_to_rad(ang)) * L - k * 0.08, 0), 0.025, MN_WING.darkened(0.4))
		wings.append(w)
	j["wings"] = wings
	return j

static func manananggal_lower(root: Node3D) -> Dictionary:
	var j := {}
	var body := M3.pivot(root, Vector3.ZERO, "Lower")
	j["body"] = body
	M3.cylinder(body, 0.2, 0.34, 0.6, MN_DRESS, Vector3(0, 0.78, 0), Vector3.ZERO, 12)  # saya skirt
	M3.cylinder(body, 0.17, 0.2, 0.08, MN_DRESS.darkened(0.45), Vector3(0, 1.1, 0), Vector3.ZERO, 10)
	for side in [-1, 1]:
		var hip := M3.pivot(body, Vector3(0.1 * side, 0.55, 0))
		M3.capsule(hip, 0.07, 0.55, MN_SKIN, Vector3(0, -0.25, 0))
		M3.box(hip, Vector3(0.1, 0.05, 0.2), INK, Vector3(0, -0.52, -0.04))
		j["hip_l" if side < 0 else "hip_r"] = hip
	return j

# ============================================================= TIKBALANG ===
static func tikbalang(root: Node3D) -> Dictionary:
	var j := {}
	var fur := Color(0.46, 0.31, 0.2)
	var dark := Color(0.34, 0.22, 0.14)
	var mane := Color(0.1, 0.08, 0.08)
	var body := M3.pivot(root, Vector3.ZERO, "Body")
	j["body"] = body
	for side in [-1, 1]:
		var hip := M3.pivot(body, Vector3(0.16 * side, 1.25, 0))
		M3.capsule(hip, 0.1, 0.7, dark, Vector3(0, -0.32, 0))
		var knee := M3.pivot(hip, Vector3(0, -0.66, 0))
		M3.capsule(knee, 0.075, 0.62, dark, Vector3(0, -0.28, 0.05))
		M3.cylinder(knee, 0.09, 0.11, 0.12, Color(0.15, 0.12, 0.1), Vector3(0, -0.6, 0.05), Vector3.ZERO, 8)  # hoof
		j["hip_l" if side < 0 else "hip_r"] = hip
		j["knee_l" if side < 0 else "knee_r"] = knee
	var torso := M3.pivot(body, Vector3(0, 1.25, 0), "Torso")
	j["torso"] = torso
	M3.capsule(torso, 0.26, 0.9, fur, Vector3(0, 0.42, 0), Vector3(-8, 0, 0))
	M3.cylinder(torso, 0.28, 0.3, 0.26, Color(0.3, 0.24, 0.16), Vector3(0, 0.04, 0), Vector3.ZERO, 10)  # bahag
	# long arms
	for side in [-1, 1]:
		var sh := M3.pivot(torso, Vector3(0.33 * side, 0.75, 0))
		M3.capsule(sh, 0.075, 0.6, fur, Vector3(0, -0.26, 0))
		M3.capsule(sh, 0.065, 0.55, fur, Vector3(0, -0.74, -0.06))
		for k in range(3):
			M3.cone(sh, 0.018, 0.12, INK, Vector3((k - 1) * 0.03, -1.05, -0.08), Vector3(170, 0, 0), 4)
		j["sh_l" if side < 0 else "sh_r"] = sh
	# horse head on a long neck
	var head := M3.pivot(torso, Vector3(0, 1.0, -0.05), "Head")
	j["head"] = head
	M3.capsule(head, 0.12, 0.45, fur, Vector3(0, 0.16, -0.06), Vector3(-25, 0, 0))
	M3.capsule(head, 0.13, 0.62, fur, Vector3(0, 0.36, -0.28), Vector3(-75, 0, 0))  # long snout
	M3.sphere(head, 0.12, fur.darkened(0.25), Vector3(0, 0.28, -0.56), Vector3(1, 0.8, 1))
	for side in [-1, 1]:
		M3.cone(head, 0.05, 0.16, fur, Vector3(0.08 * side, 0.55, -0.08), Vector3(-10, 0, 15 * side), 6)
		M3.sphere(head, 0.035, Color(1, 0.82, 0.25), Vector3(0.11 * side, 0.43, -0.2), Vector3.ONE, 8)
		M3.sphere(head, 0.02, INK, Vector3(0.05 * side, 0.27, -0.66), Vector3.ONE, 6)
	M3.box(head, Vector3(0.06, 0.5, 0.36), mane, Vector3(0, 0.34, 0.1), Vector3(20, 0, 0))  # mane
	M3.box(torso, Vector3(0.08, 0.6, 0.12), mane, Vector3(0, 0.62, 0.22), Vector3(10, 0, 0))
	return j

# ================================================================= KAPRE ===
static func kapre(root: Node3D) -> Dictionary:
	var j := {}
	var skin := Color(0.29, 0.21, 0.16)
	var hair := Color(0.14, 0.11, 0.09)
	var body := M3.pivot(root, Vector3.ZERO, "Body")
	j["body"] = body
	for side in [-1, 1]:
		M3.capsule(body, 0.36, 2.0, skin.darkened(0.2), Vector3(0.5 * side, 1.0, 0))
		M3.box(body, Vector3(0.6, 0.25, 0.8), hair, Vector3(0.5 * side, 0.12, -0.1))
	var torso := M3.pivot(body, Vector3(0, 1.9, 0), "Torso")
	j["torso"] = torso
	M3.sphere(torso, 1.0, skin, Vector3(0, 0.9, 0), Vector3(1.05, 1.2, 0.8))
	# shaggy hair tufts all over
	for k in range(26):
		var a := randf() * TAU
		var y := randf_range(0.2, 1.8)
		M3.cone(torso, 0.12, 0.4, hair, Vector3(cos(a) * 0.95, y, sin(a) * 0.7), Vector3(randf_range(150, 210), 0, randf_range(-20, 20)), 5)
	M3.cylinder(torso, 1.0, 1.02, 0.3, Color(0.6, 0.17, 0.15), Vector3(0, 0.12, 0), Vector3.ZERO, 16)  # bahag
	M3.box(torso, Vector3(0.5, 0.7, 0.1), Color(0.6, 0.17, 0.15), Vector3(0, -0.2, -0.72))
	M3.cylinder(torso, 1.02, 1.03, 0.06, Color(0.9, 0.72, 0.3), Vector3(0, 0.2, 0), Vector3.ZERO, 16)
	for side in [-1, 1]:
		var sh := M3.pivot(torso, Vector3(1.05 * side, 1.5, 0))
		M3.capsule(sh, 0.28, 1.2, skin, Vector3(0.1 * side, -0.5, 0))
		M3.capsule(sh, 0.24, 1.1, skin, Vector3(0.15 * side, -1.4, -0.1))
		M3.sphere(sh, 0.3, skin.darkened(0.15), Vector3(0.15 * side, -2.0, -0.1))
		j["sh_l" if side < 0 else "sh_r"] = sh
	var head := M3.pivot(torso, Vector3(0, 2.25, -0.1), "Head")
	j["head"] = head
	M3.sphere(head, 0.9, hair, Vector3(0, 0.1, 0.15), Vector3(1.1, 1.0, 1.0))  # wild mane
	M3.sphere(head, 0.62, skin, Vector3(0, 0, -0.2))
	M3.sphere(head, 0.5, hair, Vector3(0, -0.4, -0.35), Vector3(1.1, 1.1, 0.8))  # beard
	for side in [-1, 1]:
		M3.sphere(head, 0.11, Color(1, 0.72, 0.2), Vector3(0.22 * side, 0.12, -0.72), Vector3.ONE, 10)
		M3.sphere(head, 0.05, Color(0.5, 0.1, 0.02), Vector3(0.22 * side, 0.12, -0.8), Vector3.ONE, 8)
		M3.box(head, Vector3(0.3, 0.07, 0.08), hair, Vector3(0.22 * side, 0.3, -0.72), Vector3(0, 0, -18 * side))
	var eye_light := OmniLight3D.new()
	eye_light.light_color = Color(1, 0.6, 0.2)
	eye_light.light_energy = 1.5
	eye_light.omni_range = 2.5
	eye_light.position = Vector3(0, 0.1, -1.0)
	head.add_child(eye_light)
	# tabako with a glowing ember
	var cigar := M3.pivot(head, Vector3(0.18, -0.22, -0.72), "Cigar")
	M3.cylinder(cigar, 0.05, 0.05, 0.6, Color(0.55, 0.36, 0.2), Vector3(0.12, 0, -0.25), Vector3(90, 25, 0), 8)
	var ember := M3.sphere(cigar, 0.06, M3.mat(Color(1, 0.45, 0.1), 0.5, 4.0), Vector3(0.24, 0, -0.52), Vector3.ONE, 8)
	j["ember"] = ember
	return j

# ============================================================ BALETE TREE ===
static func balete(root: Node3D) -> Dictionary:
	var j := {}
	var bark := M3.noise_mat(Color(0.3, 0.22, 0.15), Color(0.45, 0.34, 0.24), 0.08, 0.6)
	var leaf := Color(0.19, 0.4, 0.2)
	var trunk := M3.pivot(root, Vector3.ZERO, "Trunk")
	j["trunk"] = trunk
	M3.cylinder(trunk, 1.1, 1.8, 7.0, bark, Vector3(0, 3.5, 0), Vector3.ZERO, 14)
	# braided aerial roots
	for k in range(12):
		var a := TAU * k / 12.0 + randf() * 0.2
		var top := Vector3(cos(a) * 0.9, randf_range(4.5, 6.5), sin(a) * 0.9)
		var foot := Vector3(cos(a) * randf_range(2.0, 2.8), 0, sin(a) * randf_range(2.0, 2.8))
		M3.limb(trunk, top, foot, randf_range(0.12, 0.22), bark)
	# huge crown
	for k in range(9):
		var a := TAU * k / 9.0
		var r := randf_range(2.2, 3.6)
		M3.sphere(trunk, randf_range(2.2, 3.0), leaf.lightened(randf_range(0, 0.15)), Vector3(cos(a) * r, 8.2 + randf_range(-0.6, 1.2), sin(a) * r), Vector3(1, 0.75, 1), 12)
	M3.sphere(trunk, 3.4, leaf, Vector3(0, 9.6, 0), Vector3(1, 0.7, 1), 14)
	# hanging vines
	for k in range(14):
		var a := randf() * TAU
		var r := randf_range(2.0, 4.5)
		var L := randf_range(1.5, 3.5)
		M3.cylinder(trunk, 0.03, 0.03, L, leaf.darkened(0.3), Vector3(cos(a) * r, 7.0 - L * 0.5, sin(a) * r), Vector3.ZERO, 4, false)
	return j

# ================================================================ JEEPNEY ===
static func jeepney(root: Node3D) -> Dictionary:
	var j := {}
	var red := M3.mat(Color(0.8, 0.14, 0.16), 0.45)
	var red_dark := Color(0.55, 0.08, 0.1)
	var yellow := Color(0.98, 0.78, 0.2)
	var blue := Color(0.15, 0.36, 0.75)
	var chrome := M3.mat(Color(0.86, 0.88, 0.92), 0.2, 0.0, 0.9)
	var glass := M3.mat(Color(0.6, 0.8, 0.9, 0.7), 0.1)
	var body := M3.pivot(root, Vector3.ZERO, "Jeep")
	j["body"] = body
	# passenger cabin (long axis = Z, front at -Z)
	M3.box(body, Vector3(2.0, 1.3, 4.6), red, Vector3(0, 1.35, 0.6))
	M3.box(body, Vector3(2.04, 0.12, 4.64), yellow, Vector3(0, 1.1, 0.6))
	M3.box(body, Vector3(2.05, 0.08, 4.65), blue, Vector3(0, 0.98, 0.6))
	M3.box(body, Vector3(2.02, 0.3, 4.62), red_dark, Vector3(0, 0.75, 0.6))
	for k in range(5):
		for side in [-1, 1]:
			M3.box(body, Vector3(0.02, 0.5, 0.7), glass, Vector3(1.01 * side, 1.62, -1.1 + k * 0.85))
			M3.sphere(body, 0.07, [yellow, Color.WHITE, blue][k % 3], Vector3(1.02 * side, 0.82, -1.2 + k * 0.85), Vector3.ONE, 8)
	# roof with chrome rack, flags and signboard
	M3.box(body, Vector3(2.2, 0.12, 4.9), chrome, Vector3(0, 2.07, 0.55))
	M3.box(body, Vector3(1.6, 0.35, 0.08), Color(0.98, 0.95, 0.85), Vector3(0, 2.3, -1.75))
	for k in range(6):
		var fx := -0.9 + k * 0.36
		M3.cylinder(body, 0.012, 0.012, 0.45, Color(0.3, 0.3, 0.3), Vector3(fx, 2.35, 2.8), Vector3.ZERO, 4)
		M3.box(body, Vector3(0.02, 0.14, 0.22), [yellow, blue, Color(0.85, 0.15, 0.15)][k % 3], Vector3(fx, 2.5, 2.9))
	# hood + grille + headlights + silver horse
	M3.box(body, Vector3(1.8, 0.75, 1.4), chrome, Vector3(0, 1.0, -2.35))
	M3.box(body, Vector3(1.9, 0.9, 0.12), chrome, Vector3(0, 1.0, -3.08))
	for k in range(6):
		M3.box(body, Vector3(1.4, 0.04, 0.02), Color(0.3, 0.3, 0.32), Vector3(0, 0.75 + k * 0.08, -3.15))
	for side in [-1, 1]:
		M3.cylinder(body, 0.14, 0.14, 0.08, M3.mat(Color(1, 0.95, 0.75), 0.3, 1.5), Vector3(0.7 * side, 1.25, -3.15), Vector3(90, 0, 0), 12)
	M3.box(body, Vector3(1.9, 0.6, 0.05), glass, Vector3(0, 1.75, -1.68), Vector3(-15, 0, 0))
	var horse := M3.pivot(body, Vector3(0, 1.42, -2.8))
	M3.capsule(horse, 0.06, 0.3, chrome, Vector3(0, 0.1, 0), Vector3(-30, 0, 0))
	M3.capsule(horse, 0.05, 0.22, chrome, Vector3(0, 0.25, -0.1), Vector3(-80, 0, 0))
	M3.box(body, Vector3(2.1, 0.12, 0.2), chrome, Vector3(0, 0.6, -3.2))  # bumper
	M3.box(body, Vector3(2.1, 0.12, 0.2), chrome, Vector3(0, 0.6, 2.95))
	# rear entrance step
	M3.box(body, Vector3(1.0, 0.08, 0.4), chrome, Vector3(0, 0.55, 3.1))
	# wheels
	var wheels := []
	for z in [-2.2, 1.9]:
		for side in [-1, 1]:
			var w := M3.pivot(body, Vector3(1.02 * side, 0.45, z))
			M3.cylinder(w, 0.45, 0.45, 0.3, Color(0.1, 0.1, 0.1), Vector3.ZERO, Vector3(0, 0, 90), 16)
			M3.cylinder(w, 0.24, 0.24, 0.32, chrome, Vector3.ZERO, Vector3(0, 0, 90), 12)
			wheels.append(w)
	j["wheels"] = wheels
	# driver silhouette in the cab
	M3.sphere(body, 0.18, SKIN, Vector3(0.45, 1.9, -1.3))
	M3.dome(body, 0.19, Color(0.9, 0.25, 0.2), Vector3(0.45, 1.95, -1.3))
	M3.capsule(body, 0.22, 0.6, Color(0.24, 0.43, 0.67), Vector3(0.45, 1.5, -1.25))
	return j

# ================================================================= PROPS ===
static func palm(parent: Node3D, pos: Vector3, height: float = 7.0, lean: Vector3 = Vector3(0.12, 0, 0.05)) -> Node3D:
	var root := M3.pivot(parent, pos)
	var trunk_mat := M3.noise_mat(Color(0.42, 0.32, 0.22), Color(0.58, 0.46, 0.32), 0.3, 2.0)
	var segs := 7
	var prev := Vector3.ZERO
	for i in range(1, segs + 1):
		var t := float(i) / segs
		var p := Vector3(lean.x * height * t * t, height * t, lean.z * height * t * t)
		M3.limb(root, prev, p, 0.2 - t * 0.07, trunk_mat)
		prev = p
	var leaf := Color(0.2, 0.48, 0.22)
	for k in range(9):
		var a := TAU * k / 9.0 + randf() * 0.2
		var frond := M3.pivot(root, prev)
		frond.rotation = Vector3(0, a, 0)
		var droop := M3.pivot(frond, Vector3.ZERO)
		droop.rotation_degrees = Vector3(0, 0, -18 - randf() * 25)
		M3.box(droop, Vector3(2.6, 0.03, 0.55), leaf.lightened(randf() * 0.12), Vector3(1.25, -0.25, 0), Vector3(0, 0, -12))
	for k in range(3):
		M3.sphere(root, 0.16, Color(0.36, 0.26, 0.12), prev + Vector3(cos(k * 2.1) * 0.2, -0.25, sin(k * 2.1) * 0.2), Vector3.ONE, 8)
	return root

static func pine(parent: Node3D, pos: Vector3, height: float = 6.0) -> Node3D:
	var root := M3.pivot(parent, pos)
	M3.cylinder(root, 0.12, 0.2, height * 0.35, Color(0.36, 0.25, 0.17), Vector3(0, height * 0.17, 0), Vector3.ZERO, 8)
	var green := Color(0.14, 0.34, 0.2)
	for k in range(3):
		var r := height * (0.32 - k * 0.07)
		M3.cone(root, r, height * 0.45, green.lightened(k * 0.06), Vector3(0, height * (0.35 + k * 0.2), 0), Vector3.ZERO, 10)
	return root

static func round_tree(parent: Node3D, pos: Vector3, size: float = 3.0, leaf: Color = Color(0.22, 0.46, 0.22)) -> Node3D:
	var root := M3.pivot(parent, pos)
	M3.cylinder(root, size * 0.07, size * 0.11, size * 0.9, Color(0.36, 0.26, 0.18), Vector3(0, size * 0.45, 0), Vector3.ZERO, 8)
	for k in range(4):
		var a := TAU * k / 4.0 + randf()
		M3.sphere(root, size * randf_range(0.42, 0.55), leaf.lightened(randf() * 0.12), Vector3(cos(a) * size * 0.3, size * 1.05 + randf() * size * 0.25, sin(a) * size * 0.3), Vector3(1, 0.85, 1), 10)
	return root

static func ifugao_house(parent: Node3D, pos: Vector3, s: float = 1.0) -> Node3D:
	var root := M3.pivot(parent, pos)
	root.scale = Vector3.ONE * s
	var wood := Color(0.36, 0.23, 0.14)
	for x in [-1, 1]:
		for z in [-1, 1]:
			M3.cylinder(root, 0.12, 0.14, 1.6, wood.darkened(0.2), Vector3(x * 1.0, 0.8, z * 1.0), Vector3.ZERO, 8)
			M3.cylinder(root, 0.28, 0.28, 0.06, wood.darkened(0.4), Vector3(x * 1.0, 1.35, z * 1.0), Vector3.ZERO, 10)  # rat guard disk
	M3.box(root, Vector3(2.4, 0.9, 2.4), wood, Vector3(0, 2.0, 0))
	M3.cone(root, 2.4, 3.2, M3.noise_mat(Color(0.55, 0.43, 0.25), Color(0.7, 0.58, 0.36), 0.4, 3.0), Vector3(0, 3.95, 0), Vector3(0, 45, 0), 4)
	M3.box(root, Vector3(0.5, 0.7, 0.05), Color(0.2, 0.13, 0.08), Vector3(0, 1.95, -1.23))
	return root

static func nipa_hut(parent: Node3D, pos: Vector3, rot_y: float = 0.0, s: float = 1.0) -> Node3D:
	var root := M3.pivot(parent, pos)
	root.rotation_degrees.y = rot_y
	root.scale = Vector3.ONE * s
	var bamboo := Color(0.72, 0.6, 0.35)
	for x in [-1, 1]:
		for z in [-1, 1]:
			M3.cylinder(root, 0.08, 0.08, 1.2, bamboo.darkened(0.2), Vector3(x * 1.2, 0.6, z * 1.0), Vector3.ZERO, 6)
	M3.box(root, Vector3(2.7, 1.4, 2.3), M3.noise_mat(Color(0.62, 0.5, 0.3), Color(0.78, 0.66, 0.42), 0.6, 4.0), Vector3(0, 1.9, 0))
	M3.prism(root, Vector3(3.4, 1.6, 2.9), M3.noise_mat(Color(0.5, 0.4, 0.22), Color(0.68, 0.56, 0.32), 0.5, 3.0), Vector3(0, 3.4, 0))
	M3.box(root, Vector3(0.7, 1.0, 0.05), Color(0.25, 0.17, 0.1), Vector3(0.4, 1.8, -1.16))
	M3.box(root, Vector3(0.6, 0.5, 0.05), Color(0.2, 0.14, 0.08), Vector3(-0.7, 2.1, -1.16))
	return root

static func bahay_na_bato(parent: Node3D, pos: Vector3, rot_y: float = 0.0, width: float = 6.0) -> Node3D:
	var root := M3.pivot(parent, pos)
	root.rotation_degrees.y = rot_y
	var stone := M3.noise_mat(Color(0.7, 0.62, 0.5), Color(0.82, 0.74, 0.6), 0.2, 1.0)
	var wood := Color(0.42, 0.24, 0.14)
	M3.box(root, Vector3(width, 2.4, 4.0), stone, Vector3(0, 1.2, 0))
	for k in range(int(width / 1.6)):
		M3.box(root, Vector3(0.8, 1.5, 0.06), Color(0.22, 0.15, 0.12), Vector3(-width * 0.5 + 0.9 + k * 1.6, 1.0, -2.02))
	M3.box(root, Vector3(width + 0.6, 2.0, 4.4), wood, Vector3(0, 3.4, -0.2))
	var capiz := M3.mat(Color(0.98, 0.92, 0.75), 0.4, 0.35)
	for k in range(int(width / 1.1)):
		M3.box(root, Vector3(0.85, 1.2, 0.06), capiz, Vector3(-width * 0.5 + 0.7 + k * 1.1, 3.45, -2.43))
		M3.box(root, Vector3(0.05, 1.2, 0.08), wood.darkened(0.3), Vector3(-width * 0.5 + 0.7 + k * 1.1, 3.45, -2.45))
	M3.box(root, Vector3(width + 1.0, 0.15, 0.6), wood.darkened(0.3), Vector3(0, 2.4, -2.5))
	M3.prism(root, Vector3(width + 1.2, 1.4, 5.2), Color(0.62, 0.24, 0.16), Vector3(0, 5.1, -0.2))
	return root

static func lamp_post(parent: Node3D, pos: Vector3, with_light: bool = true) -> Node3D:
	var root := M3.pivot(parent, pos)
	var iron := Color(0.12, 0.12, 0.14)
	M3.cylinder(root, 0.06, 0.1, 3.4, iron, Vector3(0, 1.7, 0), Vector3.ZERO, 8)
	M3.box(root, Vector3(0.36, 0.5, 0.36), M3.mat(Color(1, 0.86, 0.55), 0.3, 2.5), Vector3(0, 3.6, 0))
	M3.cone(root, 0.3, 0.3, iron, Vector3(0, 4.0, 0), Vector3.ZERO, 4)
	if with_light:
		var l := OmniLight3D.new()
		l.light_color = Color(1, 0.8, 0.5)
		l.light_energy = 1.6
		l.omni_range = 7.0
		l.position = Vector3(0, 3.5, 0)
		root.add_child(l)
	return root

static func paraw(parent: Node3D, pos: Vector3, sail: Color, rot_y: float = 0.0) -> Node3D:
	var root := M3.pivot(parent, pos)
	root.rotation_degrees.y = rot_y
	var hull := Color(0.35, 0.22, 0.14)
	M3.capsule(root, 0.35, 5.0, hull, Vector3(0, 0.2, 0), Vector3(90, 0, 0))
	for side in [-1, 1]:
		M3.cylinder(root, 0.08, 0.08, 5.5, hull.lightened(0.2), Vector3(2.2 * side, 0.1, 0), Vector3(90, 0, 0), 6)
	for z in [-1.2, 1.2]:
		M3.box(root, Vector3(4.6, 0.08, 0.1), hull, Vector3(0, 0.45, z))
	M3.cylinder(root, 0.06, 0.06, 5.0, hull, Vector3(0, 2.7, 0), Vector3.ZERO, 6)
	M3.prism(root, Vector3(0.05, 4.2, 3.2), sail, Vector3(0, 3.0, 0.8), Vector3(0, 90, 0))
	return root

static func rock(parent: Node3D, pos: Vector3, size: float, color: Color = Color(0.45, 0.42, 0.4)) -> MeshInstance3D:
	var mi := M3.sphere(parent, size, color, pos, Vector3(randf_range(0.8, 1.3), randf_range(0.5, 0.8), randf_range(0.8, 1.3)), 7)
	mi.rotation = Vector3(randf(), randf() * TAU, randf())
	return mi
