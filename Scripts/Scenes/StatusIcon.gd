extends TextureRect

@onready var count_label = $CountLabel

func _ready():
    var tooltip_theme = Theme.new()
    tooltip_theme.set_font_size("font_size", "TooltipLabel", 30) # 아이콘 툴팁 크기
    theme = tooltip_theme

func setup(status_id: String, amount: int, icon_size: Vector2 = Vector2(30, 30)):
    custom_minimum_size = icon_size # 부모 컨테이너에게 요구할 자신의 크기 강제 지정!
    count_label.text = str(amount)
    
    var s_data = CardDatabase.get_status_data(status_id)
    var status_name = s_data.get("name", "알 수 없는 효과")
    var status_desc = s_data.get("description", "효과가 적용 중입니다.")
    
    if s_data.has("icon_path"):
        texture = load(s_data["icon_path"])

    # 현재 스택에 따른 실시간 수식 및 결과 계산 텍스트 추가
    var dynamic_text = ""
    if status_id == "CHARM":
        dynamic_text = "\n▶ 현재 강제 선택 확률: %d%% " % [amount * 10]
    elif status_id == "POISON":
        dynamic_text = "\n▶ 턴 종료 시 받을 데미지: %d" % amount

    tooltip_text = "%s : %d스택\n%s%s" % [status_name, amount, status_desc, dynamic_text]