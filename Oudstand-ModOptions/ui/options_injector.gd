extends Node

const MOD_NAME := "ModOptions"
const OPTIONS_MENU_SCRIPT := "res://ui/menus/pages/menu_options.gd"
const MENU_BUTTON_SCRIPT := "res://ui/menus/global/my_menu_button.gd"

const OptionsTabFactory := preload("res://mods-unpacked/Oudstand-ModOptions/ui/options_tab_factory.gd")

var injected_menus := []
var factory_instance = null


# Get ModOptions manager reference
func _get_mod_options() -> Node:
	# Get sibling mod node (both are children of ModLoader)
	var parent = get_parent()
	if not parent:
		return null
	return parent.get_node_or_null("ModOptions")


func _ready() -> void:
	factory_instance = OptionsTabFactory.new()
	# Set ModOptions reference in factory
	factory_instance.mod_options = _get_mod_options()
	call_deferred("_setup_menu_monitor")


func _setup_menu_monitor() -> void:
	get_tree().connect("node_added", self, "_on_node_added")


func _on_node_added(node: Node) -> void:
	if _is_options_menu(node) and not injected_menus.has(node):
		_inject_mod_options_tabs(node)


func _is_options_menu(node: Node) -> bool:
	if not node is MarginContainer:
		return false
	var script = node.get_script()
	return script != null and script.resource_path == OPTIONS_MENU_SCRIPT


func _inject_mod_options_tabs(menu_options: MarginContainer) -> void:
	injected_menus.append(menu_options)
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

	# Create a single "Mod Options" tab containing all mod options
	_inject_unified_mod_options_tab(button_container, tab_container, tab_script_node, registered_mods)


func _inject_unified_mod_options_tab(button_container: Node, tab_container: Node, tab_script_node: Node, registered_mods: Array) -> void:
	# Create single button for "Mod Options"
	var button = _create_unified_tab_button()
	button_container.add_child(button)

	# Create tab instance containing all mod options
	var tab_instance = _create_unified_tab_instance(registered_mods)
	tab_container.add_child(tab_instance)

	_register_button_with_tab_system(button, tab_script_node)


func _validate_containers(button_container: Node, tab_container: Node) -> bool:
	if not is_instance_valid(button_container):
		ModLoaderLog.error("Could not find button container", MOD_NAME)
		return false
	if not is_instance_valid(tab_container):
		ModLoaderLog.error("Could not find tab container", MOD_NAME)
		return false
	return true


func _create_unified_tab_button() -> Button:
	var button = Button.new()
	button.name = "ModOptions_but"
	button.text = "Mods"
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.size_flags_vertical = Control.SIZE_EXPAND_FILL
	button.toggle_mode = true

	var button_script = load(MENU_BUTTON_SCRIPT)
	if button_script:
		button.set_script(button_script)

	return button


func _create_unified_tab_instance(registered_mods: Array) -> Control:
	var instance = factory_instance.create_unified_options_tab(registered_mods)
	instance.name = "ModOptions_Container"
	instance.visible = false
	return instance


func _register_button_with_tab_system(button: Button, tab_script_node: Node) -> void:
	if not tab_script_node:
		return

	var buttons_array = tab_script_node.get("buttons_tab_np")
	var buttons_tab = tab_script_node.get("buttons_tab")

	if buttons_array == null or buttons_tab == null:
		return

	var new_tab_index = buttons_array.size()

	buttons_array.append(button.get_path())
	tab_script_node.set("buttons_tab_np", buttons_array)

	buttons_tab.append(button)
	tab_script_node.set("buttons_tab", buttons_tab)

	if buttons_tab.size() > 1:
		var first_button = buttons_tab[0]
		if first_button and first_button.group:
			button.group = first_button.group

	if tab_script_node.has_method("_change_tab"):
		button.connect("pressed", tab_script_node, "_change_tab", [new_tab_index])
