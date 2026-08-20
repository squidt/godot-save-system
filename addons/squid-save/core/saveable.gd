@tool
class_name Saveable extends Node

const TRAIT_NAME := &"Saveable"

enum Ownership {
	NONE,
	AUTO,
	MANUAL,
}

enum Recreation {
	NONE,
	AUTO,
}

signal saving
signal saved
signal loading
signal loaded

@export_tool_button("print") var savenprint = _debug_print_serialization
@export var _enabled := true

## Ownership model. See [member Ownership]
@export var ownership = Ownership.AUTO
## Recreates the trait owner from disk, then loads in save data if the trait owner is a .tscn file.
## Set to false for child scenes that are not desired to be recreated i.e. they may have settings
## already set inside of the parent scene that are not included in the save steps or the original
## scene.
@export var recreation = Recreation.AUTO
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


func is_recreatable() -> bool:
	return !get_parent().scene_file_path.is_empty() and recreation != Recreation.NONE


func is_save_owner() -> bool:
	assert(
		get_parent(),
		(
			"Orphaned [Saveable]. Somehow a [Saveable] has been added to the meta of a node "
			+ "without the [Saveable] itself being inside the scene tree. This has happened "
			+ "either due to a tool script or user chicanery and or sheganery."
		)
	)
	return (is_recreatable() or ownership == Ownership.MANUAL) and ownership != Ownership.NONE


func serialize() -> Dictionary:
	saving.emit()

	var node := get_parent()
	var data := {}

	# prefix
	var pref := SaveStep.Prefix.new()
	data[pref.title()] = pref.to(node)
	for step in behavior.steps:
		data[step.title()] = step.to(node)

	_append_ownership(node, data)

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
	SaveStep.Prefix.new().from(node, data.get(SaveStep.Prefix.title()))
	for step in behavior.steps:
		var entry = data.get(step.title())
		if entry:
			step.from(get_parent(), entry)
	if is_save_owner() and data.has(SaveStep.Ownership.title()):
		SaveStep.Ownership.new().from(node, data[SaveStep.Ownership.title()])
	loaded.emit()


## Appends ownership to data if applicable
func _append_ownership(node: Node, data: Dictionary) -> void:
	if ownership == Ownership.AUTO and is_save_owner():
		var ownership := SaveStep.Ownership.new().to(node)
		if !ownership.is_empty():
			data[SaveStep.Ownership.title()] = ownership


func _debug_print_serialization() -> void:
	print_debug("\n", JSON.stringify(serialize(), "    ", false))
