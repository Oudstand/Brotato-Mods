extends "res://ui/menus/pages/menu_options.gd"

onready var OptionsMenu = get_node_or_null("/root/ModLoader/Oudstand-ModOptions")

const OptionsTabFactory := preload("res://mods-unpacked/Oudstand-ModOptions/ui/options_tab_factory.gd")
var factory_instance :OptionsTabFactory


func _ready() -> void:
	._ready()
	_inject_mod_options()


func _inject_mod_options():
	if not is_instance_valid(OptionsMenu):
		return

	var mod_options = OptionsMenu.get_node_or_null("ModOptions")
	if not is_instance_valid(mod_options):
		return

	# Get all registered mods
	var registered_mods = mod_options.get_registered_mods()
	
	factory_instance = OptionsTabFactory.new()
	# Set ModOptions reference in factory
	factory_instance.mod_options = mod_options
	
	if registered_mods.empty():
		return
	
	var settings_container = factory_instance.create_unified_options_tab(registered_mods)
	if settings_container:
		var tab_container = get_node_or_null("Buttons/HBoxContainer3/TabContainer")
		if is_instance_valid(tab_container):
			tab_container.add_child(settings_container)
	else:
		var mods_button = get_node_or_null("Buttons/HBoxContainer2/Mods_but")
		if is_instance_valid(mods_button):
			mods_button.hide()
