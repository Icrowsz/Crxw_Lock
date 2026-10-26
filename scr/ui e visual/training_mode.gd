class_name TrainingMode
extends CanvasLayer
## MODO TREINO: janela de debug (tecla F1 abre/fecha; arraste pela barra de título) para testar personagens à vontade.
## Só existe quando o jogo foi aberto pelo botão "MODO TREINO" do menu inicial (GameMode.apply_to() cria).
##
## O QUE O PAINEL FAZ
##   Partida   · Recargas desativadas   · Ações ilimitadas (o turno só acaba em "Passar turno")
##             · Limpar recargas agora · Passar turno · Zerar placar · Bola no centro / Bola onde eu clicar
##   Jogador   · escolher o jogador na lista (ou ligar "Arrastar jogadores" e clicar nele no campo)
##             · Altura (Chão / Suspenso / Voando) · Derrubar / Levantar · Trocar por outro personagem · Remover
##   Adicionar · escolher personagem, time e quantidade e clicar em "Adicionar" (vale qualquer número de jogadores)
##   Menu inicial · volta ao menu
##
## Ações ilimitadas: enquanto estiver ligado, as ações do Protagonista e dos Secundários nunca acabam.
## Recargas desativadas: a cada quadro as recargas de todos são zeradas (as habilidades nunca ficam em espera).
##
## Nada aqui altera as regras do jogo normal: sem o menu inicial (GameMode.training = false) este nó nem é criado.

const SEL_COLOR: Color = Color(0.4, 1.0, 0.7)

## Tamanho e lugar da janela quando abre (dá para arrastar e redimensionar depois)
@export var window_size: Vector2i = Vector2i(440, 640)
@export var window_position: Vector2i = Vector2i(24, 110)

var manager: MatchManager

var _window: Window
var _body: VBoxContainer
var _selected: Player = null
var _player_option: OptionButton
var _height_option: OptionButton
var _swap_option: OptionButton
var _add_option: OptionButton
var _add_team: OptionButton
var _add_count: SpinBox
var _drag_check: CheckButton
var _info: Label
var _toast_label: Label
var _toast_tween: Tween
var _marker: _Marker
var _ids: Array = []            # jogadores da lista (para saber quando refazer)
var _check_timer: float = 0.0
var _dragging: Player = null
var _drag_offset: Vector2 = Vector2.ZERO
var _ball_click_mode: bool = false
var _roster: Array[Dictionary] = []


func _ready() -> void:
	layer = 12
	_roster = CharacterRoster.available()
	_build()
	_marker = _Marker.new()
	_marker.z_index = 4000
	var world: Node = manager.get_parent() if manager != null else get_tree().current_scene
	world.add_child.call_deferred(_marker)
	_refresh_players()
	_toast("MODO TREINO  ·  F1 abre/fecha o painel")


# ---------- MONTAGEM DA TELA ----------

func _build() -> void:
	# Uma JANELA de verdade (arrasta pela barra de título, redimensiona pelas bordas, o X ou o F1 fecham)
	_window = Window.new()
	_window.title = "Modo treino  (F1 abre/fecha)"
	_window.size = window_size
	_window.position = window_position
	_window.min_size = Vector2i(360, 260)
	_window.exclusive = false
	_window.transient = false
	_window.close_requested.connect(func() -> void: _window.hide())
	_window.window_input.connect(_on_window_input)   # F1 também funciona com a janela em foco
	add_child(_window)

	var back := PanelContainer.new()
	UiStyle.style_panel(back, Color(UiStyle.ACCENT_COLOR, 0.45))
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	_window.add_child(back)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO   # só aparece se algo teimar em não caber
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	back.add_child(scroll)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 6)
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_body)

	# ----- Partida
	_section("Partida")
	_check("Recargas desativadas", GameMode.no_cooldowns, func(v: bool) -> void: GameMode.no_cooldowns = v)
	_check("Ações ilimitadas", GameMode.infinite_actions, func(v: bool) -> void: GameMode.infinite_actions = v)
	_buttons_row([
		["Limpar recargas", _clear_cooldowns],
		["Passar turno", _pass_turn],
		["Zerar placar", _reset_score]])
	_buttons_row([
		["Bola no centro", _ball_center],
		["Bola onde eu clicar", _ball_arm]])

	# ----- Jogador
	_section("Jogador")
	_player_option = OptionButton.new()
	_compact(_player_option)
	_player_option.fit_to_longest_item = false
	_player_option.add_theme_constant_override("icon_max_width", 28)
	_player_option.item_selected.connect(_on_player_chosen)
	_body.add_child(_player_option)
	_drag_check = _check("Arrastar jogadores com o mouse", false, func(_v: bool) -> void: _end_drag())
	_info = UiStyle.make_label("", 15, UiStyle.MUTED_COLOR)
	_info.custom_minimum_size.x = 0.0
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_child(_info)

	var height_row := HBoxContainer.new()
	_body.add_child(height_row)
	height_row.add_child(UiStyle.make_label("Altura", 17))
	_height_option = OptionButton.new()
	_compact(_height_option)
	_height_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for lv in [Heights.Level.GROUND, Heights.Level.SUSPENDED, Heights.Level.FLYING]:
		_height_option.add_item(Heights.level_name(lv), int(lv))
	_height_option.item_selected.connect(_on_height_chosen)
	height_row.add_child(_height_option)

	_buttons_row([
		["Derrubar", _knock_down],
		["Levantar", _stand_up],
		["Remover", _remove_selected]])

	var swap_row := HBoxContainer.new()
	_body.add_child(swap_row)
	_swap_option = _character_option(swap_row)
	var swap_btn := _make_button("Trocar", _swap_selected)
	swap_row.add_child(swap_btn)

	# ----- Adicionar
	_section("Adicionar personagens")
	var add_row := HBoxContainer.new()
	_body.add_child(add_row)
	_add_option = _character_option(add_row)
	_add_team = OptionButton.new()
	_compact(_add_team)
	for t in 2:
		_add_team.add_item("Time %d" % t, t)
	add_row.add_child(_add_team)
	var count_row := HBoxContainer.new()
	_body.add_child(count_row)
	count_row.add_child(UiStyle.make_label("Quantidade", 17))
	_add_count = SpinBox.new()
	_add_count.custom_minimum_size.x = 0.0
	_add_count.min_value = 1
	_add_count.max_value = 20
	_add_count.value = 1
	_add_count.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	count_row.add_child(_add_count)
	_body.add_child(_make_button("Adicionar", _add_players))

	_section("")
	_body.add_child(_make_button("Menu inicial", _back_to_menu))

	# Aviso rápido no pé da tela
	_toast_label = UiStyle.make_label("", 26, Color.WHITE)
	_toast_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_toast_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_toast_label.offset_bottom = -140.0
	_toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_label.modulate.a = 0.0
	add_child(_toast_label)


func _section(title: String) -> void:
	_body.add_child(HSeparator.new())
	if title != "":
		var l: Label = UiStyle.make_label(title, 19, Color(1, 1, 1, 0.9))
		l.clip_text = true
		_body.add_child(l)


## Deixa o controle pequeno e "encolhível": texto cortado em vez de empurrar a janela, fonte menor
func _compact(c: Control, font_size: int = 16) -> void:
	c.custom_minimum_size.x = 0.0
	c.add_theme_font_size_override("font_size", font_size)
	if c is Button:
		(c as Button).clip_text = true


func _check(text: String, value: bool, on_toggle: Callable) -> CheckButton:
	var c := CheckButton.new()
	_compact(c)
	c.text = text
	c.button_pressed = value
	c.toggled.connect(on_toggle)
	_body.add_child(c)
	return c


func _make_button(text: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiStyle.style_button(b)
	_compact(b)
	b.custom_minimum_size.x = 96.0   # largura mínima: abaixo disso a fileira quebra de linha
	b.pressed.connect(on_press)
	return b


func _buttons_row(items: Array) -> void:
	var row := HFlowContainer.new()   # se a janela estreitar, os botões descem para a linha de baixo
	row.add_theme_constant_override("h_separation", 6)
	row.add_theme_constant_override("v_separation", 6)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_child(row)
	for it in items:
		row.add_child(_make_button(String(it[0]), it[1]))


## Lista de personagens (com rostinho) para trocar/adicionar
func _character_option(parent: Control) -> OptionButton:
	var o := OptionButton.new()
	_compact(o)
	o.fit_to_longest_item = false
	o.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	o.add_theme_constant_override("icon_max_width", 28)
	for i in _roster.size():
		var c: Dictionary = _roster[i]
		var face: Texture2D = CharacterRoster.face_for(String(c["id"]))
		if face != null:
			o.add_item(String(c["name"]), i)
			o.set_item_icon(o.item_count - 1, face)
		else:
			o.add_item(String(c["name"]), i)
	parent.add_child(o)
	return o


# ---------- LISTA DE JOGADORES ----------

func _all_players() -> Array[Player]:
	var list: Array[Player] = []
	for p: Player in get_tree().get_nodes_in_group("players"):
		if is_instance_valid(p) and not p.is_queued_for_deletion():
			list.append(p)
	return list


func _refresh_players() -> void:
	var players: Array[Player] = _all_players()
	var ids: Array = []
	for p in players:
		ids.append(p.get_instance_id())
	if ids == _ids:
		return
	_ids = ids
	_player_option.clear()
	var keep: int = -1
	for i in players.size():
		var p: Player = players[i]
		_player_option.add_item("T%d · %s  (%s)" % [p.team, p.get_display_name(), p.name], i)
		var face: Texture2D = p.get_face_image()
		if face != null:
			_player_option.set_item_icon(i, face)
		_player_option.set_item_metadata(i, p)
		if p == _selected:
			keep = i
	if keep >= 0:
		_player_option.select(keep)
	elif not players.is_empty():
		_select(players[0])
	else:
		_selected = null


func _on_player_chosen(index: int) -> void:
	var p: Player = _player_option.get_item_metadata(index) as Player
	_select(p)


func _select(p: Player) -> void:
	_selected = p
	if p == null:
		return
	for i in _player_option.item_count:
		if _player_option.get_item_metadata(i) == p:
			_player_option.select(i)
	_height_option.select(int(p.height_level))
	_update_info()


func _update_info() -> void:
	if _selected == null or not is_instance_valid(_selected):
		_info.text = ""
		return
	var p: Player = _selected
	_info.text = "%s  ·  time %d  ·  altura %s%s" % [p.get_display_name(), p.team, Heights.level_name(p.height_level),
		"  ·  derrubado" if p.is_down else ""]


# ---------- AÇÕES: PARTIDA ----------

func _clear_cooldowns() -> void:
	for p in _all_players():
		p.restore_cooldowns({})
	_toast("Recargas zeradas")


func _pass_turn() -> void:
	if manager == null:
		return
	if manager.phase == MatchManager.Phase.CHOOSING_PROTAGONIST or manager.phase == MatchManager.Phase.CHOOSING_ACTION:
		manager._end_turn()
		_toast("Turno passado")
	else:
		_toast("Espere a ação terminar para passar o turno")


func _reset_score() -> void:
	if manager == null:
		return
	manager.scores.fill(0)
	manager.goal_log.clear()
	manager.state_changed.emit()
	_toast("Placar zerado")


func _field() -> Field:
	return get_tree().get_first_node_in_group("field") as Field


func _ball_center() -> void:
	var f: Field = _field()
	if f != null:
		f.reset_ball()
		_toast("Bola no centro")


func _ball_arm() -> void:
	_ball_click_mode = true
	_toast("Clique no campo para pôr a bola (botão direito cancela)")


func _back_to_menu() -> void:
	if GameMode.menu_scene == "" or not ResourceLoader.exists(GameMode.menu_scene):
		_toast("Menu inicial não encontrado (abra o jogo pelo menu)")
		return
	var path: String = GameMode.menu_scene
	GameMode.reset()
	get_tree().change_scene_to_file(path)


# ---------- AÇÕES: JOGADOR SELECIONADO ----------

func _on_height_chosen(index: int) -> void:
	apply_height(_selected, _height_option.get_item_id(index) as Heights.Level)
	_update_info()


## Muda a altura de um jogador (a mesma subida/descida que Pular e land() usam)
func apply_height(p: Player, level: Heights.Level) -> void:
	if p == null or not is_instance_valid(p):
		return
	if level == Heights.Level.GROUND:
		p.land()
		return
	p.height_level = level
	var tw := p.create_tween()
	tw.tween_property(p, "height", Heights.to_height(level), 0.25) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _knock_down() -> void:
	if _selected != null and is_instance_valid(_selected):
		_selected.knock_down()
		_update_info()


func _stand_up() -> void:
	if _selected != null and is_instance_valid(_selected):
		_selected.get_up_now()
		_update_info()


func _remove_selected() -> void:
	if _selected == null or not is_instance_valid(_selected):
		return
	var p: Player = _selected
	_selected = null
	_forget(p)
	p.get_parent().remove_child(p)   # sai do grupo "players" na hora
	p.queue_free()
	_toast("Removido: %s" % p.get_display_name())
	_refresh_players()


func _swap_selected() -> void:
	if _selected == null or not is_instance_valid(_selected) or _roster.is_empty():
		return
	var entry: Dictionary = _roster[_swap_option.selected]
	var old: Player = _selected
	_forget(old)
	var fresh: Player = CharacterRoster.replace_player(old, String(entry["id"]))
	if fresh == null:
		_toast("Não deu para trocar")
		return
	manager.register_player(fresh)
	_selected = fresh
	_refresh_players()
	_select(fresh)
	_toast("%s agora é %s" % [fresh.name, fresh.get_display_name()])


## Se o jogador era quem estava agindo, solta o turno dele para o MatchManager não ficar com um jogador sumido
func _forget(p: Player) -> void:
	if manager == null:
		return
	if manager.protagonist == p or manager.active_player == p:
		manager._clear_roles()
		manager.protagonist = null
		manager.active_player = null
		manager.protagonist_general_left = 0
		manager.protagonist_skill_left = 0
		manager.secondary_general_left = 0
		manager.secondary_skill_left = 0
		if manager.phase == MatchManager.Phase.CHOOSING_ACTION:
			manager._set_phase(MatchManager.Phase.CHOOSING_PROTAGONIST)


# ---------- ADICIONAR ----------

func _add_players() -> void:
	if _roster.is_empty():
		_toast("Nenhuma cena de personagem encontrada (veja CharacterRoster)")
		return
	var entry: Dictionary = _roster[_add_option.selected]
	var scene := load(String(entry["scene"])) as PackedScene
	if scene == null:
		_toast("Não consegui carregar %s" % entry["scene"])
		return
	var team: int = _add_team.get_item_id(_add_team.selected)
	var made: Player = null
	for i in int(_add_count.value):
		var pos := Vector2(randf_range(-420.0, 420.0), randf_range(-280.0, 280.0))
		var f: Field = _field()
		if f != null:
			pos = f.to_global(pos)
		made = spawn_player(scene, team, pos)
	if made != null:
		_refresh_players()
		_select(made)
		_toast("Adicionado: %d x %s (time %d)" % [int(_add_count.value), entry["name"], team])


## Cria um jogador a partir de uma cena e o liga ao jogo (MatchManager, casa, grupo "players")
func spawn_player(scene: PackedScene, team: int, pos: Vector2) -> Player:
	var p := scene.instantiate() as Player
	if p == null:
		return null
	p.team = team   # antes de entrar na cena (a cor e o lado dependem disso)
	var world: Node = manager.get_parent() if manager != null else get_tree().current_scene
	var existing: Node = get_tree().get_first_node_in_group("players")
	if existing != null:
		world = existing.get_parent()
	world.add_child(p, true)
	p.global_position = pos
	p.home_position = pos
	if manager != null:
		manager.register_player(p)
	return p


# ---------- BOLA E ARRASTAR (mouse no campo) ----------

func _mouse_world() -> Vector2:
	var f: Field = _field()
	return f.get_global_mouse_position() if f != null else Vector2.ZERO


func _over_gui() -> bool:
	return get_viewport().gui_get_hovered_control() != null


func _player_at(world_pos: Vector2) -> Player:
	var best: Player = null
	var best_d: float = 48.0
	for p in _all_players():
		var d: float = (p.global_position + Vector2(0.0, -18.0)).distance_to(world_pos)
		if d < best_d:
			best_d = d
			best = p
	return best


func _end_drag() -> void:
	if _dragging != null and is_instance_valid(_dragging):
		_dragging.home_position = _dragging.global_position
	_dragging = null


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F1:
		_toggle_window()
		get_viewport().set_input_as_handled()
		return

	# Bola onde eu clicar
	if _ball_click_mode and event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT and not _over_gui():
			var f: Field = _field()
			if f != null:
				f.reset_ball(f.to_local(_mouse_world()))
			_ball_click_mode = false
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_ball_click_mode = false
			get_viewport().set_input_as_handled()
		return

	# Arrastar jogadores
	if _drag_check == null or not _drag_check.button_pressed:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if _over_gui():
				return
			var p: Player = _player_at(_mouse_world())
			if p != null:
				_dragging = p
				_drag_offset = p.global_position - _mouse_world()
				_select(p)
				get_viewport().set_input_as_handled()
		elif _dragging != null:
			_end_drag()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _dragging != null and is_instance_valid(_dragging):
		_dragging.global_position = _mouse_world() + _drag_offset
		get_viewport().set_input_as_handled()


# ---------- LOOP ----------

func _physics_process(_delta: float) -> void:
	if GameMode.no_cooldowns:
		for p in _all_players():
			if not p.snapshot_cooldowns().is_empty():
				p.restore_cooldowns({})
	if GameMode.infinite_actions and manager != null and manager.protagonist != null:
		manager.protagonist_general_left = maxi(manager.protagonist_general_left, 99)
		manager.protagonist_skill_left = maxi(manager.protagonist_skill_left, 99)
		manager.secondary_general_left = maxi(manager.secondary_general_left, 99)
		manager.secondary_skill_left = maxi(manager.secondary_skill_left, 99)


func _process(delta: float) -> void:
	if _marker != null:
		_marker.target = _selected if (_selected != null and is_instance_valid(_selected) and _window.visible) else null
	_check_timer -= delta
	if _check_timer <= 0.0:
		_check_timer = 0.4
		_refresh_players()
		_update_info()


func _toggle_window() -> void:
	_window.visible = not _window.visible


func _on_window_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F1:
		_toggle_window()
		_window.set_input_as_handled()


func _toast(text: String) -> void:
	if _toast_label == null:
		return
	_toast_label.text = text
	_toast_label.modulate.a = 1.0
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(1.6)
	_toast_tween.tween_property(_toast_label, "modulate:a", 0.0, 0.5)


## Anel em volta do jogador selecionado (desenhado no campo)
class _Marker extends Node2D:
	var target: Player = null

	func _process(_delta: float) -> void:
		visible = target != null
		if target != null and is_instance_valid(target):
			global_position = target.global_position
		queue_redraw()

	func _draw() -> void:
		if target == null or not is_instance_valid(target):
			return
		draw_arc(Vector2(0.0, -18.0), 38.0, 0.0, TAU, 40, SEL_COLOR, 3.0)
		draw_arc(Vector2(0.0, -18.0), 44.0, 0.0, TAU, 40, Color(SEL_COLOR, 0.35), 2.0)
