extends Node2D

const CARD_SCENE = preload("res://scenes/Card.tscn")

@onready var ui_manager = $UI

@onready var ability_manager = $Managers/AbilityManager
@onready var enemy_ai = $Managers/EnemyAIManager
@onready var dialogue_manager = $Managers/DialogueManager
@onready var input_manager = $Managers/InputManager


@onready var attack_line = $UI/AttackLine
@onready var input_blocker = $InputBlocker

@onready var player_slot_nodes = [$Slots/P1, $Slots/P2, $Slots/P3]
@onready var enemy_slot_nodes = [$Slots/E1, $Slots/E2, $Slots/E3]

@onready var magic_slot = $MagicSlot # 실제 씬의 마법 슬롯 경로에 맞게 수정해 주세요!!!!!

@onready var card_container = $Cards

const PLAYER_HAND_CENTER_POS = Vector2(576, 600)
const ENEMY_HAND_CENTER_POS = Vector2(576, 200)

const CARD_SPACING = 120.0

var current_master: Master = null

class Master:
	var name: String

	var avatar: Node

	var hp:int = 20
	var max_mana:int = 0
	var mana:int = 0

	var hand_position: Vector2 = Vector2.ZERO

	var hand: Array[Area2D] = []
	var slot: Array[Area2D] = [null, null, null]
	var deck: Array = []

	func add_card_to_hand(card: Area2D):
		hand.append(card)
	func remove_card_from_hand(card: Area2D):
		hand.erase(card)

	func add_card_to_slot(card: Area2D, index: int):
		slot[index] = card
	func remove_card_from_slot(index: int):
		slot[index] = null

	func grow_mana():
		if max_mana < 10:
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
	attack_line.width = 10.0
	attack_line.default_color = Color(1, 0, 0, 0.7)

	refill_deck(player)
	refill_deck(enemy)

	draw_cards(player, 5)
	draw_cards(enemy, 5)

	ui_manager.update()

func refill_deck(master: Master):
	print("덱 리필: %s의 덱을 카드 데이터로 채웁니다." % master.name)
	if(master == player):
		for card_id in DeckLib.get_player_deck():
			var amount = DeckLib.get_player_deck()[card_id]
			for i in range(amount):
				master.deck.append(card_id)
	elif(master == enemy):
		for card_id in DeckLib.get_enemy_deck():
			var amount = DeckLib.get_enemy_deck()[card_id]
			for i in range(amount):
				master.deck.append(card_id)
	master.deck.shuffle()
	ui_manager.update()

func draw_cards(master: Master, amount: int):
	for i in range(amount):
		if master.deck.size() == 0:
			print("%s의 덱이 비었습니다!" % master.name)
			refill_deck(master)
		var new_card_id = master.deck.pop_front()
		var new_card_data = CardDatabase.get_card_by_id(new_card_id)
		if new_card_data == {}:
			print("경고: 카드 데이터베이스에 %s 카드 정보가 없습니다. Dummy 카드로 대체합니다." % new_card_id)
			new_card_data = CardDatabase.get_card_by_id("DUMMY")
		add_to_hand(new_card_data, master)
	ui_manager.update()

func add_to_hand(data: Dictionary, master_: Master):
	var new_card = CARD_SCENE.instantiate()
	card_container.add_child(new_card)
	new_card.init_card(data, master_)
	master_.add_card_to_hand(new_card)
	new_card.update_display()

	reposition_hand(master_)
	print("Hand of %s : %s 추가" % [master_.name, data["name"]])

func reposition_hand(master_: Master):
	var count = master_.hand.size()
	for i in range(count):
		var card = master_.hand[i]
		# 중앙 정렬 수식: Center + (index - median) * spacing
		var target_x = master_.hand_position.x + (i - (count - 1) / 2.0) * CARD_SPACING
		var target_pos = Vector2(target_x, master_.hand_position.y)
		
		# 드래그 중이 아닐 때만 위치 조정
		if card.current_state == card.State.IN_HAND:
			var tween = create_tween()
			tween.tween_property(card, "global_position", target_pos, 0.2).set_trans(Tween.TRANS_QUAD)

func cast_magic(card: Area2D, master_: Master):
	card.foreground.visible = false


	card.safety_top_level(true)
	card.z_index = 100

	card.current_state = card.State.ON_BOARD
	master_.remove_card_from_hand(card)
	ui_manager.update()
	
	var tween = create_tween()
	var move_time = 0.0 if master_ == player else 0.2
	card.scale = card.SCALE_DRAG
	tween\
		.tween_property(card, "global_position", magic_slot.global_position, move_time)\
		.set_ease(Tween.EASE_IN_OUT)
	tween.tween_interval(0.5)
	tween.chain()\
		.tween_property(card, "scale", Vector2(0, 0), 0.1)\
		.set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(func():
		ability_manager.trigger_ability("onUse", card) # 사용 시 발동
		card.z_index = 0
		card.safety_top_level(false)
		card.queue_free()
	)
	
	await tween.finished

	reposition_hand(master_)
	print("마법 시전: %s가 %s 사용" % [master_.name, card.card_data["name"]])

		
func summon_to_slot(card: Area2D, slot_index: int, master_ : Master):
	var slot_node = player_slot_nodes[slot_index] if master_ == player else enemy_slot_nodes[slot_index]

	master_.hand.erase(card)
	master_.slot[slot_index] = card

	card.z_index = 10
	card.current_state = card.State.ON_BOARD
	card.foreground.visible = false

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
		# 3. 트윈 끝난 후 reparent 및 anchor/preset 적용
		tween.finished.connect(func():
			print("끝")
		)
		await tween.finished
		
	card.global_position = slot_node.global_position # 플레이어 드롭 보정 및 적 트윈 완료 후 완벽한 슬롯 정중앙 스냅
	await card.set_on_board(slot_index)
	card.z_index = 0
	ability_manager.trigger_ability("onUse", card) # 소환 시 발동 능력 체크
	reposition_hand(master_)
	print("hand to bf: %s의 슬롯%d에 %s 소환" % [master_.name, slot_index, card.card_data["name"]])

func change_turn():
	for card in current_master.slot:
		if card != null:
			ability_manager.trigger_ability("onTurnEnd", card) #이전 턴 마스터 턴 미니언 종료 능력 활성
	
	current_master = enemy if current_master == player else player 

	print("턴이 변경. 현재 턴:%s" % (current_master.name))

	$UI/EndTurnButton.disabled = current_master != player # 플레이어 턴일 때만 종료 버튼 활성화

	draw_cards(current_master, 1) # 턴이 바뀔 때마다 카드 한 장 뽑기
	current_master.grow_mana()
	current_master.refill_mana()

	for card in current_master.slot: # 바뀐 턴 마스터 턴 미니언 시작 능력 활성
		if card != null:
			card.attackable = 1 # 소환된 카드들은 다음 턴부터 공격 가능하게 설정
			ability_manager.trigger_ability("onTurnStart", card) # 플레이어 전장 카드의 턴 시작 시 발동 능력 체크
			card.update_display() # 공격 가능 여부에 따라 카드 색상 업데이트
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

	var tween = create_tween()
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
		else:				 # 미니언 공격
			ability_manager.trigger_ability("onHit", target) # 공격 후 발동 능력 체크
			attacker.card_data["hp"] -= target.card_data["atk"]
			target.card_data["hp"] -= attacker.card_data["atk"]
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
	if is_instance_valid(attacker) and attacker.card_data["hp"] <= 0:
		print("%s의 %s 전사" % [attacker.master.name, attacker.card_data["name"]])
		destroy_minion(attacker)
	if is_instance_valid(target) and target is not Master and target.card_data["hp"] <= 0:
		print("%s의 %s 전사" % [target.master.name, target.card_data["name"]])
		destroy_minion(target)
	set_input_lock(false) # 공격 애니메이션 완료 후 입력 잠금 해제

func destroy_minion(card: Area2D):
	# 1. 전장 배열에서 해당 데이터 삭제
	card.master.slot[card.slot_position] = null
	card.queue_free()

func set_input_lock(is_locked: bool):
	input_blocker.visible = is_locked

func _is_targetable(_attacker, target) -> bool:
	if not is_instance_valid(target): return false

	var target_owner = target if target is Master else target.master
	
	# 2. 적 필드에서 '도발' 미니언이 있는지 싹 뒤져!!!!!
	# 마스터는 도발이 없다고 했으니 battlefield만 검사하면 끝이야!!!!!
	var taunt_minions = target_owner.slot.filter(func(c):
		if not is_instance_valid(c): return false
		return c.card_data.get("abilities", {}).get("keyword", {}).get("ID") == "TAUNT"
	)

	# 3. 판정 로직
	if taunt_minions.size() > 0:
		if not (target in taunt_minions):
			return false
	# 4. 도발이 없거나, 찍은 타겟이 도발 미니언이라면 공격 가능
	return true
