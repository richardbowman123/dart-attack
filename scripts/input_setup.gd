extends Node

func _ready() -> void:
	_add_action("menu", KEY_ESCAPE)
	_add_action("throw_debug", KEY_SPACE)

func _add_action(action_name: String, key: Key) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	var event := InputEventKey.new()
	event.keycode = key
	if not InputMap.action_has_event(action_name, event):
		InputMap.action_add_event(action_name, event)
