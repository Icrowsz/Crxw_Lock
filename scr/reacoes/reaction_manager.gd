class_name ReactionManager
extends Node
## Gerencia as Reações Químicas: lista das reações existentes, recarga (por time) e a cutscene.
## Não precisa estar na cena: quem precisar chama ReactionManager.get_for(self), que cria o nó
## sozinho como filho do MatchManager (e ele some junto com a partida).
##
## COMO ADICIONAR UMA REAÇÃO NOVA
##  1. Crie um script que estende ChemicalReaction (copie o reaction_carnival.gd);
##  2. Registre-o em _register_reactions() aqui embaixo;
##  3. Na habilidade do personagem que EXECUTA o movimento, pergunte find_available(self) e,
##     se vier uma reação, chame await play(reação, self, parceiro) antes de fazer o movimento.

signal reaction_started(reaction: ChemicalReaction, trigger: Player, partner: Player)
signal reaction_finished(reaction: ChemicalReaction)

var reactions: Array[ChemicalReaction] = []

## "time:id" -> primeira rodada em que a reação volta a poder ser usada
var _cooldown_ready: Dictionary = {}


## Acha (ou cria) o gerenciador. "from" = qualquer nó que já esteja na árvore.
static func get_for(from: Node) -> ReactionManager:
	var tree: SceneTree = from.get_tree()
	var existing := tree.get_first_node_in_group("reaction_manager") as ReactionManager
	if existing != null:
		return existing
	var parent: Node = tree.get_first_node_in_group("match_manager")
	if parent == null:
		parent = tree.current_scene
	if parent == null:
		return null   # sem partida/cena ainda: quem chama trata o null
	var rm := ReactionManager.new()
	parent.add_child(rm)
	return rm


func _ready() -> void:
	add_to_group("reaction_manager")
	_register_reactions()
	# Partida nova (a formação recomeça): todas as recargas zeram
	var m := get_tree().get_first_node_in_group("match_manager") as MatchManager
	if m != null and not m.formation_started.is_connected(clear_cooldowns):
		m.formation_started.connect(clear_cooldowns)


func _register_reactions() -> void:
	register(ReactionCarnival.new())


func register(reaction: ChemicalReaction) -> void:
	reactions.append(reaction)


# ---------- RECARGA ----------

func _key(reaction: ChemicalReaction, team: int) -> String:
	return "%d:%s" % [team, reaction.id]


func _current_round() -> int:
	var m := get_tree().get_first_node_in_group("match_manager") as MatchManager
	return m.round_number if m != null else 0


## Quantas rodadas faltam para o time poder usar a reação de novo. 0 = disponível.
func rounds_left(reaction: ChemicalReaction, team: int) -> int:
	var key: String = _key(reaction, team)
	if not _cooldown_ready.has(key):
		return 0
	return maxi(0, int(_cooldown_ready[key]) - _current_round())


func is_ready(reaction: ChemicalReaction, team: int) -> bool:
	return rounds_left(reaction, team) <= 0


## Usou na rodada 5 com recarga 12 -> volta na rodada 17 (mesma regra das habilidades)
func start_cooldown(reaction: ChemicalReaction, team: int) -> void:
	_cooldown_ready[_key(reaction, team)] = _current_round() + reaction.cooldown_rounds


func clear_cooldowns() -> void:
	_cooldown_ready.clear()


# ---------- USO ----------

## A reação que "actor" (o que executa o movimento) pode usar agora: personagem certo,
## fora de recarga e com todas as condições cumpridas. null = nenhuma.
func find_available(actor: Player) -> ChemicalReaction:
	if actor == null:
		return null
	for reaction in reactions:
		if reaction.trigger_id != actor.character_id:
			continue
		if not is_ready(reaction, actor.team):
			continue
		if reaction.find_partner(actor) != null:
			return reaction
	return null


## Começa a recarga, congela a partida e toca a cutscene + diálogo. Só volta quando acabou
## (use "await"). O movimento da reação deve ser feito DEPOIS disto.
func play(reaction: ChemicalReaction, trigger: Player, partner: Player) -> void:
	start_cooldown(reaction, trigger.team)
	reaction_started.emit(reaction, trigger, partner)
	var cutscene := ReactionCutscene.new()
	add_child(cutscene)
	await cutscene.play(reaction, partner, trigger)
	reaction_finished.emit(reaction)
