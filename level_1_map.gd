extends Node

func _ready() -> void:
	$tile_layers/ground.tile_set = ResourceCache.Tileset
	$tile_layers/ground_decoration.tile_set = ResourceCache.Tileset
	$tile_layers/building_decoration.tile_set = ResourceCache.Tileset
	$tile_layers/building_obstacles_1.tile_set = ResourceCache.Tileset
	$tile_layers/building_obstacles_2.tile_set = ResourceCache.Tileset
	$tile_layers/decoration.tile_set = ResourceCache.Tileset
