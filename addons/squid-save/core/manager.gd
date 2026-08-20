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


## Constructs a [StringName] appending [constant USER], [constant FOLDER], and [constant EXTENSION]
## to create a formatted save filepath.
## [br]EXAMPLE:
## [br][code]"user://folder/<save>.extension"[/code][br]
## Does not perform i.o. operations
func get_filepath_string(save: StringName) -> StringName:
	return USER + FOLDER + save + EXTENSION


func write_file(filepath: StringName, data: Dictionary) -> Error:
	var dir := DirAccess.open(USER)
	if dir:
		var base := filepath.get_base_dir()
		if !dir.dir_exists(base):
			dir.make_dir_recursive(base)
	else:
		# TODO: Error handle
		push_error("Failed to Open user file (%s). Which is guranteed by Godot" % [USER])
		return DirAccess.get_open_error()

	var file := FileAccess.open(filepath, FileAccess.WRITE)
	if file:
		var json := JSON.stringify(data, "\t", false)
		file.store_string(json)
		file.close()
		return OK
	else:
		var err = FileAccess.get_open_error()
		push_error("FileAccess Error: ", error_string(FileAccess.get_open_error()))
		return err


func read_file(filepath: StringName) -> Dictionary:
	if !FileAccess.file_exists(filepath):
		printerr("File (%s) does not exist" % [filepath])
		return {}

	var file := FileAccess.open(filepath, FileAccess.READ)
	var data := JSON.parse_string(file.get_as_text()) as Dictionary
	file.close()

	if !data.has("name") or !data.has("date") or !data.has("version") or !data.has("state"):
		printerr("Expected fields (%s, %s, %s, %s) in game save data" % ["name", "date", "version", "state"])

	return data


func _ready() -> void:
	recreation = Recreation.NONE
	ownership = Ownership.MANUAL
	super()


func is_save_owner() -> bool:
	return true


func save_game() -> void:
	write_file(get_filepath_string(save_name), SaveManager.serialize())


func load_game() -> void:
	SaveManager.deserialize(read_file(get_filepath_string(save_name)))


func serialize() -> Dictionary:
	saving.emit()

	var node := get_parent()
	var data := {
		"name": save_name,
		"date": Time.get_datetime_string_from_system(),
		"version": VERSION,
		"state": SaveStep.Ownership.new().to(node)
	}

	saved.emit()
	return data


func deserialize(data: Dictionary) -> void:
	loading.emit()

	await SaveStep.Ownership.new().from(get_parent(), data.get("state"))

	loaded.emit()
