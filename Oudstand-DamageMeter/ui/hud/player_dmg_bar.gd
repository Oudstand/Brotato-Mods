extends VBoxContainer

export(PackedScene) var source_item_scene

onready var progress_bar: ProgressBar = $TotalDamageBar/ProgressBar
onready var icon_rect: TextureRect = $TotalDamageBar/HBoxContainer/CharacterIcon
onready var label: Label = $TotalDamageBar/HBoxContainer/DamageLabel
onready var source_list: VBoxContainer = $SourceListBackground/MarginContainer/SourceList
onready var hbox: HBoxContainer = $TotalDamageBar/HBoxContainer

var style_normal: StyleBox = null

var _current_progress: float = 0.0
var _target_progress: float = 0.0
var _mirrored: bool = false
var _icon_position: int = -1
var _target_alpha: float = 1.0
var _current_alpha: float = 1.0

# Settings (set by updater)
var _lerp_speed: float = 6.0
var _fade_speed: float = 8.0
var _max_alpha: float = 1.0
var _compact_mode: bool = false

const ROW_HEIGHT_NORMAL: int = 32
const ROW_HEIGHT_COMPACT: int = 24
const ICON_SIZE_NORMAL: int = 32
const ICON_SIZE_COMPACT: int = 24
const SEPARATION: int = 2
const MAX_SOURCES: int = 12

func _ready() -> void:
	_init_styles()
	progress_bar.value = 0.0
	progress_bar.connect("resized", self, "_on_progress_resized")

func _init_styles() -> void:
	var base_style = progress_bar.get("custom_styles/fg")
	style_normal = base_style if base_style else StyleBoxFlat.new()
	progress_bar.add_stylebox_override("fg", style_normal)

func set_animation_settings(animation_speed: float, opacity: float, compact_mode: bool) -> void:
	_lerp_speed = animation_speed
	_max_alpha = opacity
	_compact_mode = compact_mode
	
	if _compact_mode:
		icon_rect.rect_min_size = Vector2(ICON_SIZE_COMPACT, ICON_SIZE_COMPACT)

func _process(delta: float) -> void:
	if abs(_current_progress - _target_progress) > 0.1:
		_current_progress = lerp(_current_progress, _target_progress, _lerp_speed * delta)
		progress_bar.value = _current_progress

	if abs(_current_alpha - _target_alpha) > 0.01:
		_current_alpha = lerp(_current_alpha, _target_alpha, _fade_speed * delta)
		modulate.a = _current_alpha

func _on_progress_resized() -> void:
	if _mirrored:
		progress_bar.rect_pivot_offset = progress_bar.rect_size / 2.0

func _set_layout(player_index: int) -> void:
	var is_right = (player_index == 1 or player_index == 3)

	label.align = Label.ALIGN_RIGHT if is_right else Label.ALIGN_LEFT
	hbox.alignment = BoxContainer.ALIGN_END if is_right else BoxContainer.ALIGN_BEGIN

	var target_pos = 1 if is_right else 0
	if _icon_position != target_pos:
		hbox.move_child(icon_rect, target_pos)
		_icon_position = target_pos

	if _mirrored != is_right:
		_mirrored = is_right
		progress_bar.rect_scale.x = -1.0 if is_right else 1.0
		progress_bar.rect_pivot_offset = progress_bar.rect_size / 2.0 if is_right else Vector2.ZERO

func update_total_damage(
	damage: int, 
	percentage: float, 
	max_damage: int, 
	icon: Texture, 
	player_index: int,
	show_dps: bool = false,
	dps: int = 0,
	show_percentage: bool = true
) -> void:
	_set_layout(player_index)

	# Build label text
	var text_parts = []
	text_parts.append(Text.get_formatted_number(damage))
	
	if show_percentage and max_damage > 0 and damage > 0:
		text_parts.append("(%d%%)" % int(percentage))
	
	if show_dps and dps > 0:
		text_parts.append("| %s/s" % Text.get_formatted_number(dps))
	
	label.text = " ".join(text_parts) if text_parts.size() > 1 else text_parts[0]

	icon_rect.texture = icon

	# Calculate progress
	if damage == 0 or max_damage == 0:
		_target_progress = 0.0
	else:
		_target_progress = percentage

func update_source_list(sources: Array, player_index: int, show_item_count: bool = true) -> void:
	if sources.empty():
		for child in source_list.get_children():
			child.visible = false
		source_list.rect_min_size.y = 0
		var bg = get_node_or_null("SourceListBackground")
		if is_instance_valid(bg):
			bg.rect_min_size.y = 0
		return

	var is_right = (player_index == 1 or player_index == 3)
	var existing = source_list.get_children()
	var count = min(sources.size(), MAX_SOURCES)
	var row_height = ROW_HEIGHT_COMPACT if _compact_mode else ROW_HEIGHT_NORMAL

	for i in range(count):
		var item
		if i < existing.size():
			item = existing[i]
		else:
			item = source_item_scene.instance()
			source_list.add_child(item)

		item.visible = true
		item.set_data(sources[i], show_item_count)
		item.set_mod_alignment(is_right)

	for i in range(count, existing.size()):
		existing[i].visible = false

	var height = count * row_height + max(0, count - 1) * SEPARATION
	source_list.rect_min_size.y = height
	source_list.add_constant_override("separation", SEPARATION)

	var bg = get_node_or_null("SourceListBackground")
	if is_instance_valid(bg):
		bg.rect_min_size.y = height
