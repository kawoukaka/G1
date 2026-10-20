extends Node2D
## Screen-space starfield with parallax depths plus a distant planet.
## Lives on a background CanvasLayer, so it reads the camera position each frame.

const STAR_COUNT := 280
const DEPTHS := [0.03, 0.08, 0.18] ## Parallax factor per depth layer.
const STAR_COLORS := [Color("4a4e69"), Color("8d99ae"), Color("c9d1dc"), Color("f8f9fa"), Color("6fb3ff"), Color("ffd166")]
const SPACE_COLOR := Color("0b0a17")
const PLANET := preload("res://assets/sprites/fx/planet.png")
const PLANET_SCALE := 4
const PLANET_DEPTH := 0.015

var _stars: Array[Dictionary] = []


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in STAR_COUNT:
		var depth := rng.randi_range(0, DEPTHS.size() - 1)
		_stars.append({
			"pos": Vector2(rng.randf(), rng.randf()),
			"depth": depth,
			"color": STAR_COLORS[rng.randi_range(0, depth + 3)],
			"size": 2.0 if depth < 2 else 3.0,
		})


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var size := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, size), SPACE_COLOR)
	var camera := get_viewport().get_camera_2d()
	var cam_pos := camera.position if camera else Vector2.ZERO

	var planet_pos := (size * Vector2(0.72, 0.58) - cam_pos * PLANET_DEPTH).round()
	draw_texture_rect(PLANET, Rect2(planet_pos, PLANET.get_size() * PLANET_SCALE), false)

	for star in _stars:
		var p: Vector2 = star.pos * size - cam_pos * DEPTHS[star.depth]
		p = Vector2(fposmod(p.x, size.x), fposmod(p.y, size.y)).floor()
		draw_rect(Rect2(p, Vector2.ONE * star.size), star.color)
