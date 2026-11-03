extends "res://entities/structures/dart_trap/dart_trap.gd"

# DamageMeter Extension: Track Dart Trap damage
#
# Problem: The Dart Trap structure effects (Awl weapon and Dart Trap item) ship
# without a tracking key, so the game never records their damage.
#
# Solution: Fall back to "item_dart_trap", which RunData already initializes as
# a tracked item key. Traps that come with their own tracking key keep it.

const DART_TRAP_ID := "item_dart_trap"


func set_data(data: Resource) -> void:
	.set_data(data)
	if _damage_tracking_key_hash == Keys.empty_hash:
		_damage_tracking_key_hash = Keys.generate_hash(DART_TRAP_ID)
