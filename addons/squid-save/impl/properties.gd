class_name SaveProperties extends SaveStep

@export var properties: Array[StringName]


static func title() -> StringName:
	return &"properties"


func to(node: Node) -> Variant:
	var data := {}
	for p in properties:
		if p in node:
			data[p] = JSON.stringify(JSON.from_native(node.get(p)))
	return data


func from(node: Node, data: Variant) -> void:
	assert(data is Dictionary)
	for property in data.keys():
		if property in node:
			node.set(property, JSON.to_native(JSON.parse_string(data[property])))
