class_name SaveOwner extends SaveStep

var restored: Dictionary[String, Node] = {}


func title() -> StringName:
	return &"owner"


func version() -> int:
	return 0


func is_enabled() -> bool:
	return true


func is_owner() -> bool:
	return true


func is_reinstantiated() -> bool:
	return true


func on_ready(node):
	pass


func to(node: Node) -> Variant:
	var data := {}
	var children := _collect_saveables(node)

	for child: Saveable in children:
		var child_data := child.serialized()

		if !child.is_reinstantiated():
			child_data["path"] = node.get_path_to(child)

		# add child entry with save_uid as unique id for the list
		data[SavePrefix.get_save_uid(child_data)] = child_data
	return {}


# load steps for an owner
# 1. free owned && reinstantiated nodes
# 2. recreate owned && reinstantiated nodes present in data
# 3. graft - add recreated to tree
# 4. deserialize - data into recreated nodes || nodes not recreated
#
# data = Dictionary[SaveUID, Saveable's Data]
func from(node: Node, data: Variant) -> void:
	assert(data is Dictionary)

	_queue_free_children(node)
	await node.get_tree().process_frame

	for child_save_uid in data.keys():
		var child_trait_data = data[child_save_uid]
		# local, subcomponent in scene that should not be reinstantiated
		if child_trait_data.has("path"):
			pass
		# reinstantiated
		else:
			var new = _recreate_child(node, SavePrefix.get_scene_uid(child_trait_data))
			if !new:
				continue
			restored[child_save_uid] = new

			# Apply data
			var child_saveable = Saveable.as_trait(new)
			assert(child_saveable)
			child_saveable._save_uid = child_save_uid
			child_saveable.deserialize(child_trait_data)


func _queue_free_children(node) -> void:
	var children := _collect_saveables(node)
	for child in children:
		if child.is_reinstantiated():
			child.get_parent().queue_free()


func _recreate_child(node, scene_uid: String):
	if !ResourceUID.has_id(ResourceUID.text_to_id(scene_uid)):
		return null

	var new = load(scene_uid).instantiate()
	if new:
		node.add_child(new, true)
	return new


## Returns the owners of the trait [Saveable], not [Saveable]s themselves
func _collect_saveables(root: Node) -> Array[Node]:
	var out: Array[Node] = []
	_collect_saveables_impl(root, out)
	return out


# root
# for child in root:
# if child: Node has Saveable trait (as child) (via Saveable.is_trait(child))
# out.push(Saveable.as_trait(child))
#
# root
# 	- child1
# 	- child2 - saveable, owner
# 		- Saveable:Node (owner)
#   - child3 - saveable, owner, !enabled
# 		- Saveable:Node
# 	- child4 - saveable, !enabled
# 		- ...
# 	- child5 - saveable
# 		- ...
func _collect_saveables_impl(current: Node, out: Array[Node]) -> void:
	for child in current.get_chidren():
		var saveable := Saveable.as_trait(child) if Saveable.is_trait(child) else null
		if !saveable or !saveable.is_enabled():
			continue

		out.append(child)

		if !saveable.is_owner():
			_collect_saveables_impl(child, out)
