class_name SaveGame extends SaveStep

# TODO:
# save:
# current map uid
# map to history
# - transition point, re-entry point

# load
# - spawn last map
# - spawn map history
# - spawn player @ entry point

# Q: any diff b/t map transition and saving entire game state?
# game state:
# - meta: thumb, time, some stats
# - player
# - map (transition)
# - map state

# loading game state can't cause a .map_transition or it will recurse against { map_tranit { save_game, load_game } }

# map transit {
# set game state to load new map, set player transition point
# save game state {}
# load game state {}
# }

# save game state {}
# load game state { free scenes, load json, load map from disk, set map data from json, }


static func title() -> StringName:
	return &"game"


func to(node: Node) -> Variant:
	assert(node is Main)
	node = node as Main

	node.map_history[node.map_uid] = Saveable.if_is_trait(
		node.map, func(save: Saveable): return save.serialize(), {}
	)
	var data := {"map": node.map_uid, "history": node.map_history}
	if !node.map_transit.is_empty():
		data["transit"] = node.map_transit
	return data


# difference b/t saving game state and map transition:
# game state has no 'transit' data
# transit will load map being moved to, then load from history
func from(node: Node, data: Variant) -> void:
	assert(node is Main)
	node = node as Main

	# get transit map or current map
	# TODO: explicitly hande transit/ load map fail with warnings instead of defaulting back to original map
	var map_uid = (
		data.get("transit").get("to", data.get("map")) if data.has("transit") else data.get("map")
	)

	# load from disk
	node.map_load(map_uid)
	node.map_history = data.get("history")
	if node.map_history.has(map_uid):
		Saveable.if_is_trait(
			node.map, func(save: Saveable): save.deserialize(node.map_history.get(map_uid))
		)

	# handle player move
	if data.has("transit"):
		var transits = node.get_tree().get_nodes_in_group("Transit")
		var found = transits.find_custom(
			func(v: Node): return data.get("transit").get("entry") == v.transit_name
		)
		if found != -1 and "get_transit_point" in found:
			node.set_player_position(found.get_transit_point())


static func transit_to_dict(
	_from_map: String, _to_map: String, _return_point: String, _entry_point: String
) -> Dictionary:
	return {
		"from": _from_map,
		"to": _to_map,
		"return": _return_point,
		"entry": _entry_point,
	}
