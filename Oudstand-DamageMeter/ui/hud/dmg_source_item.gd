extends Control

const SPACING_LEFT: int = 8
const SPACING_RIGHT: int = 12
const ICON_SIZE_NORMAL: int = 40
const ICON_SIZE_COMPACT: int = 32
const LABEL_WIDTH_RIGHT: int = 250

onready var content: HBoxContainer = $Content
onready var icon_bg: Panel = $Content/IconBackground
onready var icon: TextureRect = $Content/IconBackground/Icon
onready var count_badge: Panel = $Content/IconBackground/CountBadge
onready var count_label: Label = $Content/IconBackground/CountBadge/CountLabel
onready var label: Label = $Content/Label

var _is_right: bool = false

func _ready() -> void:
	# Style the count badge with dark semi-transparent background
	if is_instance_valid(count_badge):
		var stylebox = StyleBoxFlat.new()
		stylebox.bg_color = Color(0, 0, 0, 0.7)  # Dark semi-transparent
		stylebox.corner_radius_top_left = 3
		stylebox.corner_radius_top_right = 3
		stylebox.corner_radius_bottom_left = 3
		stylebox.corner_radius_bottom_right = 3
		count_badge.add_stylebox_override("panel", stylebox)

func set_data(source_info: Dictionary, show_item_count: bool = true) -> void:
	var source = source_info.get("source")
	if not is_instance_valid(source) or not "icon" in source:
		return

	var damage = source_info.get("damage", 0)
	var count = source_info.get("count", 1)

	# Set damage text (without count)
	label.text = Text.get_formatted_number(damage)

	# Show count badge on icon if enabled and count > 1
	if is_instance_valid(count_badge) and is_instance_valid(count_label):
		if show_item_count and count > 1:
			count_label.text = "x%d" % count
			count_badge.visible = true
		else:
			count_badge.visible = false

	if is_instance_valid(icon):
		icon.texture = source.icon

	# Set background color based on rarity
	if "tier" in source:
		var is_cursed = source.is_cursed if "is_cursed" in source else false
		_update_background_color(source.tier, is_cursed)

func _update_background_color(tier: int, is_cursed: bool) -> void:
	if not is_instance_valid(icon_bg):
		return
	
	var stylebox = StyleBoxFlat.new()
	ItemService.change_inventory_element_stylebox_from_tier(stylebox, tier, 0.3)
	
	# Rounded corners
	stylebox.corner_radius_top_left = 6
	stylebox.corner_radius_top_right = 6
	stylebox.corner_radius_bottom_left = 6
	stylebox.corner_radius_bottom_right = 6
	
	icon_bg.add_stylebox_override("panel", stylebox)
	
	# IMPORTANT: Always set cursed status (even false) to override old states
	if icon_bg.has_method("_update_stylebox"):
		icon_bg._update_stylebox(is_cursed)

func set_mod_alignment(is_right: bool) -> void:
	if _is_right == is_right:
		return
	
	_is_right = is_right
	
	content.anchor_left = 1.0 if is_right else 0.0
	content.anchor_right = content.anchor_left
	
	if is_right:
		label.rect_min_size.x = LABEL_WIDTH_RIGHT
		label.align = Label.ALIGN_RIGHT 
		content.move_child(label, 0)
		content.move_child(icon_bg, 1)
	else:
		label.rect_min_size.x = 0
		label.align = Label.ALIGN_LEFT
		content.move_child(icon_bg, 0)
		content.move_child(label, 1)
	
	content.add_constant_override("separation", SPACING_RIGHT if is_right else SPACING_LEFT)
	
	_update_margins()
	call_deferred("_update_margins")

func _update_margins() -> void:
	if not is_instance_valid(content):
		return
	
	var size = content.get_combined_minimum_size()
	
	if _is_right:
		content.margin_left = -size.x
		content.margin_right = 0
	else:
		content.margin_left = 0
		content.margin_right = size.x
