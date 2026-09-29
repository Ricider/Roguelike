# Roguelike - Cross-Platform Godot 4

Turn-based dungeon roguelike that runs on Windows / macOS / Linux / Web / Android / iOS from one Godot 4 codebase.

## Open in Godot
1. Open Godot 4.4+ (you installed 4.7.1 - perfect)
2. Import -> Browse -> select `/Users/sarahangeli/roguelike/project.godot`
3. Press ▶ Play (or F5)

> Tests: `godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit` (works with Godot 4.7.1 on this Mac now).

## Controls (all platforms)
- **Keyboard**: Arrow keys / WASD to move, Space / . to wait a turn, R to restart
- **Gamepad**: D-Pad / Left Stick to move, any face button to wait
- **Touch / Mouse**: Tap a neighboring tile to move there, tap player to wait. On-screen D-pad (bottom right) also works on mobile/web

## World Map campaign (hex war)
- **This is the main mode:** Main menu -> **New Game** opens the map chooser: **World**, **Europe**, **Byzantium** or **East Asia**. Every map has all 8 nations starting from real cities; only the world map wraps east-west. **Resume** continues a saved campaign on its own map.
- **Terrain:** non-flying units standing on mountain hexes take 1 less damage from every hit (minimum 1).
- The map is Earth on a 90x40 hex grid generated from real coastlines (pointy-top hexes, odd rows offset half a hex; every hex has 6 neighbors, and the map wraps east-west at the Bering Strait). Capitals sit at their real locations. Pick your nation in the chooser first.
- Maps are data files (`Assets/Maps/<id>.json`). Regenerate them with `python3 tools/make_world.py` (or `... make_world.py europe` for one map); each map's bounds, grid size and faction-to-city assignments are set in the `MAPS` table there. It uses Natural Earth's public-domain 1:110m land polygons, cached in `tools/data/`, samples 7 points per hex so thin islands survive, assigns terrain from climate and mountain boxes, and bridges narrow straits (Dover, Korea, Indonesia) so every capital is reachable. Far islands such as New Zealand and Antarctica stay unclaimed wilderness. Saves made on an older map layout restart the campaign.
- **The map is the battlefield.** Turns go one nation at a time: you first, then every AI nation. On its turn a nation collects income (Money/Bio from its buildings on the map), draws back up to 10 cards, deploys cards onto its own empty hexes, and then every one of its units fires.
- **Targeting:** every enemy card is a target, and so is every enemy nation's **capital flag**. Damage to a flag goes straight to that nation's HP, and each flag shows an HP bar. Units without Range hit the closest target anywhere on the map (hex distance). Units with Range find the closest enemy nation and hit a random one of its targets (any of its cards or its flag).
- Card rules carry over from battles: Rocket Launcher/Howitzer fire 4 times, Special Ops x2 vs ground, Anti Aircraft x3 vs flying, Flying takes half from non-ranged, Barracks give +2 to adjacent units, Interceptors halve ranged/flying hits on neighbors, Fighter Jets splash.
- A destroyed card costs its owner HP equal to its BioCost. **A nation at 0 HP cedes border hexes** (1 per 10 HP the victor has left; **x2 if it fields fewer than 3 units, x4 if it has no units on the map**, which the nation list marks with a red "2x"/"4x") to whoever damaged it most, loses the cards on those hexes, then rebuilds to full HP. Conquest takes hexes ring by ring outward from the old border, so fronts advance evenly instead of thin wedges driving inland. Hold every claimed hex to win; lose your last hex and you're out.
- **Flags:** each flag keeps a hex to itself (no cards on it). When a nation loses its flag hex, the flag falls back to the free hex nearest the center of its remaining land.
- Starting territories never cross continents: the Americas belong to Peace Keepers, who meet Asia only at the Bering land bridge.
- **Influence and Shop:** every hex a nation takes in a collapse earns it **5 Influence**. Yours is shown by the counter next to the pixel HP/Bio/Money gauges (each gauge shows next turn's income). **Every nation has its own shop**, restocked at the start of its turn. Its 5 card slots are drawn with odds matching that nation's starting deck (10 Infantry + 5 Tanks means each slot is Infantry 2/3 and Tank 1/3 of the time), plus 3 random modifiers it doesn't own yet. Your **Shop** button shows the odds, sells cards and modifiers for Influence, and removes one card from your deck for 25 per turn; bought cards are drawn next. **AI nations shop too**, before deploying: a random affordable modifier, then the priciest cards they can afford. The battle log lists what they buy.
- **Hover help:** hover a card in your hand, a shop card or any card on the map to see its description card (art, HP/damage or income, costs, special effect) with [Flying]/[Grounded] and [HasRange]/[Melee] trait boxes. Map cards also show their owner, Barracks and mountain bonuses, and their **next shot**, with a dashed arrow to the target. Flags, gauges, Influence and the Shop button have tooltips too.
- Controls: click a card in the hand bar, then a glowing hex (Esc cancels). Space or End Turn ends your turn. Speed toggles 1x/2x/4x for the AI turns. Hover any hex for its owner, card, HP and damage.
- Camera: the map opens zoomed in on your capital. Scroll wheel or trackpad pinch zooms (1x-4x), dragging pans (it wraps east-west like a globe), arrows/WASD pan, +/- zoom, and H or the Home button returns to your capital.
- Rules live in `Classes/GameBoard/MapWar.gd` (covered by `tests/unit/test_map_war.gd`). Saves include every card on the map, nation HP/Bio/Money and the turn.

## Card battles on the 4x10 grid (legacy)
The original card-battle run and its tutorial are no longer on the main menu. The code (`scenes/Game.tscn`, `GodotHelpers/GameController.gd`) stays in the project, so older saves of that mode still resume, and the world war reuses its cards, decks, modifiers and shop rules.

## Project Structure
```
project.godot          - input map for keyboard+gamepad+touch, gl_compatibility renderer (widest support)
icon.svg               - app icon
scenes/Main.tscn       - main scene: Node2D + CanvasLayer UI + touch D-pad
scripts/main.gd        - grid, turn logic, enemy AI, drawing (no external assets - draws with draw_rect/draw_circle)
scripts/dungeon_generator.gd - random rooms + L-corridors, cross-platform RNG
export_presets.cfg     - one-click exports for Windows/macOS/Linux/Web
```

## Cross-Platform Builds
In Godot: Project -> Export
- **Windows**: `build/roguelike.exe` (x86_64)
- **macOS**: `build/roguelike.zip` (universal)
- **Linux**: `build/roguelike.x86_64`
- **Web**: `build/web/index.html` (run with `godot --headless --export-release Web` or via editor; host on itch.io / GitHub Pages)

Renderer is `gl_compatibility` so it runs on low-end mobile and web without Vulkan.

## Art (8-bit pixel art)
All sprites are generated by `tools/retro_overhaul.py` (stdlib-only Python). It covers cards (20-frame idle + attack), projectiles, effects, piles, modifiers, faction flags and backdrops, UI icons, gauges and board tiles. To regenerate everything, or only some groups:
```
python3 tools/retro_overhaul.py               # everything
python3 tools/retro_overhaul.py cards kit     # groups: cards projectiles effects piles modifiers players ui kit
```
The generator's `kit` group also writes the pixel UI kit (9-slice buttons, panels) and `Assets/UI/retro_theme.tres`, which is the project-wide theme. That theme uses Pixelify Sans for UI text and Press Start 2P for titles (`Assets/Fonts`, both SIL OFL, licenses included). Controls choose a style with `theme_type_variation`: `PrimaryButton`, `DangerButton`, `SelectedButton`, `GoldPanel` or `TitleLabel`.

World-map terrain tiles are pixel art drawn at runtime by `scripts/tile_art.gd`. `tools/bw_overhaul.py` is the previous art generator; running it would overwrite the current art.

Screenshot helper for checking UI changes without clicking through the game:
```
godot --path . -s tools/dev/screenshot.gd -- res://scenes/Game.tscn /tmp/shot.png 160 battle_select
```

## Sound & music
All audio is 8-bit chiptune synthesized by `tools/chiptune.py` (stdlib-only Python emulating 2 pulse channels, a triangle and a noise channel). It writes about 24 sound effects to `Assets/Audio/sfx/` and three looping tracks (menu, world map, battle) to `Assets/Audio/music/`:
```
python3 tools/chiptune.py          # everything
python3 tools/chiptune.py sfx      # or: music
```
`GodotHelpers/SoundManager.gd` (autoload) plays them. It crossfades music between scenes, gives every text button a click and hover sound, and each weapon has its own firing sound. **M** or the **Sound: On/Off** button mutes, and the setting is saved in `user://audio.cfg`.

## Tweaking
- `scripts/main.gd` top constants: `GRID_WIDTH`, `GRID_HEIGHT`, `TILE_SIZE`, `NUM_ROOMS`, `NUM_ENEMIES`
- `scripts/dungeon_generator.gd`: `generate(num_rooms, min_size, max_size)`

## Next Steps
- Add items/inventory, fog-of-war, stairs, save system
- Replace `draw_rect` tiles with TileMap + spritesheet
- Add Android/iOS export presets (requires export templates)
