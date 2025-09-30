extends Node

func reorder_for_top_player() -> void:
	var container: VBoxContainer = get_parent()
	var total_damage_bar: Control = container.get_node("TotalDamageBar")
	container.move_child(total_damage_bar, 0)

func reorder_for_bottom_player() -> void:
	var container: VBoxContainer = get_parent()
	var total_damage_bar: Control = container.get_node("TotalDamageBar")
	container.move_child(total_damage_bar, container.get_child_count() - 1)
