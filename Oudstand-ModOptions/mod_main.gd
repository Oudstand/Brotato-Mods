extends Node

const MOD_DIR_NAME := "Oudstand-ModOptions"
const MOD_ID := "Oudstand-ModOptions"


func _init():
	var mod_dir_path := ModLoaderMod.get_unpacked_dir().plus_file(MOD_DIR_NAME)
	_setup_autoloads(mod_dir_path)


func _setup_autoloads(mod_dir_path: String) -> void:
	# Register the ModOptions manager as a global autoload
	# This makes it accessible via "ModOptions" from any mod
	var _mod_options_manager := _create_autoload(
		mod_dir_path.plus_file("mod_options_manager.gd"),
		"ModOptions"
	)

	# Register the options injector to dynamically add tabs to the options menu
	var _options_injector := _create_autoload(
		mod_dir_path.plus_file("ui/options_injector.gd"),
		"ModOptionsInjector"
	)


func _create_autoload(script_path: String, node_name: String) -> Node:
	var script = load(script_path)
	var instance = script.new()
	instance.name = node_name
	add_child(instance)
	return instance
