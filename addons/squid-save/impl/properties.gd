class_name SaveProperties extends SaveStep

@export var properties: Array[StringName]


static func title() -> StringName:
	return &"properties"


func to(node: Node) -> Variant:
	var data := {}
	for property in properties:
		if property in node:
			data[property] = JSON.from_native(node.get(property))
	return data


func from(node: Node, data: Variant) -> void:
	assert(data is Dictionary)
	for property in data.keys():
		if property in node:
			node.set(property, JSON.to_native(data.get(property)))
