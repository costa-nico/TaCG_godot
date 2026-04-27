extends Control

# 에디터에서 구성해야 할 UI 노드들
@onready var pool_container = $HBoxContainer/PoolPanel/ScrollContainer/VBoxContainer # 모든 카드 목록
@onready var deck_container = $HBoxContainer/DeckPanel/ScrollContainer/VBoxContainer # 내 덱 목록
@onready var save_button = $SaveButton
@onready var count_label = $CountLabel

var temp_deck: Dictionary = {}

func _ready():
	# 저장되어 있는 덱 정보를 임시로 복사해옵니다. (저장 전까지는 원본 유지)
	temp_deck = DeckLib.get_player_deck().duplicate()
	
	if save_button:
		save_button.pressed.connect(_on_save_pressed)
		
	_refresh_ui()

func _refresh_ui():
	# 1. 화면의 기존 버튼들 비우기
	for child in pool_container.get_children(): child.queue_free()
	for child in deck_container.get_children(): child.queue_free()

	var total_cards = 0
	
	# 2. 모든 보유 가능 카드 목록 띄우기 (왼쪽 패널)
	for card_id in CardDatabase.card_list.keys():
		if card_id == "DUMMY": continue # 더미 카드는 숨김
		var card_data = CardDatabase.get_card_by_id(card_id)
		var btn = Button.new()
		btn.text = "%s 추가" % card_data["name"]
		btn.pressed.connect(func(): _add_card(card_id))
		pool_container.add_child(btn)

	# 3. 현재 내 덱 목록 띄우기 (오른쪽 패널)
	for card_id in temp_deck.keys():
		var count = temp_deck[card_id]
		total_cards += count
		var card_data = CardDatabase.get_card_by_id(card_id)
		var btn = Button.new()
		btn.text = "%s [x%d] (빼기)" % [card_data["name"], count]
		btn.pressed.connect(func(): _remove_card(card_id))
		deck_container.add_child(btn)
		
	if count_label:
		count_label.text = "현재 덱 장수: " + str(total_cards)

func _add_card(card_id: String):
	temp_deck[card_id] = temp_deck.get(card_id, 0) + 1
	_refresh_ui() # 갱신

func _remove_card(card_id: String):
	if temp_deck.has(card_id):
		temp_deck[card_id] -= 1
		if temp_deck[card_id] <= 0:
			temp_deck.erase(card_id)
	_refresh_ui() # 갱신

func _on_save_pressed():
	# 변경된 덱 정보를 DeckLib에 덮어씌우고 실제 파일로 저장!
	DeckLib.player_deck = temp_deck.duplicate()
	DeckLib.save_deck()
	
	# 메인 화면으로 돌아가기 (경로 수정 필요)
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")