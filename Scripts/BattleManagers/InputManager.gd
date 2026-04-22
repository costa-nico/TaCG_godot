extends Node


@onready var battle_scene = get_tree().current_scene
@onready var attack_line = battle_scene.get_node("UI/AttackLine")


var dragging_card: Area2D = null
var current_attack_line_end: Vector2 = Vector2.ZERO # 어택 라인의 현재 끝점을 기억 (스냅 애니메이션용)

func _process(_delta: float) -> void:
	if dragging_card:
		match dragging_card.current_state:
			dragging_card.State.DRAGGING_TO_USE:
				_handle_use_drag()
			dragging_card.State.DRAGGING_TO_ATTACK:
				_handle_attack_drag()
	else:
		_handle_hover() # 드래그 중이 아닐 때는 호버 상태를 감지합니다!

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
	battle_scene.update_hover(null) # 드래그 시작 시 호버 상태 강제 해제
	card.z_index = 100
	
	var tween = card.get_card_tween()
	tween.tween_property(card, "rotation_degrees", 0.0, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)

	if card.slot_position == -1: # 핸드에 있을 때
		if card.current_state == card.State.IN_HAND: # 완전히 손패에 있을 때만 플레이스홀더 생성 (오류로 여러번 눌리는 것 방지)
			card.current_state = card.State.DRAGGING_TO_USE
			card.create_placeholder()
			tween.parallel().tween_property(card, "scale", card.SCALE_DRAG, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	elif card.attackable > 0: # 보드에 있고 공격 가능할 때
		if card.current_state == card.State.ON_BOARD:
			card.current_state = card.State.DRAGGING_TO_ATTACK
			start_attack_line(card)


func end_drag(card):
	dragging_card = null

	match card.current_state:
		card.State.DRAGGING_TO_USE:
			check_drop(card)
		card.State.DRAGGING_TO_ATTACK:
			end_attack_line(card)
			card.current_state = card.State.ON_BOARD

func _handle_hover():
	var space_state = battle_scene.get_world_2d().direct_space_state
	var query = PhysicsPointQueryParameters2D.new()
	query.position = battle_scene.get_global_mouse_position()
	query.collide_with_areas = true
	query.collide_with_bodies = false
	
	var results = space_state.intersect_point(query)
	var top_card = null
	var max_z = -1
	
	for r in results:
		var collider = r.collider
		# 마우스 아래 걸린 Area2D가 카드이고, 내 손패에 있으며, 클릭 가능한 상태일 때 가장 오른쪽(z_index가 높은) 카드 판별
		if "current_state" in collider and collider.current_state == collider.State.IN_HAND and collider.input_pickable:
			if collider.master == battle_scene.player and collider.base_z_index > max_z:
				top_card = collider
				max_z = collider.base_z_index
				
	battle_scene.update_hover(top_card)

func _handle_use_drag():
	var card = dragging_card
	var mouse_pos = battle_scene.get_global_mouse_position()
	var what_is_under = get_target_under_mouse()

	var target_pos = mouse_pos
	
	if card.card_data["type"] == "minion":
		if what_is_under["has_slot"] and what_is_under["slot_side"] == "player" and what_is_under["is_slot_empty"]:
			target_pos = what_is_under["slot"].global_position # Area2D 슬롯의 중심 좌표를 바로 사용

	elif card.card_data["type"] == "magic":
		# 다른 영역은 무시하고, 오직 마우스가 매직 슬롯 영역(Area2D) 안에 들어왔을 때만 중앙으로 스냅!
		if what_is_under["has_magic_slot"]:
			target_pos = battle_scene.magic_slot.global_position
		
	# 매 프레임 초기화되는 트윈 대신 선형 보간(lerp)을 사용하여 
	# 마우스 이동은 부드럽게, 슬롯 위에서는 자석처럼 쫀득하게 달라붙도록 만듭니다.
	var weight = clamp(30.0 * get_process_delta_time(), 0.0, 1.0) # 프레임 저하 시 목표 위치를 초과하여 진동하는 것 방지
	card.global_position = card.global_position.lerp(target_pos, weight)


func return_to_hand(card: Area2D, _reason: String):
	print("return to hand: ", _reason)

	card.current_state = card.State.IN_HAND
	
	# 부모 노드가 컨테이너가 아니라면(최상단으로 빠져나왔다면) 다시 넣어줌
	if card.get_parent() != battle_scene.card_container:
		card.reparent(battle_scene.card_container)

	if is_instance_valid(card.placeholder): 
		var target_idx = card.placeholder.get_index()
		card.remove_placeholder()
		battle_scene.card_container.move_child(card, target_idx)
			
	_handle_hover() # 드래그 종료 직후 마우스 위치를 검사해 호버 상태 즉시 갱신
	battle_scene.reposition_hand(battle_scene.player) # 별도 트윈 없이 정렬 함수에 애니메이션 일임

func handle_right_click(card):
	if card.current_state == card.State.DRAGGING_TO_ATTACK:
		attack_line.visible = false
		battle_scene.set_target_highlights(card, false) # 우클릭 취소 시 하이라이트 끄기
		card.current_state = card.State.ON_BOARD
		dragging_card = null
	elif card.current_state == card.State.DRAGGING_TO_USE:
		dragging_card = null
		return_to_hand(card, "우클릭으로 손패로 돌아감")
		

func check_drop(card: Area2D):
	var what_is_under = get_target_under_mouse()
	if card.card_data["type"] == "minion":
		if what_is_under["has_slot"] and what_is_under["slot_side"] == "player" and what_is_under["is_slot_empty"]:
			if not _try_consume_mana_and_drop(card): return
			# BattleScene의 summon_to_slot 시그니처(card, index, master)에 맞춰 호출
			card.z_index = 0
			battle_scene.summon_to_slot(card, what_is_under["slot_index"], battle_scene.player)
			card.remove_placeholder()
			return
		else:
			return_to_hand(card, "아군의 빈슬롯이 아닙니다.")
			return

	elif card.card_data["type"] == "magic":
		# 마법 슬롯, 일반 빈 슬롯, 미니언, 마스터 등 전장 영역 어디든 시전 가능하도록 조건 확대!
		if what_is_under["has_magic_slot"] or what_is_under["has_slot"] or what_is_under["has_minion"] or what_is_under["has_master"]:
			if not _try_consume_mana_and_drop(card): return
			card.remove_placeholder()
			card.z_index = 0
			battle_scene.cast_magic(card, battle_scene.player)
			return
		else:
			return_to_hand(card, "마법을 시전할 전장 영역에 놓아주세요.")
			return

func _try_consume_mana_and_drop(card: Area2D) -> bool:
	if battle_scene.player.use_mana(card.card_data["cost"]) == false:
		return_to_hand(card, "마나 부족 (현재 마나: %d)" % battle_scene.player.mana)
		return false
	return true

func _handle_attack_drag():
	var card = dragging_card
	update_attack_line(card.global_position)


func start_attack_line(attacker):
	attack_line.visible = true
	current_attack_line_end = battle_scene.get_global_mouse_position() # 시작 시 끝점을 마우스 위치로 초기화
	battle_scene.set_target_highlights(attacker, true) # 타겟 하이라이트 켜기
	update_attack_line(attacker.global_position) # 즉시 렌더링

func update_attack_line(start_pos):
	var what_is_under = get_target_under_mouse()
	
	var target = _get_enemy_target_from_info(what_is_under)
	var desired_target_pos = battle_scene.get_global_mouse_position()
		
	if target and battle_scene._is_targetable(dragging_card, target):
		desired_target_pos = target.global_position if target is Area2D else target.avatar.global_position

	# 끝점이 즉시 이동하지 않고 매 프레임 목표 지점(마우스 or 타겟 중앙)을 향해 부드럽게 쫓아가도록 보간(Lerp) 적용
	var weight = clamp(30.0 * get_process_delta_time(), 0.0, 1.0)
	current_attack_line_end = current_attack_line_end.lerp(desired_target_pos, weight)

	# 2차 베지어 곡선(Quadratic Bezier Curve)을 활용한 동적 포물선 그리기
	attack_line.clear_points()
	var mid_point = (start_pos + current_attack_line_end) / 2.0
	var distance = start_pos.distance_to(current_attack_line_end)
	mid_point.y -= distance * 0.25 # 타겟과의 거리가 멀수록 아치가 더 높게 휘어짐
	
	var segments = 15 # 선을 부드럽게 나눌 횟수 (다각형의 수)
	for i in range(segments + 1):
		var t = float(i) / segments
		var q0 = start_pos.lerp(mid_point, t)
		var q1 = mid_point.lerp(current_attack_line_end, t)
		attack_line.add_point(q0.lerp(q1, t))

func end_attack_line(attacker):
	attack_line.visible = false
	battle_scene.set_target_highlights(attacker, false) # 타겟 하이라이트 끄기
	var what_is_under = get_target_under_mouse()

	var target = _get_enemy_target_from_info(what_is_under)

	if target and battle_scene._is_targetable(attacker, target):
		battle_scene.attack_with_minion(attacker, target)
	else:
		print("Attack Cancel: 공격 대상이 없음")

func _get_enemy_target_from_info(what_is_under: Dictionary):
	if what_is_under["has_minion"] and what_is_under["minion_side"] == "enemy":
		return what_is_under["minion"]
	elif what_is_under["has_master"] and what_is_under["master_side"] == "enemy":
		return what_is_under["master"]
	return null

func get_target_under_mouse() -> Dictionary:
	# 마우스 아래의 모든 정보를 담는 종합 딕셔너리
	var info = {
		"has_minion": false, "minion": null, "minion_side": "none",
		"has_master": false, "master": null, "master_side": "none",
		"has_slot": false, "slot": null, "slot_index": -1, "slot_side": "none", "is_slot_empty": false,
		"has_magic_slot": false, "magic_slot": null
	}

	var space_state = battle_scene.get_world_2d().direct_space_state
	var query = PhysicsPointQueryParameters2D.new()
	query.position = battle_scene.get_global_mouse_position()
	query.collide_with_areas = true # Area2D를 감지하도록 켜!!!
	query.collide_with_bodies = false

	if dragging_card and is_instance_valid(dragging_card):
		query.exclude = [dragging_card.get_rid()]

	var results = space_state.intersect_point(query)

	if results.is_empty():
		return info

	var colliders = results.map(func(r): return r.collider)

	# 모든 콜라이더를 순회하며 info 딕셔너리를 채웁니다.
	for target in colliders:
		if target in battle_scene.enemy.slot:
			info["has_minion"] = true
			info["minion"] = target
			info["minion_side"] = "enemy"
		elif target in battle_scene.player.slot:
			info["has_minion"] = true
			info["minion"] = target
			info["minion_side"] = "player"
			
		if target == battle_scene.enemy.avatar:
			info["has_master"] = true
			info["master"] = battle_scene.enemy
			info["master_side"] = "enemy"
		elif target == battle_scene.player.avatar:
			info["has_master"] = true
			info["master"] = battle_scene.player
			info["master_side"] = "player"
			
		if target in battle_scene.player_slot_nodes:
			info["has_slot"] = true
			info["slot"] = target
			info["slot_index"] = battle_scene.player_slot_nodes.find(target)
			info["slot_side"] = "player"
			info["is_slot_empty"] = (battle_scene.player.slot[info["slot_index"]] == null)
		elif target in battle_scene.enemy_slot_nodes:
			info["has_slot"] = true
			info["slot"] = target
			info["slot_index"] = battle_scene.enemy_slot_nodes.find(target)
			info["slot_side"] = "enemy"
			info["is_slot_empty"] = (battle_scene.enemy.slot[info["slot_index"]] == null)

		if target == battle_scene.magic_slot:
			info["has_magic_slot"] = true
			info["magic_slot"] = target

	return info
