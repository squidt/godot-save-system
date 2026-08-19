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


# 1. save
# 2. delete
# 3. spawn things
## Erase any previous map and load new one without serialization
func map_load(uid: String) -> void:
	world_3d.get_children().all(func(c): c.queue_free())
	map = null
	map_uid = uid
	var new_map = load(uid).instantiate()
	$World3D.add_child(new_map, true)
	map = new_map


## Serialize, Transition, Deserialize from history
func map_transition(uid: String, transit_return: String, transit_entry: String) -> void:
	if map_uid == uid:
		print_debug("Already on map (%s), no transition" % [uid])
		return

	transitioning.emit()
	map_transit = SaveGame.transit_to_dict(map_uid, uid, transit_return, transit_entry)
	SaveManager.save_game()
	SaveManager.load_game()
	transitioned.emit()


## Map transition usage
func set_player_position(global_transform: Transform3D) -> void:
	var found = get_tree().get_first_node_in_group("Player")
	if found and "global_transform" in found:
		found.global_transform = global_transform


# save game state
# record some info
func _on_transitioning():
	pass


# load map
# set player
func _on_transitioned():
	pass
