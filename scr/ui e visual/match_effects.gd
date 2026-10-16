class_name MatchEffects
extends CanvasLayer
## Efeitos visuais da partida (o MatchManager cria este nó sozinho: show_match_effects):
##  - APRESENTAÇÃO DE INÍCIO: os dois selos entram dos lados, "VS", e a partida começa.
##  - ANIMAÇÃO DE GOL: flash, faixa na cor do time com "GOL!", selo, autor, assistência, placar,
##    confete e a torcida pulando (veja Crowd).
##  - AVISO DE TEMPO: faixa no 2º tempo e na prorrogação.
##  - TELA FINAL: selo (logo) de cada time com o placar, vencedor em destaque e o MVP ao lado,
##    com confete e o botão "Jogar novamente".
##  - TORCIDA e brilho no gramado: o Crowd é colocado como filho do Field.
##
## As cores, nomes e ícones vêm do TeamStyle (o que o jogador escolheu na formação).

signal intro_finished

var manager: MatchManager

@export var intro_time: float = 3.0       # duração da apresentação de início (s); clique pula
@export var goal_time: float = 3.0        # duração da animação de gol (s)
@export var show_end_card: bool = true    # tela final própria (logo dos times + MVP)


var _intro_root: Control
var _intro_done: bool = true
var _goal_until_msec: int = 0
var _end_root: Control


func _ready() -> void:
	layer = 30   # acima do placar e da formação
	if manager == null:
		return
	manager.goal_scored.connect(_on_goal_scored)
	manager.half_started.connect(_on_half_started)
	manager.extra_time_started.connect(_on_extra_time_started)
	manager.match_ended.connect(_on_match_ended)
	manager.formation_started.connect(_clear_end_card)


func _screen() -> Vector2:
	return get_viewport().get_visible_rect().size


func _team_name(team: int) -> String:
	return manager.get_team_name(team)


## Texto com contorno (fica legível sobre qualquer fundo)
func _label(text: String, size: int, color: Color = Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", maxi(size / 9, 3))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _full_rect(c: Control) -> void:
	c.set_anchors_preset(Control.PRESET_FULL_RECT)


func _badge(team: int, px: float) -> TeamBadge:
	var b: TeamBadge = TeamBadge.make(team, px, manager.get_default_team_name(team))
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return b


## Torcida + brilho do gramado, como filha do campo



# ---------- APRESENTAÇÃO DE INÍCIO ----------

## O MatchManager espera isto antes de começar o primeiro turno. Clicar pula.
func play_intro() -> void:
	if intro_time <= 0.0 or manager == null:
		return
	_build_intro()
	_intro_done = false
	get_tree().create_timer(intro_time).timeout.connect(_finish_intro)
	await intro_finished


func _build_intro() -> void:
	if _intro_root != null:
		_intro_root.queue_free()
	var screen: Vector2 = _screen()
	var team_a: int = 0
	var team_b: int = mini(1, manager.team_count - 1)

	_intro_root = Control.new()
	_full_rect(_intro_root)
	_intro_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_intro_root.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			_finish_intro())
	add_child(_intro_root)

	# Fundo dividido na diagonal, nas cores dos dois times
	var bg := _VersusBg.new()
	_full_rect(bg)
	bg.left_color = TeamStyle.color_of(team_a).darkened(0.3)
	bg.right_color = TeamStyle.color_of(team_b).darkened(0.3)
	_intro_root.add_child(bg)
	create_tween().tween_property(bg, "progress", 1.0, 0.55) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	# Os dois times entram deslizando dos lados
	for i in 2:
		var team: int = team_a if i == 0 else team_b
		var half := CenterContainer.new()
		half.anchor_left = 0.0 if i == 0 else 0.5
		half.anchor_right = 0.5 if i == 0 else 1.0
		half.anchor_top = 0.0
		half.anchor_bottom = 1.0
		half.offset_left = -screen.x * 0.6 if i == 0 else screen.x * 0.6
		half.offset_right = half.offset_left
		half.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_intro_root.add_child(half)

		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 18)
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		half.add_child(box)
		box.add_child(_badge(team, clampf(screen.y * 0.3, 120.0, 260.0)))
		var name_label: Label = _label(_team_name(team).to_upper(), 46)
		box.add_child(name_label)

		var tw := create_tween().set_parallel(true)
		tw.tween_property(half, "offset_left", 0.0, 0.5).set_delay(0.15) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(half, "offset_right", 0.0, 0.5).set_delay(0.15) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# "VS" no meio
	var vs_holder := CenterContainer.new()
	_full_rect(vs_holder)
	vs_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_intro_root.add_child(vs_holder)
	var vs: Label = _label("VS", 120, Color(1.0, 0.92, 0.55))
	vs_holder.add_child(vs)
	vs.modulate.a = 0.0
	await get_tree().process_frame
	if _intro_root == null:
		return
	vs.pivot_offset = vs.size * 0.5
	vs.scale = Vector2(2.4, 2.4)
	var vs_tween := create_tween().set_parallel(true)
	vs_tween.tween_property(vs, "modulate:a", 1.0, 0.2).set_delay(0.55)
	vs_tween.tween_property(vs, "scale", Vector2.ONE, 0.35).set_delay(0.55) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# Texto de baixo
	var bottom := CenterContainer.new()
	bottom.anchor_left = 0.0
	bottom.anchor_right = 1.0
	bottom.anchor_top = 0.84
	bottom.anchor_bottom = 0.96
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_intro_root.add_child(bottom)
	var go: Label = _label("A PARTIDA VAI COMEÇAR", 34, Color(1, 1, 1, 0.95))
	go.modulate.a = 0.0
	bottom.add_child(go)
	create_tween().tween_property(go, "modulate:a", 1.0, 0.3).set_delay(1.2)


func _finish_intro() -> void:
	if _intro_done:
		return
	_intro_done = true
	var root: Control = _intro_root
	_intro_root = null
	if root != null:
		root.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var fade := create_tween()
		fade.tween_property(root, "modulate:a", 0.0, 0.4)
		fade.tween_callback(root.queue_free)
	intro_finished.emit()   # a partida começa enquanto a apresentação some


## Fundo da apresentação: duas metades coloridas separadas por uma diagonal
class _VersusBg extends Control:
	var left_color: Color = Color(0.6, 0.1, 0.1)
	var right_color: Color = Color(0.1, 0.2, 0.6)
	var progress: float = 0.0:
		set(value):
			progress = value
			queue_redraw()

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var w: float = size.x
		var h: float = size.y
		var cx: float = w * 0.5
		var skew: float = h * 0.2
		var slide: float = (1.0 - progress)
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.04, 0.05, 0.08))
		var dl: float = -w * 0.6 * slide
		var dr: float = w * 0.6 * slide
		draw_colored_polygon(PackedVector2Array([
			Vector2(dl, 0.0), Vector2(cx + skew + dl, 0.0), Vector2(cx - skew + dl, h), Vector2(dl, h)]),
			left_color)
		draw_colored_polygon(PackedVector2Array([
			Vector2(cx + skew + dr, 0.0), Vector2(w + dr, 0.0), Vector2(w + dr, h), Vector2(cx - skew + dr, h)]),
			right_color)
		draw_line(Vector2(cx + skew + dl, 0.0), Vector2(cx - skew + dl, h), Color(1, 1, 1, 0.8 * progress), 5.0)


# ---------- GOL ----------

func _on_goal_scored(goal: Dictionary) -> void:
	var team: int = int(goal["team"])
	var own_goal: bool = bool(goal.get("own_goal", false))
	var accent: Color = TeamStyle.color_of(team)
	var screen: Vector2 = _screen()
	_goal_until_msec = Time.get_ticks_msec() + int(goal_time * 1000.0)

	var root := Control.new()
	_full_rect(root)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE   # o jogo continua por baixo
	add_child(root)

	# Flash na cor do time
	var flash := ColorRect.new()
	_full_rect(flash)
	flash.color = Color(accent.lightened(0.35), 0.65)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(flash)
	create_tween().tween_property(flash, "color:a", 0.0, 0.55)

	# Faixa inclinada que cruza a tela
	var band_h: float = clampf(screen.y * 0.36, 220.0, 340.0)
	var band := Control.new()
	band.size = Vector2(screen.x * 1.6, band_h)
	band.pivot_offset = band.size * 0.5
	band.rotation = deg_to_rad(-6.0)
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(band)
	var fill := ColorRect.new()
	fill.size = band.size
	fill.color = Color(accent.darkened(0.3), 0.94)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.add_child(fill)
	for edge_y in [0.0, band_h - 6.0]:
		var edge := ColorRect.new()
		edge.position = Vector2(0.0, edge_y)
		edge.size = Vector2(band.size.x, 6.0)
		edge.color = Color(1, 1, 1, 0.9) if edge_y == 0.0 else accent.lightened(0.45)
		edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		band.add_child(edge)
	var band_home: Vector2 = Vector2(screen.x * 0.5, screen.y * 0.4) - band.size * 0.5
	band.position = band_home + Vector2(-screen.x * 1.4, 0.0)
	create_tween().tween_property(band, "position", band_home, 0.3) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	# Conteúdo: selo + GOL! + autor/assistência
	var content := CenterContainer.new()
	content.anchor_left = 0.0
	content.anchor_right = 1.0
	content.anchor_top = 0.4 - band_h / screen.y * 0.5
	content.anchor_bottom = 0.4 + band_h / screen.y * 0.5
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(content)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 32)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(row)
	var badge: TeamBadge = _badge(team, band_h * 0.52)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(badge)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(col)
	var title: Label = _label("GOL CONTRA!" if own_goal else "GOL!", int(band_h * 0.46))
	col.add_child(title)
	var scorer: String = String(goal.get("scorer", ""))
	var who: String = ("Gol contra de %s" if own_goal else "Gol de %s") % scorer
	col.add_child(_label(who, int(band_h * 0.14), Color(1, 0.95, 0.7)))
	var assist: String = String(goal.get("assist", ""))
	if assist != "":
		col.add_child(_label("Assistência: %s" % assist, int(band_h * 0.1), Color(1, 1, 1, 0.85)))

	# Placar logo abaixo da faixa
	var score_holder := CenterContainer.new()
	score_holder.anchor_left = 0.0
	score_holder.anchor_right = 1.0
	score_holder.anchor_top = 0.4 + band_h / screen.y * 0.5 + 0.03
	score_holder.anchor_bottom = score_holder.anchor_top + 0.12
	score_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(score_holder)
	var score_label: Label = _label(_score_line(), 46)
	score_holder.add_child(score_label)

	# Entradas: GOL! estoura, o resto aparece
	for c in [badge, col, score_label]:
		c.modulate.a = 0.0
	await get_tree().process_frame
	if not is_instance_valid(root):
		return
	title.pivot_offset = title.size * 0.5
	title.scale = Vector2(2.0, 2.0)
	var pop := create_tween().set_parallel(true)
	pop.tween_property(col, "modulate:a", 1.0, 0.15).set_delay(0.12)
	pop.tween_property(title, "scale", Vector2.ONE, 0.4).set_delay(0.12) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop.tween_property(badge, "modulate:a", 1.0, 0.2).set_delay(0.2)
	pop.tween_property(score_label, "modulate:a", 1.0, 0.25).set_delay(0.5)

	# Confete + torcida
	var confetti := _Confetti.new()
	_full_rect(confetti)
	root.add_child(confetti)
	confetti.burst(110, [accent, accent.lightened(0.4), Color.WHITE, Color(1.0, 0.85, 0.25)])


	# Some no fim
	await get_tree().create_timer(maxf(goal_time - 0.4, 0.5)).timeout
	if is_instance_valid(root):
		var out := create_tween()
		out.tween_property(root, "modulate:a", 0.0, 0.4)
		out.tween_callback(root.queue_free)


## "Vermelho 1 × 0 Azul"
func _score_line() -> String:
	var parts: PackedStringArray = []
	for t in manager.team_count:
		parts.append(_team_name(t))
	var scores: PackedStringArray = []
	for t in manager.scores.size():
		scores.append(str(manager.scores[t]))
	if manager.team_count == 2:
		return "%s  %s × %s  %s" % [parts[0], scores[0], scores[1], parts[1]]
	return " × ".join(scores)


# ---------- AVISOS DE TEMPO ----------

func _on_half_started(half: int) -> void:
	if half >= 2:
		_show_banner("SEGUNDO TEMPO", "A bola volta a rolar", Color(0.35, 0.45, 0.85))


func _on_extra_time_started() -> void:
	_show_banner("PRORROGAÇÃO", "Gol de ouro: o próximo gol decide", Color(0.85, 0.6, 0.15))


## Faixa inclinada rápida com um título e uma linha de apoio
func _show_banner(title_text: String, sub_text: String, color: Color) -> void:
	var screen: Vector2 = _screen()
	var band_h: float = clampf(screen.y * 0.24, 150.0, 240.0)
	var root := Control.new()
	_full_rect(root)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var band := ColorRect.new()
	band.size = Vector2(screen.x * 1.6, band_h)
	band.pivot_offset = band.size * 0.5
	band.rotation = deg_to_rad(-5.0)
	band.color = Color(color.darkened(0.35), 0.94)
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(band)
	var home: Vector2 = screen * 0.5 - band.size * 0.5
	band.position = home + Vector2(-screen.x * 1.4, 0.0)
	create_tween().tween_property(band, "position", home, 0.3) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	var holder := CenterContainer.new()
	_full_rect(holder)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(holder)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(col)
	col.add_child(_label(title_text, int(band_h * 0.42)))
	col.add_child(_label(sub_text, int(band_h * 0.14), Color(1, 1, 1, 0.85)))
	col.modulate.a = 0.0
	create_tween().tween_property(col, "modulate:a", 1.0, 0.25).set_delay(0.15)

	await get_tree().create_timer(1.9).timeout
	if is_instance_valid(root):
		var out := create_tween().set_parallel(true)
		out.tween_property(root, "modulate:a", 0.0, 0.35)
		out.chain().tween_callback(root.queue_free)


# ---------- TELA FINAL ----------

func _on_match_ended(winner: int) -> void:
	if not show_end_card:
		return
	# Se o gol da vitória acabou de sair, deixa a animação de gol terminar antes
	var wait_ms: int = _goal_until_msec - Time.get_ticks_msec()
	if wait_ms > 0:
		await get_tree().create_timer(float(wait_ms) / 1000.0 + 0.3).timeout
	if manager == null or not manager.match_over:
		return
	_build_end_card(winner)


func _clear_end_card() -> void:
	if _end_root != null:
		_end_root.queue_free()
		_end_root = null


func _panel_style(border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.08, 0.11, 0.96)
	sb.set_corner_radius_all(18)
	sb.set_border_width_all(3)
	sb.border_color = border
	sb.set_content_margin_all(32)
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 12
	return sb


## Um time no placar final: selo (logo) grande, nome e, se venceu, o aviso de vencedor
func _team_result_block(team: int, is_winner: bool, draw_game: bool) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var size_px: float = 150.0 if is_winner else 120.0
	var badge: TeamBadge = _badge(team, size_px)
	box.add_child(badge)
	box.add_child(_label(_team_name(team), 28 if is_winner else 24))
	var tag: String = "VENCEDOR" if is_winner else ("EMPATE" if draw_game else "")
	var tag_label: Label = _label(tag, 20, Color(1.0, 0.85, 0.3) if is_winner else Color(1, 1, 1, 0.7))
	tag_label.custom_minimum_size = Vector2(0.0, 28.0)
	box.add_child(tag_label)
	return box


func _build_end_card(winner: int) -> void:
	_clear_end_card()
	var screen: Vector2 = _screen()
	var draw_game: bool = winner < 0
	var accent: Color = TeamStyle.color_of(winner) if not draw_game else Color(0.7, 0.72, 0.8)

	_end_root = Control.new()
	_full_rect(_end_root)
	_end_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_end_root)

	var dim := ColorRect.new()
	_full_rect(dim)
	dim.color = Color(0, 0, 0, 0.82)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_end_root.add_child(dim)

	var center := CenterContainer.new()
	_full_rect(center)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_end_root.add_child(center)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style(accent))
	# Painel principal no meio e as caixinhas de estatísticas nos lados
	var layout := HBoxContainer.new()
	layout.alignment = BoxContainer.ALIGNMENT_CENTER
	layout.add_theme_constant_override("separation", 22)
	layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(layout)
	var left_col: VBoxContainer = _stat_column()
	var right_col: VBoxContainer = _stat_column()
	layout.add_child(left_col)
	layout.add_child(panel)
	layout.add_child(right_col)
	var stat_cards: Array[Control] = _build_stat_cards(left_col, right_col, screen)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 22)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(box)

	box.add_child(_label("FIM DE JOGO", 40))

	# Selos dos dois times com o placar no meio
	var score_row := HBoxContainer.new()
	score_row.alignment = BoxContainer.ALIGNMENT_CENTER
	score_row.add_theme_constant_override("separation", 44)
	score_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(score_row)
	var team_a: int = 0
	var team_b: int = mini(1, manager.team_count - 1)
	score_row.add_child(_team_result_block(team_a, winner == team_a, draw_game))
	var score_text: String = "%d × %d" % [manager.scores[team_a], manager.scores[team_b]]
	var score_label: Label = _label(score_text, 84, Color(1.0, 0.95, 0.75))
	score_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	score_row.add_child(score_label)
	score_row.add_child(_team_result_block(team_b, winner == team_b, draw_game))

	# MVP: imagem do personagem com o selo do time dele
	var mvp: Dictionary = manager.mvp
	var mvp_block: Control = null
	if not mvp.is_empty():
		mvp_block = _build_mvp_block(mvp, screen)
		box.add_child(mvp_block)

	var again := Button.new()
	again.text = "Jogar novamente"
	again.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	again.custom_minimum_size = Vector2(280.0, 58.0)
	again.add_theme_font_size_override("font_size", 22)
	again.pressed.connect(func() -> void:
		_clear_end_card()
		manager.return_to_formation())
	box.add_child(again)

	# Entrada: o painel "sobe" e o MVP desliza
	panel.modulate.a = 0.0
	await get_tree().process_frame
	if _end_root == null:
		return
	panel.pivot_offset = panel.size * 0.5
	panel.scale = Vector2(0.88, 0.88)
	var pop := create_tween().set_parallel(true)
	pop.tween_property(panel, "modulate:a", 1.0, 0.25)
	pop.tween_property(panel, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if mvp_block != null:
		mvp_block.modulate.a = 0.0
		create_tween().tween_property(mvp_block, "modulate:a", 1.0, 0.4).set_delay(0.45)
	for i in stat_cards.size():   # as caixinhas aparecem uma depois da outra
		create_tween().tween_property(stat_cards[i], "modulate:a", 1.0, 0.4).set_delay(0.6 + 0.12 * float(i))

	var confetti := _Confetti.new()
	_full_rect(confetti)
	_end_root.add_child(confetti)
	confetti.burst(160, [accent, accent.lightened(0.4), Color.WHITE, Color(1.0, 0.85, 0.25)])



# ---------- ESTATÍSTICAS (caixinhas ao lado do painel principal) ----------

const STAT_MUTED := Color(1, 1, 1, 0.65)


func _stat_column() -> VBoxContainer:
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 14)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return col


## Largura de cada caixinha (acompanha a tela)
func _stat_width(screen: Vector2) -> float:
	return clampf(screen.x * 0.19, 210.0, 300.0)


func _card_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.08, 0.11, 0.94)
	sb.set_corner_radius_all(14)
	sb.set_border_width_all(2)
	sb.border_color = Color(1.0, 0.85, 0.3, 0.55)
	sb.set_content_margin_all(14)
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 8
	return sb


## Caixinha com título. O conteúdo vai no VBox devolvido por _card_box().
func _stat_card(title: String, width: float) -> PanelContainer:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _card_style())
	card.custom_minimum_size = Vector2(width, 0.0)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.modulate.a = 0.0   # aparece na animação de entrada
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(vb)
	vb.add_child(_label(title, 20, Color(1.0, 0.85, 0.3)))
	vb.add_child(HSeparator.new())
	return card


func _card_box(card: PanelContainer) -> VBoxContainer:
	return card.get_child(0) as VBoxContainer


func _stat_text(parent: Control, text: String, color: Color, size: int, width: float) -> void:
	var l: Label = _label(text, size, color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(width - 34.0, 0.0)
	parent.add_child(l)


func _team_text_color(team: int) -> Color:
	return TeamStyle.color_of(team).lightened(0.35)


## Monta as 5 caixinhas (esquerda: gols e destaques; direita: defesas, chutes/passes e resumo)
## e devolve todas, para a animação de entrada.
func _build_stat_cards(left: VBoxContainer, right: VBoxContainer, screen: Vector2) -> Array[Control]:
	var w: float = _stat_width(screen)
	var cards: Array[Control] = []
	var goals_card: PanelContainer = _goals_card(w, screen)
	var top_card: PanelContainer = _top_players_card(w)
	var keepers_card: PanelContainer = _keepers_card(w)
	var shots_card: PanelContainer = _shots_passes_card(w)
	var summary_card: PanelContainer = _summary_card(w)
	left.add_child(goals_card)
	left.add_child(top_card)
	right.add_child(keepers_card)
	right.add_child(shots_card)
	right.add_child(summary_card)
	cards.append(goals_card)
	cards.append(top_card)
	cards.append(keepers_card)
	cards.append(shots_card)
	cards.append(summary_card)
	return cards


## Quem fez cada gol, a assistência e a rodada (na cor do time que marcou)
func _goals_card(w: float, screen: Vector2) -> PanelContainer:
	var card: PanelContainer = _stat_card("Gols", w)
	var vb: VBoxContainer = _card_box(card)
	if manager.goal_log.is_empty():
		_stat_text(vb, "Nenhum gol", STAT_MUTED, 16, w)
		return card

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(w - 30.0,
		clampf(float(manager.goal_log.size()) * 46.0, 46.0, screen.y * 0.3))
	vb.add_child(scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 6)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)

	for goal: Dictionary in manager.goal_log:
		var goal_team: int = int(goal["team"])
		var rnd: int = int(goal["round"])
		var own_goal: bool = bool(goal["own_goal"])
		var head: String = "Rodada %d · %s" % [rnd, goal["scorer"]]
		if own_goal:
			head += " (gol contra)"
		elif rnd > manager.rounds_per_half * 2:
			head += " (gol de ouro)"
		_stat_text(list, head, _team_text_color(goal_team), 17, w)
		if not own_goal and String(goal["assist"]) != "":
			_stat_text(list, "assist.: %s" % goal["assist"], STAT_MUTED, 14, w)
	return card


## Os 3 jogadores que mais pontuaram (o primeiro é o MVP)
func _top_players_card(w: float) -> PanelContainer:
	var card: PanelContainer = _stat_card("Destaques", w)
	var vb: VBoxContainer = _card_box(card)
	var entries: Array = manager.player_stats.values().filter(
		func(e: Dictionary) -> bool: return int(e["points"]) > 0)
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["points"] != b["points"]:
			return a["points"] > b["points"]
		if a["goals"] != b["goals"]:
			return a["goals"] > b["goals"]
		return a["assists"] > b["assists"])
	if entries.is_empty():
		_stat_text(vb, "Ninguém pontuou", STAT_MUTED, 16, w)
		return card

	for i in mini(3, entries.size()):
		var e: Dictionary = entries[i]
		_stat_text(vb, "%d. %s" % [i + 1, e["name"]], _team_text_color(int(e["team"])), 17, w)
		var parts: PackedStringArray = []
		var goals: int = int(e["goals"])
		var assists: int = int(e["assists"])
		if goals > 0:
			parts.append("%d gol%s" % [goals, "" if goals == 1 else "s"])
		if assists > 0:
			parts.append("%d assist." % assists)
		if int(e["win"]) > 0:
			parts.append("vitória")
		var detail: String = "%d pts" % int(e["points"])
		if not parts.is_empty():
			detail += " · " + " · ".join(parts)
		_stat_text(vb, detail, STAT_MUTED, 14, w)
	return card


## Quantas vezes os goleiros agarraram a bola (total e em chutes ao gol)
func _keepers_card(w: float) -> PanelContainer:
	var card: PanelContainer = _stat_card("Defesas dos goleiros", w)
	var vb: VBoxContainer = _card_box(card)
	var total: int = 0
	for t in manager.team_count:
		var s: Dictionary = manager.team_stat(t)
		var catches: int = int(s["catches"])
		total += catches
		_stat_text(vb, "%s: %d" % [_team_name(t), catches], _team_text_color(t), 18, w)
		var detail: String = "%d em chutes ao gol" % int(s["saves"])
		if String(s["keeper"]) != "":
			detail = "%s · %s" % [s["keeper"], detail]
		_stat_text(vb, detail, STAT_MUTED, 14, w)
	_stat_text(vb, "Total: %d" % total, Color(1.0, 0.95, 0.75), 17, w)
	return card


## Chutes que chegaram ao gol, aproveitamento e passes certos de cada time
func _shots_passes_card(w: float) -> PanelContainer:
	var card: PanelContainer = _stat_card("Chutes e passes", w)
	var vb: VBoxContainer = _card_box(card)
	for t in manager.team_count:
		var s: Dictionary = manager.team_stat(t)
		var shots: int = int(s["shots_on_target"])
		var goals: int = 0
		for goal: Dictionary in manager.goal_log:
			if int(goal["team"]) == t and not bool(goal["own_goal"]):
				goals += 1
		var rate: String = "—"
		if shots > 0:
			rate = "%d%%" % clampi(int(round(float(goals) / float(shots) * 100.0)), 0, 100)
		_stat_text(vb, _team_name(t), _team_text_color(t), 18, w)
		_stat_text(vb, "Chutes no gol: %d · Aproveitamento: %s" % [shots, rate], STAT_MUTED, 14, w)
		_stat_text(vb, "Passes certos: %d" % int(s["passes"]), STAT_MUTED, 14, w)
	return card


## Rodadas jogadas, gols por tempo e quando saíram o primeiro e o último gol
func _summary_card(w: float) -> PanelContainer:
	var card: PanelContainer = _stat_card("Resumo da partida", w)
	var vb: VBoxContainer = _card_box(card)
	_stat_text(vb, "Rodadas jogadas: %d" % manager.round_number, Color.WHITE, 16, w)

	var first_half: int = 0
	var second_half: int = 0
	var extra: int = 0
	for goal: Dictionary in manager.goal_log:
		var rnd: int = int(goal["round"])
		if rnd > manager.rounds_per_half * 2:
			extra += 1
		elif rnd > manager.rounds_per_half:
			second_half += 1
		else:
			first_half += 1
	var by_half: String = "Gols: 1º tempo %d · 2º tempo %d" % [first_half, second_half]
	if extra > 0:
		by_half += " · prorrogação %d" % extra
	_stat_text(vb, by_half, Color.WHITE, 16, w)

	if not manager.goal_log.is_empty():
		var first_goal: Dictionary = manager.goal_log[0]
		var last_goal: Dictionary = manager.goal_log[manager.goal_log.size() - 1]
		_stat_text(vb, "Primeiro gol: rodada %d" % int(first_goal["round"]), STAT_MUTED, 15, w)
		if manager.goal_log.size() > 1:
			_stat_text(vb, "Último gol: rodada %d" % int(last_goal["round"]), STAT_MUTED, 15, w)
	return card


func _build_mvp_block(mvp: Dictionary, screen: Vector2) -> Control:
	var team: int = int(mvp.get("team", 0))
	var color: Color = TeamStyle.color_of(team)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 30)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Imagem do MVP numa moldura na cor do time
	var tex: Texture2D = mvp.get("image") as Texture2D
	if tex == null:
		tex = CharacterRoster.full_for(String(mvp.get("character_id", "")))
	var frame := PanelContainer.new()
	var fsb := StyleBoxFlat.new()
	fsb.bg_color = color.darkened(0.55)
	fsb.set_corner_radius_all(14)
	fsb.set_border_width_all(4)
	fsb.border_color = Color(1.0, 0.85, 0.3)
	fsb.set_content_margin_all(6)
	frame.add_theme_stylebox_override("panel", fsb)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(frame)
	var img_h: float = clampf(screen.y * 0.26, 150.0, 260.0)
	if tex != null:
		var rect := TextureRect.new()
		rect.texture = tex
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var aspect: float = float(tex.get_width()) / maxf(float(tex.get_height()), 1.0)
		rect.custom_minimum_size = Vector2(minf(img_h * aspect, img_h * 1.4), img_h)
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.add_child(rect)
	else:
		var letter: Label = _label(String(mvp.get("name", "?")).substr(0, 1).to_upper(), int(img_h * 0.6), color.lightened(0.4))
		letter.custom_minimum_size = Vector2(img_h * 0.8, img_h)
		letter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		frame.add_child(letter)

	# Textos + selo do time do MVP
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 8)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(col)
	var mvp_label: Label = _label("MVP", 54, Color(1.0, 0.85, 0.3))
	mvp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	col.add_child(mvp_label)
	var name_label: Label = _label(String(mvp.get("name", "")), 36)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	col.add_child(name_label)

	var goals: int = int(mvp.get("goals", 0))
	var assists: int = int(mvp.get("assists", 0))
	var stats: PackedStringArray = []
	if goals > 0:
		stats.append("%d gol%s" % [goals, "" if goals == 1 else "s"])
	if assists > 0:
		stats.append("%d assistência%s" % [assists, "" if assists == 1 else "s"])
	if int(mvp.get("win", 0)) > 0:
		stats.append("vitória")
	if not stats.is_empty():
		var stats_label: Label = _label(" · ".join(stats), 20, Color(1, 1, 1, 0.8))
		stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		col.add_child(stats_label)

	var team_row := HBoxContainer.new()
	team_row.add_theme_constant_override("separation", 12)
	team_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(team_row)
	var team_badge: TeamBadge = _badge(team, 44.0)
	team_row.add_child(team_badge)
	var team_label: Label = _label(_team_name(team), 22, color.lightened(0.4))
	team_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	team_row.add_child(team_label)
	return row


# ---------- CONFETE ----------

class _Confetti extends Control:
	var _pieces: Array[Dictionary] = []

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	## Solta count pedaços de confete do alto da tela
	func burst(count: int, colors: Array) -> void:
		var w: float = maxf(get_viewport_rect().size.x, 100.0)
		for i in count:
			_pieces.append({
				"pos": Vector2(randf() * w, -randf_range(10.0, 400.0)),
				"vel": Vector2(randf_range(-90.0, 90.0), randf_range(120.0, 340.0)),
				"rot": randf() * TAU,
				"spin": randf_range(-8.0, 8.0),
				"size": Vector2(randf_range(8.0, 15.0), randf_range(5.0, 9.0)),
				"color": colors[randi() % colors.size()],
				"phase": randf() * TAU,
			})

	func _process(delta: float) -> void:
		var h: float = get_viewport_rect().size.y
		var alive: bool = false
		for p in _pieces:
			p["vel"] = Vector2(p["vel"].x, minf(p["vel"].y + 380.0 * delta, 420.0))
			p["pos"] += p["vel"] * delta + Vector2(sin(Time.get_ticks_msec() * 0.004 + float(p["phase"])) * 28.0 * delta, 0.0)
			p["rot"] += float(p["spin"]) * delta
			if p["pos"].y < h + 30.0:
				alive = true
		queue_redraw()
		if not alive and not _pieces.is_empty():
			queue_free()

	func _draw() -> void:
		for p in _pieces:
			draw_set_transform(p["pos"], float(p["rot"]), Vector2.ONE)
			var s: Vector2 = p["size"]
			draw_rect(Rect2(-s * 0.5, s), p["color"])
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
