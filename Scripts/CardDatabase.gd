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
	"POISON_DART": {
		"type": "magic",
		"name": "독화살",
		"cost": 0,
		"description": "핫둘셋넷.",
		"abilities": {
			"onUse": [
				{ "ID": "APPLY_STATUS", "target": "any", "status_id": "POISON", "amount": 2 },
			]
		},
		"category" : "damage"
	},
	"COIN_POCKET": {
		"type": "magic",
		"name": "동전 주머니",
		"cost": 0,
		"texture_path": "res://Images/cards/coin.png",
		"description": "와!",
		"abilities": {
			"onUse": [
				{ "ID": "ADD_MANA", "target": "my_master", "amount": 5 },
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
	},
	"GIVE_UP" : {
		"type": "magic",
		"name": "항복",
		"cost": 0,
		"description": "적의 유혹에 무방비해집니다.",
		"abilities": {
			"onUse": [
				{ "ID": "APPLY_STATUS", "target": "my_master", "status_id": "CHARM", "amount": 10 }
			]
		},
		"category" : "special"
	},
	"PINK_MAID" : {
		"type": "minion",
		"name": "핑크 메이드",
		"cost": 3,
		"atk": 3,
		"hp": 3,
		"description": "밤시중에 특화된 메이드입니다.",
		"texture_path": "res://Images/cards/pink_maid.png",
		"abilities": {
			"onUse": [
				{ "ID": "APPLY_STATUS", "target": "enemy_master", "status_id": "CHARM", "amount": 2 }
			],
			"passive": [
				{ "ID": "INDUCE", "target": "self", "dialogue_id": "INDUCE_PASSIVE" }
			]
		},
		"category" : "lewd"
	},
	"SERVICE_START": {
		"type": "magic",
		"name": "봉사 개시",
		"cost": 0,
		"description": "미인계 테스트용 카드입니다.",
		"abilities": {
			"onUse": [
				{ "ID": "SUMMON", "target": "enemy_empty_slot", "card_id": "PINK_MAID" }
			]
		},
		"category" : "special"
	}
}

# ID 기반 조회 함수
func get_card_by_id(id: String) -> Dictionary:
	if card_list.has(id):
		return card_list[id]
	return {}

# 이름 기반 원본 조회 함수 (설명창 등에서 원본 스탯 표시용)
func get_original_card_by_name(card_name: String) -> Dictionary:
	for id in card_list.keys():
		if card_list[id].get("name") == card_name:
			return card_list[id]
	return {}

# 상태이상 데이터베이스 (중앙 관리)
var status_list = {
	"POISON": {
		"name": "독",
		"description": "턴이 끝날 때 스택만큼 피해를 입고, 1스택 감소합니다.",
		"icon_path": "res://Images/status/poison.png"
	},
	"CHARM": {
		"name": "매혹",
		"description": "스택 × 10%의 확률로 적의 유혹에 강제로 당합니다.",
		"icon_path": "res://Images/status/heart.png"
	}
}

func get_status_data(id: String) -> Dictionary:
	if status_list.has(id):
		return status_list[id]
	return {}

# ==========================================
# 다이얼로그(대화) 데이터베이스
# ==========================================
var dialogue_list = {
	"ENEMY_TURN_START": [
		# === 패턴 1 ===
		[
			{"image": "res://Images/enemy.jpg", "text": "후훗, 오빠. 나랑 재밌는 거 할래?"},
			{
				"image": "res://Images/enemy.jpg", 
				"text": "시간이 없어! 빨리 결정해!",
				"time_limit": 10.0, 
				"timeout_index": 0,
				"charm_lock_index": [1],
				"options": [
					{
						"text": "(유혹에 넘어간다)", 
						"effect": { "ID": "DAMAGE", "target": "my_master", "amount": 5 },
						"next_dialogue": [
							{"image": "res://Images/enemy.jpg", "text": "착한 아이네. 상으로 기분좋게 해줄게!"},
							{"image": "res://Images/enemy.jpg", "text": "어때 좋지?"}
						]
					},
					{
						"text": "(거절한다)", 
						"next_dialogue": [
							{"image": "res://Images/enemy.jpg", "text": "쳇, 시시하긴. 후회하게 될 거야!"}
						]
					}
				]
			}
		],
	],
	"INDUCE_PASSIVE": [
		[
			{
				"image": "res://Images/cg/pink_maid_stand.png", 
				"text": "저기, 그 효과 저한테 주시겠어요? \n만약 저한테 주신다면 '봉사' 해드리겠습니다❤️",
				# "time_limit": 10.0,
				"timeout_index": 0,
				"charm_lock_index": [1], 
				"options": [
					{
						"text": "(유혹에 넘어간다) 효과 대상을 변경", 
						"override_target": true,
						"next_dialogue": [
							{"image": "res://Images/cg/pink_maid_stand.png", "text": "감사합니다 주인님❤️. 잘 받을게요❤️"},
							{	"image": "res://Images/cg/pink_maid_handjob_0.png", 
								"text": "자 그러면 보답으로❤️.\n최고로 기분 좋은 봉사❤️ 시작하겠습니다❤️",
								"effect": { "ID": "APPLY_STATUS", "target": "my_master", "status_id": "CHARM", "amount": 1 }},
							{"image": "res://Images/cg/pink_maid_handjob_1.png", "text": "다음에도 잘 부탁드립니다. 주인님❤️",
								"effect": { "ID": "DAMAGE", "target": "my_master", "amount": 1 }},
						]
					},
					{
						"text": "(단호하게 거절한다) 원래 대상에게 사용", 
						"override_target": false,
						"next_dialogue": [
							{"image": "res://Images/cg/pink_maid_stand.png", "text": "칫, 쪼잔하긴."}
						]
					}
				]
			}
		],
	]
}

func get_dialogue(id: String) -> Array:
	if dialogue_list.has(id):
		var data = dialogue_list[id]
		# 리스트의 첫 번째 요소가 또 '배열(Array)'이라면 (여러 패턴이 묶여 있다면)
		if data.size() > 0 and typeof(data[0]) == TYPE_ARRAY:
			# 배열 안의 시퀀스 중 하나를 무작위로 뽑아서 반환합니다!
			return data.pick_random().duplicate(true)
		else:
			return data.duplicate(true)
	return []
