class_name GameManager
extends RefCounted

## Coordinador ligero entre modo, nivel actual, guardado y puntuación.


static func begin_level(level_id: int) -> Dictionary:
	LevelManager.set_current_level(level_id)
	return LevelManager.get_level(level_id)


static func complete_level(level_id: int, moves: int, elapsed_sec: float = -1.0) -> Dictionary:
	var level := LevelManager.get_level(level_id)
	var stars := LevelManager.calculate_stars(level, moves)
	var reward: Dictionary = SaveManager.register_level_complete(
		level_id, moves, stars, "", elapsed_sec, level
	)
	return {
		"stars": stars,
		"moves": moves,
		"hint_reward": int(reward.get("hint_reward", 0)),
		"first_perfect": bool(reward.get("first_perfect", false)),
		"streak_reward": bool(reward.get("streak_reward", false)),
		"streak_counted": bool(reward.get("streak_counted", false)),
		"next_level_id": LevelManager.get_next_level_id(level_id),
		"mode": LevelManager.current_mode,
	}


static func current_playable_level_id() -> int:
	return maxi(1, SaveManager.get_last_unlocked_level())
