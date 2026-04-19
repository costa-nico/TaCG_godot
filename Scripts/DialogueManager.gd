extends Control

# 대사 데이터 구조: [{"image": "res://path/to/image.png", "text": "대사 내용"}, ...]
var dialogue_data: Array = []
var current_index: int = 0

@onready var sprite: Sprite2D = $Sprite2D
@onready var text_label: Label = $Panel/TextLabel
@onready var next_button: Button = $Panel/NextButton

signal dialogue_finished

func _ready():
	hide()

func start_dialogue(data: Array):
	dialogue_data = data
	current_index = 0
	_show_current_dialogue()
	show()

func _show_current_dialogue():
	print("다이얼로그 매니저: 현재 대사: ", dialogue_data[current_index]["text"]) # 디버그용 로그
	if current_index < dialogue_data.size():
		var current = dialogue_data[current_index]
		if current.has("image"):
			sprite.texture = load(current["image"])
		text_label.text = current["text"]
	else:
		_end_dialogue()

func _gui_input(event):
	# 마우스 왼쪽 버튼이 '눌렸을 때'만 작동!!!!!
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_proceed_dialogue()

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
