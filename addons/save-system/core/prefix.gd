class_name SavePrefix extends SaveStep


static func static_title() -> StringName:
	return &"prefix"


func title() -> StringName:
	return SavePrefix.static_title()


func version() -> int:
	return 0


func is_owner() -> bool:
	return false


func is_enabled() -> bool:
	return true


func is_reinstantiated() -> bool:
	return false


func on_ready(node):
	pass


func to(node: Node) -> Variant:
	return [node.name, Saveable.make_save_uid(node), Saveable.get_uid(node), Saveable.VERSION]


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
