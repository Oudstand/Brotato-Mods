extends Node

# Resources used for creating UI elements
const SLIDER_SCENE := "res://ui/menus/global/slider_option.tscn"
const FONT_PATH := "res://resources/fonts/actual/base/font_40_outline.tres"
const BUTTON_HOVER_STYLE := "res://resources/themes/button_styles/button_hover.tres"
const MENU_BUTTON_SCRIPT := "res://ui/menus/global/my_menu_button.gd"


# Reference to ModOptions manager (set by injector)
var mod_options: Node = null


# Create a unified options tab containing all registered mods
# Returns a ScrollContainer with all mods' options
func create_unified_options_tab(registered_mods: Array) -> ScrollContainer:
	var scroll_container := ScrollContainer.new()
	scroll_container.name = "ModOptions_Container"
	scroll_container.anchor_right = 1.0
	scroll_container.anchor_bottom = 1.0
	scroll_container.margin_top = 20.0
	scroll_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll_container.follow_focus = true
	scroll_container.scroll_horizontal_enabled = false

	var vbox := VBoxContainer.new()
	vbox.name = "ModOptionsContainer"
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.set("custom_constants/separation", 15)
	vbox.alignment = BoxContainer.ALIGN_CENTER

	scroll_container.add_child(vbox)

	# Add options for each mod with separators
	for i in range(registered_mods.size()):
		var mod_id = registered_mods[i]
		var config = mod_options.get_mod_config(mod_id) if mod_options else {}

		if config.empty():
			continue

		# Add mod header
		_add_mod_header(vbox, config.tab_title)

		# Add mod options
		for option in config.options:
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

		# Add info text if present
		if config.has("info_text"):
			var info_label := Label.new()
			info_label.text = tr(config.info_text)
			info_label.align = Label.ALIGN_CENTER
			info_label.valign = Label.VALIGN_CENTER
			info_label.autowrap = true
			info_label.modulate = Color(0.6, 0.6, 0.6)
			# Set font size to 24
			var font: DynamicFont = load(FONT_PATH)
			if font:
				var custom_font = font.duplicate()
				custom_font.size = 24
				info_label.set("custom_fonts/font", custom_font)
			vbox.add_child(info_label)

		# Add separator between mods (except after last one)
		if i < registered_mods.size() - 1:
			var separator := HSeparator.new()
			separator.set("custom_constants/separation", 30)
			vbox.add_child(separator)

	return scroll_container


# Add a mod name header
func _add_mod_header(vbox: VBoxContainer, title: String) -> void:
	var header := Label.new()
	header.text = title
	header.align = Label.ALIGN_CENTER
	var font: DynamicFont = load(FONT_PATH)
	if font:
		header.set("custom_fonts/font", font)
	vbox.add_child(header)


# Create a complete options tab for a mod (DEPRECATED - kept for compatibility)
# Returns a ScrollContainer with all the options
func create_options_tab(mod_id: String, config: Dictionary) -> ScrollContainer:
	var scroll_container := ScrollContainer.new()
	scroll_container.name = "%s_Container" % mod_id
	scroll_container.anchor_right = 1.0
	scroll_container.anchor_bottom = 1.0
	scroll_container.margin_top = 20.0
	scroll_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll_container.follow_focus = true
	scroll_container.scroll_horizontal_enabled = false

	var vbox := VBoxContainer.new()
	vbox.name = "%sContainer" % mod_id
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.set("custom_constants/separation", 15)
	vbox.alignment = BoxContainer.ALIGN_CENTER

	scroll_container.add_child(vbox)

	# Create controls for each option
	for option in config.options:
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

	# Add separator and info text at the bottom if present
	if config.has("info_text"):
		var separator := HSeparator.new()
		vbox.add_child(separator)

		var info_label := Label.new()
		info_label.text = tr(config.info_text)
		info_label.align = Label.ALIGN_CENTER
		info_label.valign = Label.VALIGN_CENTER
		info_label.autowrap = true
		info_label.modulate = Color(0.6, 0.6, 0.6)
		# Set font size to 24
		var font: DynamicFont = load(FONT_PATH)
		if font:
			var custom_font = font.duplicate()
			custom_font.size = 24
			info_label.set("custom_fonts/font", custom_font)
		vbox.add_child(info_label)

	return scroll_container


# Create a slider control
func _create_slider_option(mod_id: String, option: Dictionary) -> Node:
	var slider_scene: PackedScene = load(SLIDER_SCENE)
	if not slider_scene:
		ModLoaderLog.error("ModOptions: Failed to load slider scene", "ModOptions")
		return null

	var slider_instance := slider_scene.instance()
	slider_instance.name = "%sSlider" % option.id.capitalize().replace(" ", "")
	slider_instance.unique_name_in_owner = true

	# Configure label
	var label: Label = slider_instance.get_node("Label")
	if label:
		label.text = option.label

	# Configure slider
	var hslider: HSlider = slider_instance.get_node("HSlider")
	if hslider:
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

	return slider_instance


# Create a toggle (CheckButton) control
func _create_toggle_option(mod_id: String, option: Dictionary) -> Node:
	var check_button := CheckButton.new()
	check_button.name = "%sButton" % option.id.capitalize().replace(" ", "")
	check_button.unique_name_in_owner = true

	# Load and apply resources
	var font: DynamicFont = load(FONT_PATH)
	if font:
		check_button.set("custom_fonts/font", font)

	var hover_style: StyleBox = load(BUTTON_HOVER_STYLE)
	if hover_style:
		check_button.set("custom_styles/hover_pressed", hover_style)

	# Apply menu button script for sound effects
	var menu_script: Script = load(MENU_BUTTON_SCRIPT)
	if menu_script:
		check_button.script = menu_script

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
	var font: DynamicFont = load(FONT_PATH)
	if font:
		label.set("custom_fonts/font", font)
	label.text = option.label
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(label)

	# OptionButton
	var option_button := OptionButton.new()
	option_button.unique_name_in_owner = true
	if font:
		option_button.set("custom_fonts/font", font)

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
	return hbox


# Create a text input (LineEdit or TextEdit) control
func _create_text_option(mod_id: String, option: Dictionary) -> Node:
	var vbox_container := VBoxContainer.new()
	vbox_container.name = "%sContainer" % option.id.capitalize().replace(" ", "")
	vbox_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Label
	var label := Label.new()
	var font: DynamicFont = load(FONT_PATH)
	if font:
		label.set("custom_fonts/font", font)
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
		if font:
			text_edit.set("custom_fonts/font", font)

		if mod_options:
			text_edit.text = str(mod_options.get_value(mod_id, option.id))
			text_edit.connect("text_changed", self, "_on_text_edit_changed", [mod_id, option.id, text_edit])

		text_input = text_edit
	else:
		var line_edit := LineEdit.new()
		line_edit.unique_name_in_owner = true
		if font:
			line_edit.set("custom_fonts/font", font)

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
		if font:
			var custom_font = font.duplicate()
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
	var font: DynamicFont = load(FONT_PATH)
	if font:
		label.set("custom_fonts/font", font)
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
	# Use translation if help_text is a translation key, otherwise use default text
	var button_translation_key = ""
	if option.has("help_text") and option.help_text.begins_with("QUICKEQUIP_"):
		# QuickEquip mod uses translation keys
		if option.get("item_type", "item") == "weapon":
			button_translation_key = "QUICKEQUIP_ADD_WEAPON"
		else:
			button_translation_key = "QUICKEQUIP_ADD_ITEM"

	if not button_translation_key.empty():
		add_button.text = tr(button_translation_key)
	else:
		add_button.text = "+ Add %s" % ("Weapon" if option.get("item_type", "item") == "weapon" else "Item")

	if font:
		add_button.set("custom_fonts/font", font)
	add_button.connect("pressed", self, "_on_add_item_pressed", [items_container, mod_id, option])
	main_vbox.add_child(add_button)

	# Help text
	if option.has("help_text"):
		var help_label := Label.new()
		help_label.text = tr(option.help_text)
		help_label.modulate = Color(0.7, 0.7, 0.7)
		help_label.autowrap = true
		# Set font size to 30
		if font:
			var custom_font = font.duplicate()
			custom_font.size = 30
			help_label.set("custom_fonts/font", custom_font)
		main_vbox.add_child(help_label)

	return main_vbox


# Add a row for a single item in the item selector
func _add_item_row(container: VBoxContainer, mod_id: String, option: Dictionary, item_data: Dictionary) -> void:
	var row := HBoxContainer.new()
	row.set("custom_constants/separation", 10)

	var font: DynamicFont = load(FONT_PATH)

	# Get unique base items
	var item_type = option.get("item_type", "item")
	var unique_items = _get_unique_base_items(item_type)

	# Dropdown for weapon/item selection (deduplicated)
	var item_dropdown := OptionButton.new()
	item_dropdown.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if font:
		item_dropdown.set("custom_fonts/font", font)

	# Populate dropdown with unique items and icons
	var selected_item_index = 0
	var icon_size = Vector2(60, 60)  # Fixed icon size for consistency

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
	row.add_child(item_dropdown)

	# Dropdown for tier selection (only shown if multiple tiers available)
	var tier_dropdown := OptionButton.new()
	tier_dropdown.rect_min_size.x = 80
	if font:
		tier_dropdown.set("custom_fonts/font", font)

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
	row.add_child(tier_dropdown)

	# Count input
	var count_spinbox := SpinBox.new()
	count_spinbox.min_value = 1
	count_spinbox.max_value = 999
	count_spinbox.step = 1
	count_spinbox.value = item_data.get("count", 1)
	count_spinbox.rect_min_size = Vector2(80, 0)
	if font:
		count_spinbox.get_line_edit().set("custom_fonts/font", font)
	count_spinbox.connect("value_changed", self, "_on_item_row_changed", [container, mod_id, option])
	row.add_child(count_spinbox)

	# Cursed checkbox
	var cursed_check := CheckButton.new()
	# Use translation if available
	if option.has("help_text") and option.help_text.begins_with("QUICKEQUIP_"):
		cursed_check.text = tr("QUICKEQUIP_CURSED")
	else:
		cursed_check.text = "Cursed"
	cursed_check.pressed = item_data.get("cursed", false)
	if font:
		cursed_check.set("custom_fonts/font", font)
	cursed_check.connect("toggled", self, "_on_item_row_changed", [container, mod_id, option])
	row.add_child(cursed_check)

	# Remove button
	var remove_button := Button.new()
	remove_button.text = "X"
	if font:
		remove_button.set("custom_fonts/font", font)
	remove_button.connect("pressed", self, "_on_remove_item_pressed", [row, container, mod_id, option])
	row.add_child(remove_button)

	container.add_child(row)


# Get all available items or weapons from ItemService
func _get_available_items(item_type: String) -> Array:
	var result = []

	if not is_instance_valid(ItemService):
		return result

	var source_list = ItemService.weapons if item_type == "weapon" else ItemService.items

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

	var source_list = ItemService.weapons if item_type == "weapon" else ItemService.items
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


# Handle remove item button press
func _on_remove_item_pressed(row: HBoxContainer, container: VBoxContainer, mod_id: String, option: Dictionary) -> void:
	container.remove_child(row)
	row.queue_free()
	_save_item_selector_value(container, mod_id, option)


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
	_populate_tier_dropdown(tier_dropdown, item_type, base_name, 0)  # Default to first available tier

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
