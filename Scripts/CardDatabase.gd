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
		"abilities": {}
	},
	"DRAWCARD": {
		"type": "magic",
		"name": "압축",
		"cost": 2,
		# "texture_path": "res://assets/cards/draw_card.png",
		"abilities": {
			"onUse": [
				{ "ID": "DRAW_CARD", "target": "my_master", "amount": 2 },
			]
		}
	},
	"COIN": {
		"type": "magic",
		"name": "동전",
		"cost": 0,
		# "texture_path": "res://assets/cards/coin.png",
		"abilities": {
			"onUse": [
				{ "ID": "ADD_MANA", "target": "my_master", "amount": 1 },
			]
		}
	},
	"BOAR": {
		"type": "minion",
		"name": "맷돼지",
		"cost": 1,
		"atk": 1,
		"hp": 1,
		# "texture_path": "res://assets/cards/boar.png",
		"abilities": {
			"keyword": { "ID": "TAUNT" }
		}
	},
	"FARMER": {
		"type": "minion",
		"name": "농부",
		"cost": 2,
		"atk": 1,
		"hp": 2,
		# "texture_path": "res://assets/cards/farmer.png",
		"abilities": {
			"onTurnStart": { "ID": "ADD_MANA", "target": "my_master", "amount": 1 }
		}
	},
	"MOLD": {
		"type": "minion",
		"name": "곰팡이",
		"cost": 2,
		"atk": 2,
		"hp": 2,
		# "texture_path": "res://assets/cards/mold.png",
		"abilities": {
			"onUse": { "ID": "DOUBLE_HP", "target": "self", "amount": null }
		}
	}
}

# ID 기반 조회 함수
func get_card_by_id(id: String) -> Dictionary:
	if card_list.has(id):
		return card_list[id]
	return {}

# onSummon, onTurnStart, onTurnEnd, onAttack, onHit 등등의 트리거 타입을 자유롭게 추가할 수 있게 설계
