class_name CampaignSelection
extends VBoxContainer

signal mission_requested(definition: MissionDefinition)
const crest_ids: Array[StringName] = [&"shadow_walker", &"no_traces", &"one_strike", &"swift", &"side_objective"]
const RANK_COLORS := {"kaiden": Color("806326"), "okuden": Color("a03028"), "chuden": Color("30342c"), "shoden": Color("77786e")}
var slots: Array[Button] = []
var selected: MissionDefinition
var start_button: Button
var _campaign: Dictionary
var _missions: Array[MissionDefinition]
var _details: VBoxContainer
var _text: VBoxContainer

func configure(campaign: Dictionary) -> void:
	_campaign = campaign.duplicate(true)
	_missions = CampaignCatalog.missions()
	for child in get_children(): remove_child(child); child.queue_free()
	slots.clear()
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 170
	scroll.follow_focus = true
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var nights := HBoxContainer.new()
	scroll.add_child(nights)
	for index in range(_missions.size()):
		var mission := _missions[index]
		var button := Button.new()
		button.name = "Night%02d" % (index+1)
		for state in ["normal", "hover", "pressed", "disabled", "focus"]:
			var paper := StyleBoxFlat.new()
			paper.bg_color = Color("d1c5a0") if state != "disabled" else Color("8d927f")
			paper.border_color = Color("a03028") if state == "focus" else Color("82775c")
			paper.set_border_width_all(3 if state == "focus" else 1)
			paper.content_margin_left = 14
			paper.content_margin_right = 14
			button.add_theme_stylebox_override(state,paper)
		for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			button.add_theme_color_override(state,Color("30382f"))
		button.add_theme_color_override("font_disabled_color",Color("586458"))
		button.custom_minimum_size = Vector2(170,145)
		button.disabled = not CampaignCatalog.is_unlocked(mission.id, campaign)
		var receipt: Dictionary = campaign.get("mission_results",{}).get(String(mission.id),{})
		var rank: String = receipt.get("rank", "")
		var title := GameText.get_text(&"campaign.locked") if button.disabled else mission.localized_title()
		button.text = "%s\n%s" % [GameText.get_text(StringName("campaign.night.%d" % (index+1))), title]
		if not rank.is_empty():
			button.text += "\n" + GameText.get_text(StringName("result.rank."+rank))
			button.add_theme_color_override("font_color", RANK_COLORS.get(rank, Color.WHITE))
		var marks := ""
		for flag in crest_ids: marks += "● " if receipt.get("flags",{}).get(String(flag),false) else "○ "
		button.text += "\n"+marks
		button.pressed.connect(select_mission.bind(index))
		nights.add_child(button)
		slots.append(button)
	_details = VBoxContainer.new()
	add_child(_details)
	select_mission(clampi(int(campaign.get("unlocked_mission",1))-1,0,9))

func select_mission(index: int) -> void:
	if index < 0 or index >= _missions.size() or slots[index].disabled: return
	selected = _missions[index]
	for child in _details.get_children(): _details.remove_child(child); child.queue_free()
	_text = _details
	var heading := _label(selected.localized_title(), 30)
	heading.name = "SelectedMission"
	var row := HBoxContainer.new()
	_details.add_child(row)
	var poster := TextureRect.new()
	poster.name = "WantedPortrait"
	poster.texture = load("res://assets/ui/posters/m%02d.svg" % (index+1))
	poster.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	poster.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	poster.custom_minimum_size = Vector2(144,180)
	row.add_child(poster)
	_text = VBoxContainer.new()
	_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_text)
	var target := _label(GameText.get_text(StringName("campaign.target.%d" % (index+1))), 24)
	target.name = "WantedPoster"
	var paper := StyleBoxFlat.new()
	paper.bg_color = Color("c9bd97")
	paper.set_content_margin_all(20)
	target.add_theme_stylebox_override("normal",paper)
	target.add_theme_color_override("font_color",Color("25251e"))
	_label(GameText.get_text(&"campaign.oko"), 16)
	_label(GameText.get_text(StringName("campaign.summary.%d" % (index+1))), 20)
	var receipt: Dictionary = _campaign.get("mission_results",{}).get(String(selected.id),{})
	var crests := HFlowContainer.new()
	_text.add_child(crests)
	for id in crest_ids:
		var crest := Label.new()
		crest.text = ("● " if receipt.get("flags",{}).get(String(id),false) else "○ ")+GameText.get_text(StringName("result.flag."+String(id)))
		crests.add_child(crest)
	var loadout: Array[String] = []
	for id in selected.tool_loadout:
		var tool = load("res://data/tools/%s.tres" % id)
		loadout.append("%s ×%d" % [tool.localized_name(), int(selected.tool_loadout[id])])
	_label(GameText.get_text(&"campaign.loadout")+"　"+" / ".join(loadout), 16)
	start_button = Button.new()
	start_button.name = "StartMission"
	start_button.disabled = selected.level_scene == null
	start_button.text = GameText.get_text(&"campaign.unavailable" if start_button.disabled else &"tutorial.start" if index == 0 else &"m02.start" if index == 1 else &"campaign.depart")
	start_button.pressed.connect(func() -> void: if not start_button.disabled: mission_requested.emit(selected))
	_text.add_child(start_button)

func _label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size",font_size)
	_text.add_child(label)
	return label
