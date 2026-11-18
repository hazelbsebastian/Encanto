class_name UIKit
extends RefCounted
## Small helpers for building themed pop-ups in code (puzzle, pause menu...).
## Styling itself comes from assets/ui/encanto_theme.tres (project theme);
## these helpers only pick the right theme variations and wire up layout.

## Full-screen translucent backdrop that also swallows clicks/taps.
static func dim(parent: Node, alpha: float = 0.72) -> ColorRect:
	var c := ColorRect.new()
	c.color = Color(0.03, 0.02, 0.05, alpha)
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(c)
	return c

## A themed panel centred on screen. Returns the panel; add a VBox to it.
static func centered_panel(parent: Node, min_size: Vector2 = Vector2.ZERO) -> PanelContainer:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = min_size
	center.add_child(panel)
	return panel

static func vbox(parent: Node, separation: int = 14) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", separation)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	parent.add_child(v)
	return v

static func hbox(parent: Node, separation: int = 14) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", separation)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	parent.add_child(h)
	return h

## variation: "", "TitleLabel", "HeaderLabel", "AccentLabel", "HintLabel", "HudLabel"
static func label(parent: Node, text: String, variation: String = "", font_size: int = 0, wrap: bool = true) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if variation != "":
		l.theme_type_variation = variation
	if font_size > 0:
		l.add_theme_font_size_override("font_size", font_size)
	parent.add_child(l)
	return l

static func button(parent: Node, text: String, gold: bool = false, min_height: float = 50.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, min_height)
	if gold:
		b.theme_type_variation = "GoldButton"
	b.focus_mode = Control.FOCUS_ALL
	parent.add_child(b)
	return b

## Soft "pop" entrance: fade + slight zoom from the centre. (Scale is used
## rather than position because containers own their children's position.)
## Works while the tree is paused as long as the owner processes when paused.
static func pop_in(node: Control, delay: float = 0.0) -> void:
	node.modulate.a = 0.0
	node.scale = Vector2(0.9, 0.9)
	var tw := node.create_tween()
	tw.tween_interval(delay)
	tw.tween_callback(func() -> void: node.pivot_offset = node.size * 0.5)
	tw.set_parallel(true)
	tw.tween_property(node, "modulate:a", 1.0, 0.2)
	tw.tween_property(node, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## Small key-cap style hint, e.g. "ENTER" - shown next to on-screen actions
## so keyboard players know which key does the same thing as the tap.
static func key_hint(parent: Node, text: String) -> Label:
	var l := label(parent, text, "HintLabel", 13, false)
	l.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.06, 0.04, 0.75)
	sb.border_color = Color(0.86, 0.64, 0.26, 0.8)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 7
	sb.content_margin_right = 7
	sb.content_margin_top = 1
	sb.content_margin_bottom = 2
	l.add_theme_stylebox_override("normal", sb)
	return l
