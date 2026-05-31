extends "res://ui/menus/pages/menu_options.gd"

onready var OptionsMenu = get_node_or_null("/root/ModLoader/Oudstand-ModOptions")

const OptionsTabFactory := preload("res://mods-unpacked/Oudstand-ModOptions/ui/options_tab_factory.gd")
const MODS_BUTTON_PATH := "Buttons/HBoxContainer2/Mods_but"
const TAB_CONTAINER_PATH := "Buttons/HBoxContainer3/TabContainer"
const MOD_OPTIONS_TAB_NAME := "ModOptionsRootContainer"

var factory_instance :OptionsTabFactory


func _ready() -> void:
	._ready()
	_inject_mod_options()


func _inject_mod_options():
	if not is_instance_valid(OptionsMenu):
		_set_mods_button_available(false)
		return

	var mod_options = OptionsMenu.get_node_or_null("ModOptions")
	if not is_instance_valid(mod_options):
		_set_mods_button_available(false)
		return

	if not mod_options.is_connected("mod_registered", self, "_on_mod_options_registered"):
		mod_options.connect("mod_registered", self, "_on_mod_options_registered")

	# Get all registered mods
	var registered_mods = mod_options.get_registered_mods()

	var tab_container = get_node_or_null(TAB_CONTAINER_PATH)
	if not is_instance_valid(tab_container):
		_set_mods_button_available(false)
		return

	var was_mods_tab_selected = _is_mod_options_tab_selected(tab_container)
	_remove_existing_mod_options_tab(tab_container)

	factory_instance = OptionsTabFactory.new()
	# Set ModOptions reference in factory
	factory_instance.mod_options = mod_options

	if registered_mods.empty():
		_set_mods_button_available(false)
		return

	var settings_container = factory_instance.create_unified_options_tab(registered_mods)
	if settings_container:
		tab_container.add_child(settings_container)
		_set_mods_button_available(true)
		if was_mods_tab_selected:
			tab_container.current_tab = settings_container.get_index()
			var mods_button = get_node_or_null(MODS_BUTTON_PATH)
			if is_instance_valid(mods_button):
				mods_button.pressed = true
	else:
		_set_mods_button_available(false)


func _on_mod_options_registered(_mod_id: String) -> void:
	call_deferred("_inject_mod_options")


func _remove_existing_mod_options_tab(tab_container: TabContainer) -> void:
	var existing_tab = tab_container.get_node_or_null(MOD_OPTIONS_TAB_NAME)
	if is_instance_valid(existing_tab):
		tab_container.remove_child(existing_tab)
		existing_tab.queue_free()


func _is_mod_options_tab_selected(tab_container: TabContainer) -> bool:
	if tab_container.current_tab < 0 or tab_container.current_tab >= tab_container.get_child_count():
		return false

	return tab_container.get_child(tab_container.current_tab).name == MOD_OPTIONS_TAB_NAME


func _set_mods_button_available(available: bool) -> void:
	var mods_button = get_node_or_null(MODS_BUTTON_PATH)
	if not is_instance_valid(mods_button):
		return

	mods_button.visible = available
	mods_button.disabled = not available
