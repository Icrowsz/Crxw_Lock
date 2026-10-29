class_name ReactionCutscene
extends CanvasLayer
## Cutscene de uma Reação Química: CONGELA a partida (get_tree().paused) e mostra, sobre a tela
## escurecida:
##   - no CENTRO: o vídeo da reação (reaction.video_path), se existir, esticado na tela (tamanho em
##     reaction.video_size_ratio) e com o fundo verde removido por chroma key;
##   - EMBAIXO: o rosto de quem está falando e, abaixo dele, a fala centralizada, sem caixa,
##     com contorno na cor do personagem.
## O movimento da reação só acontece quando o DIÁLOGO termina (o vídeo não segura nada: se acabar
## antes, some; se o diálogo acabar antes, o vídeo é cortado).
##
## Controles: clique esquerdo / Enter / Espaço passam a fala (o 1º clique completa o texto);
## Esc pula a cutscene inteira. Sem clicar, a fala passa sozinha depois de um tempinho.
##
## FALANTES DE FORA: a fala pode ser de alguém que não está na reação (narrador, outro personagem):
## _say("narrador", "...") na reação. O rosto vem de reaction.speakers (veja _add_speaker) ou, sem cadastro,
## de <faces_dir>/<id>.png. Sem imagem, aparece um círculo com a inicial. Fala com who vazio fica sem rosto.
##
## Rosto de cada personagem: <reaction.faces_dir>/<character_id>.png (ou .webp/.jpg/.jpeg;
## também tenta o nome com a inicial maiúscula e o display_name). Sem imagem, usa a imagem de
## MVP do personagem e, por último, um círculo colorido com a inicial.

signal finished

const TYPE_SPEED: float = 40.0         # caracteres por segundo
const HOLD_AFTER_LINE: float = 1.8     # espera depois da fala completa antes de passar sozinha
const DIM_ALPHA: float = 0.75

## Chroma key: o pixel fica transparente quanto mais perto da cor-chave ele estiver (a comparação é
## feita só pela cor, em CbCr, então sombras/brilhos do fundo verde também somem)
const CHROMA_SHADER: String = """
shader_type canvas_item;

uniform vec4 key_color : source_color = vec4(0.0, 1.0, 0.0, 1.0);
uniform float similarity = 0.20;
uniform float smoothness = 0.08;
uniform float spill = 0.5;

vec2 cbcr(vec3 c) {
	return vec2(
		0.5 - 0.168736 * c.r - 0.331264 * c.g + 0.5 * c.b,
		0.5 + 0.5 * c.r - 0.418688 * c.g - 0.081312 * c.b);
}

void fragment() {
	vec3 rgb = texture(TEXTURE, UV).rgb;
	float d = distance(cbcr(rgb), cbcr(key_color.rgb));
	float keyed = smoothstep(similarity, similarity + smoothness, d);
	// remove o reflexo verde que sobra nas bordas
	float limit = max(COLOR.r, COLOR.b);
	COLOR.g = mix(COLOR.g, min(COLOR.g, limit), spill);
	COLOR.a *= keyed;
}
"""

var reaction: ChemicalReaction
var _left: Player    # o parceiro (ex: Sae)
var _right: Player   # quem executa o movimento (ex: Shidou)
var _vs: Vector2
var _accent: Color

var _root: Control
var _dim: ColorRect
var _burst: _Burst
var _video: VideoStreamPlayer = null
var _face_holder: Control = null
var _text_label: Label
var _flash: ColorRect

var _advance: bool = false
var _skipped: bool = false
var _released: bool = false
var _was_paused: bool = false


## left = parceiro, right = quem executa. Só volta quando a cutscene acabou (use await).
func play(r: ChemicalReaction, left: Player, right: Player) -> void:
	reaction = r
	_left = left
	_right = right
	_accent = r.accent
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS   # este nó continua rodando com o jogo congelado
	_vs = get_viewport().get_visible_rect().size

	_was_paused = get_tree().paused
	get_tree().paused = true
	_build()
	await _intro()
	await _dialogue()
	await _outro()

	# O jogo volta na hora (o movimento da reação acontece agora) e o clarão some por cima dele
	_released = true
	get_tree().paused = _was_paused
	var fade: Tween = create_tween()
	fade.tween_property(_flash, "color:a", 0.0, 0.35)
	fade.finished.connect(queue_free)
	finished.emit()


# Garantia: se a cutscene for removida no meio, o jogo não fica congelado
func _exit_tree() -> void:
	if not _released and get_tree() != null:
		get_tree().paused = _was_paused


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_advance = true
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept"):
		_advance = true
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		_skipped = true
		get_viewport().set_input_as_handled()


# ---------- MONTAGEM ----------

func _build() -> void:
	_root = Control.new()
	add_child(_root)
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP   # nada embaixo recebe clique

	_dim = ColorRect.new()
	_dim.color = Color(0.0, 0.0, 0.0, 0.0)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_dim)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_burst = _Burst.new()
	_burst.color = _accent
	_burst.modulate.a = 0.0
	_root.add_child(_burst)
	_burst.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_setup_video()

	# Fala: centralizada embaixo, sem caixa (o contorno colorido é feito por cada fala)
	_text_label = Label.new()
	_text_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_text_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_root.add_child(_text_label)
	_text_label.position = Vector2(_vs.x * 0.15, _vs.y * 0.82)
	_text_label.size = Vector2(_vs.x * 0.7, _vs.y * 0.15)
	_text_label.visible_ratio = 0.0

	# Clarão branco (começa cheio: a cutscene "estoura" na tela)
	_flash = ColorRect.new()
	_flash.color = Color(1.0, 1.0, 1.0, 1.0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_flash)
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


## Vídeo no centro da tela (sem arquivo ou formato não suportado: a cutscene segue sem ele)
func _setup_video() -> void:
	if reaction.video_path == "" or not ResourceLoader.exists(reaction.video_path):
		return
	var stream := load(reaction.video_path) as VideoStream
	if stream == null:
		push_warning("ReactionCutscene: não consegui carregar o vídeo %s (use .ogv)" % reaction.video_path)
		return
	_video = VideoStreamPlayer.new()
	_video.stream = stream
	_video.expand = true
	_video.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_video.modulate.a = 0.0
	_root.add_child(_video)
	# Esticado para a fração da tela pedida (1.0 = tela inteira), centralizado
	var vsize: Vector2 = _vs * reaction.video_size_ratio
	_video.size = vsize
	_video.position = (_vs - vsize) * 0.5
	if reaction.video_chroma_key:
		var shader := Shader.new()
		shader.code = CHROMA_SHADER
		var mat := ShaderMaterial.new()
		mat.shader = shader
		mat.set_shader_parameter("key_color", reaction.chroma_color)
		mat.set_shader_parameter("similarity", reaction.chroma_similarity)
		mat.set_shader_parameter("smoothness", reaction.chroma_smoothness)
		mat.set_shader_parameter("spill", reaction.chroma_spill)
		_video.material = mat
	_video.finished.connect(_on_video_finished)


func _on_video_finished() -> void:
	if _video == null or not is_instance_valid(_video):
		return
	if reaction.video_loop:
		_video.play()
	else:
		create_tween().tween_property(_video, "modulate:a", 0.0, 0.3)   # acabou antes do diálogo: some


## Procura o rosto em <faces_dir>/<nome>.<ext> para cada nome da lista (devolve null se não achar)
func _find_face(names: Array) -> Texture2D:
	for n in names:
		for ext in ["png", "webp", "jpg", "jpeg"]:
			var path: String = "%s/%s.%s" % [reaction.faces_dir, n, ext]
			if ResourceLoader.exists(path):
				return load(path) as Texture2D
	return null


## O Player da reação (esquerda ou direita) com este character_id, ou null
func _player_of(character_id: String) -> Player:
	if _left != null and _left.character_id == character_id:
		return _left
	if _right != null and _right.character_id == character_id:
		return _right
	return null


## Rosto de quem fala, em cima da fala (com moldura na cor do personagem). Troca a cada fala.
## "sp" é o que _speaker() devolve (nome, cor, imagem...).
func _show_face(sp: Dictionary) -> void:
	var color: Color = sp["color"]
	if _face_holder != null:
		_face_holder.queue_free()
		_face_holder = null
	if not bool(sp.get("has_face", true)):
		return
	var fs: float = _vs.y * 0.17
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(holder)
	holder.size = Vector2(fs, fs)
	holder.position = Vector2((_vs.x - fs) * 0.5, _vs.y * 0.645)
	holder.pivot_offset = holder.size * 0.5

	var frame := Panel.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(color.darkened(0.8), 0.9)
	sb.border_color = color
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(14)
	frame.add_theme_stylebox_override("panel", sb)
	holder.add_child(frame)
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var tex: Texture2D = sp.get("texture") as Texture2D
	if tex != null:
		var pic := TextureRect.new()
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pic.texture = tex
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		holder.add_child(pic)
		pic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		pic.offset_left = 6.0
		pic.offset_top = 6.0
		pic.offset_right = -6.0
		pic.offset_bottom = -6.0
	else:
		# Sem imagem: a inicial do nome
		var initial := Label.new()
		initial.text = String(sp["name"]).substr(0, 1).to_upper()
		initial.mouse_filter = Control.MOUSE_FILTER_IGNORE
		initial.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		initial.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		var ls := LabelSettings.new()
		ls.font_size = int(fs * 0.55)
		ls.font_color = color.lightened(0.3)
		initial.label_settings = ls
		holder.add_child(initial)
		initial.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Um "pop" a cada troca de quem fala
	holder.scale = Vector2(0.75, 0.75)
	create_tween().tween_property(holder, "scale", Vector2.ONE, 0.2) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_face_holder = holder
	# Mantém o clarão por cima de tudo
	_root.move_child(_flash, _root.get_child_count() - 1)


func _style_text(color: Color) -> void:
	var ls := LabelSettings.new()
	ls.font_size = int(_vs.y * 0.045)
	ls.font_color = Color.WHITE
	ls.outline_size = 12
	ls.outline_color = color   # contorno na cor do personagem que está falando
	_text_label.label_settings = ls


# ---------- ETAPAS ----------

func _intro() -> void:
	var tw: Tween = create_tween().set_parallel(true)
	tw.tween_property(_flash, "color:a", 0.0, 0.3)
	tw.tween_property(_dim, "color:a", DIM_ALPHA, 0.3)
	tw.tween_property(_burst, "modulate:a", 1.0, 0.5)
	await tw.finished


func _dialogue() -> void:
	# O vídeo começa junto com a primeira fala
	if _video != null:
		_video.play()
		create_tween().tween_property(_video, "modulate:a", 1.0, 0.25)
	for line in reaction.lines:
		if _skipped:
			break
		await _show_line(_speaker(String(line.get("who", ""))), String(line.get("text", "")))
	_text_label.visible = false
	if _face_holder != null:
		_face_holder.visible = false


## Quem fala nesta fala: um dos dois personagens da reação OU um falante de fora (narrador etc.).
## Devolve {"name", "color", "texture" (ou null), "has_face"}. has_face é false só quando "who" é vazio.
func _speaker(who: String) -> Dictionary:
	var info: Dictionary = {"name": who.capitalize(), "color": _accent, "texture": null, "has_face": who != ""}
	if who == "":
		return info

	var p: Player = _player_of(who)
	if p != null:
		info["name"] = p.get_display_name()
		if reaction.colors.has(p.character_id):
			info["color"] = reaction.colors[p.character_id]
		var tex: Texture2D = _find_face([p.character_id, p.character_id.capitalize(), p.get_display_name()])
		info["texture"] = tex if tex != null else p.get_mvp_image()
		return info

	# Falante de fora (cadastrado com _add_speaker ou só com <faces_dir>/<id>.png)
	var guest: Dictionary = reaction.speakers.get(who, {})
	if guest.has("name"):
		info["name"] = String(guest["name"])
	if reaction.colors.has(who):
		info["color"] = reaction.colors[who]
	if guest.has("color"):
		info["color"] = guest["color"]
	var face: Variant = guest.get("face", null)
	var face_tex: Texture2D = null
	if face is Texture2D:
		face_tex = face
	elif face != null and String(face) != "" and ResourceLoader.exists(String(face)):
		face_tex = load(String(face)) as Texture2D
	if face_tex == null:
		face_tex = _find_face([who, who.capitalize(), String(info["name"])])
	info["texture"] = face_tex
	return info


func _show_line(sp: Dictionary, text: String) -> void:
	var color: Color = sp["color"]
	_show_face(sp)
	_style_text(color)
	_text_label.text = text
	_text_label.visible_ratio = 0.0

	_advance = false
	var type_time: float = maxf(0.2, float(text.length()) / TYPE_SPEED)
	var tw: Tween = create_tween()
	tw.tween_property(_text_label, "visible_ratio", 1.0, type_time)

	var hold: float = 0.0
	while not _skipped:
		await get_tree().process_frame
		var dt: float = get_process_delta_time()
		if tw.is_valid() and tw.is_running():
			if _advance:   # 1º clique: completa o texto
				tw.kill()
				_text_label.visible_ratio = 1.0
		else:
			hold += dt
			if _advance or hold >= HOLD_AFTER_LINE:
				break
		_advance = false


func _outro() -> void:
	# O diálogo acabou: para o vídeo (se ainda rodando) e faz o clarão branco que cobre tudo;
	# quando ele fecha, o jogo volta por baixo e a reação acontece
	if _video != null and is_instance_valid(_video):
		_video.stop()
	var tw: Tween = create_tween()
	tw.tween_property(_flash, "color:a", 1.0, 0.18)
	await tw.finished
	_dim.visible = false
	_burst.visible = false
	if _video != null and is_instance_valid(_video):
		_video.visible = false


# ====================================================================
# Raios de velocidade girando no fundo
# ====================================================================

class _Burst extends Control:
	var color: Color = Color(1.0, 0.1, 0.6)
	var _t: float = 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var c: Vector2 = size * 0.5
		var reach: float = size.length()
		var rays: int = 26
		for i in rays:
			var a: float = TAU * float(i) / float(rays) + _t * 0.12
			var wobble: float = 0.5 + 0.5 * sin(_t * 3.0 + float(i) * 1.7)
			var d := Vector2(cos(a), sin(a))
			draw_line(c + d * reach * (0.10 + 0.05 * wobble), c + d * reach * (0.55 + 0.10 * wobble),
				Color(color, 0.22 + 0.20 * wobble), 3.0 + 6.0 * wobble)
