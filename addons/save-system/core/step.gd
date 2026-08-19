class_name SaveStep extends Resource


static func title() -> StringName:
	push_error("Abstract class function called. Expected implementation from inherited class")
	return &"invalid"


static func on_ready(_node) -> void:
	return


static func to(_node: Node) -> Variant:
	push_error("Abstract class function called. Expected implementation from inherited class")
	return "invalid"


static func from(_node: Node, _data: Variant) -> void:
	push_error("Abstract class function called. Expected implementation from inherited class")


class Prefix:
	extends SaveStep

	static func title() -> StringName:
		return &"prefix"

	static func to(node: Node) -> Variant:
		var save_owner = get_save_owner(node)
		var name = save_owner.get_path_to(node) if save_owner else node.name
		return [name, Saveable.make_save_uid(node), Saveable.get_uid(node)]

	static func from(node: Node, data: Variant) -> void:
		node.name = get_node_name(data).rsplit("/", false, 1).get(1)
		Saveable.as_trait(node)._save_uid = get_save_uid(data)

	static func get_node_name(data: Dictionary) -> String:
		return data[title()][0]

	static func get_save_uid(data: Dictionary) -> String:
		return data[title()][1]

	static func get_scene_uid(data: Dictionary) -> String:
		return data[title()][2]

	static func get_version(data: Dictionary) -> int:
		return data[title()][3]

	static func get_save_owner(node: Node) -> Node:
		var current = node.get_parent()
		while current:
			var current_trait = Saveable.as_trait(current) if Saveable.is_trait(current) else null
			if current_trait and current_trait.is_save_owner():
				return current
			current = current.get_parent()
		return null


class Ownership:
	extends SaveStep

	static func title() -> StringName:
		return &"ownership"

	static func on_ready(node) -> void:
		pass

	static func to(node: Node) -> Variant:
		var data := {}
		var children := _collect_saveables(node)

		for child: Node in children:
			var child_save := Saveable.as_trait(child)
			var child_data := child_save.serialized()

			if !child_save.is_save_owner():
				child_data["local"] = true
			else:
				child_data["local"] = false

			# add child entry with save_uid as unique id for the list
			data[SaveStep.Prefix.get_save_uid(child_data)] = child_data
		return data

	# load steps for an owner
	# 1. free owned && reinstantiated nodes (handled by SaveManager)
	# 2. recreate owned && reinstantiated nodes present in data
	# 3. graft - add recreated to tree
	# 4. deserialize - data into recreated nodes || nodes not recreated
	#
	# data = Dictionary[SaveUID, Saveable's Data]
	static func from(node: Node, data: Variant) -> void:
		assert(data is Dictionary)

		var restored: Dictionary[String, Node] = {}

		_queue_free_first_saveables(node)

		# wait twice to fix name clashes on add_child()
		await node.get_tree().process_frame
		await node.get_tree().process_frame
		# end wait twice

		for child_save_uid in data.keys():
			var child_trait_data = data[child_save_uid]
			# local, subcomponent in scene that should not be reinstantiated (set data only)
			var path_in_scene: NodePath = child_trait_data.get("prefix").get(0)
			if child_trait_data.get("local"):
				var local = node.get_node(path_in_scene)
				var local_trait = Saveable.as_trait(local)
				local_trait.deserialize(child_trait_data)
				#breakpoint
			# reinstantiated
			else:
				var new = _recreate_child(SaveStep.Prefix.get_scene_uid(child_trait_data))
				if !new:  # TODO: error printing/ handle/ default error obj
					continue
				restored[child_save_uid] = new

				# get only path to parent
				var graft_path = _rtrim_last_name(path_in_scene)
				var graft_target = node.get_node(graft_path)
				if graft_target:  # TODO: error handling
					_graft_child(graft_target, new)
					new.name = child_trait_data.get("prefix").get(0)
				else:
					print_debug(
						(
							"SaveStep::Ownership::from(line:104): Cannot add new node to path (%s) as it no longer exists in the scene. Attempting to add to root of scene"
							% [graft_path]
						)
					)
					_graft_child(node, new)

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

	static func _recreate_child(scene_uid: String) -> Node:
		if !ResourceUID.has_id(ResourceUID.text_to_id(scene_uid)):
			return null
		return load(scene_uid).instantiate()

	static func _graft_child(node: Node, child: Node) -> void:
		node.add_child(child, true, Node.INTERNAL_MODE_DISABLED)

	static func _queue_free_first_saveables(node: Node) -> void:
		for child in node.get_children():
			var saveable = Saveable.as_trait(child) if Saveable.is_trait(child) else null
			if saveable and saveable.is_save_owner():
				child.queue_free()
			else:
				_queue_free_first_saveables(child)

	## Returns the parent of [param path]
	## Removes the last name in NodePath
	static func _rtrim_last_name(path: NodePath) -> NodePath:
		if path.get_name_count() == 1:
			return NodePath(".")
		return NodePath(path.get_concatenated_names().rsplit("/", true, 1).get(0))

	## Returns the owners of the trait [Saveable], not [Saveable]s themselves
	static func _collect_saveables(root: Node) -> Array[Node]:
		var out: Array[Node] = []
		_collect_saveables_impl(root, out)
		print("%s collected %s:" % [root, out])
		#for n in out:
		#print("  %s" % [n.name])
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
	static func _collect_saveables_impl(current: Node, out: Array[Node]) -> void:
		for child in current.get_children():
			var saveable := Saveable.as_trait(child) if Saveable.is_trait(child) else null

			# collect
			if saveable:
				if saveable.is_enabled():
					out.append(child)
				if saveable.is_save_owner():
					continue

			# recursion if not save owner
			_collect_saveables_impl(child, out)

# collect if:
# - valid
# - enabled

# recursion if:
# - node
# - not is_save_owner()
