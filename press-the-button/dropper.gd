extends TileMapLayer

@export var lethal_tile_source_id := -1  # -1 means all tiles are lethal
@export var kill_distance := 48.0
var player: CharacterBody2D
var killEnabled = false

func _ready():
	# Find the player
	player = get_node("/root/main/Player")
	if player:
		print("Player found: ", player.name, " at ", player.global_position)
	else:
		print("ERROR: Player still not found!")
		
	collision_enabled = false
	# Set permanent red tint
	modulate = Color(1.0, 0.0, 0.0)

func _process(delta):
	if not player or not killEnabled:
		return
	
	# Get player's collision shape
	var collision_shape = get_player_collision_shape()
	if not collision_shape:
		print("No collision shape found on player")
		return
	
	var player_pos = player.global_position
	var shape = collision_shape.shape
	var shape_position = player_pos + collision_shape.position
	
	# Get hitbox bounds based on shape type
	var hitbox_size = get_shape_size(shape)
	var hitbox_half_size = hitbox_size * 0.5
	
	# Calculate the area the hitbox covers in local tile coordinates
	var top_left_world = shape_position - hitbox_half_size
	var bottom_right_world = shape_position + hitbox_half_size
	
	var top_left_local = to_local(top_left_world)
	var bottom_right_local = to_local(bottom_right_world)
	
	var top_left_tile = local_to_map(top_left_local)
	var bottom_right_tile = local_to_map(bottom_right_local)
	
	# Check all tiles the hitbox overlaps
	for x in range(top_left_tile.x, bottom_right_tile.x + 1):
		for y in range(top_left_tile.y, bottom_right_tile.y + 1):
			var tile_pos = Vector2i(x, y)
			if is_lethal_tile(tile_pos):
				kill_player()
				return

func get_player_collision_shape() -> CollisionShape2D:
	# Look for CollisionShape2D in player and its children
	if player.has_method("get_children"):
		for child in player.get_children():
			if child is CollisionShape2D:
				return child
	return null

func get_shape_size(shape: Shape2D) -> Vector2:
	if shape is RectangleShape2D:
		return (shape as RectangleShape2D).size
	elif shape is CapsuleShape2D:
		var capsule = shape as CapsuleShape2D
		return Vector2(capsule.radius * 2, capsule.height)
	elif shape is CircleShape2D:
		var radius = (shape as CircleShape2D).radius
		return Vector2(radius * 2, radius * 2)
	else:
		# Default fallback size
		return Vector2(32, 48)  # Common character size

func is_lethal_tile(tile_pos: Vector2i) -> bool:
	var source_id = get_cell_source_id(tile_pos)
	if source_id == -1:
		return false
	if lethal_tile_source_id == -1:
		return true
	return source_id == lethal_tile_source_id

func kill_player():
	if player and player.is_inside_tree():
		get_tree().current_scene.reset()
