class_name CutscenePlayer
extends Control

signal finished(id: StringName, skipped: bool)

const HOLD_DELAY := 0.45
const HOLD_INTERVAL := 0.12

var active := false
var current_slide := 0
var current_line := 0
var skip_pending := false
var auto_enabled := false
var image_view: TextureRect
var ambience: AudioStreamPlayer
var subtitle: Label
var speaker: Label
var _data: CutsceneData
var _reduced := false
var _prior_pause := false
var _prior_mouse: Input.MouseMode
var _slide_elapsed := 0.0
var _line_elapsed := 0.0
var _held_elapsed := 0.0
var _next_repeat := HOLD_DELAY
var _auto_button: Button
var _skip_button: Button
var _dialog: ConfirmationDialog
var _scroll: ScrollContainer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = GameUi.theme()
	clip_contents = true
	_build()
	resized.connect(_layout)
	visible = false

func play(data: CutsceneData, reduced_mode: bool = false) -> bool:
	if active or data == null or not data.is_valid() or not is_node_ready():
		return false
	if reduced_mode and data.slides.size() != 1:
		return false
	_data = data
	_reduced = reduced_mode
	_prior_pause = get_tree().paused
	_prior_mouse = Input.mouse_mode
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	active = true
	visible = true
	skip_pending = false
	current_slide = 0
	current_line = 0
	set_auto(false)
	_skip_button.visible = data.skippable
	_show_slide()
	_layout()
	return true

func advance() -> void:
	if not active or skip_pending:
		return
	current_line += 1
	if current_line >= _data.slides[current_slide].lines.size():
		current_line = 0
		current_slide += 1
		if current_slide >= _data.slides.size():
			_finish(false)
			return
		_show_slide()
	else:
		_show_line()

func set_auto(enabled: bool) -> void:
	auto_enabled = enabled
	_line_elapsed = 0.0
	if _auto_button != null:
		_auto_button.set_pressed_no_signal(enabled)
		_auto_button.text = GameText.get_text(&"cutscene.auto_on" if enabled else &"cutscene.auto_off")

func request_skip() -> void:
	if not active or not _data.skippable or skip_pending:
		return
	skip_pending = true
	_held_elapsed = 0.0
	_next_repeat = HOLD_DELAY
	_dialog.popup_centered(Vector2i(mini(440, int(size.x) - 32), 160))

func confirm_skip(confirmed: bool) -> void:
	if not skip_pending:
		return
	_dialog.hide()
	skip_pending = false
	if confirmed:
		_finish(true)

func stop() -> void:
	# Hosts may cancel playback without reporting a narrative completion.
	if active:
		_restore_ownership()
	visible = false

func _exit_tree() -> void:
	if active:
		_restore_ownership()

func _process(delta: float) -> void:
	advance_time(delta, Input.is_action_pressed(&"ui_accept"))

func advance_time(delta: float, accept_held: bool) -> void:
	if not active or skip_pending or not is_finite(delta) or delta < 0.0:
		return
	_slide_elapsed += delta
	_line_elapsed += delta
	if not _reduced:
		var progress := clampf(_slide_elapsed / _data.slides[current_slide].duration_auto, 0.0, 1.0)
		image_view.scale = Vector2.ONE * lerpf(1.03, 1.12, progress)
		image_view.position = -size * Vector2(0.015 + 0.04 * progress, 0.015 + 0.025 * progress)
	if accept_held:
		_held_elapsed += delta
		if _held_elapsed >= _next_repeat:
			# At most one line per frame: a resumed/stalled frame cannot skip a scene.
			_next_repeat = _held_elapsed + HOLD_INTERVAL
			advance()
	else:
		_held_elapsed = 0.0
		_next_repeat = HOLD_DELAY
	if active and auto_enabled and _line_elapsed >= _data.slides[current_slide].duration_auto / _data.slides[current_slide].lines.size():
		advance()

func _input(event: InputEvent) -> void:
	if not active:
		return
	if event.is_action_pressed(&"ui_cancel"):
		if skip_pending:
			confirm_skip(false)
		else:
			request_skip()
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if active and not skip_pending and event.is_action_pressed(&"ui_accept") and not event.is_echo():
		advance()
		get_viewport().set_input_as_handled()

func _show_slide() -> void:
	_slide_elapsed = 0.0
	image_view.texture = _data.slides[current_slide].image
	image_view.scale = Vector2.ONE
	image_view.position = Vector2.ZERO
	ambience.stop()
	ambience.stream = _data.slides[current_slide].ambience
	if ambience.stream != null:
		ambience.play()
	_show_line()

func _show_line() -> void:
	_line_elapsed = 0.0
	var line: LineData = _data.slides[current_slide].lines[current_line]
	subtitle.text = GameText.get_text(line.text_key)
	speaker.text = GameText.get_text(line.speaker_key) if not line.speaker_key.is_empty() else ""
	speaker.visible = line.style == LineData.Style.DIALOGUE
	subtitle.add_theme_color_override("font_color", Color("c9d2d3") if line.style == LineData.Style.INNER else Color("fff9ec"))
	if line.style == LineData.Style.INNER:
		var slanted := FontVariation.new()
		slanted.base_font = theme.default_font
		slanted.variation_transform = Transform2D(Vector2(1, 0), Vector2(0.15, 1), Vector2.ZERO)
		subtitle.add_theme_font_override("font", slanted)
	else:
		subtitle.remove_theme_font_override("font")
	_scroll.scroll_vertical = 0

func _finish(skipped: bool) -> void:
	var id := _data.id
	_restore_ownership()
	visible = false
	finished.emit(id, skipped)

func _restore_ownership() -> void:
	active = false
	skip_pending = false
	_held_elapsed = 0.0
	_next_repeat = HOLD_DELAY
	ambience.stop()
	_dialog.hide()
	get_tree().paused = _prior_pause
	Input.mouse_mode = _prior_mouse

func _build() -> void:
	var black := ColorRect.new()
	black.color = Color("10171b")
	black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(black)
	image_view = TextureRect.new()
	image_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image_view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	image_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(image_view)
	var band := Panel.new()
	band.name = "SubtitleBand"
	band.anchor_top = 0.75
	band.anchor_right = 1.0
	band.anchor_bottom = 1.0
	var ink := StyleBoxFlat.new()
	ink.bg_color = Color(0.04, 0.065, 0.07, 0.95)
	ink.border_color = Color("a28d67")
	ink.border_width_top = 1
	band.add_theme_stylebox_override("panel", ink)
	add_child(band)
	_scroll = ScrollContainer.new()
	_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scroll.offset_left = 28
	_scroll.offset_right = -28
	_scroll.offset_top = 10
	_scroll.offset_bottom = -10
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	band.add_child(_scroll)
	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.add_theme_constant_override("separation", 4)
	_scroll.add_child(copy)
	speaker = Label.new()
	speaker.add_theme_color_override("font_color", Color("ddb881"))
	copy.add_child(speaker)
	subtitle = Label.new()
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	copy.add_child(subtitle)
	var toolbar := HBoxContainer.new()
	toolbar.name = "Toolbar"
	toolbar.position = Vector2(16, 16)
	toolbar.add_theme_constant_override("separation", 8)
	add_child(toolbar)
	var next := _button(&"cutscene.next", advance)
	toolbar.add_child(next)
	_auto_button = _button(&"cutscene.auto_off", func(): set_auto(not auto_enabled))
	_auto_button.toggle_mode = true
	toolbar.add_child(_auto_button)
	_skip_button = _button(&"cutscene.skip", request_skip)
	toolbar.add_child(_skip_button)
	_dialog = ConfirmationDialog.new()
	_dialog.title = GameText.get_text(&"cutscene.skip_title")
	_dialog.dialog_text = GameText.get_text(&"cutscene.skip_confirm")
	_dialog.ok_button_text = GameText.get_text(&"cutscene.skip_yes")
	_dialog.cancel_button_text = GameText.get_text(&"cutscene.skip_no")
	_dialog.confirmed.connect(func(): confirm_skip(true))
	_dialog.canceled.connect(func(): confirm_skip(false))
	add_child(_dialog)
	ambience = AudioStreamPlayer.new()
	ambience.bus = &"BGM" if AudioServer.get_bus_index(&"BGM") >= 0 else &"Master"
	add_child(ambience)

func _button(key: StringName, action: Callable) -> Button:
	var button := Button.new()
	button.text = GameText.get_text(key)
	button.pressed.connect(action)
	return button

func _layout() -> void:
	if image_view == null:
		return
	image_view.size = size
	var compact := size.y < 500.0
	subtitle.add_theme_font_size_override("font_size", 16 if compact else 24)
	speaker.add_theme_font_size_override("font_size", 14 if compact else 18)
	for button: Button in get_node("Toolbar").get_children():
		button.add_theme_font_size_override("font_size", 14 if compact else 18)
