extends Node2D
## Wires the systems together and handles global keys (pause, speed, save/load).

@onready var _build = $BuildController
@onready var _hud = $HUD


func _ready() -> void:
	_hud.tool_selected.connect(_build.set_tool)
	_build.tool_changed.connect(_hud.set_active_tool)
	_build.hover_changed.connect(_hud.set_hover)
	GameState.new_game()
	if "--demo" in OS.get_cmdline_user_args():
		_build_demo_station()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		GameState.toggle_pause()
	elif event.is_action_pressed("speed_cycle"):
		GameState.cycle_speed()
	elif event.is_action_pressed("save_game"):
		GameState.save_game()
	elif event.is_action_pressed("load_game"):
		GameState.load_game()
	elif event.is_action_pressed("new_game"):
		GameState.new_game()


## Pre-built layout for screenshots and quick testing: `Godot --path game -- --demo`.
func _build_demo_station() -> void:
	GameState.credits = 99999.0
	for _pass in 4: # Floors must touch the station, so grow outward over a few passes.
		for x in range(-3, 5):
			for y in range(-3, 4):
				GameState.build(Vector2i(x, y), BuildingDB.FLOOR_ID)
	var layout := {
		Vector2i(1, -1): "solar", Vector2i(2, -1): "solar", Vector2i(3, -1): "solar",
		Vector2i(1, 0): "battery", Vector2i(-1, 1): "o2_gen", Vector2i(-2, 1): "o2_gen",
		Vector2i(-1, -2): "hydroponics", Vector2i(-2, -2): "hydroponics",
		Vector2i(2, 2): "quarters", Vector2i(3, 2): "quarters", Vector2i(-3, 0): "dock",
		Vector2i(0, 2): "storage", Vector2i(4, 0): "dock",
	}
	for cell in layout:
		GameState.build(cell, layout[cell])
	GameState.credits = 600.0
	GameState.crew = 8
	GameState.resources_changed.emit()
