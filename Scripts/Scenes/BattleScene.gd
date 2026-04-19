extends Control

const CARD_SCENE = preload("res://scenes/Card.tscn")

@onready var ui_manager = $UI
@onready var ability_manager = $AbilityManager
@onready var enemy_ai = $EnemyAIManager
@onready var dialogue_manager = $DialogueManager


@onready var player_hand = $PlayerHand 
@onready var enemy_hand = $EnemyHand

@onready var attack_line = $UI/AttackLine
@onready var input_blocker = $InputBlocker

@onready var player_battlefield_nodes = [$Battlefield/PlayerSlot0, $Battlefield/PlayerSlot1, $Battlefield/PlayerSlot2]
@onready var enemy_battlefield_nodes = [$Battlefield/EnemySlot0, $Battlefield/EnemySlot1, $Battlefield/EnemySlot2]


var current_master: Master = null

class Master:
	var name: String

	var avatar: Node

	var hp:int = 20
	var max_mana:int = 0
	var mana:int = 0

	var hand: Array = []
	var battlefield: Array = [null, null, null]
	var deck: Array = []

	func add_node_to_hand(card: Control):
		hand.append(card)
	func remove_node_from_hand(card: Control):
		hand.erase(card)

	func add_node_to_battlefield(card: Control, index: int):
		battlefield[index] = card
	func remove_node_from_battlefield(index: int):
		battlefield[index] = null

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
	if master_ == enemy:
		enemy.add_node_to_hand(new_card)
		enemy_hand.add_child(new_card)
	else:
		player.add_node_to_hand(new_card)
		player_hand.add_child(new_card)
	new_card.init_card(data, master_)
	new_card.update_display()
	print("Hand of %s : %s 추가" % [master_.name, data["name"]])

func cast_magic(card: Control, master: Master):
	card.foreground.visible = false

	print("마법 시전: %s가 %s 사용" % [master.name, card.card_data["name"]])

	card.top_level = true
	card.z_index = 100

	card.current_state = card.State.ON_BOARD
	master.remove_node_from_hand(card)
	ui_manager.update()
	
	var tween = create_tween()

	tween.tween_property(card, "global_position", card.global_position, 0)\
		.set_ease(Tween.EASE_IN_OUT)
	tween.chain()\
		.tween_property(card, "global_position", Vector2(1920/2.0, 1080/2.0) - (card.size * card.scale / 2.0), 0.2)\
		.set_ease(Tween.EASE_IN_OUT)
	tween.parallel()\
		.tween_property(card, "scale", card.SCALE_BOARD*1.5, 0.2)\
		.set_ease(Tween.EASE_IN_OUT)
	tween.tween_interval(0.5)
	tween.chain()\
		.tween_property(card, "scale", Vector2(0, 0), 0.1)\
		.set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(func():
		ability_manager.trigger_ability("onUse", card) # 사용 시 발동
		card.z_index = 0
		card.top_level = false
		card.queue_free()
	)
	
	await tween.finished


		
func summon_to_slot(card, slot_node, master, index):
	card.foreground.visible = false
	card.z_index = 100

	card.current_state = card.State.ON_BOARD

	master.remove_node_from_hand(card)
	card.top_level = false
	ui_manager.update()
	card.update_display()

	# 1. 슬롯의 중앙 위치 계산

	var slot_center = slot_node.global_position + (slot_node.get_size() / 2.0)

	card.scale = card.SCALE_DRAG
	if master == enemy:
		card.scale = card.SCALE_HAND
		var tween = create_tween()
		tween.tween_property(card, "global_position", card.global_position, 0)\
			.set_ease(Tween.EASE_IN_OUT)
		tween.parallel()\
			.tween_property(card, "scale", card.SCALE_DRAG, 0.05)\
			.set_ease(Tween.EASE_IN_OUT)
		tween.chain()\
			.tween_property(card, "global_position", slot_center-(card.size * card.scale / 2.0), 0.1)\
			.set_ease(Tween.EASE_IN_OUT)
		# 3. 트윈 끝난 후 reparent 및 anchor/preset 적용
		tween.finished.connect(func():
			print("끝")
		)
		await tween.finished
	
	card.reparent(slot_node, false)
	card.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	await card.set_on_board(index)

	master.battlefield[index] = card # 배열에 기록
	card.z_index = 0
	ability_manager.trigger_ability("onUse", card) # 소환 시 발동 능력 체크
	print("hand to bf: %s의 슬롯%d에 %s 소환" % [master.name, index, card.card_data["name"]])

func change_turn():
	for card in current_master.battlefield:
		if card != null:
			ability_manager.trigger_ability("onTurnEnd", card) #이전 턴 마스터 턴 미니언 종료 능력 활성
	
	current_master = enemy if current_master == player else player 

	print("턴이 변경. 현재 턴:%s" % (current_master.name))

	$UI/EndTurnButton.disabled = current_master != player # 플레이어 턴일 때만 종료 버튼 활성화

	draw_cards(current_master, 1) # 턴이 바뀔 때마다 카드 한 장 뽑기
	current_master.grow_mana()
	current_master.refill_mana()

	for card in current_master.battlefield: # 바뀐 턴 마스터 턴 미니언 시작 능력 활성
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
	var tween = create_tween()

	var scale_origin = attacker.scale
	var scale_attack = scale_origin * 1.2

	var start_pos = attacker.get_global_rect().position
	var start_center = attacker.get_global_rect().position+( attacker.size*scale_origin / 2.0)

	tween.tween_property(attacker, "scale", scale_attack, 0.1) # 시작 위치 고정 (드래그 중이던 카드가 갑자기 튀는 걸 방지하기 위해)

	var target_center = Vector2.ZERO
	if target is Master:
		target_center = target.avatar.global_position + (target.avatar.size * target.avatar.scale / 2.0)
	else:
		target_center = target.global_position + (target.size * target.scale / 2.0)
	var target_pos = target_center - (attacker.size * scale_attack / 2.0)
	var wind_center = (start_center).lerp(target_center, -0.1)

	# 공격 준비 (살짝 뒤로)
	tween.chain()\
		.tween_property(attacker, "global_position", wind_center-(attacker.size * scale_attack / 2.0), 0.1)
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

func destroy_minion(card: Control):
	# 1. 전장 배열에서 해당 데이터 삭제
	card.master.battlefield[card.battlefield_position] = null
	card.queue_free()

func set_input_lock(is_locked: bool):
	input_blocker.visible = is_locked

func _is_targetable(_attacker, target) -> bool:
	if not is_instance_valid(target): return false

	var target_owner = target if target is Master else target.master
	
	# 2. 적 필드에서 '도발' 미니언이 있는지 싹 뒤져!!!!!
	# 마스터는 도발이 없다고 했으니 battlefield만 검사하면 끝이야!!!!!
	var taunt_minions = target_owner.battlefield.filter(func(c):
		if not is_instance_valid(c): return false
		return c.card_data.get("abilities", {}).get("keyword", {}).get("ID") == "TAUNT"
	)

	# 3. 판정 로직
	if taunt_minions.size() > 0:
		if not (target in taunt_minions):
			return false
	# 4. 도발이 없거나, 찍은 타겟이 도발 미니언이라면 공격 가능
	return true
