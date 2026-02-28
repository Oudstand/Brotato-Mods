extends "res://ui/menus/pages/menu_options.gd"

onready var OptionsMenu = get_node("/root/ModLoader/Oudstand-ModOptions")

const OptionsTabFactory := preload("res://mods-unpacked/Oudstand-ModOptions/ui/options_tab_factory.gd")
var factory_instance :OptionsTabFactory


func _ready() -> void:
	._ready()
	_inject_mod_options()


func _inject_mod_options():
	# Get all registered mods
	var registered_mods = OptionsMenu.get_node("ModOptions").get_registered_mods()
	
	factory_instance = OptionsTabFactory.new()
	# Set ModOptions reference in factory
	factory_instance.mod_options = OptionsMenu.get_node("ModOptions")
	
	if registered_mods.empty():
		return
	
	var settings_container = factory_instance.create_unified_options_tab(registered_mods)
	if settings_container:
		$Buttons/HBoxContainer3/TabContainer.add_child(settings_container)
	else:
		$Buttons/HBoxContainer2/Mods_but.hide()
