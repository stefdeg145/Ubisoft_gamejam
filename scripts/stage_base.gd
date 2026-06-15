extends Node2D
class_name StageBase
## Shared scaffolding for the dream-stage levels: a side-view background, bounding
## walls, the player, and helpers to drop in props and interactables. Each stage
## extends this and implements its own little mechanic in _ready().

const PlayerScene := preload("res://scenes/actors/player.tscn")
const Interactable := preload("res://scripts/interactable.gd")

var player: CharacterBody2D
var view_size := Vector2(1280, 720)

func setup_sideview(bg_path: String, bg_scale := 8.0) -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var bg := Sprite2D.new()
	bg.texture = load(bg_path)
	bg.centered = false
	bg.scale = Vector2(bg_scale, bg_scale)
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(bg)
	# left / right bounds
	_wall(-24, 0, 24, view_size.y)
	_wall(view_size.x, 0, 24, view_size.y)

func _wall(x: float, y: float, w: float, h: float) -> void:
	var b := StaticBody2D.new()
	var cs := CollisionShape2D.new()
	var s := RectangleShape2D.new()
	s.size = Vector2(w, h)
	cs.shape = s
	cs.position = Vector2(x + w / 2.0, y + h / 2.0)
	b.add_child(cs)
	add_child(b)

func spawn_player(pos: Vector2, lock_vertical := false) -> void:
	player = PlayerScene.instantiate()
	player.position = pos
	player.can_move = false
	player.lock_vertical = lock_vertical
	add_child(player)

func add_prop(tex_path: String, x: float, y: float, s := 4.0, centered := true) -> Sprite2D:
	var sp := Sprite2D.new()
	sp.texture = load(tex_path)
	sp.centered = centered
	sp.position = Vector2(x, y)
	sp.scale = Vector2(s, s)
	sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sp)
	return sp

func add_interactable(x: float, y: float, radius := 70.0, prompt := "") -> Area2D:
	var area := Area2D.new()
	area.set_script(Interactable)
	area.prompt = prompt
	area.position = Vector2(x, y)
	var cs := CollisionShape2D.new()
	var sh := CircleShape2D.new()
	sh.radius = radius
	cs.shape = sh
	area.add_child(cs)
	add_child(area)
	return area

## Resolve the stage: warm the house one notch and wake back into it.
func finish(stage_name: String, fragment: String) -> void:
	GameState.complete_stage(stage_name, fragment)
	await Game.fade_out(1.6)
	Game.change_scene("res://scenes/house/house.tscn")
