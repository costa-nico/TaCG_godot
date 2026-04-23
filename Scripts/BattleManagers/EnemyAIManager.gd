extends Node

@onready var battle_scene = get_tree().current_scene

func start_enemy_turn():
	print("Enemy AI: 턴 시작")
	
	battle_scene.dialogue_manager.start_dialogue([
		{"image": "res://Images/enemy.jpg", "text": "내 차례다!"}
	])
	await battle_scene.dialogue_manager.dialogue_finished

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
	var hand = battle_scene.enemy.hand # 노드의 자식이 아닌, 데이터 배열(hand)을 직접 참조합니다.
	var has_empty_slot = battle_scene.enemy.slot.any(func(c): return c == null)
	
	var usable = hand.filter(func(c): 
		if not is_instance_valid(c) or c.card_data["cost"] > battle_scene.enemy.mana:
			return false
		# 필드가 꽉 찼는데 하수인 카드라면 사용할 수 없는 카드로 분류!
		if c.card_data["type"] == "minion" and not has_empty_slot:
			return false
		return true
	)
	
	if usable.is_empty(): return false
	
	usable.sort_custom(func(a, b):
		return a.card_data["cost"] > b.card_data["cost"] # 비용 높은 순(내림차순) 정렬 (Godot 4.x 표준)
	)
	var card_to_use = usable[0] # 가장 비싼 카드 선택
	
	# AI 타겟팅 판단 로직 (카테고리 기반)
	var target = _choose_skill_target(card_to_use)
	
	if card_to_use.card_data["type"] == "minion":
		for i in range(battle_scene.enemy.slot.size()): # 하드코딩(3) 제거, 슬롯 개수 확장에 자동 대응
			if battle_scene.enemy.slot[i] == null:
				battle_scene.enemy.use_mana(card_to_use.card_data["cost"]) # 마나 차감
				await battle_scene.summon_to_slot(card_to_use, i, battle_scene.enemy, target)
				return true
	elif card_to_use.card_data["type"] == "magic":
		battle_scene.enemy.use_mana(card_to_use.card_data["cost"]) # 마나 차감
		await battle_scene.cast_magic(card_to_use, battle_scene.enemy, target)
		return true
	# 빈 슬롯 찾기
			
	return false

func _try_attack_one_time() -> bool:
	# 1. 공격 가능한 적 미니언들 필터링
	var attackers = battle_scene.enemy.slot.filter(func(c): 
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
	var targets: Array = battle_scene.player.slot.filter(func(c): return is_instance_valid(c))
	targets.append(battle_scene.player)

	# 2. 타겟 우선순위(도발 등) 판정 필터링 
	var valid_targets = targets.filter(func(t): 
		return battle_scene._is_targetable(_attacker, t)
	)
	
	if valid_targets.is_empty():
		return null
		
	var valid_minions = valid_targets.filter(func(t): return t != battle_scene.player)
	var can_hit_master = valid_targets.has(battle_scene.player)
	var dmg = _attacker.card_data.get("atk", 0)
	
	# 3. 킬각 확인: 명치(마스터)를 때려서 게임을 끝낼 수 있다면 무조건 명치 타겟팅!
	if can_hit_master and battle_scene.player.hp <= dmg:
		return battle_scene.player
		
	if valid_minions.is_empty():
		if can_hit_master: return battle_scene.player
		return null
		
	# 4. 정렬 로직: 1순위(내 데미지로 죽일 수 있는가?), 2순위(그 중 가장 강한 적인가?)
	valid_minions.sort_custom(func(a, b):
		var a_kill = a.card_data.get("hp", 0) <= dmg
		var b_kill = b.card_data.get("hp", 0) <= dmg
		if a_kill and not b_kill: return true
		if not a_kill and b_kill: return false
		
		var a_power = a.card_data.get("atk", 0) + a.card_data.get("hp", 0)
		var b_power = b.card_data.get("atk", 0) + b.card_data.get("hp", 0)
		return a_power > b_power # 처치 여부가 같다면 강한 순 정렬
	)
	
	return valid_minions[0]

func _choose_skill_target(card: Area2D):
	# 타겟 지정이 필요 없는 카드면 패스
	if not battle_scene.ability_manager.needs_target(card.card_data):
		return null
		
	var category = card.card_data.get("category", "")
	
	if category == "buff":
		# 1. 아군 필드의 하수인 중 가장 강한(공격력+체력) 하수인 찾기
		var my_minions = battle_scene.enemy.slot.filter(func(c): return is_instance_valid(c) and c != card)
		if my_minions.is_empty(): return null
		
		my_minions.sort_custom(func(a, b):
			var a_power = a.card_data.get("atk", 0) + a.card_data.get("hp", 0)
			var b_power = b.card_data.get("atk", 0) + b.card_data.get("hp", 0)
			return a_power > b_power # 강한 순 정렬
		)
		return my_minions[0]
		
	elif category == "damage":
		# 1. 데미지량 파악
		var dmg = 0
		var can_hit_master = false
		if card.card_data.has("abilities") and card.card_data["abilities"].has("onUse"):
			for eff in card.card_data["abilities"]["onUse"]:
				if eff.get("ID") in ["DAMAGE", "DAMAGE_ALL"]:
					dmg = eff.get("amount", 0)
				if eff.get("target") in ["any", "enemy_master"]:
					can_hit_master = true
					
		var enemy_minions = battle_scene.player.slot.filter(func(c): return is_instance_valid(c))
		
		# 적 하수인이 없는데 명치를 칠 수 있는 스킬(예: 화살)이라면 명치 타겟팅!
		if enemy_minions.is_empty():
			if can_hit_master: return battle_scene.player
			return null
			
		# 2. 정렬 로직: 1순위(내 데미지로 죽일 수 있는가?), 2순위(그 중 가장 강한 적인가?)
		enemy_minions.sort_custom(func(a, b):
			var a_kill = a.card_data.get("hp", 0) <= dmg
			var b_kill = b.card_data.get("hp", 0) <= dmg
			if a_kill and not b_kill: return true
			if not a_kill and b_kill: return false
			
			var a_power = a.card_data.get("atk", 0) + a.card_data.get("hp", 0)
			var b_power = b.card_data.get("atk", 0) + b.card_data.get("hp", 0)
			return a_power > b_power # 처치 여부가 같다면 강한 순 정렬
		)
		return enemy_minions[0]
		
	return null # 카테고리가 등록 안 된 카드는 기존처럼 무작위(null) 처리
