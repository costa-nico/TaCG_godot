extends Node

# 배틀씬 참조
@onready var battle_scene = get_parent()

# 어빌리티 실행 메인 함수
func trigger_ability(trigger_type: String, source_card: Control):
	var abilities = source_card.card_data.get("abilities", {})
	if not abilities.has(trigger_type):
		return
	var ability_data = abilities[trigger_type]
	# 배열인 경우와 단일 객체인 경우 모두 처리 (확장성)
	if ability_data is Array:
		for effect in ability_data:
			_execute_effect(effect, source_card)
	else:
		_execute_effect(ability_data, source_card)

# 실제 효과를 물리적으로 적용
func _execute_effect(effect: Dictionary, source: Control):
	var effect_id = effect["ID"]
	var target_type = effect["target"]
	var amount = effect.get("amount", 0)
	
	# 1. 대상(Target) 확정
	var targets = _get_targets(target_type, source)
	
	# 2. 연출 및 효과 적용
	for target in targets:
		_apply_popping(source) # 번쩍이는 연출 넣어
		_apply_effect_by_id(effect_id, target, amount)

func _apply_effect_by_id(effect_id: String, target, amount):
	match effect_id:
		"ADD_HP":
			if target is Control: # 카드인 경우
				target.card_data["hp"] += amount
				target.update_display()
			else: # 마스터인 경우
				target.hp += amount
				battle_scene.ui_manager.update()
		"ADD_MANA":
			target.mana += amount
			battle_scene.ui_manager.update()
		"DOUBLE_HP":
			target.card_data["hp"] *= 2
			target.update_display()
		"DRAW_CARD":
			battle_scene.draw_cards(target, amount)
			pass
	
# 타겟팅 로직 분리
func _get_targets(target_type: String, source: Control) -> Array:
	var result = []
	match target_type:
		"self":
			result.append(source)
		"my_master":
			result.append(battle_scene.player if source.master == battle_scene.player else battle_scene.enemy)
		"other_master":
			result.append(battle_scene.enemy if source.master == battle_scene.player else battle_scene.player)
	return result

# 능력 발동 시 시각적 피드백!!!!!
func _apply_popping(target):
	if target is Control: # 카드면 살짝 키웠다 줄여!!!!!
		var tween = create_tween()
		tween.tween_property(target, "scale", target.scale * 1.2, 0.1)
		tween.chain().tween_property(target, "scale", target.scale	, 0.1)
