class_name ReactionCopyBee
extends ChemicalReaction

func _init() -> void:
	id = &"copy_bee"
	display_name = "Copy-Bee"
	trigger_id = "reo"
	partner_id = "bachira"
	cooldown_rounds = 12
	accent = Color(0.65, 0.3, 0.95) # Roxo
	description = "Reação com o Bachira: o Step Overs copiado libera o Model: Panther."
	
	video_path = ""
	colors = {
		"reo": Color(0.65, 0.3, 0.95),
		"bachira": Color(1.0, 0.85, 0.2),
		"ego": Color(0.92, 0.92, 0.98),
		"reobachira": Color(0.65, 0.3, 0.95),
		"reochigiri": Color(0.65, 0.3, 0.95),
	}
	
	_say("bachira", "Let's go! Buzz, Buzz!")
	_say("bachira", "Double-Bachira formation!!!")
	_say("ego", "It's a free and technical...")
	_say("ego", "...Duo playstyle.")
	_say("reo", "Copy...")
	_say("reobachira", "...And change.")
	_say("reochigiri", "I'll win... BY MYSELF.")

## Condições (TODAS): o Reo está com o Step Overs do Bachira copiado; o Bachira usou o Step Overs ORIGINAL e
## fez um passe para o Reo (na mesma rodada, sem ninguém tocar na bola depois); e é o turno do time deles.
## Quem confere isto é o Reo, ANTES de o Step Overs copiado rodar (ele mexe na bola); o Reo guarda o passe
## do Bachira em last_bee_pass e o Bachira guarda o Step Overs em last_step_overs.
## Efeito: cutscene e o Reo recebe o complemento GRATUITO Model: Panther (chute curvo que sobe, 1.5x, 75%).
func find_partner(trigger: Player) -> Player:
	var reo := trigger as Reo
	if reo == null:
		return null

	# 1) O Reo está com o Step Overs (a variante Step Overs, não o Freedom) do Bachira copiado
	if reo._copy_skill_id != &"step_overs":
		return null
	var ghost := reo._copy_ghost as Bachira
	if ghost == null or ghost.get_step_variant() != Bachira.StepVariant.STEP:
		return null

	var m: MatchManager = reo._get_manager()
	var ball: Ball = reo._get_ball()
	if m == null or ball == null or m.current_team != reo.team:
		return null

	# 2) O Bachira usou o Step Overs original e passou para o Reo, e a bola não foi tocada depois do passe
	var pass_info: Dictionary = reo.last_bee_pass
	var bachira := pass_info.get("bachira") as Bachira
	if bachira == null or not is_instance_valid(bachira) or bachira.is_down:
		return null
	if int(pass_info.get("round", -1)) != m.round_number:
		return null
	# Ninguém de fora da dupla pode ter tocado na bola depois do passe. NÃO dá para contar toques: a bola
	# encostada no Reo soma um toque a cada quadro (colisão) e a contagem quebrava a reação.
	var last: Player = ball.last_toucher
	if last != null and last != bachira and last != reo:
		return null
	return bachira
