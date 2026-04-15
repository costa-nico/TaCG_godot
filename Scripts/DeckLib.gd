extends Node

# 플레이어 덱 정보: 카드ID(또는 이름): 장 수
var player_deck: Dictionary = {
	"DRAWCARD": 5,
	"BOAR": 1,
	"FARMER": 1,
	"COIN": 5,
}

var enemy_deck: Dictionary = {
	"BOAR": 5,
	"DRAWCARD": 5,
	"COIN": 2,
}

# 덱 리스트 반환
func get_player_deck() -> Dictionary:
	return player_deck

func get_enemy_deck() -> Dictionary:
	return enemy_deck
