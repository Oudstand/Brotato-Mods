extends "res://ui/menus/pages/menu_options.gd"

# During a coop wave, Utils.get_focus_emulator(0) returns null because Main has no
# root-level FocusEmulator1. Vanilla then accesses .player_index on null, which halts
# debug/editor runs (release builds only log the error).


func init() -> void:
	if RunData.is_coop_run and Utils.get_focus_emulator(0) == null:
		# Skip the coop branch that sets the LB/RB icons from the focus emulator
		RunData.is_coop_run = false
		.init()
		RunData.is_coop_run = true
	else:
		.init()


func _on_BackButton_pressed() -> void:
	if not is_instance_valid(focus_before_created):
		emit_signal("back_button_pressed")
		return
	._on_BackButton_pressed()
