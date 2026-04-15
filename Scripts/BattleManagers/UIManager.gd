extends Node

@onready var battle_scene = get_parent()

@onready var player_mana_label = $PlayerManaLabel
@onready var player_hp_label = $PlayerHPLabel

@onready var enemy_mana_label = $EnemyManaLabel
@onready var enemy_hp_label = $EnemyHPLabel

@onready var player_deck_label = $PlayerDeckLabel
@onready var enemy_deck_label = $EnemyDeckLabel

func update():
	player_mana_label.text = "%d/%d" % [battle_scene.player.mana, battle_scene.player.max_mana]
	enemy_mana_label.text = "%d/%d" % [battle_scene.enemy.mana, battle_scene.enemy.max_mana]
	player_hp_label.text = "%d" % battle_scene.player.hp
	enemy_hp_label.text = "%d" % battle_scene.enemy.hp
	player_deck_label.text = "%d장" % battle_scene.player.deck.size()
	enemy_deck_label.text = "%d장" % battle_scene.enemy.deck.size()
