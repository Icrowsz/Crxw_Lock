class_name ReactionMiracle
extends ChemicalReaction
## MIRACLE (Reo + Nagi). Recarga: 12 rodadas.
##
## Condições (todas ao mesmo tempo):
##  1. O Reo (do mesmo time do Nagi) usou o Our Dream na rodada ANTERIOR. O passe alto sobe na rodada
##     do Reo e pousa Suspenso no começo do próximo turno do time, então é nesse turno que vale;
##  2. A bola ainda está pairando e ninguém mexeu nela depois do passe, EXCETO o próprio Nagi
##     (que pode "pegar" a bola com o Trap, ou chegar nela pulando);
##  3. O Nagi está com o botão Fake Volley (ele e a bola Suspensos e próximos) e tem um inimigo por
##     perto. Isso é conferido pelo próprio Nagi (nagi.gd, _miracle_available): só aí o botão vira
##     "Five Stage Volley".
##
## Efeito: cutscene + diálogo e depois o Nagi repete a finta do Fake Volley (anda e gira suspenso
## em volta da bola, com a caveira cada vez maior) e, na última etapa, volta ao ponto original e
## chuta forte, com 80% de chance de gol. A parte do movimento e dos efeitos está no nagi.gd
## (_use_five_stage_volley); o passe do Reo está no reo.gd (_use_dream). Aqui ficam só os dados
## e as condições.


func _init() -> void:
	id = &"miracle"
	display_name = "Miracle"
	trigger_id = "nagi"      # quem executa o movimento
	partner_id = "reo"       # quem deu o passe
	cooldown_rounds = 12
	accent = Color(0.78, 0.62, 1.0)   # violeta claro (o roxo do Reo clareado pelo branco do Nagi)
	description = "Reação Química com o Reo: o Fake Volley vira o Five Stage Volley."

	# Cutscene: troque o caminho do vídeo pelo seu (.ogv). Se o arquivo não existir, é pulado.
	video_path = "res://video/miracle.ogv"
	colors = {
		"reo": Color(0.65, 0.3, 0.95),     # roxo
		"nagi": Color(0.607, 0.697, 1.0, 1.0),    # branco azulado
	}

	# Falas de exemplo: troque pelas que você quiser (a ordem é a da cutscene)
	_say("reo", "We followed different paths.")
	_say("reo", "I was frustated.")
	_say("reo", "But maybe all of that...")
	_say("reo", "Was all for this moment.")
	_say("reo", "YOUR DREAM...")
	_say("reo", "IS THAT WAY, ISN'T IT?")
	_say("nagi", "Yes, boss.")


func find_partner(trigger: Player) -> Player:
	var nagi := trigger as Nagi
	# A cópia "fantasma" do Copy do Reo fica fora do grupo "players": ela nunca dispara a reação
	if nagi == null or not nagi.is_in_group("players"):
		return null
	var m: MatchManager = nagi._get_manager()
	var ball: Ball = nagi._get_ball()
	if m == null or ball == null:
		return null

	# 1) Um Reo do mesmo time fez o Our Dream
	var reo: Reo = null
	for p: Player in m.get_team_players(nagi.team):
		if p is Reo and not (p as Reo).last_our_dream.is_empty():
			reo = p as Reo
			break
	if reo == null:
		return null

	# 2) O passe foi na rodada anterior (a bola chega no começo do turno deste time)
	var dream: Dictionary = reo.last_our_dream
	if m.round_number != int(dream.get("round", -999)) + 0:
		return null

	# 3) A bola ainda está pairando e só o Reo (nenhum toque a mais) ou o Nagi (1 toque, o Trap) mexeu nela
	if not ball.hovering or ball.is_held():
		return null
	var extra_touches: int = ball.interaction_count - int(dream.get("touches", -999))
	if extra_touches < 0 or extra_touches > 1:
		return null
	if extra_touches == 0 and ball.last_toucher != reo:
		return null
	if extra_touches == 1 and ball.last_toucher != nagi:
		return null

	# (Nagi suspenso + bola suspensa + inimigo por perto) é conferido pelo próprio Nagi
	return reo
