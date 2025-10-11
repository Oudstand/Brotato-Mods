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

### With Mod Options (Recommended)

If you have **Mod Options** installed, you can configure all settings in-game:
1. Go to **Options → Mods → DamageMeter**
2. Adjust settings with sliders and toggles
3. Changes are saved automatically and persist across game restarts
4. Changes apply instantly without needing to restart

**Install Mod Options:** [Thunderstore - dami-ModOptions](https://thunderstore.io/c/brotato/p/dami/ModOptions/)

### Without Mod Options

The mod works perfectly fine without Mod Options using sensible default values. Settings are saved automatically and persist between sessions. Advanced users can manually edit the config file at `%APPDATA%\Godot\app_userdata\Brotato\Oudstand-DamageMeter_config.json`.

**Available Settings (requires Mod Options):**
- **OPACITY** (0.3-1.0): Transparency of all UI elements
- **NUMBER_OF_SOURCES** (1-25): Number of top damage sources to display
- **SHOW_ITEM_COUNT**: Show count for grouped items (e.g. "x5")
- **SHOW_DPS**: Show damage per second
- **SHOW_PERCENTAGE**: Show percentage values relative to top player

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

## Optional Dependencies

- **Mod Options** (dami-ModOptions): Enables in-game configuration UI
  - Without it, the mod uses default values and works fine
  - Recommended for users who want to customize settings
  - Config persistence works with or without Mod Options installed

## Compatibility

- **Mod Loader Version**: 6.2.0+
- **Game Version**: 1.1.12.0
- **Multiplayer**: Supports up to 4 players

## Known Issues

- Some modded items may not be tracked if they don't use standard damage tracking

## Credits

Created by Oudstand

## License

This mod is provided as-is for the Brotato community. Feel free to modify and share.

## Support

For bugs or feature requests, please create an issue on the project repository.

## Changelog

### v1.2.0
- **Configuration System**: Full in-game configuration support with persistence
- Added Mod Options (dami-ModOptions) as optional dependency for config UI
- All settings configurable in-game when Mod Options is installed
- Works perfectly fine without Mod Options using default values
- Config changes are saved automatically and persist across game restarts
- Live config updates - changes apply instantly without restarting
- Custom config file support for advanced users
- Streamlined settings: removed rarely-used options (compact mode, animation speed, etc.)

### v1.1.0
- Added Pocket Factory support
- Performance optimizations with intelligent caching
- Added item count display for grouped items
- Added DPS display option
- Added configurable settings (code-based)
- Fixed cursed item display bug
- Added rounded icon corners
- Improved damage filtering

### v1.0.0
- Initial release
- Basic damage tracking
- Top 6 damage sources display
- Multi-player support