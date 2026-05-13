extends "res://entities/units/enemies/enemy.gd"

# Extension for tracking damage dealt by charmed enemies
# Much more performant than monitoring all hitboxes - only called when damage is actually dealt

const MOD_NAME: String = "DamageMeter"
const CHARMED_ENEMIES_DAMAGE_ID: String = "charmed_enemies_damage"

# Cache charm tracker singleton (lazy-loaded on first damage event)
var _charm_tracker = null
var _charm_tracker_loaded: bool = false

func take_damage(value: int, args) -> Array:
	# Call original method first to get actual damage dealt
	var result = .take_damage(value, args)

	# Lazy load charm tracker (only once on first damage event)
	# This avoids _ready() override issues that can cause duplicate signal connections
	if not _charm_tracker_loaded:
		_charm_tracker = get_node_or_null("/root/ModLoader/Oudstand-DamageMeter/DamageMeterCharmTracker")
		_charm_tracker_loaded = true

	# Early exit if charm tracker is not available
	if not is_instance_valid(_charm_tracker):
		return result

	# Early exit if charm tracking is disabled (performance optimization)
	# This avoids checking every enemy if no player has charm capabilities
	if not _charm_tracker.charm_tracking_enabled:
		return result

	# Check if the ATTACKER (who dealt damage to this enemy) is a charmed enemy
	# The attacker is stored in args.hitbox.from
	if not is_instance_valid(args):
		return result

	if not "hitbox" in args:
		return result

	var hitbox = args.hitbox
	if not is_instance_valid(hitbox):
		return result

	if not "from" in hitbox:
		return result

	var attacker = hitbox.from
	if not is_instance_valid(attacker):
		return result

	# Check if the attacker is a charmed enemy
	var charm_info = _get_charm_info_for_node(attacker)
	if charm_info.is_charmed:
		if charm_info.player_index < 0 or charm_info.player_index >= RunData.get_player_count():
			return result

		var damage_taken = result[1]  # result = [full_dmg, actual_dmg, is_dodge]
		RunData.add_tracked_value(charm_info.player_index, Keys.generate_hash(CHARMED_ENEMIES_DAMAGE_ID), damage_taken)

	return result

# Returns {is_charmed: bool, player_index: int} for any node
func _get_charm_info_for_node(node: Node) -> Dictionary:
	var result = {"is_charmed": false, "player_index": -1}

	if not is_instance_valid(node):
		return result

	# Look for CharmEnemyEffectBehavior in the node's direct children
	for child in node.get_children():
		# Check if it's a CharmEnemyEffectBehavior by looking for unique properties
		if "charmed" in child and "charmed_by_player_index" in child:
			if child.charmed:
				result.is_charmed = true
				result.player_index = child.charmed_by_player_index
				return result

		# CharmEnemyEffectBehavior is inside the EffectBehaviors container
		# Check if this child is the EffectBehaviors container
		if child.get_name() == "EffectBehaviors":
			# Look inside the EffectBehaviors container
			for effect_behavior in child.get_children():
				if "charmed" in effect_behavior and "charmed_by_player_index" in effect_behavior:
					if effect_behavior.charmed:
						result.is_charmed = true
						result.player_index = effect_behavior.charmed_by_player_index
						return result

	return result
