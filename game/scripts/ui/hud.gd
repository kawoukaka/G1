extends CanvasLayer
## Heads-up display, built in code for the prototype: resource bar, build palette,
## context info panel and a notification feed. Phase 2 swaps in a pixel UI theme.

signal tool_selected(tool: String)

const TOOL_DEMOLISH := "demolish"
const PANEL_BG := Color("14121fe6")
const PANEL_BORDER := Color("4a4e69")
const BUTTON_BG := Color("2b2d42")
const BUTTON_HOVER := Color("4a4e69")
const BUTTON_ACTIVE := Color("1d3557")
const ACCENT := Color("6fb3ff")
const TEXT := Color("f8f9fa")
const DIM := Color("8d99ae")
const GOOD := Color("52b788")
const WARN := Color("ffd166")
const BAD := Color("e63946")
const LEVEL_COLORS := [Color("c9d1dc"), GOOD, WARN, BAD] ## Indexed by GameState.Level.
const NOTE_SECONDS := 6.0
const MAX_NOTES := 6
const HELP := "LMB build (hold to paint) · RMB/Esc cancel · X demolish · 1-8 modules\nWASD/MMB pan · Wheel zoom · Space pause · Tab speed · F5 save · F9 load · F2 new"

var _labels: Dictionary = {}
var _buttons: Dictionary = {} ## tool -> Button
var _info_title: Label
var _info_body: Label
var _info_status: Label
var _notes: VBoxContainer
var _tool := ""
var _hover := Vector2i.ZERO


func _ready() -> void:
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = _make_theme()
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_resource_bar(root)
	_build_palette(root)
	_build_info_panel(root)
	_build_notes(root)
	_build_help(root)
	GameState.resources_changed.connect(_refresh)
	GameState.speed_changed.connect(func(_speed: int) -> void: _refresh())
	GameState.announced.connect(push_note)


func set_active_tool(tool: String) -> void:
	_tool = tool
	for key in _buttons:
		_buttons[key].set_pressed_no_signal(key == tool)
	_refresh_info()


func set_hover(cell: Vector2i) -> void:
	_hover = cell
	_refresh_info()


func push_note(text: String, level: int) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", LEVEL_COLORS[level])
	label.add_theme_color_override("font_outline_color", Color("0b0a17"))
	label.add_theme_constant_override("outline_size", 4)
	_notes.add_child(label)
	if _notes.get_child_count() > MAX_NOTES:
		_notes.get_child(0).free()
	var tween := label.create_tween()
	tween.tween_interval(NOTE_SECONDS)
	tween.tween_property(label, "modulate:a", 0.0, 1.0)
	tween.tween_callback(label.queue_free)


# --- Layout -------------------------------------------------------------------

func _build_resource_bar(root: Control) -> void:
	var bar := PanelContainer.new()
	root.add_child(bar)
	bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 28)
	bar.add_child(row)
	for key in ["credits", "power", "energy", "oxygen", "food", "crew", "goal", "time"]:
		var label := Label.new()
		row.add_child(label)
		_labels[key] = label
	_labels.goal.add_theme_color_override("font_color", DIM)
	_labels.time.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_labels.time.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT


func _build_palette(root: Control) -> void:
	var panel := PanelContainer.new()
	root.add_child(panel)
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_top = -8
	panel.offset_bottom = -8
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	panel.add_child(row)
	var ids := BuildingDB.buildable_ids()
	for i in ids.size():
		var id := ids[i]
		var button := _make_tool_button(id, BuildingDB.texture(id),
			"%d %s\n$%d" % [i + 1, BuildingDB.display_name(id), BuildingDB.cost(id)])
		button.tooltip_text = "%s\n%s" % [BuildingDB.get_def(id).get("desc", ""), BuildingDB.describe(id)]
		row.add_child(button)
	row.add_child(_make_tool_button(TOOL_DEMOLISH, null, "X Demolish\n50% refund"))


## Square palette button: 2x sprite on top, two lines of caption below.
func _make_tool_button(tool: String, icon: Texture2D, caption: String) -> Button:
	var button := Button.new()
	button.toggle_mode = true
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(112, 108)
	button.pressed.connect(func() -> void: tool_selected.emit("" if _tool == tool else tool))
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.alignment = BoxContainer.ALIGNMENT_END
	button.add_child(column)
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 6)
	if icon:
		var picture := TextureRect.new()
		picture.texture = _scaled_icon(icon, 2)
		picture.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		picture.size_flags_vertical = Control.SIZE_EXPAND_FILL
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_child(picture)
	var label := Label.new()
	label.text = caption
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 12)
	if tool == TOOL_DEMOLISH:
		label.add_theme_color_override("font_color", BAD)
	column.add_child(label)
	_buttons[tool] = button
	return button


func _build_info_panel(root: Control) -> void:
	var panel := PanelContainer.new()
	root.add_child(panel)
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.offset_left = -12
	panel.offset_right = -12
	panel.offset_top = 56
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(280, 0)
	panel.add_child(column)
	_info_title = Label.new()
	_info_title.add_theme_color_override("font_color", ACCENT)
	_info_body = Label.new()
	_info_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_status = Label.new()
	_info_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for label in [_info_title, _info_body, _info_status]:
		column.add_child(label)


func _build_notes(root: Control) -> void:
	_notes = VBoxContainer.new()
	_notes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_notes)
	_notes.anchor_top = 1.0
	_notes.anchor_bottom = 1.0
	_notes.offset_left = 12
	_notes.offset_top = -144
	_notes.offset_bottom = -144
	_notes.grow_vertical = Control.GROW_DIRECTION_BEGIN


func _build_help(root: Control) -> void:
	var label := Label.new()
	label.text = HELP
	label.add_theme_color_override("font_color", DIM)
	label.add_theme_font_size_override("font_size", 12)
	root.add_child(label)
	label.position = Vector2(12, 52)


func _make_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 15
	theme.set_stylebox("panel", "PanelContainer", _box(PANEL_BG, PANEL_BORDER, 8))
	theme.set_stylebox("normal", "Button", _box(BUTTON_BG, PANEL_BORDER, 6))
	theme.set_stylebox("hover", "Button", _box(BUTTON_HOVER, PANEL_BORDER, 6))
	theme.set_stylebox("pressed", "Button", _box(BUTTON_ACTIVE, ACCENT, 6))
	theme.set_stylebox("hover_pressed", "Button", _box(BUTTON_ACTIVE, ACCENT, 6))
	theme.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	theme.set_stylebox("panel", "TooltipPanel", _box(PANEL_BG, ACCENT, 6))
	theme.set_color("font_color", "Label", TEXT)
	theme.set_color("font_color", "Button", TEXT)
	theme.set_color("font_pressed_color", "Button", ACCENT)
	theme.set_color("font_hover_pressed_color", "Button", ACCENT)
	theme.set_constant("h_separation", "Button", 6)
	return theme


func _box(bg: Color, border: Color, margin: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(2)
	box.set_content_margin_all(margin)
	return box


## Integer-scaled copy of a sprite so palette icons stay crisp.
func _scaled_icon(texture: Texture2D, factor: int) -> Texture2D:
	var image := texture.get_image()
	image.resize(image.get_width() * factor, image.get_height() * factor, Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(image)


# --- Refresh ------------------------------------------------------------------

func _refresh() -> void:
	var gs := GameState
	_set_label("credits", "Credits %d (%+.1f)" % [gs.credits, gs.credits_delta], TEXT)
	var short_power := gs.power_demand > gs.power_supply
	_set_label("power", "Power %d / %d" % [gs.power_supply, gs.power_demand],
		BAD if gs.brownout else (WARN if short_power else TEXT))
	_set_label("energy", "Battery %d / %d" % [gs.energy, gs.energy_capacity], WARN if short_power else TEXT)
	_set_label("oxygen", "O2 %d / %d (%+.1f)" % [gs.oxygen, gs.storage_capacity, gs.oxygen_delta],
		_stock_color(gs.oxygen, gs.storage_capacity))
	_set_label("food", "Food %d / %d (%+.1f)" % [gs.food, gs.storage_capacity, gs.food_delta],
		_stock_color(gs.food, gs.storage_capacity))
	_set_label("crew", "Crew %d / %d%s" % [gs.crew, gs.housing, "" if gs.has_dock else " (no dock)"],
		TEXT if gs.has_dock else WARN)
	_set_label("goal", "Goal %d crew" % gs.GOAL_CREW, GOOD if gs.crew >= gs.GOAL_CREW else DIM)
	var speed := gs.current_speed()
	_set_label("time", "T+%d   %s" % [gs.tick, "PAUSED" if speed == 0 else "Speed x%d" % speed],
		WARN if speed == 0 else TEXT)
	_refresh_info()


func _refresh_info() -> void:
	var gs := GameState
	var status := ""
	var ok := true
	if _tool == TOOL_DEMOLISH:
		_info_title.text = "Demolish"
		_info_body.text = "Removes a module (or empty floor) and refunds %d%% of its cost." % int(gs.DEMOLISH_REFUND * 100)
		status = gs.can_demolish(_hover)
	elif _tool != "":
		_info_title.text = "%s  -  $%d" % [BuildingDB.display_name(_tool), BuildingDB.cost(_tool)]
		_info_body.text = "%s\n%s" % [BuildingDB.get_def(_tool).get("desc", ""), BuildingDB.describe(_tool)]
		status = gs.can_build(_hover, _tool)
	elif gs.buildings.has(_hover):
		var id: String = gs.buildings[_hover]
		_info_title.text = BuildingDB.display_name(id)
		_info_body.text = BuildingDB.describe(id)
		ok = not (gs.brownout and BuildingDB.consumes_power(id))
		status = "" if ok else "OFFLINE - not enough power"
	elif gs.floors.has(_hover):
		_info_title.text = "Floor plating"
		_info_body.text = "Empty deck at %s. Pick a module (1-8) to build here." % str(_hover)
	else:
		_info_title.text = "Open space"
		_info_body.text = "Extend the station with Floor (1)."
	if _tool != "":
		ok = status == ""
		status = "Ready - click to apply" if ok else "Blocked: " + status
	_info_status.text = status
	_info_status.visible = status != ""
	_info_status.add_theme_color_override("font_color", GOOD if ok else BAD)


func _set_label(key: String, text: String, color: Color) -> void:
	_labels[key].text = text
	_labels[key].add_theme_color_override("font_color", color)


func _stock_color(amount: float, capacity: float) -> Color:
	if amount <= 0.0:
		return BAD
	if amount < capacity * GameState.LOW_STOCK:
		return WARN
	return TEXT
