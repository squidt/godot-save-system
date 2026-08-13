@abstract
class_name SaveStep extends Resource

@abstract func title() -> StringName
@abstract func version() -> int
@abstract func on_ready(node) -> void
@abstract func to(node: Node) -> Variant
@abstract func from(node: Node, data: Variant) -> void


class Prefix:
	extends SaveStep

	static func static_title() -> StringName:
		return &"prefix"

	func title() -> StringName:
		return Prefix.static_title()

	func version() -> int:
		return 0

	func on_ready(node) -> void:
		pass

	func to(node: Node) -> Variant:
		return [node.name, Saveable.make_save_uid(node), Saveable.get_uid(node)]

	func from(node: Node, data: Variant) -> void:
		node.name = get_node_name(data)
		Saveable.as_trait(node)._save_uid = get_save_uid(data)

	static func get_node_name(data: Dictionary) -> String:
		return data[static_title()][0]

	static func get_save_uid(data: Dictionary) -> String:
		return data[static_title()][1]

	static func get_scene_uid(data: Dictionary) -> String:
		return data[static_title()][2]

	static func get_version(data: Dictionary) -> int:
		return data[static_title()][3]


class Ownership:
	extends SaveStep

	func title() -> StringName:
		return &"ownership"

	func version() -> int:
		return 0

	func on_ready(node) -> void:
		pass

	func to(node: Node) -> Variant:
		var data := {}
		var children := _collect_saveables(node)

		for child: Node in children:
			var child_save := Saveable.as_trait(child)
			var child_data := child_save.serialized()

			if !child_save.is_save_owner():
				child_data["path"] = node.get_path_to(child)

			# add child entry with save_uid as unique id for the list
			data[SaveStep.Prefix.get_save_uid(child_data)] = child_data
		return data

	# load steps for an owner
	# 1. free owned && reinstantiated nodes
	# 2. recreate owned && reinstantiated nodes present in data
	# 3. graft - add recreated to tree
	# 4. deserialize - data into recreated nodes || nodes not recreated
	#
	# data = Dictionary[SaveUID, Saveable's Data]
	func from(node: Node, data: Variant) -> void:
		assert(data is Dictionary)

		var restored: Dictionary[String, Node] = {}
		_queue_free_children(node)
		await node.get_tree().process_frame

		for child_save_uid in data.keys():
			var child_trait_data = data[child_save_uid]
			# local, subcomponent in scene that should not be reinstantiated
			if child_trait_data.has("path"):
				pass
			# reinstantiated
			else:
				var new = _recreate_child(node, SaveStep.Prefix.get_scene_uid(child_trait_data))
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
		for child in current.get_children():
			var saveable := Saveable.as_trait(child) if Saveable.is_trait(child) else null
			if !saveable or !saveable.is_enabled():
				continue

			out.append(child)

			if !saveable.is_save_owner():
				_collect_saveables_impl(child, out)
