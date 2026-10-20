extends Camera2D
## Pixel-friendly camera: integer zoom steps (no mixels), keyboard and middle-mouse
## panning, and zoom that keeps the point under the cursor fixed.

const ZOOM_LEVELS := [1.0, 2.0, 3.0, 4.0, 6.0]
const PAN_SPEED := 700.0 ## Screen pixels per second.
const LIMIT := 1500.0 ## World pixels from the core.
const MAGNIFY_STEP := 0.15 ## Accumulated trackpad pinch needed per zoom step.

var _zoom_index := 2
var _dragging := false
var _pinch := 0.0


func _ready() -> void:
	zoom = Vector2.ONE * ZOOM_LEVELS[_zoom_index]
	make_current()


func _process(delta: float) -> void:
	var dir := Input.get_vector("cam_left", "cam_right", "cam_up", "cam_down")
	if dir != Vector2.ZERO:
		position += dir * PAN_SPEED * delta / zoom.x
		_clamp()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				if event.pressed:
					_zoom_step(1)
			MOUSE_BUTTON_WHEEL_DOWN:
				if event.pressed:
					_zoom_step(-1)
			MOUSE_BUTTON_MIDDLE:
				_dragging = event.pressed
	elif event is InputEventMouseMotion and _dragging:
		position -= event.relative / zoom.x
		_clamp()
	elif event is InputEventMagnifyGesture:
		_pinch += event.factor - 1.0
		if absf(_pinch) >= MAGNIFY_STEP:
			_zoom_step(1 if _pinch > 0.0 else -1)
			_pinch = 0.0


func _zoom_step(direction: int) -> void:
	var index := clampi(_zoom_index + direction, 0, ZOOM_LEVELS.size() - 1)
	if index == _zoom_index:
		return
	var from_centre := get_viewport().get_mouse_position() - get_viewport_rect().size / 2.0
	var anchor := position + from_centre / zoom.x
	_zoom_index = index
	zoom = Vector2.ONE * ZOOM_LEVELS[index]
	position = anchor - from_centre / zoom.x
	_clamp()


func _clamp() -> void:
	position = position.clamp(Vector2(-LIMIT, -LIMIT), Vector2(LIMIT, LIMIT))
