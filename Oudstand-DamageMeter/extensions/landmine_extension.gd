extends "res://entities/structures/landmine/landmine.gd"

# DamageMeter Extension: Redirect Bot-O-Mine pet landmine damage tracking
#
# Problem: Bot-O-Mine spawns landmines that use the shared "item_landmines"
# tracking key, making it impossible to attribute their damage to Bot-O-Mine.
#
# Solution: Pet landmines have is_pet = true (set from bot_o_mine_landmines_effect.tres),
# while regular landmines have is_pet = false. We use this flag to redirect
# the damage tracking to "item_bot_o_mine" for pet landmines.


func explode() -> void:
	var landmine_effects = get("effects")

	# Only intercept pet landmines (spawned by Bot-O-Mine)
	if not _is_pet_landmine() or _is_dead() or not landmine_effects is Array or landmine_effects.size() <= 0:
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
