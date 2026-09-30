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
- **This is the main mode:** Main menu -> **New Game** opens the map chooser: **World**, **Europe**, **Byzantium**, **East Asia**, **North America**, **British Isles**, **Bering Strait** or **Balkans**. Every map has all 8 nations starting from real cities; only the world map wraps east-west. **Resume** continues a saved campaign on its own map.
- **Terrain:** non-flying units standing on mountain hexes take 1 less damage from every hit. Any unit in a forest (jungle hex) takes 1 less damage from flying attackers. Neither can bring a hit below 1 damage. Buildings, walls included, can't be placed on mountains; mountain hexes don't glow when a building is selected, and the AI skips them too.
- The map is Earth on a 90x40 hex grid generated from real coastlines (pointy-top hexes, odd rows offset half a hex; every hex has 6 neighbors, and the map wraps east-west at the Bering Strait). Capitals sit at their real locations. Pick your nation in the chooser first.
- Maps are data files (`Assets/Maps/<id>.json`). Regenerate them with `python3 tools/make_world.py` (or `... make_world.py europe` for one map); each map's bounds, grid size and faction-to-city assignments are set in the `MAPS` table there. It uses Natural Earth's public-domain 1:110m land polygons, cached in `tools/data/`, samples 7 points per hex so thin islands survive, assigns terrain from climate and mountain boxes, and bridges narrow straits (Dover, Korea, Indonesia) so every capital is reachable. A map can add its own `mountains`/`deserts`/`forests` boxes, replace the shared regional ranges with `regional_mountains` (the Balkans follow their real ranges this way), and move the snow line with `snow_lat` (the Bering Strait uses the Arctic Circle). Longitudes may run past 180 so a map can straddle the date line. Far islands such as New Zealand and Antarctica stay unclaimed wilderness. Saves made on an older map layout restart the campaign.
- **The map is the battlefield.** Turns go one nation at a time: you first, then every AI nation. On its turn a nation collects income (Money/Bio from its buildings on the map), draws back up to 10 cards, deploys cards onto its own empty hexes, and then every one of its units fires.
- **Targeting:** every enemy card is a target, and so is every enemy nation's **capital flag**. Damage to a flag goes straight to that nation's HP, and each flag shows an HP bar. Units without Range hit the closest target anywhere on the map (hex distance). Units with Range find the closest enemy nation and hit a random one of its targets (any of its cards or its flag).
- Card rules carry over from battles: Rocket Launcher/Howitzer fire 4 times, Special Ops x2 vs ground, Anti Aircraft x3 vs flying, Flying takes half from non-ranged, Barracks give +2 to adjacent units, Interceptors halve ranged/flying hits on neighbors, Fighter Jets splash.
- A destroyed card costs its owner HP equal to its BioCost. **A nation at 0 HP cedes border hexes** (1 per 10 HP the victor has left; **x2 if it fields fewer than 3 units, x4 if it has no units on the map**, which the nation list marks with a red "2x"/"4x") to whoever damaged it most, loses the cards on those hexes, then rebuilds to full HP. This happens the moment its HP hits 0, even in the middle of an enemy attack: its flag re-forms at full HP on its new hex, so later shots in that attack never pound a flag that is already down. Conquest takes hexes ring by ring outward from the old border, so fronts advance evenly instead of thin wedges driving inland. A winner that doesn't border the loser (overseas) lands on the loser's hexes nearest its own land across the sea, then spreads out from that beachhead. Hold every claimed hex to win; lose your last hex and you're out.
- **Flags:** each flag keeps a hex to itself (no cards on it). When a nation loses its flag hex, the flag falls back to the free hex nearest the center of its remaining land.
- **Starting territories:** Corporate Troops hold North America (capital San Francisco). Peace Keepers hold South America (Rio de Janeiro) and Australia (a second base at Sydney). Horde holds Russia and East China (a second base at Beijing), including Korea and Japan. Fundamentalists sit in West Africa (Timbuktu), and Coalition Army holds all of Europe. They are set by lat/lon claim boxes plus extra seed cities in the `MAPS` table of `tools/make_world.py`. Unclaimed land goes to the nearest nation without crossing between the Americas and the rest of the world. Corporate Troops meet Horde at the Bering land bridge. A Sulawesi-New Guinea bridge makes Australia reachable over land.
- **Modifiers apply immediately:** a bought modifier (yours or an AI's) changes max HP on every card that nation already has on the map, buildings included. Current HP moves by the same amount, and floating numbers show the change. A unit never drops below 1 HP from a modifier. The player card's **Modifiers** row shows an animated badge for each modifier you own (hover it to see its effect), and hovering a nation in the list or its flag on the map lists its modifiers. The nations list is sorted by hex count (most first); eliminated nations drop to the bottom.
- **Influence and Shop:** every hex a nation takes in a collapse earns it **5 Influence**. Yours is shown by the counter next to the pixel HP/Bio/Money gauges (each gauge shows next turn's income). **Every nation has its own shop**, restocked at the start of its turn. Its 5 card slots are drawn with odds matching that nation's starting deck (10 Infantry + 5 Tanks means each slot is Infantry 2/3 and Tank 1/3 of the time), plus 3 random modifiers it doesn't own yet. Modifiers cost 4x their listed base price (`Modifier.PRICE_MULT`), for example Conscription 140 and Advanced Robotics 240. Your **Shop** button shows the odds, sells cards and modifiers for Influence, and removes one card from your deck for 25 per turn; bought cards are drawn next. **AI nations shop too**, before deploying: a random affordable modifier, then the priciest cards they can afford. The battle log lists what they buy.
- **Support effects on the map:** a Barracks sends golden hex ripples over the ring it covers, and units there get a spinning gold ring and chevrons; when they fire, a golden burst shows the +2. Cards covered by an Interceptor wear a cyan hex shield. When a hit is halved, the Interceptor launches a counter-missile and a honeycomb shield flashes over the target.
- **Marching to the front:** a nation's whole attack is resolved first, so each unit's real targets are known: random picks, and new targets chosen after an earlier shot killed the old one. The screen then replays it. All units march out together, hex by hex, toward their actual target; a unit firing several shots (Rocket Launcher) heads for the one most central to all of its targets. HP bars and flags stay at their pre-attack values until each shot lands, and cards that are about to die stay on the map until the shot that kills them. When a shot brings a nation down mid-attack, the replay splits into waves. Units firing after the collapse only set off once the flag has visibly re-formed, and they march to its new spot. Ground units walk over their own land, cross open sea in a small boat in their nation's colour, and cross the border into the land of the nation they attack, but never through a third nation's land. Flying units fly straight. Melee units stop on the free hex closest to their target, right beside it when they can reach. Ranged units stop no closer than 3 hexes (`RANGED_GAP`). A walk only ends on a hex no card or flag stands on and no other walker is heading to, so units never overlap; a unit with no better free hex stays put. Each unit fires from where it stopped, then they all walk back. A march takes at most about 1 second each way at 1x; longer routes step faster. It is visual only: the cards never leave their hexes (`walk_out`/`walk_back`/`at_sea` in `scripts/world_map_view.gd`, `_walk_path`, `WALK_STEP`, `WALK_MAX` and `RANGED_GAP` in `scripts/world_map.gd`).
- **Round report:** at the start of each of your turns after the first, a report shows what every nation did to every other last round (your attack plus every AI turn). It covers:
    - damage **dealt**, how much of it went into **flags**, and **kills** (with the HP each kill cost its owner)
    - damage **added** by Barracks, modifiers (negative for Defensive Doctrine), unit bonuses (Special Ops x2 against ground, Anti Aircraft x3 against flying) and Fighter Jet splash
    - damage **blocked** by Interceptors, mountains, forests and flying units dodging melee

  It opens on **Your fights** (your attacks, then attacks on you) with an **All nations** tab, and a summary line of damage dealt, taken and stopped. The **Round report** button next to the battle log reopens it; Esc or Close shuts it. The numbers come from `MapWar.round_stats`, and hovering a column header explains it.
- **Minimap:** the map's bottom-left corner shows the whole map with every nation's territory, flags, card positions, and a gold frame around what the main view shows. Click or drag on it to move the camera (`scripts/minimap.gd`).
- **Nation art:** every nation fields its own version of every card, drawn from the shared pixel art with its own colours, headgear, camo and emblem:
    - State Troops: olive drab, gold star, steel helmets
    - Insurgents: desert sand with rust patches, orange sun, chequered shemaghs
    - Fundamentalists: slate-green splinter camo, purple flame, dark headwraps
    - Mercenaries: black tiger stripes, skull, red berets and shades
    - Peace Keepers: white with UN-blue helmets and wreath
    - Horde: riveted rust-maroon iron, claw marks, fur hats
    - Coalition Army: blue-grey digital camo, green cross, goggles
    - Corporate Troops: glossy violet, teal neon coin and visors

  Buildings change brick, glass and roof colours and fly the nation's colour on the barracks flag. The map, hover cards, your hand and the shop all use the owner's art. Frames live in `Assets/Cards/<card>/nations/<nation>/` (256px idle frames); regenerate them with `python3 tools/retro_overhaul.py nations`, which also writes a contact sheet to `build/previews/nations.png`. The legacy card-battle screens keep the shared art.
- **Rendering:** the terrain is a single GPU mesh built once per map: the ocean has one mesh per wave phase, and the land mesh is rebuilt only when borders or the selection change. Panning and zooming just move and scale it. Grid lines and borders are precomputed line lists, and the minimap redraws only when the camera or the cards change. To measure frame times, run `godot --path . --resolution 1600x900 -s tools/dev/profile.gd`, optionally with `PROF_MAP=<id>` for another map.
- **Hover help:** hover a card in your hand, a shop card or any card on the map to see its description card (art, HP/damage or income, costs, special effect) with [Flying]/[Grounded] and [HasRange]/[Melee] trait boxes. Map cards also show their owner, Barracks, mountain and forest bonuses, and their **next shot**, with a dashed arrow to the target. Flags, gauges, Influence and the Shop button have tooltips too.
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
Stretch mode is `canvas_items`, so text and UI are drawn at the window's real resolution (sharp on Retina and scaled windows). Both fonts are switched to MSDF rendering at startup (`GameState._ready`, since `.import` files are gitignored), and the Press Start 2P titles are only used at multiples of its 8px grid.

## Art (8-bit pixel art)
All sprites are generated by `tools/retro_overhaul.py` (stdlib-only Python). It covers cards (20-frame idle + attack), projectiles, effects, piles, modifiers, faction flags and backdrops, UI icons, gauges and board tiles. To regenerate everything, or only some groups:
```
python3 tools/retro_overhaul.py               # everything
python3 tools/retro_overhaul.py cards kit     # groups: cards projectiles effects piles modifiers players ui kit nations
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
