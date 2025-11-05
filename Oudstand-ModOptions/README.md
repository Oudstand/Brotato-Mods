# ModOptions for Brotato

A powerful and flexible configuration framework for Brotato mods. ModOptions provides an easy-to-use API for mod developers to add in-game configuration interfaces, and a unified "Mods" tab in the Options menu where players can configure all their mods in one place.

## Features

### For Players
- **Unified Interface**: All mod configurations in one convenient "Mods" tab in Options
- **Live Updates**: Most configuration changes apply immediately without restarting
- **Persistent Settings**: All settings are automatically saved and restored
- **User-Friendly**: Clean, consistent interface for all mod settings

### For Mod Developers
- **Simple API**: Register your mod's options with just a few lines of code
- **Rich Option Types**: Sliders, toggles, dropdowns, text inputs, and custom item selectors
- **Zero Boilerplate**: No UI code needed - just define your options
- **Automatic Persistence**: Settings are saved and loaded automatically
- **Change Notifications**: Get callbacks when settings change
- **Translation Support**: Full internationalization support

## Installation

Install via Steam Workshop or download from the repository.

## Screenshots

![ModOptions Interface](screenshots/modoptions_ui_damage_meter.png)
*Unified "Mods" tab showing configuration options for Damage Meter mod*

![ModOptions Interface](screenshots/modoptions_ui_quick_equip.png)
*Unified "Mods" tab showing configuration options for Quick Equip mod*

## For Mod Developers

### Quick Start

1. Add `Oudstand-ModOptions` as a dependency in your `manifest.json`:
```json
{
  "name": "YourMod",
  "namespace": "YourName",
  "version_number": "1.0.0",
  "dependencies": ["Oudstand-ModOptions"]
}
```

2. Register your options in your mod's `_ready()` function:
```gdscript
func _ready():
    var ModOptionsAPI = get_node("/root/ModLoader/Oudstand-ModOptions/ModOptionsAPI")

    if ModOptionsAPI:
        ModOptionsAPI.register_mod_options("YourModID", {
            "tab_title": "Your Mod Name",
            "options": [
                {
                    "type": "slider",
                    "id": "damage_multiplier",
                    "label": "Damage Multiplier",
                    "min": 0.5,
                    "max": 2.0,
                    "step": 0.1,
                    "default": 1.0
                },
                {
                    "type": "toggle",
                    "id": "enable_feature",
                    "label": "Enable Special Feature",
                    "default": true
                }
            ],
            "info_text": "Configure your mod settings here."
        })
```

3. Access your settings:
```gdscript
# Get a value
var damage = ModOptionsAPI.get_value("YourModID", "damage_multiplier")

# Listen for changes
ModOptionsAPI.config_manager.connect("config_changed", self, "_on_config_changed")

func _on_config_changed(mod_id: String, option_id: String, new_value):
    if mod_id == "YourModID" and option_id == "damage_multiplier":
        print("Damage multiplier changed to: ", new_value)
```

### Supported Option Types

#### Slider
```gdscript
{
    "type": "slider",
    "id": "opacity",
    "label": "Opacity",
    "min": 0.0,
    "max": 1.0,
    "step": 0.1,
    "default": 0.8,
    "display_as_integer": false  # Optional: show as integer instead of float
}
```

#### Toggle (Checkbox)
```gdscript
{
    "type": "toggle",
    "id": "enabled",
    "label": "Enable Mod",
    "default": true
}
```

#### Dropdown
```gdscript
{
    "type": "dropdown",
    "id": "difficulty",
    "label": "Difficulty",
    "choices": ["Easy", "Normal", "Hard"],
    "default": "Normal"
}
```

#### Text Input
```gdscript
{
    "type": "text",
    "id": "player_name",
    "label": "Player Name",
    "default": "Anonymous",
    "multiline": false,  # Optional: use TextEdit instead of LineEdit
    "min_height": 100,   # Optional: minimum height for multiline
    "help_text": "Enter your name"  # Optional: help text below input
}
```

#### Item Selector (Advanced)
```gdscript
{
    "type": "item_selector",
    "id": "weapons_list",
    "label": "Weapons",
    "default": [],
    "item_type": "weapon",  # or "item"
    "help_text": "Select weapons from the dropdown"
}
```

### API Reference

#### Registration
```gdscript
ModOptionsAPI.register_mod_options(mod_id: String, config: Dictionary)
```
- `mod_id`: Unique identifier for your mod
- `config`: Configuration dictionary with `tab_title`, `options`, and optional `info_text`

#### Getting Values
```gdscript
ModOptionsAPI.get_value(mod_id: String, option_id: String) -> Variant
```
Returns the current value of an option, or its default if not set.

#### Setting Values
```gdscript
ModOptionsAPI.set_value(mod_id: String, option_id: String, value: Variant)
```
Updates an option value and emits `config_changed` signal.

#### Signals
```gdscript
config_manager.connect("config_changed", target, method)
```
Called when any option value changes:
- `mod_id: String` - The mod identifier
- `option_id: String` - The option identifier
- `new_value: Variant` - The new value

### Translation Support

ModOptions fully supports translations. Use translation keys in your labels and help text:

```gdscript
{
    "type": "toggle",
    "id": "enabled",
    "label": "YOURMOD_ENABLE_LABEL",
    "default": true
}
```

Then add your translations using `ModLoaderMod.add_translation()` in your mod's `_init()` function.

## Examples

See these mods for real-world examples:
- **DamageMeter** - Uses sliders and toggles for display configuration
- **QuickEquip** - Uses the advanced item_selector type for weapon/item selection

## Compatibility

- **Mod Loader Version**: 6.2.0+
- **Game Version**: 1.1.12.0+

## Credits

Created by Oudstand

## License

This mod is provided as-is for the Brotato community. Feel free to modify and share.

## Support

For bugs or feature requests, please create an issue on the project repository.

## Changelog

### v1.0.0
- Initial release
- Unified "Mods" tab for all mod configurations
- Support for slider, toggle, dropdown, text, and item_selector option types
- API-based registration system
- Automatic config persistence
- Live config updates
- Translation support
- Integer display mode for sliders
