extends Node


@onready var battle_scene = get_tree().current_scene
@onready var attack_line = battle_scene.get_node("UI/AttackLine")


var dragging_card: Control = null

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


func _process(_delta: float) -> void:
	if not dragging_card: return # 드래그 중이 아니면 아무것도 안 해!!!!!

	match dragging_card.current_state:
		dragging_card.State.DRAGGING_TO_USE:
			_handle_use_drag()
		dragging_card.State.DRAGGING_TO_ATTACK:
			_handle_attack_drag()

func start_drag(card):
	dragging_card = card
	if card.battlefield_position == -1: # 핸드에 있을 때
		card.current_state = card.State.DRAGGING_TO_USE
		card.create_placeholder()
		card.animate_scale(card.SCALE_DRAG)
		card.top_level = true
	elif card.attackable > 0: # 보드에 있고 공격 가능할 때
		card.current_state = card.State.DRAGGING_TO_ATTACK
		start_attack_line(card)

	card.z_index = 100

func end_drag(card):
	dragging_card = null
	card.z_index = 0
	match card.current_state:
		card.State.DRAGGING_TO_USE:
				check_drop(card)
		card.State.DRAGGING_TO_ATTACK:
			end_attack_line(card)
			card.current_state = card.State.ON_BOARD

func handle_right_click(card):
	if card.current_state == card.State.DRAGGING_TO_ATTACK:
		end_attack_line(card)
		card.current_state = card.State.ON_BOARD
	elif card.current_state == card.State.DRAGGING_TO_USE:
		return_to_hand(card, "우클릭으로 손패로 돌아감")
		card.animate_scale(card.SCALE_HAND)
		card.current_state = card.State.IN_HAND
		card.top_level = false
	

func check_drop(card: Control):
	var what_is_under = get_target_under_mouse()
	if card.card_data["type"] == "minion":
		if what_is_under["type"] == "slot" and what_is_under["side"] == "player":
			if battle_scene.player.use_mana(card.card_data["cost"]) == false:
				print("소환	실패: 마나 부족")
				return_to_hand(card, "마나 부족%d" % battle_scene.player.mana)
				return	
			battle_scene.summon_to_slot(card, what_is_under["object"], battle_scene.player, what_is_under["index"])
			card.remove_placeholder()
			return
		else:
			return_to_hand(card, "아군의 빈슬롯이 아닙니다.")
			return

	elif card.card_data["type"] == "magic":
		if what_is_under["type"] == "none":
			return_to_hand(card, "마법은 사용할 수 있는 곳에만 사용할 수 있습니다.")
			return
		if battle_scene.player.use_mana(card.card_data["cost"]) == false:
			print("마법 실패: 마나 부족")
			return_to_hand(card, "마나 부족%d" % battle_scene.player.mana)
			return	
		card.remove_placeholder()
		battle_scene.cast_magic(card, battle_scene.player)
		return

func return_to_hand(card: Control, _reason: String):
	battle_scene.set_input_lock(true) # 입력 잠금 

	print("return to hand: ", _reason)

	card.top_level = false 
	card.current_state = card.State.IN_HAND
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.animate_scale(card.SCALE_HAND)

	if not is_instance_valid(card.placeholder): return

	var target_pos = card.placeholder.global_position

	# 2. 위치 복귀 애니메이션
	var tween = create_tween()
	tween.tween_property(card, "global_position", card.global_position, 0)\
		.set_ease(Tween.EASE_IN_OUT)
	tween.chain()\
		.tween_property(card, "global_position", target_pos, 0.1)\
		.set_ease(Tween.EASE_IN_OUT)
	# 3. 완료 후 정리 작업
	tween.finished.connect(func():
		var target_idx = card.placeholder.get_index()
		battle_scene.set_input_lock(false) # 입력 잠금 해제
		card.remove_placeholder()
		if card.get_parent() != battle_scene.player_hand:
			card.reparent(battle_scene.player_hand)
		battle_scene.player_hand.move_child(card, target_idx)
		card.mouse_filter = Control.MOUSE_FILTER_STOP
	)

func _handle_use_drag():
	var card = dragging_card
	var mouse_pos = battle_scene.get_global_mouse_position()
	var what_is_under = get_target_under_mouse()
	if card.card_data["type"] == "minion":
		if what_is_under["type"] == "slot" and what_is_under["side"] == "player":
			var target_slot = what_is_under["object"]
			var slot_center = target_slot.global_position + target_slot.size / 2
			card.global_position = slot_center - (card.size * card.scale / 2.0)
		else:
			card.global_position = mouse_pos - (card.size * card.scale / 2.0)
	elif card.card_data["type"] == "magic":
		if what_is_under["type"] != "none":
			var bf_rect = battle_scene.get_node("Battlefield").get_global_rect()
			card.global_position = bf_rect.position + (bf_rect.size / 2) - (card.size * card.scale / 2.0)
		else:
			card.global_position = mouse_pos - (card.size * card.scale / 2.0)

func _handle_attack_drag():
	var card = dragging_card
	update_attack_line(card.global_position + (card.size * card.SCALE_BOARD / 2.0))


func start_attack_line(attacker):
	attack_line.clear_points()
	attack_line.add_point(attacker.global_position)
	attack_line.add_point(battle_scene.get_global_mouse_position())
	attack_line.visible = true

func update_attack_line(start_pos):
	attack_line.set_point_position(0, start_pos)
	var what_is_under = get_target_under_mouse()
	if what_is_under["type"] == "master" and what_is_under["side"] == "enemy" and battle_scene._is_targetable(dragging_card, what_is_under["object"]):
		attack_line.set_point_position(1, battle_scene.enemy.avatar.global_position + (battle_scene.enemy.avatar.size * battle_scene.enemy.avatar.scale / 2.0))
	elif what_is_under["type"] == "minion" and what_is_under["side"] == "enemy" and battle_scene._is_targetable(dragging_card, what_is_under["object"]):
		attack_line.set_point_position(1, what_is_under["object"].global_position + (what_is_under["object"].size * what_is_under["object"].scale / 2.0))
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
	var mouse_pos = get_viewport().get_mouse_position()
	# 1. 적 미니언 체크
	for m in battle_scene.enemy.battlefield:
		if is_instance_valid(m) and m.get_global_rect().has_point(mouse_pos):
			return {"type": "minion", "object": m, "side": "enemy"}
	# 2. 내 미니언 체크
	for m in battle_scene.player.battlefield:
		if is_instance_valid(m) and m.get_global_rect().has_point(mouse_pos):
			return {"type": "minion", "object": m, "side": "player"}
	# 3. 마스터 체크 (본체)
	if battle_scene.player.avatar.get_global_rect().has_point(mouse_pos):
		return {"type": "master", "object": battle_scene.player, "side": "player"}
	# 4. 적 마스터 체크 (본체)
	if battle_scene.enemy.avatar.get_global_rect().has_point(mouse_pos):
		return {"type": "master", "object": battle_scene.enemy, "side": "enemy"}
	# 5. 빈 슬롯 체크
	for i in range(battle_scene.player_battlefield_nodes.size()):
		var slot = battle_scene.player_battlefield_nodes[i]
		if slot.get_global_rect().has_point(mouse_pos):
			if battle_scene.player.battlefield[i] != null: # 빈 슬롯인지 추가 체크
				return {"type" : "minion", "object": battle_scene.player.battlefield[i], "side": "player"}
			return {"type": "slot", "index": i, "object": slot, "side": "player"}
	# 6. 적 빈 슬롯 체크
	for i in range(battle_scene.enemy_battlefield_nodes.size()):
		var slot = battle_scene.enemy_battlefield_nodes[i]
		if slot.get_global_rect().has_point(mouse_pos):
			if battle_scene.enemy.battlefield[i] != null: # 빈 슬롯인지 추가 체크
				return {"type" : "minion", "object": battle_scene.enemy.battlefield[i], "side": "enemy"}
			return {"type": "slot", "index": i, "object": slot, "side": "enemy"}
	if battle_scene.get_node("Battlefield").get_global_rect().has_point(mouse_pos):
		return {"type": "battlefield", "object": battle_scene.get_node("Battlefield"), "side": "none"}
	return {"type": "none", "index": -1, "object": null, "side": "none"}
