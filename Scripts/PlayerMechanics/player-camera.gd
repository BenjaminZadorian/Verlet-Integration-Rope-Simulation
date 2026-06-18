extends Camera2D

@onready var player : CharacterBody2D = $"../Player"
@onready var ropeSimulation : Node2D = $"../RopeSimulation"

@onready var ropePieceCounterLeft : Label = $"../CanvasLayer/HUDControl/RopePieceCounterLeft"
@onready var ropePieceCounterUsed : Label = $"../CanvasLayer/HUDControl/RopePieceCounterUsed"
@onready var fpsLabel : Label = $"../CanvasLayer/HUDControl/FPSLabel"

# Flags
@export var showGameInfo : bool = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass


func _process(delta: float) -> void:
	if showGameInfo:
		fpsLabel.visible = true
		UpdateGameInfoLabel()
	else:
		fpsLabel.visible = false
	
	self.global_position = Vector2(player.global_position.x, player.global_position.y)
	
	print(ropeSimulation.ropeSegmentCount)
	ropePieceCounterLeft.text = "Rope Pieces Left: " + str(ropeSimulation.ropeSegmentBase - ropeSimulation.ropeSegmentCount)
	ropePieceCounterUsed.text = "Rope Pieces Currently Used:" + str(ropeSimulation.ropeSegmentCount)

func UpdateGameInfoLabel() -> void:
	fpsLabel.text = "FPS: " + str(Engine.get_frames_per_second())
