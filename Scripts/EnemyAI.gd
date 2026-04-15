extends Node

@onready var battle_scene = get_parent()

func start_enemy_turn():
	print("Enemy AI: 턴 시작")
	await get_tree().create_timer(1.0).timeout # 턴 시작 딜레이
	var safety_counter = 0
	while safety_counter < 20:
		print("Enemy AI 행동 시도: ", safety_counter)
		if await _try_use_card():
			safety_counter += 1
			print("Enemy AI: 카드 소환 성공, 재소환 시도")
			await get_tree().create_timer(0.8).timeout # 연출 대기
			continue 
		if await _try_attack_one_time():
			safety_counter += 1
			print("Enemy AI: 소환 실패, 공격 성공, 재소환 재시도")
			await get_tree().create_timer(0.8).timeout # 연출 대기
			continue
		break
	if safety_counter >= 20:
		print("Enemy AI: 행동 횟수 초과로 강제 종료")
	print("Enemy AI: 턴 종료")
	battle_scene.change_turn()

# --- 내부 헬퍼 함수들 (Atomic Actions) ---

func _try_use_card() -> bool:
	var hand = battle_scene.enemy_hand.get_children()
	var usable = hand.filter(func(c): 
		return is_instance_valid(c) and c.card_data["cost"] <= battle_scene.enemy.mana
	)
	
	if usable.is_empty(): return false
	
	usable.sort_custom(func(a, b):
		return b.card_data["cost"] - a.card_data["cost"] # 비용 높은 순 정렬
	)
	var card_to_use = usable[-1]
	if card_to_use.card_data["type"] == "minion":
		for i in range(3):
			if battle_scene.enemy.battlefield[i] == null:
				var slot_node = battle_scene.enemy_battlefield_nodes[i]
				battle_scene.enemy.use_mana(card_to_use.card_data["cost"]) # 마나 차감
				await battle_scene.summon_to_slot(card_to_use, slot_node, battle_scene.enemy, i)
				return true
	elif card_to_use.card_data["type"] == "magic":
		battle_scene.enemy.use_mana(card_to_use.card_data["cost"]) # 마나 차감
		await battle_scene.cast_magic(card_to_use, battle_scene.enemy)
		return true
	# 빈 슬롯 찾기
			
	return false

func _try_attack_one_time() -> bool:
	# 1. 공격 가능한 적 미니언들 필터링
	var attackers = battle_scene.enemy.battlefield.filter(func(c): 
		return is_instance_valid(c) and c.attackable > 0
	)
	if attackers.is_empty(): return false # 공격할 놈 없으면 종료
	var attacker = attackers[0]
	# 2. 공격 대상 결정 (마스터 포함 모든 타겟 중 선택)
	var target = _choose_attack_target(attacker)
	if target == null:
		return false 
	await battle_scene.attack_with_minion(attacker, target)
	return true

func _choose_attack_target(_attacker):
	# 1. 후보군 생성 (미니언 + 마스터)
	var targets = battle_scene.player.battlefield.filter(func(c): return is_instance_valid(c))
	targets.append(battle_scene.player)

	# 2. 도발 판정 필터링 
	var valid_targets = targets.filter(func(t): 
		return battle_scene._is_targetable(_attacker, t)
	)
	
	if valid_targets.is_empty():
		return null
		
	return valid_targets[0] # 그 외에는 첫 번째 가능한 미니언 공격!!!!!
