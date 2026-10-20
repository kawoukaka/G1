extends Node
## Building catalogue loaded from data/buildings.json. Data-driven so balance can be
## tuned without touching code; see docs/GAME_DESIGN.md for the field reference.

const DATA_PATH := "res://data/buildings.json"
const FLOOR_ID := "floor"
const RESOURCE_LABELS := {"oxygen": "O2", "food": "food"}

var _defs: Dictionary = {}
var _order: Array[String] = []
var _textures: Dictionary = {}


func _enter_tree() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	if not (parsed is Array):
		push_error("BuildingDB: %s must contain a JSON array" % DATA_PATH)
		return
	for entry in parsed:
		var id: String = entry["id"]
		_defs[id] = entry
		_order.append(id)


func get_def(id: String) -> Dictionary:
	return _defs.get(id, {})


func display_name(id: String) -> String:
	return get_def(id).get("name", id)


func cost(id: String) -> int:
	return int(get_def(id).get("cost", 0))


func power(id: String) -> float:
	return float(get_def(id).get("power", 0.0))


func consumes_power(id: String) -> bool:
	return power(id) < 0.0


## Ids shown in the build palette, in file order.
func buildable_ids() -> Array[String]:
	var ids: Array[String] = []
	for id in _order:
		if _defs[id].get("buildable", true):
			ids.append(id)
	return ids


func texture(id: String) -> Texture2D:
	if not _textures.has(id):
		_textures[id] = load(get_def(id).get("sprite", ""))
	return _textures[id]


## One-line stat summary, e.g. "-3 power, +3 O2/tick".
func describe(id: String) -> String:
	var def := get_def(id)
	var parts: PackedStringArray = []
	if power(id) != 0.0:
		parts.append("%s power" % _signed(power(id)))
	var produces: Dictionary = def.get("produces", {})
	for key in produces:
		parts.append("%s %s/tick" % [_signed(produces[key]), RESOURCE_LABELS.get(key, key)])
	for key in ["housing", "storage", "battery"]:
		if def.has(key):
			parts.append("+%s %s" % [str(def[key]), key])
	if def.get("dock", false):
		parts.append("crew can arrive")
	if def.get("edge", false):
		parts.append("must be on the station edge")
	return ", ".join(parts)


func _signed(value: float) -> String:
	return ("+" if value > 0.0 else "") + str(snappedf(value, 0.01))
