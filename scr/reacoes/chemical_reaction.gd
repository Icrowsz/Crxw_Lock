class_name ChemicalReaction
extends RefCounted
## Reação Química (Chemical Reaction): um combo entre DOIS personagens com afinidade.
## Cada reação é um script que estende esta classe (veja reaction_carnival.gd) e define:
##   - quem são os dois personagens (character_id de cada um);
##   - as condições para usar (find_partner);
##   - a recarga (em rodadas), a cor e as falas da cutscene.

## CARNIVAL; Shidou X Sae / CRUEL; Rin X Charles / FEEDING; Barou X Lorenzo / HERBIVICUS; Kaiser X Ness
## MIRACLE; Nagi X Reo / BEYOND; Isagi X Hiori / SACRIFICE; Hiori X Karasu / SUPERSTAR; Kaiser X Kiyora

## Quem EXECUTA o movimento é o "trigger" (ex: Shidou, que dá o chute). O outro é o "partner"
## (ex: Sae, que deu o passe). A habilidade do trigger é quem chama o ReactionManager.play().

var id: StringName = &""
var display_name: String = ""
var trigger_id: String = ""      # character_id de quem executa o movimento
var partner_id: String = ""      # character_id do parceiro
var cooldown_rounds: int = 12    # recarga da reação (por time), em rodadas
var accent: Color = Color(1.0, 0.1, 0.6)   # cor da cutscene
var description: String = ""     # texto curto para o balão do menu

## Cutscene: pasta com os rostinhos (<character_id>.png), vídeo do centro da tela e cor de cada
## personagem (contorno do diálogo e moldura do rosto). Sem vídeo/rosto, a cutscene funciona igual.
var faces_dir: String = "res://img/rostinhos"
var video_path: String = ""      # vídeo .ogv (o único formato de vídeo que o Godot toca nativamente)
var video_loop: bool = false     # true = o vídeo repete até o fim do diálogo; false = some quando acaba
## Tamanho do vídeo como fração da tela, ESTICADO (1.0 = tela inteira, 1920x1080; 0.5 = metade)
var video_size_ratio: float = 1.0
## Chroma key: tira o fundo de uma cor (verde por padrão) do vídeo
var video_chroma_key: bool = true
var chroma_color: Color = Color.from_rgba8(1, 128, 1)
var chroma_similarity: float = 0.20   # quanto da cor é removido (sobe = remove mais; se sobrar verde, aumente)
var chroma_smoothness: float = 0.08   # suavidade da borda (sobe = borda mais "esfumada")
var chroma_spill: float = 0.5         # tira o reflexo verde das bordas (0 a 1; só faz sentido para fundo verde)
var colors: Dictionary = {}      # character_id -> Color

## Falas da cutscene, na ordem: {"who": character_id, "text": String}
var lines: Array[Dictionary] = []


func _say(who: String, text: String) -> void:
	lines.append({"who": who, "text": text})


## O personagem faz parte desta reação?
func involves(character_id: String) -> bool:
	return character_id == trigger_id or character_id == partner_id


## Devolve o PARCEIRO se TODAS as condições da reação estão cumpridas agora (a recarga é conferida
## pelo ReactionManager), ou null se não dá para usar. Sobrescreva em cada reação.
func find_partner(_trigger: Player) -> Player:
	return null
