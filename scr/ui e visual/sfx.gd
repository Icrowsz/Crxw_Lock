class_name Sfx
extends Node
## Efeitos sonoros do jogo. NÃO precisa de Autoload nem de cena: a primeira chamada de
## Sfx.ensure() / Sfx.play(...) cria sozinho um nó "Sfx" na raiz do jogo.
##
## Uso em qualquer script:   Sfx.play(&"kick")      Sfx.play(&"bounce", 0.5)   (0.5 = metade do volume)
##
## Eventos: run, jump, slide, kick, pass, keeper_dive, keeper_catch, bounce, ui_hover, ui_click
##
## Como ele acha o arquivo de cada evento (pasta res://zaudios/, .wav / .ogg / .mp3):
##  1. Se o evento estiver na tabela FILES abaixo, usa exatamente esse(s) arquivo(s).
##  2. Senão procura pelo NOME do arquivo (sem diferenciar maiúsculas/acentos) usando as
##     palavras da tabela KEYWORDS. Se vários arquivos casarem (chute1, chute2, chute3),
##     sorteia um a cada vez, e o tom varia um pouquinho, então não fica repetitivo.
## Os eventos que não acharem nenhum arquivo ficam em silêncio e avisam no painel "Saída" do
## Godot (com a lista de arquivos da pasta), é só escrever o nome certo na tabela FILES.

const FOLDER: String = "res://video/zaudios/"
const BUS: StringName = &"Master"
const POOL_SIZE: int = 10   # quantos sons podem tocar ao mesmo tempo

## Escreva aqui o arquivo exato quando o nome automático não acertar. Exemplos:
##   &"kick": "chute_forte.wav",
##   &"run": ["passo1.ogg", "passo2.ogg"],
const FILES: Dictionary = {
}

## A ORDEM importa: quando dois eventos casariam com o mesmo arquivo, o primeiro da lista fica com ele
const EVENT_ORDER: Array[StringName] = [
	&"keeper_dive", &"keeper_catch", &"run", &"jump", &"slide",
	&"kick", &"pass", &"bounce", &"ui_hover", &"ui_click",
]

## Pedaços do nome do arquivo (minúsculos e sem acento) que identificam cada evento
const KEYWORDS: Dictionary = {
	&"keeper_dive": ["goleiro_pul", "keeper_dive", "gk_dive", "mergulho", "dive"],
	&"keeper_catch": ["agarr", "keeper_catch", "gk_catch", "defesa", "catch"],
	&"run": ["corr", "run", "passos", "step", "foot"],
	&"jump": ["pul", "jump", "salt"],
	&"slide": ["carrinho", "slide", "tackle", "desliz"],
	&"kick": ["chut", "kick", "shoot", "shot"],
	&"pass": ["pass", "toque"],
	&"bounce": ["quic", "bounce", "cai", "drop", "land"],
	&"ui_hover": ["hover", "mouse", "over"],
	&"ui_click": ["click", "clique", "botao", "button", "press", "select"],
}

static var _inst: Sfx = null

var _streams: Dictionary = {}   # evento -> Array[AudioStream]
var _pool: Array[AudioStreamPlayer] = []
var _next_voice: int = 0


## Garante que o nó de sons existe. Chame no _ready de quem usa sons (é barato).
static func ensure() -> void:
	if _inst != null and is_instance_valid(_inst):
		return
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	_inst = Sfx.new()
	_inst.name = "Sfx"
	tree.root.add_child.call_deferred(_inst)   # deferred: a raiz pode estar ocupada montando a cena


## Toca o evento. strength: 0 a 1 (vira volume). pitch_jitter: variação aleatória do tom.
static func play(event: StringName, strength: float = 1.0, pitch_jitter: float = 0.05) -> void:
	if _inst == null or not is_instance_valid(_inst) or not _inst.is_inside_tree():
		ensure()   # ainda não existe: cria agora (este primeiro som é perdido)
		return
	_inst._play(event, strength, pitch_jitter)


## Sorteia um som do evento (null se não houver). Usado para sons em laço, como o de correr.
static func pick(event: StringName) -> AudioStream:
	if _inst == null or not is_instance_valid(_inst):
		ensure()
		return null
	var list: Array = _inst._streams.get(event, [])
	if list.is_empty():
		return null
	return list[randi() % list.size()]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # os sons da UI tocam até com o jogo pausado
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = BUS
		add_child(p)
		_pool.append(p)
	_load_streams()


func _play(event: StringName, strength: float, pitch_jitter: float) -> void:
	var list: Array = _streams.get(event, [])
	if list.is_empty():
		return
	var voice: AudioStreamPlayer = _free_voice()
	voice.stream = list[randi() % list.size()]
	voice.volume_db = linear_to_db(clampf(strength, 0.05, 1.0))
	voice.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	voice.play()


## Uma voz parada; se todas estiverem tocando, rouba a mais antiga
func _free_voice() -> AudioStreamPlayer:
	for p in _pool:
		if not p.playing:
			return p
	var stolen: AudioStreamPlayer = _pool[_next_voice]
	_next_voice = (_next_voice + 1) % _pool.size()
	return stolen


func _load_streams() -> void:
	var names: Array[String] = _list_files()
	if names.is_empty():
		push_warning("Sfx: nenhum arquivo de áudio em %s" % FOLDER)
		return
	var claimed: Dictionary = {}
	var missing: PackedStringArray = []
	for event: StringName in EVENT_ORDER:
		var found: Array[String] = []
		# 1) arquivo(s) escrito(s) à mão na tabela FILES
		var manual: Variant = FILES.get(event, "")
		if manual is String and String(manual) != "":
			found.append(String(manual))
		elif manual is Array:
			for f in manual:
				found.append(String(f))
		# 2) senão, procura pelas palavras no nome do arquivo
		if found.is_empty():
			for keyword in KEYWORDS.get(event, []):
				for n in names:
					if not claimed.has(n) and _normalize(n).contains(String(keyword)):
						found.append(n)
				if not found.is_empty():
					break
		var list: Array[AudioStream] = []
		for n in found:
			claimed[n] = true
			var res: Resource = load(FOLDER + n)
			if res is AudioStream:
				list.append(res)
		if list.is_empty():
			missing.append(String(event))
		else:
			_streams[event] = list
	if not missing.is_empty():
		push_warning("Sfx: sem som para [%s]. Arquivos em %s: %s. Escreva o nome certo na tabela FILES do sfx.gd." % [
			", ".join(missing), FOLDER, ", ".join(names)])


## Lista os áudios da pasta. No jogo exportado o Godot só enxerga "arquivo.wav.import" / ".remap"
## (e no editor enxerga os dois), então tira o sufixo e tira repetidos.
func _list_files() -> Array[String]:
	var out: Array[String] = []
	for f in DirAccess.get_files_at(FOLDER):
		var n: String = f
		if n.ends_with(".import"):
			n = n.trim_suffix(".import")
		elif n.ends_with(".remap"):
			n = n.trim_suffix(".remap")
		if n.get_extension().to_lower() in ["wav", "ogg", "mp3"] and not out.has(n):
			out.append(n)
	out.sort()
	return out


func _normalize(file_name: String) -> String:
	var s: String = file_name.get_basename().to_lower()
	for pair in [["á", "a"], ["à", "a"], ["â", "a"], ["ã", "a"], ["é", "e"], ["ê", "e"],
			["í", "i"], ["ó", "o"], ["ô", "o"], ["õ", "o"], ["ú", "u"], ["ç", "c"], [" ", "_"], ["-", "_"]]:
		s = s.replace(pair[0], pair[1])
	return s
