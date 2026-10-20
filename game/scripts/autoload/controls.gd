extends Node
## Registers input actions in code so every binding lives in one readable place.
## Physical keycodes keep WASD in the same spot on AZERTY/QWERTZ keyboards.

const BINDINGS := {
	"cam_left": [KEY_A, KEY_LEFT],
	"cam_right": [KEY_D, KEY_RIGHT],
	"cam_up": [KEY_W, KEY_UP],
	"cam_down": [KEY_S, KEY_DOWN],
	"pause": [KEY_SPACE],
	"speed_cycle": [KEY_TAB],
	"save_game": [KEY_F5],
	"load_game": [KEY_F9],
	"new_game": [KEY_F2],
	"tool_cancel": [KEY_ESCAPE],
	"tool_demolish": [KEY_X],
}
const TOOL_KEYS := [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9]


func _enter_tree() -> void:
	for action in BINDINGS:
		_bind(action, BINDINGS[action])
	for i in TOOL_KEYS.size():
		_bind(tool_action(i), [TOOL_KEYS[i]])


## Action name for the n-th (0-based) slot of the build palette.
static func tool_action(index: int) -> String:
	return "tool_%d" % (index + 1)


func _bind(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for key in keys:
		var event := InputEventKey.new()
		event.physical_keycode = key
		InputMap.action_add_event(action, event)
