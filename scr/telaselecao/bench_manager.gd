class_name BenchManager
extends CanvasLayer
## Banco de reservas, substituições e pausas.
##
## - Cada time escolhe RESERVES (3) reservas na tela de formação, antes da partida.
## - Cada time pode pedir PAUSA até MAX_PAUSES (2) vezes, nos momentos em que o MatchManager deixa
##   (veja MatchManager.pause_window): depois de um gol, no fim do tempo e com o goleiro
##   segurando a bola. Os botões de pausa ficam no canto inferior direito.
## - Na pausa o time pode fazer até MAX_SUBS (2) substituições (somando a partida inteira) e
##   editar a formação. As posições novas valem a partir do PRÓXIMO reset (gol ou troca de lado):
##   os jogadores não saem do lugar na hora.
## - Quem sai não volta. Quem entra nasce no lugar de quem saiu, com as recargas zeradas.
##
## O MatchManager cria este nó sozinho (guardado em manager.bench).

## Interno: a tela de pausa terminou (botão "Continuar o jogo")
signal _screen_closed

const RESERVES: int = 3          # vagas de reserva por time
const MAX_SUBS: int = 2          # substituições por time na partida inteira
const MAX_PAUSES: int = 2        # pausas por time na partida inteira
const BUTTON_LAYER: int = 11     # acima do placar (10) e abaixo da tela de formação (12)
const SCREEN_LAYER: int = 14     # a tela de pausa fica acima de tudo
const GHOST_PICK_RADIUS: float = 28.0   # distância (px) para pegar uma posição com o mouse

var manager: MatchManager

var _reserves: Dictionary = {}       # time -> lista de ids de personagem ("" = vaga vazia)
var _subs_left: Array[int] = []
var _pauses_left: Array[int] = []
var _buttons: Array[Button] = []

# Tela de pausa (só existe enquanto está aberta)
var _screen_layer: CanvasLayer
var _team: int = -1
var _field: Field
var _ghosts: _Ghosts
var _sel_out: Player = null          # quem vai sair (escolhido na lista "Em campo")
var _out_box: VBoxContainer
var _in_box: VBoxContainer
var _info: Label
var _home_backup: Dictionary = {}    # Player -> posição "casa" de quando a pausa abriu (botão Restaurar)
var _drag_offset: Vector2 = Vector2.ZERO


## Bolinhas coloridas no campo: a posição "casa" de cada jogador (para onde ele volta no reset).
## Uma linha fina liga o jogador ao lugar para onde ele vai.
class _Ghosts extends Node2D:
	var players: Array[Player] = []
	var color: Color = Color.WHITE
	var area: Rect2 = Rect2()
	var drag: Player = null

	func _draw() -> void:
		draw_rect(area, Color(color, 0.10))
		draw_rect(area, Color(color, 0.55), false, 3.0)
		var font: Font = ThemeDB.fallback_font
		for i in players.size():
			var p: Player = players[i]
			if not is_instance_valid(p):
				continue
			var from: Vector2 = to_local(p.global_position)
			var dest: Vector2 = to_local(p.home_position)
			draw_line(from, dest, Color(1, 1, 1, 0.35), 2.0)
			var strong: bool = p == drag
			draw_circle(dest, 17.0 if strong else 15.0, Color(color, 0.9))
			draw_arc(dest, 17.0, 0.0, TAU, 24, Color.WHITE, 3.0 if strong else 2.0)
			draw_string(font, dest + Vector2(-7.0, 5.0), str(i + 1), HORIZONTAL_ALIGNMENT_CENTER, 14.0, 14, Color.WHITE)


func _ready() -> void:
	layer = BUTTON_LAYER
	reset_match()
	_build_buttons()


# ---------- DADOS DO BANCO ----------

## Zera tudo (começo de uma partida nova): reservas vazias e contadores cheios
func reset_match() -> void:
	_reserves.clear()
	_subs_left.clear()
	_pauses_left.clear()
	for t in manager.team_count:
		var slots: Array = []
		for i in RESERVES:
			slots.append("")
		_reserves[t] = slots
		_subs_left.append(MAX_SUBS)
		_pauses_left.append(MAX_PAUSES)


## Ids dos reservas do time ("" = vaga vazia)
func reserves_of(team: int) -> Array:
	return _reserves.get(team, [])


func reserve_id(team: int, slot: int) -> String:
	var list: Array = reserves_of(team)
	if slot < 0 or slot >= list.size():
		return ""
	return String(list[slot])


func set_reserve(team: int, slot: int, id: String) -> void:
	if _reserves.has(team) and slot >= 0 and slot < RESERVES:
		_reserves[team][slot] = id


func subs_left(team: int) -> int:
	return _subs_left[team] if team >= 0 and team < _subs_left.size() else 0


func pauses_left(team: int) -> int:
	return _pauses_left[team] if team >= 0 and team < _pauses_left.size() else 0


## O time pode pedir pausa agora? (ainda tem pausa e o jogo está num momento que permite)
func can_pause(team: int) -> bool:
	if pauses_left(team) <= 0 or manager.is_pause_queued(team):
		return false
	return manager.pause_window() != &""


# ---------- BOTÕES DE PAUSA (canto inferior direito) ----------

func _build_buttons() -> void:
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	box.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	box.offset_right = -10
	box.offset_bottom = -10
	box.add_theme_constant_override("separation", 4)
	add_child(box)
	for t in manager.team_count:
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 12)
		b.custom_minimum_size = Vector2(130.0, 28.0)
		b.tooltip_text = "Pedir pausa para substituições e formação.\nDá para pedir depois de um gol, no fim do tempo ou com o goleiro segurando a bola."
		UiStyle.style_button(b, TeamStyle.color_of(t))
		b.pressed.connect(manager.request_pause.bind(t))
		box.add_child(b)
		_buttons.append(b)


func _process(_delta: float) -> void:
	if manager == null:
		return
	var show_buttons: bool = manager.phase != MatchManager.Phase.FORMATION and not manager.match_over
	for t in _buttons.size():
		var b: Button = _buttons[t]
		b.visible = show_buttons
		if not show_buttons:
			continue
		var short_name: String = manager.get_team_name(t)
		if short_name.length() > 9:
			short_name = short_name.left(9) + "."
		var label: String
		if manager.is_pause_queued(t):
			label = "%s: agendada" % short_name
		else:
			label = "Pausa %s (%d)" % [short_name, pauses_left(t)]
		if b.text != label:
			b.text = label
		b.disabled = manager.is_pause_queued(t) or not can_pause(t)
	if _ghosts != null and is_instance_valid(_ghosts):
		_ghosts.queue_redraw()


# ---------- SUBSTITUIÇÃO ----------

## Troca o jogador "out" pelo reserva da vaga "slot". Devolve true se deu certo.
func substitute(team: int, out: Player, slot: int) -> bool:
	if subs_left(team) <= 0 or not is_instance_valid(out) or out.team != team:
		return false
	var id: String = reserve_id(team, slot)
	if id == "":
		return false
	var out_name: String = out.get_display_name()
	var old_home: Vector2 = out.home_position
	if _home_backup.has(out):
		old_home = _home_backup[out]
	var fresh: Player = CharacterRoster.replace_player(out, id)
	if fresh == null:
		return false
	_subs_left[team] -= 1
	_reserves[team][slot] = ""    # quem sai não volta e a vaga do banco fica vazia
	_home_backup.erase(out)
	_home_backup[fresh] = old_home
	manager.on_player_replaced(out, fresh)
	manager.announce_keeper("Substituição (%s): %s sai, %s entra" % [
		manager.get_team_name(team), out_name, fresh.get_display_name()], team)
	return true


# ---------- TELA DE PAUSA ----------

## Abre a tela de pausa do time e espera ele clicar em "Continuar o jogo"
func run_pause_screen(team: int) -> void:
	_field = get_tree().get_first_node_in_group("field") as Field
	if _field == null:
		return
	_team = team
	_pauses_left[team] -= 1
	_sel_out = null
	_home_backup.clear()
	for p in manager.get_team_players(team):
		_home_backup[p] = p.home_position
	_build_screen()
	await _screen_closed
	_close_screen()


func _build_screen() -> void:
	var color: Color = TeamStyle.color_of(_team)
	_screen_layer = CanvasLayer.new()
	_screen_layer.layer = SCREEN_LAYER
	add_child(_screen_layer)

	# Fundo quase transparente: segura os cliques (o jogo está parado) e recebe o arrastar das posições
	var blocker := ColorRect.new()
	blocker.color = Color(0, 0, 0, 0.18)
	blocker.set_anchors_preset(Control.PRESET_FULL_RECT)
	blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	blocker.gui_input.connect(_on_blocker_input)
	_screen_layer.add_child(blocker)

	# Posições "casa" desenhadas no campo (a metade do time)
	_ghosts = _Ghosts.new()
	_ghosts.z_as_relative = false
	_ghosts.z_index = 3000
	_ghosts.color = color
	_ghosts.area = Formations.team_area(_team, _field)
	_ghosts.players = manager.get_team_players(_team)
	_field.add_child(_ghosts)

	# Painel do lado OPOSTO à metade do time, para não cobrir as posições que ele vai arrastar
	var panel := PanelContainer.new()
	var style: StyleBoxFlat = UiStyle.style_panel(panel)
	style.set_border_width_all(3)
	style.border_color = color

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.custom_minimum_size = Vector2(440.0, 0.0)
	panel.add_child(box)

	box.add_child(UiStyle.make_label("Pausa — %s" % manager.get_team_name(_team), 22))
	_info = UiStyle.make_label("", 13, UiStyle.ACCENT_COLOR)
	box.add_child(_info)
	box.add_child(_wrapped("Substituição: clique em quem sai (Em campo) e depois em quem entra (Banco).", 12))

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 14)
	box.add_child(columns)
	_out_box = _make_column(columns, "Em campo")
	_in_box = _make_column(columns, "Banco")

	box.add_child(HSeparator.new())
	box.add_child(UiStyle.make_label("Formação para o próximo reset", 14))
	box.add_child(_wrapped("Arraste as bolinhas no campo ou escolha uma formação pronta. Os jogadores só vão para as novas posições no próximo reset (gol ou troca de lado).", 12))

	var presets := HFlowContainer.new()
	presets.add_theme_constant_override("h_separation", 8)
	presets.add_theme_constant_override("v_separation", 8)
	box.add_child(presets)
	for f in Formations.presets_for(manager.get_team_players(_team).size()):
		var pb := Button.new()
		pb.text = f
		pb.focus_mode = Control.FOCUS_NONE
		pb.tooltip_text = Formations.nickname(f)
		UiStyle.style_button(pb)
		pb.pressed.connect(_apply_preset.bind(f))
		presets.add_child(pb)
	var restore := Button.new()
	restore.text = "Restaurar"
	restore.focus_mode = Control.FOCUS_NONE
	UiStyle.style_button(restore, Color(0.35, 0.45, 0.85))
	restore.pressed.connect(_restore_homes)
	presets.add_child(restore)

	var go := Button.new()
	go.text = "Continuar o jogo"
	go.focus_mode = Control.FOCUS_NONE
	go.custom_minimum_size = Vector2(0.0, 46.0)
	UiStyle.style_button(go, Color(0.25, 0.65, 0.35))
	go.pressed.connect(func() -> void: _screen_closed.emit())
	box.add_child(go)

	_screen_layer.add_child(panel)
	var left: bool = _field.defend_dir(_team) < 0
	panel.set_anchors_and_offsets_preset(
		Control.PRESET_CENTER_RIGHT if left else Control.PRESET_CENTER_LEFT, Control.PRESET_MODE_MINSIZE, 16)
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN if left else Control.GROW_DIRECTION_END
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH

	_refresh_lists()


func _close_screen() -> void:
	if _ghosts != null and is_instance_valid(_ghosts):
		_ghosts.queue_free()
	_ghosts = null
	if _screen_layer != null and is_instance_valid(_screen_layer):
		_screen_layer.queue_free()
	_screen_layer = null
	_home_backup.clear()
	_sel_out = null


func _wrapped(text: String, size: int) -> Label:
	var l: Label = UiStyle.make_label(text, size, UiStyle.MUTED_COLOR)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(440.0, 0.0)
	return l


## Coluna com título; devolve a caixa onde entram os botões
func _make_column(parent: Control, title: String) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 6)
	parent.add_child(col)
	col.add_child(UiStyle.make_label(title, 14))
	var items := VBoxContainer.new()
	items.add_theme_constant_override("separation", 4)
	col.add_child(items)
	return items


## Botão com rosto + nome (a imagem some se o personagem não tiver rosto)
func _make_person_button(text: String, face: Texture2D, selected: bool) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0.0, 44.0)
	if selected:
		UiStyle.style_button(b, TeamStyle.color_of(_team))
	else:
		UiStyle.style_button(b)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 4)
	b.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(row)
	if face != null:
		var pic := TextureRect.new()
		pic.texture = face
		pic.custom_minimum_size = Vector2(34.0, 34.0)
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(pic)
	var label: Label = UiStyle.make_label(text, 13)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(label)
	return b


## Refaz as duas listas (em campo / banco) e o resumo de cima
func _refresh_lists() -> void:
	for c in _out_box.get_children():
		_out_box.remove_child(c)
		c.queue_free()
	for c in _in_box.get_children():
		_in_box.remove_child(c)
		c.queue_free()

	var players: Array[Player] = manager.get_team_players(_team)
	_ghosts.players = players
	for i in players.size():
		var p: Player = players[i]
		var pb: Button = _make_person_button("%d. %s" % [i + 1, p.get_display_name()],
			CharacterRoster.face_for(p.character_id), p == _sel_out)
		pb.pressed.connect(_on_out_pressed.bind(p))
		_out_box.add_child(pb)

	for slot in RESERVES:
		var id: String = reserve_id(_team, slot)
		if id == "":
			var empty: Button = _make_person_button("Vaga vazia", null, false)
			empty.disabled = true
			_in_box.add_child(empty)
			continue
		var entry: Dictionary = CharacterRoster.find(id)
		var rb: Button = _make_person_button(String(entry.get("name", id)), CharacterRoster.face_for(id), false)
		rb.disabled = subs_left(_team) <= 0
		rb.pressed.connect(_on_in_pressed.bind(slot))
		_in_box.add_child(rb)

	_info.text = "Substituições restantes: %d de %d   ·   Pausas restantes depois desta: %d" % [
		subs_left(_team), MAX_SUBS, pauses_left(_team)]
	_ghosts.queue_redraw()


func _on_out_pressed(p: Player) -> void:
	_sel_out = null if _sel_out == p else p
	_refresh_lists()


func _on_in_pressed(slot: int) -> void:
	if _sel_out == null or not is_instance_valid(_sel_out):
		_info.text = "Primeiro clique em quem vai sair (lista Em campo)."
		return
	if substitute(_team, _sel_out, slot):
		_sel_out = null
	_refresh_lists()


# ---------- FORMAÇÃO (posições "casa" para o próximo reset) ----------

## Arrastar as bolinhas no campo (o fundo da tela de pausa recebe o mouse)
func _on_blocker_input(event: InputEvent) -> void:
	if _ghosts == null or _field == null:
		return
	var world: Vector2 = _field.get_global_mouse_position()
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var best: Player = null
			var best_dist: float = GHOST_PICK_RADIUS
			for p in _ghosts.players:
				if not is_instance_valid(p):
					continue
				var d: float = p.home_position.distance_to(world)
				if d < best_dist:
					best = p
					best_dist = d
			_ghosts.drag = best
			if best != null:
				_drag_offset = best.home_position - world
		else:
			_ghosts.drag = null
		_ghosts.queue_redraw()
	elif event is InputEventMouseMotion and _ghosts.drag != null:
		_ghosts.drag.home_position = _clamp_home(world + _drag_offset)
		_ghosts.queue_redraw()


## Mantém a posição dentro da metade do time
func _clamp_home(global_pos: Vector2) -> Vector2:
	var local: Vector2 = _field.to_local(global_pos)
	var area: Rect2 = _ghosts.area
	local.x = clampf(local.x, area.position.x, area.end.x)
	local.y = clampf(local.y, area.position.y, area.end.y)
	return _field.to_global(local)


## Formação pronta: cada espaço fica com o jogador cuja "casa" atual é a mais próxima
func _apply_preset(formation: String) -> void:
	var slots: Array[Vector2] = Formations.slots(formation, _team, _field)
	var free: Array[Player] = _ghosts.players.duplicate()
	for s in slots:
		if free.is_empty():
			break
		var best: Player = free[0]
		for p in free:
			if p.home_position.distance_to(s) < best.home_position.distance_to(s):
				best = p
		best.home_position = s
		free.erase(best)
	_ghosts.queue_redraw()


## Volta as posições para como estavam quando a pausa abriu
func _restore_homes() -> void:
	for p in manager.get_team_players(_team):
		if _home_backup.has(p):
			p.home_position = _home_backup[p]
	_ghosts.queue_redraw()
