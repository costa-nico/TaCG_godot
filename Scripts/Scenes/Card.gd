extends Area2D

# 연출용 스케일 값 정의 (상수로 관리해!!!!!)
const SCALE_HAND = Vector2(0.4, 0.4)   # 손패에서는 작게
const SCALE_DRAG = Vector2(0.6, 0.6)   # 
const SCALE_BOARD = Vector2(0.45, 0.45)  # 전장에선 원래대로
const SCALE_DESC = Vector2(1, 1)   # 설명 창에서의 크기

const COLOR_ATTACKABLE = Color(0, 0.5, 0, 0.5) # 아군 공격 가능 (초록색 오라)
const COLOR_TARGETABLE = Color(1.0, 0, 0, 0.5) # 타겟으로 지정됨 (빨간색 오라)

const CARD_SIZE = Vector2(200, 300)

enum State { IN_HAND, DRAGGING_TO_USE, ON_BOARD, DRAGGING_TO_ATTACK, SNAPPED}
var current_state: State = State.IN_HAND

@onready var battle_scene = get_tree().current_scene
@onready var input_manager = battle_scene.input_manager

# 노드 참조
@onready var labels = {
	"name": $Labels/NameLabel,
	"atk": $Labels/AtkLabel,
	"hp": $Labels/HpLabel,
	"cost": $Labels/CostLabel
}

@onready var illustration = $Illust/Texture
@onready var aura = $Aura
@onready var cover = $Cover

var card_data: Dictionary
var master: Object
var attackable: int = 0
var slot_position = -1 # 전장 위치 (0,1,2) -1은 아직 전장에 안 나왔다는 뜻
var placeholder: Node2D = null

var is_hovered: bool = false
var base_position: Vector2 = Vector2.ZERO
var base_rotation: float = 0.0
var base_z_index: int = 0
var card_tween: Tween
var aura_tween: Tween # 오라 애니메이션 전용 트윈
var _current_aura_color: Color = Color.TRANSPARENT # 오라 중복 실행 방지용

func _ready():
	scale = SCALE_HAND
	
	input_pickable = true
	input_event.connect(_on_area_2d_input_event)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	aura.visible = false

func init_card(data: Dictionary, master_: Object):
	card_data = data.duplicate(true)
	
	labels.name.text = data["name"]
	labels.cost.text = str(data["cost"])

	if self.card_data["type"] == "minion":
		labels.atk.text = str(data["atk"])
		labels.hp.text = str(data["hp"])
	else:
		labels.hp.text = ""
		labels.atk.text = ""
	self.master = master_
	if data.has("texture_path"):
		illustration.texture = load(data["texture_path"])
	if self.master == battle_scene.enemy:
		cover.visible = true

func _on_mouse_entered():
	if current_state == State.IN_HAND and master == battle_scene.player:
		battle_scene.update_hover(self)

func _on_mouse_exited():
	if battle_scene.hovered_card == self:
		battle_scene.update_hover(null)

func _on_area_2d_input_event(_viewport, event, _shape_idx):
	if battle_scene.current_master != battle_scene.player or master != battle_scene.player:
		return
		
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				# 드래그 감지 로직은 겹침 버그 방지를 위해 InputManager._input()의 물리 광선(RayCast) 시스템으로 이관되었습니다.
				pass

func update_display():
	if card_data["type"] == "minion":
		labels.atk.text = str(card_data["atk"])
		labels.hp.text = str(card_data["hp"])
		_animate_aura(attackable > 0, COLOR_ATTACKABLE) # 트윈 애니메이션으로 오라 켜기/끄기

func set_on_board(index: int):
	slot_position = index
	current_state = State.ON_BOARD
	
	var tween = get_card_tween() # 이전에 재생 중이던 손패 애니메이션을 즉시 취소함
	tween.chain()\
		.tween_property(self, "scale", SCALE_DRAG*1.1, 0.1).set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_IN_OUT)
	tween.chain()\
		.tween_property(self, "scale", SCALE_BOARD, 0.2).set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_IN_OUT)
	await tween.finished

func get_card_tween() -> Tween:
	if card_tween and card_tween.is_valid():
		card_tween.kill() # 새 애니메이션 시작 전 기존 애니메이션 완벽 차단!
	card_tween = create_tween()
	return card_tween

func create_placeholder():
	placeholder = Node2D.new()
	placeholder.global_position = global_position
	get_parent().add_child(placeholder)
	get_parent().move_child(placeholder, get_index())

func remove_placeholder():
	if is_instance_valid(placeholder):
		placeholder.queue_free()
		placeholder = null

func set_hover_state(is_on: bool):
	if is_hovered == is_on: return
	is_hovered = is_on
	var tween = get_card_tween()
	if is_hovered:
		z_index = 100
		var hover_pos = Vector2(base_position.x, master.hand_position.y - 40) # X는 자기 자리 유지, Y는 핸드 기준선에서 고정된 높이로 띄움
		tween.tween_property(self, "global_position", hover_pos, 0.1).set_trans(Tween.TRANS_QUAD)
		tween.parallel().tween_property(self, "rotation_degrees", 0.0, 0.1).set_trans(Tween.TRANS_QUAD)
		tween.parallel().tween_property(self, "scale", SCALE_DRAG, 0.1).set_trans(Tween.TRANS_QUAD)
	else:
		z_index = base_z_index
		if current_state == State.IN_HAND and input_manager.dragging_card != self: # 내가 드래그 시작된 카드라면 원래 자리로 돌아가는 애니메이션 무시
			tween.tween_property(self, "global_position", base_position, 0.1).set_trans(Tween.TRANS_QUAD)
			tween.parallel().tween_property(self, "rotation_degrees", base_rotation, 0.1).set_trans(Tween.TRANS_QUAD)
			tween.parallel().tween_property(self, "scale", SCALE_HAND, 0.1).set_trans(Tween.TRANS_QUAD)

func set_target_highlight(is_on: bool):
	if is_on:
		_animate_aura(true, COLOR_TARGETABLE)
	else:
		update_display() # 본래 attackable 상태에 맞게 visible 초기화

func _animate_aura(is_on: bool, target_color: Color):
	# 동일한 색상으로 이미 애니메이션 중이거나, 이미 꺼져 있는 경우 트윈 재시작(깜빡임) 방지
	if is_on and aura.visible and _current_aura_color == target_color and aura_tween and aura_tween.is_valid():
		return
	if not is_on and not aura.visible:
		return
		
	_current_aura_color = target_color if is_on else Color.TRANSPARENT

	if aura_tween and aura_tween.is_valid():
		aura_tween.kill() # 진행 중이던 오라 애니메이션 초기화
		
	if is_on:
		if not aura.visible:
			aura.visible = true
			var start_color = target_color
			start_color.a = 0.0
			aura.modulate = start_color # 처음 켜질 때는 투명도 0에서 시작
			
		aura_tween = create_tween().set_loops() # 무한 반복(숨쉬기 효과)
		# 1. 지정된 색상으로 밝아짐
		aura_tween.tween_property(aura, "modulate", target_color, 2).set_trans(Tween.TRANS_SINE)
		# 2. 원래 설정한 투명도의 30% 수준으로 살짝 어두워짐
		var dim_color = target_color
		dim_color.a = target_color.a * 0.3 
		aura_tween.tween_property(aura, "modulate", dim_color, 2).set_trans(Tween.TRANS_SINE)
	else:
		if not aura.visible: return
		
		aura_tween = create_tween() # 끌 때는 반복 없이 서서히 사라짐
		var end_color = aura.modulate
		end_color.a = 0.0
		aura_tween.tween_property(aura, "modulate", end_color, 0.5).set_trans(Tween.TRANS_SINE)
		aura_tween.tween_callback(func(): aura.visible = false)
