class_name GameCamera
extends Camera2D
## Câmera do jogo. Anexe este script ao nó Camera2D da cena Main.
##
## - Clicou num jogador do time da vez (e ele virou o jogador que vai agir): a câmera dá zoom
##   nele e ACOMPANHA a jogada (corrida, carrinho...). Quando a bola sai em velocidade, a
##   câmera passa a seguir a bola, para dar para ver o chute.
## - Tecla C: volta ao enquadramento normal. Apertar C de novo volta ao jogador.
## - Volta sozinha ao normal quando o turno acaba, quando sai gol e quando a partida começa.
## - Na escolha do alvo do Passe o zoom abre um pouco, para dar para ver os companheiros.
## - F3: MODO FOTO. Esconde a interface e libera a câmera: roda do mouse = zoom, botão do meio
##   (segurar e arrastar) ou setas = mover, R = centralizar. F3 de novo volta tudo. Fica aqui
##   (e não no Field) porque é esta câmera que manda no zoom e na posição a cada quadro.
##
## Não mexe em nada do MatchManager: só escuta o sinal `clicked` dos jogadores e lê
## active_player / phase / turn_ended / goal_scored do MatchManager.

const ACTION_TOGGLE: StringName = &"toggle_camera"
const ACTION_PHOTO: StringName = &"toggle_photo_mode"

## Zoom ao focar, em múltiplos do zoom normal da câmera (1.6 = 60% mais perto)
@export var focus_zoom: float = 1.8
## Zoom enquanto escolhe o alvo do Passe
@export var pass_target_zoom: float = 1.15
## Velocidade da transição (maior = mais rápido)
@export var smooth_speed: float = 6.0
## Segue a bola quando ela sai em velocidade durante a jogada
@export var follow_ball_in_motion: bool = true
@export var ball_speed_threshold: float = 120.0
## Não deixa a câmera mostrar muito além do campo (a borda de fora do campo, em px)
@export var clamp_to_field: bool = true
@export var field_margin: float = 150.0

@export_group("Modo foto (F3)")
## Telas acima desta camada (formação, pausa...) bloqueiam o modo foto
@export var photo_modal_layer: int = 10
## Limites do zoom do modo foto, em vezes o zoom normal da câmera
@export var photo_zoom_range: Vector2 = Vector2(0.5, 3.0)
## No modo foto dá para olhar mais além das bordas do campo (para ver o banco e a grama de fora)
@export var photo_field_margin: float = 700.0
@export var photo_pan_speed: float = 700.0

var _home_position: Vector2
var _home_zoom: Vector2
var _focused: bool = false
var _manager: MatchManager = null

## Modo foto
var _photo_mode: bool = false
var _photo_hidden: Array = []        # CanvasLayers e Controls escondidos (voltam ao sair)
var _photo_zoom: float = 1.0         # em vezes o zoom normal
var _photo_pan: Vector2 = Vector2.ZERO
var _photo_check: float = 0.0
var _toast_layer: CanvasLayer
var _toast_label: Label
var _toast_tween: Tween


func _ready() -> void:
	_ensure_input_map()
	_home_position = global_position
	_home_zoom = zoom
	_setup.call_deferred()   # o MatchManager e os jogadores entram na árvore no mesmo frame


## Cria a ação "toggle_camera" (tecla C) caso você ainda não tenha criado no InputMap
static func _ensure_input_map() -> void:
	if not InputMap.has_action(ACTION_TOGGLE):
		InputMap.add_action(ACTION_TOGGLE)
		var ev := InputEventKey.new()
		ev.physical_keycode = KEY_C
		InputMap.action_add_event(ACTION_TOGGLE, ev)
	if not InputMap.has_action(ACTION_PHOTO):
		InputMap.add_action(ACTION_PHOTO)
		var ev2 := InputEventKey.new()
		ev2.physical_keycode = KEY_F3
		InputMap.action_add_event(ACTION_PHOTO, ev2)


func _setup() -> void:
	_manager = get_tree().get_first_node_in_group("match_manager") as MatchManager
	if _manager:
		_manager.turn_ended.connect(_on_reset)
		_manager.goal_scored.connect(_on_reset)
		_manager.match_started.connect(_on_reset)
		_manager.formation_started.connect(_on_reset)

	for p: Player in get_tree().get_nodes_in_group("players"):
		_watch(p)
	get_tree().node_added.connect(_on_node_added)   # jogadores criados depois (troca de formação)


func _on_node_added(node: Node) -> void:
	if node is Player:
		_watch.call_deferred(node)


func _watch(p: Player) -> void:
	if is_instance_valid(p) and not p.clicked.is_connected(_on_player_clicked):
		p.clicked.connect(_on_player_clicked)


func _on_reset(_arg = null) -> void:
	_focused = false


func _on_player_clicked(player: Player) -> void:
	# Espera o MatchManager tratar o clique primeiro: só foca se o jogador virou o que vai agir
	await get_tree().process_frame
	if _manager == null or not is_instance_valid(player):
		return
	if _manager.active_player == player and player.team == _manager.current_team:
		_focused = true


## F3 em _input (e não _unhandled_input): funciona mesmo com um botão da interface com foco
func _input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if event.is_action_pressed(ACTION_PHOTO) or event.keycode == KEY_F3 or event.physical_keycode == KEY_F3:
		_toggle_photo_mode()
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if _photo_mode:
		_photo_input(event)
		return
	if not event.is_action_pressed(ACTION_TOGGLE) or event.is_echo():
		return
	if _minigame_running():
		return   # QTE / jogo de digitar usam o teclado: não rouba a tecla
	if _focused:
		_focused = false
	elif _manager != null and _manager.active_player != null:
		_focused = true


## Tem um QTE ou o jogo de digitar rodando agora? (eles são filhos do MatchManager)
func _minigame_running() -> bool:
	if _manager == null:
		return false
	for child in _manager.get_children():
		if child is QTE or child is TypingGame:
			return true
	return false


func _process(delta: float) -> void:
	var target_pos: Vector2 = _home_position
	var target_zoom: Vector2 = _home_zoom

	if _photo_mode:
		# Modo foto: a câmera é livre (a jogada não puxa a câmera nem o foco)
		_photo_tick(delta)
		target_zoom = _home_zoom * _photo_zoom
		target_pos = _clamp_to_field(_home_position + _photo_pan, target_zoom, photo_field_margin)
	elif _focused:
		var actor: Player = _manager.active_player if _manager else null
		if actor == null or not is_instance_valid(actor) \
				or _manager.phase == MatchManager.Phase.MATCH_OVER:
			_focused = false
		else:
			var z: float = focus_zoom
			if _manager.phase == MatchManager.Phase.CHOOSING_PASS_TARGET:
				z = pass_target_zoom
			target_zoom = _home_zoom * z
			target_pos = actor.global_position + Vector2(0.0, -actor.height * 0.5)
			# Bola saindo em velocidade (chute, passe): acompanha ela
			if follow_ball_in_motion and _manager.phase == MatchManager.Phase.EXECUTING:
				var ball := get_tree().get_first_node_in_group("ball") as Ball
				if ball != null and not ball.is_held() and _ball_is_moving(ball):
					target_pos = ball.global_position + Vector2(0.0, -ball.height * 0.5)
			if clamp_to_field:
				target_pos = _clamp_to_field(target_pos, target_zoom)

	var t: float = 1.0 - exp(-smooth_speed * delta)   # suavização independente do FPS
	global_position = global_position.lerp(target_pos, t)
	zoom = zoom.lerp(target_zoom, t)


func _ball_is_moving(ball: Ball) -> bool:
	return ball.velocity.length() > ball_speed_threshold \
		or (not ball.hovering and ball.height > 1.0)


## Mantém a janela da câmera dentro do campo (+ margem). Se a janela é maior que o campo,
## centraliza no campo.
func _clamp_to_field(pos: Vector2, for_zoom: Vector2, margin: float = -1.0) -> Vector2:
	var field := get_tree().get_first_node_in_group("field") as Field
	if field == null:
		return pos
	var m: float = field_margin if margin < 0.0 else margin
	var half_view: Vector2 = get_viewport_rect().size / for_zoom * 0.5
	var half_field: Vector2 = field.pitch_size * 0.5 + Vector2(m, m)
	var center: Vector2 = field.global_position
	var limit := Vector2(maxf(half_field.x - half_view.x, 0.0), maxf(half_field.y - half_view.y, 0.0))
	return Vector2(
		center.x + clampf(pos.x - center.x, -limit.x, limit.x),
		center.y + clampf(pos.y - center.y, -limit.y, limit.y))


# ---------- MODO FOTO (F3) ----------

func _photo_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var lo: float = photo_zoom_range.x
		var hi: float = photo_zoom_range.y
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_photo_zoom = clampf(_photo_zoom * 1.1, lo, hi)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_photo_zoom = clampf(_photo_zoom / 1.1, lo, hi)
	elif event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_MIDDLE) != 0:
		_photo_pan -= event.relative / maxf(zoom.x, 0.01)   # arrastar move o campo junto com a mão
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
		_photo_zoom = 1.0
		_photo_pan = Vector2.ZERO


## Um CanvasLayer "grande" (formação, pausa...) está realmente aparecendo? Camada vazia não conta.
func _modal_open() -> bool:
	var layers: Array[CanvasLayer] = []
	_collect_layers(get_tree().root, layers)
	for layer in layers:
		if layer == _toast_layer or not layer.visible or layer.layer < photo_modal_layer:
			continue
		for child in layer.get_children():
			if child is CanvasItem and (child as CanvasItem).visible:
				return true
	return false


func _collect_layers(node: Node, out: Array[CanvasLayer]) -> void:
	for child in node.get_children():
		if child is CanvasLayer:
			out.append(child)
		_collect_layers(child, out)


## Esconde (e guarda para restaurar) todas as camadas e controles da interface que estão aparecendo.
## Roda de novo a cada instante no modo foto: o menu de ações se reexibe sozinho a cada mudança de fase.
func _hide_ui() -> void:
	var layers: Array[CanvasLayer] = []
	_collect_layers(get_tree().root, layers)
	for layer in layers:
		if layer != _toast_layer and layer.visible and layer.layer < photo_modal_layer:
			layer.visible = false
			if not _photo_hidden.has(layer):
				_photo_hidden.append(layer)
	var scene: Node = get_tree().current_scene
	if scene != null:
		for child in scene.get_children():
			if child is Control and (child as Control).visible:
				(child as Control).visible = false
				if not _photo_hidden.has(child):
					_photo_hidden.append(child)


func _toggle_photo_mode() -> void:
	if _photo_mode:
		_exit_photo_mode()
	elif _modal_open():
		_show_toast("F3: feche a tela aberta (formação/pausa) para usar o modo foto", 2.2)
	else:
		_enter_photo_mode()


func _enter_photo_mode() -> void:
	_photo_mode = true
	_focused = false
	_photo_zoom = 1.0
	_photo_pan = Vector2.ZERO
	_photo_hidden.clear()
	_hide_ui()
	_show_toast("MODO FOTO   ·   F3 volta   ·   roda: zoom   ·   botão do meio / setas: mover   ·   R: centralizar", 3.5)


func _exit_photo_mode() -> void:
	_photo_mode = false
	for item in _photo_hidden:
		if is_instance_valid(item):
			item.visible = true
	_photo_hidden.clear()
	if _toast_layer != null:
		_toast_layer.visible = false
	# A câmera volta sozinha ao enquadramento normal (o _process leva zoom e posição ao "home")


## A cada quadro no modo foto: setas movem, a interface continua escondida e telas grandes encerram o modo
func _photo_tick(delta: float) -> void:
	var dir := Vector2(
		Input.get_axis(&"ui_left", &"ui_right"), Input.get_axis(&"ui_up", &"ui_down"))
	if dir != Vector2.ZERO:
		_photo_pan += dir * photo_pan_speed * delta / maxf(zoom.x, 0.01)
	# O menu de ações faz "visible = true" sozinho: esconde de novo, todo quadro
	for item in _photo_hidden:
		if is_instance_valid(item) and item.visible:
			item.visible = false
	_photo_check -= delta
	if _photo_check <= 0.0:
		_photo_check = 0.25
		if _modal_open():
			_exit_photo_mode()   # abriu uma tela grande: sai do modo foto
		else:
			_hide_ui()           # pegou alguma interface nova que apareceu


## Aviso rápido no pé da tela (some sozinho)
func _show_toast(text: String, seconds: float) -> void:
	if _toast_layer == null:
		_toast_layer = CanvasLayer.new()
		_toast_layer.layer = 99
		add_child(_toast_layer)
		_toast_label = Label.new()
		_toast_label.add_theme_font_size_override("font_size", 18)
		_toast_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
		_toast_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
		_toast_label.add_theme_constant_override("outline_size", 6)
		_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_toast_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
		_toast_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
		_toast_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
		_toast_label.offset_bottom = -24.0
		_toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_toast_layer.add_child(_toast_label)
	_toast_label.text = text
	_toast_layer.visible = true
	_toast_label.modulate.a = 1.0
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(seconds)
	_toast_tween.tween_property(_toast_label, "modulate:a", 0.0, 1.0)
