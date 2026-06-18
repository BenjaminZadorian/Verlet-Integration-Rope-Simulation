extends Camera2D

@export var cameraSpeed : int = 300

func _process(delta: float) -> void:
	if Input.is_action_pressed("move_left"):
		self.global_position.x -= cameraSpeed * delta
	if Input.is_action_pressed("move_right"):
		self.global_position.x += cameraSpeed * delta
	if Input.is_action_pressed("camera-move-up"):
		self.global_position.y -= cameraSpeed * delta
	if Input.is_action_pressed("camera-move-down"):
		self.global_position.y += cameraSpeed * delta
