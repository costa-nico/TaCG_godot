extends Control

const CARD_SCENE = preload("res://scenes/Card.tscn")
var display_card: Node2D = null

@onready var card_node: Node2D = $CardNode # 확대된 카드가 위치할 노드

@onready var desc_label: RichTextLabel = $VBoxContainer/DescriptionPanel/DescriptionContainer/DescriptionLabel
@onready var info_label: Label = $VBoxContainer/InfoPanel/InfoContainer/InfoLabel
@onready var spec_label: Label = $VBoxContainer/InfoPanel/InfoContainer/SpecLabel


var is_closing: bool = false # 닫히는 애니메이션 도중 중복 실행 방지용 플래그

func _ready():
	# 툴팁 글자 크기 일괄 적용 (24 부분의 숫자를 원하시는 만큼 조절하세요!)
	var tooltip_theme = Theme.new()
	tooltip_theme.set_font_size("font_size", "TooltipLabel", 30) 
	desc_label.theme = tooltip_theme
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.fit_content = true
	desc_label.bbcode_enabled = true
	desc_label.clip_contents = false # 박스 오른쪽 끝에 닿은 글자가 미세하게 깎이는(잘리는) 시각적 버그 완벽 차단!
	
	# 텍스트 박스가 좁아서 한국어가 강제로 잘리는 현상을 막기 위해
	# 라벨의 최소 가로 너비를 450픽셀로 아주 넉넉하게 강제 고정해버립니다!
	desc_label.custom_minimum_size = Vector2(450, 0)
	
	hide()

# 배틀 씬에서 호출하는 함수
func show_card(card_data: Dictionary, _original_card_pos: Vector2): # 사용하지 않는 매개변수에 _ 추가
	is_closing = false # 열릴 때 플래그 초기화
	
	# 변경된 스탯이 아닌 원본 데이터 불러오기 (에러 원인 해결!)
	var original_data = CardDatabase.get_original_card_by_name(card_data.get("name", ""))
	if original_data.is_empty():
		original_data = card_data # 만약 못 찾으면 그대로 사용
		
	# 1. 이전에 띄워둔 카드가 남아있다면 안전하게 제거
	if is_instance_valid(display_card):
		display_card.queue_free()
		display_card = null
		
	# 2. 디스크립션 씬 전용으로 카드 인스턴스 새로 생성
	display_card = CARD_SCENE.instantiate()
	add_child(display_card)
	
	# 3. 카드 정보 세팅 (master 파라미터는 단순히 화면 표시용이므로 배틀 씬의 player를 임시 할당)
	var battle_scene = get_tree().get_first_node_in_group("battle_scene")
	display_card.init_card(original_data, battle_scene.player)
	display_card.update_display()
	
	# 5. 카드 콜라이더 끄기 (카드 자체를 클릭하는 게 아니라 배경을 클릭해서 닫히게 하기 위함)
	display_card.input_pickable = false 
	
	# 6. 카드 텍스트 정보 업데이트
	_update_info_text(original_data)
	_update_desc_text(original_data)
	
	# 7. 위치 및 크기 즉시 적용 (애니메이션 제거)
	display_card.global_position = card_node.global_position
	display_card.scale = display_card.SCALE_DESC
	display_card.z_index = 4000 # 최상단에 렌더링
	
	show()

func hide_card():
	is_closing = true
	if is_instance_valid(display_card):
		display_card.queue_free()
		display_card = null
	hide()

# 빈 공간 클릭 시 닫기 처리
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_RIGHT) and event.pressed:
		if is_closing: return # 이미 닫히는 중이라면 추가 클릭 무시
		is_closing = true
		
		if is_instance_valid(display_card):
			display_card.queue_free()
			display_card = null
		hide()

func _update_info_text(data: Dictionary):
	if info_label: 
		info_label.text = data.get("name", "Unknown")
		
	if spec_label:
		var spec = "💧%d" % data.get("cost", 0)
		if data.get("type") == "minion":
			spec += "   🗡️%d   ❤️%d" % [data.get("atk", 0), data.get("hp", 0)]
		spec_label.text = spec

func _update_desc_text(data: Dictionary):
	if not desc_label: return
	
	desc_label.mouse_filter = Control.MOUSE_FILTER_PASS # 마우스 호버(툴팁) 인식을 위해 필터 활성화 보장
	
	var type_str = "하수인" if data.get("type") == "minion" else "주문"
	var text = type_str +"\n\n" 
	var abilities = data.get("abilities", {})
	
	var tooltips: Dictionary = {} # 툴팁 설명들을 모아둘 주머니
	
	if not abilities.is_empty():
		# 1. 키워드 처리
		if abilities.has("keyword"):
			var kw_list = abilities["keyword"] if typeof(abilities["keyword"]) == TYPE_ARRAY else [abilities["keyword"]]
			for kw in kw_list:
				if typeof(kw) == TYPE_DICTIONARY:
					var kw_desc = CardDatabase.get_keyword_description(kw, tooltips)
					if kw_desc != "":
						text += kw_desc + "\n"
					
		# 2. 일반 트리거 처리
		for trigger in ["passive", "onUse", "onTurnStart", "onTurnEnd", "onAttack", "onHit"]:
			if abilities.has(trigger):
				var prefix = ""
				if trigger == "passive": prefix = ""
				elif trigger == "onUse" and data.get("type") == "minion": prefix = "전투의 함성: "
				elif trigger == "onUse" and data.get("type") == "magic": prefix = "" # 마법은 사용 시 접두사 생략
				elif trigger == "onTurnStart": prefix = "턴 시작 시: "
				elif trigger == "onTurnEnd": prefix = "턴 종료 시: "
				elif trigger == "onAttack": prefix = "공격 시: "
				elif trigger == "onHit": prefix = "피격 시: "
				
				var effects = abilities[trigger]
				var effect_strs = PackedStringArray()
				for eff in effects:
					effect_strs.append(CardDatabase.get_effect_description(eff, tooltips))
					
				if effect_strs.size() > 0:
					# 문장들이 이미 '.'으로 끝나므로 쉼표 대신 띄어쓰기(공백)로 자연스럽게 연결합니다.
					text += prefix + " ".join(effect_strs) + "\n"

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
		
	# [lang=en] 꼼수는 오히려 BBCode([color]) 주변의 툴팁 키워드를 쪼개버리므로 원상복구합니다!
	desc_label.text = text.strip_edges()
	
	# 수집된 툴팁들을 모아서 라벨의 툴팁으로 병합 설정
	var tooltip_str = ""
	for key in tooltips:
		tooltip_str += "- " + tooltips[key] + "\n\n"
	desc_label.tooltip_text = tooltip_str.strip_edges()
