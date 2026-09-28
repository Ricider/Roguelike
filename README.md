# Roguelike - Cross-Platform Godot 4

Turn-based dungeon roguelike that runs on Windows / macOS / Linux / Web / Android / iOS from one Godot 4 codebase.

## Open in Godot
1. Open Godot 4.4+ (you installed 4.7.1 - perfect)
2. Import -> Browse -> select `/Users/sarahangeli/roguelike/project.godot`
3. Press ▶ Play (or F5)

> Note: `godot --headless` currently crashes on this Mac (MoltenVK/SPIRV signal 11) - this is a Godot 4.7 headless bug, not a project bug. Running via the Editor works fine.

## Controls (all platforms)
- **Keyboard**: Arrow keys / WASD to move, Space / . to wait a turn, R to restart
- **Gamepad**: D-Pad / Left Stick to move, any face button to wait
- **Touch / Mouse**: Tap a neighboring tile to move there, tap player to wait. On-screen D-pad (bottom right) also works on mobile/web

## World Map campaign (Civ-style)
- Main menu -> **World Map**: Earth on a 60x30 square grid (ocean, grassland, desert, mountain, snow, jungle). Pick your nation in the chooser first.
- Every nation starts with connected territory around its capital (Antarctica/NZ are unclaimed wilderness; the map wraps east-west at the Bering Strait).
- Tap a tile to inspect it. You can only declare war on **neighbors** (shared border).
- Each war is one normal card battle, then a shop, then back to the map. Winner takes **1 tile per 10 HP left** (min 1) from the shared border; the loser stays connected when possible, so no border gore. Lose and you cede land but your army rebuilds.
- Win by conquering all claimed land; lose if you hold nothing. Sequential runs via New Game still work as before.
- Tiles use generated art per terrain (4 variants each, no asset files); nation borders draw in each nation's color.
- Save from the map (Save Campaign) or mid-battle; Resume returns to the map between wars or straight back into an ongoing battle. Flags move to stay inside friendly borders if a capital tile falls.

## How to Play
- Red `@` is you. Blue squares are enemies (3 HP).
- Bump into enemy to attack (2 damage). Enemies hit back when adjacent (1 damage, 10 HP total).
- Walls are dark, floors are light checker.
- Defeat all 6 enemies to win. Die at 0 HP.

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

## Tweaking
- `scripts/main.gd` top constants: `GRID_WIDTH`, `GRID_HEIGHT`, `TILE_SIZE`, `NUM_ROOMS`, `NUM_ENEMIES`
- `scripts/dungeon_generator.gd`: `generate(num_rooms, min_size, max_size)`

## Next Steps
- Add items/inventory, fog-of-war, stairs, save system
- Replace `draw_rect` tiles with TileMap + spritesheet
- Add Android/iOS export presets (requires export templates)
