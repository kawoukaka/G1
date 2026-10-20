extends Sprite2D
## Visual-only crew member that idles and wanders between free floor tiles.
## Phase 1 replaces this with job-driven agents and AStarGrid2D pathfinding.

const TEXTURES := [
	preload("res://assets/sprites/crew/crew_0.png"),
	preload("res://assets/sprites/crew/crew_1.png"),
	preload("res://assets/sprites/crew/crew_2.png"),
	preload("res://assets/sprites/crew/crew_3.png"),
]
const STEP_SECONDS := 0.6

var cell := Vector2i.ZERO
var _wait := 0.0
var _tween: Tween


func setup(start: Vector2i) -> void:
	cell = start
	texture = TEXTURES.pick_random()
	centered = false
	offset = Vector2(-floorf(texture.get_width() / 2.0), 1 - texture.get_height())
	position = _cell_position(cell)
	_wait = randf_range(0.3, 1.5)


func _process(delta: float) -> void:
	var speed := GameState.current_speed()
	if _tween:
		if speed == 0:
			_tween.pause()
		else:
			_tween.set_speed_scale(speed)
			_tween.play()
		return
	if not GameState.floors.has(cell):
		cell = GameState.floors.keys().pick_random()
		position = _cell_position(cell)
		return
	if speed == 0:
		return
	_wait -= delta * speed
	if _wait <= 0.0:
		_step()


func _step() -> void:
	_wait = randf_range(0.5, 3.0)
	var options: Array[Vector2i] = []
	for offset_dir in GameState.NEIGHBORS:
		var next: Vector2i = cell + offset_dir
		if GameState.floors.has(next) and not GameState.buildings.has(next):
			options.append(next)
	if options.is_empty():
		return
	cell = options.pick_random()
	var target := _cell_position(cell)
	flip_h = target.x < position.x
	_tween = create_tween()
	_tween.tween_property(self, "position", target, STEP_SECONDS)
	_tween.finished.connect(func() -> void: _tween = null)


## Tile centre plus a little jitter so crew sharing a tile don't overlap exactly.
func _cell_position(c: Vector2i) -> Vector2:
	return (Iso.cell_to_world(c) + Vector2(randi_range(-5, 5), randi_range(-2, 2))).round()
