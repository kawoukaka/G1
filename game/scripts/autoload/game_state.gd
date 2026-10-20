extends Node
## Station model + economy simulation.
##
## Owns everything that goes into a save file: floor plates, buildings and resource
## stocks. Views (StationView, HUD, BuildController) read from here and react to
## signals; they only change state through the public API below.

signal cell_changed(cell: Vector2i)
signal station_reloaded
signal resources_changed
signal speed_changed(speed: int)
signal announced(text: String, level: int)

enum Level { INFO, GOOD, WARN, BAD }

const SAVE_PATH := "user://station_save.json"
const SAVE_VERSION := 1
const TICK_SECONDS := 1.0
const SPEEDS := [0, 1, 2, 4]
const MAP_RADIUS := 40
const CORE_CELL := Vector2i.ZERO
const NEIGHBORS := [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]

# Tuning. Per crew member per tick unless noted.
const CREW_OXYGEN := 0.5
const CREW_FOOD := 0.25
const CREW_INCOME := 1.5
const FLOOR_LEAK := 0.02 ## Oxygen lost per floor tile per tick.
const ARRIVAL_TICKS := 10
const SUFFOCATE_TICKS := 5
const STARVE_TICKS := 10
const DEMOLISH_REFUND := 0.5
const LOW_STOCK := 0.2 ## Fraction of storage that triggers a warning.
const GOAL_CREW := 20

var floors: Dictionary = {} ## Vector2i -> true
var buildings: Dictionary = {} ## Vector2i -> building id

var credits := 0.0
var oxygen := 0.0
var food := 0.0
var energy := 0.0
var crew := 0
var tick := 0

# Derived from buildings by _recalculate(); read-only for views.
var power_supply := 0.0
var power_demand := 0.0
var energy_capacity := 0.0
var storage_capacity := 0.0
var housing := 0
var has_dock := false
var brownout := false
var credits_delta := 0.0
var oxygen_delta := 0.0
var food_delta := 0.0

var speed_index := 1
var _speed_before_pause := 1
var _accum := 0.0
var _arrival_timer := 0
var _suffocate_timer := 0
var _starve_timer := 0
var _warned: Dictionary = {}
var _goal_reached := false


func _process(delta: float) -> void:
	var speed := current_speed()
	if speed == 0:
		return
	_accum += delta * speed
	while _accum >= TICK_SECONDS:
		_accum -= TICK_SECONDS
		_simulate_tick()


# --- Game lifecycle ---------------------------------------------------------

func new_game() -> void:
	floors.clear()
	buildings.clear()
	for x in range(-1, 2):
		for y in range(-1, 2):
			floors[Vector2i(x, y)] = true
	buildings[CORE_CELL] = "core"
	credits = 600.0
	oxygen = 40.0
	food = 40.0
	energy = 20.0
	crew = 2
	tick = 0
	_reset_runtime()
	station_reloaded.emit()
	resources_changed.emit()
	announce("Welcome, Commander. Build a Docking Port on the edge to attract crew. Goal: %d crew." % GOAL_CREW)


func save_game() -> void:
	var floor_list := []
	for cell in floors:
		floor_list.append([cell.x, cell.y])
	var building_list := []
	for cell in buildings:
		building_list.append([cell.x, cell.y, buildings[cell]])
	var data := {
		"version": SAVE_VERSION,
		"tick": tick,
		"credits": credits,
		"oxygen": oxygen,
		"food": food,
		"energy": energy,
		"crew": crew,
		"floors": floor_list,
		"buildings": building_list,
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		announce("Save failed: %s" % error_string(FileAccess.get_open_error()), Level.BAD)
		return
	file.store_string(JSON.stringify(data, "  "))
	announce("Game saved.")


func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		announce("No save file yet (F5 to save).", Level.WARN)
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if not (data is Dictionary) or int(data.get("version", 0)) != SAVE_VERSION:
		announce("Save file is missing or incompatible.", Level.BAD)
		return
	floors.clear()
	buildings.clear()
	for entry in data.floors:
		floors[Vector2i(int(entry[0]), int(entry[1]))] = true
	for entry in data.buildings:
		buildings[Vector2i(int(entry[0]), int(entry[1]))] = str(entry[2])
	tick = int(data.tick)
	credits = float(data.credits)
	oxygen = float(data.oxygen)
	food = float(data.food)
	energy = float(data.energy)
	crew = int(data.crew)
	_reset_runtime()
	station_reloaded.emit()
	resources_changed.emit()
	announce("Game loaded.")


# --- Time -------------------------------------------------------------------

func current_speed() -> int:
	return SPEEDS[speed_index]


func toggle_pause() -> void:
	if speed_index == 0:
		_set_speed_index(_speed_before_pause)
	else:
		_speed_before_pause = speed_index
		_set_speed_index(0)


func cycle_speed() -> void:
	_set_speed_index(1 if speed_index == 0 else speed_index % (SPEEDS.size() - 1) + 1)


func _set_speed_index(index: int) -> void:
	speed_index = index
	speed_changed.emit(current_speed())


# --- Construction API -------------------------------------------------------

## Returns "" if `id` can be built at `cell`, otherwise a player-facing reason.
func can_build(cell: Vector2i, id: String) -> String:
	if BuildingDB.get_def(id).is_empty():
		return "Unknown module"
	if absi(cell.x) > MAP_RADIUS or absi(cell.y) > MAP_RADIUS:
		return "Too far from the core"
	if id == BuildingDB.FLOOR_ID:
		if floors.has(cell):
			return "Already plated"
		if not floors.is_empty() and not _touches_floor(cell):
			return "Must connect to the station"
	else:
		if not floors.has(cell):
			return "Needs floor plating"
		if buildings.has(cell):
			return "Tile occupied"
		if BuildingDB.get_def(id).get("edge", false) and not _is_edge(cell):
			return "Must be on the station edge"
	if credits < BuildingDB.cost(id):
		return "Not enough credits"
	return ""


func build(cell: Vector2i, id: String) -> bool:
	if can_build(cell, id) != "":
		return false
	credits -= BuildingDB.cost(id)
	if id == BuildingDB.FLOOR_ID:
		floors[cell] = true
	else:
		buildings[cell] = id
	_recalculate()
	cell_changed.emit(cell)
	resources_changed.emit()
	return true


func can_demolish(cell: Vector2i) -> String:
	if buildings.has(cell):
		if not BuildingDB.get_def(buildings[cell]).get("demolishable", true):
			return "Cannot be demolished"
		return ""
	if floors.has(cell):
		if _floor_removal_splits(cell):
			return "Would split the station"
		return ""
	return "Nothing to demolish"


func demolish(cell: Vector2i) -> bool:
	if can_demolish(cell) != "":
		return false
	var id: String = buildings.get(cell, BuildingDB.FLOOR_ID)
	if buildings.has(cell):
		buildings.erase(cell)
	else:
		floors.erase(cell)
	credits += floorf(BuildingDB.cost(id) * DEMOLISH_REFUND)
	_recalculate()
	cell_changed.emit(cell)
	resources_changed.emit()
	return true


func announce(text: String, level: Level = Level.INFO) -> void:
	announced.emit(text, level)


# --- Simulation -------------------------------------------------------------

func _simulate_tick() -> void:
	tick += 1
	_recalculate()
	var credits_before := credits
	var oxygen_before := oxygen
	var food_before := food

	# Power: surplus charges batteries, deficits drain them, empty batteries brown out.
	var was_brownout := brownout
	var net := power_supply - power_demand
	if net >= 0.0:
		energy = minf(energy + net, energy_capacity)
		brownout = false
	elif energy + net >= 0.0:
		energy += net
		brownout = false
	else:
		energy = 0.0
		brownout = true
	if brownout and not was_brownout:
		announce("Brownout! Power-hungry modules are offline.", Level.BAD)
	elif was_brownout and not brownout:
		announce("Power restored.", Level.GOOD)

	# Production. Consumers only work while powered.
	for id in buildings.values():
		if brownout and BuildingDB.consumes_power(id):
			continue
		var produces: Dictionary = BuildingDB.get_def(id).get("produces", {})
		oxygen += float(produces.get("oxygen", 0.0))
		food += float(produces.get("food", 0.0))

	# Consumption and income.
	oxygen -= crew * CREW_OXYGEN + floors.size() * FLOOR_LEAK
	food -= crew * CREW_FOOD
	if oxygen > 0.0 and food > 0.0:
		credits += crew * CREW_INCOME
	oxygen = clampf(oxygen, 0.0, storage_capacity)
	food = clampf(food, 0.0, storage_capacity)

	credits_delta = credits - credits_before
	oxygen_delta = oxygen - oxygen_before
	food_delta = food - food_before
	_update_crew()
	_check_low_stock("oxygen", oxygen, "Oxygen")
	_check_low_stock("food", food, "Food")
	resources_changed.emit()


func _update_crew() -> void:
	var before := crew
	_suffocate_timer = _suffocate_timer + 1 if oxygen <= 0.0 and crew > 0 else 0
	if _suffocate_timer >= SUFFOCATE_TICKS:
		_suffocate_timer = 0
		crew -= 1
		announce("A crew member suffocated. Build O2 Generators!", Level.BAD)

	_starve_timer = _starve_timer + 1 if food <= 0.0 and crew > 0 else 0
	if _starve_timer >= STARVE_TICKS:
		_starve_timer = 0
		crew -= 1
		announce("A crew member starved. Build Hydroponics!", Level.BAD)

	var can_arrive := has_dock and crew < housing and oxygen > 0.0 and food > 0.0
	_arrival_timer = _arrival_timer + 1 if can_arrive else 0
	if _arrival_timer >= ARRIVAL_TICKS:
		_arrival_timer = 0
		crew += 1
		announce("A shuttle docked: new crew member (%d/%d beds)." % [crew, housing], Level.GOOD)

	if crew == 0 and before > 0:
		announce("The station is empty. A running Docking Port can still bring crew.", Level.BAD)
	if crew >= GOAL_CREW and not _goal_reached:
		_goal_reached = true
		announce("Goal reached: %d crew aboard! Keep building or start over (F2)." % GOAL_CREW, Level.GOOD)


func _recalculate() -> void:
	power_supply = 0.0
	power_demand = 0.0
	energy_capacity = 0.0
	storage_capacity = 0.0
	housing = 0
	has_dock = false
	for id in buildings.values():
		var def := BuildingDB.get_def(id)
		var p := BuildingDB.power(id)
		if p > 0.0:
			power_supply += p
		else:
			power_demand -= p
		energy_capacity += float(def.get("battery", 0.0))
		storage_capacity += float(def.get("storage", 0.0))
		housing += int(def.get("housing", 0))
		has_dock = has_dock or def.get("dock", false)
	energy = minf(energy, energy_capacity)


func _check_low_stock(key: String, amount: float, label: String) -> void:
	var low := amount < storage_capacity * LOW_STOCK
	if low and not _warned.get(key, false):
		announce("%s running low!" % label, Level.WARN)
	_warned[key] = low


func _reset_runtime() -> void:
	_accum = 0.0
	_arrival_timer = 0
	_suffocate_timer = 0
	_starve_timer = 0
	_warned.clear()
	_goal_reached = crew >= GOAL_CREW
	brownout = false
	credits_delta = 0.0
	oxygen_delta = 0.0
	food_delta = 0.0
	_recalculate()


# --- Grid helpers -----------------------------------------------------------

func _touches_floor(cell: Vector2i) -> bool:
	for offset in NEIGHBORS:
		if floors.has(cell + offset):
			return true
	return false


func _is_edge(cell: Vector2i) -> bool:
	for offset in NEIGHBORS:
		if not floors.has(cell + offset):
			return true
	return false


## Flood-fills from the core without `cell`; true if some floor would be cut off.
func _floor_removal_splits(cell: Vector2i) -> bool:
	if cell == CORE_CELL:
		return true
	var seen := {CORE_CELL: true}
	var frontier: Array[Vector2i] = [CORE_CELL]
	while not frontier.is_empty():
		var current: Vector2i = frontier.pop_back()
		for offset in NEIGHBORS:
			var next: Vector2i = current + offset
			if next != cell and floors.has(next) and not seen.has(next):
				seen[next] = true
				frontier.append(next)
	return seen.size() < floors.size() - 1
