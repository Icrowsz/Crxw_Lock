class_name ReactionFeeding
extends ChemicalReaction
## FEEDING (Lorenzo + Barou). Recarga: 12 rodadas.
##
## Condições (todas ao mesmo tempo):
##  1. O Lorenzo deu o Undead Pass para o Barou NESTE turno e ninguém tocou na bola depois;
##  2. O Barou está com o Predator Eye ATIVO (ele precisa ter usado o Predator Eye antes);
##  3. O Barou está com a bola ao alcance do Nero (ele no chão + bola no chão);
##  4. Há um inimigo em pé a até enemy_range px do Barou. O botão do Nero vira "Devour".
##
## Efeito: cutscene + diálogo e o Nero sai como Devour (mais força e velocidade, 80% de chance de gol),
## com um leão vermelho e preto gigante rugindo no momento do chute. Antes, o Undead Pass já saiu
## brilhando e com um zumbi translúcido acompanhando a bola. O chute e os efeitos estão no barou.gd
## (_use_shot) e o passe brilhante no lorenzo.gd (_use_undead_pass); os efeitos desenhados por código
## estão no feeding_fx.gd. Aqui ficam só os dados e as condições.

## "Próximo de um inimigo": distância máxima (px) entre o Barou e um inimigo em pé
var enemy_range: float = 160.0


func _init() -> void:
	id = &"feeding"
	display_name = "Feeding"
	trigger_id = "barou"
	partner_id = "lorenzo"
	cooldown_rounds = 12
	accent = Color(0.85, 0.05, 0.08)   # vermelho
	description = "Reação Química com o Lorenzo: o Nero vira o Devour."

	# Cutscene: troque o caminho do vídeo pelo seu (.ogv). Se o arquivo não existir, é pulado.
	video_path = "res://video/feeding.ogv"
	colors = {
		"lorenzo": Color(0.62, 0.25, 0.95),   # roxo
		"barou": Color(0.85, 0.05, 0.08),     # vermelho
	}

	# Falas de exemplo: troque pelas que você quiser (a ordem é a da cutscene)
	_say("lorenzo", "Feeding time, okay?")
	_say("barou", "Don't stand in my way...")
	_say("barou", "Or I'll kill you.")
	_say("lorenzo", "Yo-Ho Barou-Kun!")
	_say("barou", "Serve me...")
	_say("barou", "Ubers.")


func find_partner(trigger: Player) -> Player:
	var barou := trigger as Barou
	if barou == null:
		return null
	var m: MatchManager = barou._get_manager()
	var ball: Ball = barou._get_ball()
	if m == null or ball == null:
		return null

	# 1) O Barou precisa estar com o Predator Eye ativo
	if not barou._predator_active():
		return null

	# 2) ...e na situação do Nero (ele no chão + bola no chão ao alcance)
	if barou.get_shot_variant() != Barou.ShotVariant.NERO:
		return null

	# 3) Achar o Lorenzo do mesmo time
	var lorenzo: Lorenzo = null
	for p: Player in barou.get_tree().get_nodes_in_group("players"):
		if p is Lorenzo and p.team == barou.team:
			lorenzo = p as Lorenzo
			break
	if lorenzo == null:
		return null

	# 4) O último Undead Pass do Lorenzo foi neste turno, para o Barou, e a bola não foi tocada depois
	var up: Dictionary = lorenzo.last_undead_pass
	if up.is_empty():
		return null
	if up.get("target") != barou or int(up.get("round", -1)) != m.round_number:
		return null
	if int(up.get("touches", -1)) != ball.interaction_count or ball.last_toucher != lorenzo:
		return null

	# 5) Precisa ter um inimigo em pé por perto
	if not _enemy_near(barou):
		return null

	return lorenzo


## Há um inimigo em pé a até enemy_range px do Barou?
func _enemy_near(barou: Barou) -> bool:
	for p: Player in barou.get_tree().get_nodes_in_group("players"):
		if p.team == barou.team or p.is_down:
			continue
		if barou.global_position.distance_to(p.global_position) <= enemy_range:
			return true
	return false
