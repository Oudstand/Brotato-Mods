extends "res://entities/structures/landmine/landmine.gd"

# DamageMeter Extension: Redirect Bot-O-Mine pet landmine damage tracking
#
# Problem: Bot-O-Mine spawns landmines that use the shared "item_landmines"
# tracking key, making it impossible to attribute their damage to Bot-O-Mine.
#
# Solution: Only landmines spawned by the vanilla Bot-O-Mine structure effect
# are redirected to "item_bot_o_mine". Other pet/modded landmines keep their
# own tracking key.

const BOT_O_MINE_LANDMINE_EFFECT_PATH := "res://entities/units/pet/bot_o_mine/bot_o_mine_landmines_effect.tres"
const LANDMINES_ID := "item_landmines"

var _damage_meter_structure_data: Resource = null


func set_data(data: Resource) -> void:
	_damage_meter_structure_data = data
	.set_data(data)


func explode() -> void:
	var landmine_effects = get("effects")

	# Only intercept Bot-O-Mine landmines. Some mods create pet landmines too,
	# and redirecting all of them would hide their own damage tracking.
	if not _should_redirect_to_bot_o_mine(landmine_effects) or _is_dead():
		.explode()
		return

	# SAFER STRATEGY: Duplicate the effect instead of modifying the shared resource.
	# 1. Capture the original shared effect
	var original_effect = landmine_effects[0]
		
	# 2. Create a local copy and modify the copy's tracking key
	var temp_effect = original_effect.duplicate()
	temp_effect.set("tracking_key_hash", Keys.generate_hash("item_bot_o_mine"))
		
	# 3. Swap the copy into the effects array so .explode() uses it
	landmine_effects[0] = temp_effect
	set("effects", landmine_effects)

	# 4. Call the original explode logic
	.explode()

	# 5. Restore the original effect (good practice, though the mine dies anyway)
	landmine_effects[0] = original_effect
	set("effects", landmine_effects)

func _is_pet_landmine() -> bool:
	return "is_pet" in self and get("is_pet")

func _is_dead() -> bool:
	return "dead" in self and get("dead")

func _should_redirect_to_bot_o_mine(landmine_effects) -> bool:
	if not _is_pet_landmine() or not landmine_effects is Array or landmine_effects.size() <= 0:
		return false

	var explosion_effect = landmine_effects[0]
	if not is_instance_valid(explosion_effect):
		return false

	# Bot-O-Mine landmines reuse the vanilla Landmines tracking key. Modded
	# landmines with their own tracking key should keep that key untouched.
	if explosion_effect.get("tracking_key_hash") != Keys.generate_hash(LANDMINES_ID):
		return false

	return is_instance_valid(_damage_meter_structure_data) and _damage_meter_structure_data.resource_path == BOT_O_MINE_LANDMINE_EFFECT_PATH
