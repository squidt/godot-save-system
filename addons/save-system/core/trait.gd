@tool
class_name SaveTrait extends Node

const TRAIT_NAME := &"SaveTrait"
const VERSION = 1

signal saving
signal saved
signal loading
signal loaded

@export var enabled := true
@export var steps: Array[SaveStep]

var _save_uid


static func is_trait(node: Node) -> bool:
	return node.has_meta(TRAIT_NAME)


static func as_trait(node: Node) -> SaveTrait:
	return node.get_meta(TRAIT_NAME)


static func get_uid(v: Object) -> String:
	if v is Node:
		return ResourceUID.id_to_text(ResourceLoader.get_resource_uid(v.scene_file_path))
	if v is Resource:
		return ResourceUID.id_to_text(ResourceLoader.get_resource_uid(v.resource_path))
	return &""


# Makes an object from [param uid], instantiates if necessary. Null otherwise
static func make_object(uid: String) -> Object:
	var id = ResourceUID.text_to_id(uid)
	if ResourceUID.has_id(id):
		var v = load(uid)
		if "instantiate" in v:
			return v.instantiate()
		return v
	return null


func _ready() -> void:
	assert(get_parent(), "Expected to be the child of any node.")
	get_parent().set_meta(TRAIT_NAME, self)


# "node.name": {
# "meta": [version, save, scene] e.g. "GuyNode3D": [1, "suid://bleh", "uid://godot"]
# "steps": {
# 	"step.title()": [step.version(), step.to()]
#   "funny": [1, "hehe"]
#   "xform": [1, {position, rotation, scale}]
# }}
func serialized() -> Dictionary:
	saving.emit()
	if steps.is_empty():
		return {}

	var node := get_parent()
	var dict := {"meta": get_save_meta(), "steps": {}}
	for step in steps:
		dict["steps"].merge({step.title(): step.to(node)})

	_save_uid = dict["meta"].get(1)
	saved.emit()
	return dict


func deserialize(data: Dictionary) -> void:
	for step in steps:
		var entry = data.get("steps", {}).get(step.title())
		if entry:
			step.from(get_parent(), entry)


# version, save uid, scene uid
func get_save_meta() -> Array:
	var node = get_parent()
	return [VERSION, make_save_uid(node), get_uid(node)]


func make_save_uid(node) -> String:
	return "suid://" + str(node.get_path()).sha256_text().substr(0, 12)
