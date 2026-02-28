extends Node

const MOD_DIR_NAME := "Oudstand-ModOptions"
const MOD_ID := "Oudstand-ModOptions"

var changed_resources := []


func _init():
	ModLoaderLog.info("Init", MOD_ID + ":Main")
	_fix_broken_script_classes()
	var mod_dir_path := ModLoaderMod.get_unpacked_dir().plus_file(MOD_DIR_NAME)
	_load_translations(mod_dir_path)
	_install_extensions(mod_dir_path)
	_setup_autoloads(mod_dir_path)
	call_deferred("_install_scene_overrides")


func _load_translations(mod_dir_path: String) -> void:
	var translations_dir := mod_dir_path.plus_file("translations")
	ModLoaderMod.add_translation(translations_dir.plus_file("ModOptions.en.translation"))
	ModLoaderMod.add_translation(translations_dir.plus_file("ModOptions.de.translation"))


func _install_extensions(mod_dir_path: String) -> void:
	var extensions_dir := mod_dir_path.plus_file("extensions")
	ModLoaderMod.install_script_extension(extensions_dir.plus_file("focus_emulator_extension.gd"))


func _install_scene_overrides() -> void:
	var scene_overwrite_1 = load("res://mods-unpacked/Oudstand-ModOptions/extensions/menu_options.tscn")
	scene_overwrite_1.take_over_path("res://ui/menus/pages/menu_options.tscn")
	changed_resources.append(scene_overwrite_1)


func _setup_autoloads(mod_dir_path: String) -> void:
	# Register the ModOptions manager
	var _mod_options_manager := _create_autoload(
		mod_dir_path.plus_file("mod_options_manager.gd"),
		"ModOptions"
	)

	# Register the options injector
	var _options_injector := _create_autoload(
		mod_dir_path.plus_file("ui/options_injector.gd"),
		"ModOptionsInjector"
	)


func _create_autoload(script_path: String, node_name: String) -> Node:
	var instance = load(script_path).new()
	instance.name = node_name
	add_child(instance)
	return instance


# Workaround for ModLoader crash: The game's _global_script_classes contains
# entries for test files (e.g., pd_enemy.gd) that don't exist in production.
# When ModLoader installs extensions, it tries to reload these and crashes.
# This function removes broken entries using ResourceLoader.exists().
func _fix_broken_script_classes() -> void:
	var global_classes = ProjectSettings.get_setting("_global_script_classes")
	if not global_classes is Array or global_classes.empty():
		return

	var clean_classes = []
	var removed_count = 0

	for class_entry in global_classes:
		if class_entry is Dictionary and class_entry.has("path"):
			if ResourceLoader.exists(class_entry.path):
				clean_classes.append(class_entry)
			else:
				removed_count += 1
		else:
			clean_classes.append(class_entry)

	if removed_count > 0:
		ProjectSettings.set_setting("_global_script_classes", clean_classes)
		ModLoaderLog.info("Removed %d broken script class entries (game test files)" % removed_count, MOD_ID)
