extends Node2D

const CARD_SCENE = preload("res://scenes/Card.tscn")

@onready var ui_manager = $UI

@onready var ability_manager = $Managers/AbilityManager
@onready var enemy_ai = $Managers/EnemyAIManager
@onready var input_manager = $Managers/InputManager

@onready var dialogue_manager = $UI/DialogueManager
@onready var game_over_ui = $UI/GameOverUI # 씬 트리에 추가한 GameOverUI 노드 경로
@onready var description_manager = $UI/DescriptionManager # !!! 실제로 만드신 디스크립션 씬 노드 경로로 맞춰주세요 !!!

@onready var attack_line = $UI/AttackLine
@onready var input_blocker = $InputBlocker

@onready var player_slot_nodes = [$Slots/P1, $Slots/P2, $Slots/P3]
@onready var enemy_slot_nodes = [$Slots/E1, $Slots/E2, $Slots/E3]

@onready var magic_slot = $MagicSlot # 실제 씬의 마법 슬롯 경로에 맞게 수정해 주세요!!!!!

@onready var card_container = $Cards

@onready var player_deck_node = $PlayerDeck # 실제 씬의 플레이어 덱 노드 경로에 맞게 수정해 주세요!
@onready var enemy_deck_node = $EnemyDeck   # 실제 씬의 적 덱 노드 경로에 맞게 수정해 주세요!

@onready var player_status_container = $UI/PlayerStatusContainer # 에디터에서 만든 노드 연결
@onready var enemy_status_container = $UI/EnemyStatusContainer

const PLAYER_HAND_CENTER_POS = Vector2(576, 600)
const ENEMY_HAND_CENTER_POS = Vector2(576, 200)


const CARD_SPACING = 120.0
const CARD_ROTATION = 7.0

var hovered_card: Area2D = null # 현재 호버 중인 단 하나의 카드를 저장

var current_master: Master = null

class Master:
	var name: String

	var avatar: Node

	var hp:int = 5
	var max_mana:int = 0
	var mana:int = 0

	var hand_position: Vector2 = Vector2.ZERO

	var hand: Array[Area2D] = []
	var slot: Array[Area2D] = [null, null, null]
	var deck: Array = []
	var status_effects: Dictionary = {} # 본체용 상태이상 스택 저장소 추가!!

	func grow_mana():
		if max_mana < 5:
			max_mana += 1
	func refill_mana():
		mana = max_mana
	func use_mana(amount):
		if mana >= amount:
			mana -= amount
			return true
		return false

var player = Master.new()
var enemy = Master.new()

func _ready():
	print("배틀 씬 시작")

	current_master = player

	player.name = "player"
	enemy.name = "enemy"

	player.max_mana = 1
	player.mana = 1

	player.avatar = $PlayerAvatar
	enemy.avatar = $EnemyAvatar

	player.hand_position = $PlayerHand.position
	enemy.hand_position = $EnemyHand.position

	attack_line.visible = false
	
	# --- 어택 라인 비주얼 업그레이드 ---
	attack_line.width = 15.0 # 최대 굵기 증가
	attack_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	attack_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	
	# 1. 색상 그라데이션 (시작은 투명하게, 끝은 강렬한 빨간색)
	var gradient = Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.7, 1.0])
	gradient.colors = PackedColorArray([Color(1, 0.2, 0.2, 0.0), Color(1, 0.1, 0.1, 0.8), Color(1, 0, 0, 1)])
	attack_line.gradient = gradient
	
	# 2. 굵기 곡선 (시작은 얇게, 끝부분에서 뾰족해지는 에너지 빔 형태)
	var width_curve = Curve.new()
	width_curve.add_point(Vector2(0.0, 0.2)) # 시작점: 20% 굵기
	width_curve.add_point(Vector2(0.9, 1.0)) # 90% 지점: 100% 굵기
	width_curve.add_point(Vector2(1.0, 0.0)) # 끝점: 0% 굵기 (뾰족하게)
	attack_line.width_curve = width_curve

	refill_deck(player)
	if game_over_ui:
		game_over_ui.play_again_pressed.connect(func(): get_tree().reload_current_scene())

	refill_deck(enemy)

	_create_deck_visuals() # 화면에 더미 덱 시각화

	_start_battle() # 순차적 드로우 연출 시작

func _start_battle():
	set_input_lock(true) # 덱에서 카드가 날아오는 동안 마우스 조작 방지
	await get_tree().create_timer(0.5).timeout # 덱이 테이블에 놓이고 잠시 대기
	
	# 플레이어와 적이 번갈아가며 한 장씩 카드를 뽑는 쫀득한 연출
	for i in range(5):
		draw_cards(player, 1)
		await get_tree().create_timer(0.15).timeout
		draw_cards(enemy, 1)
		await get_tree().create_timer(0.15).timeout
		
	set_input_lock(false) # 연출 완료 후 조작 잠금 해제
func _create_deck_visuals():
	# 더미용 최소 데이터

	var dummy_data = {"name": "", "cost": 0, "type": "magic"}
	
	# 플레이어 덱 생성
	var p_deck = CARD_SCENE.instantiate()
	card_container.add_child(p_deck)
	p_deck.init_card(dummy_data, player)
	p_deck.scale = p_deck.SCALE_HAND # 덱 크기를 핸드 스케일과 동일하게 맞춤
	p_deck.cover.visible = true # 커버 활성화
	p_deck.input_pickable = false    # 클릭 방지
	p_deck.global_position = player_deck_node.global_position
	p_deck.z_index = 0               # 배경 이미지 뒤로 숨지 않도록 z_index를 0으로 수정
	
	# 에너미 덱 생성
	var e_deck = CARD_SCENE.instantiate()
	card_container.add_child(e_deck)
	e_deck.init_card(dummy_data, enemy)
	e_deck.scale = e_deck.SCALE_HAND # 덱 크기를 핸드 스케일과 동일하게 맞춤
	e_deck.cover.visible = true
	e_deck.input_pickable = false
	e_deck.global_position = enemy_deck_node.global_position
	e_deck.z_index = 0               # 배경 이미지 뒤로 숨지 않도록 z_index를 0으로 수정

func refill_deck(master: Master):
	print("덱 리필: %s의 덱을 카드 데이터로 채웁니다." % master.name)
	
	var deck_data = DeckLib.get_player_deck() if master == player else DeckLib.get_enemy_deck()
	for card_id in deck_data:
		var amount = deck_data[card_id]
		for i in range(amount):
			master.deck.append(card_id)
			
	master.deck.shuffle()
	ui_manager.update()

func draw_cards(master: Master, amount: int):
	for i in range(amount):
		if master.deck.size() == 0:
			print("%s의 덱이 비었습니다!" % master.name)
			refill_deck(master)
			if master.deck.size() == 0:
				break # 리필 후에도 덱이 비어있다면 탈출 (크래시 방지)
		var new_card_id = master.deck.pop_front()
		var new_card_data = CardDatabase.get_card_by_id(new_card_id)
		if new_card_data == {}:
			print("경고: 카드 데이터베이스에 %s 카드 정보가 없습니다. Dummy 카드로 대체합니다." % new_card_id)
			new_card_data = CardDatabase.get_card_by_id("DUMMY")
		add_to_hand(new_card_data, master)
	ui_manager.update()

func add_to_hand(data: Dictionary, master_: Master):
	if master_.hand.size() >= 10:
		print("%s의 패가 가득 차서 '%s' 카드가 파괴되었습니다!" % [master_.name, data.get("name", "알 수 없음")])
		return
		
	var new_card = CARD_SCENE.instantiate()
	card_container.add_child(new_card)
	new_card.init_card(data, master_)
	master_.hand.append(new_card) # 래퍼 함수 대신 직접 추가
	new_card.update_display()

	# 카드가 생성될 때 덱 위치에서 시작하게 설정 (이후 reposition_hand가 호출되며 날아오는 연출 됨!)
	if master_ == player:
		new_card.global_position = player_deck_node.global_position
	else:
		new_card.global_position = enemy_deck_node.global_position

	reposition_hand(master_)

func update_hover(new_hovered_card: Area2D):
	if hovered_card != new_hovered_card:
		if is_instance_valid(hovered_card):
			hovered_card.set_hover_state(false) # 기존 카드 집어넣기
		hovered_card = new_hovered_card
		if is_instance_valid(hovered_card):
			hovered_card.set_hover_state(true)  # 새 카드 꺼내기

func reposition_hand(master_: Master):
	var count = master_.hand.size()
	for i in range(count):
		var card = master_.hand[i]
		
		# 중앙을 0으로 하는 상대적 오프셋 (예: 5장이면 -2, -1, 0, 1, 2)
		var offset = i - (count - 1) / 2.0
		
		# 플레이어는 아래로 휘고(1.0), 에너미는 위로 휘도록(-1.0) 방향 변수 설정
		var dir_multiplier = 1.0 if master_ == player else -1.0
		
		# 포물선 수식을 적용해 부채꼴 형태 만들기
		var target_x = master_.hand_position.x + offset * CARD_SPACING
		var target_y = master_.hand_position.y + (pow(abs(offset), 2) * 7.0 +50)* dir_multiplier
		var target_pos = Vector2(target_x, target_y)
		var target_rotation = offset * CARD_ROTATION * dir_multiplier
		
		# 카드가 자신의 원래 위치와 각도를 기억하도록 저장
		card.base_position = target_pos
		card.base_rotation = target_rotation
		card.base_z_index = i
		
		# 드래그 중이 아닐 때만 위치 조정
		if card.current_state == card.State.IN_HAND:
			var tween = card.get_card_tween()
			if card.is_hovered:
				card.z_index = 100
				var hover_pos = Vector2(target_pos.x, master_.hand_position.y - 40)
				tween.tween_property(card, "global_position", hover_pos, 0.2).set_trans(Tween.TRANS_QUAD)
				tween.parallel().tween_property(card, "rotation_degrees", 0.0, 0.2).set_trans(Tween.TRANS_QUAD)
				tween.parallel().tween_property(card, "scale", card.SCALE_DRAG, 0.2).set_trans(Tween.TRANS_QUAD)
			else:
				card.z_index = i # 오른쪽 카드일수록 렌더링 및 클릭 최우선순위(Z-Index)를 갖게 함
				tween.tween_property(card, "global_position", target_pos, 0.2).set_trans(Tween.TRANS_QUAD)
				tween.parallel().tween_property(card, "rotation_degrees", target_rotation, 0.2).set_trans(Tween.TRANS_QUAD)
				tween.parallel().tween_property(card, "scale", card.SCALE_HAND, 0.2).set_trans(Tween.TRANS_QUAD)


func cast_magic(card: Area2D, master_: Master, target = null):
	card.cover.visible = false
	card.input_pickable = false # 마법 시전 중 마우스 상호작용 완전 차단

	card.z_index = 100
	card.rotation_degrees = 0.0 # 시전 시 각도 즉시 정상화 (에너미 카드 누움 방지)

	card.current_state = card.State.ON_BOARD
	master_.hand.erase(card) # 래퍼 함수 대신 직접 제거
	ui_manager.update()
	
	var tween = card.get_card_tween()
	var move_time = 0.0 if master_ == player else 0.2
	card.scale = card.SCALE_DRAG
	tween\
		.tween_property(card, "global_position", magic_slot.global_position, move_time)\
		.set_ease(Tween.EASE_IN_OUT)
	tween.tween_interval(0.5)
	tween.chain()\
		.tween_property(card, "scale", Vector2(0, 0), 0.1)\
		.set_ease(Tween.EASE_IN_OUT)
	
	await tween.finished

	# === 인터럽트(Interrupt) 파이프라인 ===
	var final_target = await ability_manager.process_interrupts(card, master_, target, "onUse")
	ability_manager.trigger_ability("onUse", card, final_target) # 타겟과 함께 사용 시 발동
	
	card.z_index = 0
	card.queue_free()

	reposition_hand(master_)
	print("마법 시전: %s가 %s 사용" % [master_.name, card.card_data["name"]])

		
func summon_to_slot(card: Area2D, slot_index: int, master_ : Master, target = null):
	var slot_node = player_slot_nodes[slot_index] if master_ == player else enemy_slot_nodes[slot_index]

	master_.hand.erase(card)
	master_.slot[slot_index] = card # 래퍼 함수 제거에 따른 직접 할당

	card.z_index = 10
	card.cover.visible = false
	card.rotation_degrees = 0.0 # 소환 시 각도 즉시 정상화 (에너미 카드 누움 방지)

	ui_manager.update()
	card.update_display()

	# 1. 슬롯의 중앙 위치 계산

	card.scale = card.SCALE_DRAG

	if master_ == enemy:
		card.scale = card.SCALE_HAND
		var tween = create_tween()
		tween\
			.tween_property(card, "global_position", slot_node.global_position, 0.2)\
			.set_ease(Tween.EASE_IN_OUT)
		await tween.finished
		
	card.global_position = slot_node.global_position # 플레이어 드롭 보정 및 적 트윈 완료 후 완벽한 슬롯 정중앙 스냅
	await card.set_on_board(slot_index)
	card.z_index = 0
	
	# === 인터럽트(Interrupt) 파이프라인 ===
	var final_target = await ability_manager.process_interrupts(card, master_, target, "onUse")
	ability_manager.trigger_ability("onUse", card, final_target) # 타겟과 함께 사용 시 발동 능력 체크
	
	reposition_hand(master_)
	print("hand to bf: %s의 슬롯%d에 %s 소환" % [master_.name, slot_index, card.card_data["name"]])

func change_turn():
	for card in current_master.slot:
		if is_instance_valid(card):
			ability_manager.trigger_ability("onTurnEnd", card) #이전 턴 마스터 턴 미니언 종료 능력 활성
			if not is_instance_valid(card) or card.is_queued_for_deletion(): continue # 능력 발동 중 죽었으면 이후 로직 패스
			card.attackable = 0 # 턴이 끝나면 공격 횟수 초기화
			card.update_display()
			ability_manager.process_status_effects(card, "onTurnEnd")
	
	ability_manager.process_status_effects(current_master, "onTurnEnd") # 본체 상태이상

	current_master = enemy if current_master == player else player 

	print("턴이 변경. 현재 턴:%s" % (current_master.name))

	$UI/EndTurnButton.disabled = current_master != player # 플레이어 턴일 때만 종료 버튼 활성화

	draw_cards(current_master, 1) # 턴이 바뀔 때마다 카드 한 장 뽑기
	current_master.grow_mana()
	current_master.refill_mana()

	for card in current_master.slot: # 바뀐 턴 마스터 턴 미니언 시작 능력 활성
		if is_instance_valid(card):
			card.attackable = 1 # 소환된 카드들은 다음 턴부터 공격 가능하게 설정
			ability_manager.trigger_ability("onTurnStart", card) # 플레이어 전장 카드의 턴 시작 시 발동 능력 체크
			if not is_instance_valid(card) or card.is_queued_for_deletion(): continue
			ability_manager.process_status_effects(card, "onTurnStart")
			if not is_instance_valid(card) or card.is_queued_for_deletion(): continue
			card.update_display() # 공격 가능 여부에 따라 카드 색상 업데이트
			
	ability_manager.process_status_effects(current_master, "onTurnStart")
	ui_manager.update()

	if(current_master == enemy):
		enemy_ai.start_enemy_turn() # 적 AI 돌리기

func _on_end_turn_button_pressed():
	if current_master != player:
		print("현재 플레이어 턴이 아닙니다.")
		return
	change_turn()
	
func attack_with_minion(attacker, target):
	if not is_instance_valid(attacker): return
	if not is_instance_valid(target): return	

	set_input_lock(true) # 공격 애니메이션 동안 입력 잠금
	attacker.z_index = 100

	attacker.attackable -= 1
	
	ability_manager.trigger_ability("onAttack", attacker) # 공격 시 발동 능력 체크
	
	# 애니메이션

	var scale_origin = attacker.scale
	var scale_attack = scale_origin * 1.2

	var tween = attacker.get_card_tween() # 기존 트윈 충돌 방지를 위해 카드 전용 통합 트윈 사용
	tween.tween_property(attacker, "scale", scale_attack, 0.1) # 시작 위치 고정 (드래그 중이던 카드가 갑자기 튀는 걸 방지하기 위해)

	var start_pos = attacker.global_position

	var target_pos = target.global_position if target is Area2D else target.avatar.global_position

	# 타겟을 향하는 방향 벡터를 구하고, 현재 위치(start_pos)에서 반대 방향으로 일정 거리(40px)만큼 빼줍니다.
	var direction = (target_pos - start_pos).normalized()
	var wind_up = start_pos - direction * 50.0

	# 공격 준비 (살짝 뒤로)
	tween.chain()\
		.tween_property(attacker, "global_position", wind_up, 0.1)
	# 공격 돌진
	tween.chain()\
		.tween_property(attacker, "global_position", target_pos, 0.2)\
		.set_trans(Tween.TRANS_EXPO)
	# 타격 순간 로직 실행 (데미지 계산)
	tween.tween_callback(func():
		if not is_instance_valid(attacker) or not is_instance_valid(target): return
		if target is Master: # 본체 공격
			target.hp -= attacker.card_data["atk"]
			attacker.update_display()
			ui_manager.update()
			_check_master_death(target) # 명치 데미지 후 생존 확인!
		else:				 # 미니언 공격
			ability_manager.trigger_ability("onHit", target) # 공격 후 발동 능력 체크
			target.card_data["hp"] -= attacker.card_data["atk"]
			attacker.card_data["hp"] -= target.card_data["atk"] # 반격 데미지
			
			attacker.update_display()
			target.update_display()
	)
	# 다시 제자리로 복귀 
	tween.chain()\
		.tween_property(attacker, "global_position", start_pos, 0.2)
	tween.parallel()\
		.tween_property(attacker, "scale", scale_origin, 0.2)
	await tween.finished

	# 정리 (살아있을 때만)
	if is_instance_valid(attacker):
		attacker.z_index = 0
		
	_check_minion_death(attacker)
	_check_minion_death(target)
	set_input_lock(false) # 공격 애니메이션 완료 후 입력 잠금 해제

func _check_master_death(master: Master):
	if master.hp <= 0:
		game_over(master)

func game_over(loser: Master):
	set_input_lock(true) # 조작 완전 잠금
	var is_player_victory = (loser == enemy)
	if game_over_ui:
		game_over_ui.show_result(is_player_victory)
	else:
		print("게임 오버! 승리 여부: ", is_player_victory)

func _check_minion_death(target):
	if is_instance_valid(target) and target is not Master and target.card_data["hp"] <= 0:
		print("%s의 %s 전사" % [target.master.name, target.card_data["name"]])
		destroy_minion(target)

func destroy_minion(card: Area2D):
	# 1. 전장 배열에서 해당 데이터 삭제
	if card.slot_position != -1:
		card.master.slot[card.slot_position] = null # 직접 null 할당
	card.queue_free()

func set_input_lock(is_locked: bool):
	input_blocker.visible = is_locked

func _has_taunt(card: Area2D) -> bool:
	if not is_instance_valid(card) or not card.card_data.has("abilities"): return false
	var abilities = card.card_data["abilities"]
	if abilities.has("keyword"):
		var kw = abilities["keyword"]
		if typeof(kw) == TYPE_ARRAY:
			return kw.any(func(k): return typeof(k) == TYPE_DICTIONARY and k.get("ID") == "TAUNT")
		elif typeof(kw) == TYPE_DICTIONARY:
			return kw.get("ID") == "TAUNT"
	return false

func _is_targetable(_attacker, target) -> bool:
	if not is_instance_valid(target): return false

	var target_owner = target if target is Master else target.master
	
	var has_taunt = target_owner.slot.any(func(c): return is_instance_valid(c) and _has_taunt(c))
			
	if has_taunt:
		# 도발 하수인이 있다면, 본체(Master)는 칠 수 없고 오직 도발 하수인만 타겟 가능
		if target is Master: return false
		return _has_taunt(target)
		
	# 도발이 없을 때: 본체(Master)와 모든 하수인 타겟팅 가능
	return true

func set_target_highlights(card: Area2D, is_on: bool):
	# 일단 양쪽 모든 필드와 마스터의 하이라이트 초기화
	for c in player.slot:
		if is_instance_valid(c): c.set_target_highlight(false)
	for c in enemy.slot:
		if is_instance_valid(c): c.set_target_highlight(false)
	player.avatar.modulate = Color.WHITE
	enemy.avatar.modulate = Color.WHITE
	
	if not is_on:
		return
		
	# 1. 하수인의 일반 공격인 경우 (도발 룰 적용)
	if card.current_state == card.State.DRAGGING_TO_ATTACK or card.current_state == card.State.ON_BOARD:
		var target_owner = enemy if card.master == player else player
		var has_taunt = target_owner.slot.any(func(c): return is_instance_valid(c) and _has_taunt(c))
		
		for c in target_owner.slot:
			if is_instance_valid(c):
				if has_taunt and not _has_taunt(c): continue # 도발이 있는데 자신은 도발 하수인이 아니면 패스
				c.set_target_highlight(true)
				
		if not has_taunt:
			target_owner.avatar.modulate = Color(1.0, 0.2, 0.2, 1.0)
			
	# 2. 마법 카드이거나 하수인의 전투의 함성(타겟 지정)인 경우 (능력 유효 대상 하이라이트)
	else:
		for c in player.slot:
			if is_instance_valid(c) and ability_manager.is_valid_target(card.card_data, c):
				c.set_target_highlight(true)
		for c in enemy.slot:
			if is_instance_valid(c) and ability_manager.is_valid_target(card.card_data, c):
				c.set_target_highlight(true)
				
		if ability_manager.is_valid_target(card.card_data, player):
			player.avatar.modulate = Color(0.5, 1.0, 0.5, 1.0) # 아군은 초록색
		if ability_manager.is_valid_target(card.card_data, enemy):
			enemy.avatar.modulate = Color(1.0, 0.2, 0.2, 1.0) # 적은 빨간색

func show_description(card: Area2D):
	if description_manager:
		if description_manager.has_method("show_card"):
			description_manager.show_card(card.card_data, card.global_position) # 카드 데이터와 '원본 카드 위치'를 함께 넘겨줌
		else:
			description_manager.show()

func hide_description():
	if description_manager and description_manager.has_method("hide_card"):
		description_manager.hide_card()

func update_master_statuses():
	_update_single_master_status(player, player_status_container)
	_update_single_master_status(enemy, enemy_status_container)
	
func _update_single_master_status(master_obj: Master, container: Node):
	if not container: return
	for child in container.get_children():
		child.queue_free()
	var STATUS_ICON = preload("res://scenes/StatusIcon.tscn") # 실제 경로에 맞게 수정하세요!
	for status_id in master_obj.status_effects:
		var amount = master_obj.status_effects[status_id]
		var icon = STATUS_ICON.instantiate()
		container.add_child(icon)
		icon.setup(status_id, amount, Vector2(45, 45)) # UI (본체) 옆에 띄울 아이콘의 큼직한 크기 설정!
