class_name StatusHud
extends CanvasLayer
## STATUS VISÍVEIS: uma fileira de rostinhos no topo da tela, só dos personagens que têm algo ATIVO (meio transparentes;
## ficam inteiros quando o mouse passa). O time 0 fica no canto de CIMA À ESQUERDA
## e o time 1 no canto de CIMA À DIREITA. Passando o mouse num rostinho aparece a lista do que está ATIVO naquele personagem.
##
## No próprio rostinho:
##   anel na cor do time (dourado = quem está agindo) · cinza e com "X" = derrubado
##   setinhas amarelas = Suspenso (1) / Voando (2) · bolinha azul com número = quantidade de efeitos ativos
##
## O QUE APARECE NA LISTA (tudo lido do Player, nada para configurar):
##   altura, derrubado, travado, habilidades/ações gerais proibidas por outro jogador, habilidades desabilitadas,
##   recargas das habilidades, e bônus (próximo chute, passe, correr, ações extras).
##
## EFEITOS PRÓPRIOS DO PERSONAGEM: no script dele, crie
##     func get_status_effects() -> Array:
##         return [{"text": "Metavision ativa (2 rodadas)", "color": Color.CYAN}, "texto simples também vale"]
## e a linha aparece junto das outras. Devolver [] = nada a mostrar.
##
## Quem cria: GameMode.apply_to() (chamado pelo MatchManager). Também dá para criar na mão: StatusHud.new() com manager.

@export var chip_size: float = 56.0
@export var top_margin: float = 12.0
@export var side_margin: float = 14.0
## Espaço extra no canto direito para os botões de pausa do placar não ficarem em cima dos rostos
@export var right_extra_margin: float = 190.0
@export var refresh_interval: float = 0.15
## Opacidade dos rostinhos parados (1.0 quando o mouse passa por cima)
@export_range(0.05, 1.0) var idle_opacity: float = 0.5
## true = só aparecem os personagens que têm algo ativo (altura, derrubado, recarga, bônus, efeito próprio...)
@export var only_active: bool = true

var manager: MatchManager

var _rows: Array[HBoxContainer] = []
var _chips: Dictionary = {}      # Player -> _Chip
var _tip: PanelContainer
var _tip_box: VBoxContainer
var _tip_signature: String = ""
var _hover: Player = null
var _timer: float = 0.0


func _ready() -> void:
	layer = 9   # abaixo do placar/menu (10), acima do campo
	for team in 2:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if team == 0:
			row.set_anchors_preset(Control.PRESET_TOP_LEFT)
			row.offset_left = side_margin
			row.offset_top = top_margin
		else:
			row.set_anchors_preset(Control.PRESET_TOP_RIGHT)
			row.grow_horizontal = Control.GROW_DIRECTION_BEGIN
			row.offset_right = -(side_margin + right_extra_margin)
			row.offset_top = top_margin
		add_child(row)
		_rows.append(row)

	_tip = PanelContainer.new()
	UiStyle.style_panel(_tip)
	_tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip.visible = false
	_tip.z_index = 50
	add_child(_tip)
	_tip_box = VBoxContainer.new()
	_tip_box.add_theme_constant_override("separation", 2)
	_tip_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip.add_child(_tip_box)
	_sync()


func _process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = refresh_interval
	if manager == null:
		manager = get_tree().get_first_node_in_group("match_manager") as MatchManager
	_sync()
	for p in _chips:
		(_chips[p] as _Chip).refresh(p, manager, collect(p, manager))
	_update_tip()


## Cria/remove rostinhos conforme os jogadores existem (troca de personagem, treino, substituição)
func _sync() -> void:
	for p: Player in get_tree().get_nodes_in_group("players"):
		if not _chips.has(p) or (_chips[p] as _Chip).team != p.team:
			if _chips.has(p):
				(_chips[p] as _Chip).queue_free()
			var chip := _Chip.new()
			chip.hud = self
			chip.size_px = chip_size
			chip.team = p.team
			chip.player = p
			chip.modulate.a = idle_opacity
			chip.visible = not only_active
			_rows[clampi(p.team, 0, 1)].add_child(chip)
			_chips[p] = chip
	for p in _chips.keys():
		if not is_instance_valid(p) or not p.is_inside_tree():
			(_chips[p] as _Chip).queue_free()
			_chips.erase(p)
			if _hover == p:
				_hover = null


func _on_hover(p: Player, on: bool) -> void:
	if on:
		_hover = p
		_tip_signature = ""
		_update_tip()
	elif _hover == p:
		_hover = null
		_tip.visible = false


# ---------- COLETA DO QUE ESTÁ ATIVO ----------

## Lista do que está ativo no personagem: [{"text": String, "color": Color}]
static func collect(p: Player, m: MatchManager) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if p == null or not is_instance_valid(p):
		return out
	var round_now: int = m.round_number if m != null else 0

	if p.height_level != Heights.Level.GROUND:
		out.append(_fx("Altura: %s" % Heights.level_name(p.height_level), Color(1.0, 0.85, 0.3)))
	if p.is_down:
		var extra: String = ""
		if m != null:
			var left: int = m.auto_stand_up_rounds - p.rounds_down
			if left > 0:
				extra = " (levanta sozinho em %d rodada%s)" % [left, "" if left == 1 else "s"]
		out.append(_fx("Derrubado" + extra, UiStyle.BAD_COLOR))
	if p.is_locked():
		out.append(_fx("Travado: não pode agir", UiStyle.BAD_COLOR))
	if p.is_generals_suppressed():
		out.append(_fx("Ações gerais proibidas", UiStyle.BAD_COLOR))
	if p.is_skills_suppressed():
		out.append(_fx("Habilidades proibidas", UiStyle.BAD_COLOR))
	for id in p.disabled_skills:
		var until: int = int(p.disabled_skills[id])
		if until >= round_now:
			out.append(_fx("%s desabilitada (até a rodada %d)" % [_pretty(id), until], UiStyle.BAD_COLOR))

	# Recargas
	var cds: Dictionary = p.snapshot_cooldowns()
	for group in cds:
		var left_cd: int = int(cds[group]) - round_now
		if left_cd > 0:
			out.append(_fx("Recarga: %s (%d rodada%s)" % [_pretty(group), left_cd, "" if left_cd == 1 else "s"], Color(0.55, 0.75, 1.0)))

	# Bônus acumulados
	if not is_equal_approx(p.next_kick_force_mult, 1.0):
		out.append(_fx("Próximo chute: força x%.2f" % p.next_kick_force_mult, UiStyle.GOOD_COLOR))
	if not is_zero_approx(p.next_shot_bonus):
		out.append(_fx("Próximo chute: %+d%% de chance" % int(round(p.next_shot_bonus * 100.0)), UiStyle.GOOD_COLOR))
	if not is_zero_approx(p.pass_range_bonus):
		out.append(_fx("Passe: %+d de alcance" % int(round(p.pass_range_bonus)), UiStyle.GOOD_COLOR))
	if not is_zero_approx(p.run_time_bonus):
		out.append(_fx("Correr: %+.1f s" % p.run_time_bonus, UiStyle.GOOD_COLOR))
	if p.extra_skill_left > 0:
		out.append(_fx("+%d ação de habilidade" % p.extra_skill_left, UiStyle.GOOD_COLOR))
	if p.extra_general_left > 0:
		out.append(_fx("+%d ação geral" % p.extra_general_left, UiStyle.GOOD_COLOR))
	if p.extra_general_no_run_left > 0:
		out.append(_fx("+%d ação geral (menos Correr)" % p.extra_general_no_run_left, UiStyle.GOOD_COLOR))
	if p.slide_immune:
		out.append(_fx("Imune a Carrinho", UiStyle.GOOD_COLOR))

	# Efeitos que o próprio personagem declara
	if p.has_method("get_status_effects"):
		for item in p.get_status_effects():
			if item is Dictionary:
				out.append(_fx(String(item.get("text", "")), item.get("color", UiStyle.TEXT_COLOR)))
			elif item is String or item is StringName:
				out.append(_fx(String(item), UiStyle.TEXT_COLOR))
	return out


static func _fx(text: String, color: Color) -> Dictionary:
	return {"text": text, "color": color}


## "cryo_shot" -> "Cryo shot"
static func _pretty(id: Variant) -> String:
	var s: String = String(id).replace("_", " ").strip_edges()
	return s.substr(0, 1).to_upper() + s.substr(1)


# ---------- DICA (O QUE ESTÁ ATIVO) ----------

func _update_tip() -> void:
	if _hover == null or not is_instance_valid(_hover) or not _chips.has(_hover):
		_tip.visible = false
		return
	var effects: Array[Dictionary] = collect(_hover, manager)
	var sig: String = "%s|%s" % [_hover.get_instance_id(), str(effects)]
	if sig != _tip_signature:
		_tip_signature = sig
		for c in _tip_box.get_children():
			c.queue_free()
		var color: Color = TeamStyle.color_of(_hover.team).lightened(0.25)
		_tip_box.add_child(UiStyle.make_label(_hover.get_display_name(), 22, color))
		if effects.is_empty():
			_tip_box.add_child(UiStyle.make_label("Nenhum efeito ativo", 17, UiStyle.MUTED_COLOR))
		for e in effects:
			_tip_box.add_child(UiStyle.make_label("• " + String(e["text"]), 17, e["color"]))
		_tip.reset_size()
	var chip: _Chip = _chips[_hover]
	if not chip.visible:
		_hover = null   # o efeito acabou com o mouse em cima
		_tip.visible = false
		return
	var pos: Vector2 = chip.global_position + Vector2(0.0, chip.size.y + 8.0)
	var vp: Vector2 = get_viewport().get_visible_rect().size
	pos.x = clampf(pos.x, 6.0, maxf(6.0, vp.x - _tip.size.x - 6.0))
	_tip.position = pos
	_tip.visible = true


# ---------- O ROSTINHO ----------

class _Chip extends Control:
	var hud: StatusHud
	var player: Player
	var team: int = 0
	var size_px: float = 56.0
	var effect_count: int = 0
	var is_active: bool = false
	var is_down: bool = false
	var level: int = 0
	var _hovering: bool = false
	var _face: Texture2D
	var _face_owner: Player
	var _scale_tween: Tween

	func _ready() -> void:
		custom_minimum_size = Vector2(size_px, size_px)
		size = custom_minimum_size
		mouse_filter = Control.MOUSE_FILTER_STOP
		pivot_offset = custom_minimum_size * 0.5
		mouse_entered.connect(_set_hover.bind(true))
		mouse_exited.connect(_set_hover.bind(false))

	func _set_hover(on: bool) -> void:
		_hovering = on
		if _scale_tween != null and _scale_tween.is_valid():
			_scale_tween.kill()
		_scale_tween = create_tween()
		_scale_tween.set_parallel(true)
		_scale_tween.tween_property(self, "scale", Vector2.ONE * (1.14 if on else 1.0), 0.12)
		_scale_tween.tween_property(self, "modulate:a", 1.0 if on else hud.idle_opacity, 0.15)
		if hud != null and is_instance_valid(player):
			hud._on_hover(player, on)
		queue_redraw()

	func refresh(p: Player, m: MatchManager, effects: Array[Dictionary]) -> void:
		if player != p or _face_owner != p:
			_face = p.get_face_image()   # só procura o arquivo uma vez por personagem
			_face_owner = p
		player = p
		is_down = p.is_down
		level = int(p.height_level)
		is_active = m != null and m.active_player == p
		# A altura e o "derrubado" já têm sinal próprio: o número conta só o resto
		var n: int = effects.size()
		if level != 0:
			n -= 1
		if is_down:
			n -= 1
		effect_count = maxi(n, 0)
		var show_it: bool = (not hud.only_active) or not effects.is_empty()
		if visible != show_it:
			visible = show_it
			if not show_it:
				_hovering = false
		queue_redraw()

	func _draw() -> void:
		if not is_instance_valid(player):
			return
		var c: Vector2 = size * 0.5
		var r: float = size.x * 0.42
		var team_color: Color = TeamStyle.color_of(team)
		draw_circle(c, r + 3.0, Color(0.05, 0.06, 0.09, 0.9))
		var tex: Texture2D = _face
		if tex != null:
			_draw_face(tex, c, r)
		else:
			draw_circle(c, r, team_color.darkened(0.45))
			var initial: String = player.get_display_name().substr(0, 1).to_upper()
			draw_string(ThemeDB.fallback_font, c + Vector2(-r, 8.0), initial, HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, 24, Color.WHITE)
		if is_down:
			draw_circle(c, r, Color(0.0, 0.0, 0.0, 0.55))
			var d: float = r * 0.5
			draw_line(c + Vector2(-d, -d), c + Vector2(d, d), UiStyle.BAD_COLOR, 4.0)
			draw_line(c + Vector2(-d, d), c + Vector2(d, -d), UiStyle.BAD_COLOR, 4.0)
		# Anel: cor do time, dourado e mais grosso para quem está agindo
		if is_active:
			draw_arc(c, r + 2.0, 0.0, TAU, 40, UiStyle.ACCENT_COLOR, 4.5)
		else:
			draw_arc(c, r + 1.5, 0.0, TAU, 40, Color(team_color, 0.95), 3.0)
		if _hovering:
			draw_arc(c, r + 6.0, 0.0, TAU, 40, Color(1, 1, 1, 0.85), 2.0)
		# Altura: 1 seta = Suspenso, 2 = Voando (embaixo à esquerda)
		for i in level:
			var base := Vector2(size.x * 0.12 + 11.0 * float(i), size.y - 5.0)
			draw_colored_polygon(PackedVector2Array([
				base + Vector2(0, -10), base + Vector2(-6, 0), base + Vector2(6, 0)]), UiStyle.ACCENT_COLOR)
		# Efeitos ativos: bolinha com o número (em cima à direita)
		if effect_count > 0:
			var bp := Vector2(size.x - 9.0, 9.0)
			draw_circle(bp, 9.0, Color(0.2, 0.45, 0.95))
			draw_arc(bp, 9.0, 0.0, TAU, 20, Color.WHITE, 1.5)
			draw_string(ThemeDB.fallback_font, bp + Vector2(-9.0, 5.0), str(effect_count), HORIZONTAL_ALIGNMENT_CENTER, 18.0, 14, Color.WHITE)

	func _draw_face(tex: Texture2D, c: Vector2, r: float) -> void:
		var aspect: float = float(tex.get_width()) / maxf(float(tex.get_height()), 1.0)
		var su: float = 1.0 / aspect if aspect >= 1.0 else 1.0
		var sv: float = 1.0 if aspect >= 1.0 else aspect
		var cv: float = 0.5 - maxf(0.0, 1.0 - aspect) * 0.25   # retrato alto: foca na parte de cima
		var pts := PackedVector2Array()
		var uvs := PackedVector2Array()
		for i in 28:
			var a: float = TAU * float(i) / 28.0
			pts.append(c + Vector2(cos(a), sin(a)) * r)
			uvs.append(Vector2(0.5 + 0.5 * cos(a) * su, cv + 0.5 * sin(a) * sv))
		draw_colored_polygon(pts, Color.WHITE, uvs, tex)
