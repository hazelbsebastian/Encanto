extends Control
## Title screen. Fully keyboard-driven (arrows/WASD + Enter, Esc closes the
## settings panel) as well as touch/mouse.

@onready var money_label: Label = $MoneyChip/Row/MoneyLabel
@onready var title_label: Label = $VBox/TitleLabel
@onready var play_button: Button = $VBox/PlayButton
@onready var settings_button: Button = $VBox/MenuGrid/SettingsButton
@onready var settings_dim: ColorRect = $SettingsDim
@onready var settings_panel: PanelContainer = $SettingsPanel
@onready var volume_slider: HSlider = $SettingsPanel/VBox/VolumeSlider
@onready var close_button: Button = $SettingsPanel/VBox/CloseButton
@onready var farmer: TextureRect = $Farmer

static var _welcomed: bool = false
## Week 17 (PT7): instructions and credits, opened from the settings panel.
var _info: CanvasLayer = null

const HOW_TO_PLAY := """LAYUNIN
Sumakay sa jeepney papunta sa isa sa limang lugar sa Pilipinas. Talunin ang 4 na Tyanak, 4 na Manananggal at 4 na Tikbalang, saka patumbahin ang puno ng balete ng Kapre para manalo.

PAANO
1. PLAY - piliin ang lugar ("San punta mo?") at sumakay.
2. Batuhin ang mga nilalang gamit ang TIRA. Kusa itong tumututok sa pinakamalapit (gintong bilog).
3. Bawat natalong nilalang ay may iniiwang piraso ng larawan. Pagkatapos ng bawat yugto, ayusin ang 4 na piraso para makilala ang susunod na kalaban.
4. 5 sunod-sunod na tira = CHARGE READY. Hawakan ang TIRA para mag-charge, bitawan para ibato. Ito lang ang nakakasira sa puno ng Kapre.
5. May 5 PUSO ka. Kapag naubos: Game Over - pwedeng subukan ulit.
6. Kapag nanalo: piliin ang PERA (P500) o ang BAYONG (random na damit). Gamitin sa WARDROBE.

KONTROL - TOUCH
Joystick sa kaliwa = galaw  |  TIRA at TALON sa kanan  |  i-drag ang screen = camera  |  II = hinto

KONTROL - KEYBOARD
Galaw: W A S D o arrow keys  |  Talon: SPACE (double jump mula sa Tikbalang)
Tira: X (hawakan para mag-charge)  |  Camera: Q / E  |  Hinto: ESC o P
Menu: arrow keys + ENTER, ESC = bumalik

PAG-SAVE
Naka-save ang pera at mga damit sa iyong profile sa device na ito lamang (walang internet). Kapag nawala sa focus ang app (tawag, home button), kusang humihinto ang laro."""

const CREDITS := """ENCANTO  -  version %s
Isang laro tungkol sa mga nilalang ng alamat ng Pilipinas.
Theme: Philippine Games and Sports

GAME DESIGN AT DEVELOPMENT
Hazel B. Sebastian  -  BSIT-4A
MOBILE DEV 002 - Advanced Mobile Application Development

ENGINE
Godot Engine %s - MIT License (full text below)

ART AT 3D MODELS
Lahat ng 2D art ay ginawa ng sariling Python/Pillow scripts ng proyekto (gen_scripts/). Ang mga 3D na tauhan, hayop at lugar ay binuo sa code mula sa simpleng hugis (M3.gd, Models.gd, MapBuilder3D.gd). Walang third-party na art.

MUSIKA AT SOUND EFFECTS
Kulintang-style na musika, ambience at SFX: sinynthesize ng sariling scripts (gen_audio.py, gen_audio_more.py).

BOSES
Windows text-to-speech (Microsoft David at Microsoft Zira, System.Speech) na may phonetic na Tagalog.

FONTS
Mga system font ng device - walang font file na kasama sa laro.

ALAMAT AT LUGAR
Tyanak, Manananggal, Tikbalang at Kapre - mga tradisyonal na alamat ng Pilipinas. Banaue Rice Terraces, Intramuros, Mayon Volcano, Chocolate Hills at Boracay.

AI ASSISTANCE (disclosure)
Claude (Anthropic) ang tumulong sa pagsulat at pag-review ng code, ng mga script na gumawa ng art at tunog, ng mga automated test at ng dokumentasyon. Nakasaad ito sa lahat ng project documents.

SALAMAT
Sa mga playtester ng Week 14 at sa aming instructor.

--------------------------------
GODOT ENGINE LICENSE
%s

Godot Engine also contains third-party libraries under their own licenses (listed at godotengine.org/license)."""

func _ready() -> void:
	# Week 13: every run belongs to a local profile. First launch (or after
	# signing out / deleting the active profile) goes to the profile screen.
	if not SaveSystem.has_active_profile():
		get_tree().change_scene_to_file.call_deferred("res://scenes/ui/ProfileSelect.tscn")
		return
	$PlayerChip/PlayerLabel.text = "Player: %s" % SaveSystem.active_profile_name()
	$VBox/MenuGrid/ProfileButton.pressed.connect(_on_profile)
	SaveSystem.save_failed.connect(_on_save_failed)
	var notice := SaveSystem.take_notice()
	if notice != "":
		_toast(notice)
	money_label.text = "₱%d" % SaveSystem.money
	play_button.pressed.connect(_on_play)
	$VBox/MenuGrid/WardrobeButton.pressed.connect(_on_wardrobe)
	settings_button.pressed.connect(_on_settings_open)
	$VBox/MenuGrid/ExitButton.pressed.connect(_on_exit)
	close_button.pressed.connect(_on_settings_close)
	$SettingsPanel/VBox/InfoRow/HowToButton.pressed.connect(func() -> void: _open_info("PAANO MAGLARO", HOW_TO_PLAY))
	$SettingsPanel/VBox/InfoRow/CreditsButton.pressed.connect(func() -> void:
		var v: Dictionary = Engine.get_version_info()
		_open_info("CREDITS", CREDITS % [ProjectSettings.get_setting("application/config/version"),
			"%d.%d.%d" % [v.major, v.minor, v.patch], Engine.get_license_text()]))
	volume_slider.value = SaveSystem.volume
	volume_slider.value_changed.connect(_on_volume_changed)
	# keyboard hint only makes sense for keyboard players (Week 14)
	# (faded, not hidden, so the menu layout and title animation don't shift)
	$VBox/KeysHint.modulate.a = 0.0 if Controls.touch_mode else 1.0
	Controls.input_mode_changed.connect(func(t: bool) -> void: $VBox/KeysHint.modulate.a = 0.0 if t else 1.0)
	settings_panel.visible = false
	settings_dim.visible = false
	# gentle idle motion so the menu feels alive
	var tw := create_tween().set_loops()
	# relative moves: the menu container may still be laying out at this point
	tw.tween_property(title_label, "position:y", -4.0, 1.4).as_relative().set_trans(Tween.TRANS_SINE)
	tw.tween_property(title_label, "position:y", 4.0, 1.4).as_relative().set_trans(Tween.TRANS_SINE)
	var ft := create_tween().set_loops()
	ft.tween_property(farmer, "scale", Vector2(1.0, 1.02), 0.9).set_trans(Tween.TRANS_SINE)
	ft.tween_property(farmer, "scale", Vector2.ONE, 0.9).set_trans(Tween.TRANS_SINE)
	farmer.pivot_offset = Vector2(30, 84)
	Controls.focus(play_button)
	Audio.stop_ambient()
	Audio.play_music("music_title")
	if not _welcomed:
		_welcomed = true
		get_tree().create_timer(0.6).timeout.connect(func() -> void: Audio.play_voice("narrator_welcome"))

func _unhandled_input(event: InputEvent) -> void:
	if _info != null and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close_info()
		return
	if settings_panel.visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_settings_close()

func _on_play() -> void:
	Audio.play_sfx("click")
	get_tree().change_scene_to_file("res://scenes/jeepney/JeepneyIntro.tscn")

func _on_profile() -> void:
	Audio.play_sfx("click")
	get_tree().change_scene_to_file("res://scenes/ui/ProfileSelect.tscn")

func _on_save_failed(message: String) -> void:
	_toast(message)

## Small message at the bottom of the screen that fades out by itself.
func _toast(text: String) -> void:
	var chip := PanelContainer.new()
	chip.theme_type_variation = "HudChip"
	# bottom-right, clear of the menu column on the left
	chip.anchor_left = 1.0
	chip.anchor_right = 1.0
	chip.anchor_top = 1.0
	chip.anchor_bottom = 1.0
	chip.offset_left = -520
	chip.offset_right = -16
	chip.offset_top = -64
	chip.offset_bottom = -16
	UIKit.label(chip, text, "HudLabel", 15)
	add_child(chip)
	var tw := chip.create_tween()
	tw.tween_interval(4.0)
	tw.tween_property(chip, "modulate:a", 0.0, 0.6)
	tw.tween_callback(chip.queue_free)

func _on_wardrobe() -> void:
	Audio.play_sfx("click")
	get_tree().change_scene_to_file("res://scenes/ui/Wardrobe.tscn")

func _on_settings_open() -> void:
	Audio.play_sfx("click")
	settings_dim.visible = true
	settings_panel.visible = true
	_set_menu_focusable(false)
	UIKit.pop_in(settings_panel)
	Controls.focus(volume_slider)

func _on_settings_close() -> void:
	SaveSystem.save_game()
	Audio.play_sfx("click")
	settings_panel.visible = false
	settings_dim.visible = false
	_set_menu_focusable(true)
	Controls.focus(settings_button)

## Keep keyboard focus trapped inside the settings panel while it is open.
func _set_menu_focusable(on: bool) -> void:
	for c in $VBox.get_children() + $VBox/MenuGrid.get_children():
		if c is Button:
			(c as Button).focus_mode = Control.FOCUS_ALL if on else Control.FOCUS_NONE

func _on_volume_changed(value: float) -> void:
	SaveSystem.set_volume(value)

func _on_exit() -> void:
	get_tree().quit()

## Scrollable text panel on top of the settings panel (instructions, credits).
func _open_info(title: String, text: String) -> void:
	if _info != null:
		return
	Audio.play_sfx("click")
	_info = CanvasLayer.new()
	_info.layer = 10
	add_child(_info)
	UIKit.dim(_info, 0.6)
	var panel := UIKit.centered_panel(_info, Vector2(780, 470))
	var box := UIKit.vbox(panel, 10)
	UIKit.label(box, title, "HeaderLabel")
	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.custom_minimum_size = Vector2(740, 330)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.focus_mode = Control.FOCUS_ALL   # arrow keys / drag scroll the text
	box.add_child(scroll)
	var body := UIKit.label(scroll, text, "HintLabel", 15)
	body.name = "Body"
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	body.custom_minimum_size = Vector2(720, 0)
	var close := UIKit.button(box, "ISARA", true, UIKit.MIN_TOUCH)
	close.pressed.connect(_close_info)
	_set_settings_focusable(false)
	UIKit.pop_in(panel)
	Controls.focus(close)

func _close_info() -> void:
	if _info == null:
		return
	Audio.play_sfx("click")
	_info.queue_free()
	_info = null
	_set_settings_focusable(true)
	Controls.focus(close_button)

func _set_settings_focusable(on: bool) -> void:
	for b in [volume_slider, close_button, $SettingsPanel/VBox/InfoRow/HowToButton, $SettingsPanel/VBox/InfoRow/CreditsButton]:
		(b as Control).focus_mode = Control.FOCUS_ALL if on else Control.FOCUS_NONE
