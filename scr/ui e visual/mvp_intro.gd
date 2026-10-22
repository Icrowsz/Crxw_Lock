class_name MvpIntro
extends CanvasLayer
## Abertura do MVP: antes da tela final (MVP + estatísticas) a tela ESCURECE até ficar toda preta, o
## TÍTULO do personagem aparece no centro e, logo abaixo, a FRASE dele é DIGITADA letra por letra.
## Depois de um tempinho parada, o MatchManager abre a tela do MVP e chama fade_out(): o preto some
## revelando a tela já aberta.
##
## Quem usa: MatchManager._end_match(). Título e frase vêm do personagem (Player.mvp_title /
## Player.mvp_phrase, ou get_mvp_title() / get_mvp_phrase() sobrescritos no script dele).
## Um clique ou tecla completa a frase na hora; outro clique encerra a espera.
##
## O ROSTINHO do personagem (res://img/rostinhos/, o mesmo do CharacterRoster.face_for) aparece
## centralizado ACIMA do título, sem moldura: só a imagem, com um CONTORNO na cor do título que segue
## a forma dela (o recorte do desenho; imagem sem transparência ganha contorno quadrado). Passe a imagem no 4º
## parâmetro do play(): play(titulo, frase, cor, CharacterRoster.face_for(id_do_mvp)).
## Para goleiro use KeeperRoster.face_for(id). Sem imagem, a abertura fica como antes (só título e frase).
##
## Para pôr som na digitação, ligue-se ao sinal char_typed.

## Uma letra acabou de aparecer (para efeito sonoro)
signal char_typed(character: String)

@export_group("Tempos")
@export var fade_in_time: float = 0.9        # a tela escurecendo
@export var title_time: float = 0.6          # o título aparecendo
@export var title_pause: float = 0.35        # pausa entre o título e a frase
@export var char_delay: float = 0.055        # tempo entre uma letra e outra
@export var punctuation_delay: float = 0.30  # pausa extra depois de . , ! ? …
@export var hold_time: float = 2.2           # frase completa parada, antes de abrir a tela do MVP

@export_group("Texto")
@export var title_size: int = 34
@export var phrase_size: int = 52
@export var max_text_width: float = 1100.0
@export var face_size: float = 180.0         # tamanho do rostinho (px; o lado maior da imagem)
@export var face_outline_width: float = 5.0  # espessura do contorno na forma da imagem (px)

var _bg: ColorRect
var _content: Control
var _title: Label
var _face: _FaceShape
var _phrase: Label
var _skip: bool = false
var _accept_input: bool = false


## Mostra a abertura e só volta quando a frase foi digitada e ficou parada. A tela continua PRETA
## depois disto: chame fade_out() quando a tela do MVP já estiver aberta por baixo.
func play(title: String, phrase: String, title_color: Color = Color.WHITE, face: Texture2D = null) -> void:
	layer = 200   # acima de tudo (menus, placar, QTE, efeitos)
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build(title, phrase, title_color, face)

	# 1) Escurece até ficar tudo preto
	var fade := create_tween()
	fade.tween_property(_bg, "color:a", 1.0, fade_in_time)
	await fade.finished

	# 2) O rostinho e o título aparecem juntos
	if title != "" or _face != null:
		var show := create_tween().set_parallel(true)
		if _face != null:
			show.tween_property(_face, "modulate:a", 1.0, title_time)
		if title != "":
			show.tween_property(_title, "modulate:a", 1.0, title_time)
		await show.finished
	_accept_input = true
	await _wait(title_pause)

	# 3) A frase é digitada, letra por letra
	await _type_phrase()

	# 4) Fica parada um instante (clique pula)
	var waited: float = 0.0
	var last: int = Time.get_ticks_msec()
	while waited < hold_time and not _skip:
		await get_tree().process_frame
		var now: int = Time.get_ticks_msec()
		waited += float(now - last) / 1000.0
		last = now


## Some devagar revelando o que está por baixo (a tela do MVP) e se apaga
func fade_out(time: float = 0.7) -> void:
	_accept_input = false
	if _bg == null:
		queue_free()
		return
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_bg, "color:a", 0.0, time)
	tw.tween_property(_content, "modulate:a", 0.0, time * 0.6)
	await tw.finished
	queue_free()


func _build(title: String, phrase: String, title_color: Color, face: Texture2D = null) -> void:
	_bg = ColorRect.new()
	_bg.color = Color(0.0, 0.0, 0.0, 0.0)
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.mouse_filter = Control.MOUSE_FILTER_STOP   # nada embaixo recebe clique
	add_child(_bg)

	_content = Control.new()
	_content.set_anchors_preset(Control.PRESET_FULL_RECT)
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_content)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(center)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 22)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(box)

	var width: float = minf(max_text_width, get_viewport().get_visible_rect().size.x * 0.8)

	# O rostinho fica ACIMA do título, centralizado (só a imagem + contorno na forma dela)
	if face != null:
		_face = _FaceShape.new()
		_face.setup(face, face_size, face_outline_width, title_color)
		_face.size_flags_horizontal = Control.SIZE_SHRINK_CENTER   # centraliza na coluna
		_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_face.modulate.a = 0.0
		box.add_child(_face)

	# O título fica ACIMA da frase
	_title = UiStyle.make_label(title, title_size, title_color)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title.custom_minimum_size = Vector2(width, 0.0)
	_title.modulate.a = 0.0
	_title.visible = title != ""
	box.add_child(_title)

	# A frase inteira já ocupa o espaço dela (invisível); as letras vão aparecendo, então o texto
	# não "pula" de linha enquanto é digitado
	_phrase = UiStyle.make_label(phrase, phrase_size)
	_phrase.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_phrase.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_phrase.custom_minimum_size = Vector2(width, 0.0)
	_phrase.visible_characters = 0
	box.add_child(_phrase)


func _type_phrase() -> void:
	var text: String = _phrase.text
	for i in text.length():
		if _skip:
			_skip = false   # o clique foi usado para completar; o próximo encerra a espera
			break
		_phrase.visible_characters = i + 1
		var c: String = text[i]
		char_typed.emit(c)
		var delay: float = char_delay
		if c in [".", ",", "!", "?", "…", ";", ":"]:
			delay += punctuation_delay
		await _wait(delay)
	_phrase.visible_characters = -1   # tudo visível


## Espera em tempo real (não é afetada pela câmera lenta do hit_stop)
func _wait(seconds: float) -> void:
	if seconds <= 0.0:
		return
	await get_tree().create_timer(seconds, true, false, true).timeout


func _input(event: InputEvent) -> void:
	if not _accept_input:
		return
	var pressed: bool = (event is InputEventMouseButton and event.pressed) \
		or (event is InputEventKey and event.pressed and not event.echo)
	if pressed:
		_skip = true
		get_viewport().set_input_as_handled()


## Rostinho sem moldura: a imagem inteira (mesma proporção) com um contorno que segue a forma dela.
## O contorno é feito num shader: olha em volta de cada pixel e pinta de cor onde a imagem não tem nada
## mas tem imagem por perto. A área desenhada é um pouco maior que a imagem (margem do contorno).
class _FaceShape extends Control:
	const SHADER: String = """
shader_type canvas_item;

uniform vec4 outline_color : source_color = vec4(1.0);
uniform vec2 outline_uv = vec2(0.02, 0.02);   // espessura do contorno em unidades de UV

// Fora da imagem conta como transparente (assim o contorno também aparece em volta de imagens sem recorte)
float alpha_at(vec2 uv) {
	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
		return 0.0;
	}
	return texture(TEXTURE, uv).a;
}

void fragment() {
	float own = alpha_at(UV);
	vec4 c = vec4(0.0);
	if (own > 0.0) {
		c = texture(TEXTURE, UV);
	}
	float near = 0.0;
	for (int i = 0; i < 16; i++) {
		float ang = 6.2831853 * float(i) / 16.0;
		vec2 dir = vec2(cos(ang), sin(ang));
		near = max(near, alpha_at(UV + dir * outline_uv));
		near = max(near, alpha_at(UV + dir * outline_uv * 0.5));
	}
	vec4 o = vec4(outline_color.rgb, outline_color.a * near);
	COLOR = mix(o, c, c.a);   // a imagem fica por cima do contorno
}
"""

	var tex: Texture2D
	var _img_rect: Rect2          # onde a imagem é desenhada (dentro da margem do contorno)
	var _pad: float = 6.0

	func setup(texture: Texture2D, max_side: float, outline: float, color: Color) -> void:
		tex = texture
		_pad = outline + 3.0
		var w: float = maxf(float(tex.get_width()), 1.0)
		var h: float = maxf(float(tex.get_height()), 1.0)
		var scale: float = max_side / maxf(w, h)
		var img_size := Vector2(w, h) * scale
		_img_rect = Rect2(Vector2(_pad, _pad), img_size)
		custom_minimum_size = img_size + Vector2(_pad, _pad) * 2.0
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var shader := Shader.new()
		shader.code = SHADER
		var mat := ShaderMaterial.new()
		mat.shader = shader
		mat.set_shader_parameter("outline_color", color)
		mat.set_shader_parameter("outline_uv", Vector2(outline / img_size.x, outline / img_size.y))
		material = mat

	func _draw() -> void:
		if tex == null:
			return
		# O quadrado desenhado é a imagem + a margem; os UVs passam de 0..1 na margem (o shader trata isso)
		var quad: Rect2 = _img_rect.grow(_pad)
		var pts := PackedVector2Array([quad.position, Vector2(quad.end.x, quad.position.y),
			quad.end, Vector2(quad.position.x, quad.end.y)])
		var uvs := PackedVector2Array()
		for p in pts:
			uvs.append((p - _img_rect.position) / _img_rect.size)
		draw_colored_polygon(pts, Color.WHITE, uvs, tex)
