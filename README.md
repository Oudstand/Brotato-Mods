# DamageMeter for Brotato

A comprehensive damage tracking mod for Brotato that displays real-time damage statistics for each player, including total damage dealt and the top damage sources (weapons/items).

## Features

- **Total Damage Display**: Shows each player's total damage as a progress bar, with percentage relative to the highest damage dealer
- **Top Damage Sources**: Displays the top 6 damage sources (weapons, items, abilities) with their individual damage values
- **Item Grouping**: Automatically groups identical items (e.g., multiple turrets) and shows the count
- **Smart Tracking**: Tracks damage from:
  - All weapons
  - Damage-dealing items
  - Spawned entities (turrets from Wrench, landmines from Screwdriver, turrets from Pocket Factory)
  - Character abilities
- **Visual Indicators**: 
  - Item rarity colors (Common, Uncommon, Rare, Legendary)
  - Cursed item markers (purple flames)
  - Rounded icon backgrounds
- **Performance Optimized**: Intelligent caching system for smooth gameplay

## Installation

1. Download the latest release
2. Extract the `Oudstand-DamageMeter` folder to your Brotato mods directory:
   - Windows: `%APPDATA%\Godot\app_userdata\Brotato\mods-unpacked\`
   - Linux: `~/.local/share/godot/app_userdata/Brotato/mods-unpacked/`
3. Launch Brotato and enable the mod in the Mods menu

## Configuration

All settings can be configured by editing constants at the top of `player_damage_updater.gd`:

```gdscript
const TOP_K: int = 6                    // Number of top damage sources to display (1-12)
const SHOW_ITEM_COUNT: bool = true      // Show count for grouped items (e.g. "x5")
const SHOW_DPS: bool = false            // Show damage per second
const BAR_OPACITY: float = 1.0          // Transparency (0.3-1.0)
const UPDATE_INTERVAL: float = 0.1      // Update frequency in seconds (0.05-0.5)
const ANIMATION_SPEED: float = 6.0      // Bar animation speed (1.0-20.0)
const MIN_DAMAGE_FILTER: int = 1        // Minimum damage to display (0 = show all)
const SHOW_PERCENTAGE: bool = true      // Show percentage values
const COMPACT_MODE: bool = false        // Smaller icons and text
```

## How It Works

### Damage Tracking
- **Weapons**: Tracked via `dmg_dealt_last_wave` property
- **Items**: Tracked via `RunData.tracked_item_effects` for items with `DAMAGE_DEALT` tracking
- **Spawned Entities**: Automatically detects and tracks damage from:
  - Engineering turrets (Wrench weapon)
  - Landmines (Screwdriver weapon)
  - Pocket Factory turrets

### Grouping System
Items are grouped by:
- Item ID
- Tier (rarity)
- Cursed status

This means 5 common turrets are grouped together, but a cursed turret appears separately.

### Performance
- **Source Caching**: The mod caches which items/weapons a player has and only recalculates damage values
- **Selective Updates**: UI elements only update when their values change
- **Optimized Arrays**: Uses PoolArrays for better performance

### Display Logic
- Progress bars are relative to the highest damage dealer (100%)
- When Player 1 has 100 damage and Player 2 has 80 damage:
  - Player 1: 100% progress bar
  - Player 2: 80% progress bar
- Bars update dynamically as damage changes

## Compatibility

- **Mod Loader Version**: 6.2.0+
- **Game Version**: 1.1.12.0
- **Multiplayer**: Supports up to 4 players

## Known Issues

- Config file support is not yet implemented (use constants instead)
- Some modded items may not be tracked if they don't use standard damage tracking

## Credits

Created by Oudstand

## License

This mod is provided as-is for the Brotato community. Feel free to modify and share.

## Support

For bugs or feature requests, please create an issue on the project repository.

## Changelog

### v1.1.0
- Added Pocket Factory support
- Performance optimizations with intelligent caching
- Added item count display for grouped items
- Added DPS display option
- Added configurable settings
- Fixed cursed item display bug
- Added rounded icon corners
- Improved damage filtering

### v1.0.0
- Initial release
- Basic damage tracking
- Top 6 damage sources display
- Multi-player support
