class_name Iso
## 2:1 isometric grid math. Cell (x, y) <-> world pixels.
## +x runs down-right on screen, +y runs down-left; cell_to_world() is the tile centre.

const TILE_SIZE := Vector2i(32, 16)
const HALF_W := 16
const HALF_H := 8


static func cell_to_world(cell: Vector2i) -> Vector2:
	return Vector2((cell.x - cell.y) * HALF_W, (cell.x + cell.y) * HALF_H)


static func world_to_cell(pos: Vector2) -> Vector2i:
	var a := pos.x / HALF_W
	var b := pos.y / HALF_H
	return Vector2i(floori((a + b) * 0.5 + 0.5), floori((b - a) * 0.5 + 0.5))


## Top-left corner of the tile's 32x16 diamond.
static func tile_origin(cell: Vector2i) -> Vector2:
	return cell_to_world(cell) - Vector2(HALF_W, HALF_H)


## Offset for an uncentred Sprite2D placed at cell_to_world(): the bottom 16 rows of
## every module sprite are its footprint diamond (see docs/ART_PIPELINE.md).
static func sprite_offset(texture: Texture2D) -> Vector2:
	return Vector2(-HALF_W, -(texture.get_height() - HALF_H))
