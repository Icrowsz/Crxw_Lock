class_name CopyBeeFX
extends RefCounted

const YELLOW := Color(1.0, 0.85, 0.2)
const BLACK := Color(0.1, 0.1, 0.1)
const PURPLE := Color(0.65, 0.3, 0.95)
const PURPLE_DARK := Color(0.3, 0.05, 0.5)

## Cria uma vespa flutuando em volta do jogador e a remove após "duration" segundos
static func spawn_wasp(player: Node2D, duration: float = 3.5) -> void:
	if player == null or not player.is_inside_tree(): return
	var wasp := Wasp.new()
	player.add_child(wasp)
	
	# O nó se autodestrói depois do tempo
	player.get_tree().create_timer(duration).timeout.connect(func():
		if is_instance_valid(wasp):
			wasp.queue_free()
	)

## Cria a pantera roxa correndo com a bola
static func panther(from: Node, ball: Ball) -> void:
	if from == null or not from.is_inside_tree() or ball == null: return
	var p := Panther.new()
	p.target = ball
	var scene := from.get_tree().current_scene
	scene.add_child(p)

## A vespa (desenhada por código)
class Wasp extends Node2D:
	var _time: float = 0.0
	func _ready() -> void:
		z_index = 5
	func _process(delta: float) -> void:
		_time += delta
		position = Vector2(cos(_time * 3.0) * 25.0, -45.0 + sin(_time * 5.0) * 10.0)
		queue_redraw()
	func _draw() -> void:
		draw_circle(Vector2(0, -5), 6.0, Color(1, 1, 1, 0.6))
		draw_circle(Vector2(-4, 0), 6.0, Color(1, 1, 1, 0.6))
		draw_rect(Rect2(-5, -2, 10, 12), YELLOW)
		draw_rect(Rect2(-5, 2, 10, 3), BLACK)
		draw_rect(Rect2(-5, 8, 10, 3), BLACK)
		draw_line(Vector2(0, 10), Vector2(0, 14), BLACK, 2.0)

## A pantera (desenhada por código, correndo com a bola)
class Panther extends Node2D:
	var target: Ball 
	var _time: float = 0.0
	
	func _ready() -> void:
		z_index = -1
		top_level = true
		
	func _process(delta: float) -> void:
		if not is_instance_valid(target):
			queue_free()
			return
		_time += delta
		global_position = target.global_position + Vector2(0, -target.height)
		rotation = target.velocity.angle() if target.velocity.length() > 10 else rotation
		queue_redraw()
		
	func _draw() -> void:
		var pts := PackedVector2Array([
			Vector2(-30, -10), Vector2(30, -10), Vector2(40, 0), 
			Vector2(30, 10), Vector2(-30, 10), Vector2(-40, 0)
		])
		draw_colored_polygon(pts, Color(PURPLE, 0.8))
		draw_polyline(pts + PackedVector2Array([pts[0]]), Color(PURPLE_DARK, 0.9), 2.0)
		var leg_offset = sin(_time * 30.0) * 8.0
		draw_line(Vector2(-20, 10), Vector2(-20 + leg_offset, 25), PURPLE_DARK, 4.0)
		draw_line(Vector2(20, 10), Vector2(20 - leg_offset, 25), PURPLE_DARK, 4.0)
		draw_circle(Vector2(35, -15), 12.0, Color(PURPLE, 0.8))
		draw_circle(Vector2(35, -15), 12.0, Color(PURPLE_DARK, 0.9), false, 2.0)
		draw_circle(Vector2(40, -18), 2.0, YELLOW)
