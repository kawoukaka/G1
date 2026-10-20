extends SceneTree
## Headless smoke test for the station simulation.
## Run: Godot --headless --path game -s res://tests/sim_smoke_test.gd

var _failures := 0


func _initialize() -> void:
	# Autoloads are added after _initialize; run on the first frame.
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	var gs = root.get_node("GameState")
	gs.new_game()
	gs.speed_index = 0

	_check(Iso.world_to_cell(Iso.cell_to_world(Vector2i(3, -7))) == Vector2i(3, -7), "iso round trip")
	_check(gs.can_build(Vector2i(5, 5), "floor") != "", "floor must touch the station")
	_check(gs.can_build(Vector2i(2, 0), "floor") == "", "adjacent floor is allowed")
	_check(gs.can_build(Vector2i(1, 0), "solar") == "", "solar on empty floor")
	_check(gs.can_build(Vector2i(0, 0), "solar") != "", "core tile is occupied")
	_check(gs.can_demolish(Vector2i(0, 0)) != "", "core cannot be demolished")

	gs.build(Vector2i(2, 0), "floor")
	_check(gs.can_demolish(Vector2i(2, 0)) == "", "a leaf floor tile can be removed")
	_check(gs.can_demolish(Vector2i(1, 0)) != "", "removing a bridge tile would split the station")

	gs.build(Vector2i(1, 0), "solar")
	gs.build(Vector2i(1, 1), "o2_gen")
	gs.build(Vector2i(-1, 0), "dock")
	gs.build(Vector2i(0, -1), "quarters")
	gs.build(Vector2i(-1, -1), "hydroponics")
	_check(gs.has_dock and gs.housing == 6, "dock and housing registered")

	for i in 120:
		gs._simulate_tick()
	_check(gs.crew > 2, "crew arrived via dock (crew=%d)" % gs.crew)
	_check(not gs.brownout, "no brownout with solar")

	gs.save_game()
	var crew_before: int = gs.crew
	gs.new_game()
	gs.load_game()
	_check(gs.crew == crew_before and gs.buildings.size() == 6, "save/load round trip")

	print("SIM SMOKE TEST: %s" % ("PASS" if _failures == 0 else "%d FAILURE(S)" % _failures))
	quit(_failures)


func _check(ok: bool, what: String) -> void:
	if not ok:
		_failures += 1
		printerr("  FAIL: ", what)
	else:
		print("  ok: ", what)
