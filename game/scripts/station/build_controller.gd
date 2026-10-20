extends Node2D
## Turns mouse/keyboard input into build and demolish calls on GameState.
## Owns the hover cursor and the ghost preview of the selected module.

signal tool_changed(tool: String)
signal hover_changed(cell: Vector2i)

const TOOL_NONE := ""
const TOOL_DEMOLISH := "demolish"
const CURSOR_TEXTURE := preload("res://assets/sprites/ui/cursor.png")
const OK_TINT := Color(0.6, 1.0, 0.7, 0.8)
const BAD_TINT := Color(1.0, 0.35, 0.35, 0.7)
const DEMOLISH_TINT := Color(1.0, 0.3, 0.3)
const IDLE_TINT := Color(1, 1, 1, 0.5)

var tool := TOOL_NONE
var hovered := Vector2i.ZERO

var _cursor := Sprite2D.new()
var _ghost := Sprite2D.new()
var _painting := false
var _last_painted := Vector2i(1 << 30, 1 << 30)


func _ready() -> void:
	z_index = 10
	_cursor.texture = CURSOR_TEXTURE
	_cursor.centered = false
	add_child(_cursor)
	_ghost.centered = false
	add_child(_ghost)
	GameState.resources_changed.connect(_refresh)
	GameState.cell_changed.connect(func(_cell: Vector2i) -> void: _refresh())


func set_tool(new_tool: String) -> void:
	tool = new_tool
	_refresh()
	tool_changed.emit(tool)


func _process(_delta: float) -> void:
	var cell := Iso.world_to_cell(get_global_mouse_position())
	if cell != hovered:
		hovered = cell
		_refresh()
		hover_changed.emit(hovered)
	if _painting and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_painting = false
	if _painting and hovered != _last_painted:
		_apply(hovered, false)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT and tool != TOOL_NONE:
			_painting = true
			_apply(hovered, true)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_RIGHT and tool != TOOL_NONE:
			set_tool(TOOL_NONE)
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed("tool_cancel"):
		set_tool(TOOL_NONE)
	elif event.is_action_pressed("tool_demolish"):
		set_tool(TOOL_NONE if tool == TOOL_DEMOLISH else TOOL_DEMOLISH)
	else:
		var ids := BuildingDB.buildable_ids()
		for i in mini(ids.size(), Controls.TOOL_KEYS.size()):
			if event.is_action_pressed(Controls.tool_action(i)):
				set_tool(TOOL_NONE if tool == ids[i] else ids[i])


## Single clicks report why they failed; drag-painting fails silently.
func _apply(cell: Vector2i, explain: bool) -> void:
	_last_painted = cell
	var reason: String
	if tool == TOOL_DEMOLISH:
		reason = GameState.can_demolish(cell)
		if reason == "":
			GameState.demolish(cell)
	else:
		reason = GameState.can_build(cell, tool)
		if reason == "":
			GameState.build(cell, tool)
	if reason != "" and explain:
		GameState.announce(reason, GameState.Level.WARN)


func _refresh() -> void:
	_cursor.position = Iso.tile_origin(hovered)
	_ghost.visible = tool != TOOL_NONE and tool != TOOL_DEMOLISH
	match tool:
		TOOL_NONE:
			_cursor.modulate = IDLE_TINT
		TOOL_DEMOLISH:
			_cursor.modulate = DEMOLISH_TINT if GameState.can_demolish(hovered) == "" else IDLE_TINT
		_:
			var ok := GameState.can_build(hovered, tool) == ""
			_cursor.modulate = OK_TINT if ok else BAD_TINT
			_ghost.texture = BuildingDB.texture(tool)
			_ghost.position = Iso.cell_to_world(hovered)
			_ghost.offset = Iso.sprite_offset(_ghost.texture)
			_ghost.modulate = OK_TINT if ok else BAD_TINT
