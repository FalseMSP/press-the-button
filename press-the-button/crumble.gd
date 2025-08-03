# CrumblingTileMapLayer.gd
extends TileMapLayer

@export var crumble_delay = 0.5  # Time before crumbling
@export var warning_shake_intensity = 2.0
@export var crumble_tile_source_id = 0  # Which tileset source can crumble (-1 for all sources)
@export var check_distance = 48  # How close player needs to be to activate

var player: CharacterBody2D
var crumbling_tiles = {}  # Dictionary to track each tile's state
var original_positions = {}  # Store original positions for shaking
var original_tile_layout = {}
var crumble = false;

# Tile state structure:
# {
#   "timer": float,
#   "is_shaking": bool,
#   "original_pos": Vector2
# }

func _ready():
	# Find the player
	player = get_tree().get_first_node_in_group("player")
	store_original_layout()
	if not player:
		# Try common player names
		player = get_node_or_null("../Player")
		if not player:
			player = get_node_or_null("../../Player")
		if not player:
			# Search more thoroughly
			player = find_player_in_tree(get_tree().root)
	
	if player:
		print("Player found: ", player.name, " at ", player.global_position)
	else:
		print("ERROR: Player still not found!")

func store_original_layout():
	# Store all existing tiles in the layer
	original_tile_layout.clear()
	# Get the bounds of the tilemap to scan all tiles
	var used_rect = get_used_rect()
	
	print("Storing original layout. Used rect: ", used_rect)
	
	for x in range(used_rect.position.x, used_rect.position.x + used_rect.size.x):
		for y in range(used_rect.position.y, used_rect.position.y + used_rect.size.y):
			var tile_pos = Vector2i(x, y)
			var source_id = get_cell_source_id(tile_pos)

			# Only store tiles that actually exist
			if source_id != -1:
				var atlas_coords = get_cell_atlas_coords(tile_pos)
				var alternative_tile = get_cell_alternative_tile(tile_pos)
				original_tile_layout[tile_pos] = {
					"source_id": source_id,
					"atlas_coords": atlas_coords,
					"alternative_tile": alternative_tile
				}
	
	print("Stored ", original_tile_layout.size(), " tiles in original layout")


func find_player_in_tree(node: Node) -> Node:
	# Recursively search for player
	if node.name.to_lower().contains("player"):
		return node
	
	for child in node.get_children():
		var result = find_player_in_tree(child)
		if result:
			return result
	return null

var shake_time = 0.0  # Add this at the top with other variables

func _process(delta):
	if not player or not crumble:
		return
	
	shake_time += delta  # Update shake timer
		
	var player_grid_pos = local_to_map(to_local(player.global_position))
	
	# Check tiles around player position
	check_tiles_around_player(player_grid_pos, delta)
	
	# Update existing crumbling tiles
	update_crumbling_tiles(delta)

func check_tiles_around_player(player_pos: Vector2i, delta: float):
	# Check in a radius around player
	var check_radius = 2  # Check 2 tiles in each direction
	
	for x in range(player_pos.x - check_radius, player_pos.x + check_radius + 1):
		for y in range(player_pos.y - check_radius, player_pos.y + check_radius + 1):
			var tile_pos = Vector2i(x, y)
			
			# Skip if no tile at this position
			var source_id = get_cell_source_id(tile_pos)
			if source_id == -1:
				continue
			
			# Check if this is a crumbleable tile
			if not is_crumbleable_tile(tile_pos):
				continue
				
			# Check if player is standing on this tile (player is one tile above)
			var tile_above = Vector2i(x, y - 2)
			var tile_above_left = Vector2i(x-1, y - 2)
			var tile_above_right = Vector2i(x+1, y - 2)
			if player_pos == tile_above or player_pos == tile_above_left or player_pos == tile_above_right:
				handle_player_on_tile(tile_pos, delta)
			# Don't reset timer if player leaves - let it continue crumbling!

func handle_player_on_tile(tile_pos: Vector2i, delta: float):
	
	# Initialize tile state if not exists
	if tile_pos not in crumbling_tiles:
		crumbling_tiles[tile_pos] = {
			"timer": 0.0,
			"is_shaking": false,
			"original_pos": map_to_local(tile_pos)
		}
	
	# Timer is now updated in update_crumbling_tiles() so it continues even if player leaves
	var tile_data = crumbling_tiles[tile_pos]

func update_crumbling_tiles(delta: float):
	var tiles_to_remove = []
	
	for tile_pos in crumbling_tiles:
		var tile_data = crumbling_tiles[tile_pos]
		
		# Continue timer even if player left
		tile_data.timer += delta
		
		# Start shaking halfway through delay
		if tile_data.timer > crumble_delay * 0.5 and not tile_data.is_shaking:
			start_tile_shaking(tile_pos)
		
		# Crumble when timer reaches delay
		if tile_data.timer >= crumble_delay:
			tiles_to_remove.append(tile_pos)
			crumble_tile(tile_pos)
		
		# Continue shaking effect
		elif tile_data.is_shaking:
			shake_tile(tile_pos)
	
	# Remove tiles that have crumbled
	for tile_pos in tiles_to_remove:
		if tile_pos in crumbling_tiles:
			crumbling_tiles.erase(tile_pos)

func is_crumbleable_tile(tile_pos: Vector2i) -> bool:
	var source_id = get_cell_source_id(tile_pos)
	
	# If source_id is -1, there's no tile here
	if source_id == -1:
		return false
	
	# If crumble_tile_source_id is -1, all tiles are crumbleable
	if crumble_tile_source_id == -1:
		return true
	
	# Otherwise, only tiles from the specified source are crumbleable
	return source_id == crumble_tile_source_id

func start_tile_shaking(tile_pos: Vector2i):
	if tile_pos in crumbling_tiles:
		crumbling_tiles[tile_pos].is_shaking = true
		# Play warning sound
		play_crumble_warning_sound()

func shake_tile(tile_pos: Vector2i):
	# Create visual warning by modulating the color
	var warning_intensity = sin(shake_time * 20) * 0.5 + 0.5
	modulate = Color(1.0, 1.0 - warning_intensity * 0.3, 1.0 - warning_intensity * 0.3)

func crumble_tile(tile_pos: Vector2i):
	# Remove the tile
	set_cell(tile_pos, -1)
	
	# Create falling debris effect
	create_falling_debris(tile_pos)
	
	# Play crumble sound
	play_crumble_sound()
	
	# Remove from tracking
	if tile_pos in crumbling_tiles:
		crumbling_tiles.erase(tile_pos)
	
	# Reset modulation if no more shaking tiles
	if crumbling_tiles.is_empty():
		modulate = Color.WHITE

func reset_tile(tile_pos: Vector2i):
	if tile_pos in crumbling_tiles:
		crumbling_tiles.erase(tile_pos)
	
	# Reset modulation if no more tiles are shaking
	if crumbling_tiles.is_empty():
		modulate = Color.WHITE

func create_falling_debris(tile_pos: Vector2i):
	# Create visual debris effect
	var world_pos = to_global(map_to_local(tile_pos))
	
	# Create multiple small debris pieces
	for i in range(4):
		var debris = create_debris_piece()
		get_parent().add_child(debris)
		debris.global_position = world_pos + Vector2(randf_range(-16, 16), randf_range(-16, 16))
		
		# Animate debris falling
		var tween = create_tween()
		tween.parallel().tween_property(debris, "global_position:y", debris.global_position.y + 200, 1.0)
		tween.parallel().tween_property(debris, "modulate:a", 0.0, 1.0)
		tween.tween_callback(debris.queue_free)

func create_debris_piece() -> Node2D:
	var debris = Sprite2D.new()
	
	# Create a small square texture for debris
	var image = Image.create(4, 4, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.6, 0.4, 0.2))  # Brown debris color
	var texture = ImageTexture.new()
	texture.set_image(image)
	
	debris.texture = texture
	debris.scale = Vector2(randf_range(0.5, 1.5), randf_range(0.5, 1.5))
	
	return debris

func play_crumble_warning_sound():
	# Play warning sound - replace with your audio file
	var audio = AudioStreamPlayer2D.new()
	# audio.stream = preload("res://audio/crumble_warning.ogg")
	add_child(audio)
	# audio.play()
	
	# Remove after playing
	var timer = Timer.new()
	timer.wait_time = 1.0
	timer.one_shot = true
	timer.timeout.connect(func(): 
		if audio and is_instance_valid(audio):
			audio.queue_free()
		if timer and is_instance_valid(timer):
			timer.queue_free()
	)
	add_child(timer)
	timer.start()

func play_crumble_sound():
	# Play crumble sound - replace with your audio file
	var audio = AudioStreamPlayer2D.new()
	# audio.stream = preload("res://audio/tile_crumble.ogg")
	add_child(audio)
	# audio.play()
	
	# Remove after playing
	var timer = Timer.new()
	timer.wait_time = 2.0
	timer.one_shot = true
	timer.timeout.connect(func(): 
		if audio and is_instance_valid(audio):
			audio.queue_free()
		if timer and is_instance_valid(timer):
			timer.queue_free()
	)
	add_child(timer)
	timer.start()

func reset_all_tiles():
	crumbling_tiles.clear()
	modulate = Color.WHITE
	
	restore_all_tiles()

func restore_all_tiles():
	# Restore all tiles from the original layout
	print("Restoring all tiles...")
	var restored_count = 0
	
	for tile_pos in original_tile_layout:
		var tile_data = original_tile_layout[tile_pos]
		set_cell(tile_pos, tile_data.source_id, tile_data.atlas_coords, tile_data.alternative_tile)
		restored_count += 1
	
	print("Restored ", restored_count, " tiles")
