extends Node2D

@onready var player = $Player
@onready var Roulette = $UI/Roulette
@onready var platform = $BaseLayer/Platforms
@onready var platform2 = $BaseLayer/Platforms2
@onready var endScreen = $EndScreen
@onready var ui = $UI
@onready var sb = $UI/Scoreboard
@onready var timer = $UI/TimerControl
@onready var timeLabel = $UI/TimerControl/TimeLabel

func reset():
	Roulette.spin();
	player.reset();	
	platform.reset_all_tiles()
	platform2.reset_all_tiles()
	timer.stop_timer()
	timer.start_timer()
	pass
	
func complete():
	Roulette.spinGood();
	player.reset();	
	platform.reset_all_tiles()
	platform2.reset_all_tiles()
	timer.stop_timer()
	timer.start_timer()
	
func endGame():
	endScreen.visible = true
	ui.show_end_screen()
	Roulette.visible = false
	player.visible = false
	sb.visible = false
	timer.stop_timer()
	timeLabel.visible = false
	pass
