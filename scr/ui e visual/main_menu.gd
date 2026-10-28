class_name MainMenu
extends Control
## MENU INICIAL do Crxw Lock: o nome do jogo e os botões JOGAR, MODO TREINO e SAIR.
##
## COMO USAR
##   1. Crie uma cena nova com a raiz do tipo Control (nome: MainMenu) e anexe este script. Salve (ex: res://cena/main_menu.tscn).
##   2. Em Projeto > Configurações do Projeto > Aplicação > Run > Main Scene, escolha esta cena de menu.
##   3. (Opcional) Em "Game Scene" aponte a cena do jogo, se ela não for a main.tscn de sempre.
##
## JOGAR        -> abre a cena do jogo com a tela de formação, como sempre.
## MODO TREINO  -> abre a mesma cena em modo de teste (sem formação, sem fim de jogo, com o painel de debug).
## Quem decide isso na partida é o GameMode (game_mode.gd), que o MatchManager consulta no _setup().
##
## O fundo é feito só por código: rostinhos dos personagens (res://img/rostinhos/) flutuando bem de leve.

## Cena do jogo (padrão: a main.tscn do projeto, pelo uid). Aceita caminho res://... ou uid://...
@export_file("*.tscn") var game_scene: String = "uid://vyuwdkpu5dcw"
@export var game_title_left: String = "CRXW"
@export var game_title_right: String = "LOCK"
@export var subtitle: String = "Futebol de habilidades, turno a turno"
@export var floating_faces: int = 14
@export var signature: String = "Icrowsz"
@export var signature_size: int = 28
@export var fade_time: float = 0.35

var _buttons: Array[Button] = []
var _fade: ColorRect
var _error: Label
var _leaving: bool = false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	GameMode.menu_scene = scene_file_path
	GameMode.reset()
	_build()


func _build() -> void:
	# Fundo escuro com um degradê suave
	var bg := ColorRect.new()
	bg.color = Color(0.035, 0.05, 0.075)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var glow := _Glow.new()
	glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(glow)

	_spawn_faces()

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(column)

	# O nome do jogo
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 26)
	title_row.alignment = BoxContainer.ALIGNMENT_CENTER
	title_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(title_row)
	var left: Label = UiStyle.make_label(game_title_left, 170, Color.WHITE)
	var right: Label = UiStyle.make_label(game_title_right, 170, UiStyle.ACCENT_COLOR)
	title_row.add_child(left)
	title_row.add_child(right)

	var sub: Label = UiStyle.make_label(subtitle, 26, UiStyle.MUTED_COLOR)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(sub)
	column.add_child(_spacer(46.0))

	# Os botões
	var play := _menu_button("JOGAR", "Partida normal: monte os times na tela de formação")
	play.pressed.connect(_go.bind(false))
	var train := _menu_button("MODO TREINO", "Partida de teste: sem formação, sem fim de jogo e com menu de debug")
	train.pressed.connect(_go.bind(true))
	var quit := _menu_button("SAIR", "")
	quit.pressed.connect(_quit)
	for b in [play, train, quit]:
		var holder := CenterContainer.new()
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(b)
		column.add_child(holder)
		_buttons.append(b)

	_error = UiStyle.make_label("", 20, UiStyle.BAD_COLOR)
	_error.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_error)

	# Assinatura no canto inferior direito
	if signature != "":
		var sig: Label = UiStyle.make_label(signature, signature_size, Color(UiStyle.MUTED_COLOR, 0.8))
		sig.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		sig.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		sig.grow_vertical = Control.GROW_DIRECTION_BEGIN
		sig.offset_right = -28.0
		sig.offset_bottom = -18.0
		sig.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(sig)

	# Fade (entra clareando, sai escurecendo)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 1)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)

	play.grab_focus()
	_intro.call_deferred(left, right)


func _spacer(h: float) -> Control:
	var s := Control.new()
	s.custom_minimum_size = Vector2(0.0, h)
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return s


func _menu_button(text: String, tip: String) -> Button:
	var b := Button.new()
	b.text = text
	b.tooltip_text = tip
	b.custom_minimum_size = Vector2(560.0, 96.0)
	UiStyle.style_card_button(b, 46)
	return b


## Entrada: o preto some, o título "estoura" e os botões balançam em sequência
func _intro(left: Label, right: Label) -> void:
	await get_tree().process_frame
	create_tween().tween_property(_fade, "color:a", 0.0, 0.5)
	for l in [left, right]:
		l.pivot_offset = l.size * 0.5
	UiStyle.pop(left, 1.5, 0.55)
	await get_tree().create_timer(0.12).timeout
	UiStyle.pop(right, 1.5, 0.55)
	UiStyle.alive(left, 0.0, 0.6, 4.2)
	UiStyle.alive(right, 0.5, 0.6, 4.2)
	UiStyle.jelly_chain(_buttons, 1.1, 0.08)


# ---------- FUNDO: ROSTINHOS FLUTUANDO ----------

func _spawn_faces() -> void:
	var ids: Array[String] = []
	for c in CharacterRoster.CHARACTERS:
		ids.append(String(c["id"]))
	ids.shuffle()
	var size_px: Vector2 = get_viewport_rect().size
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var made: int = 0
	for id in ids:
		if made >= floating_faces:
			break
		var tex: Texture2D = CharacterRoster.face_for(id)
		if tex == null:
			continue
		made += 1
		var s: float = rng.randf_range(90.0, 190.0)
		var holder := Control.new()
		holder.custom_minimum_size = Vector2(s, s)
		holder.size = Vector2(s, s)
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.modulate = Color(1, 1, 1, rng.randf_range(0.10, 0.22))
		holder.position = Vector2(rng.randf_range(0.0, size_px.x - s), rng.randf_range(0.0, size_px.y - s))
		holder.pivot_offset = Vector2(s, s) * 0.5
		holder.rotation = rng.randf_range(-0.35, 0.35)
		add_child(holder)
		var face := _RoundFace.new()
		face.tex = tex
		face.set_anchors_preset(Control.PRESET_FULL_RECT)
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(face)
		# Sobe e desce devagar, cada um no seu ritmo
		var dist: float = rng.randf_range(18.0, 46.0)
		var period: float = rng.randf_range(4.0, 8.0)
		var tw := holder.create_tween().set_loops()
		tw.tween_property(holder, "position:y", holder.position.y - dist, period).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(holder, "position:y", holder.position.y + dist, period).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


# ---------- AÇÕES ----------

func _go(training: bool) -> void:
	if _leaving:
		return
	if not ResourceLoader.exists(game_scene):
		_error.text = "Cena do jogo não encontrada: %s (ajuste 'Game Scene' no MainMenu)" % game_scene
		return
	_leaving = true
	_error.text = ""
	GameMode.menu_scene = scene_file_path
	GameMode.start(training)
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, fade_time)
	await tw.finished
	get_tree().change_scene_to_file(game_scene)


func _quit() -> void:
	if _leaving:
		return
	_leaving = true
	get_tree().quit()


# ---------- DESENHO ----------

## Brilho suave no meio da tela
class _Glow extends Control:
	func _draw() -> void:
		var c: Vector2 = size * 0.5
		for i in 7:
			var k: float = float(i) / 6.0
			draw_circle(c + Vector2(0.0, -40.0), lerpf(size.y * 0.75, size.y * 0.18, k), Color(0.25, 0.4, 0.75, 0.035))


## Rosto recortado em círculo
class _RoundFace extends Control:
	var tex: Texture2D

	func _draw() -> void:
		if tex == null:
			return
		var c: Vector2 = size * 0.5
		var r: float = minf(size.x, size.y) * 0.5
		var aspect: float = float(tex.get_width()) / maxf(float(tex.get_height()), 1.0)
		var su: float = 1.0 / aspect if aspect >= 1.0 else 1.0
		var sv: float = 1.0 if aspect >= 1.0 else aspect
		var cv: float = 0.5 - maxf(0.0, 1.0 - aspect) * 0.25
		var pts := PackedVector2Array()
		var uvs := PackedVector2Array()
		for i in 40:
			var a: float = TAU * float(i) / 40.0
			pts.append(c + Vector2(cos(a), sin(a)) * r)
			uvs.append(Vector2(0.5 + 0.5 * cos(a) * su, cv + 0.5 * sin(a) * sv))
		draw_colored_polygon(pts, Color.WHITE, uvs, tex)
		draw_arc(c, r, 0.0, TAU, 48, Color(1, 1, 1, 0.9), 4.0)
