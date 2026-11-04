class_name RhythmGame
extends CanvasLayer
## 4-Key Rhythm Game: minigame de ritmo de 4 teclas (D F J K), tudo desenhado por código.
## Notas caem em 4 colunas; aperte a tecla da coluna quando a nota chegar na linha. Acertar pelo menos
## pass_ratio das notas = vitória. Usado nas habilidades (ex: Dance Battle / Breakdance do Kiyora).
##
## Uso (dentro de uma coroutine):
##   var game := RhythmGame.new()
##   get_tree().current_scene.add_child(game)     # qualquer nó na árvore serve
##   game.start("Ritmo!")
##   var ok: bool = await game.finished            # true = passou
##
## Opcional, para os outros personagens usarem sem criar o nó na mão (cole no match_manager.gd,
## perto de run_qte):
##   func run_rhythm_game(title: String = "Ritmo!") -> bool:
##       var game := RhythmGame.new()
##       add_child(game)
##       game.start(title)
##       return await game.finished
##
## As teclas são consumidas (set_input_as_handled) enquanto o jogo está aberto, então D/F/J/K não
## movem ninguém nem disparam outros atalhos.

signal finished(success: bool)

const KEYS: Array[Key] = [KEY_W, KEY_A, KEY_S, KEY_D]
const LABELS: Array[String] = ["W", "A", "S", "D"]
const LANE_COLORS: Array[Color] = [Color(0.28, 0.68, 0.64), Color(0.45, 0.82, 0.78),
	Color(0.45, 0.82, 0.78), Color(0.28, 0.68, 0.64)]

@export var note_count: int = 12
@export var beat_interval: float = 0.7            # tempo entre notas (s)
@export var fall_time: float = 1.1                 # quanto a nota leva do topo até a linha (s)
@export var hit_window: float = 0.16               # erro máximo (s) para contar o acerto
@export var perfect_window: float = 0.06           # erro máximo (s) para PERFECT
@export_range(0.0, 1.0) var pass_ratio: float = 0.7   # fração de acertos para vencer
@export var layer_index: int = 100

var _title: String = "Ritmo!"
var _notes: Array[Dictionary] = []     # {lane, time, state}: state 0 = pendente, 1 = acertou, 2 = errou
var _elapsed: float = 0.0
var _running: bool = false
var _hits: int = 0
var _misses: int = 0
var _flash: Array[float] = [0.0, 0.0, 0.0, 0.0]   # brilho de cada coluna ao apertar
var _feedback: String = ""
var _feedback_time: float = 0.0
var _result: int = 0                   # 0 = jogando, 1 = passou, 2 = perdeu
var _board: Board


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # funciona mesmo se o jogo estiver pausado


## Começa o jogo. Sorteia as colunas (sem repetir a mesma 3 vezes seguidas).
func start(title: String = "Ritmo!", count: int = -1) -> void:
	_title = title
	if count > 0:
		note_count = count
	layer = layer_index
	_board = Board.new()
	_board.game = self
	_board.set_anchors_preset(Control.PRESET_FULL_RECT)
	_board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_board)

	var lead: float = fall_time + 0.5
	var last_lane: int = -1
	var repeats: int = 0
	for i in note_count:
		var lane: int = randi() % 4
		if lane == last_lane:
			repeats += 1
			if repeats >= 2:
				lane = (lane + 1 + randi() % 3) % 4
				repeats = 0
		else:
			repeats = 0
		last_lane = lane
		_notes.append({"lane": lane, "time": lead + float(i) * beat_interval, "state": 0})
	_elapsed = 0.0
	_running = true


func needed_hits() -> int:
	return int(ceil(float(note_count) * pass_ratio))


func _process(delta: float) -> void:
	for i in 4:
		_flash[i] = maxf(0.0, _flash[i] - delta * 5.0)
	_feedback_time = maxf(0.0, _feedback_time - delta)
	if _board != null:
		_board.queue_redraw()
	if not _running:
		return
	_elapsed += delta
	for n in _notes:
		if int(n["state"]) == 0 and _elapsed - float(n["time"]) > hit_window:
			n["state"] = 2
			_misses += 1
			_say("MISS")
	# Acabou: todas resolvidas
	var all_done: bool = true
	for n in _notes:
		if int(n["state"]) == 0:
			all_done = false
			break
	if all_done:
		_finish()


func _input(event: InputEvent) -> void:
	if not _running:
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	var lane: int = KEYS.find(key.keycode)
	if lane < 0:
		lane = KEYS.find(key.physical_keycode)
	if lane < 0:
		return
	get_viewport().set_input_as_handled()
	_flash[lane] = 1.0
	# A nota pendente mais próxima da linha nessa coluna
	var best: Dictionary = {}
	var best_err: float = hit_window
	for n in _notes:
		if int(n["state"]) != 0 or int(n["lane"]) != lane:
			continue
		var err: float = absf(_elapsed - float(n["time"]))
		if err <= best_err:
			best = n
			best_err = err
	if best.is_empty():
		return
	best["state"] = 1
	_hits += 1
	_say("PERFECT" if best_err <= perfect_window else "GOOD")


func _say(text: String) -> void:
	_feedback = text
	_feedback_time = 0.5


func _finish() -> void:
	if not _running:
		return
	_running = false
	var ok: bool = _hits >= needed_hits()
	_result = 1 if ok else 2
	_feedback = "PASSOU!" if ok else "PERDEU!"
	_feedback_time = 1.0
	await get_tree().create_timer(0.7).timeout
	finished.emit(ok)
	queue_free()


## Se o nó for apagado no meio (ex: partida reiniciou), quem espera recebe "perdeu" em vez de ficar pendurado
func _exit_tree() -> void:
	if _running:
		_running = false
		finished.emit(false)


## Desenho do jogo (um Control por cima de tudo)
class Board extends Control:
	var game: RhythmGame
	const LANE_W: float = 92.0
	const TRAVEL: float = 360.0

	func _draw() -> void:
		if game == null:
			return
		var size_v: Vector2 = get_viewport_rect().size
		var font: Font = ThemeDB.fallback_font
		var cx: float = size_v.x * 0.5
		var hit_y: float = size_v.y * 0.5 + 190.0
		var top_y: float = hit_y - TRAVEL
		var left: float = cx - LANE_W * 2.0

		draw_rect(Rect2(Vector2.ZERO, size_v), Color(0.0, 0.0, 0.0, 0.45))               # escurece o fundo
		draw_rect(Rect2(left - 12.0, top_y - 70.0, LANE_W * 4.0 + 24.0, TRAVEL + 150.0),
			Color(0.04, 0.12, 0.15, 0.92))                                                 # painel
		draw_string(font, Vector2(left, top_y - 36.0), game._title, HORIZONTAL_ALIGNMENT_CENTER, LANE_W * 4.0, 30,
			Color(0.78, 0.98, 0.92))
		draw_string(font, Vector2(left, top_y - 10.0), "%d / %d acertos" % [game._hits, game.needed_hits()],
			HORIZONTAL_ALIGNMENT_CENTER, LANE_W * 4.0, 18, Color(0.28, 0.68, 0.64))

		for i in 4:
			var x: float = left + LANE_W * float(i)
			draw_rect(Rect2(x + 2.0, top_y, LANE_W - 4.0, TRAVEL), Color(1, 1, 1, 0.04 + 0.12 * game._flash[i]))
			# alvo na linha de acerto
			var target := Rect2(x + 8.0, hit_y - 14.0, LANE_W - 16.0, 28.0)
			draw_rect(target, Color(RhythmGame.LANE_COLORS[i], 0.25 + 0.6 * game._flash[i]))
			draw_rect(target, Color(0.78, 0.98, 0.92, 0.9), false, 2.0)
			draw_string(font, Vector2(x, hit_y + 46.0), RhythmGame.LABELS[i], HORIZONTAL_ALIGNMENT_CENTER, LANE_W, 26,
				Color(0.78, 0.98, 0.92))

		# notas
		for n in game._notes:
			if int(n["state"]) != 0:
				continue
			var t_left: float = float(n["time"]) - game._elapsed   # tempo até chegar na linha
			var y: float = hit_y - t_left / game.fall_time * TRAVEL
			if y < top_y - 20.0 or y > hit_y + 60.0:
				continue
			var lane: int = int(n["lane"])
			var x: float = left + LANE_W * float(lane)
			draw_rect(Rect2(x + 10.0, y - 12.0, LANE_W - 20.0, 24.0), RhythmGame.LANE_COLORS[lane])
			draw_rect(Rect2(x + 10.0, y - 12.0, LANE_W - 20.0, 24.0), Color(0.9, 1.0, 0.97), false, 2.0)

		if game._feedback_time > 0.0:
			var col := Color(0.78, 0.98, 0.92, clampf(game._feedback_time * 2.0, 0.0, 1.0))
			if game._result == 2 or game._feedback == "MISS":
				col = Color(1.0, 0.55, 0.55, col.a)
			draw_string(font, Vector2(left, hit_y - 60.0), game._feedback, HORIZONTAL_ALIGNMENT_CENTER, LANE_W * 4.0, 34, col)
