extends Control

# 대사 데이터 구조: [{"image": "res://path/to/image.png", "text": "대사 내용"}, ...]
var dialogue_data: Array = []
var current_index: int = 0

@onready var sprite: Sprite2D = $Sprite2D
@onready var text_label: Label = $Panel/MarginContainer/TextLabel

signal dialogue_finished

func _ready():
	hide()

func start_dialogue(data: Array):
	dialogue_data = data
	current_index = 0
	_show_current_dialogue()
	show()
	
	# 다이얼로그가 열릴 때 InputManager의 상태를 강제로 UI_OPEN으로 변경
	var battle_scene = get_tree().current_scene
	if battle_scene and battle_scene.input_manager:
		battle_scene.input_manager.set_state(battle_scene.input_manager.InputState.UI_OPEN)

func _show_current_dialogue():
	print("다이얼로그 매니저: 현재 대사: ", dialogue_data[current_index]["text"]) # 디버그용 로그
	if current_index < dialogue_data.size():
		var current = dialogue_data[current_index]
		if current.has("image"):
			# 스프라이트가 없는 경우를 대비한 안전 코드
			if sprite: sprite.texture = load(current["image"])
		text_label.text = current["text"]
	else:
		_end_dialogue()

func _gui_input(event):
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_proceed_dialogue() # 좌클릭: 다음 대사로 진행
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_end_dialogue()     # 우클릭: 대화 즉시 종료

func _proceed_dialogue():
	print("다이얼로그 매니저: 다음 버튼 눌림") # 디버그용 로그
	current_index += 1

	if current_index < dialogue_data.size():
		_show_current_dialogue()
	else:
		_end_dialogue()


func _end_dialogue():
	print("다이얼로그 매니저: 대사 종료") # 디버그용 로그
	hide()
	emit_signal("dialogue_finished")
	dialogue_data.clear()
	
	# 창이 완전히 닫히면 InputManager를 다시 대기(IDLE) 상태로 돌려놓음
	var battle_scene = get_tree().current_scene
	if battle_scene and battle_scene.input_manager:
		battle_scene.input_manager.set_state(battle_scene.input_manager.InputState.IDLE)
