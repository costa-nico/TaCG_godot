extends Node

const SAVE_PATH = "user://player_deck.json"

# 저장된 데이터가 없을 때 제공할 기본 덱
var default_deck: Dictionary = {
	"GIVE_UP": 1, # 테스트용 카드, 실제 게임에서는 제거 예정
	"SERVICE_START": 1,
	"ENHANCER": 1,
	"IRON_KNIGHT": 1,
	"COIN_POCKET": 5
}

var player_deck: Dictionary = {}

# 플레이어 프로필 정보
var player_avatar: String = "res://Images/cg/player.png" # 기본 플레이어 아바타 이미지 경로

var enemy_deck: Dictionary = {
	"DUMMY" : 30 # 테스트용 더미 카드, 실제 게임에서는 제거 예정
}

func set_enemy_deck_by_id(enemy_id: String):
	var enemy_data = EnemyDatabase.get_enemy_data(enemy_id)
	if not enemy_data.is_empty() and enemy_data.has("deck"):
		enemy_deck = enemy_data["deck"].duplicate()
	else:
		enemy_deck = { "DUMMY": 30 } # 등록되지 않은 적은 기본 더미 덱 사용

func _ready():
	load_deck() # 게임이 켜질 때 자동으로 덱을 불러옵니다!

# 덱 리스트 반환
func get_player_deck() -> Dictionary:
	return player_deck

func get_enemy_deck() -> Dictionary:
	return enemy_deck

# ==========================================
# 세이브 / 로드 시스템
# ==========================================
func save_deck():
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		# 딕셔너리를 JSON 문자열로 변환하여 파일에 저장
		file.store_string(JSON.stringify(player_deck))
		file.close()
		print("덱 저장 완료! 경로: ", SAVE_PATH)

func load_deck():
	if FileAccess.file_exists(SAVE_PATH):
		var json_string = FileAccess.get_file_as_string(SAVE_PATH)
		var loaded_data = JSON.parse_string(json_string)
		if loaded_data != null and typeof(loaded_data) == TYPE_DICTIONARY:
			player_deck = loaded_data
			print("덱 불러오기 완료!")
			return
			
	print("저장된 덱이 없거나 파일이 손상되어 기본 덱을 사용합니다.")
	player_deck = default_deck.duplicate()



	# "COIN": 2,
	# "APPRENTICE_SHIELDBEARER": 2,
	# "SHARP_ARROW": 2,
	# "POISON_DART": 2,
	# "ENHANCER": 2,
	# "IRON_KNIGHT": 2,
	# "LIGHTNING": 1,
	# "VICTORIOUS_COMMANDER": 1