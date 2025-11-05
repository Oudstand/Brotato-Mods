extends Node

const MOD_DIR_NAME := "Oudstand-DamageMeter"
const MOD_ID := "Oudstand-DamageMeter"


func _init():
	var mod_dir_path := ModLoaderMod.get_unpacked_dir().plus_file(MOD_DIR_NAME)

	_load_translations(mod_dir_path)
	_setup_autoloads(mod_dir_path)
	_install_extensions(mod_dir_path)


func _ready():
	# Register options with ModOptions (after it's loaded)
	call_deferred("_register_mod_options")


func _load_translations(mod_dir_path: String) -> void:
	var translations_dir := mod_dir_path.plus_file("translations")
	ModLoaderMod.add_translation(translations_dir.plus_file("DamageMeter.en.translation"))
	ModLoaderMod.add_translation(translations_dir.plus_file("DamageMeter.de.translation"))


func _get_mod_options() -> Node:
	# Get sibling mod node (both are children of ModLoader)
	var parent = get_parent()
	if not parent:
		return null
	var mod_options_mod = parent.get_node_or_null("Oudstand-ModOptions")
	if not mod_options_mod:
		return null
	return mod_options_mod.get_node_or_null("ModOptions")


func _register_mod_options() -> void:
	var mod_options = _get_mod_options()
	if not mod_options:
		ModLoaderLog.error("ModOptions not found, cannot register options", MOD_ID)
		return

	mod_options.register_mod_options("DamageMeter", {
		"tab_title": "DAMAGEMETER_TAB_TITLE",
		"options": [
			{
				"type": "slider",
				"id": "opacity",
				"label": "DAMAGEMETER_OPACITY_LABEL",
				"min": 0.3,
				"max": 1.0,
				"step": 0.1,
				"default": 1.0
			},
			{
				"type": "slider",
				"id": "top_k",
				"label": "DAMAGEMETER_NUMBER_OF_SOURCES_LABEL",
				"min": 1.0,
				"max": 25.0,
				"step": 1.0,
				"default": 6.0,
				"display_as_integer": true
			},
			{
				"type": "toggle",
				"id": "show_item_count",
				"label": "DAMAGEMETER_SHOW_ITEM_COUNT_LABEL",
				"default": true
			},
			{
				"type": "toggle",
				"id": "show_dps",
				"label": "DAMAGEMETER_SHOW_DPS_LABEL",
				"default": false
			},
			{
				"type": "toggle",
				"id": "show_percentage",
				"label": "DAMAGEMETER_SHOW_PERCENTAGE_LABEL",
				"default": true
			},
			{
				"type": "toggle",
				"id": "hide_total_bar_singleplayer",
				"label": "DAMAGEMETER_HIDE_TOTAL_BAR_SINGLEPLAYER_LABEL",
				"default": false
			}
		],
		"info_text": "DAMAGEMETER_INFO_TEXT"
	})


func _setup_autoloads(mod_dir_path: String) -> void:
	var charm_tracker := _create_autoload(
		mod_dir_path.plus_file("extensions/charm_tracker.gd"),
		"DamageMeterCharmTracker"
	)


func _create_autoload(script_path: String, node_name: String) -> Node:
	var script = load(script_path)
	var instance = script.new()
	instance.name = node_name
	add_child(instance)
	return instance


func _install_extensions(mod_dir_path: String) -> void:
	var extensions_dir := mod_dir_path.plus_file("extensions")
	ModLoaderMod.install_script_extension(extensions_dir.plus_file("enemy_extension.gd"))

	var ui_extensions_dir := mod_dir_path.plus_file("ui/hud")
	ModLoaderMod.install_script_extension(ui_extensions_dir.plus_file("player_damage_updater.gd"))
	ModLoaderMod.install_script_extension(ui_extensions_dir.plus_file("main_extension.gd"))
