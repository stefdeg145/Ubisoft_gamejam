extends Node
## Global progress tracker for "The Last Morning".
## Autoloaded as `GameState`. Holds run state in memory (prototype – no save file).

## The grief stages, in order. Acceptance is the finale.
const STAGES := ["Denial", "Anger", "Bargaining", "Depression", "Acceptance"]

## Index of the memory the player can currently face (the one that glows).
var current_index := 0

## Names of stages the player has resolved.
var completed: Array[String] = []

## Memory fragments collected (flavour text shown on the pause/among the HUD).
var fragments: Array[String] = []

## Set once the player pockets the photograph in Anger; bridges to Bargaining.
var has_photo := false

## True until the player has woken for the first time (drives the intro beats).
var first_wake := true

## True until the title card has been shown once.
var title_shown := false

func current_stage() -> String:
	if current_index < STAGES.size():
		return STAGES[current_index]
	return "Acceptance"

func is_active(stage_name: String) -> bool:
	return stage_name == current_stage() and not completed.has(stage_name)

func complete_stage(stage_name: String, fragment := "") -> void:
	if not completed.has(stage_name):
		completed.append(stage_name)
	if fragment != "":
		fragments.append(fragment)
	current_index = min(current_index + 1, STAGES.size())

## 0.0 = fully grey/cold house, 1.0 = warm & at peace. Drives the house grade.
func warmth() -> float:
	return float(completed.size()) / float(STAGES.size())

func reset() -> void:
	current_index = 0
	completed.clear()
	fragments.clear()
	has_photo = false
	first_wake = true
	title_shown = false
