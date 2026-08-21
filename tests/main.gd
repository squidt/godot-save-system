class_name Main extends Node

signal transitioning
signal transitioned

@export_file("*.tscn") var inital_map = "uid://ci6dtybx64jjk"  # map_one.tscn

@onready var world_3d = $World3D

## Current map
var map: Node3D = null
## Current map uid
var map_uid = ""
## History of maps
var map_history := {}
var map_transit := {}


# add map_one as first map
func _ready() -> void:
	map_load(inital_map)
	transitioning.connect(_on_transitioning)
	transitioned.connect(_on_transitioned)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"save_game"):
		SaveManager.save_game()
	elif event.is_action_pressed(&"load_game"):
		SaveManager.load_game()
	elif event.is_action_pressed(&"print_save"):
		SaveManager._debug_print_serialization()


# 1. save
# 2. delete
# 3. spawn things
## Erase any previous map and load new one without serialization
func map_load(uid: String) -> void:
	if !ResourceUID.has_id(ResourceUID.text_to_id(uid)):
		push_error("damn")
	world_3d.get_children().all(func(c): c.queue_free())
	map = null
	map_uid = uid
	var new_map = load(uid).instantiate()
	$World3D.add_child(new_map, true)
	map = new_map


## Serialize, Transition, Deserialize from history
func map_transition(uid: String, data = {}) -> void:
	if map_uid == uid:
		return

	transitioning.emit()
	# TODO: no save 'map_transit' to disk, keep memory only
	map_transit = SaveGame.transit_to_dict(
		map_uid, uid, data.get("return", ""), data.get("entry", "")
	)
	var autosave_filepath := SaveManager.get_filepath_string(SaveManager.save_name + "-autosave")
	SaveManager.write_file(autosave_filepath, SaveManager.serialize())
	SaveManager.deserialize(SaveManager.read_file(autosave_filepath))
	map_transit = {}
	transitioned.emit()


## Map transition usage
func set_player_position(global_transform: Transform3D) -> void:
	var found = get_tree().get_first_node_in_group("Player")
	if found and "global_transform" in found:
		found.global_transform = global_transform


func _on_transitioning():
	pass


func _on_transitioned():
	pass
