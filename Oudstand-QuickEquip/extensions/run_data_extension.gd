extends "res://singletons/run_data.gd"

# Gives the configured QuickEquip items at the start of each run. on_wave_start()
# runs in Main._ready(), before the players spawn, so they spawn already equipped.

const MOD_ID = "Oudstand-QuickEquip"


func _get_quickequip_mod() -> Node:
	return get_node_or_null("/root/ModLoader/%s" % MOD_ID)


func reset(restart: bool = false) -> void:
	.reset(restart)
	_clear_quickequip_tracking()


func resume_from_state(state: Dictionary) -> void:
	.resume_from_state(state)
	_clear_quickequip_tracking()


func on_wave_start(timer) -> void:
	.on_wave_start(timer)

	if current_wave == 1:
		var quick_equip_mod = _get_quickequip_mod()
		if quick_equip_mod:
			quick_equip_mod.on_run_started()


# Tracked resources belong to the previous run (or a run loaded from a save)
func _clear_quickequip_tracking() -> void:
	var quick_equip_mod = _get_quickequip_mod()
	if quick_equip_mod:
		quick_equip_mod.clear_tracking()
