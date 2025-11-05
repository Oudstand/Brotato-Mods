extends Node

# Signal emitted when any option value changes
# Parameters: mod_id (String), option_id (String), new_value (Variant)
signal config_changed(mod_id, option_id, new_value)

# Stores registered mod configurations
# Structure: { "ModName": { "tab_title": "...", "options": [...] } }
var _registered_mods := {}

# Stores actual option values
# Structure: { "ModName": { "option_id": value } }
var _config_values := {}


func _ready() -> void:
	pass


# Register a mod's options configuration
# mod_id: Unique identifier for the mod (e.g., "DamageMeter")
# config: Dictionary with structure:
#   {
#       "tab_title": "Translation key or display name",
#       "options": [
#           {
#               "type": "slider" | "toggle" | "dropdown",
#               "id": "unique_option_id",
#               "label": "Translation key or display name",
#               "default": default_value,
#               # For sliders:
#               "min": float,
#               "max": float,
#               "step": float,
#               "display_as_integer": bool (optional),
#               # For dropdowns:
#               "choices": ["choice1", "choice2", ...]
#           }
#       ]
#   }
func register_mod_options(mod_id: String, config: Dictionary) -> void:
	if _registered_mods.has(mod_id):
		ModLoaderLog.error("ModOptions: Mod '%s' is already registered" % mod_id, "ModOptions")
		return

	if not _validate_config(mod_id, config):
		return

	_registered_mods[mod_id] = config
	_load_config(mod_id)
	ModLoaderLog.info("ModOptions: Mod '%s' registered successfully" % mod_id, "ModOptions")


# Get an option value for a specific mod
func get_value(mod_id: String, option_id: String):
	if not _config_values.has(mod_id):
		ModLoaderLog.error("ModOptions: Mod '%s' not registered" % mod_id, "ModOptions")
		return null

	if not _config_values[mod_id].has(option_id):
		ModLoaderLog.error("ModOptions: Option '%s' not found for mod '%s'" % [option_id, mod_id], "ModOptions")
		return null

	return _config_values[mod_id][option_id]


# Set an option value for a specific mod
func set_value(mod_id: String, option_id: String, value) -> void:
	if not _config_values.has(mod_id):
		ModLoaderLog.error("ModOptions: Mod '%s' not registered" % mod_id, "ModOptions")
		return

	if not _config_values[mod_id].has(option_id):
		ModLoaderLog.error("ModOptions: Option '%s' not found for mod '%s'" % [option_id, mod_id], "ModOptions")
		return

	_config_values[mod_id][option_id] = value
	_save_config(mod_id)
	emit_signal("config_changed", mod_id, option_id, value)


# Get all registered mod IDs
func get_registered_mods() -> Array:
	return _registered_mods.keys()


# Get the full configuration for a specific mod
func get_mod_config(mod_id: String) -> Dictionary:
	if not _registered_mods.has(mod_id):
		return {}
	return _registered_mods[mod_id]


# Get all current values for a specific mod
func get_mod_values(mod_id: String) -> Dictionary:
	if not _config_values.has(mod_id):
		return {}
	return _config_values[mod_id].duplicate()


# Validate config structure
func _validate_config(mod_id: String, config: Dictionary) -> bool:
	if not config.has("tab_title"):
		ModLoaderLog.error("ModOptions: Config for '%s' missing 'tab_title'" % mod_id, "ModOptions")
		return false

	if not config.has("options") or not config.options is Array:
		ModLoaderLog.error("ModOptions: Config for '%s' missing or invalid 'options' array" % mod_id, "ModOptions")
		return false

	for option in config.options:
		if not option is Dictionary:
			ModLoaderLog.error("ModOptions: Invalid option format in '%s'" % mod_id, "ModOptions")
			return false

		if not option.has("type") or not option.has("id") or not option.has("label") or not option.has("default"):
			ModLoaderLog.error("ModOptions: Option in '%s' missing required fields (type, id, label, default)" % mod_id, "ModOptions")
			return false

		var type = option.type
		if type == "slider":
			if not option.has("min") or not option.has("max") or not option.has("step"):
				ModLoaderLog.error("ModOptions: Slider option '%s' in '%s' missing min/max/step" % [option.id, mod_id], "ModOptions")
				return false
		elif type == "dropdown":
			if not option.has("choices") or not option.choices is Array or option.choices.empty():
				ModLoaderLog.error("ModOptions: Dropdown option '%s' in '%s' missing or empty 'choices'" % [option.id, mod_id], "ModOptions")
				return false
		elif type == "item_selector":
			if not option.has("item_type"):
				ModLoaderLog.error("ModOptions: Item selector option '%s' in '%s' missing 'item_type'" % [option.id, mod_id], "ModOptions")
				return false
		elif type != "toggle" and type != "text":
			ModLoaderLog.error("ModOptions: Unknown option type '%s' for option '%s' in '%s'" % [type, option.id, mod_id], "ModOptions")
			return false

	return true


# Load config from file for a specific mod
func _load_config(mod_id: String) -> void:
	var config_path := "user://mod_options_%s.json" % mod_id
	var file := File.new()

	_config_values[mod_id] = {}

	# Initialize with defaults
	for option in _registered_mods[mod_id].options:
		_config_values[mod_id][option.id] = option.default

	# Load saved values if file exists
	if file.file_exists(config_path):
		var error := file.open(config_path, File.READ)
		if error == OK:
			var json_result := JSON.parse(file.get_as_text())
			file.close()

			if json_result.error == OK and json_result.result is Dictionary:
				var saved_values: Dictionary = json_result.result

				# Only apply saved values for options that still exist
				for option_id in saved_values.keys():
					if _config_values[mod_id].has(option_id):
						_config_values[mod_id][option_id] = saved_values[option_id]
			else:
				ModLoaderLog.warning("ModOptions: Failed to parse config for '%s'" % mod_id, "ModOptions")
		else:
			ModLoaderLog.warning("ModOptions: Failed to open config file for '%s'" % mod_id, "ModOptions")


# Save config to file for a specific mod
func _save_config(mod_id: String) -> void:
	if not _config_values.has(mod_id):
		return

	var config_path := "user://mod_options_%s.json" % mod_id
	var file := File.new()
	var error := file.open(config_path, File.WRITE)

	if error == OK:
		file.store_string(JSON.print(_config_values[mod_id], "\t"))
		file.close()
	else:
		ModLoaderLog.error("ModOptions: Failed to save config for '%s'" % mod_id, "ModOptions")
