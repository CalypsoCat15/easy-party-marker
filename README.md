# Easy Party Marker

A customizable map-marker addon for **World of Warcraft Classic Era**, designed by [CalypsoCat15](https://github.com/CalypsoCat15).

Easy Party Marker makes party members and your own position much easier to spot on both the minimap and the large world map. Its signature defaults are a vivid pink party marker and a mint/seafoam directional player arrow.

Version 2.1 is completely standalone: **Questie is no longer required.** Version 2.1.1 also updates the large-map player arrow through Classic Era's current native player-pin API.

## Features

- Bright party markers on the minimap and large map
- A clear directional player arrow on both maps
- Eight color choices: mint, pink, cyan, lime, yellow, orange, purple, and white
- Adjustable party-marker and player-arrow sizes
- A draggable mint button around the minimap
- Live customization menu; changes appear immediately
- One-click **Lisa's Defaults** reset
- North-up minimap behavior (map rotation is intentionally disabled for now)
- A bundled map-position helper, so no other addon is required

## Requirements

- World of Warcraft Classic Era
- No required addons

## Install

1. Download `EasyPartyMarker-v2.1.1.zip` from the [latest release](https://github.com/CalypsoCat15/easy-party-marker/releases/latest).
2. Completely exit World of Warcraft.
3. Open the ZIP and copy the entire `EasyPartyMarker` folder into:

   `C:\Program Files (x86)\World of Warcraft\_classic_era_\Interface\AddOns`

4. Start WoW Classic Era.
5. On the character-selection screen, click **AddOns**.
6. Make sure **Easy Party Marker** is checked.

## Customize

- Click the mint arrow button around the minimap to open or close the menu.
- Drag the button around the minimap edge to move it.
- Use the sliders to resize party markers or your player arrow.
- Click any color circle to apply it immediately.
- Click **Lisa's Defaults** to restore pink party markers and the mint arrow.
- You can also type `/epm` to open or close the menu.

## Default look

- Party marker: pink, size 10
- Player arrow: mint/seafoam, medium size
- Minimap button: right side of the minimap

## Privacy

This repository contains only addon code and marker textures. It does not contain character names, account information, saved settings, screenshots, or other personal game data.

## Bundled library

Easy Party Marker embeds [HereBeDragons 2.16](https://github.com/Nevcairiel/HereBeDragons/tree/2.16-release) for map-coordinate handling. See `THIRD_PARTY_NOTICES.txt` for attribution and license information.
