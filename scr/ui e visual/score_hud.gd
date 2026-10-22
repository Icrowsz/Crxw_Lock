class_name ScoreHud
extends CanvasLayer
## Placar no topo, aviso de gol/tempo, mensagens do jogo e resumo final da partida.
## Monta tudo por código. O MatchManager cria este nó sozinho (show_score_hud).
## O placar é uma "barrinha de transmissão": logo do time (a que o jogador escolheu), nome e número grande de cada lado, com o
## tempo da partida embaixo. Gol e troca de tempo ganham um aviso grande (com confete no gol).

## Quanto tempo o aviso grande (gol, 2º tempo, prorrogação) fica parado antes de sumir
@export var banner_time: float = 3.5
## Notificações do lado (defesa do goleiro, lançamento, rodada bônus...): tempo paradas e tempo para sair
@export var event_time: float = 5.0
@export var event_fade_time: float = 0.7
## Máximo de notificações ao mesmo tempo em cada lado (as mais antigas saem primeiro)
@export var max_notes_per_side: int = 4
## Confete saindo do aviso do gol (o MatchEffects já solta confete pela tela toda; ligue se quiser os dois)
@export var goal_confetti: bool = false

const PANEL_BG := Color(0.05, 0.06, 0.09, 0.84)
const NOTE_WIDTH: float = 330.0
const NOTE_GAP: float = 8.0
const NOTE_TOP: float = 84.0       # abaixo dos botões de pausa
const NOTE_MARGIN: float = 14.0
const BANNER_TOP: float = 124.0    # longe do placar e do "Rodada N"

var manager: MatchManager

var _score_labels: Array[Label] = []
var _name_labels: Array[Label] = []
var _score_boxes: Array[PanelContainer] = []
var _badges: Array[TeamBadge] = []   # logo de cada time: o ícone/cor/nome que o jogador escolheu na formação
var _last_scores: Array[int] = []
var _banner: PanelContainer
var _banner_style: StyleBoxFlat
var _banner_row: HBoxContainer
var _banner_badge: Control   # logo do time (TeamBadge) nos avisos de gol
var _banner_title: Label
var _banner_sub: Label
var _banner_detail: Label
var _banner_tween: Tween
var _notes: Array[PanelContainer] = []   # notificações na tela (a mais nova por último)
var _summary: PanelContainer
var _summary_box: VBoxContainer
## "1º TEMPO" / "2º TEMPO" / "PRORROGAÇÃO", exibido embaixo do placar
var _period_label: Label


func _ready() -> void:
	layer = 10  # acima do menu de ações
	_build_scoreboard()
	_build_banner()
	_build_summary()
	manager.goal_scored.connect(_on_goal_scored)
	manager.match_ended.connect(_on_match_ended)
	manager.keeper_event.connect(_on_keeper_event)
	manager.formation_started.connect(_on_formation_started)
	manager.match_started.connect(_on_match_started)
	manager.half_started.connect(_on_half_started)
	manager.sides_swapped.connect(_on_sides_swapped)
	manager.extra_time_started.connect(_on_extra_time_started)
	_refresh_scores()
	_refresh_period()


# ---------- CONSTRUÇÃO ----------

## Painel escuro arredondado com borda e sombra (usado no placar, nas mensagens e no aviso)
func _glass_style(border: Color, radius: int = 16, border_w: int = 2, pad_x: int = 14, pad_y: int = 6) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = PANEL_BG
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = pad_x
	sb.content_margin_right = pad_x
	sb.content_margin_top = pad_y
	sb.content_margin_bottom = pad_y
	sb.shadow_color = Color(0, 0, 0, 0.38)
	sb.shadow_size = 7
	return sb


func _build_scoreboard() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.offset_top = 8   # o placar fica no topo; "Rodada N" (ActionMenu) vem logo abaixo
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _glass_style(UiStyle.PANEL_BORDER, 18, 2, 16, 5))
	add_child(panel)

	# Pilha vertical: placar em cima, "1º TEMPO / 2º TEMPO / PRORROGAÇÃO" embaixo
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 1)
	outer.alignment = BoxContainer.ALIGNMENT_CENTER
	outer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(outer)

	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outer.add_child(box)

	for t in manager.team_count:
		if t > 0:
			box.add_child(UiStyle.make_label("×", 22, UiStyle.MUTED_COLOR))
		var color: Color = _team_color(t)

		# Logo do time: vem direto da escolha do jogador (TeamStyle) e se atualiza sozinha se ele trocar ícone, cor ou nome.
		# Sem ícone escolhido, o TeamBadge desenha o escudo com a inicial do nome.
		var badge := TeamBadge.make(t, 38.0, manager.get_default_team_name(t))
		badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER

		var name_label := UiStyle.make_label("", 20, color)
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var score_box := PanelContainer.new()   # número grande dentro de uma caixinha escura com borda do time
		score_box.custom_minimum_size = Vector2(46, 0)
		score_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var score_label := UiStyle.make_label("0", 30)
		score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		score_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		score_box.add_child(score_label)

		# Time da esquerda: logo, nome, placar. Time da direita: placar, nome, logo (espelhado)
		var block := HBoxContainer.new()
		block.add_theme_constant_override("separation", 8)
		block.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var order: Array[Control] = [badge, name_label, score_box]
		if t % 2 == 1:
			order.reverse()
		for c in order:
			block.add_child(c)
		box.add_child(block)

		_badges.append(badge)
		_name_labels.append(name_label)
		_score_boxes.append(score_box)
		_score_labels.append(score_label)
		_last_scores.append(0)

	_period_label = UiStyle.make_label("", 13, UiStyle.MUTED_COLOR)
	_period_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_period_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outer.add_child(_period_label)


func _flat(color: Color, radius: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	return sb


## Aviso grande: GOL!, 2º TEMPO, PRORROGAÇÃO
func _build_banner() -> void:
	_banner = PanelContainer.new()
	_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_banner.offset_top = BANNER_TOP
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE  # não atrapalha cliques no jogo
	_banner.visible = false
	_banner_style = _glass_style(UiStyle.PANEL_BORDER, 18, 2, 32, 14)
	_banner.add_theme_stylebox_override("panel", _banner_style)
	add_child(_banner)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.add_child(row)
	_banner_row = row

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(vbox)

	_banner_title = UiStyle.make_label("", 56)
	vbox.add_child(_banner_title)
	_banner_sub = UiStyle.make_label("", 26)
	vbox.add_child(_banner_sub)
	_banner_detail = UiStyle.make_label("", 19, UiStyle.MUTED_COLOR)
	vbox.add_child(_banner_detail)


func _build_summary() -> void:
	_summary = PanelContainer.new()
	_summary.set_anchors_preset(Control.PRESET_CENTER)
	_summary.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_summary.grow_vertical = Control.GROW_DIRECTION_BOTH
	_summary.visible = false
	UiStyle.style_panel(_summary)
	add_child(_summary)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	_summary.add_child(margin)

	_summary_box = VBoxContainer.new()
	_summary_box.add_theme_constant_override("separation", 14)
	margin.add_child(_summary_box)


# ---------- EVENTOS ----------

func _on_goal_scored(goal: Dictionary) -> void:
	_refresh_scores()
	var team: int = goal["team"]
	var color: Color = _team_color(team)
	_show_banner("GOL!", manager.get_team_name(team), _goal_description(goal), color, banner_time, team)
	if goal_confetti:
		_confetti(color)


## Aviso grande no meio do topo: entra com um "pulo", fica parado e some devagar.
## A faixa e a borda ganham a cor dada.
func _show_banner(title: String, sub: String, detail: String, color: Color, hold: float, crest_team: int = -1) -> void:
	# Logo do time ao lado do texto (nos avisos sem time, como o 2º tempo, não tem)
	if _banner_badge != null and is_instance_valid(_banner_badge):
		_banner_badge.queue_free()
		_banner_badge = null
	if crest_team >= 0:
		_banner_badge = TeamBadge.make(crest_team, 84.0, manager.get_default_team_name(crest_team))
		_banner_badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_banner_row.add_child(_banner_badge)
		_banner_row.move_child(_banner_badge, 0)
	_banner_title.text = title
	_banner_title.add_theme_color_override("font_color", color)
	_banner_sub.text = sub
	_banner_sub.visible = sub != ""
	_banner_detail.text = detail
	_banner_detail.visible = detail != ""
	_banner_style.border_color = color
	_banner_style.set_border_width_all(2)
	_banner_style.border_width_left = 10   # faixa grossa na cor do time/aviso
	_banner.visible = true

	if _banner_tween and _banner_tween.is_valid():
		_banner_tween.kill()
	_banner.pivot_offset = _banner.get_combined_minimum_size() * 0.5
	_banner.scale = Vector2.ONE * 0.6
	_banner.modulate.a = 0.0
	_banner_tween = create_tween()
	_banner_tween.tween_property(_banner, "modulate:a", 1.0, 0.15)
	_banner_tween.parallel().tween_property(_banner, "scale", Vector2.ONE, 0.4) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_banner_tween.tween_interval(hold)
	_banner_tween.tween_property(_banner, "modulate:a", 0.0, 0.5)
	_banner_tween.tween_callback(_banner.hide)


## Confete saindo do aviso de gol (cores do time e branco)
func _confetti(color: Color) -> void:
	var width: float = get_viewport().get_visible_rect().size.x
	for c: Color in [color, Color.WHITE, color.lightened(0.45)]:
		var p := CPUParticles2D.new()
		p.position = Vector2(width * 0.5, BANNER_TOP + 50.0)
		p.amount = 20
		p.lifetime = 1.7
		p.one_shot = true
		p.explosiveness = 0.95
		p.direction = Vector2.UP
		p.spread = 75.0
		p.initial_velocity_min = 260.0
		p.initial_velocity_max = 560.0
		p.gravity = Vector2(0.0, 720.0)
		p.scale_amount_min = 4.0
		p.scale_amount_max = 8.0
		p.angular_velocity_min = -360.0
		p.angular_velocity_max = 360.0
		p.color = c
		add_child(p)
		p.emitting = true
		get_tree().create_timer(p.lifetime + 0.6).timeout.connect(p.queue_free)


## Mensagens do jogo viram NOTIFICAÇÕES: entram deslizando pela lateral do time a que se referem
## (time 0 = esquerda, time 1 = direita, como no placar) e vão se empilhando, a mais nova em cima
func _on_keeper_event(text: String, team: int) -> void:
	_add_note(text, team)


func _add_note(text: String, team: int) -> void:
	var side: int = -1 if team < 0 else team % 2   # 0 = esquerda, 1 = direita, -1 = centro (sem time)
	var color: Color = _team_color(team) if team >= 0 else UiStyle.PANEL_BORDER

	var panel := PanelContainer.new()
	panel.set_meta("side", side)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.custom_minimum_size = Vector2(NOTE_WIDTH, 0.0)
	var sb: StyleBoxFlat = _glass_style(color, 12, 2, 14, 8)
	if side == 0:
		sb.border_width_left = 8    # faixa colorida do lado de onde a notificação chega
	elif side == 1:
		sb.border_width_right = 8
	panel.add_theme_stylebox_override("panel", sb)
	var label := UiStyle.make_label(text, 17)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(NOTE_WIDTH - 40.0, 0.0)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(label)
	panel.modulate.a = 0.0
	add_child(panel)
	_notes.append(panel)

	# Passou do limite do lado: a mais antiga sai
	var same_side: Array[PanelContainer] = []
	for n in _notes:
		if int(n.get_meta("side")) == side:
			same_side.append(n)
	if same_side.size() > max_notes_per_side:
		_dismiss_note(same_side[0], 0.2)

	await get_tree().process_frame   # o tamanho do painel só existe depois de um quadro
	if not is_instance_valid(panel) or not _notes.has(panel):
		return
	_restack(panel)

	await get_tree().create_timer(event_time).timeout
	_dismiss_note(panel, event_fade_time)


## Tira a notificação (desliza para fora e some) e reorganiza as outras
func _dismiss_note(panel: PanelContainer, time: float) -> void:
	if not is_instance_valid(panel) or not _notes.has(panel):
		return
	_notes.erase(panel)
	_kill_note_tween(panel)
	var side: int = int(panel.get_meta("side"))
	var width: float = get_viewport().get_visible_rect().size.x
	var out_x: float = panel.position.x
	if side == 0:
		out_x = -panel.size.x - 20.0
	elif side == 1:
		out_x = width + 20.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(panel, "modulate:a", 0.0, time)
	if side >= 0:
		tw.tween_property(panel, "position:x", out_x, time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await tw.finished
	if is_instance_valid(panel):
		panel.queue_free()
	_restack()


func _kill_note_tween(panel: PanelContainer) -> void:
	if panel.has_meta("tween"):
		var old: Tween = panel.get_meta("tween") as Tween
		if old and old.is_valid():
			old.kill()


## Posiciona as notificações de cada lado: a mais nova no topo, as outras descem. new_panel desliza para dentro.
func _restack(new_panel: PanelContainer = null) -> void:
	var width: float = get_viewport().get_visible_rect().size.x
	for side in [-1, 0, 1]:
		var y: float = NOTE_TOP if side >= 0 else NOTE_TOP + 12.0
		for i in range(_notes.size() - 1, -1, -1):
			var n: PanelContainer = _notes[i]
			if int(n.get_meta("side")) != side:
				continue
			var target_x: float = (width - n.size.x) * 0.5
			if side == 0:
				target_x = NOTE_MARGIN
			elif side == 1:
				target_x = width - n.size.x - NOTE_MARGIN
			_kill_note_tween(n)
			var tw := create_tween().set_parallel(true)
			n.set_meta("tween", tw)
			if n == new_panel:
				var start_x: float = target_x
				if side == 0:
					start_x = -n.size.x - 20.0
				elif side == 1:
					start_x = width + 20.0
				n.position = Vector2(start_x, y + (0.0 if side >= 0 else -16.0))
				tw.tween_property(n, "modulate:a", 1.0, 0.2)
				tw.tween_property(n, "position", Vector2(target_x, y), 0.4) \
					.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			else:
				tw.tween_property(n, "modulate:a", 1.0, 0.1)
				tw.tween_property(n, "position", Vector2(target_x, y), 0.25) \
					.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			y += n.size.y + NOTE_GAP


func _clear_notes() -> void:
	for n in _notes:
		if is_instance_valid(n):
			_kill_note_tween(n)
			n.queue_free()
	_notes.clear()


## Durante a montagem das formações o HUD some (a tela de formação ocupa o lugar)
func _on_formation_started() -> void:
	visible = false
	if _banner_tween and _banner_tween.is_valid():
		_banner_tween.kill()
	_banner.hide()
	_clear_notes()
	_summary.hide()
	_refresh_scores()


func _on_match_started() -> void:
	visible = true
	_refresh_scores()   # os times podem ter mudado de nome e cor na formação
	_refresh_period()


func _on_half_started(_half: int) -> void:
	_refresh_period()


## Os times trocaram de lado (começo do 2º tempo)
func _on_sides_swapped() -> void:
	_refresh_period()
	_show_banner("2º TEMPO", "Os times trocaram de lado", "", UiStyle.ACCENT_COLOR, banner_time)


func _on_extra_time_started() -> void:
	_refresh_period()
	_show_banner("PRORROGAÇÃO", "Gol de ouro decide a partida", "", UiStyle.ACCENT_COLOR, banner_time)


func _refresh_period() -> void:
	_period_label.text = manager.time_label().to_upper()


func _on_back_pressed(button: Button) -> void:
	button.disabled = true  # evita clique duplo
	manager.return_to_formation()


func _on_match_ended(winner: int) -> void:
	_refresh_scores()
	if _banner_tween and _banner_tween.is_valid():
		_banner_tween.kill()
	_banner.hide()
	_clear_notes()

	# O MatchEffects já mostra a tela final própria (FIM DE JOGO + MVP + estatísticas):
	# não monta este resumo antigo por cima, senão aparecem duas telas.
	if manager.effects != null and manager.effects.show_end_card:
		return

	for child in _summary_box.get_children():
		_summary_box.remove_child(child)
		child.queue_free()

	# Título e placar final (winner = -1 quando a prorrogação acaba empatada)
	var is_draw: bool = winner < 0
	var title_text: String = "FIM DE JOGO — Empate!" if is_draw \
		else "FIM DE JOGO — %s venceu!" % manager.get_team_name(winner)
	var title := UiStyle.make_label(title_text, 34)
	if not is_draw:
		title.add_theme_color_override("font_color", _team_color(winner))
	_summary_box.add_child(title)

	var parts: PackedStringArray = []
	for t in manager.team_count:
		parts.append("%s %d" % [manager.get_team_name(t), manager.scores[t]])
	_summary_box.add_child(UiStyle.make_label("  ×  ".join(parts), 26))

	_summary_box.add_child(HSeparator.new())

	# Uma coluna por time, com os gols na ordem em que aconteceram (#1, #2...)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 56)
	columns.alignment = BoxContainer.ALIGNMENT_CENTER
	_summary_box.add_child(columns)

	for t in manager.team_count:
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 6)
		columns.add_child(col)

		var header := UiStyle.make_label("%s (%d)" % [manager.get_team_name(t), manager.scores[t]], 22, _team_color(t))
		col.add_child(header)

		var any_goal: bool = false
		for goal: Dictionary in manager.goal_log:
			if goal["team"] != t:
				continue
			any_goal = true
			var line := UiStyle.make_label(_goal_line(goal), 16)
			line.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			col.add_child(line)
		if not any_goal:
			var none := UiStyle.make_label("Nenhum gol", 16, UiStyle.MUTED_COLOR)
			none.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			col.add_child(none)

	_add_mvp_section()

	# Botão para voltar à montagem das formações e começar de novo
	_summary_box.add_child(HSeparator.new())
	var back := Button.new()
	back.text = "Voltar às formações"
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	UiStyle.style_button(back, UiStyle.ACCENT_COLOR.darkened(0.25))
	back.pressed.connect(_on_back_pressed.bind(back))
	_summary_box.add_child(back)

	_summary.visible = true
	_summary.modulate.a = 0.0
	UiStyle.pop(_summary, 0.85, 0.35)
	create_tween().tween_property(_summary, "modulate:a", 1.0, 0.25)


## Bloco do MVP no resumo final: nome, imagem ou vídeo embaixo (a moldura se adapta ao formato) e a conta dos pontos
func _add_mvp_section() -> void:
	var mvp: Dictionary = manager.mvp
	if mvp.is_empty():
		return
	var color: Color = _team_color(mvp["team"])

	_summary_box.add_child(HSeparator.new())
	_summary_box.add_child(UiStyle.make_label("MVP", 18, UiStyle.MUTED_COLOR))
	_summary_box.add_child(UiStyle.make_label(String(mvp["name"]), 32, color))

	# MvpMedia: a moldura assume o formato da imagem ou do vídeo do MVP (mvp["video"] vem do match_manager)
	var portrait := MvpMedia.new()
	portrait.setup(mvp["image"] as Texture2D, color, String(mvp["name"]),
		MvpMedia.find_video(String(mvp.get("character_id", "")), mvp.get("video") as VideoStream))
	portrait.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_summary_box.add_child(portrait)

	_summary_box.add_child(UiStyle.make_label(_mvp_breakdown(mvp), 16, UiStyle.MUTED_COLOR))


## "5 pts — 2 gols · 1 assist. · vitória"
func _mvp_breakdown(mvp: Dictionary) -> String:
	var parts: PackedStringArray = []
	if mvp["goals"] > 0:
		var goal_word: String = "gol de ouro" if mvp["golden"] else ("gol" if mvp["goals"] == 1 else "gols")
		parts.append("%d %s" % [mvp["goals"], goal_word])
	if mvp["assists"] > 0:
		parts.append("%d assist." % mvp["assists"])
	if mvp["win"] > 0:
		parts.append("vitória")
	return "%d pts — %s" % [mvp["points"], " · ".join(parts)]


# ---------- TEXTOS ----------

## Linha do resumo final: "#2  Fulano — assist.: Ciclano"
func _goal_line(goal: Dictionary) -> String:
	var text: String = "#%d  %s" % [goal["order"], goal["scorer"]]
	if goal["own_goal"]:
		text += " (gol contra)"
	elif goal["assist"] != "":
		text += " — assist.: %s" % goal["assist"]
	return text


## Detalhe do aviso de gol
func _goal_description(goal: Dictionary) -> String:
	var text: String = goal["scorer"]
	if goal["own_goal"]:
		text += " (gol contra)"
	elif goal["assist"] != "":
		text += "\nAssistência: %s" % goal["assist"]
	return text


func _refresh_scores() -> void:
	for t in _score_labels.size():
		var color: Color = _team_color(t)   # o time pode ter mudado o nome e a cor na formação
		_name_labels[t].text = manager.get_team_name(t)
		_name_labels[t].add_theme_color_override("font_color", color)
		var box_style := _flat(color.darkened(0.6), 9)
		box_style.border_color = color
		box_style.set_border_width_all(2)
		box_style.content_margin_left = 8
		box_style.content_margin_right = 8
		box_style.content_margin_top = 1
		box_style.content_margin_bottom = 1
		_score_boxes[t].add_theme_stylebox_override("panel", box_style)
		_score_labels[t].text = str(manager.scores[t])
		# Quando o time marca, o número dele dá um "pulinho"
		if manager.scores[t] != _last_scores[t]:
			_last_scores[t] = manager.scores[t]
			UiStyle.pop(_score_boxes[t], 1.3, 0.3)
			_flash_score(_score_labels[t])


## Gol: além do pulinho, o placar brilha e dá uma balançadinha de lado
func _flash_score(label: Label) -> void:
	label.pivot_offset = label.get_combined_minimum_size() * 0.5
	label.modulate = Color(2.0, 2.0, 2.0)
	var tw := label.create_tween().set_parallel(true)
	tw.tween_property(label, "modulate", Color.WHITE, 0.6) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	label.rotation = deg_to_rad(6.0)
	tw.tween_property(label, "rotation", 0.0, 0.6) \
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


# ---------- UTIL ----------

func _team_color(team: int) -> Color:
	return TeamStyle.color_of(team)
