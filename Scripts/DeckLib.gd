extends Node

# 플레이어 덱 정보: 카드ID(또는 이름): 장 수
var player_deck: Dictionary = {
	"GIVE_UP": 1, # 테스트용 카드, 실제 게임에서는 제거 예정
	"SERVICE_START": 1,
	"ENHANCER": 1,
	"IRON_KNIGHT": 1,
	"COIN_POCKET": 5
}

var enemy_deck: Dictionary = {
	"DUMMY" : 30 # 테스트용 더미 카드, 실제 게임에서는 제거 예정
}

# 덱 리스트 반환
func get_player_deck() -> Dictionary:
	return player_deck

func get_enemy_deck() -> Dictionary:
	return enemy_deck



	# "COIN": 2,
	# "APPRENTICE_SHIELDBEARER": 2,
	# "SHARP_ARROW": 2,
	# "POISON_DART": 2,
	# "ENHANCER": 2,
	# "IRON_KNIGHT": 2,
	# "LIGHTNING": 1,
	# "VICTORIOUS_COMMANDER": 1