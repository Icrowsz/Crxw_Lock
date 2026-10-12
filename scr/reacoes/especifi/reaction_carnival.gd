class_name ReactionCarnival
extends ChemicalReaction
## CARNIVAL (Sae + Shidou). Recarga: 12 rodadas.
##
## Condições (todas ao mesmo tempo):
##  1. A Sae está sob o efeito do Obsessive Lover do Shidou;
##  2. A Sae deu um Perfect Pass no Shidou NESTE turno e ninguém tocou na bola depois;
##  3. O Shidou usa o Big Bang Drive (ele suspenso + bola voando). O botão vira "Carnival".
##
## Efeito: cutscene + diálogo e o Big Bang Drive sai com 83% de chance de gol, câmera tremendo,
## efeitos rosa-choque e asas no Shidou por 2 rodadas (só visual). A parte do chute e dos efeitos
## está no shidou.gd (_use_shot_skill); aqui ficam só os dados e as condições.


func _init() -> void:
	id = &"carnival"
	display_name = "Carnival"
	trigger_id = "shidou"
	partner_id = "sae"
	cooldown_rounds = 12
	accent = Color(1.0, 0.1, 0.6)   # rosa-choque
	description = "Reação Química com a Sae: o Big Bang Drive vira o Carnival."

	# Cutscene: troque o caminho do vídeo pelo seu (.ogv). Se o arquivo não existir, é pulado.
	video_path = "res://video/carnival.ogv"
	colors = {
		"sae": Color(1.0, 0.05, 0.55),      # rosa-choque
		"shidou": Color(0.75, 0.2, 1.0),    # roxo
	}

	# Falas de exemplo: troque pelas que você quiser (a ordem é a da cutscene)
	_say("shidou", "My soccer cells...")
	_say("shidou", "are tingling and stirring to spark.")
	_say("sae", "Fly, you zesty demon..")
	_say("shidou", "With my goal...")
	_say("shidou", "With my genes...")
	_say("shidou", "BIG BANG DRIVE!")

func find_partner(trigger: Player) -> Player:
	var shidou := trigger as Shidou
	if shidou == null:
		return null

	# 1) A Sae precisa ser o "amigo" do Obsessive Lover (e o efeito ainda estar valendo)
	var sae := shidou.get_lover() as Sae
	if sae == null:
		return null

	# 2) O último Perfect Pass da Sae foi neste turno, para o Shidou, e a bola não foi tocada depois
	var m: MatchManager = shidou._get_manager()
	var ball: Ball = shidou._get_ball()
	if m == null or ball == null:
		return null
	var pp: Dictionary = sae.last_perfect_pass
	if pp.is_empty():
		return null
	if pp.get("target") != shidou or int(pp.get("round", -1)) != m.round_number:
		return null
	if int(pp.get("touches", -1)) != ball.interaction_count or ball.last_toucher != sae:
		return null

	# 3) (Shidou suspenso + bola voando) é conferido pelo próprio Shidou: só aí o botão é o Big Bang
	return sae
