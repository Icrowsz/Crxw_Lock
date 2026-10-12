class_name TeamBadge
extends Control
## Selo do time: o ÍCONE escolhido na tela de formação dentro de um medalhão com a cor do time.
## Sem ícone escolhido, desenha um escudo com a inicial do nome do time.
##
## Usar no placar, na tela final, nos menus...:
##     var badge := TeamBadge.make(team, 40)
##     row.add_child(badge)
## Ele lê tudo do TeamStyle e se atualiza sozinho se o jogador trocar cor, nome ou ícone.

var team: int = 0:
	set(value):
		team = value
		queue_redraw()
## Nome usado na inicial do emblema padrão (vazio = só o nome que o jogador escolheu, se houver)
var fallback_name: String = ""
## Anel colorido em volta do selo
var show_ring: bool = true

var _seen_version: int = -1


static func make(for_team: int, px: float = 40.0, default_name: String = "") -> TeamBadge:
	var badge := TeamBadge.new()
	badge.team = for_team
	badge.fallback_name = default_name
	badge.custom_minimum_size = Vector2(px, px)
	return badge


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(40.0, 40.0)


func _process(_delta: float) -> void:
	if _seen_version != TeamStyle.version:
		_seen_version = TeamStyle.version
		queue_redraw()


func _draw() -> void:
	var color: Color = TeamStyle.color_of(team)
	var center: Vector2 = size * 0.5
	var radius: float = minf(size.x, size.y) * 0.5
	if radius < 2.0:
		return

	# Medalhão: fundo escuro com um brilho da cor do time
	draw_circle(center, radius, color.darkened(0.6))
	draw_circle(center, radius * 0.92, color.darkened(0.35))

	var tex: Texture2D = TeamStyle.icon_of(team)
	if tex != null:
		# Ícone na proporção original, dentro do medalhão
		var box: float = radius * 1.46
		var aspect: float = float(tex.get_width()) / maxf(float(tex.get_height()), 1.0)
		var draw_size: Vector2 = Vector2(box, box / aspect) if aspect >= 1.0 else Vector2(box * aspect, box)
		draw_texture_rect(tex, Rect2(center - draw_size * 0.5, draw_size), false)
	else:
		_draw_default_emblem(center, radius, color)

	if show_ring:
		draw_arc(center, radius - 1.5, 0.0, TAU, 48, color, maxf(2.0, radius * 0.1))
		draw_arc(center, radius - 0.5, 0.0, TAU, 48, Color(1, 1, 1, 0.55), 1.0)


## Escudo com a inicial do nome do time
func _draw_default_emblem(center: Vector2, radius: float, color: Color) -> void:
	var w: float = radius * 0.62
	var top: float = -radius * 0.62
	var bottom: float = radius * 0.7
	var shield := PackedVector2Array([
		center + Vector2(-w, top),
		center + Vector2(w, top),
		center + Vector2(w, top + (bottom - top) * 0.5),
		center + Vector2(0.0, bottom),
		center + Vector2(-w, top + (bottom - top) * 0.5),
	])
	draw_colored_polygon(shield, color)
	var rim: PackedVector2Array = shield.duplicate()
	rim.append(shield[0])
	draw_polyline(rim, color.lightened(0.45), maxf(1.5, radius * 0.07))

	var label: String = TeamStyle.name_of(team, fallback_name).strip_edges()
	if label == "":
		label = str(team + 1)
	var letter: String = label.substr(0, 1).to_upper()
	var font: Font = ThemeDB.fallback_font
	var font_size: int = maxi(int(radius * 0.95), 8)
	var text_size: Vector2 = font.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	var text_pos: Vector2 = center + Vector2(-text_size.x * 0.5, text_size.y * 0.28)
	# Letra clara em cor escura e vice-versa, para sempre dar para ler
	var luminance: float = color.r * 0.3 + color.g * 0.59 + color.b * 0.11
	var text_color: Color = Color(0.08, 0.08, 0.1) if luminance > 0.55 else Color.WHITE
	draw_string(font, text_pos, letter, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, text_color)
