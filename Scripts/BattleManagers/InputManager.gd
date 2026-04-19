extends Node


@onready var battle_scene = get_tree().current_scene
@onready var attack_line = battle_scene.get_node("UI/AttackLine")


var dragging_card: Area2D = null
var drag_tween: Tween

func _process(_delta: float) -> void:
	if not dragging_card: return # 드래그 중이 아니면 아무것도 안 해!!!!!

	match dragging_card.current_state:
		dragging_card.State.DRAGGING_TO_USE:
			_handle_use_drag()
		dragging_card.State.DRAGGING_TO_ATTACK:
			_handle_attack_drag()

# 글로벌 입력 감지: Area2D 바깥으로 마우스가 나간 상태에서 클릭을 뗄 때를 대비함 (공격 버그 해결)
func _input(event: InputEvent) -> void:
	if dragging_card != null:
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
				end_drag(dragging_card)
			elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
				handle_right_click(dragging_card)
				get_viewport().set_input_as_handled()

func start_drag(card):
	dragging_card = card
	card.z_index = 100
	if card.slot_position == -1: # 핸드에 있을 때
		if card.current_state == card.State.IN_HAND: # 완전히 손패에 있을 때만 플레이스홀더 생성 (오류로 여러번 눌리는 것 방지)
			card.current_state = card.State.DRAGGING_TO_USE
			card.create_placeholder()
			card.animate_scale(card.SCALE_DRAG)
			card.top_level = true
	elif card.attackable > 0: # 보드에 있고 공격 가능할 때
		if card.current_state == card.State.ON_BOARD:
			card.current_state = card.State.DRAGGING_TO_ATTACK
			start_attack_line(card)


func end_drag(card):
	if drag_tween and drag_tween.is_valid():
		drag_tween.kill() # 드롭 시 카드 위치를 덮어씌우는 이전 트윈을 강제 종료

	dragging_card = null
	card.z_index = 0

	match card.current_state:
		card.State.DRAGGING_TO_USE:
			check_drop(card)
		card.State.DRAGGING_TO_ATTACK:
			end_attack_line(card)
			card.current_state = card.State.ON_BOARD

func _handle_use_drag():
	var card = dragging_card
	var mouse_pos = battle_scene.get_global_mouse_position()
	var what_is_under = get_target_under_mouse()

	var target_pos = mouse_pos
	print(what_is_under) # 디버그용 로그: 마우스 아래에 무엇이 있는지 출력
	if card.card_data["type"] == "minion":
		if what_is_under["type"] == "slot" and what_is_under["side"] == "player":
			var target_slot = what_is_under["object"]
			target_pos = target_slot.global_position # Area2D 슬롯의 중심 좌표를 바로 사용

	elif card.card_data["type"] == "magic":
		if what_is_under["type"] == "magic_slot" || what_is_under["type"] == "slot": # 마법 슬롯 또는 일반 슬롯 위에 있을 때
			target_pos = what_is_under["object"].global_position # 마법 슬롯 중앙으로 착! 스냅
		
	# 매 프레임 초기화되는 트윈 대신 선형 보간(lerp)을 사용하여 
	# 마우스 이동은 부드럽게, 슬롯 위에서는 자석처럼 쫀득하게 달라붙도록 만듭니다.
	var weight = clamp(30.0 * get_process_delta_time(), 0.0, 1.0) # 프레임 저하 시 목표 위치를 초과하여 진동하는 것 방지
	card.global_position = card.global_position.lerp(target_pos, weight)


func return_to_hand(card: Area2D, _reason: String):
	print("return to hand: ", _reason)

	battle_scene.set_input_lock(true) # 입력 잠금 
	card.current_state = card.State.IN_HAND
	card.input_pickable = false
	card.z_index = 0
	card.animate_scale(card.SCALE_HAND)

	if not is_instance_valid(card.placeholder): 
		# 플레이스홀더가 없는 비정상적인 상황에 대한 안전장치 (화면에 멈추는 것 방지)
		battle_scene.set_input_lock(false)
		card.top_level = false
		card.input_pickable = true
		if card.get_parent() != battle_scene.card_container:
			card.reparent(battle_scene.card_container)
		battle_scene.reposition_hand(battle_scene.player)
		return

	var target_pos = card.placeholder.global_position

	# 2. 위치 복귀 애니메이션
	var tween = create_tween()
	tween.tween_property(card, "global_position", target_pos, 0.1)\
		.set_ease(Tween.EASE_IN_OUT)
	# 3. 완료 후 정리 작업
	tween.finished.connect(func():
		var target_idx = card.placeholder.get_index()
		battle_scene.set_input_lock(false) # 입력 잠금 해제
		card.remove_placeholder()

		card.top_level = false
		if card.get_parent() != battle_scene.card_container:
			card.reparent(battle_scene.card_container)

		battle_scene.card_container.move_child(card, target_idx)
		card.input_pickable = true
		battle_scene.reposition_hand(battle_scene.player) # 손패 겹침을 방지하기 위해 정렬 갱신
	)

func handle_right_click(card):
	if drag_tween and drag_tween.is_valid():
		drag_tween.kill()

	if card.current_state == card.State.DRAGGING_TO_ATTACK:
		print("공격 취소: 우클릭으로 공격 취소")
		attack_line.visible = false
		card.current_state = card.State.ON_BOARD
		card.z_index = 0
	elif card.current_state == card.State.DRAGGING_TO_USE:
		return_to_hand(card, "우클릭으로 손패로 돌아감")
		
	dragging_card = null # 취소 후 드래그 변수 초기화
	

func check_drop(card: Area2D):
	var what_is_under = get_target_under_mouse()
	if card.card_data["type"] == "minion":
		if what_is_under["type"] == "slot" and what_is_under["side"] == "player":
			if battle_scene.player.use_mana(card.card_data["cost"]) == false:
				print("소환	실패: 마나 부족")
				return_to_hand(card, "마나 부족%d" % battle_scene.player.mana)
				return	
			# BattleScene의 summon_to_slot 시그니처(card, index, master)에 맞춰 호출
			battle_scene.summon_to_slot(card, what_is_under["index"], battle_scene.player)
			card.remove_placeholder()
			return
		else:
			return_to_hand(card, "아군의 빈슬롯이 아닙니다.")
			return

	elif card.card_data["type"] == "magic":
		# 마법 슬롯뿐만 아니라 일반 슬롯에 놓았을 때도 마법이 시전되도록 조건을 추가합니다.
		if what_is_under["type"] == "magic_slot" or what_is_under["type"] == "slot":
			if battle_scene.player.use_mana(card.card_data["cost"]) == false:
				print("마법 실패: 마나 부족")
				return_to_hand(card, "마나 부족%d" % battle_scene.player.mana)
				return	
			card.remove_placeholder()
			battle_scene.cast_magic(card, battle_scene.player)
			return
		else:
			return_to_hand(card, "마법을 시전할 슬롯에 놓아주세요.")
			return



func _handle_attack_drag():
	var card = dragging_card
	update_attack_line(card.global_position)


func start_attack_line(attacker):
	attack_line.clear_points()
	attack_line.add_point(attacker.global_position)
	attack_line.add_point(battle_scene.get_global_mouse_position())
	attack_line.visible = true

func update_attack_line(start_pos):
	attack_line.set_point_position(0, start_pos)
	var what_is_under = get_target_under_mouse()
	if what_is_under["type"] == "master" and what_is_under["side"] == "enemy" and battle_scene._is_targetable(dragging_card, what_is_under["object"]):
		attack_line.set_point_position(1, battle_scene.enemy.avatar.global_position)
	elif what_is_under["type"] == "minion" and what_is_under["side"] == "enemy" and battle_scene._is_targetable(dragging_card, what_is_under["object"]):
		attack_line.set_point_position(1, what_is_under["object"].global_position)
	else:
		attack_line.set_point_position(1, battle_scene.get_global_mouse_position())

func end_attack_line(attacker):
	attack_line.visible = false
	var what_is_under = get_target_under_mouse()

	if what_is_under["side"] == "enemy" and battle_scene._is_targetable(attacker, what_is_under["object"]):
		battle_scene.attack_with_minion(attacker, what_is_under["object"])
	else:
		print("Attack Cancel: 공격 대상이 없음")


func get_target_under_mouse() -> Dictionary:
	# 1. 물리 엔진의 쿼리 시스템을 가져와!!!
	var space_state = battle_scene.get_world_2d().direct_space_state
	var query = PhysicsPointQueryParameters2D.new()
	query.position = battle_scene.get_global_mouse_position()
	query.collide_with_areas = true # Area2D를 감지하도록 켜!!!
	query.collide_with_bodies = false

	# 드래그 중인 카드 자신은 마우스 물리 판정에서 완전히 무시하여 "자기 자신을 인식"하는 버그를 원천 차단합니다!
	if dragging_card and is_instance_valid(dragging_card):
		query.exclude = [dragging_card.get_rid()]

	# 2. 마우스 좌표에 있는 모든 콜리전을 배열로 반환!!!
	var results = space_state.intersect_point(query)

	if results.is_empty():
		return {"type": "none", "index": -1, "object": null, "side": "none"}

	# 3. 충돌한 콜리전들을 확인하기 편하게 배열로 추출합니다.
	var colliders = []
	for r in results:
		colliders.append(r.collider)

	# 우선순위 1: 미니언 (가장 최상단 판정)
	for target in colliders:
		if target in battle_scene.enemy.slot:
			return {"type": "minion", "object": target, "side": "enemy"}
		if target in battle_scene.player.slot:
			return {"type": "minion", "object": target, "side": "player"}

	# 우선순위 2: 마스터 (본체)
	for target in colliders:
		if target == battle_scene.enemy.avatar:
			return {"type": "master", "object": battle_scene.enemy, "side": "enemy"}
		if target == battle_scene.player.avatar:
			return {"type": "master", "object": battle_scene.player, "side": "player"}

	# 우선순위 3: 일반 슬롯 (마법 슬롯과 겹쳐있을 경우 무조건 일반 슬롯 우선 판정!)
	for target in colliders:
		if target in battle_scene.player_slot_nodes:
			var idx = battle_scene.player_slot_nodes.find(target)
			if battle_scene.player.slot[idx] == null:
				return {"type": "slot", "index": idx, "object": target, "side": "player"}
		if target in battle_scene.enemy_slot_nodes:
			var idx = battle_scene.enemy_slot_nodes.find(target)
			if battle_scene.enemy.slot[idx] == null:
				return {"type": "slot", "index": idx, "object": target, "side": "enemy"}

	# 우선순위 4: 마법 슬롯 (가장 넓게 깔려 있으므로 최하위 판정)
	for target in colliders:
		if target == battle_scene.magic_slot:
			return {"type": "magic_slot", "object": target, "side": "none"}

	return {"type": "none", "index": -1, "object": null, "side": "none"}
