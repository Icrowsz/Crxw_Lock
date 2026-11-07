class_name PauseMenu
extends CanvasLayer
## MENU DE PAUSA (tecla ESC durante a partida). Criado pelo MatchManager.
##
##   Continuar            -> fecha o menu (ESC de novo também fecha)
##   Pular turno          -> pula o turno do time da vez, SEJA O QUE FOR que esteja acontecendo
##                           (veja MatchManager.force_skip_turn)
##   Ver posições bônus   -> liga/desliga os contornos das zonas dos bônus de posição no campo (Field.show_bonus_zones)
##   Voltar para o Menu   -> volta ao menu inicial (pede confirmação: a partida é perdida)
##
## Enquanto o menu está aberto o jogo fica pausado (get_tree().paused). O ESC NÃO abre o menu quando ele já
## serve para cancelar outra coisa (mira, escolha de passe, escolha de alvo/ponto de habilidade) nem durante a
## montagem das formações e o fim de jogo.

var manager: MatchManager

var _root: Control
var _open: bool = false
var _zones_button: Button
var _menu_button: Button
var _menu_confirm: bool = false


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS   # continua recebendo ESC com o jogo pausado


func is_open() -> bool:
	return _open


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if _open:
		close()
		get_viewport().set_input_as_handled()
	elif _can_open():
		open()
		get_viewport().set_input_as_handled()


## O ESC já tem outro uso agora? Então não abre o menu (o ESC seguinte abre).
func _can_open() -> bool:
	if manager == null or manager.match_over or manager.paused:
		return false
	var blocked: Array = [MatchManager.Phase.FORMATION, MatchManager.Phase.MATCH_OVER,
		MatchManager.Phase.CHOOSING_PASS_VARIANT, MatchManager.Phase.CHOOSING_PASS_TARGET]
	if manager.phase in blocked:
		return false
	if manager._picking_skill_target or manager._picking_skill_point:
		return false
	if manager.active_player != null and manager.active_player.is_aiming:
		return false
	return true


func open() -> void:
	if _open:
		return
	_open = true
	_menu_confirm = false
	_build()
	get_tree().paused = true


func close() -> void:
	if not _open:
		return
	_open = false
	get_tree().paused = false
	if _root != null and is_instance_valid(_root):
		_root.queue_free()
	_root = null


func _build() -> void:
	if _root != null and is_instance_valid(_root):
		_root.queue_free()
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP   # o jogo está parado: segura os cliques
	add_child(_root)

	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center)

	var panel := PanelContainer.new()
	UiStyle.style_panel(panel, Color(UiStyle.ACCENT_COLOR, 0.7))
	panel.custom_minimum_size = Vector2(420.0, 0.0)
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)

	var title: Label = UiStyle.make_label("PAUSA", 44, UiStyle.ACCENT_COLOR)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var resume: Button = _make_button("Continuar", UiStyle.ACCENT_COLOR)
	resume.pressed.connect(close)
	box.add_child(resume)

	var skip: Button = _make_button("Pular turno", TeamStyle.color_of(manager.current_team))
	skip.disabled = not manager.can_force_skip()
	skip.pressed.connect(_on_skip_pressed)
	box.add_child(skip)

	_zones_button = _make_button("", UiStyle.MUTED_COLOR)
	_zones_button.pressed.connect(_on_zones_pressed)
	box.add_child(_zones_button)
	_refresh_zones_button()

	_menu_button = _make_button("Voltar para o Menu", UiStyle.BAD_COLOR)
	_menu_button.pressed.connect(_on_menu_pressed)
	box.add_child(_menu_button)

	var hint: Label = UiStyle.make_label("ESC fecha este menu", 15, UiStyle.MUTED_COLOR)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint)

	UiStyle.pop(panel, 1.08, 0.2)


func _make_button(text: String, color: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0.0, 52.0)
	UiStyle.style_button(b, color)
	return b


func _on_skip_pressed() -> void:
	close()   # despausa primeiro: o pulo precisa que o jogo ande
	manager.force_skip_turn()


func _get_field() -> Field:
	return get_tree().get_first_node_in_group("field") as Field


func _on_zones_pressed() -> void:
	var f: Field = _get_field()
	if f != null:
		f.toggle_bonus_zones()
	_refresh_zones_button()


func _refresh_zones_button() -> void:
	var f: Field = _get_field()
	var on: bool = f != null and f.show_bonus_zones
	_zones_button.text = "Ver posições bônus: %s" % ("LIGADO" if on else "DESLIGADO")
	_zones_button.disabled = f == null


func _on_menu_pressed() -> void:
	# Duas etapas: a partida em andamento se perde
	if not _menu_confirm:
		_menu_confirm = true
		_menu_button.text = "Confirmar? A partida será perdida"
		return
	var path: String = GameMode.menu_scene
	if path == "":
		path = str(ProjectSettings.get_setting("application/run/main_scene", ""))
	if path == "" or not ResourceLoader.exists(path):
		_menu_confirm = false
		_menu_button.text = "Menu não encontrado (abra a partida pelo menu inicial)"
		return
	get_tree().paused = false
	get_tree().change_scene_to_file(path)
