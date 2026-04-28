extends Node

var current_enemy_id: String = "enemy_1" # 현재 전투 중인 적의 ID

# 적(Enemy) 프로필 데이터베이스
var enemy_list = {
	"enemy_1": {
		"name": "허수아비 (튜토리얼)",
		"avatar": "res://Images/cg/player.png",
		"deck": { "DUMMY": 30 },
		"turn_start_dialogue": [], # 대사 없음
		"win_dialogue": [
			{"name": "", "image": "res://Images/cg/player.png", "text": "허수아비를 쓰러뜨렸다! 전투 종료."}
		],
		"lose_dialogue": [
			{"name": "", "image": "res://Images/cg/player.png", "text": "허수아비에게 졌다고...? 말도 안 돼..."}
		]
	},
	"enemy_2": {
		"name": "메이드 장",
		"avatar": "res://Images/cg/player.png",
		"deck": { "SERVICE_START": 5, "PINK_MAID": 10, "COIN": 15 },
		"game_start_dialogue": [
			{"name": "메이드 장", "image": "res://Images/cg/pink_maid_stand.png", "text": "어서 오세요 주인님❤️. 오늘은 성심성의껏 봉사해드리겠습니다❤️."},
		],
		"win_dialogue": [
			{"name": "메이드 장", "image": "res://Images/enemy.jpg", "text": "아앙... 주인님 너무 강해요❤️ 항복할게요❤️"}
		],
		"lose_dialogue": [
			{"name": "메이드 장", "image": "res://Images/enemy.jpg", "text": "우후훗❤️ 이제 영원히 제 장난감이에요❤️"}
		]
	},
	"enemy_3": {
		"name": "수녀님",
		"avatar": "res://Images/cg/player.png",
		"deck": { "SERVICE_START": 5, "PINK_MAID": 10, "COIN": 15 },
		"game_start_dialogue": [
			{"name": "수녀님", "image": "res://Images/cg/pink_maid_stand.png", "text": "길잃은 어린 양이시여. 제가 바른길로 인도해드릴게요❤️"},
		],
		"win_dialogue": [
			{"name": "수녀님", "image": "res://Images/enemy.jpg", "text": "아앙... 이토록 불경할수가..."}
		],
		"lose_dialogue": [
			{"name": "수녀님", "image": "res://Images/enemy.jpg", "text": "신도가 되신것을 환영합니다...❤️"}
		]
	}
}

func get_enemy_data(id: String) -> Dictionary:
	if enemy_list.has(id): return enemy_list[id].duplicate(true)
	return {}

func get_game_start_dialogue() -> Array:
	var data = get_enemy_data(current_enemy_id)
	if data.has("game_start_dialogue") and data["game_start_dialogue"].size() > 0:
		var diag = data["game_start_dialogue"]
		if typeof(diag[0]) == TYPE_ARRAY:
			return diag.pick_random().duplicate(true)
		else:
			return diag.duplicate(true)
	return []

func get_current_turn_start_dialogue() -> Array:
	var data = get_enemy_data(current_enemy_id)
	if data.has("turn_start_dialogue") and data["turn_start_dialogue"].size() > 0:
		var diag = data["turn_start_dialogue"]
		if typeof(diag[0]) == TYPE_ARRAY:
			return diag.pick_random().duplicate(true)
		else:
			return diag.duplicate(true)
	return []

func get_game_over_dialogue(is_player_victory: bool) -> Array:
	var data = get_enemy_data(current_enemy_id)
	var key = "win_dialogue" if is_player_victory else "lose_dialogue"
	if data.has(key) and data[key].size() > 0:
		var diag = data[key]
		if typeof(diag[0]) == TYPE_ARRAY:
			return diag.pick_random().duplicate(true)
		else:
			return diag.duplicate(true)
	return []