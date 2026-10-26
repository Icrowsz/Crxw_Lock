class_name GoalReplay
extends Node
## REPLAY DO GOL: depois de um gol, a jogada que deu o gol passa de novo, rápida, com a câmera seguindo a bola
## (e câmera lenta na hora do gol). Um botão (ou Esc / Espaço / Enter) pula o replay.
##
## COMO FUNCIONA
## - Durante o jogo, a cada frame de física em que ALGO se mexe (bola, jogadores, goleiros) guardamos uma "foto"
##   da posição, altura e animação de cada um. Quando ninguém se mexe (jogador pensando, menus) nada é guardado,
##   então o replay mostra só a ação, sem tempo parado.
## - Quando o gol sai, marcamos o ponto do gol. O replay roda quando a bola volta ao centro (o MatchManager chama
##   play_pending() em _on_ball_reset_after_goal); no gol que ENCERRA a partida roda antes da tela do MVP.
## - Rodando: os nós reais da partida são "congelados" (sem process/physics), colocados nas posições gravadas a cada
##   frame, e no fim voltam exatamente para onde estavam. Uma câmera própria segue a bola; a do jogo volta depois.
## - O texto do gol (frase do personagem) continua aparecendo por cima: este script não mexe nele.
##
## DICA: o replay começa quando a bola volta ao centro (Field.reset_delay, 2 s). Para ele começar mais perto da frase
## do gol, diminua o reset_delay do Field.

signal started
signal finished

@export var enabled: bool = true

@export_group("Gravação")
@export var clip_seconds: float = 3.0         # quanto de AÇÃO antes do gol entra no replay
@export var post_seconds: float = 0.5         # quanto depois do gol (a bola na rede)
@export var max_record_seconds: float = 8.0   # memória da gravação
@export var min_clip_seconds: float = 0.5     # menos ação que isto = não vale replay

@export_group("Reprodução")
@export var play_speed: float = 1.6           # velocidade normal do replay
@export var slowmo_speed: float = 0.5         # câmera lenta no finzinho antes do gol
@export var slowmo_seconds: float = 0.5       # quanto dura a câmera lenta (em tempo de jogo)
@export var post_speed: float = 0.7           # velocidade depois do gol
@export var lead_in: float = 1.2              # gol que acaba o jogo: espera isto depois do gol antes de começar
@export var zoom_factor: float = 1.35         # zoom da câmera do replay (em vezes o zoom que o jogo estava)
@export var camera_smooth: float = 7.0
@export var field_margin: float = 150.0       # a câmera não mostra muito além do campo
@export var ui_layer: int = 10

var manager: MatchManager

var _field: Field
var _ball: Ball
var _fps: float = 60.0

# Gravação
var _frames: Array = []                       # cada item: {"b": [pos, altura, rotação], "e": [entidades...]}
var _prev_sig: Dictionary = {}                # id -> Vector3(x, y, altura) do frame anterior (detecta movimento)
var _goal_index: int = -1                     # índice do primeiro frame DEPOIS do gol (-1 = sem gol esperando)
var _goal_time_ms: int = 0
var _goal_info: Dictionary = {}
var _pending: bool = false
var _busy: bool = false

# Reprodução
var _clip: Array = []
var _clip_goal: int = 0
var _cursor: float = 0.0
var _playing: bool = false
var _ended: bool = false
var _skip: bool = false
var _last_us: int = 0
var _snapshot: Array = []
var _cam: Camera2D
var _prev_cam: Camera2D
var _ui: CanvasLayer
var _ui_blink: Label
var _saved_flags: Dictionary = {}
var _hidden_ui: Array = []          # interface escondida durante o replay (volta no fim)
var _hide_check: float = 0.0


func _ready() -> void:
	add_to_group("goal_replay")   # o Field procura por aqui (e espera o replay acabar com wait_if_busy)
	process_mode = Node.PROCESS_MODE_ALWAYS
	_fps = float(Engine.physics_ticks_per_second)
	if manager != null:
		_connect_manager()
	else:
		# Criado fora do MatchManager (ex: pelo Field): o MatchManager chama bind() assim que existir;
		# se ninguém chamar, procura sozinho
		_find_manager.call_deferred()


## Liga este replay ao MatchManager (chamado por ele, ou por _find_manager)
func bind(m: MatchManager) -> void:
	if m == null or manager == m:
		return
	manager = m
	_connect_manager()


func _find_manager() -> void:
	for i in 60:   # o MatchManager pode entrar na árvore uns quadros depois
		if manager != null:
			return
		var m := get_tree().get_first_node_in_group("match_manager") as MatchManager
		if m != null:
			bind(m)
			return
		await get_tree().process_frame
	push_warning("GoalReplay: nenhum MatchManager encontrado; o replay fica desligado.")
	enabled = false


func _connect_manager() -> void:
	if not manager.goal_scored.is_connected(_on_goal):
		manager.goal_scored.connect(_on_goal)
		manager.match_started.connect(_clear)
		manager.formation_started.connect(_clear)


## Para o Field: espera enquanto um replay está tocando (ele segura a volta da bola ao centro)
func wait_if_busy() -> void:
	while _playing or _busy:
		await get_tree().process_frame


func _clear(_arg = null) -> void:
	_frames.clear()
	_prev_sig.clear()
	_goal_index = -1
	_pending = false


# ---------- GRAVAÇÃO ----------

func _physics_process(_delta: float) -> void:
	if not enabled or _playing or manager == null:
		return
	if manager.phase == MatchManager.Phase.FORMATION or manager.phase == MatchManager.Phase.SET_PIECE:
		_frames.clear()   # preparação de falta / formação: nada disso entra num replay
		return
	if manager._repositioning:
		return   # jogadores voltando às posições depois do gol
	if _goal_index >= 0 and _frames.size() >= _goal_index + int(post_seconds * _fps):
		return   # já gravou o depois do gol
	_capture()


func _capture() -> void:
	if _ball == null or not is_instance_valid(_ball):
		_ball = manager._get_ball()
		if _ball == null:
			return
	var moved: bool = false
	var ents: Array = []

	var bsig := Vector3(_ball.global_position.x, _ball.global_position.y, _ball.height)
	if _differs(_ball.get_instance_id(), bsig):
		moved = true
	var ball_rec: Array = [_ball.global_position, _ball.height, _ball.sprite.rotation if _ball.sprite != null else 0.0]

	for p: Player in get_tree().get_nodes_in_group("players"):
		var psig := Vector3(p.global_position.x, p.global_position.y, p.height)
		if _differs(p.get_instance_id(), psig):
			moved = true
		var flip: bool = false
		var anim: StringName = &""
		var frame: int = 0
		if p._has_art and p.animated_sprite != null:
			flip = p.animated_sprite.flip_h
			anim = p.animated_sprite.animation
			frame = p.animated_sprite.frame
		ents.append([p, p.global_position, p.height, flip, anim, frame, p.is_down])

	for k: Goalkeeper in get_tree().get_nodes_in_group("goalkeepers"):
		var ksig := Vector3(k.global_position.x, k.global_position.y, k.height)
		if _differs(k.get_instance_id(), ksig):
			moved = true
		ents.append([k, k.global_position, k.height, int(k.state)])

	if not moved:
		return   # todo mundo parado: não guarda (o replay não mostra tempo morto)
	_frames.append({"b": ball_rec, "e": ents})
	var max_frames: int = int(max_record_seconds * _fps)
	if _goal_index < 0 and _frames.size() > max_frames:
		_frames.pop_front()


## O sinal mudou desde o último frame? (e já guarda o novo)
func _differs(id: int, sig: Vector3) -> bool:
	var old: Variant = _prev_sig.get(id)
	_prev_sig[id] = sig
	return old == null or (old as Vector3).distance_squared_to(sig) > 0.0025


func _on_goal(goal: Dictionary) -> void:
	Player.GoalQuote.last = {}   # a fala deste gol (se tiver) é guardada daqui a pouco
	if not enabled:
		return
	_goal_info = goal
	_goal_index = _frames.size()
	_goal_time_ms = Time.get_ticks_msec()
	_pending = _frames.size() >= int(min_clip_seconds * _fps)


# ---------- COMO O MATCHMANAGER USA ----------

## Tem um replay esperando para rodar?
func has_pending() -> bool:
	return enabled and _pending and Time.get_ticks_msec() - _goal_time_ms < 20000


## Roda o replay do último gol (se houver) e só volta quando ele termina. final = true no gol que encerra o jogo
## (espera `lead_in` depois do gol para o "GOL!" aparecer primeiro).
func play_pending(final: bool = false) -> void:
	if _busy:
		await finished
		return
	if not has_pending():
		return
	_pending = false
	_busy = true
	_field = get_tree().get_first_node_in_group("field") as Field
	_ball = manager._get_ball()

	if final:
		var wait: float = lead_in - float(Time.get_ticks_msec() - _goal_time_ms) / 1000.0
		if wait > 0.0:
			await get_tree().create_timer(wait, true, false, true).timeout
	else:
		# Se o jogador já começou outra ação, espera ela terminar para não mexer em nada no meio
		var started_ms: int = Time.get_ticks_msec()
		while (manager.phase == MatchManager.Phase.EXECUTING or manager.phase == MatchManager.Phase.AIMING) \
				and not manager.match_over and Time.get_ticks_msec() - started_ms < 4000:
			await get_tree().physics_frame

	_clip = _extract_clip()
	if _field != null and _ball != null and _clip.size() >= int(min_clip_seconds * _fps):
		await _play()
	_clear()
	_busy = false
	finished.emit()


## Os frames do replay: [clip_seconds de ação antes do gol] + [post_seconds depois], cortando onde a bola "teleporta"
func _extract_clip() -> Array:
	if _goal_index < 0 or _frames.is_empty():
		return []
	var goal: int = mini(_goal_index, _frames.size())
	var last: int = mini(_frames.size(), goal + int(post_seconds * _fps))
	for i in range(maxi(goal, 1), last):
		if _ball_jump(i):
			last = i   # depois do gol a bola voltou ao centro: o resto não vale
			break
	var first: int = maxi(0, goal - int(clip_seconds * _fps))
	for i in range(goal - 1, first, -1):
		if i >= 1 and _ball_jump(i):
			first = i   # antes, houve uma reposição (saída de bola, por exemplo)
			break
	_clip_goal = goal - first
	return _frames.slice(first, last)


func _ball_jump(i: int) -> bool:
	var a: Vector2 = _frames[i - 1]["b"][0]
	var b: Vector2 = _frames[i]["b"][0]
	return a.distance_to(b) > 300.0


# ---------- REPRODUÇÃO ----------

func _play() -> void:
	_playing = true
	_ended = false
	_skip = false
	_cursor = 0.0
	started.emit()

	_freeze()
	_saved_flags = {
		"repositioning": manager._repositioning,
		"field_physics": _field.is_physics_processing(),
	}
	manager._repositioning = true   # ninguém age durante o replay
	manager.state_changed.emit()
	_field.set_physics_process(false)   # senão a rede e os limites do campo "seguram" a bola gravada

	_build_camera()
	_build_ui()
	_hide_game_ui()
	_show_quote_during_replay()
	_last_us = Time.get_ticks_usec()
	RenderingServer.frame_pre_draw.connect(_tick)   # depois de tweens e process: a nossa posição é a que vale

	while not _ended:
		await get_tree().process_frame
		if Time.get_ticks_usec() - _last_us > 150000:
			_tick()   # sem desenho (ex: teste sem janela) a conta anda por aqui

	RenderingServer.frame_pre_draw.disconnect(_tick)
	_restore()
	_show_game_ui()
	_end_replay_quote()
	_destroy_camera_and_ui()
	_field.set_physics_process(bool(_saved_flags["field_physics"]))
	manager._repositioning = bool(_saved_flags["repositioning"])
	manager.state_changed.emit()
	_playing = false


func _tick() -> void:
	if _ended:
		return
	_keep_ui_hidden()
	var now: int = Time.get_ticks_usec()
	var dt: float = clampf(float(now - _last_us) / 1000000.0, 0.0, 0.1)
	_last_us = now

	# Velocidade: normal, câmera lenta antes do gol, um pouco lenta depois
	var speed: float = play_speed
	var slow_from: float = float(_clip_goal) - slowmo_seconds * _fps
	if _cursor >= float(_clip_goal):
		speed = post_speed
	elif _cursor >= slow_from:
		speed = slowmo_speed
	var before: float = _cursor
	_cursor += dt * _fps * speed

	var last_index: int = _clip.size() - 1
	if _skip or _cursor >= float(last_index):
		_ended = true
		return

	var i: int = int(floor(_cursor))
	var t: float = _cursor - float(i)
	_apply(_clip[i], _clip[i + 1], t, dt)

	# A bola entrou na rede: ela balança
	if before < float(_clip_goal) and _cursor >= float(_clip_goal):
		var v: Vector2 = _ball.velocity
		_field.poke_net(_ball.global_position, v, clampf(v.length() / 700.0, 0.35, 2.0))

	_move_camera(dt)
	if _ui_blink != null:
		_ui_blink.modulate.a = 0.55 + 0.45 * sin(float(now) / 1000000.0 * 6.0)


## Coloca bola, jogadores e goleiros no ponto `t` (0..1) entre os frames a e b
func _apply(a: Dictionary, b: Dictionary, t: float, dt: float) -> void:
	var ba: Array = a["b"]
	var bb: Array = b["b"]
	_ball.global_position = (ba[0] as Vector2).lerp(bb[0], t)
	_ball.height = lerpf(ba[1], bb[1], t)
	_ball.velocity = ((bb[0] as Vector2) - (ba[0] as Vector2)) * _fps
	_ball._update_visuals(dt)   # sombra, profundidade e altura do desenho
	if _ball.sprite != null:
		_ball.sprite.rotation = lerp_angle(ba[2], bb[2], t)

	var ea: Array = a["e"]
	var eb: Array = b["e"]
	for i in ea.size():
		var rec_a: Array = ea[i]
		var node: Object = rec_a[0]
		if not is_instance_valid(node):
			continue
		var rec_b: Array = eb[i] if i < eb.size() and eb[i][0] == node else rec_a
		var pos: Vector2 = (rec_a[1] as Vector2).lerp(rec_b[1], t)
		if node is Player:
			var p: Player = node
			p.global_position = pos
			p.height = lerpf(rec_a[2], rec_b[2], t)
			p.z_index = int(pos.y)
			if p._has_art and p.animated_sprite != null:
				var sprite: AnimatedSprite2D = p.animated_sprite
				sprite.flip_h = rec_a[3]
				if sprite.animation != rec_a[4] and sprite.sprite_frames != null and sprite.sprite_frames.has_animation(rec_a[4]):
					sprite.animation = rec_a[4]
				sprite.frame = rec_a[5]
			if p.is_down != rec_a[6]:
				p.is_down = rec_a[6]
		elif node is Goalkeeper:
			var k: Goalkeeper = node
			k.global_position = pos
			k.height = lerpf(rec_a[2], rec_b[2], t)
			k.z_index = int(pos.y)
			if int(k.state) != rec_a[3]:
				k.state = rec_a[3]


# ---------- CONGELAR / RESTAURAR ----------

func _entities() -> Array:
	var list: Array = [_ball]
	list.append_array(get_tree().get_nodes_in_group("players"))
	list.append_array(get_tree().get_nodes_in_group("goalkeepers"))
	return list


## Guarda o estado de verdade de cada um e para o process/physics deles (o replay é quem manda nas posições)
func _freeze() -> void:
	_snapshot.clear()
	for n in _entities():
		var rec := {
			"node": n,
			"pos": n.global_position,
			"height": n.height,
			"proc": n.is_processing(),
			"phys": n.is_physics_processing(),
		}
		if n is Ball:
			rec["velocity"] = n.velocity
			rec["rot"] = n.sprite.rotation if n.sprite != null else 0.0
		elif n is Player:
			rec["down"] = n.is_down
			rec["z"] = n.z_index
			if n._has_art and n.animated_sprite != null:
				rec["flip"] = n.animated_sprite.flip_h
				rec["anim"] = n.animated_sprite.animation
				rec["frame"] = n.animated_sprite.frame
				rec["playing"] = n.animated_sprite.is_playing()
				n.animated_sprite.pause()   # o replay escolhe o quadro; a animação não anda sozinha
		elif n is Goalkeeper:
			rec["state"] = int(n.state)
		_snapshot.append(rec)
		n.set_process(false)
		n.set_physics_process(false)


func _restore() -> void:
	for rec in _snapshot:
		var n: Object = rec["node"]
		if not is_instance_valid(n):
			continue
		n.global_position = rec["pos"]
		n.height = rec["height"]
		if n is Ball:
			n.velocity = rec["velocity"]
			if n.sprite != null:
				n.sprite.rotation = rec["rot"]
		elif n is Player:
			n.is_down = rec["down"]
			n.z_index = rec["z"]
			if rec.has("anim") and n.animated_sprite != null:
				var sprite: AnimatedSprite2D = n.animated_sprite
				sprite.flip_h = rec["flip"]
				sprite.animation = rec["anim"]
				sprite.frame = rec["frame"]
				if rec["playing"]:
					sprite.play()
		elif n is Goalkeeper:
			n.state = rec["state"]
		n.set_process(rec["proc"])
		n.set_physics_process(rec["phys"])
	_snapshot.clear()


# ---------- CÂMERA ----------

func _build_camera() -> void:
	_prev_cam = get_viewport().get_camera_2d()
	_cam = Camera2D.new()
	_cam.position_smoothing_enabled = false
	_cam.global_position = _ball.global_position
	_cam.zoom = (_prev_cam.zoom if _prev_cam != null else Vector2.ONE) * zoom_factor
	add_child(_cam)
	_cam.make_current()


func _move_camera(dt: float) -> void:
	var target: Vector2 = _ball.global_position + Vector2(0.0, -_ball.height * 0.5)
	target = _clamp_to_field(target)
	_cam.global_position = _cam.global_position.lerp(target, 1.0 - exp(-camera_smooth * dt))


## Mantém a janela da câmera dentro do campo (+ margem), como a câmera do jogo
func _clamp_to_field(pos: Vector2) -> Vector2:
	var half_view: Vector2 = get_viewport().get_visible_rect().size / _cam.zoom * 0.5
	var half_field: Vector2 = _field.pitch_size * 0.5 + Vector2(field_margin, field_margin)
	var center: Vector2 = _field.global_position
	var limit := Vector2(maxf(half_field.x - half_view.x, 0.0), maxf(half_field.y - half_view.y, 0.0))
	return Vector2(center.x + clampf(pos.x - center.x, -limit.x, limit.x),
		center.y + clampf(pos.y - center.y, -limit.y, limit.y))


func _destroy_camera_and_ui() -> void:
	if _prev_cam != null and is_instance_valid(_prev_cam):
		_prev_cam.make_current()
	if _cam != null:
		_cam.queue_free()
		_cam = null
	if _ui != null:
		_ui.queue_free()
		_ui = null
	_ui_blink = null


# ---------- INTERFACE ----------

## Replay = modo "limpo" (como o F3): some placar, menus, avisos de gol e botões. Ficam só o replay (barras,
## "REPLAY", botão de pular) e a FALA do gol (Player.GoalQuote).
func _hide_game_ui() -> void:
	_hidden_ui.clear()
	_hide_check = 0.0
	_keep_ui_hidden(true)


func _is_kept(layer: CanvasLayer) -> bool:
	return layer == _ui or layer.layer >= 100 or layer is Player.GoalQuote


func _collect_layers(node: Node, out: Array) -> void:
	for child in node.get_children():
		if child is CanvasLayer:
			out.append(child)
		_collect_layers(child, out)


## Esconde (e guarda para devolver) tudo que aparece. Roda sempre: o menu de ações e o placar se reexibem sozinhos.
func _keep_ui_hidden(force_scan: bool = false) -> void:
	for item in _hidden_ui:
		if is_instance_valid(item) and item.visible:
			item.visible = false
	_hide_check -= get_physics_process_delta_time()
	if not force_scan and _hide_check > 0.0:
		return
	_hide_check = 0.25
	var layers: Array = []
	_collect_layers(get_tree().root, layers)
	for layer: CanvasLayer in layers:
		if layer.visible and not _is_kept(layer):
			layer.visible = false
			if not _hidden_ui.has(layer):
				_hidden_ui.append(layer)
	var scene: Node = get_tree().current_scene
	if scene != null:
		for child in scene.get_children():
			if child is Control and (child as Control).visible:
				(child as Control).visible = false
				if not _hidden_ui.has(child):
					_hidden_ui.append(child)


var _replay_quote: Node = null

## A fala do gol (frase do personagem) fica na tela durante TODO o replay
func _show_quote_during_replay() -> void:
	_replay_quote = null
	var q: Dictionary = Player.GoalQuote.last
	if q.is_empty():
		return
	var seconds: float = float(_clip.size()) / maxf(_fps, 1.0) / maxf(play_speed, 0.1) + 2.0
	Player.GoalQuote.show_quote(self, q["face"], q["who"], q["text"], q["color"], seconds)
	_replay_quote = Player.GoalQuote.current


func _end_replay_quote() -> void:
	if _replay_quote != null and is_instance_valid(_replay_quote) and Player.GoalQuote.current == _replay_quote:
		_replay_quote.queue_free()
	_replay_quote = null


func _show_game_ui() -> void:
	for item in _hidden_ui:
		if is_instance_valid(item):
			item.visible = true
	_hidden_ui.clear()


func _build_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.layer = ui_layer
	add_child(_ui)

	for at_top in [true, false]:
		var bar := ColorRect.new()
		bar.color = Color(0.0, 0.0, 0.0, 0.82)
		bar.set_anchors_preset(Control.PRESET_TOP_WIDE if at_top else Control.PRESET_BOTTOM_WIDE)
		bar.custom_minimum_size = Vector2(0.0, 56.0)
		bar.size = Vector2(0.0, 56.0)
		if not at_top:
			bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_ui.add_child(bar)

	_ui_blink = UiStyle.make_label("●  REPLAY", 28, UiStyle.BAD_COLOR)
	_ui_blink.position = Vector2(24.0, 10.0)
	_ui.add_child(_ui_blink)

	var scorer: String = String(_goal_info.get("scorer", ""))
	var has_quote: bool = not Player.GoalQuote.last.is_empty()
	if scorer != "" and scorer != "Ninguém" and not has_quote:   # com fala na tela, o nome já aparece nela
		var who: Label = UiStyle.make_label("Gol de %s" % scorer, 24)
		who.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
		who.grow_vertical = Control.GROW_DIRECTION_BEGIN
		who.offset_left = 24.0
		who.offset_bottom = -12.0
		_ui.add_child(who)

	var skip := Button.new()
	skip.text = "Pular replay  ▸▸  (Esc)"
	skip.custom_minimum_size = Vector2(250.0, 40.0)
	UiStyle.style_button(skip)
	skip.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	skip.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	skip.grow_vertical = Control.GROW_DIRECTION_BEGIN
	skip.offset_right = -20.0
	skip.offset_bottom = -8.0
	skip.pressed.connect(func() -> void: _skip = true)
	_ui.add_child(skip)
	UiStyle.pop(skip, 1.2, 0.3)


func _input(event: InputEvent) -> void:
	if not _playing or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if event.keycode == KEY_ESCAPE or event.keycode == KEY_SPACE or event.keycode == KEY_ENTER \
			or event.keycode == KEY_KP_ENTER:
		_skip = true
		get_viewport().set_input_as_handled()
