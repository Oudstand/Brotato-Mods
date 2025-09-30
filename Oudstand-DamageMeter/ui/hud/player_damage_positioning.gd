extends "res://ui/hud/player_ui_elements.gd"

const COMPACT_SEPARATION: int = 2

func set_hud_position(position_index: int) -> void:
	.set_hud_position(position_index)

	var dmg_container: Control = hud_container.get_node_or_null("PlayerDamageContainerP%s" % str(player_index + 1))
	if not is_instance_valid(dmg_container):
		return

	var is_bottom_player: bool = position_index > 1

	if is_bottom_player:
		hud_container.move_child(dmg_container, 0)
		dmg_container.get_node("ReorderLogic").reorder_for_bottom_player()
	else:
		dmg_container.get_node("ReorderLogic").reorder_for_top_player()

func _ready() -> void:
	var dmg_container: Control = hud_container.get_node_or_null("PlayerDamageContainerP%s" % str(player_index + 1))
	if not is_instance_valid(dmg_container):
		return
	var parent: Node = dmg_container.get_parent()
	if is_instance_valid(parent) and parent is BoxContainer:
		parent.add_constant_override("separation", COMPACT_SEPARATION)
