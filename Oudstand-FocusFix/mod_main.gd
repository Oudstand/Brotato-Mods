extends Node

const MOD_ID := "Oudstand-FocusFix"
const MOD_DIR_NAME := "Oudstand-FocusFix"

func _init():
	var mod_dir_path := ModLoaderMod.get_unpacked_dir().plus_file(MOD_DIR_NAME)
	var extensions_dir := mod_dir_path.plus_file("extensions")
	ModLoaderMod.install_script_extension(extensions_dir.plus_file("menu_options_extension.gd"))
