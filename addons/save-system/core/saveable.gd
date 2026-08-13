@tool
class_name Saveable extends Node

const TRAIT_NAME := &"Saveable"
const VERSION = 0

signal saving
signal saved
signal loading
signal loaded

@export var enabled := true
@export var steps: Array[SaveStep]

var _save_uid


static func is_trait(node: Node) -> bool:
	return node.has_meta(TRAIT_NAME)


static func as_trait(node: Node) -> Saveable:
	return node.get_meta(TRAIT_NAME)


static func get_uid(v: Object) -> String:
	if v is Node:
		return ResourceUID.id_to_text(ResourceLoader.get_resource_uid(v.scene_file_path))
	if v is Resource:
		return ResourceUID.id_to_text(ResourceLoader.get_resource_uid(v.resource_path))
	return &""


static func make_save_uid(node) -> String:
	return "suid://" + str(node.get_path()).sha256_text().substr(0, 12)


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


func is_owner() -> bool:
	return steps.any(func(v: SaveStep): return v.is_owner())


func is_reinstantiated() -> bool:
	return steps.any(func(v: SaveStep): return v.is_reinstantiated())


# trait.save_unique_id(): {
# "meta": [parent.name, version, save, scene] e.g. "GuyNode3D": [1, "suid://bleh", "uid://godot"]
# "steps": {
# 	"step.title()": [step.version(), step.to()]
#   "funny": [1, "hehe"]
#   "xform": [1, {position, rotation, scale}]
# }}
#
# real example
# "suid://cehjd31b8s": {
# 	"meta": ["Node3D", "suid://cehjd31b8s", "uid://bh18dka82m", 0]
# 	["xform", 0]: []
# }
#
func serialized() -> Dictionary:
	saving.emit()
	if steps.is_empty():
		return {}

	var node := get_parent()
	var pref := SaveStep.Prefix.new()
	var data := {pref.title(): pref.to(node)}
	for step in steps:
		data.get_or_add("steps", {})[step.title()] = step.to(node)

	_save_uid = pref.get_prefix_save_uid(data)
	saved.emit()
	return data


func deserialize(data: Dictionary) -> void:
	for step in steps:
		var entry = data.get("steps", {}).get(step.title())
		if entry:
			step.from(get_parent(), entry)
