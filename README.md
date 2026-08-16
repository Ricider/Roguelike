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
