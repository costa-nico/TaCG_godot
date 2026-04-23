extends Control

const CARD_SCENE = preload("res://scenes/Card.tscn")
var display_card: Node2D = null

@onready var card_node: Node2D = $CardNode # 확대된 카드가 위치할 노드

@onready var desc_label: Label = $VBoxContainer/DescriptionPanel/DescriptionContainer/DescriptionLabel
@onready var info_label: Label = $VBoxContainer/InfoPanel/InfoContainer/InfoLabel


var is_closing: bool = false # 닫히는 애니메이션 도중 중복 실행 방지용 플래그

func _ready():
	hide()

# 배틀 씬에서 호출하는 함수
func show_card(card_data: Dictionary, original_card_pos: Vector2):
	is_closing = false # 열릴 때 플래그 초기화
	# 1. 이전에 띄워둔 카드가 남아있다면 안전하게 제거
	if is_instance_valid(display_card):
		display_card.queue_free()
		display_card = null
		
	# 2. 디스크립션 씬 전용으로 카드 인스턴스 새로 생성
	display_card = CARD_SCENE.instantiate()
	add_child(display_card)
	
	# 3. 카드 정보 세팅 (master 파라미터는 단순히 화면 표시용이므로 배틀 씬의 player를 임시 할당)
	var battle_scene = get_tree().current_scene
	display_card.init_card(card_data, battle_scene.player)
	display_card.update_display()
	
	# 디스크립션이 열릴 때 InputManager의 상태를 강제로 UI_OPEN으로 변경
	if battle_scene.input_manager:
		battle_scene.input_manager.set_state(battle_scene.input_manager.InputState.UI_OPEN)
	
	# 5. 카드 콜라이더 끄기 (카드 자체를 클릭하는 게 아니라 배경을 클릭해서 닫히게 하기 위함)
	display_card.input_pickable = false 
	
	# 6. 카드 텍스트 정보 업데이트
	_update_info_text(card_data)
	_update_desc_text(card_data)
	
	# 7. 애니메이션 준비
	# 시작: 원본 카드의 위치와 크기(핸드에 있을 때 기준)
	display_card.global_position = original_card_pos
	display_card.scale = display_card.SCALE_HAND # 카드의 기본 핸드 스케일을 불러와 사용
	display_card.z_index = 4000 # 최상단에 렌더링
	
	show()
	
	# 8. 중앙으로 확대되는 애니메이션 실행
	var target_pos = card_node.global_position
	var target_scale = display_card.SCALE_DESC # 카드에 정의된 설명창 전용 스케일 사용
	
	var tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(display_card, "global_position", target_pos, 0.25)
	tween.parallel().tween_property(display_card, "scale", target_scale, 0.25)


# 빈 공간 클릭 시 닫기 처리
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_RIGHT) and event.pressed:
		if is_closing: return # 이미 닫히는 중이라면 추가 클릭 무시
		is_closing = true
		
		# 그냥 숨기지 않고, 카드가 사라지는 애니메이션을 추가
		if is_instance_valid(display_card):
			var tween = create_tween().set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
			tween.tween_property(display_card, "modulate:a", 0.0, 0.15) # 투명하게 사라지게
			await tween.finished
			# await 대기 중에 노드가 삭제되었을 수 있으므로 다시 한번 유효성 검사 (Godot 필수 테크닉)
			if is_instance_valid(display_card):
				display_card.queue_free()
				display_card = null
		hide()
		
		# 창이 완전히 닫히면 InputManager를 다시 대기(IDLE) 상태로 돌려놓음
		var battle_scene = get_tree().current_scene
		if battle_scene and battle_scene.input_manager:
			battle_scene.input_manager.set_state(battle_scene.input_manager.InputState.IDLE)

func _update_info_text(data: Dictionary):
	if not info_label: return
	
	var type_str = "하수인" if data.get("type") == "minion" else "주문"
	var info = "%s: %s             비용: %d" % [type_str, data.get("name", "Unknown"),  data.get("cost", 0)]
	
	if data.get("type") == "minion":
		info += ", 공격력: %d, 체력: %d" % [data.get("atk", 0), data.get("hp", 0)]
		
	info_label.text = info

func _update_desc_text(data: Dictionary):
	if not desc_label: return
	
	var text = ""
	var abilities = data.get("abilities", {})
	
	if not abilities.is_empty():
		# 1. 키워드 처리
		if abilities.has("keyword"):
			var kw_list = abilities["keyword"] if typeof(abilities["keyword"]) == TYPE_ARRAY else [abilities["keyword"]]
			for kw in kw_list:
				if typeof(kw) == TYPE_DICTIONARY and kw.get("ID") == "TAUNT":
					text += "[도발]\n"
					
		# 2. 일반 트리거 처리
		for trigger in ["onUse", "onTurnStart", "onTurnEnd", "onAttack", "onHit"]:
			if abilities.has(trigger):
				var prefix = ""
				if trigger == "onUse" and data.get("type") == "minion": prefix = "[전투의 함성]: "
				elif trigger == "onUse" and data.get("type") == "magic": prefix = "" # 마법은 사용 시 접두사 생략
				elif trigger == "onTurnStart": prefix = "[턴 시작 시]: "
				elif trigger == "onTurnEnd": prefix = "[턴 종료 시]: "
				elif trigger == "onAttack": prefix = "[공격 시]: "
				elif trigger == "onHit": prefix = "[피격 시]: "
				
				var effects = abilities[trigger]
				var effect_strs = PackedStringArray()
				for eff in effects:
					effect_strs.append(_parse_effect(eff))
					
				if effect_strs.size() > 0:
					text += prefix + ", ".join(effect_strs) + "\n"

	text = text.strip_edges()
	
	# 추가 설명 (플레이버 텍스트 등) 덧붙이기
	var extra_desc = data.get("description", data.get("descripton", "")) # 오타가 있었을 경우를 대비한 안전 장치
	if extra_desc != "":
		if text != "":
			text += "\n\n" + extra_desc # 능력 텍스트와 추가 설명 사이에 여백 추가 및 괄호
		else:
			text = extra_desc
	elif text == "": # 능력도 없고 설명도 없을 때
		text = "능력이 없습니다."
		
	desc_label.text = text.strip_edges()

func _parse_effect(eff: Dictionary) -> String:
	var target_dict = {
		"my_master": "자신 마스터에게", 
		"enemy_master": "적 마스터에게",
		"enemy_minion": "적 하수인 하나에게", 
		"my_minion": "아군 하수인 하나에게",
		"any_minion": "하수인 하나에게", 
		"enemy_minions": "모든 적 하수인에게",
		"my_minions": "모든 아군 하수인에게", 
		"any": "아무 대상에게나", 
		"self": "자신에게"
	}
	var t_str = target_dict.get(eff.get("target", ""), "")
	var t_prefix = t_str + " " if t_str != "" else ""
	match eff.get("ID", ""):
		"DAMAGE", "DAMAGE_ALL": return t_prefix + "피해를 %d 줍니다" % eff.get("amount", 0)
		"BUFF", "BUFF_ALL": return t_prefix + "+%d/+%d 부여합니다" % [eff.get("atk", 0), eff.get("hp", 0)]
		"ADD_MANA": return "마나를 %d 회복합니다" % eff.get("amount", 0)
		"DRAW_CARD": return "카드를 %d장 뽑습니다" % eff.get("amount", 0)
		"ADD_HP": return t_prefix + "체력을 %d 회복합니다" % eff.get("amount", 0)
		"DOUBLE_HP": return t_prefix + "체력을 2배로 만듭니다"
	return "알 수 없는 효과"
