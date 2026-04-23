extends Node


@onready var battle_scene = get_tree().current_scene
@onready var attack_line = battle_scene.get_node("UI/AttackLine")


var dragging_card: Area2D = null
var current_attack_line_end: Vector2 = Vector2.ZERO # 어택 라인의 현재 끝점을 기억 (스냅 애니메이션용)

var target_selection_card: Area2D = null
var pending_drop_info: Dictionary = {}

enum InputState {
	IDLE,
	DRAGGING_CARD,
	UI_OPEN,
	SELECTING_TARGET
}

var current_state: InputState = InputState.IDLE

var drag_start_pos: Vector2 = Vector2.ZERO
var drag_start_time: int = 0

var possible_click_card: Area2D = null # 드래그가 불가능한 전장 카드(적 등)의 클릭 감지용

func set_state(new_state: InputState) -> void:
	if current_state == new_state:
		return
		
	var old_state = current_state
	
	if new_state == InputState.UI_OPEN:
		battle_scene.update_hover(null)
		if old_state == InputState.DRAGGING_CARD and is_instance_valid(dragging_card):
			handle_right_click(dragging_card)
		possible_click_card = null
		
	current_state = new_state

func _process(_delta: float) -> void:
	match current_state:
		InputState.DRAGGING_CARD:
			if dragging_card:
				match dragging_card.current_state:
					dragging_card.State.DRAGGING_TO_USE:
						_handle_use_drag()
					dragging_card.State.DRAGGING_TO_ATTACK:
						_handle_attack_drag()
		InputState.SELECTING_TARGET:
			if is_instance_valid(target_selection_card):
				update_attack_line(target_selection_card.global_position)
		InputState.IDLE:
			_handle_hover() # 대기 상태일 때만 호버를 감지합니다

# 글로벌 입력 감지: Area2D 바깥으로 마우스가 나간 상태에서 클릭을 뗄 때를 대비함 (공격 버그 해결)
func _input(event: InputEvent) -> void:
	match current_state:
		InputState.UI_OPEN:
			return # UI 창이 열려있을 때는 전장 클릭/호버 완벽 차단
		InputState.IDLE:
			_handle_idle_input(event)
		InputState.DRAGGING_CARD:
			_handle_drag_input(event)
		InputState.SELECTING_TARGET:
			if event is InputEventMouseButton:
				if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
					_confirm_target_selection()
					get_viewport().set_input_as_handled()
				elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
					_cancel_target_selection()
					get_viewport().set_input_as_handled()

func _handle_idle_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				possible_click_card = _get_card_under_mouse()
				drag_start_pos = battle_scene.get_global_mouse_position()
				drag_start_time = Time.get_ticks_msec()

				if possible_click_card != null and possible_click_card.master == battle_scene.player and battle_scene.current_master == battle_scene.player:
					start_drag(possible_click_card)
					get_viewport().set_input_as_handled()
			else:
				var dist = battle_scene.get_global_mouse_position().distance_to(drag_start_pos)
				var time_elapsed = Time.get_ticks_msec() - drag_start_time

				if possible_click_card != null:
					if dist < 15.0 and time_elapsed < 250:
						if battle_scene.has_method("show_description"):
							battle_scene.show_description(possible_click_card)
				
				possible_click_card = null

func _handle_drag_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			var dist = battle_scene.get_global_mouse_position().distance_to(drag_start_pos)
			var time_elapsed = Time.get_ticks_msec() - drag_start_time

			if dragging_card != null:
				if dist < 15.0 and time_elapsed < 250:
					var clicked_card = dragging_card
					handle_right_click(clicked_card)
					if battle_scene.has_method("show_description"):
						battle_scene.show_description(clicked_card)
				else:
					end_drag(dragging_card)
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			if dragging_card != null:
				handle_right_click(dragging_card)
				get_viewport().set_input_as_handled()

func start_drag(card):
	set_state(InputState.DRAGGING_CARD)
	drag_start_pos = battle_scene.get_global_mouse_position()
	drag_start_time = Time.get_ticks_msec()
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
		card.State.ON_BOARD:
			card.z_index = 0
			
	if current_state != InputState.SELECTING_TARGET:
		set_state(InputState.IDLE)

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
			target_pos = what_is_under["slot"].global_position
	elif card.card_data["type"] == "magic":
		if what_is_under["has_magic_slot"] or what_is_under["has_slot"] or what_is_under["has_minion"] or what_is_under["has_master"]:
			target_pos = battle_scene.magic_slot.global_position
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
		card.z_index = 0
		dragging_card = null
	elif card.current_state == card.State.ON_BOARD:
		card.z_index = 0
		dragging_card = null
	elif card.current_state == card.State.DRAGGING_TO_USE:
		dragging_card = null
		return_to_hand(card, "우클릭으로 손패로 돌아감")
		
	set_state(InputState.IDLE)
		

func check_drop(card: Area2D):
	var what_is_under = get_target_under_mouse()
	if card.card_data["type"] == "minion":
		if what_is_under["has_slot"] and what_is_under["slot_side"] == "player" and what_is_under["is_slot_empty"]:
			if battle_scene.ability_manager.needs_target(card.card_data):
				start_target_selection(card, what_is_under)
				return
				
			if not _try_consume_mana_and_drop(card): return
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
			if battle_scene.ability_manager.has_targeting_ability(card.card_data):
				if battle_scene.ability_manager.needs_target(card.card_data):
					start_target_selection(card, what_is_under)
					return
				else:
					return_to_hand(card, "지정할 수 있는 대상이 없습니다.")
					return
				
			if not _try_consume_mana_and_drop(card): return
			card.remove_placeholder()
			card.z_index = 0
			battle_scene.cast_magic(card, battle_scene.player)
			return
		else:
			return_to_hand(card, "마법을 시전할 전장 영역에 놓아주세요.")
			return

func start_target_selection(card: Area2D, drop_info: Dictionary):
	target_selection_card = card
	pending_drop_info = drop_info
	
	if card.card_data["type"] == "minion":
		card.global_position = drop_info["slot"].global_position
	elif card.card_data["type"] == "magic":
		card.global_position = battle_scene.magic_slot.global_position
		
	card.z_index = 100
	set_state(InputState.SELECTING_TARGET)
	start_attack_line(card)

func _confirm_target_selection():
	var what_is_under = get_target_under_mouse()
	var target = null
	
	if what_is_under["has_minion"]: target = what_is_under["minion"]
	elif what_is_under["has_master"]: target = what_is_under["master"]
	
	var is_valid = target != null and battle_scene.ability_manager.is_valid_target(target_selection_card.card_data, target)
	
	if not is_valid:
		if target_selection_card.card_data["type"] == "minion":
			target = null # 미니언은 잘못된 대상이나 빈 공간 클릭 시 능력 증발 후 소환만 진행
		else:
			_cancel_target_selection("유효한 대상을 지정해야 합니다.")
			return
		
	if not _try_consume_mana_and_drop(target_selection_card):
		_cancel_target_selection("마나 부족")
		return
		
	var card = target_selection_card
	var info = pending_drop_info
	
	attack_line.visible = false
	battle_scene.set_target_highlights(card, false)
	set_state(InputState.IDLE)
	
	target_selection_card = null
	pending_drop_info = {}
	
	card.remove_placeholder()
	card.z_index = 0
	
	if card.card_data["type"] == "minion":
		battle_scene.summon_to_slot(card, info["slot_index"], battle_scene.player, target)
	elif card.card_data["type"] == "magic":
		battle_scene.cast_magic(card, battle_scene.player, target)

func _cancel_target_selection(reason: String = "타겟 지정 취소됨"):
	attack_line.visible = false
	if is_instance_valid(target_selection_card):
		battle_scene.set_target_highlights(target_selection_card, false)
		var card = target_selection_card
		target_selection_card = null
		pending_drop_info = {}
		set_state(InputState.IDLE)
		return_to_hand(card, reason)

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
	
	var target = null
	if current_state == InputState.SELECTING_TARGET:
		if what_is_under["has_minion"]: target = what_is_under["minion"]
		elif what_is_under["has_master"]: target = what_is_under["master"]
		
		# 유효한 타겟이 아니면 쫀득하게 스냅하지 않음 (시각적 필터링)
		if target != null and not battle_scene.ability_manager.is_valid_target(target_selection_card.card_data, target):
			target = null
	else:
		target = _get_enemy_target_from_info(what_is_under)
		if target and not battle_scene._is_targetable(dragging_card, target):
			target = null
			
	var desired_target_pos = battle_scene.get_global_mouse_position()
		
	if target:
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
		attacker.z_index = 0

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

func _get_card_under_mouse() -> Area2D:
	var space_state = battle_scene.get_world_2d().direct_space_state
	var query = PhysicsPointQueryParameters2D.new()
	query.position = battle_scene.get_global_mouse_position()
	query.collide_with_areas = true
	query.collide_with_bodies = false
	
	var results = space_state.intersect_point(query)
	var top_card = null
	var max_z = -999
	for r in results:
		var collider = r.collider
		if "card_data" in collider: # 해당 오브젝트가 '카드'인지 검사
			# 덱 더미 제외 (클릭이 막혀있는 카드)
			if collider.get("input_pickable") == false:
				continue
			# 상대방 손패 제외
			if collider.get("master") == battle_scene.enemy and collider.get("current_state") == collider.State.IN_HAND:
				continue
				
			var z = collider.z_index if "z_index" in collider else 0
			if z > max_z:
				top_card = collider
				max_z = z
	return top_card

func reset_state():
	if is_instance_valid(dragging_card):
		handle_right_click(dragging_card) # 진행 중인 드래그가 있다면 우클릭 취소 로직을 재활용해 취소
	
	possible_click_card = null # 클릭하려던 카드 정보도 확실하게 초기화
	set_state(InputState.IDLE)
