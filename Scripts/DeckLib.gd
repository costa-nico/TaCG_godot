extends Node

# 플레이어 덱 정보: 카드ID(또는 이름): 장 수
var player_deck: Dictionary = {
	"COIN": 2,
	"APPRENTICE_SHIELDBEARER": 2,
	"SHARP_ARROW": 2,
	"ENHANCER": 2,
	"IRON_KNIGHT": 2,
	"LIGHTNING": 1,
	"VICTORIOUS_COMMANDER": 1
}

var enemy_deck: Dictionary = {
	"COIN": 2,
	"APPRENTICE_SHIELDBEARER": 2,
	"SHARP_ARROW": 2,
	"ENHANCER": 2,
	"IRON_KNIGHT": 2,
	"LIGHTNING": 1,
	"VICTORIOUS_COMMANDER": 1
}

# 덱 리스트 반환
func get_player_deck() -> Dictionary:
	return player_deck

func get_enemy_deck() -> Dictionary:
	return enemy_deck
