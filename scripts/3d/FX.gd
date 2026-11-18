class_name FX
extends RefCounted
## One-shot 3D effects built from tweens (no particle assets needed).

## Expanding, fading puff of little spheres - impacts, dust, smoke.
static func puff(parent: Node, pos: Vector3, color: Color = Color(0.9, 0.85, 0.75), size: float = 0.4, count: int = 6) -> void:
	if parent == null or not (parent is Node3D or parent is Node):
		return
	var root := Node3D.new()
	parent.add_child(root)
	root.global_position = pos
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for i in range(count):
		var s := M3.sphere(root, size * randf_range(0.35, 0.6), m, Vector3.ZERO, Vector3.ONE, 8)
		s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var d := Vector3(randf_range(-1, 1), randf_range(0.2, 1.2), randf_range(-1, 1)).normalized() * size * randf_range(1.5, 3.0)
		var tw := s.create_tween().set_parallel(true)
		tw.tween_property(s, "position", d, 0.45).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		tw.tween_property(s, "scale", Vector3.ONE * 1.8, 0.45)
	var fade := root.create_tween()
	fade.tween_property(m, "albedo_color:a", 0.0, 0.45)
	fade.tween_callback(root.queue_free)

## A picture piece that pops out of a defeated creature, spins and rises -
## a 3D reminder that each kill collects one puzzle piece.
static func piece_popup(parent: Node, pos: Vector3, texture: Texture2D) -> void:
	if texture == null:
		return
	var s := Sprite3D.new()
	s.texture = texture
	s.pixel_size = 0.9 / maxf(1.0, float(texture.get_width()))
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	s.shaded = false
	s.no_depth_test = true
	s.render_priority = 5
	parent.add_child(s)
	s.global_position = pos
	var glow := OmniLight3D.new()
	glow.light_color = Color(1, 0.85, 0.4)
	glow.light_energy = 2.0
	glow.omni_range = 3.0
	s.add_child(glow)
	s.scale = Vector3.ONE * 0.2
	var tw := s.create_tween()
	tw.tween_property(s, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(s, "position:y", s.position.y + 2.2, 1.1).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(s, "modulate:a", 0.0, 1.1).set_delay(0.3)
	tw.tween_callback(s.queue_free)

## Floating damage / info text in the world.
static func popup_text(parent: Node, pos: Vector3, text: String, color: Color = Color(1, 0.9, 0.4)) -> void:
	var l := Label3D.new()
	l.text = text
	l.modulate = color
	l.outline_modulate = Color(0.15, 0.05, 0.02)
	l.outline_size = 10
	l.font_size = 64
	l.pixel_size = 0.006
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	parent.add_child(l)
	l.global_position = pos
	var tw := l.create_tween()
	tw.tween_property(l, "position:y", l.position.y + 1.2, 0.8).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.8).set_delay(0.3)
	tw.tween_callback(l.queue_free)
