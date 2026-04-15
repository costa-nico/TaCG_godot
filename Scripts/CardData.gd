extends Resource
class_name CardData

@export var id: int = 0
@export var card_name: String = ""
@export var cost: int = 0
@export var atk: int = 0
@export var hp: int = 0
@export var texture: Texture2D # 단순 문자열 대신 실제 이미지 리소스를 담는 게 좋아!!!!!
@export var keywords: Array[String] = []
@export var abilities: Dictionary = {}
