extends RigidBody2D

@onready var ropeSimulation : Node2D = $"../RopeSimulation"
@onready var safePickupPoint : Marker2D = $"../Player/Flipper/SafePickupPoint"
@onready var player : CharacterBody2D = $"../Player"

# State Variables
var isPickedUp : bool = false
var justThrown : bool = false

# Physics
var tensionScale : float = 80.0
var reelingNodeRadius : float = 1.0
var reelSpeed : float = 200.0
var playerClearDistance : float = 40.0

func _process(delta: float) -> void:
	if isPickedUp:
		self.freeze = true
		self.global_position = safePickupPoint.global_position
		ropeSimulation.isTaut = false
		ropeSimulation.currTautness = 0.0
		self.rotation = 0.0
	elif player.isReelingIn == false:
		self.freeze = false

func _physics_process(delta: float) -> void:
	# Halts physics the frame after being thrown
	if justThrown:
		# Make sure the safe has gone past the player before re-enabling collision
		var distanceToPlayer = global_position.distance_to(player.global_position)
		if distanceToPlayer > playerClearDistance:
			remove_collision_exception_with(player)
			
			justThrown = false
			return
		
	if not isPickedUp:
		if not ropeSimulation.isTaut:
			return
		
		var pullDir = ropeSimulation.GetSafePullDirection()
		var strength = ropeSimulation.GetSafeTensionStrength()
		
		apply_central_force(pullDir * strength * tensionScale)

func ValidPlaceLocation() -> bool:
	var spaceState = get_world_2d().direct_space_state

	# use the safe's  collision shape for the test
	var shape = $CollisionShape2D
	var queryParameters = PhysicsShapeQueryParameters2D.new()
	queryParameters.shape = shape.shape
	queryParameters.transform = Transform2D(0.0, safePickupPoint.global_position)
	queryParameters.collide_with_bodies = true
	queryParameters.collide_with_areas = false
	queryParameters.collision_mask = ropeSimulation.collisionLayer  # same layer as tilemap
	queryParameters.exclude = [self.get_rid()]

	var result = spaceState.intersect_shape(queryParameters)
	# if anything overlaps the drop position, placement is blocked
	return result.is_empty()
	
