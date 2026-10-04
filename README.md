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
- **Targeting:** every enemy card is a target, and so is every enemy nation's **capital flag**. Damage to a flag goes straight to that nation's HP, and each flag shows an HP bar. Units without Range hit the closest target **within 4 hexes** (hex distance). Units with Range reach **8 hexes**: they find the closest enemy nation within reach and hit a random one of its targets there (any of its cards or its flag). A unit with nothing in range doesn't fire, and its hover card says so (`MELEE_RANGE`/`RANGED_RANGE`, `MapWar.attack_range`).
- Card rules carry over from battles: Rocket Launcher/Howitzer fire 4 times, Special Ops x2 vs ground, Anti Aircraft x3 vs flying, Flying takes half from non-ranged, Barracks give +2 to adjacent units, units firing from their own nation's land deal +1 per shot (home ground: not from enemy land, unclaimed land or the sea; `HOME_BONUS`), **flanked units take more from every hit** (see Flanking below), Interceptors halve ranged/flying hits on neighbors, Fighter Jets splash, and each Corporation on the map cuts the Money cost of your cards by 20% (they stack). Every card's description (its `SpecialEffect`, shown on hover cards with [terms] highlighted) explains what it does on the map.
- A destroyed card costs its owner HP equal to its BioCost. **A nation at 0 HP cedes border hexes** (1 per 10 HP the victor has left; **x2 if it fields fewer than 3 units, x4 if it has no units on the map**, which the nation list marks with a red "2x"/"4x") to whoever damaged it most, loses the cards on those hexes, then rebuilds to full HP. This happens the moment its HP hits 0, even in the middle of an enemy attack: its flag re-forms at full HP on its new hex, so later shots in that attack never pound a flag that is already down. Conquest takes hexes ring by ring outward from the old border, so fronts advance evenly instead of thin wedges driving inland. A winner that doesn't border the loser (overseas) lands on the loser's hexes nearest its own land across the sea, then spreads out from that beachhead. Hold every claimed hex to win; lose your last hex and you're out.
- **Flags:** each flag keeps a hex to itself (no cards on it). When a nation loses its flag hex, the flag falls back to the free hex nearest the center of its remaining land.
- **Starting territories:** Corporate Troops hold North America (capital San Francisco). Peace Keepers hold South America (Rio de Janeiro) and Australia (a second base at Sydney). Horde holds Russia and East China (a second base at Beijing), including Korea and Japan. Fundamentalists sit in West Africa (Timbuktu), and Coalition Army holds all of Europe. They are set by lat/lon claim boxes plus extra seed cities in the `MAPS` table of `tools/make_world.py`. Unclaimed land goes to the nearest nation without crossing between the Americas and the rest of the world. Corporate Troops meet Horde at the Bering land bridge. A Sulawesi-New Guinea bridge makes Australia reachable over land.
- **Modifiers apply immediately:** a bought modifier (yours or an AI's) changes max HP on every card that nation already has on the map, buildings included. Current HP moves by the same amount, and floating numbers show the change. A unit never drops below 1 HP from a modifier. The player card's **Modifiers** row shows an animated badge for each modifier you own (hover it to see its effect), and hovering a nation in the list or its flag on the map lists its modifiers. The nations list is sorted by hex count (most first); eliminated nations drop to the bottom.
- **Influence and Shop:** every hex a nation takes in a collapse earns it **5 Influence**. Yours is shown by the counter next to the pixel HP/Bio/Money gauges (each gauge shows next turn's income). **Every nation has its own shop**, restocked at the start of its turn. Its 5 card slots are drawn with odds matching that nation's starting deck (10 Infantry + 5 Tanks means each slot is Infantry 2/3 and Tank 1/3 of the time), plus 3 random modifiers it doesn't own yet. Modifiers cost 4x their listed base price (`Modifier.PRICE_MULT`), for example Conscription 140 and Advanced Robotics 240. Your **Shop** button shows the odds, sells cards and modifiers for Influence, and removes one card from your deck for 25 per turn; bought cards are drawn next. **AI nations shop too**, before deploying: a random affordable modifier, then the priciest cards they can afford. The battle log lists what they buy.
- **Support effects on the map:** a Barracks sends golden hex ripples over the ring it covers, and units there get a spinning gold ring and chevrons; when they fire, a golden burst shows the +2. Cards covered by an Interceptor wear a cyan hex shield. When a hit is halved, the Interceptor launches a counter-missile and a honeycomb shield flashes over the target.
- **Flanking:** a unit hemmed in by enemy units takes extra damage from every hit; only the highest tier applies. Enemy units of any other nation count (buildings and flags don't), and buildings never take the penalty. Red arrows point in at a flanked unit (2, 4 or 6 of them), its hover card names the tier, and the round report has a +Flanked column. The AI avoids stepping into a pincer (`MapWar.flank_at`, `FLANK_*`).

  | Tier | Enemy units next to it | Extra damage per hit |
  |---|---|---|
  | Flanked | on two opposite sides | +1 |
  | Surrounded | 4 or 5 of its 6 neighbours | +2 |
  | Encircled | all 6 neighbours | +4 |

- **Deploy zones:** buildings go anywhere on your own land, but a unit must be summoned within 2 hexes (`DEPLOY_RADIUS`) of your flag or of one of your standing buildings that raises it:

  | Unit | Deploy within 2 hexes of your flag or... |
  |---|---|
  | People: BioCost ≥ MoneyCost (Infantry, Special Ops) | a Housing |
  | Flying machines: MoneyCost > BioCost (Drone, Fighter Jet) | a Corporation or a Factory |
  | Ground machines: MoneyCost > BioCost (Tank, Artilery, Howitzer, Rocket Launcher, Anti Aircraft) | a Factory or a Barracks |

  Picking a unit card tints the land where it can go in green, with a gold ring on each flag or building it can be raised from; a hex outside says why. A destroyed building stops counting. The AI follows the same rule and builds its economy first. Starting cards are laid out buildings first, and a starting unit with no room goes back into the deck. Story set pieces and reinforcements are placed by their chapter and ignore the zones (`MapWar.deploy_anchors`/`deploy_hexes`/`can_place`).
- **Moving units:** units can move each turn, across borders and over the sea. Click one of your units to light up the hexes it can reach, then click one to walk it there; moves left carry over within the turn, and Esc cancels.
  - **Bulk moves:** Shift+drag a box over your units (or Shift+click them one by one; Shift+click again drops one) to pick several, then click any hex. Each unit marches towards it as far as its moves allow: the ones already nearest go first and take the hexes closest to it, so the group fans out around the spot instead of queueing, and a unit that can't get any closer stays put. Hovering a hex previews the result (a dotted line to each unit's end hex). The group stays picked so you can march on; a plain click on another unit picks just that one, and Esc drops the selection (`MapWar.move_group`/`plan_group`).
  - **Range display:** a picked unit shows where it can shoot as a tinted zone with a thick rim and a white dashed stripe: red for melee (4 hexes), blue for ranged (8). Every enemy card or flag inside gets red corner brackets. While you hover a hex it could move to, the zone previews its range from there. A picked group shows the combined zones, previewed from where the bulk move would leave them (`range_zones`/`range_targets` in `scripts/world_map_view.gd`, `MapWar.hexes_within`/`targets_in_range`).

  | Unit | Hexes per turn |
  |---|---|
  | Flying | 6 |
  | Ranged (including range from modifiers) | 3 |
  | BioCost below MoneyCost (Tanks, AA...) | 4 |
  | Everything else (Infantry...) | 5 |

  The first rule that applies wins, so flying beats ranged. Units cross borders. They can stop on any free hex in play: their own land, another nation's land, unclaimed land, or the sea, where ground units ride a boat in their nation's colour. Boats are slow: boarding (a step from land onto the sea) costs 1 extra move, and a turn begun at sea refills 1 move fewer, so Infantry sail 4 hexes a turn, Tanks 3 and guns 2. A ground unit with only 1 move a turn couldn't board at all, and its attack marches would stay on land too; with the current speeds every unit has at least 3, so all of them can sail. Flying units ignore all of this. A unit stranded at sea with 1 move (say, one that gained Range from a modifier) still gets 1 move a turn to reach land (`SEA_PENALTY`, `MapWar.turn_allowance`/`can_sail`). They can't stop on a flag. Ground units may pass their own cards but not another nation's; flying units pass over anything. Standing on enemy land doesn't take it: hexes still change hands only when a nation collapses. When that happens, the loser keeps its units that are away from home (on enemy land or at sea) and loses only the cards on the hexes it cedes, unless it is wiped out. Sailing matters because of attack ranges: on the world map the Atlantic is about 16 hexes wide, so armies must cross the sea to reach a nation overseas. Buildings, Walls and flags never move, and a card deployed this turn moves from next turn. Hover a unit to see its moves. Each AI nation moves its units after deploying and before firing. Each unit picks the hex it can reach that scores best for being:
    - within its attack range of an enemy card or flag (otherwise, as close to the nearest one as it can get)
    - behind one of its own Walls (the wall between it and the nearest enemy)
    - beside its Barracks or Interceptors
    - not flanked there (a hex between enemy units scores worse, the more so the more of them)
    - close to badly wounded enemy cards

  The rules are in `MapWar.move_allowance` / `reachable` / `move` / `ai_move`.
- **Marching to the front:** a nation's whole attack is resolved first, so each unit's real targets are known: random picks, and new targets chosen after an earlier shot killed the old one. The screen then replays it. All units march out together, hex by hex, toward their actual target; a unit firing several shots (Rocket Launcher) heads for the one most central to all of its targets. HP bars and flags stay at their pre-attack values until each shot lands, and cards that are about to die stay on the map until the shot that kills them. When a shot brings a nation down mid-attack, the replay splits into waves. Units firing after the collapse only set off once the flag has visibly re-formed, and they march to its new spot. Ground units walk over their own land, cross open sea in a small boat in their nation's colour, and cross the border into the land of the nation they attack, but never through a third nation's land. Flying units fly straight. Melee units stop on the free hex closest to their target, right beside it when they can reach. Ranged units stop no closer than 3 hexes (`RANGED_GAP`). A walk only ends on a hex no card or flag stands on and no other walker is heading to, so units never overlap; a unit with no better free hex stays put. Each unit fires from where it stopped, then they all walk back. A march takes at most about 1 second each way at 1x; longer routes step faster. It is visual only: the cards never leave their hexes (`walk_out`/`walk_back`/`at_sea` in `scripts/world_map_view.gd`, `_walk_path`, `WALK_STEP`, `WALK_MAX` and `RANGED_GAP` in `scripts/world_map.gd`).
- **Campaigns (story mode):** **Campaign** on the main menu opens eight story campaigns, one per faction, that tell a single history between them. Each campaign covers a different part of it, and the **Chronicle** button lists every chapter of every campaign in order. Every chapter's war covers exactly the land its winner ends up with, so each victory is the version of events the other campaigns build on. For example, the Insurgents' first chapter is fought over exactly the land they hold when the State Troops' first chapter begins.

  | Act | Chapters, in order |
  |---|---|
  | I. Before the Storm | Corporate 1 (Mexico, vs Peace Keepers) · Horde 1 (East China, vs Peace Keepers) · Corporate 2 (Alaska, vs Horde) · Coalition 1 (Poland, vs Horde) · Corporate 3 (the Gulf Coast, vs their own Mercenaries) |
  | II. The Proxy Wars | Horde 2 (Central Asia, vs Insurgents) · Fundamentalists 1 (Iraq, vs Insurgents) · Fundamentalists 2 (the Levant, vs Peace Keepers) · Peace Keepers 1 (Indochina, vs Insurgents) · Fundamentalists 3 (Egypt, vs Mercenaries) · Mercenaries 1 (Libya, vs Peace Keepers) · Mercenaries 2 (the Maghreb, vs Coalition) · Coalition 2 (Italy, vs Mercenaries) · Coalition 3 (Britain, vs Corporate) · Insurgents 1 (Anatolia, vs State Troops) |
  | III. A State of Emergency | State 1 · State 2 · Mercenaries 3 (the Fezzan, vs Fundamentalist remnants) · Peace Keepers 2 (Sudan, vs Fundamentalist remnants) · State 3 · Horde 3 (Chukotka, vs Corporate) · State 4 |
  | IV. The World Against Us | Insurgents 2 (Britain, vs Coalition loyalists) · Insurgents 3 (northern France, vs State Troops) · Peace Keepers 3 (the Sahel, vs Mercenaries) · State 5 |

  Each campaign has an illustrated intro and outro for every chapter, a finale, and a defeat screen in its own colours. Chapters unlock one by one within a campaign, and progress is kept per campaign in `user://story.json`. The seven newer campaigns are in `scripts/story_campaigns.gd` (with `ACTS`), and their maps are `story_<campaign>_<n>.json`. Their pictures come from data in `COMPOSED` in `tools/story_art.py`. Two extra map frames cover them: the Central Asian steppe and the Sahel/Sudan.

  The State Troops campaign, *A State of Emergency*, has five chapters. Each chapter opens with an illustrated intro (typed-out text; a click, Space or Enter shows it all) and an objective. Winning plays an outro over the next chapter's illustration and unlocks the next chapter. Losing shows the fallen flag and offers a retry. Progress is kept in `user://story.json`, separate from the save slot.

  | Chapter | Map | The war |
  |---|---|---|
  | 1. Smoke Over Anatolia | Byzantium (Balkans and Anatolia only) | The Insurgents hold the south-eastern two thirds of Anatolia |
  | 2. Fire From the South | Byzantium | The State Troops hold the Balkans and Anatolia; the Fundamentalists hold the Levant, northern Arabia and Egypt (east of Libya) |
  | 3. The Puppet Masters | Europe & Mediterranean | Everything won so far, plus the Transcaucasus (Georgia, Armenia, Azerbaijan), so the State Troops meet the Horde (Russia) on land along the Caucasus ridge; the Horde's Mercenaries hold Libya |
  | 4. Appetite | Europe & Mediterranean | The State Troops add Libya and the Russian Caucasus and turn on the Coalition (the EU) |
  | 5. The World Against Us | World | Every conquest so far, against the Horde (Russia and East China), the Corporate Troops (North America), Insurgents in Britain and northern France, and Peace Keepers everywhere else |

  Every chapter of every campaign starts with its own forces on top of each nation's default starting cards, for both the player and the enemy. They are free, and random placements differ each play. After the tutorial, each chapter is built around an asymmetry between the two sides:
    - **Extra cards at the start**, placed by rule: near a city, along a border (or the middle of it), on mountains, in a lat/lon box, or beside an earlier placement. For example, State chapter 1 has 8 Insurgent Infantry dug in on mountains; State chapter 4 has Coalition Corporations at London, Berlin and Paris, each guarded by an Interceptor and a Fighter Jet.
    - **Reinforcements** that land at the start of their nation's turn in a given round (`turn` in a rule). Examples: a second Fundamentalist wave at Cairo on turn 3, Corporate jets on turn 4 and tanks on turn 6. Cards with no free hex to land on wait and try again the next turn, and reinforcements still on their way are kept in saves. The battle log announces each landing.
    - **Nation tweaks** (`setup`): a different max HP, starting Influence, Money or Bio. For example, brittle 80 HP zealots, an unpaid Mercenary army with 0 Money, or a State Troops empire with 250 HP in the final chapter. Values are absolute, and factions already start differently (State Troops 180 HP, Horde 200, Corporate Troops 70, and so on).
    - **A Forces briefing** on the map at the start of the chapter. It explains the matchup (what each side is good at, and how to exploit it) and lists every reinforcement on the way, with its turn, so nothing that lands later is a surprise.

  Themes include holding a line until the armour arrives, a Great Wall to fly over rather than shoot at, mountain guerrillas against siege guns, air power against flak that arrives on turn 3, an enemy economy that grows every turn you wait, and a cross-Channel war fought only by guns and wings.

  These are the `FORCES` table (`extras`, `setup`, `forces`) in `tools/make_story.py`, with State chapter 1's extras inline in `CHAPTERS`. They are applied by `MapWar.apply_setup`, `MapWar.place_extras` and `MapWar.arrive_reinforcements`.

  Chapter 1 doubles as the tutorial, with two briefings on the map that wait for a click:
    - **At the start:** the camera glides to the dug-in Insurgent Infantry. The briefing explains mountain cover (1 less damage per hit) and how targeting works, and suggests putting a Wall between the armies (it adapts to whether you hold a Wall).
    - **After the first End Turn:** a second briefing explains combat (marching and firing, HP and BioCost, flag hits, collapses and Influence) and wishes you luck.

  The text is the `briefing`/`combat_briefing` entries in `scripts/story_text.gd`, so any chapter can have them.

  An epilogue follows the last chapter. Everything outside a chapter's war is greyed out: it is never owned, entered or fought over. The Europe & Mediterranean map is the Europe map's scale, extended south to 24N and east to 52E so Libya, Egypt and the Caucasus fit (the Europe map itself stops at 34N). The chapter maps are `Assets/Maps/story_<n>.json`, made by `python3 tools/make_story.py`, which defines territories as lat/lon regions so conquests line up between maps. The illustrations are `Assets/Story/*.png`, from `python3 tools/story_art.py` (preview: `build/previews/story.png`). The words are in `scripts/story_text.gd`, and the screens in `scripts/story.gd` / `scenes/Story.tscn`. Story maps don't appear in New Game's map chooser.
- **Follow camera:** after you end your turn, the camera flies to each other nation in turn, framing its whole territory while it shops and deploys. Its attack then plays out one defender at a time, and so does yours. Before each fight, the camera glides to centre on the action, meaning where the shots land, and zooms in as close as it can while keeping the attackers in view, with about 1.5 hexes of margin. While following, it may look past the map's edges, so fights by a pole or a regional map's border still sit in the middle; your own pans and zooms keep the usual limits. On the world map it takes the short way round across the date line. When your turn comes back, the camera returns to where you left it. The **Follow** toggle in the map's top-right bar turns it off (`frame_for`/`glide_to` in `scripts/world_map_view.gd`, `CAM_GLIDE` in `scripts/world_map.gd`).
- **Round report:** at the start of each of your turns after the first, a report shows what every nation did to every other last round (your attack plus every AI turn). It covers:
    - damage **dealt**, how much of it went into **flags**, and **kills** (with the HP each kill cost its owner)
    - damage **added** by Barracks, home ground (+1 per shot fired from the attacker's own land), flanking (the target hemmed in by enemy units), modifiers (negative for Defensive Doctrine), unit bonuses (Special Ops x2 against ground, Anti Aircraft x3 against flying) and Fighter Jet splash
    - damage **blocked** by Interceptors, mountains, forests and flying units dodging melee

  It opens on **Your fights** (your attacks, then attacks on you) with an **All nations** tab, and a summary line of damage dealt, taken and stopped. The **Round report** button next to the battle log reopens it; Esc or Close shuts it. The numbers come from `MapWar.round_stats`, and hovering a column header explains it. Click a column header to sort the whole table by it, and click again to flip the order. Number columns start biggest-first, From/To start A-Z, and a gold arrow marks the sorted column. The sort is kept while you play.
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
- **Hover help:** hover a card in your hand, a shop card or any card on the map to see its description card (art, HP/damage or income, costs, special effect) with [Flying]/[Grounded] and [HasRange]/[Melee] trait boxes. Map cards also show their owner, Barracks, home-ground, mountain and forest bonuses, and their **next shot**, with a dashed arrow to the target. Flags, gauges, Influence and the Shop button have tooltips too.
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
The music is a modern synthesized score, made by `tools/soundtrack.py` (stdlib-only Python). It uses detuned analog-style pads through resonant filters, plucked arpeggios with ping-pong delay, sub bass, a felt piano, electronic drums with sidechain pumping, and a stereo reverb with a soft-clipping master. It writes three seamless looping stereo tracks (32 kHz) to `Assets/Audio/music/`:

| File | Title | Style | Where it plays |
|---|---|---|---|
| `menu.wav` | Long Shadows | slow cinematic theme, D minor, 84 bpm | main menu, story screens |
| `map.wav` | Command Table | strategy electronica that builds and thins out, A minor, 100 bpm | the war map |
| `battle.wav` | Front Line | driving hybrid with a breakdown, E minor, 128 bpm | card battles |

The sound effects are still 8-bit, from `tools/chiptune.py` (emulating 2 pulse channels, a triangle and a noise channel), in `Assets/Audio/sfx/`:
```
python3 tools/soundtrack.py         # the music (or: menu / map / battle)
python3 tools/chiptune.py           # the sound effects (chipmusic: the old 8-bit tunes)
```
`GodotHelpers/SoundManager.gd` (autoload) plays them. It crossfades music between scenes, gives every text button a click and hover sound, and each weapon has its own firing sound. **M** or the **Sound: On/Off** button mutes, and the setting is saved in `user://audio.cfg`.

## Tweaking
- `scripts/main.gd` top constants: `GRID_WIDTH`, `GRID_HEIGHT`, `TILE_SIZE`, `NUM_ROOMS`, `NUM_ENEMIES`
- `scripts/dungeon_generator.gd`: `generate(num_rooms, min_size, max_size)`

## Next Steps
- Add items/inventory, fog-of-war, stairs, save system
- Replace `draw_rect` tiles with TileMap + spritesheet
- Add Android/iOS export presets (requires export templates)
