extends Node

const MOD_NAME := "ModOptions"


# Get ModOptions manager reference
func _get_mod_options() -> Node:
	# Get sibling mod node (both are children of ModLoader)
	var parent = get_parent()
	if not parent:
		return null
	return parent.get_node_or_null("ModOptions")


func inject_mod_options_tabs(menu_options: MarginContainer) -> void:
	yield(get_tree().create_timer(0.1), "timeout")

	var button_container = menu_options.get_node_or_null("Buttons/HBoxContainer2")
	var tab_container = menu_options.get_node_or_null("Buttons/HBoxContainer3/TabContainer")
	var tab_script_node = menu_options.get_node_or_null("Buttons")

	if not _validate_containers(button_container, tab_container):
		return

	# Get all registered mods
	var mod_options = _get_mod_options()
	if not mod_options:
		ModLoaderLog.error("ModOptions manager not found", MOD_NAME)
		return

	var registered_mods = mod_options.get_registered_mods()
	if registered_mods.empty():
		return


func _validate_containers(button_container: Node, tab_container: Node) -> bool:
	if not is_instance_valid(button_container):
		ModLoaderLog.error("Could not find button container", MOD_NAME)
		return false
	if not is_instance_valid(tab_container):
		ModLoaderLog.error("Could not find tab container", MOD_NAME)
		return false
	return true
