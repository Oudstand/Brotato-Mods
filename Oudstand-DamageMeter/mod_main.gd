extends Node

const MOD_DIR_NAME := "Oudstand-DamageMeter"

func _init():
	var extensions_dir_path = ModLoaderMod.get_unpacked_dir().plus_file(MOD_DIR_NAME).plus_file("ui/hud")
	ModLoaderMod.install_script_extension(extensions_dir_path.plus_file("player_damage_updater.gd"))
	ModLoaderMod.install_script_extension(extensions_dir_path.plus_file("player_damage_positioning.gd"))

func _ready():
	var main_scene = load("res://main.tscn").instance()
	
	for i in 4:
		var player_index = str(i + 1)
		var node_name = "PlayerDamageContainerP%s" % player_index
		var parent_node = "UI/HUD/LifeContainerP%s" % player_index
		var tscn_path = "res://mods-unpacked/%s/ui/hud/player_dmg_bar.tscn" % MOD_DIR_NAME
		
		ModLoaderMod.append_node_in_scene(main_scene, node_name, parent_node, tscn_path)
	
	ModLoaderMod.save_scene(main_scene, "res://main.tscn")
