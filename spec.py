Roguelike Autochess Cardgame

### Classes ###

# Class Group: Fundamental

class GameObject(GameObject):
    UID: int

class Player(GameObject):
    HitPoints: int
    Board: Row[4]
    Difficulty: int

    BackgroundImage: AIIntrepretedString (I put text, you write the ability)

    BioSupply: int
    MoneySupply: int

    Influence: int

    Modifiers: Modifier[]

    DrawPile: Card[]
    DiscardPile: Card[]
    Hand: Card[]
    Graveyard: Card[]

class Modifier(GameObject):
    Effect: AIIntrepretedString (I put text, you write the ability)
    InfluenceCost: int

class CombatState(GameObject):
    Players: Player[2]

# Class Group: Cards

class Card(GameObject):
    SpecialEffect: AIIntrepretedString (I put text, you write the ability)
    
    MoneyCost: int
    BioCost: int

    InfluenceCost: int

class Building (Cards):
    HitPoints: int
    Income: int

class Unit (Cards):
    HitPoints: int
    Damage: int
    HasRange: bool
    Flying: bool

# Class Group: GameBoard

class Square(GameObject):
    Inhabitant: Card

class Row(GameObject):
    Squares: Square[10]

### Project Structure ###

GodotHelpers
|_ <Files to interface the game logic with godot>
Classes
|_ Fundamental
|___ <Classes classified as Fundamental, one file per class>
|_ Cards
|___ <Classes classified as Cards, one file per class>
|_ GameBoard
|___ <Classes classified as GameBoard, one file per class>
|_ <One folder per Class Group:>
Assets
|___ <Asset Files, mirror the directory structure with Classes directory where each class gets its own asset folder>
|_ AI
|___ <AI opponent files>
|
<Files that absolutely need to be in the root directory of project>

### Unit Cards ###

Card: Infantry
    Hp: 12
    Damage: 2
    HasRange: false
    Flying: false
    
    MoneyCost: 5
    BioCost: 15

    InfluenceCost: 10

Card: Tank
    Hp: 25
    Damage: 8
    HasRange: false
    Flying: false
    
    MoneyCost: 25
    BioCost: 10

    InfluenceCost: 15

Card: Artilery
    Hp: 12
    Damage: 8
    HasRange: true
    Flying: false
    
    MoneyCost: 20
    BioCost: 8

    InfluenceCost: 20

Card: Rocket Launcher
    Hp: 12
    Damage: 2
    HasRange: true
    Flying: false
    
    MoneyCost: 25
    BioCost: 5

    SpecialEffect: attacks 4 times every Combat Phase

    InfluenceCost: 30

Card: Drone
    Hp: 6
    Damage: 3
    HasRange: false
    Flying: true
    
    MoneyCost: 5
    BioCost: 0

    InfluenceCost: 15

Card: Fighter Jet
    Hp: 14
    Damage: 4
    HasRange: true
    Flying: true
    
    MoneyCost: 35
    BioCost: 5

    SpecialEffect: Also damages tiles adjacent to where it hit

    InfluenceCost: 40

### Building Cards ###

Card: Factory
    Hp: 20
    MoneyIncome: 15

    MoneyCost: 30
    BioCost 20

    InfluenceCost: 20

Card: Barracks
    Hp: 30
    MoneyIncome: 2

    MoneyCost: 20
    BioCost: 25

    SpecialEffect: Friendly units in adjacent squares have +2 damage

    InfluenceCost: 30

Card: Housing
    Hp: 50
    MoneyIncome: 2

    MoneyCost: 20
    BioCost: 30

    SpecialEffect: In your economy phase gain 4% more BioSupply

    InfluenceCost: 15

Card: Wall
    Hp: 20
    MoneyIncome: 0

    MoneyCost: 10
    BioCost: 0

    InfluenceCost: 5

Card: Corporation
    Hp: 25
    MoneyIncome: 12

    MoneyCost: 70
    BioCost: 20

    SpecialEffect: Reduce MoneyCost of playing all cards by 20%

    InfluenceCost: 60

### Players ###

Player: Insurgents
    HitPoints=120
    Board=Empty
    Difficulty=1
    BackgroundImage=Sparse mountain village

    BioSupply=120
    MoneySupply=10

    Influence=10

    DrawPile: [5 wall, 10 Infantry, 8 Drones, 2 Tank 1 Factory, 3 Housing, 2 Barrack]
    DiscardPile: []
    Hand: []


Player: State Troops
    HitPoints=100
    Board=1 Housing and 1 Infantry randomly placed at back row
    Difficulty=2
    BackgroundImage=Middle Eastern town, add some mosques around, don't make the entire thing a desert

    BioSupply=100
    MoneySupply=20

    Influence=20

    DrawPile: [10 wall, 10 Infantry, 3 Tank, 3 Artillery, 2 Factory, 2 Housing, 1 Barrack]
    DiscardPile: []
    Hand: []

Player: Horde
    HitPoints=200
    Board=2 Housing and 1 Artilery, 2 tank randomly placed at back row, all damaged down to 5 hp
    Difficulty=4
    BackgroundImage=Russian style city, snowy, add few trees

    BioSupply=160
    MoneySupply=0

    Influence=25

    DrawPile: [10 wall, 15 Infantry, 8 Drones, 2 Tank, 2 Artillery, 4 Fighter Jet, 4 Factory, 1 Housing, 2 Barrack]
    DiscardPile: []
    Hand: []

Player: Coalition Army
    HitPoints=60
    Board=2 Housing and 1 Factory randomly placed at back row
    Difficulty=5
    BackgroundImage=City with european style towers

    BioSupply=80
    MoneySupply=50

    Influence=50

    DrawPile: [10 wall, 8 Infantry, 8 Drones, 2 Tank, 2 Artillery, 1 Rocket Launcher, 4 Fighter Jet, 4 Factory, 1 Housing, 2 Barrack, 1 Corporation]
    DiscardPile: []
    Hand: []

Player: Corporate Troops
    HitPoints=30
    Board=2 Corporation randomly placed at back row
    Difficulty=6
    BackgroundImage=Cyberpunk Skyrises

    BioSupply=10
    MoneySupply=100

    Influence=50

    DrawPile: [10 wall, 4 Infantry, 14 Drones, 4 Fighter Jet, 2 Corporation, 1 Housing, 4 Barrack, 3 Rocket Launcher]
    DiscardPile: []
    Hand: []

### Modifiers ###

Modifier: Conscription
    Effect=Gain 15 additional BioSupply every turn, but earn 50% less MoneySupply
    InfluenceCost: 50

Modifier: Guerilla Warfare
    Effect=Your cards that have a BioCost higher than MoneyCost deal 100% more damage, but the ones that have BioCost lower than MoneyCost have 50% less HP
    InfluenceCost: 70

Modifier: State of emergency
    Effect=You gain 3 HitPoints every turn
    InfluenceCost: 90

Modifier: Fanaticism
    Effect=Your buildings have 50% less HP, but Units have 100% more
    InfluenceCost: 40

Modifier: Corruption
    Effect=Your buildings have 50% less HP, but you gain +10 MoneySupply every turn
    InfluenceCost: 40

Modifier: Advanced Robotics
    Effect=All units have HasRange set to true, but they cost +5 extra MoneySupply
    InfluenceCost: 100

Modifier: Aerial Supremacy
    Effect=If a unit has Flying set to true then they deal +2 damage, but they cost +5 extra MoneySupply
    InfluenceCost: 80

### Rules ###

## Main Game Rules ##

- Player choses any Player to play as with "State Troops" marked as the recommended option with a border.
- Player fights Enemies in battles starting with insurgents and if they can defeat them they face enemies with higer difficulty each turn (just sort from lowest diffculty to highest)
- Between each Battle player gets to visit a shop
- When a player defeats an enemy it gains their starting influence
- Modifier effects are permanent, meaning that once the player buys them it stays with them until the game state is reset

## Shop Rules ##

- Player starts with as many influence as specified in their influence field
- Offer 5 Cards to the player to buy from and add to their deck using influence
- On a separate row offer 3 Modifiers to the player to buy from and add to their deck using influence
- Player can also use 25 influence to remove a card once per shop

## Battle Phases ##

Every player has 3 phases they go through each turn. First player to drop to 0 hp loses

# 1) Economy Phase

- Each player gets a deck of cards, draws 10 start of each turn, shuffles discard deck back into draw pile if there are no cards left in the draw pile and continue drawing until they have 5
- Each players BioSupply grow by 10% each turn + 5 extra on top of what they have
- Each Players MoneySupply grow by 10 each turn plus the additional money suply gained from building cards that have a MoneyIncome value
- Discard cards in hand into discard pile all at the end of the turn

# 2) Build Phase

- Players get to chose which cards they play every turn into any of the squares in any of their rows. They can play any of the cards they drew by paying their BioCost and MoneyCost from theirBioSupply and MoneySupply
- Each Player has a 4x10 grid board where they can play both units and buildings on their own turn into 4 rows of 10 squares. Two players boards face each other combining to a 8x10 board, similarly to a smaller chess board

# 3) Combat Phase
- Game Plays in Autochess format in a one versus one format. 
- At the end of each players turn all of their cards that have a damage deal their damage to a random enemy prioritizing the closest enemy.
- If a card has HasRange to true then it can randomly attack any random enemy instead of being forced to attack one in the closest row
- If a card has Flying set to true then it takes half damage from enemies without HasRange set to true
- If a card has a special effect defined it is applied during the combat phase after the damage is calculated
- Whenever a card is destroyed the original BioSupply that was paid to play it gets deduced from the owning players hp
- When a card dies it goes into the graveyard, where it can only be brought back by card effects
