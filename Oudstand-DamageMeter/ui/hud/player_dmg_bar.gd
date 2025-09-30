extends VBoxContainer

export(PackedScene) var source_item_scene

onready var total_damage_bar: Control = $TotalDamageBar
onready var progress_bar: ProgressBar = $TotalDamageBar/ProgressBar
onready var icon_rect: TextureRect = $TotalDamageBar/HBoxContainer/CharacterIcon
onready var label: Label = $TotalDamageBar/HBoxContainer/DamageLabel
onready var source_list_container: VBoxContainer = $SourceListBackground/MarginContainer/SourceList
onready var hbox_container: HBoxContainer = $TotalDamageBar/HBoxContainer

var style_normal: StyleBox = null
var style_top_player: StyleBox = null
var _mirrored: bool = false
var _icon_position_cache: int = -1
var _current_style: StyleBox = null

var _target_progress: float = 0.0
var _current_progress: float = 0.0

export var bar_player_index := 0  # Setze diesen Wert je Balken-Instanz im Editor/Skript

func _ready() -> void:
	if is_instance_valid(progress_bar):
		var sb: StyleBox = progress_bar.get("custom_styles/fg")
		if sb != null:
			style_normal = sb
			style_top_player = sb.duplicate(true)
		else:
			style_normal = StyleBoxFlat.new()
			style_top_player = style_normal.duplicate(true)
		if style_top_player is StyleBoxFlat:
			(style_top_player as StyleBoxFlat).bg_color = Color(0.9, 0.75, 0.3)

	progress_bar.value = 0.0
	_current_progress = 0.0
	_target_progress = 0.0
	if style_normal:
		progress_bar.add_stylebox_override("fg", style_normal)
		_current_style = style_normal

	var icon = null
	if typeof(RunData) == TYPE_OBJECT and RunData.has_method("get_player_character"):
		var char_obj = RunData.get_player_character(bar_player_index)
		if is_instance_valid(char_obj) and "icon" in char_obj:
			icon = char_obj.icon

	update_total_damage(0, 100, false, true, icon, bar_player_index)

	if is_instance_valid(total_damage_bar):
		total_damage_bar.rect_clip_content = true
	if is_instance_valid(progress_bar):
		if not progress_bar.is_connected("resized", self, "_on_progressbar_resized"):
			progress_bar.connect("resized", self, "_on_progressbar_resized")

func _process(delta: float) -> void:
	if abs(_current_progress - _target_progress) > 0.1:
		_current_progress = lerp(_current_progress, _target_progress, 6.0 * delta)
		progress_bar.value = _current_progress
	else:
		progress_bar.value = _target_progress
		_current_progress = _target_progress

func _on_progressbar_resized() -> void:
	if _mirrored and is_instance_valid(progress_bar):
		progress_bar.rect_pivot_offset = progress_bar.rect_size / 2.0

func _set_progressbar_mirrored(enable: bool) -> void:
	_mirrored = enable
	if not is_instance_valid(progress_bar):
		return
	if enable:
		progress_bar.rect_scale.x = -1
		progress_bar.rect_pivot_offset = progress_bar.rect_size / 2.0
	else:
		progress_bar.rect_scale.x = 1
		progress_bar.rect_pivot_offset = Vector2.ZERO

func update_total_damage(damage: int, max_damage: int, is_top_player: bool, is_single_player: bool, player_icon: Texture, player_index: int) -> void:
	if not is_instance_valid(label):
		return
	var is_right_player: bool = player_index == 1 or player_index == 3
	label.align = Label.ALIGN_RIGHT if is_right_player else Label.ALIGN_LEFT
	label.text = str(damage)
	if player_icon and is_instance_valid(icon_rect):
		icon_rect.texture = player_icon
	elif is_instance_valid(icon_rect):
		icon_rect.texture = null
	var target_icon_pos: int = 1 if is_right_player else 0
	if is_instance_valid(hbox_container) and is_instance_valid(icon_rect):
		if _icon_position_cache != target_icon_pos:
			hbox_container.move_child(icon_rect, target_icon_pos)
			_icon_position_cache = target_icon_pos
	_set_progressbar_mirrored(is_right_player)
	if not is_instance_valid(progress_bar):
		return
	if damage == 0 or max_damage == 0:
		_target_progress = 0.0
		if style_normal and _current_style != style_normal:
			progress_bar.add_stylebox_override("fg", style_normal)
			_current_style = style_normal
	elif is_single_player:
		_target_progress = 100.0
		if style_normal and _current_style != style_normal:
			progress_bar.add_stylebox_override("fg", style_normal)
			_current_style = style_normal
	else:
		_target_progress = float(damage) / float(max_damage) * 100.0
		var new_style: StyleBox = style_top_player if is_top_player and damage > 0 else style_normal
		if _current_style != new_style:
			progress_bar.add_stylebox_override("fg", new_style)
			_current_style = new_style

func update_source_list(sources_with_damage: Array, player_index: int) -> void:
	if not is_instance_valid(source_list_container) or source_item_scene == null:
		return

	var is_right_player = player_index == 1 or player_index == 3
	var existing_items = source_list_container.get_children()
	var source_count = min(sources_with_damage.size(), 6)

	for i in range(source_count):
		var source_info = sources_with_damage[i]
		var src = null
		var dmg = 0
		if typeof(source_info) == TYPE_DICTIONARY:
			if source_info.has("source"): src = source_info["source"]
			if source_info.has("damage"): dmg = round(source_info["damage"])
		else:
			if "source" in source_info: src = source_info.source
			if "damage" in source_info: dmg = round(source_info.damage)

		if not is_instance_valid(src):
			continue

		var item_instance = null
		if i < existing_items.size():
			item_instance = existing_items[i]
		else:
			item_instance = source_item_scene.instance()
			source_list_container.add_child(item_instance)

		item_instance.visible = true
		if item_instance.has_method("set_data"):
			item_instance.set_data({"source": src, "damage": dmg})
		if item_instance.has_method("set_mod_alignment"):
			item_instance.set_mod_alignment(is_right_player)

	for i in range(source_count, existing_items.size()):
		existing_items[i].visible = false

	var row_h: int = 32
	if source_list_container.get_child_count() > 0:
		var first_item = source_list_container.get_child(0)
		if is_instance_valid(first_item):
			row_h = int(first_item.rect_min_size.y)

	var sep: int = 2
	var needed_list_h: int = 0
	if source_count > 0:
		needed_list_h = source_count * row_h + (source_count - 1) * sep

	if is_instance_valid(source_list_container):
		source_list_container.add_constant_override("separation", sep)
		source_list_container.rect_min_size.y = needed_list_h
		source_list_container.size_flags_vertical &= ~Control.SIZE_EXPAND

	var src_bg: Control = get_node_or_null("SourceListBackground")
	if is_instance_valid(src_bg):
		src_bg.rect_min_size.y = needed_list_h
		src_bg.size_flags_vertical &= ~Control.SIZE_EXPAND

	add_constant_override("separation", 4)
	size_flags_vertical &= ~Control.SIZE_EXPAND
