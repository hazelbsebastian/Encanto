class_name Enemy3D
extends CharacterBody3D
## Shared 3D creature plumbing: health, floating health bar, hit flash and
## knock-back, attack hitboxes (layer 8, the only thing that hurts the
## player), creepy positional voice, death animation and the puzzle-piece
## pop-up. Concrete creatures override _build() and _think(delta).

signal defeated

const GRAVITY := 22.0

var max_health: int = 3
var health: int = 3
var enemy_id: String = "enemy"
var is_dead: bool = false
var aim_height: float = 0.8
var target_size: float = 1.0
var voice_id: String = ""
var voice_interval: Vector2 = Vector2(6, 11)

var model: Node3D
var j: Dictionary = {}
var _bar: Label3D
var _voice_t: float = 0.0
var _anim_t: float = 0.0
var _stun: float = 0.0

func _ready() -> void:
	add_to_group("enemies")
	collision_layer = 2
	collision_mask = 16
	model = M3.pivot(self, Vector3.ZERO, "Model")
	_build()
	health = max_health
	_bar = Label3D.new()
	_bar.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_bar.no_depth_test = true
	_bar.font_size = 48
	_bar.pixel_size = 0.005
	_bar.outline_size = 8
	_bar.modulate = Color(1, 0.35, 0.3)
	_bar.position = Vector3(0, aim_height * 1.25 + 0.6, 0)
	add_child(_bar)
	_update_bar()
	_voice_t = randf_range(1.0, voice_interval.x)
	# spawn "pop" so creatures don't just blink into existence
	model.scale = Vector3.ONE * 0.1
	create_tween().tween_property(model, "scale", Vector3.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	FX.puff(get_parent(), global_position + Vector3(0, 0.4, 0), Color(0.5, 0.45, 0.55), 0.8, 8)

## Build the model + collision + hit areas. Override.
func _build() -> void:
	pass

## AI for one physics frame. Override.
func _think(_delta: float) -> void:
	pass

func add_body_shape(shape: Shape3D, pos: Vector3) -> void:
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position = pos
	add_child(cs)

func add_hit_area(shape: Shape3D, pos: Vector3, parent: Node3D = null) -> Area3D:
	var area := Area3D.new()
	area.set_script(preload("res://scripts/3d/EnemyHit3D.gd"))
	area.set("owner_enemy", self)
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position = pos
	area.add_child(cs)
	(parent if parent else self).add_child(area)
	return area

func player() -> Node3D:
	return get_tree().get_first_node_in_group("player") as Node3D

func get_aim_point() -> Vector3:
	return global_position + Vector3(0, aim_height, 0)

func get_target_size() -> float:
	return target_size

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	_anim_t += delta
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	if _stun > 0.0:
		_stun -= delta
		velocity.x = move_toward(velocity.x, 0, 20 * delta)
		velocity.z = move_toward(velocity.z, 0, 20 * delta)
	else:
		_think(delta)
	move_and_slide()
	_keep_in_arena()
	_voice_t -= delta
	if _voice_t <= 0.0 and voice_id != "":
		_voice_t = randf_range(voice_interval.x, voice_interval.y)
		Audio.voice_3d(voice_id, get_aim_point(), 0.0, randf_range(0.9, 1.1))

func _keep_in_arena() -> void:
	var level := get_tree().get_first_node_in_group("level")
	var r: float = float(level.get("arena_radius")) + 2.0 if level else 30.0
	var flat := Vector2(global_position.x, global_position.z)
	if flat.length() > r:
		flat = flat.normalized() * r
		global_position.x = flat.x
		global_position.z = flat.y

## Turn the model toward a point (flat), returns the flat direction.
func face(point: Vector3, delta: float, speed: float = 8.0) -> Vector3:
	var d := point - global_position
	d.y = 0
	if d.length() < 0.01:
		return Vector3.ZERO
	d = d.normalized()
	model.rotation.y = lerp_angle(model.rotation.y, atan2(-d.x, -d.z), clampf(speed * delta, 0, 1))
	return d

func forward() -> Vector3:
	return -model.global_transform.basis.z.normalized()

func take_damage(amount: int, _is_charged: bool = false, at: Vector3 = Vector3.ZERO) -> void:
	if is_dead:
		return
	health -= amount
	M3.flash(model)
	FX.popup_text(get_parent(), get_aim_point() + Vector3(0, 0.5, 0), "-%d" % amount)
	var push := global_position - (at if at != Vector3.ZERO else global_position + forward())
	push.y = 0
	velocity += push.normalized() * 4.0 + Vector3.UP * 2.0
	_stun = 0.18
	_update_bar()
	if health <= 0:
		_die()

func _update_bar() -> void:
	var s := ""
	for i in range(max_health):
		s += "■" if i < health else "□"
	_bar.text = s

func _die() -> void:
	if is_dead:
		return
	is_dead = true
	remove_from_group("enemies")
	collision_layer = 0
	for c in get_children():
		if c is Area3D:
			c.queue_free()
	_bar.visible = false
	Audio.play_3d("enemy_defeat", get_aim_point())
	GameManager.register_enemy_defeated()
	var piece := GameManager.portrait_piece(GameManager.next_creature(), GameManager.puzzle_pieces - 1)
	FX.piece_popup(get_parent(), get_aim_point() + Vector3(0, 0.6, 0), piece)
	_play_death()
	defeated.emit()
	get_tree().create_timer(1.6, false).timeout.connect(queue_free)

## Default death: topple over, sink and shrink.
func _play_death() -> void:
	var tw := create_tween()
	tw.tween_property(model, "rotation_degrees:x", 90.0, 0.4).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.5)
	tw.tween_property(model, "scale", Vector3.ONE * 0.01, 0.5)
	FX.puff(get_parent(), global_position + Vector3(0, 0.4, 0), Color(0.4, 0.35, 0.45), 0.9, 10)

## Temporary attack hitbox on layer 8, placed relative to the model facing.
func spawn_attack_hitbox(local_offset: Vector3, size: Vector3, lifetime: float = 0.3, follow: bool = false) -> Area3D:
	var area := Area3D.new()
	area.collision_layer = 8
	area.collision_mask = 0
	area.monitoring = false
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	area.add_child(cs)
	if follow:
		model.add_child(area)
		area.position = local_offset
	else:
		get_parent().add_child(area)
		area.global_transform = Transform3D(model.global_transform.basis.orthonormalized(), model.global_transform * local_offset)
	Audio.play_3d("enemy_attack", global_position, -2.0)
	get_tree().create_timer(lifetime, false).timeout.connect(area.queue_free)
	return area
