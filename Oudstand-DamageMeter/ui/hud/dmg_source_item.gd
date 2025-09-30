extends Control

const ALIGNMENT_SPACING_LEFT: int = 8
const ALIGNMENT_SPACING_RIGHT: int = 12

onready var content: HBoxContainer = $Content
onready var icon: TextureRect = $Content/Icon
onready var label: Label = $Content/Label

var _current_alignment_right: bool = false
var _label_position_cache: int = -1

func set_data(source_info: Dictionary) -> void:
	var source: Object = source_info.get("source", null)
	var damage: int = source_info.get("damage", 0)
	if is_instance_valid(source):
		label.text = str(damage)
		icon.texture = source.icon

func set_mod_alignment(is_right: bool) -> void:
	if _current_alignment_right == is_right:
		return
	_current_alignment_right = is_right
	if is_right:
		content.anchor_left = 1.0
		content.anchor_right = 1.0
		if _label_position_cache != 0:
			content.move_child(label, 0)
			content.move_child(icon, 1)
			_label_position_cache = 0
		content.add_constant_override("separation", ALIGNMENT_SPACING_RIGHT)
	else:
		content.anchor_left = 0.0
		content.anchor_right = 0.0
		if _label_position_cache != 1:
			content.move_child(icon, 0)
			content.move_child(label, 1)
			_label_position_cache = 1
		content.add_constant_override("separation", ALIGNMENT_SPACING_LEFT)
	yield(get_tree(), "idle_frame")
	_update_margins()

func _update_margins() -> void:
	if not is_instance_valid(content):
		return
	var content_size: Vector2 = content.get_combined_minimum_size()
	if content.anchor_left == 1.0:
		content.margin_left = -content_size.x
		content.margin_right = 0
	else:
		content.margin_left = 0
		content.margin_right = content_size.x
