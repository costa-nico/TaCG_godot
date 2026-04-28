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
		"beg_dialogue_id": "PINK_MAID_BEG", # 죽을 때 띄울 다이얼로그 ID!
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
		"category" : "summon"
	},
	"SISTER" : {
		"type": "minion",
		"name": "음란한 수녀",
		"cost": 3,
		"atk": 3,
		"hp": 3,
		"description": "밤시중에 특화된 메이드입니다.",
		"texture_path": "res://Images/cards/pink_maid.png",
		"beg_dialogue_id": "PINK_MAID_BEG", # 죽을 때 띄울 다이얼로그 ID!
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
	"INDUCE_PASSIVE": [
		[
			{
				"name": "핑크 메이드",
				"image": "res://Images/cg/pink_maid_stand.png", 
				"text": "저기, 그 효과 저한테 주시겠어요? \n만약 저한테 주신다면 '봉사' 해드리겠습니다❤️",
				# "time_limit": 10.0,
				"timeout_index": 0,
				"charm_lock_index": [1], 
				"charm_option": [
					{
						"text": "네, 기꺼이 드릴게요❤️", 
						"override_target": true,
						"next_dialogue": [
							{"name": "핑크 메이드", 
							 "image": "res://Images/cg/pink_maid_stand.png", 
							 "text": "감사합니다 주인님❤️. 잘 받을게요❤️"},
							{"name": "핑크 메이드",
							 "image": "res://Images/cg/pink_maid_handjob_0.png", 
							 "text": "자 그러면 보답으로❤️.\n최고로 기분 좋은 봉사❤️ 시작하겠습니다❤️",
							"effect": { "ID": "APPLY_STATUS", "target": "my_master", "status_id": "CHARM", "amount": 1 }},
						]
					},
					{
						"text": "주인님이라고 불러주니 거절할 수 없네❤️", 
						"override_target": true,
						"next_dialogue": [
							{"name": "핑크 메이드", 
							 "image": "res://Images/cg/pink_maid_stand.png", 
							 "text": "감사합니다 주인님❤️. 잘 받을게요❤️"},
							{"name": "핑크 메이드",
							 "image": "res://Images/cg/pink_maid_handjob_0.png", 
							 "text": "자 그러면 보답으로❤️.\n최고로 기분 좋은 봉사❤️ 시작하겠습니다❤️",
							"effect": { "ID": "APPLY_STATUS", "target": "my_master", "status_id": "CHARM", "amount": 1 }},
						]
					}
				],
				"options": [
					{
						"text": "(유혹에 넘어간다) 효과 대상을 변경", 
						"override_target": true,
						"next_dialogue": [
							{"name": "핑크 메이드", 
							 "image": "res://Images/cg/pink_maid_stand.png", 
							 "text": "감사합니다 주인님❤️. 잘 받을게요❤️"},
							{"name": "핑크 메이드",
							 "image": "res://Images/cg/pink_maid_handjob_0.png", 
							 "text": "자 그러면 보답으로❤️.\n최고로 기분 좋은 봉사❤️ 시작하겠습니다❤️",
							"effect": { "ID": "APPLY_STATUS", "target": "my_master", "status_id": "CHARM", "amount": 1 }},
							{"name": "핑크 메이드", 
							 "image": "res://Images/cg/pink_maid_handjob_1.png", 
							 "text": "다음에도 잘 부탁드립니다. 주인님❤️",
							 "effect": { "ID": "DAMAGE", "target": "my_master", "amount": 1 }},
						]
					},
					{
						"text": "(단호하게 거절한다) 원래 대상에게 사용", 
						"override_target": false,
						"next_dialogue": [
							{"name": "핑크 메이드", 
							 "image": "res://Images/cg/pink_maid_stand.png", 
							 "text": "칫, 쪼잔하긴."}
						]
					}
				]
			}
		],
	],
	"PINK_MAID_BEG": [
		[
			{
				"name": "핑크 메이드",
				"image": "res://Images/cg/pink_maid_stand.png", 
				"text": "꺄아앗! 아, 아파요... 이대로 죽고 싶지 않아요...\n살려주시면... 뭐든지 할게요❤️",
				"options": [
					{
						"text": "(거절한다) 가차없이 숨통을 끊는다.", 
						"kill_minion": true, # 이 플래그를 통해 BattleScene에서 최종 파괴를 결정합니다!
						"next_dialogue": [
							{"name": "핑크 메이드", "image": "res://Images/cg/pink_maid_stand.png", "text": "아아앗... 너무해..."}
						]
					},
					{
						"text": "(수락한다) 목숨을 살려준다.", 
						"kill_minion": false,
						"effect": { "ID": "APPLY_STATUS", "target": "my_master", "status_id": "CHARM", "amount": 3 },
						"next_dialogue": [
							{"name": "핑크 메이드", "image": "res://Images/cg/pink_maid_stand.png", "text": "감사합니다 주인님❤️\n제 몸, 마음껏 써주세요❤️"}
						]
					}
				]
			}
		]
	],
	"DEFAULT_BEG": [
		[
			{
				"name": "적 하수인",
				"image": "res://Images/enemy.jpg", 
				"text": "살려주세요! 한 번만 봐주세요!",
				"options": [
					{ "text": "죽어라.", "kill_minion": true },
					{ "text": "봐준다.", "kill_minion": false }
				]
			}
		]
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

# 한국어 단어 중간 잘림을 완벽하게 방지하기 위해, 글자 사이에 '단어 결합자(Word Joiner)' 투명 문자를 삽입하는 강력한 헬퍼 함수!
func keep_together(text: String) -> String:
	var result = ""
	for i in range(text.length()):
		result += text[i]
		if i < text.length() - 1:
			result += "\u2060" # U+2060: 어떤 경우에도 줄바꿈을 허용하지 않는 투명 특수문자
	return result

func get_keyword_description(kw: Dictionary, tooltips: Dictionary) -> String:
	match kw.get("ID", ""):
		"TAUNT":
			tooltips["도발"] = "도발: 도발을 가진 하수인이 있다면, 다른 대상을 공격할 수 없습니다."
			return "[color=#FFD700]%s[/color]" % keep_together("[도발]")
	return ""

func get_effect_description(eff: Dictionary, tooltips: Dictionary) -> String:
	var target_dict = {
		"my_master": "자신 마스터에게", 
		"enemy_master": "적 마스터에게",
		"enemy_minion": "적 하수인 하나에게", 
		"my_minion": "아군 하수인 하나에게",
		"any_minion": "하수인 하나에게", 
		"enemy_minions": "모든 적 하수인에게",
		"my_minions": "모든 아군 하수인에게", 
		"enemy_empty_slot": "적의 빈 슬롯 하나에",
		"my_empty_slot": "아군의 빈 슬롯 하나에",
		"any_empty_slot": "아무 빈 슬롯 하나에",
		"any": "아무 대상에게나", 
		"self": "자신에게"
	}
	var t_str = target_dict.get(eff.get("target", ""), "")
	var t_prefix = t_str + " " if t_str != "" else ""
	match eff.get("ID", ""):
		"DAMAGE", "DAMAGE_ALL": return t_prefix + "피해를 %d줍니다." % eff.get("amount", 0)
		"BUFF", "BUFF_ALL": return t_prefix + "+%d/+%d 부여합니다." % [eff.get("atk", 0), eff.get("hp", 0)]
		"ADD_MANA": return "마나를 %d회복합니다." % eff.get("amount", 0)
		"DRAW_CARD": return "카드를 %d장 뽑습니다." % eff.get("amount", 0)
		"ADD_HP": return t_prefix + "체력을 %d회복합니다." % eff.get("amount", 0)
		"DOUBLE_HP": return t_prefix + "체력을 2배로 만듭니다."
		"APPLY_STATUS": 
			var status_id = eff.get("status_id", "")
			var s_data = get_status_data(status_id)
			var s_name = s_data.get("name", "상태이상")
			
			if not s_data.is_empty():
				tooltips[s_name] = "%s: %s" % [s_name, s_data.get("description", "")]
				
			return t_prefix + "[color=#00FFFF]%s[/color]을(를) %d스택 부여합니다." % [keep_together("[" + s_name + "]"), eff.get("amount", 0)]
		"SUMMON":
			var c_data = get_card_by_id(eff.get("card_id", ""))
			var c_name = c_data.get("name", "하수인")
			return t_prefix + "[color=#FFD700]%s[/color]을(를) 소환합니다." % keep_together(c_name)
		"INDUCE":
			tooltips["유도"] = "유도: 상대가 이로운 효과(버프)를 사용할 때, 그 효과를 가로채는 유혹을 시도합니다."
			return "[color=#FF69B4]%s[/color] 능력을 지닙니다." % keep_together("[유도]")
	return "알 수 없는 효과"
