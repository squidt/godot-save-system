@tool
extends Saveable

const VERSION := &"0.0.1a"
const USER = &"user://"
const FOLDER = &"saves/"
const EXTENSION = &".json"

# TODO:
# profiles -> name, newest save timestamp, newest save thumbnail
# slot -> name, timestamp, thumbnail

static var save_name = &"profile1"


static func make_filepath(save_name: StringName) -> StringName:
	return USER + FOLDER + save_name + EXTENSION


static func _write_file(save_name: StringName, data: Dictionary) -> void:
	var dir := DirAccess.open(USER)
	if !dir.dir_exists(FOLDER):
		dir.make_dir_recursive(FOLDER)

	var filepath = make_filepath(save_name)
	var file := FileAccess.open(filepath, FileAccess.WRITE)
	if !file:
		print("FileAccess Error: ", error_string(FileAccess.get_open_error()))
	var json := JSON.stringify(data, "\t", false)
	file.store_string(json)
	file.close()


static func _read_file(save_name: StringName) -> Dictionary:
	var filepath = make_filepath(save_name)
	if !FileAccess.file_exists(filepath):
		printerr("File (%s) does not exist" % [filepath])
		return {}

	var file := FileAccess.open(filepath, FileAccess.READ)
	var data := JSON.parse_string(file.get_as_text()) as Dictionary
	file.close()
	return data


func _ready() -> void:
	_recreated = false
	print("ready called?")
	super()


func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return

	if event.is_action_pressed(&"save_game"):
		save_game()
	elif event.is_action_pressed(&"load_game"):
		load_game()
	elif event.is_action_pressed(&"print_save"):
		_debug_print_serialization()


func is_save_owner() -> bool:
	return true


func save_game() -> void:
	_write_file(save_name, SaveManager.serialize())


func load_game() -> void:
	var data := _read_file(save_name)

	if !data.has("name") or !data.has("date") or !data.has("version") or !data.has("state"):
		printerr("Expected required fields in game save")
		return

	SaveManager.deserialize(data)


func serialize() -> Dictionary:
	saving.emit()

	var node := get_parent()
	var data := {
		"name": save_name,
		"date": Time.get_datetime_string_from_system(),
		"version": VERSION,
		"state": SaveStep.Ownership.to(node)
	}

	saved.emit()
	return data


func deserialize(data: Dictionary) -> void:
	loading.emit()

	SaveStep.Ownership.from(get_parent(), data.get("game"))

	loaded.emit()
