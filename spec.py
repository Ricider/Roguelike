Roguelike Autochess Cardgame

### Classes ###

# Class Group: Fundamental

class GameObject(GameObject):
    UID: int

class Player(GameObject):
    HitPoints: int
    Board: Row[3]

class CombatState(GameObject):
    Players: Player[2]

# Class Group: Cards

class Card(GameObject):
    pass

class Unit (Cards):
    HitPoints: int
    Damage: int

# Class Group: GameBoard

class Square(GameObject):
    Inhabitant: Unit

class Row(GameObject):
    Squares: Square[5]

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
|
<Files that absolutely need to be in the root directory of project>