extends Node2D
## Renders GameState: floor plates (one batched _draw), module sprites and crew
## (y-sorted together so tall modules overlap whatever stands behind them).

const FLOOR_TOP := preload("res://assets/sprites/tiles/floor_top.png")
const FLOOR_SIDE_L := preload("res://assets/sprites/tiles/floor_side_l.png")
const FLOOR_SIDE_R := preload("res://assets/sprites/tiles/floor_side_r.png")
const CrewMember := preload("res://scripts/crew/crew_member.gd")
const OFFLINE_TINT := Color(0.45, 0.45, 0.62)

var _floor_layer := Node2D.new()
var _objects := Node2D.new()
var _sprites: Dictionary = {} ## Vector2i -> Sprite2D
var _crew: Array[Node2D] = []


func _ready() -> void:
	add_child(_floor_layer)
	_objects.y_sort_enabled = true
	add_child(_objects)
	_floor_layer.draw.connect(_draw_floor)
	GameState.cell_changed.connect(_on_cell_changed)
	GameState.station_reloaded.connect(_rebuild)
	GameState.resources_changed.connect(_on_resources_changed)


func _rebuild() -> void:
	for sprite in _sprites.values():
		sprite.queue_free()
	_sprites.clear()
	for member in _crew:
		member.queue_free()
	_crew.clear()
	for cell in GameState.buildings:
		_sync_building(cell, false)
	_floor_layer.queue_redraw()


func _on_cell_changed(cell: Vector2i) -> void:
	_sync_building(cell, true)
	_floor_layer.queue_redraw()


func _on_resources_changed() -> void:
	for sprite in _sprites.values():
		var offline: bool = GameState.brownout and BuildingDB.consumes_power(sprite.get_meta("building_id"))
		sprite.modulate = OFFLINE_TINT if offline else Color.WHITE
	_sync_crew()


## Floors are drawn back-to-front; a side slab shows only where no floor is in front.
func _draw_floor() -> void:
	var cells: Array = GameState.floors.keys()
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x + a.y < b.x + b.y)
	for cell in cells:
		var origin := Iso.tile_origin(cell)
		if not GameState.floors.has(cell + Vector2i.DOWN):
			_floor_layer.draw_texture(FLOOR_SIDE_L, origin)
		if not GameState.floors.has(cell + Vector2i.RIGHT):
			_floor_layer.draw_texture(FLOOR_SIDE_R, origin)
		_floor_layer.draw_texture(FLOOR_TOP, origin)


func _sync_building(cell: Vector2i, animate: bool) -> void:
	var id: String = GameState.buildings.get(cell, "")
	var sprite: Sprite2D = _sprites.get(cell)
	if id.is_empty():
		if sprite:
			sprite.queue_free()
			_sprites.erase(cell)
		return
	if sprite == null:
		sprite = Sprite2D.new()
		sprite.centered = false
		sprite.position = Iso.cell_to_world(cell)
		_objects.add_child(sprite)
		_sprites[cell] = sprite
	sprite.texture = BuildingDB.texture(id)
	sprite.offset = Iso.sprite_offset(sprite.texture)
	sprite.set_meta("building_id", id)
	if animate:
		sprite.scale = Vector2(1.0, 0.4)
		create_tween().tween_property(sprite, "scale", Vector2.ONE, 0.2) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _sync_crew() -> void:
	while _crew.size() < GameState.crew:
		var member := CrewMember.new()
		_objects.add_child(member)
		member.setup(_arrival_cell())
		_crew.append(member)
	while _crew.size() > GameState.crew:
		_crew.pop_back().queue_free()


## New crew step off a docking port if there is one, otherwise the core.
func _arrival_cell() -> Vector2i:
	for cell in GameState.buildings:
		if BuildingDB.get_def(GameState.buildings[cell]).get("dock", false):
			return cell
	return GameState.CORE_CELL
