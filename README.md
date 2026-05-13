# Brotato Mods Collection by Oudstand

A collection of quality-of-life and enhancement mods for Brotato, featuring a powerful configuration framework and useful gameplay tools.

## Mods Included

### 🔧 ModOptions

**A flexible configuration framework for Brotato mods**

ModOptions provides an easy-to-use API for mod developers to add in-game configuration interfaces. All mod settings appear in a unified "Mods" tab in the Options menu, providing a consistent and user-friendly experience.

**Key Features:**

- Unified configuration interface for all mods
- Rich option types: sliders, toggles, dropdowns, text inputs, item selectors
- Live configuration updates
- Automatic setting persistence
- Simple API for mod developers
- Full translation support

[📖 Read More](Oudstand-ModOptions/README.md)

---

### 📊 DamageMeter

**Real-time damage tracking and statistics**

DamageMeter displays comprehensive damage statistics during runs, showing total damage dealt and top damage sources for each player. Perfect for analyzing builds and optimizing strategies.

**Key Features:**

- Real-time damage tracking with progress bars
- Top damage sources display (weapons, items, abilities)
- Tracks spawned entities (turrets, landmines, etc.)
- Item grouping with rarity indicators
- Configurable via ModOptions
- Performance optimized

[📖 Read More](Oudstand-DamageMeter/README.md)

---

### ⚡ QuickEquip

**Instantly equip items and weapons during runs**

QuickEquip lets you add or remove weapons and items anytime during a run. Perfect for testing builds, experimenting with equipment, or setting up challenge runs.

**Key Features:**

- Add/remove equipment during active runs
- Smart item selection with icons and tier dropdowns
- Live updates - changes apply immediately
- Configure quantity and cursed status
- Clean UI integrated with ModOptions
- Multilingual (English, German)

[📖 Read More](Oudstand-QuickEquip/README.md)

---

## Screenshots

![ModOptions Interface](Oudstand-ModOptions/screenshots/modoptions_ui_damage_meter.png)
_Unified "Mods" tab in Options menu_

![ModOptions Sidebar](Oudstand-ModOptions/screenshots/modoptions_ui_sidebar.png)
_Sidebar navigation for multiple mods_

![DamageMeter](screenshots/damagemeter_overview.png)
_DamageMeter showing damage statistics during gameplay_

![QuickEquip](Oudstand-QuickEquip/screenshots/quickequip_ui.png)
_QuickEquip configuration with item selection_

## Configuration

All mods can be configured in-game:

1. Launch Brotato
2. Go to **Options** (ESC or main menu)
3. Select **Mods** tab
4. Configure each mod's settings

Settings are automatically saved and persist between sessions.

## Compatibility

- **Mod Loader Version**: 6.2.0+
- **Game Version**: 1.1.15.0+ (All Pain No Gain)
- **Multiplayer**: Full support (DamageMeter supports up to 4 players)

## For Mod Developers

Want to add configuration to your own mod? See the [ModOptions README](Oudstand-ModOptions/README.md) for full API documentation and examples.

## ☕ Support this project

This project is developed and maintained in my free time.
If you enjoy the mods or find them useful, you can support the development:

[![PayPal](https://img.shields.io/badge/PayPal-Buy%20me%20a%20coffee-blue.svg?style=for-the-badge)](https://paypal.me/oudstand)

Thank you for supporting open source! 💙

## Credits

- **Oudstand** — Creator and maintainer
- **L10nM4st3r** — Performance improvements, native Mods tab integration, sidebar navigation, controller support ([PR #2](https://github.com/Oudstand/Brotato-Mods/pull/2))

## License

These mods are provided as-is for the Brotato community. Feel free to modify and share.

## Support

For bugs, feature requests, or questions:

- Create an issue on this repository
- Check individual mod READMEs for specific documentation

## Changelog

### ModOptions v1.1.0

- Controller support: Mods tab now fully integrated with bumper/shoulder button navigation
- Sidebar: Quick navigation between mod settings when multiple mods are installed
- Performance: Settings injection no longer affects gameplay performance
- Compatibility: Updated for All Pain No Gain
- _Contributed by L10nM4st3r_

### ModOptions v1.0.0

- Initial release with unified configuration interface

### DamageMeter v1.3.0

- **Bot-O-Mine support**: Landmine damage is now correctly attributed to Bot-O-Mine via a landmine extension
- **Bonk Dog support**: Explosion and melee damage from Bonk Dog is now tracked and displayed
- **Ungroup Weapons toggle**: New option to display each weapon individually instead of grouping by tier
- Improved handling of array-based damage tracking
- Removed workaround code in favor of clean landmine extension approach

### DamageMeter v1.2.0

- Full ModOptions integration
- Live configuration updates
- Improved performance

### QuickEquip v1.1.0

- Renamed from AutoGive
- Added translation support
- Smart tier selection
- Icon-based UI

---

**Enjoy the mods! Happy farming! 🥔**
