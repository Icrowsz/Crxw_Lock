class_name PerspectivePitch
extends Control
## Campo em perspectiva (trapezoide) para a tela de formação: vista "de trás do gol".
## Desenha o campo (listras, círculo, áreas, gols), as bolinhas dos jogadores e permite:
##  - arrastar as bolinhas do time da vez (emite slot_dragged),
##  - hover (realce),
##  - clique simples (slot_clicked),
##  - duplo clique (slot_double_clicked, para abrir o seletor de personagem).
##
## O campo pode ser "flipado" (flip_to): a perspectiva gira para o outro time editar.

signal slot_dragged(target: Node2D, new_global: Vector2)
signal slot_double_clicked(target: Node2D)
signal slot_clicked(target: Node2D)

const PAD: float = 34.0
const TOP_WIDTH_RATIO: float = 0.58      # o quão mais estreito o topo é em relação à base
const BOTTOM_INSET: float = 0.05

const GRASS_DARK := Color(0.09, 0.26, 0.13)
const GRASS_LIGHT := Color(0.13, 0.34, 0.17)
const LINE_COLOR := Color(1, 1, 1, 0.62)
const BORDER_COLOR := Color(0.95, 1.0, 0.92, 0.85)
const DOT_HOVER_RING := Color.WHITE
const DOT_RADIUS := 13.0
const HIT_RADIUS := 26.0

var field: Field
var team: int = 0
var team_color: Color = Color(0.9, 0.22, 0.27)
var enemy_color: Color = Color(0.11, 0.44, 0.88)
var targets: Array[Node2D] = []          # jogadores + goleiro do time + adversários (só visual)
var slot_marks: Array[Vector2] = []      # marcas de formação (globais)

var flipped: bool = false
var hover_index: int = -1
var drag_index: int = -1


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true


# ---------- MAPEAMENTO (campo <-> tela) ----------

func _norm_to_screen(nx: float, ny: float) -> Vector2:
	# nx: -1 = gol do time (perto), +1 = gol inimigo (longe); ny: -1 = esquerda, +1 = direita
	if flipped:
		nx = -nx
	var t: float = clampf((nx + 1.0) * 0.5, 0.0, 1.0)
	var w: float = size.x - PAD * 2.0
	var h: float = size.y - PAD * 2.0
	var top_w: float = w * TOP_WIDTH_RATIO
	var bot_w: float = w * (1.0 - BOTTOM_INSET * 2.0)
	var cur_w: float = lerpf(bot_w, top_w, t)
	var cx: float = size.x * 0.5
	var y: float = PAD + h - h * t
	return Vector2(cx + ny * cur_w * 0.5, y)


func _global_to_screen(gp: Vector2) -> Vector2:
	if field == null:
		return Vector2.ZERO
	var l: Vector2 = field.to_local(gp)
	var nx: float = l.x / (field.pitch_size.x * 0.5)
	var ny: float = l.y / (field.pitch_size.y * 0.5)
	return _norm_to_screen(nx, ny)


func _screen_to_global(sp: Vector2) -> Vector2:
	if field == null:
		return Vector2.ZERO
	var w: float = size.x - PAD * 2.0
	var h: float = size.y - PAD * 2.0
	var top_w: float = w * TOP_WIDTH_RATIO
	var bot_w: float = w * (1.0 - BOTTOM_INSET * 2.0)
	var t: float = clampf((PAD + h - sp.y) / h, 0.0, 1.0)
	var cur_w: float = lerpf(bot_w, top_w, t)
	var nx: float = t * 2.0 - 1.0
	var ny: float = (sp.x - size.x * 0.5) / (cur_w * 0.5)
	if flipped:
		nx = -nx
	var l: Vector2 = Vector2(nx * field.pitch_size.x * 0.5, ny * field.pitch_size.y * 0.5)
	return field.to_global(l)


# ---------- INTERAÇÃO ----------

func _is_mine(t: Node2D) -> bool:
	if t is Goalkeeper:
		return (t as Goalkeeper).team == team
	if t is Player:
		return (t as Player).team == team
	return false


func _index_at(screen_pos: Vector2) -> int:
	var best: int = -1
	var best_d: float = HIT_RADIUS
	for i in targets.size():
		if not is_instance_valid(targets[i]):
			continue
		var p: Vector2 = _global_to_screen(targets[i].global_position)
		var d: float = p.distance_to(screen_pos)
		if d < best_d:
			best = i
			best_d = d
	return best


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var local: Vector2 = (event as InputEventMouseMotion).position
		if drag_index >= 0 and drag_index < targets.size() and is_instance_valid(targets[drag_index]):
			slot_dragged.emit(targets[drag_index], _screen_to_global(local))
			queue_redraw()
		else:
			var idx: int = _index_at(local)
			if idx != hover_index:
				hover_index = idx
				mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if idx >= 0 \
					else Control.CURSOR_ARROW
				queue_redraw()
	elif event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				var idx: int = _index_at(mb.position)
				if idx >= 0:
					if mb.double_click:
						slot_double_clicked.emit(targets[idx])
						accept_event()
					elif _is_mine(targets[idx]):
						drag_index = idx
						slot_clicked.emit(targets[idx])
						accept_event()
			else:
				if drag_index >= 0:
					drag_index = -1
					accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT and hover_index != -1:
		hover_index = -1
		queue_redraw()


# ---------- FLIP ANIMADO ----------

func flip_to(new_flipped: bool) -> void:
	if flipped == new_flipped:
		return
	pivot_offset = size * 0.5
	var tw := create_tween()
	tw.tween_property(self, "scale:x", 0.0, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void:
		flipped = new_flipped
		queue_redraw())
	tw.tween_property(self, "scale:x", 1.0, 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void: UiStyle.jelly(self, 1.05, 0.4))


# ---------- DESENHO ----------

func _draw() -> void:
	if field == null or size.x < 4.0 or size.y < 4.0:
		return
	var w: float = size.x - PAD * 2.0
	var h: float = size.y - PAD * 2.0
	var top_w: float = w * TOP_WIDTH_RATIO
	var bot_w: float = w * (1.0 - BOTTOM_INSET * 2.0)
	var bl := Vector2(size.x * 0.5 - bot_w * 0.5, PAD + h)
	var br := Vector2(size.x * 0.5 + bot_w * 0.5, PAD + h)
	var tl := Vector2(size.x * 0.5 - top_w * 0.5, PAD)
	var tr := Vector2(size.x * 0.5 + top_w * 0.5, PAD)

	# Sombra externa
	draw_colored_polygon(PackedVector2Array([bl + Vector2(-6, 8), br + Vector2(6, 8),
		tr + Vector2(6, 4), tl + Vector2(-6, 4)]), Color(0, 0, 0, 0.35))

	# Grama
	draw_colored_polygon(PackedVector2Array([bl, br, tr, tl]), GRASS_DARK)

	# Listras (no sentido do comprimento)
	var stripes: int = 12
	for i in stripes:
		if i % 2 == 1:
			continue
		var a: float = -1.0 + 2.0 * float(i) / float(stripes)
		var b: float = -1.0 + 2.0 * float(i + 1) / float(stripes)
		var p1: Vector2 = _norm_to_screen(a, -1.0)
		var p2: Vector2 = _norm_to_screen(b, -1.0)
		var p3: Vector2 = _norm_to_screen(b, 1.0)
		var p4: Vector2 = _norm_to_screen(a, 1.0)
		draw_colored_polygon(PackedVector2Array([p1, p2, p3, p4]), Color(1, 1, 1, 0.045))

	# Linha do meio (levemente curvada — no trapezoide fica uma reta entre os pontos)
	draw_line(_norm_to_screen(0.0, -1.0), _norm_to_screen(0.0, 1.0), LINE_COLOR, 2.0)

	# Círculo central (elipse)
	_draw_ellipse(Vector2.ZERO, 0.18, 1.0, LINE_COLOR)

	# Áreas
	_draw_rect_field(-1.0, -0.60, -0.70, 0.60, LINE_COLOR)
	_draw_rect_field(-1.0, -0.32, -0.88, 0.32, LINE_COLOR)
	_draw_rect_field(0.70, -0.60, 1.0, 0.60, LINE_COLOR)
	_draw_rect_field(0.88, -0.32, 1.0, 0.32, LINE_COLOR)

	# Gols
	_draw_goal(-1.0, LINE_COLOR)
	_draw_goal(1.0, LINE_COLOR)

	# Borda do campo
	draw_polyline(PackedVector2Array([bl, br, tr, tl, bl]), BORDER_COLOR, 2.5)

	# Marcas de formação
	for s in slot_marks:
		var p: Vector2 = _global_to_screen(s)
		draw_arc(p, 15.0, 0.0, TAU, 24, Color(1, 1, 1, 0.42), 2.0)

	# Bolinhas
	var font: Font = ThemeDB.fallback_font
	for i in targets.size():
		var t: Node2D = targets[i]
		if not is_instance_valid(t):
			continue
		var p: Vector2 = _global_to_screen(t.global_position)
		var is_keeper: bool = t is Goalkeeper
		var mine: bool = _is_mine(t)
		var col: Color = team_color if mine else enemy_color
		var strong: bool = i == hover_index or i == drag_index
		var r: float = DOT_RADIUS + (3.0 if strong else 0.0)

		draw_circle(p + Vector2(0.0, 3.0), r + 2.0, Color(0, 0, 0, 0.42))
		draw_circle(p, r, col)
		draw_arc(p, r, 0.0, TAU, 26,
			DOT_HOVER_RING if strong else Color(1, 1, 1, 0.75), 3.0 if strong else 1.6)
		if is_keeper:
			draw_arc(p, r + 4.0, 0.0, TAU, 26, Color(0.98, 0.98, 0.5, 0.85), 2.0)

		var txt: String = "G" if is_keeper else str(_slot_number(t))
		draw_string_outline(font, p + Vector2(-9.0, 5.0), txt,
			HORIZONTAL_ALIGNMENT_CENTER, 18.0, 13, 4, Color(0, 0, 0, 0.9))
		draw_string(font, p + Vector2(-9.0, 5.0), txt,
			HORIZONTAL_ALIGNMENT_CENTER, 18.0, 13, Color.WHITE)


func _draw_rect_field(x0: float, y0: float, x1: float, y1: float, col: Color) -> void:
	var p1: Vector2 = _norm_to_screen(x0, y0)
	var p2: Vector2 = _norm_to_screen(x1, y0)
	var p3: Vector2 = _norm_to_screen(x1, y1)
	var p4: Vector2 = _norm_to_screen(x0, y1)
	draw_polyline(PackedVector2Array([p1, p2, p3, p4, p1]), col, 2.0)


func _draw_ellipse(center: Vector2, radius_x: float, radius_y: float, col: Color) -> void:
	var segments: int = 40
	var pts := PackedVector2Array()
	for i in segments + 1:
		var a: float = TAU * float(i) / float(segments)
		pts.append(_norm_to_screen(center.x + cos(a) * radius_x, center.y + sin(a) * radius_y))
	draw_polyline(pts, col, 2.0)


func _draw_goal(goal_nx: float, col: Color) -> void:
	var out_nx: float = goal_nx + (0.06 if goal_nx > 0.0 else -0.06)
	_draw_rect_field(goal_nx, -0.16, out_nx, 0.16, Color(0.95, 0.95, 0.95, 0.85))
	_draw_rect_field(minf(goal_nx, out_nx), -0.02, maxf(goal_nx, out_nx), 0.02, col)


func _slot_number(t: Node2D) -> int:
	return maxi(1, targets.find(t) + 1)
