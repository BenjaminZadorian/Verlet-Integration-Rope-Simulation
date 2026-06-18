class_name Player
extends CharacterBody2D

# Player Child Nodes
@onready var jumpBufferTimer : Timer = $JumpBufferTimer
@onready var coyoteTimer : Timer = $CoyoteTimer
@onready var ropeSimulation : Node2D = $"../RopeSimulation"
@onready var safe : RigidBody2D = $"../Safe"
@onready var flipper : Node2D = $Flipper
@onready var safePickupPoint : Marker2D = $Flipper/SafePickupPoint
@onready var throwIndicator : Line2D = $ThrowIndicator

# Physics
var mass : float = 5.0
var speed: int = 200
var jumpHeight : float = -400.0
var gravity : float = 980.0
var friction : float = 0.3
var airResistance : float = 0.5
var climbingSpeed : float = 40.0
var directionToCursor : Vector2 = Vector2.ZERO
var minThrowStrength : float = 100.0
var maxThrowStrength : float = 500.0
var throwVelocity : float = minThrowStrength
var minClimbVelocity : Vector2 = Vector2(0.05, 0.05)

# Climbing Timer
var climbCooldown : float = 0.05 # time between snapping to nodes
var climbTimer : float = 0.0

# Reeling Timer
var reelInCooldown : float = 0.05
var reelInTimer : float = 0.0
var reelOutCooldown : float = 0.05
var reelOutTimer : float = 0.0

# States
var isReelingIn : bool = false
var isReelingOut : bool = false
var isClimbingRope : bool = false
var ropeNeedsRebuild : bool = false
@export var debugMode : bool = false

# Constraints
var safePickupDistMin : int = 30 			# value in pixels
var ropeClimbDistMin : float = 1.0
var ropeClimbingNodeRadius : float = 6.0 	# value in pixels

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("pickup_safe"):
		PickUpSafe()

func _physics_process(delta: float) -> void:	
	# --- Apply Gravity ---
	if not self.is_on_floor():
		velocity.y += gravity * delta
	
	# --- Horizontal Movement ---
	var horizontalDirection := Input.get_axis("move_left", "move_right")
	if horizontalDirection < 0:
		flipper.scale.x = -1
	elif horizontalDirection > 0:
		flipper.scale.x = 1
	if isReelingIn == false:
		if horizontalDirection: # if player is movings
			if ropeSimulation.isTaut:
				velocity.x = (horizontalDirection * speed) / 2
			else:
				velocity.x = (horizontalDirection * speed)		
		elif is_on_floor(): # if player is standing still on floor
			velocity *= friction
		else:
			velocity.x *= airResistance

	# --- Jump ---
	# start timer when jump is pressed, but Player will only jump if the timer is still active
	if Input.is_action_just_pressed("jump"):
		jumpBufferTimer.start()

	# Coyote Time
	if is_on_floor():
		coyoteTimer.start()
	# If player is jumping, and release jump key, half velocity to reduce jump height
	elif velocity.y < 0.0:
		if Input.is_action_just_released("jump"):
			velocity.y *= 0.5

	# Player can jump when: 
	# jump Buffer is playing & coyote time is playing
	if !jumpBufferTimer.is_stopped() and !coyoteTimer.is_stopped():
		if safe.isPickedUp == false or debugMode == true:
			velocity.y = jumpHeight
			coyoteTimer.stop()
			jumpBufferTimer.stop()
	
	if self.is_on_floor() and ropeNeedsRebuild:
		ropeNeedsRebuild = false
	
	# Handle Reeling in Rope/Safe Logic
	if Input.is_action_pressed("reel_in") and ropeSimulation.ropeSegmentCount > ropeSimulation.ropeSegmentMin and self.is_on_floor() and not safe.isPickedUp:
		if isReelingIn == false:
			safe.freeze = true
		ReelIn(delta)
	elif isReelingIn == true:
		safe.freeze = false
		safe.linear_velocity = Vector2.ZERO     # clear any velocity before applying physics
		safe.angular_velocity = 0.0
		isReelingIn = false
	
	# Handle Reeling out the safe
	if Input.is_action_pressed("reel_out") and ropeSimulation.ropeSegmentCount < ropeSimulation.ropeSegmentBase and not safe.isPickedUp:
		ReelOut(delta)
	elif isReelingOut == true:
		isReelingOut = false

	# Handle Player climbing rope
	if Input.is_action_pressed("climb_rope") and ropeSimulation.ropeSegmentCount > ropeSimulation.ropeSegmentMin and (safe.global_position - self.global_position).normalized().y < ropeClimbDistMin and safe.isPickedUp == false:
		if safe.get_linear_velocity().abs() > minClimbVelocity:
			print("Cannot climb safe, unstable")
		else:
			isClimbingRope = true
			ClimbRope(delta)
		
	if Input.is_action_just_released("climb_rope") and self.isClimbingRope:
		isClimbingRope = false
		ropeNeedsRebuild = true

	# Handle throwing the safe
	if Input.is_action_pressed("throw_safe") and safe.isPickedUp:
		ThrowSafePress(delta)
	
	# Handle moving the safe after the throw input
	if Input.is_action_just_released("throw_safe") and safe.isPickedUp:
		ThrowSafeRelease(delta)
		
		
	# Main function that controls movement
	move_and_slide()

func ReelIn(delta : float) -> void:
	isReelingIn = true
	if ropeSimulation.ropeSegmentCount <= ropeSimulation.ropeSegmentMin + 1:
		PickUpSafe()
		isReelingIn = false
		return
		
	if reelInTimer > 0.0:
		reelInTimer -= delta
		return
	
	safe.global_position = ropeSimulation.currentPosArray[-2]
	ropeSimulation.currentPosArray.remove_at(ropeSimulation.currentPosArray.size() - 1)
	ropeSimulation.prevPosArray.remove_at(ropeSimulation.prevPosArray.size() - 1)
	ropeSimulation.ropeSegmentCount -= 1

	# restart the cooldown for the next node
	reelInTimer = reelInCooldown

func ReelOut(delta : float) -> void:
	isReelingOut = true
	# Unable to reel out past original length
	if ropeSimulation.ropeSegmentCount >= ropeSimulation.ropeSegmentBase:
		isReelingOut = false
		return
		
	if reelOutTimer > 0.0:
		reelOutTimer -= delta
		return
		
	var midpoint : Vector2 = (ropeSimulation.currentPosArray[0] + ropeSimulation.currentPosArray[1]) * 0.5
	ropeSimulation.currentPosArray.insert(1, midpoint)
	ropeSimulation.prevPosArray.insert(1, midpoint)
	ropeSimulation.ropeSegmentCount += 1
	
	reelOutTimer = reelOutCooldown

func ClimbRope(delta : float) -> void:
	if ropeSimulation.ropeSegmentCount <= ropeSimulation.ropeSegmentMin + 1:
		PickUpSafeFromClimb()
		self.isClimbingRope = false
		return
	
	if climbTimer > 0.0:
		climbTimer -= delta
		return
	
	self.global_position = ropeSimulation.currentPosArray[1]
	ropeSimulation.currentPosArray.remove_at(0)
	ropeSimulation.prevPosArray.remove_at(0)
	ropeSimulation.ropeSegmentCount -= 1

	# restart the cooldown for the next node
	climbTimer = climbCooldown

func PickUpSafe() -> void:
	# If it isn't picked up & you're close enough to pick it up
	if safe.isPickedUp == false and self.global_position.distance_to(safe.global_position) < safePickupDistMin:
		safe.isPickedUp = true
		ropeSimulation.currentPosArray = []
		ropeSimulation.prevPosArray = []
	elif safe.isPickedUp:
		if safe.ValidPlaceLocation():
			safe.isPickedUp = false
			ropeSimulation.Initialize(ropeSimulation.ropeSegmentCount)
		else:
			print("Cannot place safe here")

func PickUpSafeFromClimb() -> void:
	# Get safe's prev position
	var safePosition = safe.global_position
	# call pickup
	if isClimbingRope == true or isReelingIn == true:
		PickUpSafe()
		self.global_position = safePosition + Vector2(4, 0)

func ThrowSafePress(delta : float) -> void:
	directionToCursor = (get_global_mouse_position() - global_position).normalized()
	# Loop to increase throw strength long, then max out
	if throwVelocity >= maxThrowStrength:
		throwVelocity = maxThrowStrength
	else:
		throwVelocity += minThrowStrength * delta
	
	UpdateThrowIndicator()

func UpdateThrowIndicator() -> void:
	throwIndicator.visible = true
	# Max pixel length at full charge
	var maxIndicatorLength = 100.0
	# Normalize the throw strength between 0 and 1 so the visual is relevant to the powers
	var chargeFraction = (throwVelocity - minThrowStrength) / (maxThrowStrength - minThrowStrength)
	throwIndicator.default_color = Color.GREEN.lerp(Color.RED, chargeFraction)
	throwIndicator.points = [
		Vector2.ZERO,
		directionToCursor * (maxIndicatorLength * chargeFraction)
	]

func ThrowSafeRelease(delta : float) -> void:
	# Set the start position at the player for the safe throw
	safe.global_position = self.global_position
	throwIndicator.visible = false
	# release the safe from being frozen
	safe.isPickedUp = false
	safe.freeze = false
	safe.justThrown = true
	# Add a collision exception to the safe checking for the player when just thrown
	safe.add_collision_exception_with(self)
	# rebuild the rope
	ropeSimulation._ready()
	# remove any stored motion
	safe.linear_velocity = Vector2.ZERO
	safe.angular_velocity = 0.0
	# throw the safe
	var throwImpulse = directionToCursor * throwVelocity
	safe.apply_central_impulse(throwImpulse)
	# Reset values to default
	throwVelocity = minThrowStrength
	directionToCursor = Vector2.ZERO
