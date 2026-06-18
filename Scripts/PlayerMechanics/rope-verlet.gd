extends Node2D

# Player Marker is always index 0 - Safe is always final index
@onready var player : CharacterBody2D = $"../Player"
@onready var playerRopePoint : Marker2D = $"../Player/Flipper/RopeAttachPoint"
@onready var safeRopePoint : Marker2D = $"../Safe/RopeAttachPoint"
@onready var ropeVisual : Line2D = $RopeVisual
@onready var safe : RigidBody2D = $"../Safe"

# Position Data
var currentPosArray : PackedVector2Array
var prevPosArray : PackedVector2Array
var ropeStartPoint : Vector2
var ropeEndPoint : Vector2

# Features Data
var ropeSegmentBase : int = 15	# Base value
var ropeSegmentCount : int		# Value live updated during play
var ropeSegmentLength : float = 5
var ropeSegmentSize : float = 5
var ropeSegmentMin : int = 4
var isTaut : bool = false

# Physics Data
var gravity : Vector2 = Vector2(0, 9.8)
var damping : float = 0.9
var collisionLayer : int = 1
var collisionRadius : float = 12.0
var bounceFactor : float = 0.1
var correctionClampAmount : float = 10.0
var collisionMargin : float = 0.01
var currTautness : float
var maxTautness : float=  0.98

# Constraints
var constraintRuns : int = 30

# Optimizations
var collisionSegmentInterval : int = 1

func _ready() -> void:
	Initialize(ropeSegmentBase)

func Initialize(ropeSegmentRequest : int) -> void:
	ropeStartPoint = playerRopePoint.global_position
	ropeEndPoint = safeRopePoint.global_position
	ropeVisual.width = ropeSegmentSize
	
	ropeSegmentCount = ropeSegmentRequest
	
	ResizeArrays()
	InitPosition()
func _physics_process(delta : float) -> void:
	if safe.isPickedUp == false:
		Simulate(delta)
		for i in range(constraintRuns):
			ApplyConstraints()
		HandleCollisions()

		currTautness = GetRopeTautness()
		isTaut = currTautness >= maxTautness

		EnforceMaxLength()

	ropeVisual.points = currentPosArray

func ResizeArrays() -> void:
	currentPosArray.resize(ropeSegmentCount)
	prevPosArray.resize(ropeSegmentCount)
	
func InitPosition() -> void:
	for i in range(ropeSegmentCount):
		# interpolate from start to end to place rope pieces
		var ropeSpawnWeight = float(i) / float(ropeSegmentCount - 1)
		var ropeSpawnPosition = ropeStartPoint.lerp(ropeEndPoint, ropeSpawnWeight)
		
		# clamp each node to not spawn too far away and start fighting eachother
		if i > 0:
			var fromPrev = ropeSpawnPosition - currentPosArray[i-1]
			if fromPrev.length() > ropeSegmentLength:
				ropeSpawnPosition = currentPosArray[i - 1] + fromPrev.normalized() * ropeSegmentLength
		
		currentPosArray[i] = ropeSpawnPosition
		prevPosArray[i] = ropeSpawnPosition
	position = Vector2.ZERO

func Simulate(delta : float) -> void:
	for i in ropeSegmentCount:
		if (i != 0 && i != ropeSegmentCount - 1):	# If not the first or last, update the point position
			var velocity = (currentPosArray[i] - prevPosArray[i]) * damping
			prevPosArray[i] = currentPosArray[i]
			currentPosArray[i] += velocity + (gravity * delta * delta)

func ApplyConstraints() -> void:
	currentPosArray[0] = playerRopePoint.global_position
	currentPosArray[-1] = safeRopePoint.global_position
	
	for i in range(ropeSegmentCount):
		
		if i == ropeSegmentCount - 1:
			return
			
		var distance = currentPosArray[i].distance_to(currentPosArray[i + 1])
		var difference = (distance - ropeSegmentLength)
		
		var changeDir = (currentPosArray[i] - currentPosArray[i + 1]).normalized()
		var changeVector = changeDir * difference # direction or correction * length of correction needed

		if i == 0:
			currentPosArray[i+1] += changeVector
		elif i + 1 == ropeSegmentCount - 1:
			currentPosArray[i] -= changeVector
		else:
			currentPosArray[i] -= (changeVector * 0.5)
			currentPosArray[i + 1] += (changeVector * 0.5)

func HandleCollisions() -> void:
	var spaceRID = get_world_2d().space
	var spaceState = PhysicsServer2D.space_get_direct_state(spaceRID)
	
	for i in range(ropeSegmentCount):
		if i == 0 or i == ropeSegmentCount - 1:
			continue
		
		var velocity = currentPosArray[i] - prevPosArray[i]
		var circle = CircleShape2D.new()
		circle.radius = collisionRadius
		
		var queryParameters = PhysicsShapeQueryParameters2D.new()
		queryParameters.shape = circle
		queryParameters.transform = Transform2D(0.0, currentPosArray[i])
		queryParameters.collide_with_bodies = true
		queryParameters.collide_with_areas = false
		queryParameters.collision_mask = collisionLayer
		queryParameters.margin = 0.0

		# returns a pair (my contact, collider contact)
		var collisionPoints = spaceState.collide_shape(queryParameters)
		
		if collisionPoints.is_empty():
			continue
		
		var closestPoint : Vector2 = Vector2.ZERO
		var closestDistance : float = INF
		
		# find the closest point on the colliders surface to the rope segment
		for j in range(0, collisionPoints.size(), 2): # 2 step due to pairs
			var colliderContact = collisionPoints[j + 1]
			var distanceSqr = currentPosArray[i].distance_squared_to(colliderContact)
			
			if distanceSqr < closestDistance:
				closestDistance = distanceSqr
				closestPoint = colliderContact
				
		if closestDistance == INF:
			continue

		var collisionVector = currentPosArray[i] - closestPoint
		var collisionDepth = collisionVector.length()
		
		if collisionDepth < collisionMargin:
			continue
		
		var pushDir = collisionVector.normalized()
		
		currentPosArray[i] = closestPoint + pushDir * (collisionRadius + collisionMargin)
		
		var collisionVelocity = (currentPosArray[i] - prevPosArray[i]) * damping
		collisionVelocity = collisionVelocity.slide(pushDir) * bounceFactor
		prevPosArray[i] = currentPosArray[i] - collisionVelocity

func GetAnchorPointDistance() -> Vector2:
	var distance : Vector2 = currentPosArray[0] - currentPosArray[-1]
	return distance
	
func GetRopeTautness() -> float:
	var usedLength : float = 0.0

	for i in range(ropeSegmentCount - 1):
		usedLength += currentPosArray[i].distance_to(currentPosArray[i+1])

	var maxLength : float = ropeSegmentCount * ropeSegmentLength
	return usedLength / maxLength

func GetSafePullDirection() -> Vector2:
	if ropeSegmentCount < 2:
		return Vector2.ZERO
	# get the direction from the safe to the next adjacent node
	return (currentPosArray[-2] - currentPosArray[-1]).normalized()

func GetSafeTensionStrength() -> float:
	if not isTaut:
		return 0.0
	
	# get how mcuh the segment adjacent to the safe has stretched beyond rest length
	var dist = currentPosArray[-2].distance_to(currentPosArray[-1])
	return maxf(0.0, dist - ropeSegmentLength)

func GetCurrentPathLength() -> float:
	var total = 0.0
	# Get the total length of the rope path
	for i in range(ropeSegmentCount - 1):
		total += currentPosArray[i].distance_to(currentPosArray[i + 1])
	return total

func EnforceMaxLength() -> void:
	if safe.isPickedUp:
		return
	var maxLength = ropeSegmentCount * ropeSegmentLength
	var overshoot = GetCurrentPathLength() - maxLength

	if overshoot <= 0.0:
		return
		
	var playerTangent = (currentPosArray[1] - currentPosArray[0]).normalized()

	player.global_position += playerTangent * overshoot

	# cancel the player's velocity component pulling away from the rope
	var playerOutward : float = player.velocity.dot(-playerTangent)
	if playerOutward > 0.0:
		player.velocity += playerTangent * playerOutward
