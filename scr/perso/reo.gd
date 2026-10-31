class_name Reo
extends Player

const SKILL_COPY: StringName = &"copy"
const SKILL_ROLE: StringName = &"role"
const SKILL_COPIED: StringName = &"copied"
const SKILL_DREAM: StringName = &"our_dream"
const SKILL_PANTHER: StringName = &"model_panther"

const REACTION_COPY_BEE: StringName = &"copy_bee"
const SKILL_STEP_OVERS: StringName = &"step_overs"
const PANTHER_TURN_DEG: float = -60.0
const PANTHER_CURVE_TIME: float = 1.0

const CD_COPY: StringName = &"cd_copy"
const CD_ROLE: StringName = &"cd_role"
const CD_DREAM: StringName = &"cd_dream"

enum Zone { DEFENSE, SUPPORT, OFFENSIVE }

const COLOR_PURPLE := Color(0.65, 0.3, 0.95)
const REACTION_MIRACLE: StringName = &"miracle"

signal popup_done(index: int)

@export_group("Copy")
@export var copy_range: float = 900.0
@export var copy_rounds: int = 4
@export var copy_cooldown: int = 2

@export_group("Role")
@export var role_cooldown: int = 2
@export_range(0.0, 1.0) var zone_threshold: float = 0.33
@export var chance_attack: float = 0.45
@export var support_range: float = 500.0
@export var defense_range: float = 450.0
@export_range(0.0, 1.0) var duel_chance: float = 0.60
@export var duel_dash_time: float = 0.3
@export var header_range: float = 250.0
@export var header_jump_time: float = 0.3
@export var chance_header: float = -1.0

@export_group("Our Dream (Reação Miracle)")
@export var dream_cooldown: int = 3
@export var dream_range: float = 500.0
@export_range(0.0, 0.6) var dream_curve: float = 0.25
@export var dream_bend_sign: float = 1.0
@export var dream_flight_time: float = 0.9
@export_range(0.2, 0.9) var dream_flight_fraction: float = 0.6
@export var dream_only_when_reaction_ready: bool = true
@export var dream_is_free: bool = false

@export_group("Visual")
@export var kick_fx: KickFX
@export var aura_amount: int = 46
@export var aura_scale_min: float = 3.0
@export var aura_scale_max: float = 6.5
@export var aura_radius_mult: float = 1.6
@export var face_dir: String = "res://img/rostinhos/"
@export var face_size: float = 44.0
@export var face_offset: float = 46.0

@export_group("Descrição (hover)")
@export var skill_icons: Dictionary = {}

var _copy_ghost: Player = null
var _copy_skill_id: StringName = &""
var _copy_until_round: int = -1
var _ghost_busy: bool = false
var last_our_dream: Dictionary = {}

var _aura: CPUParticles2D
var _burst: CPUParticles2D
var _face: Sprite2D
var _face_cache: Dictionary = {}

var _panther_ready: bool = false
var _aiming_curve: bool = false

func _init() -> void:
	character_id = "reo"
	display_name = "Reo Mikage"

func _ready() -> void:
	super()
	if kick_fx == null:
		kick_fx = _make_fx()
	_make_aura()
	_make_face()
	_hook_manager.call_deferred()

func _exit_tree() -> void:
	if _copy_ghost != null and is_instance_valid(_copy_ghost):
		_copy_ghost.queue_free()

func _hook_manager() -> void:
	var m: MatchManager = _get_manager()
	if m:
		m.round_started.connect(_on_round_started)
		m.turn_ended.connect(_on_turn_ended)

func _on_turn_ended(ended_team: int) -> void:
	if ended_team == team and _panther_ready:
		_panther_ready = false
		queue_redraw()

func _on_round_started(round_number: int) -> void:
	if _copy_ghost != null and round_number > _copy_until_round:
		_end_copy(false)

func _make_fx() -> KickFX:
	var fx := KickFX.new()
	fx.color = COLOR_PURPLE
	fx.trail_width = 14.0
	fx.particle_color = Color(0.85, 0.65, 1.0)
	fx.amount = 22
	fx.lifetime = 0.55
	fx.speed_min = 15.0
	fx.speed_max = 70.0
	fx.gravity = Vector2(0.0, -40.0)
	fx.spin = 200.0
	fx.scale_min = 0.15
	fx.scale_max = 0.35
	fx.burst_amount = 14
	fx.burst_speed = 200.0
	return fx

func _make_aura() -> void:
	_aura = CPUParticles2D.new()
	_aura.emitting = false
	_aura.amount = aura_amount
	_aura.lifetime = 1.5
	_aura.local_coords = false
	_aura.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	_aura.emission_sphere_radius = placeholder_radius * aura_radius_mult
	_aura.direction = Vector2(0.0, -1.0)
	_aura.spread = 35.0
	_aura.gravity = Vector2(0.0, -35.0)
	_aura.initial_velocity_min = 10.0
	_aura.initial_velocity_max = 34.0
	_aura.scale_amount_min = aura_scale_min
	_aura.scale_amount_max = aura_scale_max
	_aura.color_ramp = _purple_ramp(0.7)
	_aura.z_index = 1
	add_child(_aura)

	_burst = CPUParticles2D.new()
	_burst.emitting = false
	_burst.one_shot = true
	_burst.explosiveness = 1.0
	_burst.amount = 48
	_burst.lifetime = 0.9
	_burst.local_coords = false
	_burst.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	_burst.emission_sphere_radius = placeholder_radius
	_burst.spread = 180.0
	_burst.gravity = Vector2(0.0, -20.0)
	_burst.initial_velocity_min = 80.0
	_burst.initial_velocity_max = 190.0
	_burst.scale_amount_min = 3.0
	_burst.scale_amount_max = 7.0
	_burst.color_ramp = _purple_ramp(0.9)
	_burst.z_index = 1
	add_child(_burst)

func _purple_ramp(alpha: float) -> Gradient:
	var ramp := Gradient.new()
	ramp.set_color(0, Color(COLOR_PURPLE, alpha))
	ramp.set_color(1, Color(COLOR_PURPLE, 0.0))
	return ramp

func _make_face() -> void:
	_face = Sprite2D.new()
	_face.visible = false
	_face.z_index = 3
	add_child(_face)

func _face_texture_for(p: Player) -> Texture2D:
	var keys: Array[String] = [p.character_id, p.get_display_name(), String(p.name)]
	for word in p.get_display_name().split(" "):
		keys.append(word)
	for key in keys:
		if key == "" or key == "base":
			continue
		var variants: Array[String] = [key, key.to_lower(), key.to_lower().replace(" ", "_"), key.capitalize().replace(" ", "")]
		for v in variants:
			for ext in ["png", "webp", "jpg"]:
				var path: String = "%s%s.%s" % [face_dir, v, ext]
				if _face_cache.has(path):
					if _face_cache[path] != null:
						return _face_cache[path]
					continue
				if ResourceLoader.exists(path):
					var tex := load(path) as Texture2D
					_face_cache[path] = tex
					if tex != null:
						return tex
				else:
					_face_cache[path] = null
	return null

func _show_face(tex: Texture2D) -> void:
	if tex == null:
		_face.visible = false
		return
	_face.texture = tex
	var longest: float = maxf(tex.get_width(), tex.get_height())
	var k: float = face_size / maxf(longest, 1.0)
	_face.scale = Vector2(k, k)
	_face.visible = true
	queue_redraw()

func _refresh_aura() -> void:
	if _aura:
		_aura.emitting = _copy_ghost != null
	if _face and _copy_ghost == null:
		_face.visible = false
	queue_redraw()

func _make_ghost(src: Player) -> Player:
	var g := src.duplicate(Node.DUPLICATE_SCRIPTS | Node.DUPLICATE_USE_INSTANTIATION) as Player
	if g == null:
		return null
	g.name = "Copia_%s" % src.name
	g.set_meta("ghost_owner", self)
	get_parent().add_child(g)
	_hide_ghost(g)
	await get_tree().process_frame
	if is_instance_valid(g):
		_hide_ghost(g)
	return g

func _hide_ghost(g: Player) -> void:
	for grp in g.get_groups():
		if not String(grp).begins_with("_"):
			g.remove_from_group(grp)
	g.input_pickable = false
	g.collision_layer = 0
	g.collision_mask = 0
	g.draw_placeholder = false
	g.draw_shadow = false
	g.draw_team_marker = false
	for c in g.get_children():
		if c is CanvasItem:
			(c as CanvasItem).visible = false
	g.queue_redraw()

func _sync_ghost_from_reo(ghost: Player = null) -> void:
	var g: Player = ghost if ghost != null else _copy_ghost
	if g == null or not is_instance_valid(g) or _ghost_busy:
		return
	g.team = team
	g.global_position = global_position
	g.height_level = height_level
	g.height = height
	g.facing = facing
	g.is_down = is_down
	g.runs_this_turn = runs_this_turn
	g.slides_this_turn = slides_this_turn
	g.home_position = home_position

func _sync_reo_from_ghost() -> void:
	var g: Player = _copy_ghost
	if g == null or not is_instance_valid(g):
		return
	global_position = g.global_position
	height_level = g.height_level
	height = g.height
	facing = g.facing
	if g.is_down and not is_down:
		knock_down()
	elif not g.is_down and is_down:
		get_up_now()

func _transfer_ghost_gains() -> void:
	var g: Player = _copy_ghost
	if g == null or not is_instance_valid(g):
		return
	extra_general_left += g.extra_general_left
	extra_general_no_run_left += g.extra_general_no_run_left
	extra_skill_left += g.extra_skill_left
	next_shot_bonus += g.next_shot_bonus
	next_kick_force_mult *= g.next_kick_force_mult
	g.extra_general_left = 0
	g.extra_general_no_run_left = 0
	g.extra_skill_left = 0
	g.next_shot_bonus = 0.0
	g.next_kick_force_mult = 1.0

func _ghost_skill_name() -> String:
	if _copy_ghost == null or not is_instance_valid(_copy_ghost):
		return ""
	_sync_ghost_from_reo()
	for s in _copy_ghost.get_skills():
		if s["id"] == _copy_skill_id:
			return String(s["name"])
	return String(_copy_skill_id)

func _end_copy(spent: bool) -> void:
	if _copy_ghost == null:
		return
	var from_round: int = (get_current_round() if spent else _copy_until_round) + 1
	_drop_ghost()
	start_cooldown(CD_COPY, copy_cooldown, from_round)

func _drop_ghost() -> void:
	_ghost_busy = false
	if _copy_ghost != null and is_instance_valid(_copy_ghost):
		var ball: Ball = _get_ball()
		if ball != null:
			ball.replace_player(_copy_ghost, self)
		_copy_ghost.queue_free()
	_copy_ghost = null
	_copy_skill_id = &""
	_copy_until_round = -1
	_refresh_aura()

func _copy_candidates() -> Array[Player]:
	var list: Array[Player] = []
	for other: Player in get_tree().get_nodes_in_group("players"):
		if other == self or other.character_id == character_id or other.character_id == "base":
			continue
		if global_position.distance_to(other.global_position) <= copy_range:
			list.append(other)
	return list

func _show_copy_targets(cands: Array[Player], on: bool) -> void:
	range_preview = copy_range if on else 0.0
	for p in cands:
		if is_instance_valid(p):
			p.is_pass_option = on

func _use_copy() -> bool:
	var m: MatchManager = _get_manager()
	if m == null or _copy_ghost != null:
		return false
	var cands: Array[Player] = _copy_candidates()
	if cands.is_empty():
		return false

	var labels: Array[String] = []
	var icons: Array = []
	for p in cands:
		labels.append("%s  ·  %s" % [p.get_display_name(), m.get_team_name(p.team)])
		icons.append(_face_texture_for(p))
	_show_copy_targets(cands, true)
	var target_idx: int = await _popup_choose("COPY  —  quem copiar?", labels, icons)
	_show_copy_targets(cands, false)
	if target_idx < 0 or not is_instance_valid(cands[target_idx]):
		return false
	var target: Player = cands[target_idx]

	var qte_ok: bool = await m.run_qte(KickType.VOLLEY)
	if not await play_action(&"copy"):
		return false
	if not qte_ok:
		return true

	var ghost: Player = await _make_ghost(target)
	if ghost == null:
		return false
	_sync_ghost_from_reo(ghost)
	var options: Array[Dictionary] = []
	var skill_labels: Array[String] = []
	for s in ghost.get_skills():
		if ghost.skill_is_free(s["id"]):
			continue
		options.append(s)
		skill_labels.append(String(s["name"]))
	if options.is_empty():
		ghost.queue_free()
		return false
	var skill_idx: int = await _popup_choose("COPY  —  habilidade de %s" % target.get_display_name(), skill_labels, [], _face_texture_for(target))
	if skill_idx < 0:
		ghost.queue_free()
		return false

	_copy_ghost = ghost
	_copy_skill_id = StringName(options[skill_idx]["id"])
	_copy_until_round = get_current_round() + copy_rounds - 1
	_refresh_aura()
	_show_face(_face_texture_for(target))
	if _burst:
		_burst.restart()
	extra_skill_left += 1
	return true

func _use_copied() -> bool:
	if _copy_ghost == null or not is_instance_valid(_copy_ghost):
		return false
	_sync_ghost_from_reo()
	_ghost_busy = true
	var used: bool = await _copy_ghost.use_skill(_copy_skill_id)
	_ghost_busy = false
	if _copy_ghost == null:
		return used
	_sync_reo_from_ghost()
	_transfer_ghost_gains()
	
	if used and String(_copy_skill_id) == "step_overs":
		var rm := ReactionManager.get_for(self)
		if rm:
			for r in rm.reactions:
				if r.id == &"copy_bee" and rm.is_ready(r, team):
					var partner := r.find_partner(self)
					if partner:
						await rm.play(r, self, partner)
						CopyBeeFX.spawn_wasp(self, 3.5)
						CopyBeeFX.spawn_wasp(partner, 3.5)
						_panther_ready = true
						extra_skill_left += 1
						_show_face(_face_texture_for(partner))
					break
					
	if used:
		_end_copy(true)
	return used

func _popup_choose(title: String, labels: Array[String], icons: Array = [], header_icon: Texture2D = null) -> int:
	var layer := CanvasLayer.new()
	layer.layer = 100
	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.0, 0.1, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(center)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _box(Color(0.12, 0.06, 0.2, 0.96), Color(0.72, 0.4, 1.0), 2, 14, 18))
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.custom_minimum_size = Vector2(380.0, 0.0)
	panel.add_child(box)

	var head_row := HBoxContainer.new()
	head_row.alignment = BoxContainer.ALIGNMENT_CENTER
	head_row.add_theme_constant_override("separation", 10)
	box.add_child(head_row)
	if header_icon != null:
		var face := TextureRect.new()
		face.texture = header_icon
		face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		face.custom_minimum_size = Vector2(44.0, 44.0)
		head_row.add_child(face)
	var head := Label.new()
	head.text = title
	head.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.add_theme_font_size_override("font_size", 20)
	head.add_theme_color_override("font_color", Color(0.93, 0.85, 1.0))
	head.add_theme_color_override("font_outline_color", Color(0.1, 0.0, 0.2))
	head.add_theme_constant_override("outline_size", 6)
	head_row.add_child(head)

	var line := ColorRect.new()
	line.color = Color(0.72, 0.4, 1.0, 0.7)
	line.custom_minimum_size = Vector2(0.0, 2.0)
	box.add_child(line)

	for i in labels.size():
		var b := _purple_button(labels[i])
		if i < icons.size() and icons[i] != null:
			b.icon = icons[i]
			b.expand_icon = true
			b.add_theme_constant_override("icon_max_width", 34)
		b.pressed.connect(popup_done.emit.bind(i))
		box.add_child(b)

	var cancel := _purple_button("Cancelar")
	cancel.add_theme_color_override("font_color", Color(0.75, 0.68, 0.85))
	cancel.pressed.connect(popup_done.emit.bind(-1))
	box.add_child(cancel)

	get_tree().root.add_child(layer)
	var index: int = await popup_done
	layer.queue_free()
	return index

func _box(fill: Color, border: Color, border_w: int, radius: int, margin: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(margin)
	sb.shadow_color = Color(0.45, 0.15, 0.8, 0.45)
	sb.shadow_size = 10
	return sb

func _purple_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(0.0, 40.0)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_color_override("font_color", Color(0.95, 0.92, 1.0))
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_outline_color", Color(0.1, 0.0, 0.2))
	b.add_theme_constant_override("outline_size", 3)
	b.add_theme_stylebox_override("normal", _box(Color(0.22, 0.1, 0.36), Color(0.5, 0.28, 0.8), 1, 8, 10))
	b.add_theme_stylebox_override("hover", _box(Color(0.38, 0.18, 0.6), Color(0.85, 0.55, 1.0), 2, 8, 10))
	b.add_theme_stylebox_override("pressed", _box(Color(0.5, 0.25, 0.8), Color(1.0, 0.8, 1.0), 2, 8, 10))
	return b

func _current_zone() -> Zone:
	var field := get_tree().get_first_node_in_group("field") as Field
	if field == null:
		return Zone.SUPPORT
	var attack_dir: float = get_attack_dir()
	var f: float = field.to_local(global_position).x * attack_dir / (field.pitch_size.x * 0.5)
	if f < -zone_threshold:
		return Zone.DEFENSE
	if f > zone_threshold:
		return Zone.OFFENSIVE
	return Zone.SUPPORT

func _header_available() -> bool:
	if is_down or height_level != Heights.Level.SUSPENDED or _current_zone() != Zone.DEFENSE:
		return false
	var ball: Ball = _get_ball()
	if ball == null or ball.is_held() or ball.is_locked_for(team):
		return false
	if ball.get_level() == Heights.Level.GROUND:
		return false
	return global_position.distance_to(ball.global_position) <= header_range

func _role_skill_name() -> String:
	match _current_zone():
		Zone.DEFENSE:
			return "Chameleon Header" if _header_available() else "Chameleon Defense"
		Zone.OFFENSIVE:
			return "Chameleon Offensive"
	return "Chameleon Support"

func _duel_filter(other: Player) -> bool:
	return not other.is_down and can_reach_level(other.height_level)

func _has_duel_target() -> bool:
	for other: Player in get_tree().get_nodes_in_group("players"):
		if other.team != team and _duel_filter(other) \
				and global_position.distance_to(other.global_position) <= defense_range:
			return true
	return false

func _has_support_target() -> bool:
	var m: MatchManager = _get_manager()
	if m == null:
		return false
	for other in m.get_team_players(team):
		if other != self and global_position.distance_to(other.global_position) <= support_range + pass_range_bonus:
			return true
	return false

func _role_available() -> bool:
	match _current_zone():
		Zone.DEFENSE:
			return _header_available() or _has_duel_target()
		Zone.OFFENSIVE:
			return get_kick_type(_get_ball()) != KickType.NONE
	return get_kick_type(_get_ball()) != KickType.NONE and _has_support_target()

func _use_role() -> bool:
	match _current_zone():
		Zone.DEFENSE:
			if _header_available():
				return await _use_header()
			return await _use_defense()
		Zone.OFFENSIVE:
			return await _use_offensive()
	return await _use_support()

func _use_offensive() -> bool:
	var m: MatchManager = _get_manager()
	var ball: Ball = _get_ball()
	if m == null or get_kick_type(ball) == KickType.NONE:
		return false
	var aim: Vector2 = await m.aim_for_skill(self, kick_aim_range)
	if aim == Vector2.ZERO:
		return false
	var kind: KickType = get_kick_type(ball)
	if kind == KickType.NONE:
		return false
	var qte_ok: bool = true
	if kind != KickType.GROUND and not skips_qte():
		qte_ok = await m.run_qte(kind)
	await kick_ball(ball, aim, kind, qte_ok, chance_attack, false, kick_fx if qte_ok else null, &"chameleon_attack")
	start_cooldown(CD_ROLE, role_cooldown)
	return true

func _use_support() -> bool:
	var m: MatchManager = _get_manager()
	var ball: Ball = _get_ball()
	if m == null or get_kick_type(ball) == KickType.NONE:
		return false
	var target: Player = await m.pick_ally_for_skill(self, support_range + pass_range_bonus)
	if target == null:
		return false
	if get_kick_type(ball) == KickType.NONE:
		return false
	await m.run_ground_pass(self, target, ball)
	start_cooldown(CD_ROLE, role_cooldown)
	return true

func _use_defense() -> bool:
	var m: MatchManager = _get_manager()
	if m == null:
		return false
	var target: Player = await m.pick_ally_for_skill(self, defense_range, true, _duel_filter)
	if target == null:
		return false

	var dir: Vector2 = (target.global_position - global_position).normalized()
	face_towards(dir)
	var stop: Vector2 = target.global_position - dir * (body_radius + target.body_radius + 4.0)
	var tw := create_tween()
	tw.tween_property(self, "global_position", stop, duel_dash_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tw.finished

	if not await play_action(&"chameleon_defense"):
		return false
	if randf() < duel_chance and is_instance_valid(target):
		target.knock_down()
		target.apply_lock(self, 1, true)
	start_cooldown(CD_ROLE, role_cooldown)
	return true

func _use_header() -> bool:
	var m: MatchManager = _get_manager()
	if m == null or not _header_available():
		return false
	var aim: Vector2 = await m.aim_for_skill(self, kick_aim_range)
	if aim == Vector2.ZERO:
		return false
	if not _header_available():
		return false

	var ball: Ball = _get_ball()
	var dir: Vector2 = aim.normalized()
	face_towards(dir)
	var spot: Vector2 = ball.global_position - dir * 20.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "global_position", spot, header_jump_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if ball.get_level() == Heights.Level.FLYING:
		height_level = Heights.Level.FLYING
		tw.tween_property(self, "height", Heights.FLYING_HEIGHT, header_jump_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tw.finished

	var kind: KickType = get_kick_type(ball)
	if kind != KickType.NONE:
		await kick_ball(ball, dir, kind, true, chance_header, false, kick_fx, &"chameleon_header")

	if height_level == Heights.Level.FLYING:
		height_level = Heights.Level.SUSPENDED
		var down := create_tween()
		down.tween_property(self, "height", Heights.SUSPENDED_HEIGHT, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	start_cooldown(CD_ROLE, role_cooldown)
	return true

func _find_dream_partner() -> Player:
	var m: MatchManager = _get_manager()
	if m == null:
		return null
	for p: Player in m.get_team_players(team):
		if p.character_id == "nagi":
			return p
	return null

func _miracle_rounds_left() -> int:
	var rm: ReactionManager = ReactionManager.get_for(self)
	if rm == null:
		return 0
	for reaction: ChemicalReaction in rm.reactions:
		if reaction.id == REACTION_MIRACLE:
			return rm.rounds_left(reaction, team)
	return 0

func _dream_available() -> bool:
	if _find_dream_partner() == null:
		return false
	if dream_only_when_reaction_ready and _miracle_rounds_left() > 0:
		return false
	return get_kick_type(_get_ball()) != KickType.NONE

func _dream_label() -> String:
	var left: int = _miracle_rounds_left()
	if dream_only_when_reaction_ready and left > 0:
		return "Our Dream (reação em recarga %d)" % left
	return skill_label("Our Dream", CD_DREAM)

func skill_is_free(skill_id: StringName) -> bool:
	if skill_id == SKILL_DREAM:
		return dream_is_free
	if skill_id == SKILL_PANTHER:
		return _panther_ready
	return false

func has_free_followup() -> bool:
	return _panther_ready

func _use_dream() -> bool:
	var m: MatchManager = _get_manager()
	var ball: Ball = _get_ball()
	if m == null or ball == null or not _dream_available():
		return false

	var point: Vector2 = await m.pick_point_for_skill(self, dream_range)
	if point == Vector2.INF:
		return false

	face_towards(point - global_position)
	if not await play_action(&"our_dream", ANIM_PASS_HIGH):
		return false
	ball = _get_ball()
	if ball == null or get_kick_type(ball) == KickType.NONE:
		return false

	m.clear_pending_pass()
	ball.register_touch(self)
	PassFX.attach(ball, PassFX.Style.OUR_DREAM)

	await _fly_dream_ball(ball, point)

	var arrive: Tween = ball.hover_to(point, Heights.SUSPENDED_HEIGHT, m.high_pass_arrive_time)
	await arrive.finished
	m.register_skill_pass(team, null)
	MiracleFX.attach(self, 3.0)
	start_cooldown(CD_DREAM, dream_cooldown)
	last_our_dream = {
		"point": point,
		"round": get_current_round(),
		"touches": ball.interaction_count,
	}
	return true

func _fly_dream_ball(ball: Ball, point: Vector2) -> void:
	var start: Vector2 = ball.global_position
	var h0: float = ball.height
	var control: Vector2 = MatchManager.curve_control_point(start, point, dream_curve, dream_bend_sign)

	await ball.hover_to(start, h0, 0.02).finished
	ball.trail_enabled = true
	var previous_fx: bool = ball.fx_during_hover
	ball.fx_during_hover = true
	ball.play_fx(kick_fx)

	var t_end: float = dream_flight_fraction
	var flight: Tween = ball.create_tween()
	flight.tween_method(_step_dream_ball.bind(ball, start, control, point, h0, t_end),
		0.0, t_end, dream_flight_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await flight.finished

	ball.trail_enabled = false
	ball.stop_fx()
	ball.fx_during_hover = previous_fx

func _step_dream_ball(t: float, ball: Ball, start: Vector2, control: Vector2, point: Vector2, h0: float, t_end: float) -> void:
	if not is_instance_valid(ball):
		return
	ball.global_position = MatchManager.curve_point(start, control, point, t)
	ball.height = lerpf(h0, Heights.FLYING_HEIGHT, sin(t / t_end * PI * 0.5))

func _use_panther() -> bool:
	var m := _get_manager()
	var ball := _get_ball()
	if m == null or not _panther_ready or ball == null: return false
	
	_aiming_curve = true
	queue_redraw()
	var aim := await m.aim_for_skill(self, kick_aim_range)
	_aiming_curve = false
	queue_redraw()
	
	if aim == Vector2.ZERO: return false
	
	var saved_peak := volley_peak_level
	volley_peak_level = Heights.Level.SUSPENDED
	next_kick_force_mult = 1.5
	
	var on_kick: Callable = func(b: Ball, d: Vector2, _speed: float) -> void:
		CopyBeeFX.panther(self, b)
		_curve_ball(b, d, PANTHER_TURN_DEG, PANTHER_CURVE_TIME)
		
	await kick_ball(ball, aim, KickType.VOLLEY, true, 0.75, false, kick_fx, &"chameleon_attack", on_kick)
	volley_peak_level = saved_peak

	_panther_ready = false
	queue_redraw()
	return true
	
func _curve_ball(ball: Ball, dir: Vector2, degrees: float, duration: float) -> void:
	var rate := deg_to_rad(degrees) / duration
	var elapsed := 0.0
	var touches := ball.interaction_count
	while elapsed < duration:
		await get_tree().physics_frame
		var dt := get_physics_process_delta_time()
		elapsed += dt
		if not is_instance_valid(ball) or ball.interaction_count != touches or ball.hovering:
			return
		ball.velocity = ball.velocity.rotated(rate * dt)

func get_skills() -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	var copy_name: String = "Copy (cópia ativa)" if _copy_ghost != null else skill_label("Copy", CD_COPY)
	list.append({"id": SKILL_COPY, "name": copy_name})
	list.append({"id": SKILL_ROLE, "name": skill_label(_role_skill_name(), CD_ROLE)})
	var copied_name: String = "Cópia (vazio)"
	if _copy_ghost != null:
		copied_name = "%s (cópia)" % _ghost_skill_name()
	list.append({"id": SKILL_COPIED, "name": copied_name})
	if _find_dream_partner() != null:
		list.append({"id": SKILL_DREAM, "name": _dream_label()})
	if _panther_ready:
		list.append({"id": SKILL_PANTHER, "name": "Model: Panther"})
	return list

func can_use_skill(skill_id: StringName = &"default") -> bool:
	if not super(skill_id):
		return false
	match skill_id:
		SKILL_COPY:
			return _copy_ghost == null and not is_on_cooldown(CD_COPY) and not _copy_candidates().is_empty()
		SKILL_ROLE:
			return not is_on_cooldown(CD_ROLE) and _role_available()
		SKILL_COPIED:
			if _copy_ghost == null or not is_instance_valid(_copy_ghost):
				return false
			_sync_ghost_from_reo()
			return _copy_ghost.can_use_skill(_copy_skill_id)
		SKILL_DREAM:
			return not is_on_cooldown(CD_DREAM) and _dream_available()
		SKILL_PANTHER:
			return _panther_ready and get_kick_type(_get_ball()) != KickType.NONE
	return false

func use_skill(skill_id: StringName = &"default") -> bool:
	match skill_id:
		SKILL_COPY:
			return await _use_copy()
		SKILL_ROLE:
			return await _use_role()
		SKILL_COPIED:
			return await _use_copied()
		SKILL_DREAM:
			return await _use_dream()
		SKILL_PANTHER:
			return await _use_panther()
	return false

func _pct(value: float) -> int:
	return int(round(value * 100.0))

func _chance_text(value: float) -> String:
	return " %d%% de chance de gol." % _pct(value) if value >= 0.0 else " Usa a chance de gol normal do chute."

func get_skill_info(skill_id: StringName) -> Dictionary:
	var title: String = ""
	var text: String = ""
	match skill_id:
		SKILL_COPY:
			title = "Copy"
			text = ("Escolhe um jogador em campo e copia uma habilidade dele por %d rodadas, ou até usá-la. Ela aparece no terceiro botão.\n"
				+ "A Copy também dá +1 ação de habilidade: dá para usar a habilidade copiada já nesta rodada.\n"
				+ "Recarga: %d rodadas.") % [copy_rounds, copy_cooldown]
		SKILL_ROLE:
			title = _role_skill_name()
			match _current_zone():
				Zone.DEFENSE:
					if _header_available():
						text = "Reo salta até a bola no ar e cabeceia." + _chance_text(chance_header)
					else:
						text = "Vai até um inimigo e disputa na sorte (%d%%). Ganhando, o inimigo cai e fica sem habilidades até o fim da rodada." % _pct(duel_chance)
				Zone.OFFENSIVE:
					text = "Chute direto, com a bola em qualquer altura." + _chance_text(chance_attack)
				_:
					text = "Passe rasteiro para um aliado."
			text += "\nRecarga: %d rodadas." % role_cooldown
		SKILL_COPIED:
			if _copy_ghost != null and is_instance_valid(_copy_ghost):
				_sync_ghost_from_reo()
				if _copy_ghost.has_method("get_skill_info"):
					var info: Dictionary = _copy_ghost.get_skill_info(_copy_skill_id)
					if not info.is_empty():
						return info
				title = _ghost_skill_name()
				text = "Habilidade copiada."
			else:
				title = "Cópia"
				text = "Aqui aparece a habilidade que você copiar com o Copy."
		SKILL_DREAM:
			title = "Our Dream"
			text = ("Passe alto curvo (alcance %d): você escolhe onde a bola vai chegar. Ela pousa Suspensa nesse ponto na mesma rodada.\n"
				+ "Se o Nagi pegar a bola e usar o Fake Volley com um inimigo perto, nasce a Reação Química Miracle.\n"
				+ "Recarga: %d rodadas.") % [int(dream_range), dream_cooldown]
			if dream_only_when_reaction_ready and _miracle_rounds_left() > 0:
				text += "\nReação Miracle em recarga: %d rodada(s)." % _miracle_rounds_left()
		_:
			return {}
	var icon: Texture2D = skill_icons.get(String(skill_id), skill_icons.get(skill_id)) as Texture2D
	return {"title": title, "description": text, "icon": icon}

func reset_for_new_match() -> void:
	super()
	_panther_ready = false
	_aiming_curve = false
	_drop_ghost()
	last_our_dream = {}
	range_preview = 0.0

func _physics_process(delta: float) -> void:
	super(delta)
	if _ghost_busy:
		_sync_reo_from_ghost()

func _process(delta: float) -> void:
	super(delta)
	if _aura:
		_aura.position = Vector2(0.0, -height - 4.0)
	if _burst:
		_burst.position = Vector2(0.0, -height - 4.0)
	if _face:
		_face.position = _face_center()

func _face_center() -> Vector2:
	return Vector2(0.0, -height - placeholder_radius - face_offset)

func _draw() -> void:
	super()
	if is_aiming and _aiming_curve:
		var ball := _get_ball()
		if ball:
			var dt := 1.0 / 60.0
			var pos := to_local(ball.global_position)
			var dir := aim_direction
			var speed := 1.5 * kick_force_volley * kick_force_to_speed
			var turn_per_sec := deg_to_rad(PANTHER_TURN_DEG) / PANTHER_CURVE_TIME
			var drag := maxf(0.0, 1.0 - ball.air_drag * dt)
			var travelled := 0.0
			var steps := 0
			
			while steps < 240 and travelled < 600.0 and speed > 20.0:
				var seg: Vector2 = dir * speed * dt
				if steps % 2 == 0:
					draw_line(pos, pos + seg, Color(0.65, 0.3, 0.95, 0.9), 3.0)
				pos += seg
				travelled += seg.length()
				if float(steps) * dt < PANTHER_CURVE_TIME:
					dir = dir.rotated(turn_per_sec * dt)
				speed *= drag
				steps += 1
