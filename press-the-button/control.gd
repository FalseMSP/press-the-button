# GameTimer.gd
extends Control

# Timer settings
@export var time_limit: float = 25.0  # Time in seconds
@export var warning_time: float = 5.0  # When to start warning (red text, etc.)

# UI elements
@onready var time_label: Label = $TimeLabel
@onready var timer: Timer = $Timer

# Scene Setup Instructions:
# 1. Create a Control node and attach this script
# 2. Add a Label node as child named "TimeLabel"
# 3. Add a Timer node as child named "Timer"
# 4. Position the TimeLabel where you want it on screen
# 5. Set the TimeLabel font size and alignment as desired

# Game state
var current_time: float
var is_timer_active: bool = false
var end: bool = false
var rouletted = false

# Signals
signal time_up
signal time_warning

func _ready():
	# Initialize the timer
	current_time = time_limit
	
	# Set up label properties and positioning
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	time_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	# Use the simplest method - anchor to center and use AutoWrap
	time_label.anchor_left = 0.5
	time_label.anchor_right = 0.5  
	time_label.anchor_top = 0.7  # Slightly below center
	time_label.anchor_bottom = 0.7
	time_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	time_label.grow_vertical = Control.GROW_DIRECTION_BOTH
	
	update_display()
	
	# Set up the timer node
	timer.wait_time = 0.1  # Update every 0.1 seconds for smooth countdown
	timer.timeout.connect(_on_timer_timeout)

func start_timer():
	"""Start the countdown timer"""
	if not end:
		is_timer_active = true
		timer.start()

func stop_timer():
	"""Stop the countdown timer"""
	is_timer_active = false
	current_time = time_limit
	timer.stop()

func pause_timer():
	"""Pause the timer (can be resumed)"""
	timer.paused = true

func resume_timer():
	"""Resume a paused timer"""
	timer.paused = false

func add_time(bonus_time: float):
	"""Add bonus time to the timer"""
	current_time += bonus_time
	if current_time > time_limit:
		current_time = time_limit
	update_display()

func _on_timer_timeout():
	if is_timer_active and not end:
		current_time -= 0.1
		
		# Check if time is up
		if current_time <= 0:
			current_time = 0
			time_up.emit()
			game_over()
			return
		
		# Check for warning time
		if current_time <= warning_time and current_time > warning_time - 0.1:
			time_warning.emit()
		
		update_display()

func update_display():
	"""Update the timer display"""
	var seconds = int(current_time) % 60
	var milliseconds = int((current_time - int(current_time)) * 10)
	
	time_label.text = "%02d.%01d" % [seconds, milliseconds]
	
	# Change color based on time remaining
	if current_time <= warning_time:
		time_label.modulate = Color.RED
		# Optional: Add blinking effect when very low
		if current_time <= 5.0:
			var blink = sin(Time.get_ticks_msec() * 0.01) > 0
			time_label.modulate.a = 1.0 if blink else 0.5
	else:
		time_label.modulate = Color.WHITE

func game_over():
	"""Handle game over scenario"""
	if not rouletted:
		return
	
	get_tree().current_scene.reset()

func restart_game():
	"""Restart the game/level"""
	end = false
	current_time = time_limit
	is_timer_active = false
	update_display()
	
	# Reload the current scene or reset game state
	get_tree().reload_current_scene()

# Optional: Connect to game events
func _on_level_completed():
	"""Call this when player completes the level"""
	stop_timer()
	time_label.text = "LEVEL COMPLETE!"
	time_label.modulate = Color.GREEN

func _on_player_died():
	"""Call this when player dies (optional pause)"""
	pause_timer()

func _on_player_respawned():
	"""Call this when player respawns"""
	resume_timer()
