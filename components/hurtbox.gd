class_name HurtBox
extends Area2D

signal received_damage(damage: int)

@export var health: Health
@export var faction: String = "player"

func _ready() -> void:
	connect("area_entered", _on_area_entered)

func _on_area_entered(hitbox) -> void:
	if hitbox is HitBox and faction != hitbox.faction:
		health.set_health(health.health - hitbox.damage)
		received_damage.emit(hitbox.damage)
