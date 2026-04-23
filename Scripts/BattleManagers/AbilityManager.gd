extends Node

# 배틀씬 참조
@onready var battle_scene = get_tree().current_scene

# 대상 지정이 필요한 능력을 가지고 있는지 확인
func has_targeting_ability(card_data: Dictionary) -> bool:
	if not card_data.has("abilities") or not card_data["abilities"].has("onUse"): 
		return false
	
	for effect in card_data["abilities"]["onUse"]:
		var t = effect.get("target", "")
		if t in ["enemy_minion", "my_minion", "any_minion", "any"]:
			return true
	return false

# 대상이 카드의 능력 범위에 포함되는 유효한 타겟인지 검증
func is_valid_target(card_data: Dictionary, target) -> bool:
	if not has_targeting_ability(card_data): return false
	
	for effect in card_data["abilities"]["onUse"]:
		var t = effect.get("target", "")
		if t == "my_minion" and target in battle_scene.player.slot: return true
		if t == "enemy_minion" and target in battle_scene.enemy.slot: return true
		if t in ["any_minion"] and (target in battle_scene.player.slot or target in battle_scene.enemy.slot): return true
		if t == "my_master" and target == battle_scene.player: return true
		if t == "enemy_master" and target == battle_scene.enemy: return true
		if t == "any" and (target == battle_scene.player or target == battle_scene.enemy or target in battle_scene.player.slot or target in battle_scene.enemy.slot): return true
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
		
		var has_valid_target = (t == "any") or \
			(t in ["enemy_minion", "any_minion"] and enemy_has_minion) or \
			(t in ["my_minion", "any_minion"] and player_has_minion)
			
		# 직접 클릭으로 대상을 지정해야 하는 속성들
		if t in ["enemy_minion", "my_minion", "any_minion", "any"] and has_valid_target:
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
func _execute_effect(effect: Dictionary, source: Node2D, selected_target):
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
	
# 타겟팅 로직 분리
func _get_targets(target_type: String, source: Node2D, selected_target) -> Array:
	var result = []
	var my_master = source.master
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
