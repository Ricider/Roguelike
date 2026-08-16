Roguelike Autochess Cardgame

### Classes ###

# Class Group: Fundamental

class GameObject(GameObject):
    UID: int

class Player(GameObject):
    HitPoints: int
    Board: Row[4]

    BioSupply: int
    MoneySupply: int

    DrawPile: Card[]
    DiscardPile: Card[]
    Hand: Card[]
    Graveyard: Card[]

class CombatState(GameObject):
    Players: Player[2]

# Class Group: Cards

class Card(GameObject):
    SpecialEffect: AIIntrepretedString (I put text, you write the ability)

class Building (Cards):
    HitPoints: int
    Income: int
    
    MoneyCost: int
    BioCost: int

class Unit (Cards):
    HitPoints: int
    Damage: int
    HasRange: bool
    
    MoneyCost: int
    BioCost: int

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
    Hp: 10
    Damage: 2
    HasRange: false
    
    MoneyCost: 5
    BioCost: 15

Card: Tank
    Hp: 20
    Damage: 6
    HasRange: false
    
    MoneyCost: 25
    BioCost: 10

Card: Artilery
    Hp: 8
    Damage: 6
    HasRange: true
    
    MoneyCost: 20
    BioCost: 6

Card: Rocket Launcher
    Hp: 8
    Damage: 2
    HasRange: true
    
    MoneyCost: 25
    BioCost: 4

    SpecialEffect: attacks 4 times every Combat Phase

### Building Cards ###

Card: Factory
    Hp: 20
    MoneyIncome: 15

    MoneyCost: 30
    BioCost 20

Card: Barracks
    Hp: 30
    MoneyIncome: 2

    MoneyCost: 20
    BioCost: 25

    SpecialEffect: Friendly units in adjacent squares have +2 damage

Card: Housing
    Hp: 50
    MoneyIncome: 2

    MoneyCost: 20
    BioCost: 30

    SpecialEffect: In your economy phase gain 4% more BioSupply

Card: Wall
    Hp: 20
    MoneyIncome: 0

    MoneyCost: 10
    BioCost: 0

### Players ###

Player: JohnDoe
    HitPoints=100
    Board=Empty

    BioSupply=100
    MoneySupply=20

    DrawPile: [10 wall, 10 Infantry, 3 Tank, 3 Artillery, 2 Rocket Launcher, 2 Factory, 2 Housing, 1 Barrack]
    DiscardPile: []
    Hand: []

Player: Insurgents
    HitPoints=100
    Board=Empty

    BioSupply=100
    MoneySupply=20

    DrawPile: [8 wall, 5 Infantry, 2 Tank, 2 Artillery, 2 Factory, 2 Housing, 1 Barrack]
    DiscardPile: []
    Hand: []

### Rules ###

## Turn Phases ##

Every player has 3 phases they go through each turn. First player to drop to 0 hp loses

# 1) Economy Phase

- Each player gets a deck of cards, draws 7 start of each turn, shuffles discard deck back into draw pile if there are no cards left in the draw pile and continue drawing until they have 5
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
- If a card has a special effect defined it is applied during the combat phase after the damage is calculated
- Whenever a card is destroyed the original BioSupply that was paid to play it gets deduced from the owning players hp
- When a card dies it goes into the graveyard, where it can only be brought back by card effects
