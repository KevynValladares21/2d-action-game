class_name HurtBox
extends Area2D

signal received_damage(damage: int)

@export var health: Health

func _ready() -> void:
	connect("area_entered", _on_area_entered)

func _on_area_entered(hitbox) -> void:
	if hitbox is HitBox:
		health.set_health(health.health - hitbox.damage)
		received_damage.emit(hitbox.damage)
