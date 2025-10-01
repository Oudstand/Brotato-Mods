extends "res://ui/hud/ui_wave_timer.gd"

const UPDATE_INTERVAL: float = 0.25
const TOP_K: int = 6
const MOD_NAME: String = "DamageMeter"

onready var _hud: Control = get_tree().get_current_scene().get_node("UI/HUD")

var update_timer: Timer = null
var active_displays: Array = []
var all_display_containers: Array = []
var wave_start_item_damages: Dictionary = {}

var _prev_totals: PoolIntArray = PoolIntArray()
var _prev_sigs: Array = []

static func _cmp_desc_by_damage(a: Dictionary, b: Dictionary) -> bool:
	return a.damage > b.damage

static func _create_signature(sources: Array) -> String:
	var parts: PoolStringArray = PoolStringArray()
	for entry in sources:
		var source = entry.source
		var id = str(source.my_id) if is_instance_valid(source) and "my_id" in source else "-1"
		parts.append("%s:%d" % [id, entry.damage])
	return parts.join("|")

func _ready() -> void:
	var player_count: int = RunData.get_player_count()
	
	# Sammle alle 4 Display Container
	for i in range(4):
		var path = "LifeContainerP%s/PlayerDamageContainerP%s" % [str(i + 1), str(i + 1)]
		var container = _hud.get_node_or_null(path)
		if is_instance_valid(container):
			all_display_containers.append(container)
			
			if i < player_count:
				active_displays.append(container)
			else:
				container.visible = false
		else:
			all_display_containers.append(null)
			ModLoaderLog.warning("Container für Spieler %d nicht gefunden" % (i + 1), MOD_NAME)
	
	if active_displays.empty():
		ModLoaderLog.error("Keine Display Container gefunden!", MOD_NAME)
		return
	
	# Initialisiere Item-Schaden Tracking
	_snapshot_wave_start(player_count)
	
	# Cache initialisieren
	_prev_totals.resize(player_count)
	_prev_sigs.resize(player_count)
	for i in range(player_count):
		_prev_totals[i] = -1
		_prev_sigs[i] = ""
	
	# Update Timer starten
	update_timer = Timer.new()
	update_timer.wait_time = UPDATE_INTERVAL
	update_timer.connect("timeout", self, "_update_damage_bars")
	add_child(update_timer)
	update_timer.start()
	
	ModLoaderLog.success("Updater initialisiert für %d Spieler" % player_count, MOD_NAME)

func _snapshot_wave_start(player_count: int) -> void:
	wave_start_item_damages.clear()
	
	for i in range(player_count):
		if RunData.tracked_item_effects.size() <= i:
			continue
		
		var item_map = {}
		
		# Snapshot ALLER tracked_item_effects für diesen Spieler
		for item_id in RunData.tracked_item_effects[i].keys():
			item_map[item_id] = int(RunData.tracked_item_effects[i].get(item_id, 0))
		
		wave_start_item_damages[i] = item_map

func _get_turret_id_for_tier(weapon: Object) -> String:
	if not is_instance_valid(weapon) or not "tier" in weapon:
		return ""
	
	match weapon.tier:
		Tier.COMMON:
			return "item_turret"
		Tier.UNCOMMON:
			return "item_turret_flame"
		Tier.RARE:
			return "item_turret_laser"
		Tier.LEGENDARY:
			return "item_turret_rocket"
	
	return ""

func _get_spawned_items_for_weapon(weapon: Object, player_index: int) -> Array:
	var spawned_items: Array = []
	
	if not is_instance_valid(weapon) or not "name" in weapon:
		return spawned_items
	
	if weapon.name == "WEAPON_WRENCH":
		var turret_id = _get_turret_id_for_tier(weapon)
		if turret_id:
			var turret = ItemService.get_item_from_id(turret_id)
			if is_instance_valid(turret):
				spawned_items.append(turret)
	
	elif weapon.name == "WEAPON_SCREWDRIVER":
		var landmine = ItemService.get_item_from_id("item_landmines")
		if is_instance_valid(landmine):
			spawned_items.append(landmine)
	
	return spawned_items

func _get_source_damage(source: Object, player_index: int) -> int:
	if not is_instance_valid(source):
		return 0
	
	if RunData.tracked_item_effects.size() <= player_index:
		return 0
	
	# Waffen: benutze dmg_dealt_last_wave
	if source.has_method("get_category") and source.get_category() == Category.WEAPON:
		return int(source.dmg_dealt_last_wave) if "dmg_dealt_last_wave" in source else 0
	
	# Alle anderen Quellen (Items, Character, Structures): benutze tracked_item_effects
	if "my_id" in source:
		var item_id = source.my_id
		
		# Prüfe ob diese ID in tracked_item_effects existiert
		if not RunData.tracked_item_effects[player_index].has(item_id):
			return 0
		
		var start_val = wave_start_item_damages.get(player_index, {}).get(item_id, 0)
		var current_val = RunData.tracked_item_effects[player_index].get(item_id, 0)
		return int(max(0, current_val - start_val))
	
	return 0

func _get_top_sources(all_sources: Array, player_index: int) -> Array:
	var sources_with_damage: Array = []
	
	for source in all_sources:
		var damage = _get_source_damage(source, player_index)
		if damage > 0:
			sources_with_damage.append({"source": source, "damage": damage})
	
	sources_with_damage.sort_custom(self, "_cmp_desc_by_damage")
	
	return sources_with_damage.slice(0, TOP_K - 1) if sources_with_damage.size() > TOP_K else sources_with_damage

func _collect_all_sources(player_index: int) -> Array:
	var all_sources: Array = []
	var added_ids: Dictionary = {}  # Verhindere Duplikate
	
	# Waffen
	for weapon in RunData.get_player_weapons(player_index):
		if is_instance_valid(weapon) and "my_id" in weapon:
			if not added_ids.has(weapon.my_id):
				all_sources.append(weapon)
				added_ids[weapon.my_id] = true
			
			# Füge gespawnte Items von Spawner-Waffen hinzu
			for spawned_item in _get_spawned_items_for_weapon(weapon, player_index):
				if "my_id" in spawned_item and not added_ids.has(spawned_item.my_id):
					all_sources.append(spawned_item)
					added_ids[spawned_item.my_id] = true
	
	# Items
	for item in RunData.get_player_items(player_index):
		if is_instance_valid(item) and "my_id" in item:
			if not added_ids.has(item.my_id):
				all_sources.append(item)
				added_ids[item.my_id] = true
	
	# Character (z.B. Bull's Explosion)
	var player_character = RunData.get_player_character(player_index)
	if is_instance_valid(player_character) and "my_id" in player_character:
		if not added_ids.has(player_character.my_id):
			# Prüfe ob Character tatsächlich Schaden in tracked_item_effects hat
			if RunData.tracked_item_effects.size() > player_index:
				if RunData.tracked_item_effects[player_index].has(player_character.my_id):
					all_sources.append(player_character)
					added_ids[player_character.my_id] = true
	
	return all_sources

func _update_damage_bars() -> void:
	var wave_active = is_instance_valid(wave_timer) and wave_timer.time_left > 0.0
	
	if not wave_active:
		# Smooth Fade Out wenn keine Welle läuft
		for display in active_displays:
			if is_instance_valid(display):
				display._target_alpha = 0.0
		return
	
	var player_count = active_displays.size()
	
	# Berechne Gesamtschaden und finde Maximum
	var totals = PoolIntArray()
	totals.resize(player_count)
	var max_total = 0
	
	for i in range(player_count):
		var total = 0
		var all_sources = _collect_all_sources(i)
		
		for source in all_sources:
			total += _get_source_damage(source, i)
		
		totals[i] = total
		if total > max_total:
			max_total = total
	
	# Update jeden Spieler
	for i in range(player_count):
		if i >= active_displays.size() or not is_instance_valid(active_displays[i]):
			continue
		
		var display = active_displays[i]
		display.visible = true
		display._target_alpha = 1.0
		
		var total = totals[i]
		var all_sources = _collect_all_sources(i)
		var top_sources = _get_top_sources(all_sources, i)
		var signature = _create_signature(top_sources)
		
		# Update nur wenn sich etwas geändert hat
		if _prev_totals[i] != total or _prev_sigs[i] != signature:
			var is_top_player = (player_count > 1 and total == max_total and total > 0)
			var character = RunData.get_player_character(i)
			var icon = character.icon if is_instance_valid(character) and "icon" in character else null
			
			display.update_total_damage(total, max_total, is_top_player, player_count == 1, icon, i)
			display.update_source_list(top_sources, i)
			
			_prev_totals[i] = total
			_prev_sigs[i] = signature

func _exit_tree() -> void:
	if is_instance_valid(update_timer):
		update_timer.queue_free()
