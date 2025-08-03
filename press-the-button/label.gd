# SimpleTextRoulette.gd
extends Label

var allSegments = ["Spikes","Invert", "Dash", "Wall", "Platform", "Head Hitter", "Crumble Platform", "Dropper", "Start Spikes", "Wall Jump", "Flip Screen", "Wall Higher","Timer"]
var segments = ["Flip Screen", "Dash", "Spikes", "Wall Jump", "Double Jump","Timer"]
var ideas = ["Speedrun Timer","Climb", "Spin Stage continusouly (physics affecting)", "flip screen upside down (visual only)", "lava rising", "button move upwards (prereq for lava rising)", "Circle player physics", "Dark Mode (color ineversion)", "Angry Sun", "Other enemies"] # alternate platform layouts is a good idea too

# Weighted randomization - lower weights = less likely to appear
var segment_weights = {
	"Spikes": 10,
	"Invert": 8,
	"Wall": 10,
	"Platform": 10,
	"Head Hitter": 10,
	"Crumble Platform": 10,
	"Dropper": 10,
	"Start Spikes": 10,
	"Wall Jump": 4,  # Good ability - less likely
	"Wall Higher": 10,
	"Flip Screen": 8,
	"Dash": 3,       # Very good ability - very rare
	"Double Jump": 2, # Excellent ability - extremely rare
	"Timer": 7,
	"Shorten Timer": 9 # Bad effect - more likely
}

var is_spinning = false
var tick_sound: AudioStreamPlayer

@onready var wall_layer = get_node("/root/main/BaseLayer/WallLayer")
@onready var platform_layer = get_node("/root/main/BaseLayer/Platforms")
@onready var platform_layer2 = get_node("/root/main/BaseLayer/Platforms2")
@onready var headhit_layer = get_node("/root/main/BaseLayer/HeadHitters")
@onready var dropper = get_node("/root/main/BaseLayer/Dropper")
@onready var player = get_node("/root/main/Player")
@onready var startLava = get_node("/root/main/BaseLayer/StartLava")
@onready var wall_higher = get_node("/root/main/BaseLayer/WallHigher")
@onready var camera = get_node("/root/main/Camera/Camera2D")
@onready var main = get_node("/root/main")
@onready var timer = get_node("/root/main/UI/TimerControl")
@onready var timeLabel = get_node("/root/main/UI/TimerControl/TimeLabel")

func _ready():
	wall_layer.visible = false
	wall_layer.collision_enabled = false
	platform_layer.visible = false
	platform_layer.collision_enabled = false
	platform_layer2.visible = false
	platform_layer2.collision_enabled = false
	headhit_layer.visible = false
	headhit_layer.collision_enabled = false
	wall_higher.visible = false
	wall_higher.collision_enabled = false
	dropper.visible = false
	startLava.visible = false
	timeLabel.visible = false
	add_to_group("roulette")
	text = ""
	
	# Setup sound player
	setup_sound()

func setup_sound():
	tick_sound = AudioStreamPlayer.new()
	add_child(tick_sound)
	
	tick_sound.stream = load("res://sounds/tick.wav")
	tick_sound.volume_db = 1  # Adjust volume as needed

func play_tick_sound(progress: float = 0.0):
	# Pitch rises from 1.0 to 2.0 as progress goes from 0.0 to 1.0
	tick_sound.pitch_scale = 1.0 + progress
	tick_sound.play()

func get_weighted_random_segment(available_segments: Array) -> String:
	var total_weight = 0
	var weighted_segments = []
	
	# Build weighted array
	for segment in available_segments:
		var weight = segment_weights.get(segment, 5)  # Default weight of 5 if not found
		total_weight += weight
		for i in range(weight):
			weighted_segments.append(segment)
	
	if weighted_segments.size() == 0:
		return available_segments[randi() % available_segments.size()]
	
	return weighted_segments[randi() % weighted_segments.size()]

func spin():
	if segments.size() == 0:
		main.endGame();
		return
	
	if is_spinning:
		return
	
	is_spinning = true
	
	# Quick cycling effect with sound
	for i in range(25):  # Cycle 25 times
		await get_tree().create_timer(0.01 + (i * 0.005)).timeout  # Slow down over time
		text = allSegments[randi() % allSegments.size()]
		var progress = float(i) / 24.0
		play_tick_sound(progress)
	
	# Final result using weighted randomization
	var final_result = get_weighted_random_segment(segments)
	text = final_result
	is_spinning = false
	
	segments.erase(final_result)
	print("Final result: ", final_result)
	apply_effect(final_result)
	
func spinGood():
	if is_spinning or segments.size() == 0:
		return
	
	is_spinning = true
	
	# Quick cycling effect with sound
	for i in range(25):  # Cycle 25 times
		await get_tree().create_timer(0.01 + (i * 0.005)).timeout  # Slow down over time
		text = allSegments[randi() % allSegments.size()]
		var progress = float(i) / 24.0
		play_tick_sound(progress)
	
	# Final result using weighted randomization
	var final_result = get_weighted_random_segment(segments)
	
	if not segments.has("Invert"): #re-add to list if you complete level
		segments.append("Invert")
		
	text = final_result
	is_spinning = false
	
	segments.erase(final_result)
	print("Final result: ", final_result)
	apply_effect(final_result)

func apply_effect(result: String):
	# Your effect logic here
	match result:
		"Spikes":
			var spike = get_node("/root/main/spikeTrap")
			spike.emerge()
			segments.append("Wall")
			segments.append("Start Spikes")
			pass
		"Start Spikes":
			startLava.visible = true
			startLava.killEnabled = true
		"Wall":
			wall_layer.visible = true
			wall_layer.collision_enabled = true
			segments.append("Platform")
			pass
		"Platform":
			segments.append("Crumble Platform")
			match(randi() % 2):
				0:
					platform_layer.visible = true
					platform_layer.collision_enabled = true
					segments.append("Head Hitter")
					if player.dash:
						segments.append("Dropper")
					pass
				1:
					platform_layer2.visible = true
					platform_layer2.collision_enabled = true
					segments.append("Wall Higher")
					pass
			pass
		"Head Hitter":
			headhit_layer.visible = true
			headhit_layer.collision_enabled = true
			pass
		"Crumble Platform":
			if platform_layer.visible:
				platform_layer.crumble = true;
			elif platform_layer2.visible:
				platform_layer2.crumble = true;
			pass
		"Invert":
			player.invert = not player.invert
			pass
		"Dash":
			player.dash = true
			if platform_layer.visible == true and dropper.visible == false:
				segments.append("Dropper")
			pass
		"Dropper":
			dropper.visible = true
			dropper.killEnabled = true
			pass
		"Wall Jump":
			player.wall_jump = true
			pass
		"Wall Higher":
			wall_higher.visible = true
			wall_higher.collision_enabled = true
			pass
		"Flip Screen":
			camera.scale.x = -1
			pass
		"Double Jump":
			player.double = true
			pass
		"Timer":
			timer.rouletted = true
			timeLabel.visible = true
			segments.append("Shorten Timer")
			pass
		"Shorten Timer":
			timer.time_limit /= 1.25
			if timer.time_limit > 10:
				segments.append("Shorten Timer")
