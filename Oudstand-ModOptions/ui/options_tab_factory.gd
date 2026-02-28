extends Resource

# Resources used for creating UI elements
const SLIDER_SCENE := preload("res://ui/menus/global/slider_option.tscn")
const FONT := preload("res://resources/fonts/actual/base/font_40_outline.tres")
const BUTTON_HOVER_STYLE := preload("res://resources/themes/button_styles/button_hover.tres")
const MENU_BUTTON_SCRIPT := preload("res://ui/menus/global/my_menu_button.gd")


# Reference to ModOptions manager (set by injector)
var mod_options: Node = null

# Track controls with conditional visibility
# {mod_id: {condition_option_id: [controls that depend on it]}}
var _visibility_controls := {}

## TODO: _add_mod_header should add a button to a sidebar where you can select a header to jump to
# Test for controller compatability


# Create a unified options tab containing all registered mods
# Returns a ScrollContainer with all mods' options
func create_unified_options_tab(registered_mods: Array) -> HBoxContainer:
	var sidebar_scroll_container := ScrollContainer.new()
	sidebar_scroll_container.name = "ModOptions_SidebarContainer"
	sidebar_scroll_container.anchor_right = 1.0
	sidebar_scroll_container.anchor_bottom = 1.0
	sidebar_scroll_container.margin_top = 20.0
	sidebar_scroll_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sidebar_scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sidebar_scroll_container.follow_focus = true
	sidebar_scroll_container.scroll_horizontal_enabled = false
	
	
	
	var scroll_container := ScrollContainer.new()
	scroll_container.name = "ModOptions_Container"
	scroll_container.anchor_right = 1.0
	scroll_container.anchor_bottom = 1.0
	scroll_container.margin_top = 20.0
	scroll_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll_container.follow_focus = true
	scroll_container.rect_min_size.x = 1000
	scroll_container.size_flags_stretch_ratio = 4
	scroll_container.scroll_horizontal_enabled = false

	var hbox := HBoxContainer.new()
	hbox.name = "ModOptionsRootContainer"
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hbox.set("custom_constants/separation", 15)

	var vbox := VBoxContainer.new()
	vbox.name = "ModOptionsContainer"
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.set("custom_constants/separation", 15)
	vbox.alignment = BoxContainer.ALIGN_CENTER

	
	var header_sidebar_selector := VBoxContainer.new()
	header_sidebar_selector.rect_min_size.x = 250
	header_sidebar_selector.name = "HeaderSidebar"
	vbox.set("custom_constants/separation", 15)
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL


	hbox.add_child(header_sidebar_selector)
	hbox.add_child(scroll_container)
	scroll_container.add_child(vbox)

	# Add options for each mod with separators
	for i in range(registered_mods.size()):
		var mod_id = registered_mods[i]
		
		var config = mod_options.get_mod_config(mod_id) if mod_options else {}

		if config.empty():
			continue

		# Add mod header
		_add_mod_header(vbox, config.tab_title, header_sidebar_selector)

		# Add mod options
		for option in config.options:
			# Skip hidden options (ones with empty labels)
			if not option.has("label") or option.label == "":
				continue

			var control: Node = null

			match option.type:
				"slider":
					control = _create_slider_option(mod_id, option)
				"toggle":
					control = _create_toggle_option(mod_id, option)
				"dropdown":
					control = _create_dropdown_option(mod_id, option)
				"text":
					control = _create_text_option(mod_id, option)
				"item_selector":
					control = _create_item_selector_option(mod_id, option)

			if control:
				vbox.add_child(control)

				# Handle conditional visibility
				if option.has("visible_if"):
					_setup_conditional_visibility(control, mod_id, option)

		# Add info text if present
		if config.has("info_text"):
			var info_label := Label.new()
			info_label.text = tr(config.info_text)
			info_label.align = Label.ALIGN_CENTER
			info_label.valign = Label.VALIGN_CENTER
			info_label.autowrap = true
			info_label.modulate = Color(0.6, 0.6, 0.6)
			
			# Set font size to 24
			var custom_font = FONT.duplicate()
			custom_font.size = 24
			info_label.set("custom_fonts/font", custom_font)
			
			vbox.add_child(info_label)

		# Add separator between mods (except after last one)
		if i < registered_mods.size() - 1:
			var separator := HSeparator.new()
			separator.set("custom_constants/separation", 30)
			vbox.add_child(separator)


	if header_sidebar_selector.get_child_count() <= 1:
		header_sidebar_selector.hide()
	
	return hbox


# Add a mod name header
func _add_mod_header(vbox: VBoxContainer, title: String, header_sidebar_selector :VBoxContainer) -> void:
	var header := Label.new()
	header.text = title
	header.align = Label.ALIGN_CENTER
	vbox.add_child(header)
	
	
	
	var sidebar_button := MyMenuButton.new()
	sidebar_button.text = title
	header_sidebar_selector.add_child(sidebar_button)
	
	sidebar_button.clip_text = true
	
	var custom_font = FONT.duplicate()
	custom_font.size = 24
	sidebar_button.set("custom_fonts/font", custom_font)

	# Load and apply resources
	sidebar_button.connect("pressed", self, "_on_header_button_pressed", [header])


func _on_header_button_pressed(header:Label):
	if header.get_parent().get_child_count() > header.get_index()+1:
		var node_to_focus := header.get_parent().get_child(header.get_index() + 1)
		while \
				(node_to_focus is Label) or \
				(node_to_focus.has_meta("focus_action") and node_to_focus.get_meta("focus_action") == "goto_next"):
			if node_to_focus.get_parent().get_child_count() > node_to_focus.get_index()+1:
				node_to_focus = node_to_focus.get_parent().get_child(node_to_focus.get_index() + 1)
			else:
				# Nothing after this label to select??
				return
		
		
		if node_to_focus.has_meta("focus_node"):
			node_to_focus.get_meta("focus_node").grab_focus()
		
		else:
			node_to_focus.grab_focus()



# Create a slider control
func _create_slider_option(mod_id: String, option: Dictionary) -> SliderOption:
	var slider_instance :SliderOption= SLIDER_SCENE.instance()
	slider_instance.name = "%sSlider" % option.id.capitalize().replace(" ", "")
	slider_instance.unique_name_in_owner = true

	# Configure label
	var label: Label = slider_instance.get_node("Label")
	label.text = option.label

	# Configure slider
	var hslider: HSlider = slider_instance.get_node("HSlider")
	hslider.min_value = option.min
	hslider.max_value = option.max
	hslider.step = option.step

	if mod_options:
		# Set initial value first
		hslider.value = mod_options.get_value(mod_id, option.id)
		# Connect to ModOptions - use wrapper function to fix parameter order
		hslider.connect("value_changed", self, "_on_slider_value_changed", [mod_id, option.id])

	# Handle integer display - override the % formatting
	if option.get("display_as_integer", false):
		var value_label: Label = slider_instance.get_node_or_null("Value")
		if value_label:
			# Disconnect the SliderOption's internal signal to prevent % formatting
			hslider.disconnect("value_changed", slider_instance, "_on_HSlider_value_changed")
			# Connect our own handler that updates the label without %
			hslider.connect("value_changed", self, "_update_integer_display", [value_label])
			# Set initial text to integer format (deferred to override SliderOption's _ready)
			value_label.call_deferred("set_text", str(int(hslider.value)))

	slider_instance.set_meta("focus_node", hslider)
	return slider_instance


# Create a toggle (CheckButton) control
func _create_toggle_option(mod_id: String, option: Dictionary) -> CheckButton:
	var check_button := CheckButton.new()
	check_button.name = "%sButton" % option.id.capitalize().replace(" ", "")
	check_button.unique_name_in_owner = true

	# Load and apply resources

	# Apply menu button script for sound effects
	check_button.script = MENU_BUTTON_SCRIPT
	check_button.set("custom_styles/hover_pressed", BUTTON_HOVER_STYLE)
	check_button.text = option.label

	if mod_options:
		check_button.pressed = mod_options.get_value(mod_id, option.id)
		# Connect to ModOptions - use wrapper function to fix parameter order
		check_button.connect("toggled", self, "_on_toggle_changed", [mod_id, option.id])

	return check_button


# Create a dropdown (OptionButton) control
func _create_dropdown_option(mod_id: String, option: Dictionary) -> Node:
	var hbox := HBoxContainer.new()
	hbox.name = "%sContainer" % option.id.capitalize().replace(" ", "")
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Label
	var label := Label.new()
	label.text = option.label
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(label)

	# OptionButton
	var option_button := OptionButton.new()
	option_button.clip_text = true
	option_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Add choices
	var current_value = mod_options.get_value(mod_id, option.id) if mod_options else option.get("default", null)
	var selected_index := 0
	for i in range(option.choices.size()):
		var choice = option.choices[i]
		option_button.add_item(str(choice), i)
		if choice == current_value:
			selected_index = i

	option_button.selected = selected_index

	# Connect to ModOptions
	if mod_options:
		option_button.connect("item_selected", self, "_on_dropdown_selected", [mod_id, option.id, option.choices])

	hbox.add_child(option_button)
	hbox.set_meta("focus_node", option_button)
	return hbox


# Create a text input (LineEdit or TextEdit) control
func _create_text_option(mod_id: String, option: Dictionary) -> Node:
	var vbox_container := VBoxContainer.new()
	vbox_container.name = "%sContainer" % option.id.capitalize().replace(" ", "")
	vbox_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox_container.set_meta("focus_action", "goto_next")

	# Label
	var label := Label.new()
	label.text = option.label
	vbox_container.add_child(label)

	# Text input (multiline if specified)
	var text_input: Control
	var is_multiline = option.get("multiline", false)

	if is_multiline:
		var text_edit := TextEdit.new()
		text_edit.unique_name_in_owner = true
		text_edit.rect_min_size = Vector2(0, option.get("min_height", 100))
		text_edit.wrap_enabled = true

		if mod_options:
			text_edit.text = str(mod_options.get_value(mod_id, option.id))
			text_edit.connect("text_changed", self, "_on_text_edit_changed", [mod_id, option.id, text_edit])

		text_input = text_edit
	else:
		var line_edit := LineEdit.new()
		line_edit.unique_name_in_owner = true

		if mod_options:
			line_edit.text = str(mod_options.get_value(mod_id, option.id))
			line_edit.connect("text_changed", self, "_on_line_edit_changed", [mod_id, option.id])

		text_input = line_edit

	vbox_container.add_child(text_input)

	# Optional help text
	if option.has("help_text"):
		var help_label := Label.new()
		help_label.text = option.help_text
		help_label.modulate = Color(0.7, 0.7, 0.7)
		help_label.autowrap = true
		
		# Set font size to 30
		var custom_font = FONT.duplicate()
		custom_font.size = 30
		help_label.set("custom_fonts/font", custom_font)
		
		vbox_container.add_child(help_label)

	return vbox_container


# Create an item selector control for managing lists of items/weapons
func _create_item_selector_option(mod_id: String, option: Dictionary) -> Node:
	var main_vbox := VBoxContainer.new()
	main_vbox.name = "%sContainer" % option.id.capitalize().replace(" ", "")
	main_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.set("custom_constants/separation", 10)

	# Label
	var label := Label.new()
	label.text = option.label
	main_vbox.add_child(label)

	# Container for item rows
	var items_container := VBoxContainer.new()
	items_container.name = "ItemsContainer"
	items_container.set("custom_constants/separation", 5)
	main_vbox.add_child(items_container)

	# Load current items
	var current_items = []
	if mod_options:
		var saved_value = mod_options.get_value(mod_id, option.id)
		if saved_value is Array:
			current_items = saved_value
		elif saved_value == null or (saved_value is String and saved_value.empty()):
			current_items = []

	# Create rows for existing items
	var item_type = option.get("item_type", "item")
	for item_data in current_items:
		# Convert from old format {id, count, cursed} to new format {base_name, tier, count, cursed}
		if item_data.has("id"):
			var parsed = _parse_item_id(item_type, item_data.id)
			var converted_data = {
				"base_name": parsed.base_name,
				"tier": parsed.tier,
				"count": item_data.get("count", 1),
				"cursed": item_data.get("cursed", false)
			}
			_add_item_row(items_container, mod_id, option, converted_data)
		else:
			_add_item_row(items_container, mod_id, option, item_data)

	# Add Item button
	var add_button := Button.new()
	var option_item_type = option.get("item_type", "item")

	# Set a unique name for the button so we can find it later (for focus management)
	add_button.name = "AddItemButton_%s_%s" % [mod_id, option.id]

	# Check if mod provided custom button text (translation key)
	if option.has("add_button_text"):
		add_button.text = tr(option.add_button_text)
	else:
		# Use default text based on item type
		match option_item_type:
			"weapon":
				add_button.text = tr("MODOPTIONS_ADD_WEAPON")
			"character":
				add_button.text = tr("MODOPTIONS_ADD_ABILITY")
			_:
				add_button.text = tr("MODOPTIONS_ADD_ITEM")

	add_button.connect("pressed", self, "_on_add_item_pressed", [items_container, mod_id, option])
	main_vbox.add_child(add_button)

	# Help text
	if option.has("help_text"):
		var help_label := Label.new()
		help_label.text = tr(option.help_text)
		help_label.modulate = Color(0.7, 0.7, 0.7)
		help_label.autowrap = true
		
		# Set font size to 30
		var custom_font = FONT.duplicate()
		custom_font.size = 30
		help_label.set("custom_fonts/font", custom_font)
		
		main_vbox.add_child(help_label)


	main_vbox.set_meta("focus_node", add_button)
	return main_vbox


# Add a row for a single item in the item selector
func _add_item_row(container: VBoxContainer, mod_id: String, option: Dictionary, item_data: Dictionary) -> void:
	var row := HBoxContainer.new()
	row.set("custom_constants/separation", 10)

	# Get unique base items
	var item_type = option.get("item_type", "item")
	var unique_items = _get_unique_base_items(item_type)

	# Dropdown for weapon/item selection (deduplicated)
	var item_dropdown := OptionButton.new()
	item_dropdown.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item_dropdown.clip_text = true
	item_dropdown.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Populate dropdown with unique items and icons
	var selected_item_index = 0
	var icon_size = Vector2(60, 60) # Fixed icon size for consistency

	for i in range(unique_items.size()):
		var item = unique_items[i]
		if item.icon != null:
			# Scale icon to consistent size
			var scaled_icon = _scale_icon(item.icon, icon_size)
			item_dropdown.add_icon_item(scaled_icon, item.display_name, i)
		else:
			item_dropdown.add_item(item.display_name, i)
		if item.base_name == item_data.get("base_name", ""):
			selected_item_index = i
	item_dropdown.selected = selected_item_index
	item_dropdown.connect("item_selected", self, "_on_item_dropdown_changed", [container, mod_id, option, row])

	# Connect FocusEmulator signals for keyboard/controller navigation
	var popup = item_dropdown.get_popup()
	if popup:
		popup.connect("index_pressed", self, "_on_item_dropdown_index_pressed", [item_dropdown])

	row.add_child(item_dropdown)

	# Dropdown for tier selection (only shown if multiple tiers available)
	var tier_dropdown := OptionButton.new()
	tier_dropdown.rect_min_size.x = 80
	tier_dropdown.clip_text = true
	tier_dropdown.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Get the currently selected item's base name
	var current_base_name = ""
	if selected_item_index >= 0 and selected_item_index < unique_items.size():
		current_base_name = unique_items[selected_item_index].base_name

	# Populate tier dropdown with only available tiers for this item
	var available_tiers = _get_available_tiers(item_type, current_base_name)
	_populate_tier_dropdown(tier_dropdown, item_type, current_base_name, item_data.get("tier", 0))

	# Only show tier dropdown if item has multiple tiers available
	if available_tiers.size() > 1:
		tier_dropdown.visible = true
	else:
		tier_dropdown.visible = false

	tier_dropdown.connect("item_selected", self, "_on_item_row_changed", [container, mod_id, option])

	# Connect FocusEmulator signals for keyboard/controller navigation
	var tier_popup = tier_dropdown.get_popup()
	if tier_popup:
		tier_popup.connect("index_pressed", self, "_on_tier_dropdown_index_pressed", [tier_dropdown])

	row.add_child(tier_dropdown)

	# Count input
	var count_spinbox := SpinBox.new()
	count_spinbox.min_value = 1
	count_spinbox.max_value = 999
	count_spinbox.step = 1
	count_spinbox.value = item_data.get("count", 1)
	count_spinbox.rect_min_size = Vector2(80, 0)
	count_spinbox.connect("value_changed", self, "_on_item_row_changed", [container, mod_id, option])
	var show_count = option.get("show_count", true)
	count_spinbox.editable = show_count
	count_spinbox.visible = show_count
	if not show_count:
		count_spinbox.value = 1
	row.add_child(count_spinbox)

	# Cursed checkbox
	var cursed_check := CheckButton.new()
	# Check if mod provided custom cursed label (translation key)
	if option.has("cursed_label_text"):
		cursed_check.text = tr(option.cursed_label_text)
	else:
		cursed_check.text = tr("MODOPTIONS_CURSED")
	cursed_check.pressed = item_data.get("cursed", false)
	cursed_check.connect("toggled", self, "_on_item_row_changed", [container, mod_id, option])
	var show_cursed = option.get("show_cursed", true)
	cursed_check.disabled = not show_cursed
	cursed_check.visible = show_cursed
	if not show_cursed:
		cursed_check.pressed = false
	row.add_child(cursed_check)

	# Remove button
	var remove_button := Button.new()
	remove_button.text = "X"
	remove_button.connect("pressed", self, "_on_remove_item_pressed", [row, container, mod_id, option])
	row.add_child(remove_button)

	container.add_child(row)


# Get all available items or weapons from ItemService
func _get_available_items(item_type: String) -> Array:
	var result = []

	if not is_instance_valid(ItemService):
		return result

	var source_list = []
	match item_type:
		"weapon":
			source_list = ItemService.weapons
		"character":
			source_list = ItemService.characters
		_:
			source_list = ItemService.items

	if not source_list:
		return result

	for item in source_list:
		if not is_instance_valid(item):
			continue

		var item_id = item.my_id if "my_id" in item else ""
		var item_name = item.name if "name" in item else ""
		var tier = item.tier if "tier" in item else 0

		if item_id.empty():
			continue

		# Add tier suffix to name following game convention:
		# Tier 0 = COMMON (no suffix), Tier 1 = UNCOMMON (II), Tier 2 = RARE (III), Tier 3 = LEGENDARY (IV)
		var tier_suffixes = ["", " (II)", " (III)", " (IV)"]
		var display_name = tr(item_name) if not item_name.empty() else item_id
		if tier >= 0 and tier <= 3:
			display_name += tier_suffixes[tier]

		result.append({
			"id": item_id,
			"name": display_name,
			"tier": tier,
			"base_name": tr(item_name) if not item_name.empty() else item_id
		})

	# Sort by name
	result.sort_custom(self, "_sort_items_by_name")

	return result


# Get unique base items (deduplicated, one per weapon/item type)
func _get_unique_base_items(item_type: String) -> Array:
	if not is_instance_valid(ItemService):
		return []

	var source_list = []
	match item_type:
		"weapon":
			source_list = ItemService.weapons
		"character":
			source_list = ItemService.characters
		_:
			source_list = ItemService.items
	if not source_list:
		return []

	var unique_map = {}
	var result = []

	for item in source_list:
		if not is_instance_valid(item):
			continue

		var item_name = item.name if "name" in item else ""
		var base_name = tr(item_name) if not item_name.empty() else ""

		if base_name.empty() or unique_map.has(base_name):
			continue

		unique_map[base_name] = true

		# Get icon if available
		var icon = null
		if "icon" in item and item.icon != null:
			icon = item.icon

		result.append({
			"base_name": base_name,
			"display_name": base_name,
			"icon": icon
		})

	# Sort by display name
	result.sort_custom(self, "_sort_base_items_by_name")
	return result


# Sort base items alphabetically
func _sort_base_items_by_name(a: Dictionary, b: Dictionary) -> bool:
	return a.display_name < b.display_name


# Scale icon texture to a specific size
func _scale_icon(icon: Texture, size: Vector2) -> ImageTexture:
	if not icon:
		return null

	var image = icon.get_data()
	if not image:
		return null

	# Resize image to target size
	image.resize(int(size.x), int(size.y), Image.INTERPOLATE_LANCZOS)

	# Create new texture from resized image
	var scaled_texture = ImageTexture.new()
	scaled_texture.create_from_image(image, 0)
	return scaled_texture


# Find item ID from base_name and tier
func _find_item_id(item_type: String, base_name: String, tier: int) -> String:
	var all_items = _get_available_items(item_type)
	for item in all_items:
		if item.base_name == base_name and item.tier == tier:
			return item.id
	return ""


# Parse item ID to get base_name and tier
func _parse_item_id(item_type: String, item_id: String) -> Dictionary:
	var all_items = _get_available_items(item_type)
	for item in all_items:
		if item.id == item_id:
			return {"base_name": item.base_name, "tier": item.tier}
	return {"base_name": "", "tier": 0}


# Get available tiers for a specific item
func _get_available_tiers(item_type: String, base_name: String) -> Array:
	var all_items = _get_available_items(item_type)
	var available_tiers = []

	for item in all_items:
		if item.base_name == base_name:
			if not available_tiers.has(item.tier):
				available_tiers.append(item.tier)

	available_tiers.sort()
	return available_tiers


# Populate tier dropdown with available tiers for the given item
func _populate_tier_dropdown(tier_dropdown: OptionButton, item_type: String, base_name: String, selected_tier: int) -> void:
	tier_dropdown.clear()

	var available_tiers = _get_available_tiers(item_type, base_name)
	if available_tiers.empty():
		# Fallback: show all tiers if none found
		if item_type == "character":
			available_tiers = [0]
		else:
			available_tiers = [0, 1, 2, 3]

	var tier_names = ["I", "II", "III", "IV"]
	var selected_index = 0

	for i in range(available_tiers.size()):
		var tier = available_tiers[i]
		if tier >= 0 and tier < tier_names.size():
			tier_dropdown.add_item(tier_names[tier], i)
			tier_dropdown.set_item_metadata(i, tier)
			if tier == selected_tier:
				selected_index = i

	# If selected_tier is not available, select first available tier
	if selected_index < 0 or selected_index >= tier_dropdown.get_item_count():
		selected_index = 0

	tier_dropdown.selected = selected_index


# Sort items alphabetically by name
func _sort_items_by_name(a: Dictionary, b: Dictionary) -> bool:
	return a.name < b.name


# Handle add item button press
func _on_add_item_pressed(container: VBoxContainer, mod_id: String, option: Dictionary) -> void:
	var default_item = {"base_name": "", "tier": 0, "count": 1, "cursed": false}
	_add_item_row(container, mod_id, option, default_item)
	_save_item_selector_value(container, mod_id, option)


func _on_remove_item_pressed(row: HBoxContainer, container: VBoxContainer, mod_id: String, option: Dictionary) -> void:
	var next_focusable = _find_next_focusable_element(row, container)

	var viewport = row.get_viewport()
	if viewport:
		var focus_emulators = _find_focus_emulators_recursive(viewport)

		for emulator in focus_emulators:
			if not is_instance_valid(emulator):
				continue

			var focused = emulator.focused_control
			if not is_instance_valid(focused):
				continue

			if focused == row or row.is_a_parent_of(focused):
				if next_focusable != null:
					if emulator.has_method("_set_focused_control_with_style"):
						emulator.call("_set_focused_control_with_style", next_focusable, false)
				else:
					if emulator.has_method("_clear_focused_control"):
						emulator.call("_clear_focused_control")

	container.remove_child(row)
	row.queue_free()
	_save_item_selector_value(container, mod_id, option)


func _find_next_focusable_element(row_to_delete: Control, container: VBoxContainer) -> Control:
	var all_rows = container.get_children()
	var current_index = all_rows.find(row_to_delete)

	var target_row = null
	if current_index + 1 < all_rows.size():
		target_row = all_rows[current_index + 1]
	elif current_index - 1 >= 0:
		target_row = all_rows[current_index - 1]

	if target_row != null:
		var focusable = _find_focusable_in_tree(target_row)
		if focusable != null:
			return focusable

	var add_button = _find_add_button_in_parent(container)
	if add_button != null:
		return add_button

	return null


# Recursively find all FocusEmulator instances
func _find_focus_emulators_recursive(node: Node) -> Array:
	var result = []

	# Check if this node is a FocusEmulator (check class name)
	if node.get_class() == "FocusEmulator" or (node.has_method("get_class") and node.get_class() == "FocusEmulator"):
		result.append(node)

	# Recursively search children
	for child in node.get_children():
		result.append_array(_find_focus_emulators_recursive(child))

	return result


# Find any focusable control in this tree
func _find_focusable_in_tree(node: Node):
	if not is_instance_valid(node) or node.is_queued_for_deletion():
		return null
	if node is Control and node.focus_mode == Control.FOCUS_ALL and node.is_visible_in_tree():
		return node
	for child in node.get_children():
		var result = _find_focusable_in_tree(child)
		if result != null:
			return result
	return null


func _find_add_button_in_parent(container: Node):
	if not is_instance_valid(container) or container.is_queued_for_deletion():
		return null
	var parent = container.get_parent()
	if parent == null:
		return null

	return _find_button_recursive(parent, "AddItemButton")


# Find button by name pattern
func _find_button_recursive(node: Node, pattern: String):
	if node is Button:
		if node.name.find(pattern) != -1:
			if node.focus_mode == Control.FOCUS_ALL and node.is_visible_in_tree():
				return node

	for child in node.get_children():
		var result = _find_button_recursive(child, pattern)
		if result != null:
			return result

	return null


# Handle item dropdown change (update tier dropdown when item changes)
func _on_item_dropdown_changed(selected_index: int, container: VBoxContainer, mod_id: String, option: Dictionary, row: HBoxContainer) -> void:
	# Get the item dropdown and tier dropdown from the row
	var children = row.get_children()
	if children.size() < 2:
		return

	var item_dropdown = children[0] as OptionButton
	var tier_dropdown = children[1] as OptionButton

	if not item_dropdown or not tier_dropdown:
		return

	# Get the newly selected item's base name
	var base_name = ""
	if selected_index >= 0 and selected_index < item_dropdown.get_item_count():
		base_name = item_dropdown.get_item_text(selected_index)

	# Update tier dropdown with available tiers for the new item
	var item_type = option.get("item_type", "item")
	var available_tiers = _get_available_tiers(item_type, base_name)
	_populate_tier_dropdown(tier_dropdown, item_type, base_name, 0) # Default to first available tier

	# Show/hide tier dropdown based on available tiers
	if available_tiers.size() > 1:
		tier_dropdown.visible = true
	else:
		tier_dropdown.visible = false

	# Save the change
	_save_item_selector_value(container, mod_id, option)


# Handle any change in item rows
func _on_item_row_changed(_value, container: VBoxContainer, mod_id: String, option: Dictionary) -> void:
	_save_item_selector_value(container, mod_id, option)


# Save the current state of the item selector
func _save_item_selector_value(container: VBoxContainer, mod_id: String, option: Dictionary) -> void:
	if not mod_options:
		return

	var items = []
	var item_type = option.get("item_type", "item")

	for row in container.get_children():
		if not row is HBoxContainer:
			continue

		var children = row.get_children()
		if children.size() < 5:
			continue

		var item_dropdown = children[0] as OptionButton
		var tier_dropdown = children[1] as OptionButton
		var spinbox = children[2] as SpinBox
		var checkbox = children[3] as CheckButton

		if not item_dropdown or not tier_dropdown or not spinbox or not checkbox:
			continue

		# Get base_name from item dropdown
		var selected_item_index = item_dropdown.selected
		if selected_item_index < 0:
			continue

		var base_name = ""
		if selected_item_index < item_dropdown.get_item_count():
			base_name = item_dropdown.get_item_text(selected_item_index)

		if base_name.empty():
			continue

		# Get tier from tier dropdown metadata
		var tier = 0
		if tier_dropdown.visible:
			var tier_selected_index = tier_dropdown.selected
			if tier_selected_index >= 0 and tier_selected_index < tier_dropdown.get_item_count():
				var tier_metadata = tier_dropdown.get_item_metadata(tier_selected_index)
				if tier_metadata != null:
					tier = tier_metadata
		else:
			# If tier dropdown is hidden, use the only available tier
			var available_tiers = _get_available_tiers(item_type, base_name)
			if available_tiers.size() > 0:
				tier = available_tiers[0]

		# Find the actual item ID from base_name and tier
		var item_id = _find_item_id(item_type, base_name, tier)
		if not item_id.empty():
			items.append({
				"id": item_id,
				"count": int(spinbox.value),
				"cursed": checkbox.pressed
			})

	mod_options.set_value(mod_id, option.id, items)


# Wrapper to fix parameter order for slider value_changed signal
func _on_slider_value_changed(value: float, mod_id: String, option_id: String) -> void:
	if mod_options:
		mod_options.set_value(mod_id, option_id, value)


# Wrapper to fix parameter order for toggle toggled signal
func _on_toggle_changed(pressed: bool, mod_id: String, option_id: String) -> void:
	if mod_options:
		mod_options.set_value(mod_id, option_id, pressed)


# Wrapper for LineEdit text_changed signal
func _on_line_edit_changed(new_text: String, mod_id: String, option_id: String) -> void:
	if mod_options:
		mod_options.set_value(mod_id, option_id, new_text)


# Wrapper for TextEdit text_changed signal
func _on_text_edit_changed(mod_id: String, option_id: String, text_edit: TextEdit) -> void:
	if mod_options and is_instance_valid(text_edit):
		mod_options.set_value(mod_id, option_id, text_edit.text)


# Helper to update integer display on sliders
func _update_integer_display(value: float, label: Label) -> void:
	if is_instance_valid(label):
		label.text = str(int(value))


# Helper to handle dropdown selection
func _on_dropdown_selected(index: int, mod_id: String, option_id: String, choices: Array) -> void:
	if index >= 0 and index < choices.size() and mod_options:
		mod_options.set_value(mod_id, option_id, choices[index])


# Handle keyboard/controller selection in item dropdown via FocusEmulator
func _on_item_dropdown_index_pressed(index: int, option_button: OptionButton) -> void:
	if is_instance_valid(option_button):
		option_button.emit_signal("item_selected", index)


# Handle keyboard/controller selection in tier dropdown via FocusEmulator
func _on_tier_dropdown_index_pressed(index: int, option_button: OptionButton) -> void:
	if is_instance_valid(option_button):
		option_button.emit_signal("item_selected", index)


# Setup conditional visibility for an option based on another option's value
func _setup_conditional_visibility(control: Node, mod_id: String, option: Dictionary) -> void:
	if not option.has("visible_if") or not mod_options:
		return

	var condition_option_id = option.visible_if

	# Register this control in the tracking dictionary
	if not _visibility_controls.has(mod_id):
		_visibility_controls[mod_id] = {}
	if not _visibility_controls[mod_id].has(condition_option_id):
		_visibility_controls[mod_id][condition_option_id] = []
	_visibility_controls[mod_id][condition_option_id].append(control)

	# Set initial visibility based on current value
	_update_control_visibility(control, mod_id, condition_option_id)

	# Listen for changes to the condition option (connect once)
	if mod_options and not mod_options.is_connected("config_changed", self, "_on_visibility_condition_changed"):
		mod_options.connect("config_changed", self, "_on_visibility_condition_changed")


# Called when a config value changes that might affect visibility
func _on_visibility_condition_changed(changed_mod_id: String, changed_option_id: String, _new_value) -> void:
	# Update only controls that depend on this specific option
	if not _visibility_controls.has(changed_mod_id):
		return
	if not _visibility_controls[changed_mod_id].has(changed_option_id):
		return

	var controls = _visibility_controls[changed_mod_id][changed_option_id]
	for control in controls:
		if is_instance_valid(control):
			_update_control_visibility(control, changed_mod_id, changed_option_id)


# Update the visibility of a single control based on its condition
func _update_control_visibility(control: Node, mod_id: String, condition_option_id: String) -> void:
	if not mod_options or not is_instance_valid(control):
		return

	var condition_value = mod_options.get_value(mod_id, condition_option_id)

	# Show control if condition is true (for boolean toggles)
	# For other types, could extend this logic
	var should_be_visible = bool(condition_value)

	control.visible = should_be_visible
