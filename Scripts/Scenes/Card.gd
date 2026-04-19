extends Area2D

# 연출용 스케일 값 정의 (상수로 관리해!!!!!)
const SCALE_HAND = Vector2(1, 1)   # 손패에서는 작게!!!!!
const SCALE_DRAG = Vector2(1.1, 1.1)   # 드래그 중엔 크게!!!!! (1.2는 너무 커!!!!!)
const SCALE_BOARD = Vector2(0.8, 0.8)  # 전장에선 원래대로!!!!!

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

@onready var illustration = $Illustration
@onready var outline = $AttackableShadow
@onready var foreground = $FG

var card_data: Dictionary
var master: Object
var attackable: int = 0
var slot_position = -1 # 전장 위치 (0,1,2) -1은 아직 전장에 안 나왔다는 뜻
var placeholder: Node2D = null

func _ready():
	scale = SCALE_HAND
	
	input_pickable = true
	input_event.connect(_on_area_2d_input_event)

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
		foreground.visible = true

func _on_area_2d_input_event(_viewport, event, _shape_idx):
	if battle_scene.current_master != battle_scene.player:
		return
	if master != battle_scene.player:
		return
		
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			print("카드 입력 감지: ", card_data["name"], " 현재 상태: ", current_state)
			if event.pressed:
				get_viewport().set_input_as_handled() # 카드 중복 클릭 방지 (맨 위 카드만 잡히게 함)
				input_manager.start_drag(self)

func update_display():
	if card_data["type"] == "minion":
		labels.atk.text = str(card_data["atk"])
		labels.hp.text = str(card_data["hp"])
		outline.visible = attackable > 0

func set_on_board(index: int):
	slot_position = index
	current_state = State.ON_BOARD
	
	var tween = create_tween()
	tween.chain()\
		.tween_property(self, "scale", SCALE_DRAG*1.1, 0.1).set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_IN_OUT)
	tween.chain()\
		.tween_property(self, "scale", SCALE_BOARD, 0.2).set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_IN_OUT)
	await tween.finished

func animate_scale(target_scale: Vector2):
	var tween = create_tween()
	tween.tween_property(self, "scale", target_scale, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	await tween.finished

func create_placeholder():
	placeholder = Node2D.new()
	placeholder.global_position = global_position
	get_parent().add_child(placeholder)
	get_parent().move_child(placeholder, get_index())

func remove_placeholder():
	if is_instance_valid(placeholder):
		placeholder.queue_free()
		placeholder = null

func safety_top_level(target: bool):
	var current_pos = global_position
	top_level = target 
	global_position = current_pos
