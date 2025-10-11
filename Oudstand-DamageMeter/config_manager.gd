extends Node

const MOD_NAME: String = "DamageMeter"
const CONFIG_PATH: String = "user://Oudstand-DamageMeter_config.json"

# Config values
var TOP_K: int = 6
var SHOW_ITEM_COUNT: bool = false
var SHOW_DPS: bool = false
var BAR_OPACITY: float = 1.0
var SHOW_PERCENTAGE: bool = true

signal config_changed()

func _ready() -> void:
	# Load saved config from disk
	_load_saved_config()

	# Connect to ModOptions signal and sync values
	var mods_config_interface = get_node_or_null("/root/ModLoader/dami-ModOptions/ModsConfigInterface")
	if is_instance_valid(mods_config_interface):
		# Update ModOptions with our saved values
		_sync_to_mod_options(mods_config_interface)

		if mods_config_interface.connect("setting_changed", self, "_on_setting_changed") == OK:
			ModLoaderLog.info("ConfigManager connected to ModOptions", MOD_NAME)
		else:
			ModLoaderLog.warning("ConfigManager could not connect to ModOptions", MOD_NAME)

func _sync_to_mod_options(mods_config_interface) -> void:
	var mod_configs = mods_config_interface.get("mod_configs")
	if not mod_configs or not mod_configs is Dictionary:
		return

	if not mod_configs.has("Oudstand-DamageMeter"):
		return

	# Update ModOptions config with our saved values
	var config = mod_configs["Oudstand-DamageMeter"]
	config["number_of_sources"] = float(TOP_K)
	config["show_item_count"] = SHOW_ITEM_COUNT
	config["show_dps"] = SHOW_DPS
	config["opacity"] = BAR_OPACITY
	config["show_percentage"] = SHOW_PERCENTAGE

	ModLoaderLog.info("ConfigManager synced values to ModOptions UI", MOD_NAME)

func _on_setting_changed(setting_name: String, value, mod_name: String) -> void:
	if mod_name != "Oudstand-DamageMeter":
		return

	# Ignore helper settings
	if (setting_name.ends_with("_min") or setting_name.ends_with("_max") or
		setting_name.ends_with("_step") or setting_name.ends_with("_format") or
		setting_name.ends_with("_tooltip")):
		return

	ModLoaderLog.info("ConfigManager: Setting changed: %s = %s" % [setting_name, str(value)], MOD_NAME)

	match setting_name:
		"number_of_sources":
			TOP_K = int(clamp(round(value), 1.0, 25.0))
		"show_item_count":
			SHOW_ITEM_COUNT = bool(value)
		"show_dps":
			SHOW_DPS = bool(value)
		"opacity":
			BAR_OPACITY = clamp(float(value), 0.3, 1.0)
		"show_percentage":
			SHOW_PERCENTAGE = bool(value)

	# Save and notify
	_save_config()
	emit_signal("config_changed")

	ModLoaderLog.info("ConfigManager updated: TOP_K=%d, SHOW_DPS=%s, SHOW_ITEM_COUNT=%s, OPACITY=%.2f" % [TOP_K, SHOW_DPS, SHOW_ITEM_COUNT, BAR_OPACITY], MOD_NAME)

func _save_config() -> void:
	var config = {
		"number_of_sources": TOP_K,
		"show_item_count": SHOW_ITEM_COUNT,
		"show_dps": SHOW_DPS,
		"opacity": BAR_OPACITY,
		"show_percentage": SHOW_PERCENTAGE
	}

	var file = File.new()
	if file.open(CONFIG_PATH, File.WRITE) == OK:
		file.store_string(JSON.print(config, "\t"))
		file.close()
		ModLoaderLog.info("ConfigManager: Saved config to %s" % CONFIG_PATH, MOD_NAME)
	else:
		ModLoaderLog.warning("ConfigManager: Failed to save config to %s" % CONFIG_PATH, MOD_NAME)

func _load_saved_config() -> void:
	var file = File.new()
	if not file.file_exists(CONFIG_PATH):
		ModLoaderLog.info("ConfigManager: No saved config found, using defaults", MOD_NAME)
		return

	if file.open(CONFIG_PATH, File.READ) == OK:
		var json_text = file.get_as_text()
		file.close()

		var parse_result = JSON.parse(json_text)
		if parse_result.error == OK:
			var config = parse_result.result
			if config is Dictionary:
				if config.has("number_of_sources"):
					TOP_K = int(clamp(config.number_of_sources, 1, 25))
				if config.has("show_item_count"):
					SHOW_ITEM_COUNT = bool(config.show_item_count)
				if config.has("show_dps"):
					SHOW_DPS = bool(config.show_dps)
				if config.has("opacity"):
					BAR_OPACITY = clamp(float(config.opacity), 0.3, 1.0)
				if config.has("show_percentage"):
					SHOW_PERCENTAGE = bool(config.show_percentage)

				ModLoaderLog.info("ConfigManager: Loaded saved config: TOP_K=%d, SHOW_DPS=%s, SHOW_ITEM_COUNT=%s, OPACITY=%.2f" % [TOP_K, SHOW_DPS, SHOW_ITEM_COUNT, BAR_OPACITY], MOD_NAME)
		else:
			ModLoaderLog.warning("ConfigManager: Failed to parse config JSON: %s" % parse_result.error_string, MOD_NAME)
	else:
		ModLoaderLog.warning("ConfigManager: Failed to read config from %s" % CONFIG_PATH, MOD_NAME)
