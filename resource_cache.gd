extends Node

const Tileset = preload("res://level/map/level1.tres")

@export var player_sprites = {
	"Bob": preload("res://player/cats/Bob/Bob_anim.tres"),
	"Tuna": preload("res://player/cats/Tuna/Tuna_anim.tres"),
	"Kiki": preload("res://player/cats/Kiki/Kiki_anim.tres"),
	"Rupert": preload("res://player/cats/Rupert/Rupert_anim.tres"),
}

@export var jail_door = {
	"open": preload("res://level/map/jail_door_open.png"),
	"closed": preload("res://level/map/jail_door_close.png"),
}

@export var fence_door = {
	"blue_open": preload("res://level/map/blue_fence_door_open.png"),
	"blue_closed": preload("res://level/map/blue_fence_door_close.png"),
	"brown_open": preload("res://level/map/brown_fence_door_open.png"),
	"brown_closed": preload("res://level/map/brown_fence_door_close.png"),
}
