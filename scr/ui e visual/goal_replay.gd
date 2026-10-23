class_name GoalReplay
extends Node
## Replay de gol: um replay curto das jogadas antes do gol, com a câmera seguindo a bola (sem sair do campo),
## letterbox, legenda do gol e botão "Pular replay".
##
## Como funciona (sem mexer no MatchManager):
## - GRAVA: a cada quadro de gravação guarda a posição e a altura da bola e de todos os jogadores/goleiros
##   (só os últimos record_seconds segundos, uns 250 quadros: quase nenhum custo).
## - REPRODUZ: quando a bola entra, espera start_delay (comemoração e frases do gol) e então esconde os
##   personagens de verdade e desenha "fantasmas" (rostinho no círculo do time) seguindo a gravação, a 1.6x,
##   com câmera lenta perto do gol. Uma câmera própria segue a bola e nunca mostra o que está fora do campo.
##   Os personagens de verdade não são mexidos: só ficam escondidos e voltam no fim.
## - O Field segura a volta da bola ao centro até o replay acabar (Field._reset_after_delay chama wait_if_busy).
##
## SINCRONIA COM AS FRASES DO GOL:
## - O banner "GOL!" (ScoreHud) e a fala do artilheiro (Player.GoalQuote, rostinho + frase) continuam na tela
##   durante o replay: o replay não esconde nenhum dos dois.
## - Se o artilheiro tem fala, o replay começa JUNTO com ela (espera a fala aparecer, uns 0.8 s depois do gol)
##   e a velocidade é ajustada para o replay acabar quando a fala termina (goal_line_time do jogador).
##   Sem fala, o replay começa depois de start_delay.
## - As faixas pretas ficam ABAIXO do placar e da fala, para não cobrir o texto.
##
## O Field cria este nó sozinho (export goal_replay no Field). Também dá para pôr um GoalReplay na cena.
## Pular: botão na tela ou Espaço / Enter / Esc.

signal finished

@export var enabled: bool = false
@export_group("Gravação")
@export var record_hz: float = 60.0
@export var record_seconds: float = 9.0
@export_group("Replay")
@export var start_delay: float = 1.0          # sem fala do artilheiro: tempo depois do gol até o replay começar
@export var quote_wait_max: float = 1.6       # com fala: espera até esse tempo (s) a fala aparecer; o replay começa junto
@export var quote_end_margin: float = 0.5     # o replay termina um pouco antes da fala sumir
@export var pre_seconds: float = 6.0          # quanto antes do gol o replay começa
@export var post_seconds: float = 0.8         # quanto depois do gol ele termina
@export var play_speed: float = 1.6           # velocidade normal do replay (rápido, para não gastar tempo)
@export var slow_speed: float = 0.6           # velocidade perto do gol
@export var slow_before: float = 0.6          # segundos antes do gol em que fica em câmera lenta
@export var slow_after: float = 0.5           # ...e depois do gol
@export_group("Câmera")
@export var camera_zoom_mult: float = 1.3     # vezes o zoom da câmera do jogo (maior = mais perto)
@export var camera_follow_speed: float = 7.0  # quão rápido a câmera alcança a bola
@export var field_margin: Vector2 = Vector2(120.0, 50.0)   # quanto além das linhas a câmera pode mostrar (a rede cabe)
@export_group("Tela")
@export var bar_height: float = 72.0          # faixas pretas de cima e de baixo
@export var bars_layer: int = 9               # faixas pretas e REPLAY: ABAIXO do placar (10) e da fala do gol (11)
@export var ui_layer: int = 12                # botão de pular e bloqueio de cliques; bloqueia o modo foto (F3) enquanto toca

var _field: Field
var _manager: MatchManager
var _clock: float = 0.0
var _acc: float = 0.0
var _frames: Array[_Frame] = []
var _info: Dictionary = {}        # id do nó -> {team, tex, name, keeper}
var _ball_info: Dictionary = {}   # {tex, size, radius}

var _busy: bool = false           # do gol até o replay acabar (o Field espera por isso)
var _playing: bool = false
var _skip: bool = false
var _goal_t: float = 0.0
var _goal_team: int = -1
var _scorer_id: int = 0
var _quote_hold: float = 0.0      # quanto tempo a fala do gol fica na tela (0 = sem fala)
var _speed_scale: float = 1.0     # ajuste de velocidade para o replay acabar junto com a fala

var _play_t: float = 0.0
var _start_t: float = 0.0
var _end_t: float = 0.0
var _idx: int = 0

var _stage: _Stage
var _cam: Camera2D
var _prev_cam: Camera2D
var _layer: CanvasLayer           # botão de pular + bloqueio de cliques (acima de tudo)
var _bars_layer: CanvasLayer      # faixas pretas e REPLAY (abaixo do placar e da fala)
var _top_bar: ColorRect
var _bottom_bar: ColorRect
var _tag: Label
var _progress: ColorRect
var _skip_button: Button
var _hidden_ui: Array = []
var _hidden_nodes: Array = []     # [nó, visível antes]
var _ui_check: float = 0.0


func _ready() -> void:
	add_to_group("goal_replay")
	_field = get_parent() as Field
	if _field == null:
		_field = get_tree().get_first_node_in_group("field") as Field
	if _field == null:
		push_warning("GoalReplay: nenhum Field encontrado; o replay não vai funcionar.")
		enabled = false
		return
	_field.goal_scored.connect(_on_goal)


# ---------- GRAVAÇÃO ----------

func _physics_process(delta: float) -> void:
	_clock += delta
	if not enabled or _playing or _field == null or _field.ball == null:
		return
	_acc += delta
	var step: float = 1.0 / maxf(record_hz, 5.0)
	if _acc < step:
		return
	_acc = fmod(_acc, step)
	_capture()


func _tracked_nodes() -> Array[Node2D]:
	var out: Array[Node2D] = []
	for n in get_tree().get_nodes_in_group("players"):
		if n is Node2D:
			out.append(n)
	for n in get_tree().get_nodes_in_group("goalkeepers"):
		if n is Node2D and not out.has(n):
			out.append(n)
	return out


func _capture() -> void:
	var ball: Ball = _field.ball
	var f := _Frame.new()
	f.t = _clock
	f.ball_pos = ball.global_position
	f.ball_h = ball.height
	if _ball_info.is_empty() and ball.sprite != null and ball.sprite.texture != null:
		_ball_info = {
			"tex": ball.sprite.texture,
			"size": ball.sprite.texture.get_size() * ball.sprite.global_scale,
			"radius": ball.collision_radius,
		}
	for n in _tracked_nodes():
		var id: int = n.get_instance_id()
		f.index[id] = f.ids.size()
		f.ids.append(id)
		f.pos.append(n.global_position)
		var h = n.get("height")
		f.h.append(float(h) if h != null else 0.0)
		var down = n.get("is_down")
		f.down.append(1 if (down != null and bool(down)) else 0)
		if not _info.has(id):
			_info[id] = _make_info(n)
	_frames.append(f)
	while _frames.size() > 2 and _frames[0].t < _clock - record_seconds:
		_frames.pop_front()


func _make_info(n: Node2D) -> Dictionary:
	var team = n.get("team")
	var keeper_id = n.get("keeper_id")
	var char_id = n.get("character_id")
	var tex: Texture2D = null
	var who: String = ""
	if keeper_id != null:
		tex = KeeperRoster.face_for(str(keeper_id))
	elif char_id != null:
		tex = CharacterRoster.face_for(str(char_id))
	if n.has_method("get_display_name"):
		who = str(n.call("get_display_name"))
	var radius = n.get("placeholder_radius")
	return {
		"team": int(team) if team != null else 0,
		"tex": tex,
		"name": who,
		"keeper": keeper_id != null,
		"radius": float(radius) if radius != null else 20.0,
	}


# ---------- GOL: AGENDA O REPLAY ----------

func _on_goal(team: int) -> void:
	if not enabled or _busy:
		return
	_busy = true   # segura a volta da bola ao centro (o Field espera em wait_if_busy)
	_goal_t = _clock
	_goal_team = team
	var quote_before = Player.GoalQuote.current   # a fala que já estava na tela (se houver): não vale (sem tipo: pode já ter sido liberada)
	await get_tree().process_frame   # deixa o MatchManager contar o gol (goal_log, último a tocar)
	_read_goal_info()

	# Com fala do artilheiro: o replay começa junto com ela. Sem fala: depois de start_delay.
	_quote_hold = 0.0
	if _expects_quote():
		var waited: float = 0.0
		while waited < quote_wait_max:
			var q = Player.GoalQuote.current
			if q != null and is_instance_valid(q) and q != quote_before:
				_quote_hold = _scorer_quote_hold()
				break
			await get_tree().process_frame
			waited += get_process_delta_time()
	else:
		await get_tree().create_timer(start_delay).timeout

	if not _can_play():
		_busy = false
		finished.emit()
		return
	await _play()


## O artilheiro vai falar? (mesma regra do Player: gol normal, e a lista de falas dele tem a fala deste gol)
func _expects_quote() -> bool:
	var scorer: Object = instance_from_id(_scorer_id) if _scorer_id != 0 else null
	var m: MatchManager = _manager_ref()
	if scorer == null or m == null or not scorer.has_method("get_goal_line"):
		return false
	var who: String = str(scorer.call("get_display_name"))
	var team = scorer.get("team")
	var number: int = 0
	for g: Dictionary in m.goal_log:
		if not bool(g.get("own_goal", false)) and int(g.get("team", -1)) == int(team) \
				and str(g.get("scorer", "")) == who:
			number += 1
	return str(scorer.call("get_goal_line", number)) != ""


## Quanto tempo a fala fica na tela (entra em 0.25 s, fica goal_line_time do jogador)
func _scorer_quote_hold() -> float:
	var scorer: Object = instance_from_id(_scorer_id) if _scorer_id != 0 else null
	var hold = scorer.get("goal_line_time") if scorer != null else null
	return (float(hold) if hold != null else 3.5) + 0.25


## O Field chama isto antes de recolocar a bola: se há replay (agendado ou tocando), espera ele acabar
func wait_if_busy() -> void:
	if _busy:
		await finished


func _manager_ref() -> MatchManager:
	if _manager == null or not is_instance_valid(_manager):
		_manager = get_tree().get_first_node_in_group("match_manager") as MatchManager
	return _manager


func _read_goal_info() -> void:
	_scorer_id = 0
	var ball: Ball = _field.ball
	if ball != null and ball.last_toucher != null and is_instance_valid(ball.last_toucher):
		_scorer_id = ball.last_toucher.get_instance_id()
	var m: MatchManager = _manager_ref()
	if m != null and not m.goal_log.is_empty():
		var goal: Dictionary = m.goal_log.back()
		if bool(goal.get("own_goal", false)):
			_scorer_id = 0   # gol contra: ninguém é destacado como artilheiro (e não tem fala)


func _can_play() -> bool:
	var m: MatchManager = _manager_ref()
	if m != null and (m.match_over or m.phase == MatchManager.Phase.FORMATION):
		return false   # o fim da partida tem a própria apresentação
	if _frames.size() < 8 or _ball_info.is_empty():
		return false
	return true


# ---------- REPLAY ----------

func _play() -> void:
	_playing = true
	_skip = false
	_start_t = maxf(_frames[0].t, _goal_t - pre_seconds)
	_end_t = minf(_frames[_frames.size() - 1].t, _goal_t + post_seconds)
	_play_t = _start_t
	_idx = 0
	# Com fala na tela: ajusta a velocidade para o replay acabar um pouco antes de ela sumir
	_speed_scale = 1.0
	if _quote_hold > 0.0:
		var target: float = maxf(_quote_hold - 0.3 - quote_end_margin, 1.5)   # 0.3 s: as faixas entrando
		_speed_scale = clampf(_natural_duration() / target, 0.6, 2.0)
	for i in _frames.size():
		if _frames[i].t >= _start_t:
			_idx = maxi(i - 1, 0)
			break

	_hide_real_nodes()
	_build_stage()
	_build_ui()
	_hide_ui()
	_take_camera()
	await _bars_in()

	while _playing and not _skip and _play_t < _end_t:
		await get_tree().process_frame
		var dt: float = get_process_delta_time()
		_play_t += dt * _speed_at(_play_t)
		_update_frame(dt)
		_enforce_ui(dt)

	await _bars_out()
	_finish()


func _speed_at(t: float) -> float:
	var base: float = slow_speed if (t >= _goal_t - slow_before and t <= _goal_t + slow_after) else play_speed
	return base * _speed_scale


## Quanto o replay duraria nas velocidades normais (sem o ajuste para a fala)
func _natural_duration() -> float:
	var total: float = _end_t - _start_t
	var slow_len: float = maxf(0.0, minf(_end_t, _goal_t + slow_after) - maxf(_start_t, _goal_t - slow_before))
	return (total - slow_len) / play_speed + slow_len / slow_speed


func _finish() -> void:
	_playing = false
	if _stage != null:
		_stage.queue_free()
		_stage = null
	_restore_camera()
	_restore_real_nodes()
	_show_ui()
	if _layer != null:
		_layer.queue_free()
		_layer = null
	if _bars_layer != null:
		_bars_layer.queue_free()
		_bars_layer = null
	_busy = false
	finished.emit()


func _input(event: InputEvent) -> void:
	_check_skip_key(event)


func _check_skip_key(event: InputEvent) -> void:
	if not _playing or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER \
			or event.keycode == KEY_ESCAPE:
		_skip = true
		get_viewport().set_input_as_handled()


# ---------- QUADRO DO REPLAY ----------

## Posição e altura da bola e dos jogadores no instante _play_t (interpolando entre dois quadros gravados)
func _sample(t: float) -> Dictionary:
	while _idx + 1 < _frames.size() - 1 and _frames[_idx + 1].t <= t:
		_idx += 1
	var a: _Frame = _frames[_idx]
	var b: _Frame = _frames[mini(_idx + 1, _frames.size() - 1)]
	var k: float = 0.0
	if b.t > a.t:
		k = clampf((t - a.t) / (b.t - a.t), 0.0, 1.0)
	var ents: Array = []
	for i in a.ids.size():
		var id: int = a.ids[i]
		var pa: Vector2 = a.pos[i]
		var ha: float = a.h[i]
		var pb: Vector2 = pa
		var hb: float = ha
		if b.index.has(id):
			var j: int = b.index[id]
			pb = b.pos[j]
			hb = b.h[j]
		ents.append({"id": id, "pos": pa.lerp(pb, k), "h": lerpf(ha, hb, k), "down": a.down[i] == 1})
	return {
		"ball_pos": a.ball_pos.lerp(b.ball_pos, k),
		"ball_h": lerpf(a.ball_h, b.ball_h, k),
		"ents": ents,
		"t": t,
	}


func _update_frame(dt: float) -> void:
	var state: Dictionary = _sample(_play_t)
	if _stage != null:
		_stage.state = state
		_stage.queue_redraw()
	# Câmera segue a bola (no chão, sem a altura) e nunca sai do campo
	if _cam != null:
		var target: Vector2 = _clamp_camera(state["ball_pos"], _cam.zoom)
		_cam.global_position = _cam.global_position.lerp(target, 1.0 - exp(-camera_follow_speed * dt))
		_cam.global_position = _clamp_camera(_cam.global_position, _cam.zoom)
	# Barra de progresso e piscar do REPLAY
	if _progress != null and _bottom_bar != null:
		var total: float = maxf(_end_t - _start_t, 0.01)
		_progress.size.x = _bottom_bar.size.x * clampf((_play_t - _start_t) / total, 0.0, 1.0)
	if _tag != null:
		_tag.modulate.a = 0.65 + 0.35 * sin(Time.get_ticks_msec() * 0.008)


## Centro da câmera que mantém a tela dentro do campo (mais uma folga para ver a rede)
func _clamp_camera(pos: Vector2, zoom: Vector2) -> Vector2:
	var half_view: Vector2 = get_viewport().get_visible_rect().size / zoom * 0.5
	var half_field: Vector2 = _field.pitch_size * 0.5 + field_margin
	var center: Vector2 = _field.global_position
	var out: Vector2 = pos
	if half_view.x >= half_field.x:
		out.x = center.x
	else:
		out.x = clampf(pos.x, center.x - half_field.x + half_view.x, center.x + half_field.x - half_view.x)
	if half_view.y >= half_field.y:
		out.y = center.y
	else:
		out.y = clampf(pos.y, center.y - half_field.y + half_view.y, center.y + half_field.y - half_view.y)
	return out


# ---------- CÂMERA ----------

func _take_camera() -> void:
	_prev_cam = get_viewport().get_camera_2d()
	_cam = Camera2D.new()
	_cam.position_smoothing_enabled = false   # a suavização é feita aqui, junto com o limite do campo
	var base_zoom: Vector2 = _prev_cam.zoom if _prev_cam != null else Vector2.ONE
	_cam.zoom = base_zoom * camera_zoom_mult
	add_child(_cam)
	var start: Vector2 = _sample(_start_t)["ball_pos"]
	_cam.global_position = _clamp_camera(start, _cam.zoom)
	_cam.make_current()


func _restore_camera() -> void:
	if _cam != null and is_instance_valid(_cam):
		_cam.enabled = false
		_cam.queue_free()
	_cam = null
	if _prev_cam != null and is_instance_valid(_prev_cam):
		_prev_cam.make_current()
	_prev_cam = null


# ---------- PERSONAGENS DE VERDADE: escondidos durante o replay ----------

func _hide_real_nodes() -> void:
	_hidden_nodes.clear()
	var ball: Ball = _field.ball
	if ball != null:
		_hidden_nodes.append([ball, ball.visible])
		ball.visible = false
	for n in _tracked_nodes():
		_hidden_nodes.append([n, n.visible])
		n.visible = false


func _restore_real_nodes() -> void:
	for entry in _hidden_nodes:
		var n: Node2D = entry[0]
		if is_instance_valid(n):
			n.visible = entry[1]
	_hidden_nodes.clear()


# ---------- INTERFACE ----------

func _build_stage() -> void:
	_stage = _Stage.new()
	_stage.replay = self
	_stage.z_as_relative = false
	_stage.z_index = 3500   # acima de tudo no campo
	_field.add_child(_stage)


func _build_ui() -> void:
	# Faixas pretas e REPLAY ficam ABAIXO do placar (10) e da fala do gol (11): não cobrem o texto
	_bars_layer = CanvasLayer.new()
	_bars_layer.layer = bars_layer
	add_child(_bars_layer)
	var bar_color := Color(0.0, 0.0, 0.0, 0.88)
	_top_bar = ColorRect.new()
	_top_bar.color = bar_color
	_top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_top_bar.offset_bottom = bar_height
	_top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bars_layer.add_child(_top_bar)
	_bottom_bar = ColorRect.new()
	_bottom_bar.color = bar_color
	_bottom_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_bottom_bar.offset_top = -bar_height
	_bottom_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bars_layer.add_child(_bottom_bar)

	# REPLAY (piscando) na faixa de baixo, à esquerda (o banner do gol fica no topo)
	_tag = UiStyle.make_label("●  REPLAY", 34, UiStyle.BAD_COLOR)
	_tag.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	_tag.offset_left = 36.0
	_tag.offset_top = -22.0
	_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bottom_bar.add_child(_tag)

	# Linha de progresso na beirada de cima da faixa de baixo
	_progress = ColorRect.new()
	_progress.color = UiStyle.ACCENT_COLOR
	_progress.position = Vector2(0.0, 0.0)
	_progress.size = Vector2(0.0, 4.0)
	_progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bottom_bar.add_child(_progress)

	# Camada de cima: segura os cliques e tem o botão de pular (também bloqueia o F3)
	_layer = CanvasLayer.new()
	_layer.layer = ui_layer
	add_child(_layer)
	var blocker := Control.new()
	blocker.set_anchors_preset(Control.PRESET_FULL_RECT)
	blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	_layer.add_child(blocker)

	_skip_button = Button.new()
	_skip_button.text = "Pular replay  [Espaço]"
	_skip_button.add_theme_font_size_override("font_size", 22)
	UiStyle.style_button(_skip_button, UiStyle.ACCENT_COLOR.darkened(0.25))
	# Fica dentro da faixa de baixo, à direita
	var button_h: float = minf(48.0, bar_height - 16.0)
	var margin: float = (bar_height - button_h) * 0.5
	_skip_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_skip_button.offset_right = -36.0
	_skip_button.offset_left = -36.0 - 250.0
	_skip_button.offset_bottom = -margin
	_skip_button.offset_top = -margin - button_h
	_skip_button.modulate.a = 0.0
	_skip_button.pressed.connect(func() -> void: _skip = true)
	_layer.add_child(_skip_button)


## As faixas "deslizam" para dentro (a de baixo descansa em altura da tela - bar_height)
func _bars_in() -> void:
	var screen_h: float = get_viewport().get_visible_rect().size.y
	_top_bar.position.y = -bar_height
	_bottom_bar.position.y = screen_h
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_skip_button, "modulate:a", 1.0, 0.3)
	tw.tween_property(_top_bar, "position:y", 0.0, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_bottom_bar, "position:y", screen_h - bar_height, 0.3) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tw.finished


func _bars_out() -> void:
	if _top_bar == null or _bottom_bar == null:
		return
	var screen_h: float = get_viewport().get_visible_rect().size.y
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_skip_button, "modulate:a", 0.0, 0.2)
	tw.tween_property(_top_bar, "position:y", -bar_height, 0.2)
	tw.tween_property(_bottom_bar, "position:y", screen_h, 0.2)
	await tw.finished


## Esconde o resto da interface (menu de ações, placar...) enquanto o replay toca
func _hide_ui() -> void:
	var layers: Array[CanvasLayer] = []
	_collect_layers(get_tree().root, layers)
	for layer in layers:
		if _keep_visible(layer):
			continue
		if layer.visible and layer.layer < ui_layer:
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


## O que NÃO se esconde no replay: o nosso, o placar (com o banner "GOL!") e a fala do gol do artilheiro
func _keep_visible(layer: CanvasLayer) -> bool:
	return layer == _layer or layer == _bars_layer or layer is ScoreHud or layer is Player.GoalQuote


func _collect_layers(node: Node, out: Array[CanvasLayer]) -> void:
	for child in node.get_children():
		if child is CanvasLayer:
			out.append(child)
		_collect_layers(child, out)


## Alguns menus se reexibem sozinhos a cada mudança de estado: esconde de novo todo quadro
func _enforce_ui(dt: float) -> void:
	for item in _hidden_ui:
		if is_instance_valid(item) and item.visible:
			item.visible = false
	_ui_check -= dt
	if _ui_check <= 0.0:
		_ui_check = 0.3
		_hide_ui()


func _show_ui() -> void:
	for item in _hidden_ui:
		if is_instance_valid(item):
			item.visible = true
	_hidden_ui.clear()


# ---------- QUADRO GRAVADO ----------

class _Frame extends RefCounted:
	var t: float = 0.0
	var ball_pos: Vector2 = Vector2.ZERO
	var ball_h: float = 0.0
	var ids: PackedInt64Array = PackedInt64Array()
	var pos: PackedVector2Array = PackedVector2Array()
	var h: PackedFloat32Array = PackedFloat32Array()
	var down: PackedByteArray = PackedByteArray()
	var index: Dictionary = {}   # id -> posição nos vetores acima


# ---------- DESENHO DO REPLAY (no campo, em coordenadas do mundo) ----------

class _Stage extends Node2D:
	var replay: GoalReplay
	var state: Dictionary = {}
	var _trail: Array[Vector2] = []

	func _draw() -> void:
		if replay == null or state.is_empty():
			return
		var ents: Array = state["ents"]
		# De trás para a frente (quem está mais embaixo na tela aparece por cima)
		ents.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return (a["pos"] as Vector2).y < (b["pos"] as Vector2).y)

		var ball_pos: Vector2 = to_local(state["ball_pos"])
		var ball_h: float = state["ball_h"]
		var ball_drawn: bool = false
		for e: Dictionary in ents:
			var p: Vector2 = to_local(e["pos"])
			# A bola é desenhada na ordem de profundidade (atrás de quem está à frente dela)
			if not ball_drawn and ball_pos.y <= p.y:
				_draw_ball(ball_pos, ball_h)
				ball_drawn = true
			_draw_entity(e, p)
		if not ball_drawn:
			_draw_ball(ball_pos, ball_h)

	func _draw_entity(e: Dictionary, p: Vector2) -> void:
		var info: Dictionary = replay._info.get(e["id"], {})
		var team: int = int(info.get("team", 0))
		var r: float = float(info.get("radius", 20.0))
		var tex: Texture2D = info.get("tex")
		var h: float = e["h"]
		var down: bool = e["down"]
		var color: Color = TeamStyle.color_of(team)
		var scorer: bool = e["id"] == replay._scorer_id
		var alpha: float = 0.55 if down else 1.0

		# Sombra no chão
		draw_set_transform(p, 0.0, Vector2(1.0, 0.35))
		draw_circle(Vector2.ZERO, r * (0.95 - minf(h, 80.0) * 0.003), Color(0, 0, 0, 0.32 * alpha))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

		var c: Vector2 = p + Vector2(0.0, -h - r * 0.2)
		draw_circle(c, r + 3.0, Color(color, alpha))
		if tex != null:
			_draw_face(tex, c, r, Color(1, 1, 1, alpha))
		else:
			draw_circle(c, r, Color(color.darkened(0.4), alpha))
		if scorer:
			# Quem fez o gol: anel amarelo e uma setinha em cima
			draw_arc(c, r + 7.0, 0.0, TAU, 40, Color(1.0, 0.85, 0.2), 4.0)
			var tip: Vector2 = c + Vector2(0.0, -r - 16.0)
			draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(-9.0, -14.0), tip + Vector2(9.0, -14.0)]),
				Color(1.0, 0.85, 0.2))

	func _draw_face(tex: Texture2D, center: Vector2, radius: float, tint: Color) -> void:
		var aspect: float = float(tex.get_width()) / maxf(float(tex.get_height()), 1.0)
		var su: float = 1.0 / aspect if aspect >= 1.0 else 1.0
		var sv: float = 1.0 if aspect >= 1.0 else aspect
		var cv: float = 0.5 - maxf(0.0, 1.0 - aspect) * 0.25   # retrato alto: foca na parte de cima
		var pts := PackedVector2Array()
		var uvs := PackedVector2Array()
		for i in 28:
			var a: float = TAU * float(i) / 28.0
			pts.append(center + Vector2(cos(a), sin(a)) * radius)
			uvs.append(Vector2(0.5 + 0.5 * cos(a) * su, cv + 0.5 * sin(a) * sv))
		draw_colored_polygon(pts, tint, uvs, tex)

	func _draw_ball(p: Vector2, h: float) -> void:
		var info: Dictionary = replay._ball_info
		var r: float = float(info.get("radius", 10.0))
		# Rastro: some aos poucos
		_trail.append(p + Vector2(0.0, -h))
		if _trail.size() > 14:
			_trail.pop_front()
		for i in range(1, _trail.size()):
			var k: float = float(i) / float(_trail.size())
			draw_line(_trail[i - 1], _trail[i], Color(1, 1, 1, 0.45 * k), 1.0 + 4.0 * k)
		# Sombra no chão (menor quanto mais alta a bola)
		draw_set_transform(p, 0.0, Vector2(1.0, 0.4))
		draw_circle(Vector2.ZERO, r * (1.0 - minf(h, 120.0) * 0.003), Color(0, 0, 0, 0.35))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		var tex: Texture2D = info.get("tex")
		var pos: Vector2 = p + Vector2(0.0, -h)
		if tex != null:
			var size: Vector2 = info.get("size", Vector2(r, r) * 2.0)
			draw_texture_rect(tex, Rect2(pos - size * 0.5, size), false)
		else:
			draw_circle(pos, r, Color(0.96, 0.96, 0.96))
