@tool
class_name Saveable extends Node

const TRAIT_NAME := &"Saveable"

signal saving
signal saved
signal loading
signal loaded

@export_tool_button("print") var savenprint = _debug_print_serialization
@export var _enabled := true

## Recreates the trait owner from disk, then loads in save data if the trait owner is a .tscn file.
## Set to false for child scenes that are not desired to be recreated i.e. they may have settings
## already set inside of the parent scene that are not included in the save steps or the original
## scene.
@export var _recreated := true
@export var behavior := SaveBehavior.new()

var _save_uid


static func is_trait(node: Node) -> bool:
	return node.has_meta(TRAIT_NAME)


static func as_trait(node: Node) -> Saveable:
	return node.get_meta(TRAIT_NAME)


static func if_is_trait(node: Node, callable: Callable, default_return = null):
	if Saveable.is_trait(node):
		return callable.call(Saveable.as_trait(node))
	return default_return


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
	assert(behavior, "Expected 'Saveable::behavior' to be valid.")
	if !Engine.is_editor_hint():
		get_parent().set_meta(TRAIT_NAME, self)


func is_enabled() -> bool:
	return _enabled


func is_recreated() -> bool:
	return _recreated


func is_save_owner() -> bool:
	assert(
		get_parent(),
		(
			"Orphaned [Saveable]. Somehow a [Saveable] has been added to the meta of a node "
			+ "without the [Saveable] itself being inside the scene tree. This has happened "
			+ "either due to a tool script or user chicanery and or sheganery."
		)
	)
	return !get_parent().scene_file_path.is_empty() and is_recreated()


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
func serialize() -> Dictionary:
	saving.emit()

	var node := get_parent()
	var data := {}

	# prefix
	var pref := SaveStep.Prefix.new()
	data[pref.title()] = pref.to(node)
	for step in behavior.steps:
		data[step.title()] = step.to(node)

	# ownership of nested saves if applicable
	if is_save_owner():
		var ownership := SaveStep.Ownership.to(node)
		if !ownership.is_empty():
			data[SaveStep.Ownership.title()] = ownership

	_save_uid = pref.get_save_uid(data)
	saved.emit()
	return data


func deserialize(data: Dictionary) -> void:
	loading.emit()
	var node := get_parent()
	var prefix_path: String = (data.get(SaveStep.Prefix.title(), []) as Array).get(0)
	var prefix_array = prefix_path.rsplit("/", false, 1) if prefix_path else PackedStringArray()
	var prefix_name = (
		prefix_array.get(1)
		if prefix_array.size() > 1
		else prefix_array.get(0) if !prefix_array.is_empty() else "Unnamed"
	)
	node.name = prefix_name
	for step in behavior.steps:
		var entry = data.get(step.title())
		if entry:
			step.from(get_parent(), entry)
	if is_save_owner() and data.has(SaveStep.Ownership.title()):
		SaveStep.Ownership.from(node, data[SaveStep.Ownership.title()])
	loaded.emit()


func _debug_print_serialization() -> void:
	print_debug("\n", JSON.stringify(serialize(), "    ", false))
