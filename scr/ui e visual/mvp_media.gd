class_name MvpMedia
extends PanelContainer
## Moldura do MVP que aceita IMAGEM ou VÍDEO e se ADAPTA ao formato da mídia (quadrada, vertical, 16:9, ultrawide...).
##
## Uso (a mesma assinatura do MvpPortrait, com o vídeo como 4º argumento opcional):
##     var portrait := MvpMedia.new()
##     portrait.setup(imagem, cor_do_time, nome, video)      # video pode ser null
##     caixa.add_child(portrait)
##
## - Imagem: a moldura assume a proporção da textura (largura/altura) na hora.
## - Vídeo: toca em loop e muda de proporção assim que o primeiro quadro é decodificado (o tamanho do vídeo só é
##   conhecido depois de ele começar a tocar): a moldura começa em 16:9 e se ajusta com uma animação curta.
## - Sem imagem nem vídeo: um quadrado com a inicial do jogador (como placeholder).
## - Quem tem os dois (imagem e vídeo) mostra o vídeo; a imagem serve de reserva se o vídeo falhar.
##
## A mídia nunca passa de max_size (cabe dentro dessa caixa mantendo a proporção) nem fica menor que min_edge no lado
## menor. O Godot 4 só toca vídeo Ogg Theora (.ogv); veja os comentários do player.gd (get_mvp_video).

@export var max_size: Vector2 = Vector2(560.0, 420.0)   # a maior caixa que a mídia pode ocupar
@export var min_edge: float = 160.0                      # o lado menor nunca fica abaixo disto
@export var default_aspect: float = 16.0 / 9.0           # proporção até o vídeo mostrar o tamanho real
@export var video_volume_db: float = -6.0
@export var loop_video: bool = true
@export var frame_padding: float = 6.0
## Moldura própria (ex: a tela final do jogo usa borda dourada). Vazio = moldura padrão do UiStyle na cor do time.
@export var frame_style: StyleBoxFlat

var _video: VideoStreamPlayer
var _fit_tween: Tween
var _color: Color = Color.WHITE
var _frame_extra: Vector2 = Vector2.ZERO   # o que a moldura (margens) soma ao tamanho da mídia


## O vídeo do MVP: o que foi passado (ex: mvp["video"]) ou, se vazio, res://assets/mvp/<character_id>.ogv. null = não tem.
static func find_video(character_id: String, explicit: VideoStream = null) -> VideoStream:
	if explicit != null:
		return explicit 
	var path: String = "res://img/mvps/videos/%s.ogv" % character_id
	return load(path) as VideoStream if character_id != "" and ResourceLoader.exists(path) else null


func setup(image: Texture2D, color: Color, player_name: String = "", video: VideoStream = null) -> void:
	_color = color
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	clip_contents = true
	var frame: StyleBoxFlat = frame_style
	if frame == null:
		frame = UiStyle.panel_style(color, frame_padding, frame_padding)
		frame.set_corner_radius_all(12)   # raio menor que o padrão: o canto do vídeo não vaza para fora da moldura
	add_theme_stylebox_override("panel", frame)
	_frame_extra = frame.get_minimum_size()

	if video != null:
		_setup_video(video, image)
	elif image != null:
		_setup_image(image)
	else:
		_setup_placeholder(player_name)


# ---------- IMAGEM ----------

func _setup_image(image: Texture2D) -> void:
	var rect := TextureRect.new()
	rect.texture = image
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE   # a moldura já tem a proporção da imagem
	add_child(rect)
	var size: Vector2 = image.get_size()
	_fit(size.x / maxf(size.y, 1.0), false)


# ---------- VÍDEO ----------

func _setup_video(video: VideoStream, fallback_image: Texture2D) -> void:
	_video = VideoStreamPlayer.new()
	_video.expand = true            # o vídeo se estica até o tamanho da moldura (que tem a proporção dele)
	_video.loop = loop_video
	_video.volume_db = video_volume_db
	_video.stream = video
	add_child(_video)
	_fit(default_aspect, false)
	_video.play()
	_wait_video_size(fallback_image)


## O tamanho real do vídeo só existe depois do primeiro quadro: espera até ~1,5 s e então ajusta a moldura
func _wait_video_size(fallback_image: Texture2D) -> void:
	for i in 90:
		await get_tree().process_frame
		if not is_instance_valid(_video):
			return
		var tex: Texture2D = _video.get_video_texture()
		if tex != null and tex.get_width() > 0 and tex.get_height() > 0:
			_fit(float(tex.get_width()) / float(tex.get_height()), true)
			return
	# O vídeo não abriu (formato não suportado, arquivo corrompido...): cai na imagem, se houver
	push_warning("MvpMedia: o vídeo não começou a tocar (o Godot 4 só toca .ogv / Ogg Theora).")
	if is_instance_valid(_video):
		_video.queue_free()
		_video = null
	if fallback_image != null:
		_setup_image(fallback_image)
	else:
		_setup_placeholder("")


# ---------- PLACEHOLDER ----------

func _setup_placeholder(player_name: String) -> void:
	var initial: String = player_name.substr(0, 1).to_upper() if player_name != "" else "?"
	var label := UiStyle.make_label(initial, 96, _color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(label)
	_fit(1.0, false)


# ---------- ADAPTAÇÃO AO FORMATO ----------

## O maior retângulo com essa proporção que cabe em max_size (e com o lado menor de pelo menos min_edge)
func fitted_size(aspect: float) -> Vector2:
	aspect = clampf(aspect, 0.2, 5.0)
	var w: float = max_size.x
	var h: float = w / aspect
	if h > max_size.y:   # muito alto: limita pela altura
		h = max_size.y
		w = h * aspect
	if minf(w, h) < min_edge:   # muito fino/achatado: sobe o lado menor sem passar do máximo
		var k: float = min_edge / minf(w, h)
		w = minf(w * k, max_size.x)
		h = minf(h * k, max_size.y)
	return Vector2(roundf(w), roundf(h))


func _fit(aspect: float, animate: bool) -> void:
	var target: Vector2 = fitted_size(aspect) + _frame_extra   # + as margens da moldura
	if _fit_tween != null and _fit_tween.is_valid():
		_fit_tween.kill()
	if not animate:
		custom_minimum_size = target
		return
	_fit_tween = create_tween()
	_fit_tween.tween_property(self, "custom_minimum_size", target, 0.3) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
