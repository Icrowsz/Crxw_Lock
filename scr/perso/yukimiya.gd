class_name Yukimiya
extends Player

const SKILL_SHOT: StringName = &"shot"
const SKILL_DRIBBLE: StringName = &"dribble"
const SKILL_PREDATOR: StringName = &"predator"
const SKILL_STREET: StringName = &"street_mode"

const CD_SHOT: StringName = &"cd_shot"
const CD_DRIBBLE: StringName = &"cd_dribble"
const CD_PREDATOR: StringName = &"cd_predator"
const CD_STREET: StringName = &"cd_street"

enum Mode { EMPEROR, SLICED }
enum ShotVariant { NONE, GYRO, PACIFIST, SWORD }
enum DribbleVariant { NONE, DRAG_SCISSORS, RAZOR_BREAK, LANE_SPLITTER }
enum Preview { NONE, SHOT }

@export_group("Modos")
@export var mode: Mode = Mode.EMPEROR
@export var street_switches_max: int = 2
@export var street_cooldown: int = 2

@export_group("Chutes")
@export var shot_cooldown: int = 2
@export_range(0.0, 1.0) var chance_emperor: float = 0.40
@export_range(0.0, 1.0) var chance_sliced: float = 0.45
@export var force_mult: float = 1.2
@export var screw_speed_mult: float = 0.7
@export var screw_leg_time: float = 0.4

@export_group("Dribles (Drag Scissors)")
@export var dribble_cooldown: int = 2
@export var drag_distance: float = 150.0
@export var razor_distance: float = 300.0
@export var lane_distance: float = 200.0

@export_group("Predator")
@export var predator_rounds: int = 3
@export var predator_cooldown: int = 2
@export var predator_bonus: float = 0.03
@export var predator_shots: int = 3
@export var predator_pass_bonus: float = 50.0

@export_group("Trajetória do chute")
@export var show_trajectory: bool = true
@export var trajectory_length: float = 650.0

var _mode_switches_left: int
var _predator_until_round: int = -1
var _predator_shots_left: int = 0
var _pass_buff_applied: float = 0.0

var _preview: Preview = Preview.NONE
var _gyro_plan: Array = []
var _held_ball: Ball = null
var _base_run: float = 0.0

func _init() -> void:
	character_id = "yukimiya"
	display_name = "Yukimiya"

func _ready() -> void:
	super()
	_mode_switches_left = street_switches_max
	_base_run = run_duration
	_hook_manager.call_deferred()

func _hook_manager() -> void:
	var m := _get_manager()
	if m:
		m.turn_started.connect(_on_turn_started)

func _on_turn_started(turn_team: int) -> void:
	if _predator_until_round >= 0 and _get_manager().round_number > _predator_until_round:
		_end_predator()

func _end_predator() -> void:
	_predator_until_round = -1
	_predator_shots_left = 0
	pass_range_bonus -= _pass_buff_applied
	_pass_buff_applied = 0.0
	queue_redraw()

func is_predator_active() -> bool:
	var m := _get_manager()
	return m != null and _predator_until_round >= 0 and m.round_number <= _predator_until_round

func _shot_bonus() -> float:
	if is_predator_active() and _predator_shots_left > 0:
		return predator_bonus
	return 0.0

func get_shot_chance(kind: KickType) -> float:
	return minf(super(kind) + _shot_bonus(), 1.0)

func kick_ball(ball: Ball, direction: Vector2, kind: KickType, qte_success: bool = true,
		chance_override: float = -1.0, ignore_self_collision: bool = false,
		fx: KickFX = null, anim: StringName = &"", on_kick: Callable = Callable()) -> void:
	if is_predator_active() and _predator_shots_left > 0:
		_predator_shots_left -= 1
		queue_redraw()
	await super(ball, direction, kind, qte_success, chance_override, ignore_self_collision, fx, anim, on_kick)

# ---------- HABILIDADE 1: CHUTE ----------

func get_shot_variant() -> ShotVariant:
	var ball := _get_ball()
	if get_kick_type(ball) == KickType.NONE: return ShotVariant.NONE
	
	if height_level == Heights.Level.SUSPENDED:
		var lvl := ball.get_level()
		if lvl == Heights.Level.GROUND or lvl == Heights.Level.SUSPENDED:
			return ShotVariant.SWORD
			
	if height_level == Heights.Level.GROUND and ball.get_level() == Heights.Level.GROUND:
		return ShotVariant.GYRO if mode == Mode.EMPEROR else ShotVariant.PACIFIST
	return ShotVariant.NONE

func _shot_skill_name() -> String:
	match get_shot_variant():
		ShotVariant.GYRO: return "Gyro Shot"
		ShotVariant.PACIFIST: return "Pacifist Shot"
		ShotVariant.SWORD: return "Sword Screw"
	return "Chute"

func _trajectory_data() -> Dictionary:
	var ball := _get_ball()
	if ball == null or _preview == Preview.NONE: return {}
	var dir := aim_direction.normalized()
	
	if get_shot_variant() == ShotVariant.SWORD:
		return _screw_trajectory(ball, dir)
		
	var launch := BallPathPreview.launch_for(self, ball, KickType.VOLLEY)
	var curves := []
	if get_shot_variant() == ShotVariant.GYRO:
		curves = _gyro_plan
	else:
		curves = [deg_to_rad(30.0)]
		
	return BallPathPreview.simulate(ball, ball.global_position, ball.height, dir * float(launch["speed"]), float(launch["lift"]), curves, 0.4, false, trajectory_length)

func _screw_trajectory(ball: Ball, dir: Vector2) -> Dictionary:
	var speed := kick_force_volley * kick_force_to_speed * screw_speed_mult
	var waypoints := [Heights.FLYING_HEIGHT, Heights.GROUND_HEIGHT, Heights.SUSPENDED_HEIGHT]
	var step := 1.0 / 60.0
	var pos := ball.global_position
	var h := ball.height
	var points: Array[Vector2] = [pos]
	var heights: Array[float] = [h]
	var length := 0.0
	var frame := 0
	for target_h in waypoints:
		var start_h := h
		var t := 0.0
		while t < screw_leg_time and length < trajectory_length:
			t += step
			var k := clampf(t / screw_leg_time, 0.0, 1.0)
			h = lerpf(start_h, target_h, sin(k * PI * 0.5))
			pos += dir * speed * step
			length += speed * step
			frame += 1
			if frame % 3 == 0:
				points.append(pos)
				heights.append(h)
	return {"points": points, "heights": heights, "bounces": []}

func _use_shot() -> bool:
	var m := _get_manager()
	if m == null or get_shot_variant() == ShotVariant.NONE: return false

	_preview = Preview.SHOT
	if get_shot_variant() == ShotVariant.GYRO:
		_gyro_plan = []
		var side := 1.0 if randf() < 0.5 else -1.0
		for i in randi_range(2, 3):
			_gyro_plan.append(deg_to_rad(randf_range(40.0, 70.0)) * side)
			side = -side
			
	var aim := await m.aim_for_skill(self, kick_aim_range)
	_preview = Preview.NONE
	queue_redraw()
	if aim == Vector2.ZERO: return false
	
	var ball := _get_ball()
	var variant := get_shot_variant()
	if variant == ShotVariant.NONE: return false

	YukimiyaFX.burst(self, ball.global_position + Vector2(0, -ball.height), true)
	YukimiyaFX.trail_ball(ball, 1.0)

	match variant:
		ShotVariant.GYRO:
			next_kick_force_mult *= force_mult
			volley_peak_level = Heights.Level.FLYING 
			await kick_ball(ball, aim, KickType.VOLLEY, true, chance_emperor)
			_apply_curves(ball, _gyro_plan, 0.4)
		ShotVariant.PACIFIST:
			next_kick_force_mult *= force_mult
			volley_peak_level = Heights.Level.FLYING
			await kick_ball(ball, aim, KickType.VOLLEY, true, chance_sliced)
			_apply_curves(ball, [deg_to_rad(30.0)], 0.5)
		ShotVariant.SWORD:
			next_kick_force_mult *= force_mult
			await kick_ball(ball, aim, KickType.VOLLEY, true, chance_sliced)
			_screw_ball(ball, aim)
			
	volley_peak_level = Heights.Level.SUSPENDED
	start_cooldown(CD_SHOT, shot_cooldown)
	return true

func _apply_curves(ball: Ball, plan: Array, duration: float) -> void:
	for curve in plan:
		var rate := float(curve) / duration
		var elapsed := 0.0
		var touches := ball.interaction_count
		while elapsed < duration:
			await get_tree().physics_frame
			var dt := get_physics_process_delta_time()
			elapsed += dt
			if not is_instance_valid(ball) or ball.interaction_count != touches or ball.hovering or ball.is_held():
				return
			ball.velocity = ball.velocity.rotated(rate * dt)

func _screw_ball(ball: Ball, dir: Vector2) -> void:
	var speed := kick_force_volley * kick_force_to_speed * screw_speed_mult
	ball.velocity = Vector2.ZERO
	ball.vel_z = 0.0
	ball.hovering = true
	ball.trail_enabled = true
	
	var waypoints := [Heights.FLYING_HEIGHT, Heights.GROUND_HEIGHT, Heights.SUSPENDED_HEIGHT]
	for target_h in waypoints:
		var start_h := ball.height
		var t := 0.0
		while t < screw_leg_time:
			await get_tree().physics_frame
			if not is_instance_valid(ball) or not ball.hovering: return
			t += get_physics_process_delta_time()
			var k := clampf(t / screw_leg_time, 0.0, 1.0)
			ball.height = lerpf(start_h, target_h, sin(k * PI * 0.5))
			ball.global_position += dir.normalized() * speed * get_physics_process_delta_time()
			
	ball.release_hover()
	ball.velocity = dir.normalized() * speed * 0.5

# ---------- HABILIDADE 2: DRIBLE ----------

func get_dribble_variant() -> DribbleVariant:
	var ball := _get_ball()
	var near := ball != null and not ball.is_held() and global_position.distance_to(ball.global_position) <= kick_range
	if height_level != Heights.Level.GROUND: return DribbleVariant.NONE
	
	if mode == Mode.EMPEROR and near: return DribbleVariant.DRAG_SCISSORS
	elif mode == Mode.SLICED:
		if near: return DribbleVariant.RAZOR_BREAK
		else: return DribbleVariant.LANE_SPLITTER
	return DribbleVariant.NONE

func _dribble_skill_name() -> String:
	match get_dribble_variant():
		DribbleVariant.DRAG_SCISSORS: return "Drag Scissors"
		DribbleVariant.RAZOR_BREAK: return "Razor Break"
		DribbleVariant.LANE_SPLITTER: return "Lane Splitter"
	return "Drible"

func _use_dribble() -> bool:
	var m := _get_manager()
	if m == null: return false
	
	var variant := get_dribble_variant()
	if variant == DribbleVariant.NONE: return false

	start_cooldown(CD_DRIBBLE, dribble_cooldown)
	
	match variant:
		DribbleVariant.DRAG_SCISSORS:
			var target := _nearest_enemy()
			var away := (global_position - target.global_position).normalized() if target else Vector2(facing, 0)
			_grab_ball()
			await _dash(away, drag_distance)
			
			var dashes := 3 + (1 if is_predator_active() else 0)
			for i in dashes:
				var aim := await m.aim_for_skill(self, 200.0)
				if aim == Vector2.ZERO: break
				await _dash(aim.normalized(), 200.0)
		
		DribbleVariant.RAZOR_BREAK:
			var aim := await m.aim_for_skill(self, 300.0)
			if aim == Vector2.ZERO: return false
			_grab_ball()
			var dir := aim.normalized()
			var dist := razor_distance + (50.0 if is_predator_active() else 0.0)
			await _dash(dir.rotated(0.5), dist * 0.33)
			await _dash(dir.rotated(-0.5), dist * 0.33)
			await _dash(dir.rotated(0.5), dist * 0.33)
			
		DribbleVariant.LANE_SPLITTER:
			var aim := await m.aim_for_skill(self, 200.0)
			if aim == Vector2.ZERO: return false
			var dir := aim.normalized()
			var dist := lane_distance + (50.0 if is_predator_active() else 0.0)
			await _dash(dir, dist * 0.5)
			await _dash(dir, dist * 0.5)
			
			var ball := _get_ball()
			if ball and global_position.distance_to(ball.global_position) <= kick_range:
				_grab_ball()
				var qte := await m.run_qte(KickType.GROUND)
				if qte: extra_skill_left += 1

	_release_ball()
	return true

func _nearest_enemy() -> Player:
	var best: Player = null
	var min_d := INF
	for p in get_tree().get_nodes_in_group("players"):
		if p.team != team:
			var d := global_position.distance_to(p.global_position)
			if d < min_d: min_d = d; best = p
	return best

func _dash(dir: Vector2, distance: float) -> void:
	var target := _clamp_to_field(global_position + dir * distance)
	var trail := YukimiyaFX.begin_trail(self)
	
	var duration := distance / 800.0
	var start_pos := global_position
	var elapsed := 0.0
	
	while elapsed < duration:
		await get_tree().physics_frame
		elapsed += get_physics_process_delta_time()
		global_position = start_pos.lerp(target, minf(elapsed / duration, 1.0))
		trail.add(global_position)
		if _held_ball and is_instance_valid(_held_ball):
			_held_ball.global_position = global_position + Vector2(facing * (body_radius + 20), 0)
			_held_ball.height = 0.0
			
	trail.finish()

func _clamp_to_field(pos: Vector2) -> Vector2:
	var field := get_tree().get_first_node_in_group("field") as Field
	if not field: return pos
	var half := field.pitch_size * 0.5 - Vector2(body_radius, body_radius)
	var l := field.to_local(pos)
	return field.to_global(Vector2(clampf(l.x, -half.x, half.x), clampf(l.y, -half.y, half.y)))

func _grab_ball() -> void:
	var ball := _get_ball()
	if ball:
		ball.register_touch(self)
		ball.held_by = self
		_held_ball = ball

func _release_ball() -> void:
	if _held_ball and is_instance_valid(_held_ball):
		_held_ball.held_by = null
		_held_ball = null

func _physics_process(delta: float) -> void:
	super(delta)
	if _held_ball and is_instance_valid(_held_ball) and _held_ball.held_by == self:
		_held_ball.global_position = global_position + Vector2(facing * (body_radius + 20), 0)
		_held_ball.height = 0.0

# ---------- HABILIDADE 3: PREDATOR ----------

func _use_predator() -> bool:
	var m := _get_manager()
	if m == null: return false
	
	_predator_until_round = m.round_number + predator_rounds
	_predator_shots_left = predator_shots
	extra_general_left += 1
	
	_pass_buff_applied = predator_pass_bonus
	pass_range_bonus += _pass_buff_applied
	
	start_cooldown(CD_PREDATOR, predator_cooldown, _predator_until_round + 1)
	YukimiyaFX.burst(self, global_position + Vector2(0, -height), true)
	queue_redraw()
	return true

# ---------- HABILIDADE 4: STREET MODE ----------

func _use_street() -> bool:
	if _mode_switches_left <= 0: return false
	
	mode = Mode.SLICED if mode == Mode.EMPEROR else Mode.EMPEROR
	_mode_switches_left -= 1
	
	if _mode_switches_left == 0:
		start_cooldown(CD_STREET, street_cooldown)
		
	YukimiyaFX.burst(self, global_position + Vector2(0, -height))
	queue_redraw()
	return true

func skill_is_free(skill_id: StringName) -> bool:
	return skill_id == SKILL_STREET

# ---------- SISTEMA DE HABILIDADES ----------

func get_skills() -> Array[Dictionary]:
	var mode_name := "Emperor" if mode == Mode.EMPEROR else "Sliced"
	return [
		{"id": SKILL_SHOT, "name": skill_label(_shot_skill_name(), CD_SHOT)},
		{"id": SKILL_DRIBBLE, "name": skill_label(_dribble_skill_name(), CD_DRIBBLE)},
		{"id": SKILL_PREDATOR, "name": "Predator (ativo)" if is_predator_active() else skill_label("Predator", CD_PREDATOR)},
		{"id": SKILL_STREET, "name": "Street Mode (%s)" % mode_name if _mode_switches_left > 0 else skill_label("Street Mode", CD_STREET)},
	]

func can_use_skill(skill_id: StringName = &"default") -> bool:
	if not super(skill_id): return false
	match skill_id:
		SKILL_SHOT: return not is_on_cooldown(CD_SHOT) and get_shot_variant() != ShotVariant.NONE
		SKILL_DRIBBLE: return not is_on_cooldown(CD_DRIBBLE) and get_dribble_variant() != DribbleVariant.NONE
		SKILL_PREDATOR: return not is_predator_active() and not is_on_cooldown(CD_PREDATOR)
		SKILL_STREET: 
			if _mode_switches_left > 0: return true
			return not is_on_cooldown(CD_STREET)
	return false

func use_skill(skill_id: StringName = &"default") -> bool:
	match skill_id:
		SKILL_SHOT: return await _use_shot()
		SKILL_DRIBBLE: return await _use_dribble()
		SKILL_PREDATOR: return await _use_predator()
		SKILL_STREET: return await _use_street()
	return false

func _draw() -> void:
	super()
	if show_trajectory and is_aiming and _preview == Preview.SHOT:
		var data := _trajectory_data()
		if not data.is_empty():
			var color := Color(0.9, 0.2, 0.2) if mode == Mode.EMPEROR else Color(0.6, 0.1, 0.9)
			BallPathPreview.draw(self, data, color)
			
	if is_predator_active():
		var center := Vector2(0.0, -height)
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.01)
		draw_arc(center, placeholder_radius + 10.0 + pulse * 4.0, 0.0, TAU, 32, Color(1.0, 0.3, 0.0, 0.8), 3.0)
		draw_arc(center, placeholder_radius + 15.0, 0.0, TAU, 32, Color(0.6, 0.15, 0.85, 0.6), 2.0)
		for i in 3:
			var a = Time.get_ticks_msec() * 0.002 + i * TAU / 3.0
			var pos = center + Vector2(cos(a), sin(a)) * (placeholder_radius + 18.0)
			draw_rect(Rect2(pos - Vector2(3,3), Vector2(6,6)), Color(0.85, 0.5, 1.0, 0.9))

func reset_for_new_match() -> void:
	super()
	_mode_switches_left = street_switches_max
	_end_predator()
	_release_ball()
	_preview = Preview.NONE
