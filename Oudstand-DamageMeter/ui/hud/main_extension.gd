extends "res://main.gd"

const COMPACT_SEPARATION: int = 2
const MOD_DIR_NAME := "Oudstand-DamageMeter"

var _damage_meters_injected: bool = false
var _pocket_factory_turret_spawns: Array = [0, 0, 0, 0] # Track Pocket Factory turret spawns per player

# Use _enter_tree instead of _ready to inject nodes early
func _enter_tree() -> void:
	if not _damage_meters_injected:
		_inject_damage_meters()
		_damage_meters_injected = true

func _inject_damage_meters() -> void:
	var dmg_bar_scene = load("res://mods-unpacked/%s/ui/hud/player_dmg_bar.tscn" % MOD_DIR_NAME)

	for i in 4:
		var player_index = str(i + 1)
		var parent_path = "UI/HUD/LifeContainerP%s" % player_index
		var parent_node = get_node_or_null(parent_path)

		if not is_instance_valid(parent_node):
			continue

		var node_name = "PlayerDamageContainerP%s" % player_index
		if parent_node.has_node(node_name):
			continue

		var dmg_container = dmg_bar_scene.instance()
		dmg_container.name = node_name
		parent_node.add_child(dmg_container)
		# The meter stretches this container, which would otherwise catch the mouse
		parent_node.mouse_filter = Control.MOUSE_FILTER_IGNORE


# Hook into the _on_EntitySpawner_players_spawned function
# This is called after players are spawned and UI is set up
func _on_EntitySpawner_players_spawned(players: Array) -> void:
	._on_EntitySpawner_players_spawned(players)
	_reset_pocket_factory_spawns()
	_setup_damage_meter_positioning()

func _reset_pocket_factory_spawns() -> void:
	for i in range(4):
		_pocket_factory_turret_spawns[i] = 0

func _setup_damage_meter_positioning() -> void:
	var player_count = RunData.get_player_count()

	for i in range(player_count):
		var player_index = i + 1
		var life_container = _hud.get_node_or_null("LifeContainerP%s" % str(player_index))

		if not is_instance_valid(life_container):
			continue

		# Apply compact separation
		if life_container is BoxContainer:
			life_container.add_constant_override("separation", COMPACT_SEPARATION)

		# Get the damage container
		var dmg_container = life_container.get_node_or_null("PlayerDamageContainerP%s" % str(player_index))
		if not is_instance_valid(dmg_container):
			continue

		# Match HP/XP bar transparency behavior
		if RunData.is_coop_run:
			dmg_container.set_base_alpha(0.75)
		else:
			dmg_container.set_base_alpha(1.0)

		# Position based on player layout (top/bottom)
		var is_bottom_player: bool = i > 1 # P3 and P4 are bottom players

		# Reorder: bottom players show damage meter first, top players show it last
		if is_bottom_player:
			life_container.move_child(dmg_container, 0)
			_reorder_damage_bar_for_bottom_player(dmg_container)
		else:
			_reorder_damage_bar_for_top_player(dmg_container)

func _reorder_damage_bar_for_top_player(dmg_container: Control) -> void:
	var total_damage_bar = dmg_container.get_node_or_null("TotalDamageBar")
	if is_instance_valid(total_damage_bar):
		dmg_container.move_child(total_damage_bar, 0)

func _reorder_damage_bar_for_bottom_player(dmg_container: Control) -> void:
	var total_damage_bar = dmg_container.get_node_or_null("TotalDamageBar")
	if is_instance_valid(total_damage_bar):
		dmg_container.move_child(total_damage_bar, dmg_container.get_child_count() - 1)

# Override _on_neutral_died to track Pocket Factory turret spawns
func _on_neutral_died(neutral: Neutral, args: Entity.DieArgs) -> void:
	# Track Pocket Factory turret spawns BEFORE calling parent
	if not _cleaning_up:
		for player in _get_shuffled_live_players():
			var player_index = player.player_index
			var tree_turrets_count = RunData.get_player_effect(Keys.tree_turrets_hash, player_index)
			if tree_turrets_count > 0:
				_pocket_factory_turret_spawns[player_index] += tree_turrets_count

	# Call parent implementation
	._on_neutral_died(neutral, args)

# Getter for player_damage_updater.gd to access spawn counts
func get_pocket_factory_spawns(player_index: int) -> int:
	if player_index < 0 or player_index >= 4:
		return 0
	return _pocket_factory_turret_spawns[player_index]
