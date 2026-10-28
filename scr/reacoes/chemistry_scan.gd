class_name ChemistryScan
extends RefCounted
## Descobre SOZINHO quais Reações Químicas existem e quais pares de personagens do mesmo time
## ativam uma delas. Você não precisa editar nada ao criar uma reação nova:
##   1. Reações já registradas no ReactionManager (se existir na cena) entram na lista;
##   2. Além disso, todo script do projeto que "extends ChemicalReaction" é achado e lido
##      (trigger_id / partner_id / nome / cor vêm do próprio _init dele).
## Usado pela tela de formação (formation_extras.gd) para mostrar o indicador de química.

## Pastas varridas atrás de reações (subpastas incluídas)
static var scan_dirs: Array[String] = ["res://"]
static var _cache: Array[ChemicalReaction] = []
static var _scanned: bool = false


## Todas as reações conhecidas (sem repetir o id)
static func all(from: Node = null) -> Array[ChemicalReaction]:
	if not _scanned:
		_scanned = true
		var base: Script = ChemicalReaction
		for dir in scan_dirs:
			_scan_dir(dir, base)
	var list: Array[ChemicalReaction] = []
	var seen: Dictionary = {}
	if from != null:
		var rm: ReactionManager = ReactionManager.get_for(from)
		if rm != null:
			for r in rm.reactions:
				if r != null and not seen.has(r.id):
					seen[r.id] = true
					list.append(r)
	for r in _cache:
		if not seen.has(r.id):
			seen[r.id] = true
			list.append(r)
	return list


## Esquece a varredura (se criar reações com o jogo aberto)
static func rescan() -> void:
	_cache.clear()
	_scanned = false


## Pares ativos entre os jogadores dados (um time): [{reaction, trigger: Player, partner: Player}]
static func pairs_in(players: Array, from: Node = null) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for r in all(from):
		var trig: Node = null
		var part: Node = null
		for p in players:
			if not is_instance_valid(p):
				continue
			var cid: String = String(p.get("character_id"))
			if trig == null and cid == r.trigger_id:
				trig = p
			elif part == null and cid == r.partner_id:
				part = p
		if trig != null and part != null:
			out.append({"reaction": r, "trigger": trig, "partner": part})
	return out


static func _scan_dir(path: String, base: Script) -> void:
	var d := DirAccess.open(path)
	if d == null:
		return
	for sub in d.get_directories():
		if sub.begins_with(".") or sub == "addons":
			continue
		_scan_dir(path.path_join(sub), base)
	for f in d.get_files():
		var file: String = f
		if file.ends_with(".remap"):
			file = file.trim_suffix(".remap")   # projeto exportado
		if not (file.ends_with(".gd") or file.ends_with(".gdc")):
			continue
		var full: String = path.path_join(file.trim_suffix("c") if file.ends_with(".gdc") else file)
		# No editor dá para olhar o texto antes de carregar (mais rápido); exportado, o texto não existe
		var text: String = FileAccess.get_file_as_string(full)
		if text != "" and not text.contains("extends ChemicalReaction"):
			continue
		var s := load(full) as GDScript
		if s == null or s == base or not s.can_instantiate():
			continue
		var b: Script = s.get_base_script()
		var is_reaction: bool = false
		while b != null:
			if b == base:
				is_reaction = true
				break
			b = b.get_base_script()
		if not is_reaction:
			continue
		var r := s.new() as ChemicalReaction
		if r != null and r.trigger_id != "" and r.partner_id != "":
			_cache.append(r)
