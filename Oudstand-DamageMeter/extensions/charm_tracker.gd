extends Node

const MOD_NAME: String = "DamageMeter"

var charm_tracking_enabled: bool = false
var last_check_wave: int = -1

func update_charm_tracking_state() -> void:
	var current_wave = RunData.current_wave

	if last_check_wave == current_wave:
		return

	last_check_wave = current_wave
	charm_tracking_enabled = false

	for i in range(RunData.get_player_count()):
		var character = RunData.get_player_character(i)
		if is_instance_valid(character) and character.my_id == "character_romantic":
			charm_tracking_enabled = true
			return

		# Same check the game uses to decide whether enemies can be charmed
		# (see charm_enemy_effect_behavior.gd). Effects are keyed by hash.
		# charm_evolved_on_hit comes from Primal Dread (e.g. Virus).
		if RunData.players_data.size() > i:
			var effects = RunData.players_data[i].effects
			if effects[Keys.charm_on_hit_hash].size() > 0 or effects[Keys.charm_evolved_on_hit_hash].size() > 0:
				charm_tracking_enabled = true
				return

	# Flute and any other weapon carrying a charm effect
	if RunData.existing_weapon_has_effect(Keys.charm_on_hit_hash):
		charm_tracking_enabled = true
