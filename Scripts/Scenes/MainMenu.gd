extends Control

# 씬 경로 (실제 프로젝트의 씬 경로에 맞게 수정해 주세요!)
const BATTLE_SCENE_PATH = "res://scenes/BattleScene.tscn"
const DECK_EDIT_SCENE_PATH = "res://scenes/DeckEditScene.tscn"

@onready var edit_deck_button: Button = $VBoxContainer/EditDeckButton
@onready var button_container: VBoxContainer = $VBoxContainer

func _ready():
	# 버튼 클릭 시그널 연결
	if edit_deck_button:
		edit_deck_button.pressed.connect(_on_edit_deck_pressed)

	# 적 목록을 순회하며 동적으로 전투 버튼들을 VBoxContainer 아래에 계속 추가
	for enemy_id in EnemyDatabase.enemy_list.keys():
		var enemy = EnemyDatabase.enemy_list[enemy_id]
		var btn = Button.new()
		btn.text = "⚔️ %s와(과) 전투" % enemy["name"]
		
		# UI가 찌그러져서 안 보이는 현상을 막기 위해 최소 높이를 60픽셀로 큼직하게 고정합니다!
		btn.custom_minimum_size = Vector2(0, 60) 
		
		btn.pressed.connect(func(): _start_battle_with(enemy_id))
		button_container.add_child(btn)

func _start_battle_with(enemy_id: String):
	print("전투 시작! 상대 ID: ", enemy_id)
	EnemyDatabase.current_enemy_id = enemy_id # 현재 어떤 적과 싸우는지 DB에 기록!
	DeckLib.set_enemy_deck_by_id(enemy_id) # 선택한 적의 덱으로 교체!
	get_tree().change_scene_to_file(BATTLE_SCENE_PATH)

func _on_edit_deck_pressed():
	print("덱 편집 화면으로 이동!")
	get_tree().change_scene_to_file(DECK_EDIT_SCENE_PATH)