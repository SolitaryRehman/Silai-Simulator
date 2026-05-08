extends Node3D

@onready var camera_3d: Camera3D = $Camera3D
@onready var character_1: CharacterBody3D = $Character_1

@onready var continue_button: Button = $CanvasLayer/TextureRect/ContinueButton
@onready var new_game_button: Button = $CanvasLayer/TextureRect/NewGameButton
@onready var game_options_button: Button = $CanvasLayer/TextureRect/GameOptionsButton
@onready var quit_game_button: Button = $CanvasLayer/TextureRect/QuitGameButton
