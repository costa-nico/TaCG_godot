extends Control

# 대사 데이터 구조: [{"image": "res://path/to/image.png", "text": "대사 내용"}, ...]
var dialogue_data: Array = []
var current_index: int = 0
var is_waiting_for_choice: bool = false

@onready var sprite: TextureRect = $TextureRect # 텍스처렉트로 바꾸셨다면 노드 이름을 TextureRect로 맞춰주세요!
@onready var text_label: Label = $Panel/MarginContainer/TextLabel

@onready var option_container: VBoxContainer = $OptionContainer
@onready var template_button: Button = $OptionContainer/TemplateButton
@onready var timer_node: Timer = $Timer
@onready var time_label: Label = $TimeLabel

signal dialogue_finished
signal choice_made(option_data)

func _ready():
	# 템플릿 버튼은 게임 시작 시 안 보이게 숨깁니다
	if template_button: template_button.hide() 
	if timer_node: timer_node.timeout.connect(_on_time_out)
	
	# 코드로 TextureRect 비율 유지 및 중앙 정렬 완벽하게 박아넣기!
	if sprite:
		sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE # 노드 크기를 맘대로 조절 가능하게 허용
		sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED # 비율을 무조건 유지하면서 중앙 정렬!
		sprite.set_anchors_preset(Control.PRESET_FULL_RECT) # 화면(또는 부모)에 꽉 차게 앵커 고정
		
	hide()

func start_dialogue(data: Array):
	dialogue_data = data
	current_index = 0
	is_waiting_for_choice = false
	_show_current_dialogue()
	show()
	
	# 다이얼로그가 열릴 때 InputManager의 상태를 강제로 UI_OPEN으로 변경
	var battle_scene = get_tree().current_scene
	if battle_scene and battle_scene.input_manager:
		battle_scene.input_manager.set_state(battle_scene.input_manager.InputState.UI_OPEN)

func _process(_delta):
	if not timer_node.is_stopped():
		time_label.text = "남은 시간: %.1f초" % timer_node.time_left

func _show_current_dialogue():
	_clear_options()
	timer_node.stop()
	time_label.text = ""
	is_waiting_for_choice = false
	
	if current_index < dialogue_data.size():
		var current = dialogue_data[current_index]
		if current.has("image"):
			# 스프라이트가 없는 경우를 대비한 안전 코드
			if sprite: sprite.texture = load(current["image"])
		text_label.text = current.get("text", "")
		
		# 대사가 화면에 출력될 때 효과(Effect)가 있다면 즉시 발동!
		if current.has("effect"):
			var battle_scene = get_tree().current_scene
			if battle_scene and battle_scene.ability_manager:
				battle_scene.ability_manager._execute_effect(current["effect"], battle_scene.player, battle_scene.player)
				
		# 대사에 선택지가 포함되어 있다면 버튼 생성
		if current.has("options"):
			_setup_options(current)
	else:
		_end_dialogue()

func _setup_options(data: Dictionary):
	is_waiting_for_choice = true
	var options = data["options"]
	var battle_scene = get_tree().current_scene
	
	# [매혹 판정] CHARM 스택당 10%의 확률로 이성적 판단 상실!
	var charm_stacks = battle_scene.player.status_effects.get("CHARM", 0)
	var charm_chance = charm_stacks * 0.1 
	var is_charmed = randf() < charm_chance
	
	var lock_indices = data.get("charm_lock_index", [])
	if typeof(lock_indices) != TYPE_ARRAY:
		lock_indices = [lock_indices]
		
	if is_charmed and not lock_indices.is_empty():
		text_label.text = "(매혹되어 이성적인 판단이 힘듭니다...)\n\n" + text_label.text
		
	# 정상 상태: 선택지 버튼 생성
	for i in range(options.size()):
		var opt = options[i]
		# 템플릿 버튼을 복사해서 사용!
		var btn = template_button.duplicate() if template_button else Button.new()
		btn.text = opt["text"]
		btn.pressed.connect(func(): _on_option_selected(opt))
		
		if is_charmed and i in lock_indices:
			btn.disabled = true
			btn.text += " (잠김)"
			
		btn.show() # 복사본은 눈에 보이게 켭니다
		option_container.add_child(btn)
		
	# 시간 제한 타이머 가동
	if data.has("time_limit"):
		timer_node.start(data["time_limit"])

func _clear_options():
	for child in option_container.get_children():
		# 템플릿 원본은 지우면 안 되므로 제외하고 삭제
		if child != template_button:
			child.queue_free()

func _on_time_out():
	if current_index >= dialogue_data.size(): return
	var current = dialogue_data[current_index]
	var force_index = current.get("timeout_index", 0) # 타임아웃 시 강제 발동할 인덱스
	var options = current.get("options", [])
	if options.size() > force_index:
		_on_option_selected(options[force_index])

func _on_option_selected(opt: Dictionary):
	var battle_scene = get_tree().current_scene
	# 선택지에 카드 능력과 똑같은 effect가 들어있다면, 어빌리티 매니저를 통해 발동!
	if opt.has("effect") and battle_scene and battle_scene.ability_manager:
		battle_scene.ability_manager._execute_effect(opt["effect"], battle_scene.player, battle_scene.player)
		
	emit_signal("choice_made", opt)
	
	# 선택지에 다음 이어질 대화(next_dialogue)가 있다면 해당 대화로 분기(Branch)
	if opt.has("next_dialogue"):
		start_dialogue(opt["next_dialogue"])
	else:
		_proceed_dialogue()

func _gui_input(event):
	if is_waiting_for_choice: return # 선택 중에는 일반 클릭으로 넘어갈 수 없음!
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_proceed_dialogue() # 좌클릭: 다음 대사로 진행
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			# 우클릭: 뒤에 강제 선택지(미인계)가 있다면 그곳으로 고속 스킵, 없다면 대화 즉시 종료
			var found_choice = false
			for i in range(current_index, dialogue_data.size()):
				if dialogue_data[i].has("options"):
					current_index = i
					_show_current_dialogue()
					found_choice = true
					break
			if not found_choice:
				_end_dialogue()

func _proceed_dialogue():
	current_index += 1

	if current_index < dialogue_data.size():
		_show_current_dialogue()
	else:
		_end_dialogue()


func _end_dialogue():
	hide()
	if timer_node: timer_node.stop() # 대화가 끝나면 무조건 타이머 멈추기 (잠재적 버그 차단)
	emit_signal("dialogue_finished")
	dialogue_data.clear()
	
	# 창이 완전히 닫히면 InputManager를 다시 대기(IDLE) 상태로 돌려놓음
	var battle_scene = get_tree().current_scene
	if battle_scene and battle_scene.input_manager:
		battle_scene.input_manager.set_state(battle_scene.input_manager.InputState.IDLE)
