class_name NarrativeOverlay
extends CanvasLayer

const DURATION := 4.0
var _inner := ""
var _last := ""
var _inner_left := 0.0
var _last_left := 0.0
var _column: Column
var _last_label: Label
var _last_panel: PanelContainer

class Column extends Control:
	var text := ""
	var font: Font = preload("res://assets/fonts/NotoSerifJP.ttf")
	func _draw() -> void:
		if text.is_empty(): return
		var font_size := clampi(int(size.y/maxi(text.length(),1)/1.15),12,26)
		var step := float(font_size)*1.15
		for i in text.length():
			var character := text.substr(i,1)
			var point := Vector2(4.0,float(i)*step+font.get_ascent(font_size))
			if character.unicode_at(0) in [0x3002,0x3001]: point += Vector2(font_size*0.4,-font_size*0.4)
			# Unicode vertical-layout classes, not localizable dialogue strings.
			if character.unicode_at(0) in [0x2026,0x30fc,0x2014]:
				draw_set_transform(point+Vector2(font_size*0.5,-font_size*0.5),PI/2)
				point = Vector2(-font_size*0.5,font_size*0.5)
			draw_string_outline(font,point,character,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,4,Color(0.04,0.035,0.025,0.9))
			draw_string(font,point,character,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,Color("eee6d4"))
			draw_set_transform(Vector2.ZERO)

func _ready() -> void:
	layer = 25
	add_to_group(&"narrative_overlays")
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_column = Column.new()
	_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_column)
	_last_panel = PanelContainer.new()
	_last_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025,0.02,0.015,0.82)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	_last_panel.add_theme_stylebox_override("panel",style)
	root.add_child(_last_panel)
	_last_label = Label.new()
	_last_label.add_theme_font_override("font",load("res://assets/fonts/NotoSerifJP.ttf"))
	_last_label.add_theme_color_override("font_color",Color("eee6d4"))
	_last_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_last_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_last_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_last_panel.add_child(_last_label)
	get_viewport().size_changed.connect(_layout)
	EventBus.inner_monologue_requested.connect(_on_inner)
	EventBus.mission_event.connect(_on_event)
	_layout()
	advance(0.0)

func _layout() -> void:
	var viewport := get_viewport().get_visible_rect().size
	_column.position = Vector2(viewport.x*0.86,viewport.y*0.12)
	_column.size = Vector2(44,viewport.y*0.68)
	_column.queue_redraw()
	_last_panel.position = Vector2(viewport.x*0.18,viewport.y*0.83)
	_last_panel.size = Vector2(viewport.x*0.64,0)
	_last_label.add_theme_font_size_override("font_size",clampi(int(viewport.x/48),16,26))

func _on_inner(text_id: StringName) -> void:
	if not bool(SaveManager.settings().get("inner_monologue",true)) or text_id.is_empty(): return
	_inner = GameText.get_text(text_id)
	_inner_left = DURATION
	advance(0.0)

func _on_event(id: StringName,payload: Dictionary) -> void:
	if id != &"target_last_words": return
	var text_id := StringName(payload.get("text_id",&""))
	if text_id.is_empty(): return
	_last = GameText.get_text(text_id)
	_last_left = DURATION
	advance(0.0)

func advance(delta: float) -> void:
	if not is_finite(delta) or delta < 0.0: return
	_inner_left = maxf(0.0,_inner_left-delta)
	_last_left = maxf(0.0,_last_left-delta)
	if not bool(SaveManager.settings().get("inner_monologue",true)): _inner_left = 0.0
	if _inner_left < 0.000001: _inner = ""
	if _last_left < 0.000001: _last = ""
	if _column == null: return
	_column.text = _inner
	_column.modulate.a = minf(1.0,_inner_left/0.5)
	_column.queue_redraw()
	_last_label.text = _last
	_last_panel.visible = not _last.is_empty()
	_last_panel.modulate.a = minf(1.0,_last_left/0.5)

func _process(delta: float) -> void:
	advance(delta)

func monologue_text() -> String:
	return _inner

func last_words_text() -> String:
	return _last

func remaining_time() -> float:
	return maxf(_inner_left,_last_left)

func refresh_settings() -> void:
	# Explicit settings application must work while normal processing is paused.
	advance(0.0)
