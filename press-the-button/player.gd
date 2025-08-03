extends CharacterBody2D

# Movement constants
const SPEED = 300.0
const JUMP_VELOCITY = -400.0
const ACCELERATION = 1500.0
const FRICTION = 1000.0

# Coyote time settings
const COYOTE_TIME = 0.1  # Time in seconds after leaving ground where jump is still allowed
var coyote_timer = 0.0
var was_on_floor = false

# Jump buffering (optional enhancement)
const JUMP_BUFFER_TIME = 0.1
var jump_buffer_timer = 0.0

# Double jump settings
const DOUBLE_JUMP_VELOCITY = -350.0  # Slightly weaker than regular jump
var has_double_jump = false  # Whether the player has used their double jump
var double_jump_used = false  # Track if double jump was used this air time

# Dash settings
const DASH_SPEED = 600.0
const DASH_DURATION = 0.2
const DASH_COOLDOWN = 1.0
const DOUBLE_TAP_TIME = 0.3  # Time window for double tap detection

var dash_timer = 0.0
var dash_cooldown_timer = 0.0
var dash_direction = Vector2.ZERO
var is_dashing = false

# Wall jumping settings
const WALL_JUMP_VELOCITY = Vector2(400.0, -350.0)  # Horizontal and vertical force
const WALL_SLIDE_SPEED = 100.0  # Maximum speed when sliding down wall
const WALL_JUMP_TIME = 0.3  # Time after wall jump where horizontal input is reduced
const WALL_COYOTE_TIME = 0.1  # Coyote time for walls (can jump shortly after leaving wall)

var is_wall_sliding = false
var wall_jump_timer = 0.0
var wall_coyote_timer = 0.0
var was_on_wall = false
var wall_normal = Vector2.ZERO  # Direction pointing away from the wall

# Double tap detection
var last_left_press_time = -1.0
var last_right_press_time = -1.0
var dash = false
var wall_jump = false
var invert = false
var double = false

# Get the gravity from the project settings to be synced with RigidBody nodes
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
var spawn_position = Vector2.ZERO  # Store the starting position

func _ready():
	spawn_position = global_position

func _physics_process(delta):
	handle_gravity(delta)
	handle_coyote_time(delta)
	handle_wall_detection(delta)
	handle_jump_input(delta)
	handle_dash_input(delta)
	handle_dash_movement(delta)
	handle_horizontal_movement(delta)
	
	# Move the character
	move_and_slide()

func handle_gravity(delta):
	# Reduced gravity during dash for better control
	if not is_on_floor() and not is_dashing:
		if is_wall_sliding:
			# Limit fall speed when wall sliding
			velocity.y = min(velocity.y + gravity * delta * 0.3, WALL_SLIDE_SPEED)
		else:
			velocity.y += gravity * delta

func handle_coyote_time(delta):
	# Track if we were on floor last frame
	if is_on_floor():
		coyote_timer = COYOTE_TIME
		was_on_floor = true
		# Reset double jump when touching ground
		if double:
			has_double_jump = true
			double_jump_used = false
	else:
		if was_on_floor:
			# Just left the ground, start coyote timer
			coyote_timer = COYOTE_TIME
			was_on_floor = false
		else:
			# Continue counting down coyote time
			coyote_timer -= delta
	
	# Clamp timer to prevent negative values
	coyote_timer = max(coyote_timer, 0.0)

func handle_wall_detection(delta):
	# Check if we're touching a wall
	var is_on_wall_now = is_on_wall_only() and not is_on_floor()
	
	# Update wall coyote time
	if is_on_wall_now:
		wall_coyote_timer = WALL_COYOTE_TIME
		was_on_wall = true
		wall_normal = get_wall_normal()
		# Reset double jump when touching wall (optional - you can remove this if you don't want it)
		if double and wall_jump:
			has_double_jump = true
	else:
		if was_on_wall:
			# Just left the wall, start wall coyote timer
			wall_coyote_timer = WALL_COYOTE_TIME
			was_on_wall = false
		else:
			# Continue counting down wall coyote time
			wall_coyote_timer -= delta
	
	# Clamp timer to prevent negative values
	wall_coyote_timer = max(wall_coyote_timer, 0.0)
	
	# Determine if we should be wall sliding
	is_wall_sliding = false
	if is_on_wall_now and not is_on_floor() and velocity.y > 0:
		# Check if player is holding towards the wall
		var direction = Input.get_axis("left", "right")
		if invert:
			direction = -direction
		
		# If player is pushing into the wall, enable wall sliding
		if (wall_normal.x > 0 and direction < 0) or (wall_normal.x < 0 and direction > 0):
			is_wall_sliding = true
	
	# Update wall jump timer
	if wall_jump_timer > 0:
		wall_jump_timer -= delta

func handle_jump_input(delta):
	# Handle jump buffering
	if Input.is_action_just_pressed("up"):
		jump_buffer_timer = JUMP_BUFFER_TIME
	else:
		jump_buffer_timer -= delta
		jump_buffer_timer = max(jump_buffer_timer, 0.0)
	
	# Jump logic
	if jump_buffer_timer > 0.0:
		var jumped = false
		
		# Disable regular jumping during dash (but allow wall jumps)
		if not is_dashing:
			# Regular jump or coyote jump
			if is_on_floor() or coyote_timer > 0.0:
				velocity.y = JUMP_VELOCITY
				jumped = true
				coyote_timer = 0.0  # Consume coyote time
				# Mark that we've used our ground jump
				if double:
					double_jump_used = false  # Reset since we're doing a ground jump
			# Double jump (only if double jump is enabled and available)
			elif double and has_double_jump and not double_jump_used:
				velocity.y = DOUBLE_JUMP_VELOCITY
				has_double_jump = false  # Consume double jump
				double_jump_used = true
				jumped = true
		
		# Wall jump (works even during dash)
		if not jumped and (is_on_wall_only() or wall_coyote_timer > 0.0):
			perform_wall_jump()
			jumped = true
			wall_coyote_timer = 0.0  # Consume wall coyote time
		
		if jumped:
			jump_buffer_timer = 0.0  # Consume the jump buffer
	
	# Variable jump height (release jump early for shorter jumps)
	if Input.is_action_just_released("up"):
		if velocity.y < 0:  # Only if we're moving upward
			velocity.y *= 0.5

func perform_wall_jump():
	if not wall_jump:
		return
	
	# Cancel any ongoing dash
	is_dashing = false
	dash_timer = 0.0
	
	# Apply wall jump velocity
	velocity.x = wall_normal.x * WALL_JUMP_VELOCITY.x
	velocity.y = WALL_JUMP_VELOCITY.y
	
	# Start wall jump timer to reduce horizontal control temporarily
	wall_jump_timer = WALL_JUMP_TIME

func handle_dash_input(delta):
	var current_time = Time.get_ticks_msec() / 1000.0  # Convert to seconds
	
	# Update dash cooldown
	if dash_cooldown_timer > 0:
		dash_cooldown_timer -= delta
	
	# Check for double tap left
	if Input.is_action_just_pressed("ui_left"):
		if current_time - last_left_press_time <= DOUBLE_TAP_TIME and dash_cooldown_timer <= 0:
			start_dash(Vector2.LEFT)
		last_left_press_time = current_time
	
	# Check for double tap right
	if Input.is_action_just_pressed("ui_right"):
		if current_time - last_right_press_time <= DOUBLE_TAP_TIME and dash_cooldown_timer <= 0:
			start_dash(Vector2.RIGHT)
		last_right_press_time = current_time

func start_dash(direction: Vector2):
	if not dash:
		return
	# Apply invert if enabled
	if invert:
		direction = -direction
	
	is_dashing = true
	dash_direction = direction
	dash_timer = DASH_DURATION
	dash_cooldown_timer = DASH_COOLDOWN
	
	# Set initial dash velocity
	velocity.x = dash_direction.x * DASH_SPEED
	velocity.y = 0  # Reset vertical velocity for horizontal dash

func handle_dash_movement(delta):
	if is_dashing:
		dash_timer -= delta
		
		if dash_timer <= 0:
			# End dash
			is_dashing = false
			dash_direction = Vector2.ZERO
		else:
			# Maintain dash velocity
			velocity.x = dash_direction.x * DASH_SPEED
			# Slightly reduce gravity during dash
			if not is_on_floor():
				velocity.y += gravity * delta * 0.3

func handle_horizontal_movement(delta):
	# Don't apply normal movement during dash
	if is_dashing:
		return
	
	# Get input direction
	var direction = Input.get_axis("left", "right")
	if invert:
		direction = -direction
	
	# Reduce horizontal control during wall jump
	var control_factor = 1.0
	if wall_jump_timer > 0:
		control_factor = 0.3  # Reduced control during wall jump
	
	if direction != 0:
		# Accelerate towards target speed
		var target_speed = direction * SPEED * control_factor
		velocity.x = move_toward(velocity.x, target_speed, ACCELERATION * delta * control_factor)
	else:
		# Apply friction when no input (reduced during wall jump)
		var friction_force = FRICTION * delta * control_factor
		velocity.x = move_toward(velocity.x, 0, friction_force)

# Optional: Add debug information
func _draw():
	if Engine.is_editor_hint():
		return
	
	# Draw coyote time indicator (for debugging)
	if coyote_timer > 0.0 and not is_on_floor():
		var color = Color.YELLOW
		color.a = coyote_timer / COYOTE_TIME
		draw_circle(Vector2(0, -20), 5, color)
	
	# Draw jump buffer indicator (for debugging)
	if jump_buffer_timer > 0.0:
		var color = Color.CYAN
		color.a = jump_buffer_timer / JUMP_BUFFER_TIME
		draw_circle(Vector2(15, -20), 3, color)
	
	# Draw dash cooldown indicator (for debugging)
	if dash_cooldown_timer > 0.0:
		var color = Color.RED
		color.a = dash_cooldown_timer / DASH_COOLDOWN
		draw_circle(Vector2(-15, -20), 4, color)
	
	# Draw dash active indicator (for debugging)
	if is_dashing:
		var color = Color.GREEN
		draw_circle(Vector2(0, -35), 6, color)
	
	# Draw wall slide indicator (for debugging)
	if is_wall_sliding:
		var color = Color.ORANGE
		draw_circle(Vector2(0, 0), 8, color)
	
	# Draw wall coyote time indicator (for debugging)
	if wall_coyote_timer > 0.0 and not is_on_wall_only():
		var color = Color.MAGENTA
		color.a = wall_coyote_timer / WALL_COYOTE_TIME
		draw_circle(Vector2(-30, -20), 4, color)
	
	# Draw wall jump timer indicator (for debugging)
	if wall_jump_timer > 0.0:
		var color = Color.LIME_GREEN
		color.a = wall_jump_timer / WALL_JUMP_TIME
		draw_circle(Vector2(30, -20), 4, color)
	
	# Draw double jump indicator (for debugging)
	if double and has_double_jump:
		var color = Color.PURPLE
		draw_circle(Vector2(0, -50), 7, color)

# Optional: Get coyote time status (useful for animations or other systems)
func can_coyote_jump() -> bool:
	return coyote_timer > 0.0 and not is_on_floor()

func is_coyote_jumping() -> bool:
	return can_coyote_jump()

# Wall jumping status functions
func can_wall_jump() -> bool:
	return is_on_wall_only() or wall_coyote_timer > 0.0

func is_wall_jumping() -> bool:
	return wall_jump_timer > 0.0

# Dash status functions
func can_dash() -> bool:
	return dash_cooldown_timer <= 0.0

func get_dash_cooldown_percent() -> float:
	return 1.0 - (dash_cooldown_timer / DASH_COOLDOWN)

# Double jump status functions
func can_double_jump() -> bool:
	return double and has_double_jump and not double_jump_used

func has_used_double_jump() -> bool:
	return double_jump_used

func reset():
	global_position = spawn_position
	velocity = Vector2.ZERO
	is_dashing = false
	dash_timer = 0.0
	dash_cooldown_timer = 0.0
	last_left_press_time = -1.0
	last_right_press_time = -1.0
	is_wall_sliding = false
	wall_jump_timer = 0.0
	wall_coyote_timer = 0.0
	was_on_wall = false
	wall_normal = Vector2.ZERO
	# Reset double jump state
	if double:
		has_double_jump = true
		double_jump_used = false
