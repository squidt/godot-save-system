class_name SaveWiggle extends SaveStep


static func title() -> StringName:
	return &"wiggle"


func to(node: Node) -> Variant:
	return node.get("wiggle")


func from(node: Node, data: Variant) -> void:
	node.set("wiggle", data)
