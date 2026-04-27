extends Node

# 배틀씬 참조
@onready var battle_scene = get_tree().get_first_node_in_group("battle_scene")

# 대상 지정이 필요한 능력을 가지고 있는지 확인
func has_targeting_ability(card_data: Dictionary) -> bool:
	if not card_data.has("abilities") or not card_data["abilities"].has("onUse"): 
		return false
	
	for effect in card_data["abilities"]["onUse"]:
		var t = effect.get("target", "")
		if t in ["enemy_minion", "my_minion", "any_minion", "any", "enemy_empty_slot", "my_empty_slot", "any_empty_slot"]:
			return true
	return false

# 대상이 카드의 능력 범위에 포함되는 유효한 타겟인지 검증
func is_valid_target(card_data: Dictionary, target) -> bool:
	if not has_targeting_ability(card_data): return false
	if target == null: return false
	
	var is_master = ("mana" in target) # Master 객체(본체)인지 확인
	var is_area = target is Area2D     # 하수인 또는 슬롯(Area2D)인지 확인
	
	for effect in card_data["abilities"]["onUse"]:
		var t = effect.get("target", "")
		
		# 1. 대상이 본체(Master)일 때만 접근하는 안전 구역
		if is_master:
			if t == "my_master" and target == battle_scene.player: return true
			if t == "enemy_master" and target == battle_scene.enemy: return true
			if t == "any" and (target == battle_scene.player or target == battle_scene.enemy): return true
			
		# 2. 대상이 하수인 또는 슬롯(Area2D)일 때만 접근하는 안전 구역
		elif is_area:
			if t == "my_minion" and battle_scene.player.slot.has(target): return true
			if t == "enemy_minion" and battle_scene.enemy.slot.has(target): return true
			if t in ["any_minion", "any"] and (battle_scene.player.slot.has(target) or battle_scene.enemy.slot.has(target)): return true
			
			if t in ["enemy_empty_slot", "any_empty_slot"] and battle_scene.enemy_slot_nodes.has(target):
				var idx = battle_scene.enemy_slot_nodes.find(target)
				if idx != -1 and battle_scene.enemy.slot[idx] == null: return true
				
			if t in ["my_empty_slot", "any_empty_slot"] and battle_scene.player_slot_nodes.has(target):
				var idx = battle_scene.player_slot_nodes.find(target)
				if idx != -1 and battle_scene.player.slot[idx] == null: return true
	return false

# 타겟 지정이 필수적인 카드인지 판별 (InputManager에서 드래그 시 활용)
func needs_target(card_data: Dictionary) -> bool:
	if not has_targeting_ability(card_data):
		return false
	
	for effect in card_data["abilities"]["onUse"]:
		var t = effect.get("target", "")
		
		# 필드에 유효한 타겟이 하나라도 존재하는지 체크
		var enemy_has_minion = battle_scene.enemy.slot.any(func(c): return is_instance_valid(c))
		var player_has_minion = battle_scene.player.slot.any(func(c): return is_instance_valid(c))
		
		var enemy_has_empty_slot = battle_scene.enemy.slot.any(func(c): return c == null)
		var player_has_empty_slot = battle_scene.player.slot.any(func(c): return c == null)
		
		var has_valid_target = (t == "any") or \
			(t in ["enemy_minion", "any_minion"] and enemy_has_minion) or \
			(t in ["my_minion", "any_minion"] and player_has_minion) or \
			(t in ["enemy_empty_slot", "any_empty_slot"] and enemy_has_empty_slot) or \
			(t in ["my_empty_slot", "any_empty_slot"] and player_has_empty_slot)
			
		# 직접 클릭으로 대상을 지정해야 하는 속성들
		if t in ["enemy_minion", "my_minion", "any_minion", "any", "enemy_empty_slot", "my_empty_slot", "any_empty_slot"] and has_valid_target:
			return true
	return false

# 어빌리티 실행 메인 함수
func trigger_ability(trigger_type: String, source_card: Node2D, selected_target = null):
	var abilities = source_card.card_data.get("abilities", {})
	if not abilities.has(trigger_type):
		return
	var ability_data = abilities[trigger_type]
	# 배열인 경우와 단일 객체인 경우 모두 처리 (확장성)
	if ability_data is Array:
		for effect in ability_data:
			_execute_effect(effect, source_card, selected_target)
	else:
		_execute_effect(ability_data, source_card, selected_target)

# 실제 효과를 물리적으로 적용
func _execute_effect(effect: Dictionary, source, selected_target):
	var target_type = effect["target"]
	
	# 1. 대상(Target) 확정
	var targets = _get_targets(target_type, source, selected_target)
	
	# 2. 연출 및 효과 적용
	for target in targets:
		if target == null: continue
		_apply_popping(source) # 번쩍이는 연출 (안전 검사 포함)
		_apply_effect_by_id(effect, target)

func _apply_effect_by_id(effect: Dictionary, target):
	var effect_id = effect.get("ID", "")
	var amount = effect.get("amount", 0)
	var atk_val = effect.get("atk", 0)
	var hp_val = effect.get("hp", 0)

	match effect_id:
		"ADD_HP":
			if "mana" in target: # 마스터인 경우 (has_method가 이너 클래스에서 씹히는 문제 방지)
				target.hp += amount
				battle_scene.ui_manager.update()
			else: # 카드인 경우
				target.card_data["hp"] += amount
				target.update_display()
		"ADD_MANA":
			if "mana" in target:
				target.mana += amount
				battle_scene.ui_manager.update()
		"DOUBLE_HP":
			if not "mana" in target:
				target.card_data["hp"] *= 2
				target.update_display()
		"DRAW_CARD":
			battle_scene.draw_cards(target, amount)
		"DAMAGE", "DAMAGE_ALL":
			if "mana" in target: 
				target.hp -= amount
				battle_scene.ui_manager.update()
				battle_scene._check_master_death(target) # 마법으로 명치 맞았을 때 체크!
			else: # 하수인인 경우
				target.card_data["hp"] -= amount
				target.update_display()
				battle_scene._check_minion_death(target) # 체력이 0 이하인지 체크
		"BUFF", "BUFF_ALL":
			if not "mana" in target: # 하수인에게만 적용
				target.card_data["atk"] += atk_val
				target.card_data["hp"] += hp_val
				target.update_display()
		"APPLY_STATUS":
			var status_id = effect.get("status_id", "")
			if status_id != "":
				target.status_effects[status_id] = target.status_effects.get(status_id, 0) + amount
				if "mana" in target:
					battle_scene.update_master_statuses()
				else:
					target.update_display()
		"SUMMON":
			var minion_id = effect.get("card_id", "")
			var minion_data = CardDatabase.get_card_by_id(minion_id)
			if not minion_data.is_empty():
				var target_master = null
				var empty_slot_idx = -1
				
				# 사용자가 직접 슬롯을 지정했을 경우
				if target in battle_scene.player_slot_nodes:
					target_master = battle_scene.player
					empty_slot_idx = battle_scene.player_slot_nodes.find(target)
				elif target in battle_scene.enemy_slot_nodes:
					target_master = battle_scene.enemy
					empty_slot_idx = battle_scene.enemy_slot_nodes.find(target)
				else:
					# 타겟이 마스터일 경우 (자동 빈 슬롯 탐색 - 기존 로직 호환용)
					target_master = target if "mana" in target else target.master
					for i in range(target_master.slot.size()):
						if target_master.slot[i] == null:
							empty_slot_idx = i
							break
							
				if empty_slot_idx != -1:
					var new_card = battle_scene.CARD_SCENE.instantiate()
					battle_scene.card_container.add_child(new_card)
					new_card.init_card(minion_data, target_master)
					new_card.global_position = target_master.avatar.global_position # 소환 연출 시작 위치
					battle_scene.summon_to_slot(new_card, empty_slot_idx, target_master)
	
# 타겟팅 로직 분리
func _get_targets(target_type: String, source, selected_target) -> Array:
	var result = []
	var my_master = source if "mana" in source else source.master # source가 이미 마스터(본체)라면 그대로 사용!
	var enemy_master = battle_scene.enemy if my_master == battle_scene.player else battle_scene.player
	
	match target_type:
		"self":
			result.append(source)
		"my_master": 
			result.append(my_master)
		"other_master", "enemy_master": 
			result.append(enemy_master)
		"enemy_minion", "my_minion", "any_minion", "any":
			if selected_target: 
				result.append(selected_target)
			elif my_master == battle_scene.enemy:
				# AI가 사용 시 타겟을 지정하지 않았다면, 랜덤으로 하나 고르기 (자기 자신 제외)
				var pool = []
				if target_type in ["enemy_minion", "any_minion", "any"]:
					pool.append_array(enemy_master.slot.filter(func(c): return is_instance_valid(c) and c != source))
				if target_type in ["my_minion", "any_minion", "any"]:
					pool.append_array(my_master.slot.filter(func(c): return is_instance_valid(c) and c != source))
				if target_type == "any":
					pool.append(my_master)
					pool.append(enemy_master)
				
				if pool.size() > 0:
					result.append(pool.pick_random())
		"enemy_empty_slot", "my_empty_slot", "any_empty_slot":
			if selected_target: 
				result.append(selected_target)
			elif my_master == battle_scene.enemy:
				# AI가 사용 시 타겟을 지정하지 않았다면, 랜덤 빈 슬롯 하나 고르기
				var pool = []
				if target_type in ["enemy_empty_slot", "any_empty_slot"]:
					var nodes = battle_scene.player_slot_nodes if enemy_master == battle_scene.player else battle_scene.enemy_slot_nodes
					for i in range(enemy_master.slot.size()):
						if enemy_master.slot[i] == null: pool.append(nodes[i])
				if target_type in ["my_empty_slot", "any_empty_slot"]:
					var nodes = battle_scene.player_slot_nodes if my_master == battle_scene.player else battle_scene.enemy_slot_nodes
					for i in range(my_master.slot.size()):
						if my_master.slot[i] == null: pool.append(nodes[i])
				
				if pool.size() > 0:
					result.append(pool.pick_random())
		"enemy_minions":
			for c in enemy_master.slot:
				if is_instance_valid(c): result.append(c)
		"my_minions":
			for c in my_master.slot:
				if is_instance_valid(c): result.append(c)
	return result

# 능력 발동 시 시각적 피드백!!!!!
func _apply_popping(target):
	if is_instance_valid(target) and target is Node2D and target.scale.x > 0.1: # 마법 카드처럼 이미 0으로 줄어들었거나 삭제 대기 중이면 생략!
		var tween = create_tween()
		tween.tween_property(target, "scale", target.scale * 1.2, 0.1)
		tween.chain().tween_property(target, "scale", target.scale, 0.1)

# 턴 시작/종료 시 호출되어 상태이상을 처리하는 함수
func process_status_effects(target, timing: String):
	if typeof(target) == TYPE_OBJECT and not is_instance_valid(target): return # 삭제된 노드 접근 완벽 차단
	if target == null or not "status_effects" in target: return
	
	var has_changed = false
	
	for status_id in target.status_effects.keys(): # keys()로 복사본 순회(안전함)
		var stacks = target.status_effects[status_id]
		if stacks <= 0: continue
		
		# 1. 독(POISON) 로직: 턴이 끝날 때 스택만큼 데미지를 입고, 1스택이 줄어든다.
		if timing == "onTurnEnd" and status_id == "POISON":
			_apply_effect_by_id({"ID": "DAMAGE", "amount": stacks}, target)
			
			# 독 데미지로 인해 하수인이 방금 파괴되었다면, 상태이상 처리를 즉시 중단합니다! (에러 완벽 차단)
			if target is Node and target.is_queued_for_deletion(): return
			target.status_effects[status_id] -= 1
			has_changed = true
			
		# 2. 스택이 0 이하가 되면 딕셔너리에서 깔끔하게 삭제
		if target.status_effects[status_id] <= 0:
			target.status_effects.erase(status_id)
			has_changed = true
			
	if has_changed:
		if "mana" in target: battle_scene.update_master_statuses()
		else: target.update_display()

# ==========================================
# 인터럽트(Interrupt) 파이프라인 시스템
# ==========================================
func process_interrupts(card: Area2D, _master, target, action_type: String = "onUse"):
	var current_target = target
	var target_owner = battle_scene.enemy if _master == battle_scene.player else battle_scene.player
	
	# 1. 상대 필드의 모든 하수인의 패시브를 검사
	for c in target_owner.slot:
		if is_instance_valid(c) and c.card_data.has("abilities") and c.card_data["abilities"].has("passive"):
			for p in c.card_data["abilities"]["passive"]:
				# action_type을 통해 마법(onUse), 공격(onAttack), 소환(onSummon) 등 다방면으로 인터럽트 가능!
				if p.get("ID") == "INDUCE" and action_type == "onUse" and card.card_data.get("category", "") == "buff":
					current_target = await _execute_induce(c, _master, current_target, p)
					
	return current_target

func _execute_induce(inducer: Area2D, _master, target, ability_data: Dictionary):
	print("INDUCE 패시브 발동! 미인계 다이얼로그 시작")
	
	var dialog_id = ability_data.get("dialogue_id", "")
	var dialog_data = CardDatabase.get_dialogue(dialog_id)
	
	# 선택 결과를 저장할 배열 (Godot 람다에서 외부 변수 캡처용)
	var chosen_opt = [null]
	var on_choice = func(opt):
		chosen_opt[0] = opt
		
	battle_scene.dialogue_manager.choice_made.connect(on_choice, CONNECT_ONE_SHOT)
	battle_scene.dialogue_manager.start_dialogue(dialog_data)
	
	# 대화가 끝날 때까지 턴 진행 정지
	await battle_scene.dialogue_manager.dialogue_finished
	
	# 유혹에 넘어가서 플래그(override_target)가 켜졌다면 타겟 강제 변경!
	if chosen_opt[0] != null and chosen_opt[0].get("override_target", false) == true:
		return inducer
		
	return target
