extends Node

const MOD_DIR_NAME := "Oudstand-DamageMeter"

func _init():
	var extensions_dir_path = ModLoaderMod.get_unpacked_dir().plus_file(MOD_DIR_NAME).plus_file("ui/hud")
	ModLoaderMod.install_script_extension(extensions_dir_path.plus_file("player_damage_updater.gd"))
	# Don't extend player_ui_elements.gd - it causes signal duplication issues
	# ModLoaderMod.install_script_extension(extensions_dir_path.plus_file("player_damage_positioning.gd"))

	# Instead, extend Main.gd to handle positioning
	ModLoaderMod.install_script_extension(extensions_dir_path.plus_file("main_extension.gd"))

func _ready():
	# IMPORTANT: Don't use save_scene() - it causes Timer signal duplication warnings
	# The signals are defined in ui_progress_bar.tscn and get duplicated when saving
	# editable instances. Instead, we inject at runtime via main_extension.gd
	pass
