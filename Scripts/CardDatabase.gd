extends Node

# JS의 cardList를 Godot Dictionary로 변환한 형태
# 이제는 숫자 인덱스가 아닌 카드 `ID`를 키로 사용합니다.
var card_list = {
	"DUMMY": {
		"type": "minion",
		"name": "더미",
		"cost": 0,
		"atk": 0,
		"hp": 1,
		# "texture_path": "res://assets/cards/scarecrow.png",
		"abilities": {},
		"description": "완전한 테스트용 더미 카드."
	},
	"COIN": {
		"type": "magic",
		"name": "동전",
		"cost": 0,
		"texture_path": "res://Images/cards/coin.png",
		"description": "동전은 언제나 환영이야!",
		"abilities": {
			"onUse": [
				{ "ID": "ADD_MANA", "target": "my_master", "amount": 1 },
			]
		},
		"category" : "boost"
	},
	"COIN_POCKET": {
		"type": "magic",
		"name": "동전 주머니",
		"cost": 0,
		"texture_path": "res://Images/cards/coin.png",
		"description": "와!",
		"abilities": {
			"onUse": [
				{ "ID": "ADD_MANA", "target": "my_master", "amount": 10 },
				{ "ID": "DRAW_CARD", "target": "my_master", "amount": 2 },
			]
		},
		"category" : "boost"
	},
	"APPRENTICE_SHIELDBEARER": {
		"type": "minion",
		"name": "견습 방패병",
		"cost": 1,
		"atk": 1,
		"hp": 2,
		"description": "넌 못지나간다.",
		"abilities": {
			"keyword": [
				{ "ID": "TAUNT" }
			]
		},
		"category" : "normal"
	},
	"SHARP_ARROW": {
		"type": "magic",
		"name": "날카로운 화살",
		"cost": 2,
		"description": "저격 On",
		"abilities": {
			"onUse": [
				{ "ID": "DAMAGE", "target": "any", "amount": 3 }
			]
		},
		"category" : "damage"
	},
	"ENHANCER": {
		"type": "minion",
		"name": "강화 술사",
		"cost": 2,
		"atk": 2,
		"hp": 2,
		"description": "내가 강화해줄게!",
		"abilities": {
			"onUse": [
				{ "ID": "BUFF", "target": "any_minion", "atk": 1, "hp": 1 }
			]
		},
		"category" : "buff"
	},
	"IRON_KNIGHT": {
		"type": "minion",
		"name": "철갑 기사",
		"cost": 3,
		"atk": 3,
		"hp": 4,
		"description": "튼튼한 방어구로 무장한 기사입니다.",
		"abilities": {},
		"category" : "normal"
	},
	"LIGHTNING": {
		"type": "magic",
		"name": "벼락",
		"cost": 4,
		"description": "하늘에서 내리는 강력한 번개입니다.",
		"abilities": {
			"onUse": [
				{ "ID": "DAMAGE_ALL", "target": "enemy_minions", "amount": 2 }
			]
		},
		"category" : "damage"
	},
	"VICTORIOUS_COMMANDER": {
		"type": "minion",
		"name": "승리의 지휘관",
		"cost": 5,
		"atk": 4,
		"hp": 5,
		"description": "전장을 지휘하여 아군을 강화하는 지휘관입니다.",
		"abilities": {
			"onUse": [
				{ "ID": "BUFF_ALL", "target": "my_minions", "atk": 1, "hp": 1 }
			]
		},
		"category" : "buff"
	}
}

# ID 기반 조회 함수
func get_card_by_id(id: String) -> Dictionary:
	if card_list.has(id):
		return card_list[id]
	return {}
