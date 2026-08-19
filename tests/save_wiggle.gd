class_name SaveWiggle extends SaveStep


static func title() -> StringName:
	return &"wiggle"


static func on_ready(node) -> void:
	return


static func to(node: Node) -> Variant:
	return node.get("wiggle")


static func from(node: Node, data: Variant) -> void:
	node.set("wiggle", data)
