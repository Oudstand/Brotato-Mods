class_name QuickEquipItemTracker
extends Reference

# Tracks given equipment and configs to compute diffs per player

const MOD_ID := "Oudstand-QuickEquip"
const Utils = preload("res://mods-unpacked/Oudstand-QuickEquip/core/utils.gd")

# Track given equipment instances per player
# player_index -> {key -> Array of WeaponData/ItemData/CharacterData references}
var given_weapons := {}
var given_items := {}
var applied_character_abilities := {}

# Track last known configs to compute diffs per player
# player_index -> Array
var last_weapon_config := {}
var last_item_config := {}
var last_ability_config := {}


func track_weapon_instance(weapon_id: String, is_cursed: bool, weapon_data: WeaponData, player_index: int) -> void:
	var key = Utils.make_item_key(weapon_id, is_cursed)
	if not given_weapons.has(player_index):
		given_weapons[player_index] = {}
	if not given_weapons[player_index].has(key):
		given_weapons[player_index][key] = []
	given_weapons[player_index][key].append(weapon_data)


func track_item_instance(item_id: String, is_cursed: bool, item_data: ItemData, player_index: int) -> void:
	var key = Utils.make_item_key(item_id, is_cursed)
	if not given_items.has(player_index):
		given_items[player_index] = {}
	if not given_items[player_index].has(key):
		given_items[player_index][key] = []
	given_items[player_index][key].append(item_data)


func track_character_ability(character_id: String, ability_resource: CharacterData, player_index: int) -> void:
	if not applied_character_abilities.has(player_index):
		applied_character_abilities[player_index] = {}
	if not applied_character_abilities[player_index].has(character_id):
		applied_character_abilities[player_index][character_id] = []
	applied_character_abilities[player_index][character_id].append(ability_resource)


func update_tracking_configs(weapons_config: Array, items_config: Array, abilities_config: Array, player_index: int) -> void:
	last_weapon_config[player_index] = Utils.deep_copy_config(weapons_config)
	last_item_config[player_index] = Utils.deep_copy_config(items_config)
	last_ability_config[player_index] = Utils.deep_copy_config(abilities_config)
	ModLoaderLog.info("Tracking configs initialized for player %d" % player_index, MOD_ID)


func clear_all() -> void:
	# Clear all tracking data for all players
	given_weapons.clear()
	given_items.clear()
	applied_character_abilities.clear()
	last_weapon_config.clear()
	last_item_config.clear()
	last_ability_config.clear()


func has_tracked_items() -> bool:
	# Check if any player has tracked items
	return not last_weapon_config.empty() or not last_item_config.empty() or not last_ability_config.empty()
