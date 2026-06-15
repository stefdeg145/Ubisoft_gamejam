# The Last Morning

A short narrative game about moving through grief — Denial, Bargaining, Depression,
Acceptance — one morning at a time. Built in **Godot 4.6** for a game jam (theme: *Peace*).

The whole game teaches by feeling, not text: you wake in a quiet, grey house, and the
only thing you can face is the one memory that's glowing. Touch it, fall asleep, and
dream that morning again. Each memory you make peace with warms the house a little more.

---

## Run it

1. Open the project in **Godot 4.6** (`project.godot`).
2. Press **F5** (Play). The game starts on the cold open.

> ⚠️ If you edited `project.godot` outside the editor while Godot was open, Godot may
> overwrite it on save. Close the editor before pulling changes, or re-open after.

### Controls
| Action | Keys |
| --- | --- |
| Move | Arrow keys or **WASD** |
| Look / interact | **E** or **Enter** |
| Advance the cold open / restart | any key |

---

## The flow

```
cold_open  ──►  house (hub)  ──►  stage (dream)  ──►  back to house (warmer)  ──►  …  ──►  ending
```

* **Cold open** (`scenes/intro/cold_open.tscn`) — black screen, a heartbeat, *"Stay with
  me."*, a flatline. The line is the player's own unfinished sentence from the ending; it
  pays off on a replay.
* **House hub** (`scenes/house/house.tscn`) — an oblique (2.5D) apartment you actually see
  the papered walls of. You wake asleep in the chair by the window. One memory glows; the
  rest return *"I'm not ready."* Built procedurally in `house.gd` so the scene file stays
  tiny and diff-friendly. Completing stages lifts the grey grade (`CanvasModulate`).
* **The four dreams**, each its **own scene with its own camera angle**:
  * **Denial — "The Ordinary Morning"** (`stage_denial`, *side view kitchen*). The room
	won't let things be wrong: everything you straighten undoes itself. The way out is to
    stop fixing and **sit at the table** — let the broken morning be broken.
  * **Bargaining — "The Last Meeting"** (`stage_bargaining`, *front-on dialogue*). Multiple
    choice attempts to fix the last conversation with the person you lost. Every choice
    ends the same way. *"Maybe I was the one at fault."*
  * **Depression — "Insomnia"** (`stage_depression`, *dark top-down bedroom*). You can't
	sleep; you replay their voice; thirsty, you mash to reach the water — and pass out,
	down into acceptance. The screen darkens with each beat.
  * **Acceptance — "The Last Morning"** (`stage_acceptance`, *cinematic*). The one true
	awakening. No mechanic — only presence. *"Stay with me"* finally lands, you let them
	go, and wake for real into a warm, rain-stopped morning.

All transitions share one grammar — the **drift-to-sleep vignette** in `Game` (the
`scripts/autoload/game.gd` overlay): glowing object → fall asleep → dream → wake.

---

## Project structure

```
project.godot              # autoloads, input map, 1280×720, nearest-neighbour filter
icon.svg
scenes/
  intro/cold_open.tscn     # phase 0
  house/house.tscn         # 2.5D hub (built in house.gd)
  actors/player.tscn       # CharacterBody2D + camera
  stages/                  # the four dreams
  legacy/house_topdown.tscn# the original blueprint-style top-down house (kept for reference)
scripts/
  autoload/game_state.gd   # progress, current memory, warmth()
  autoload/game.gd         # fades, drift-to-sleep, captions, title card
  player.gd                # 4-direction code-driven walk animation
  memory_object.gd         # the glowing / locked memories in the hub
  interactable.gd          # generic in-stage interactable
  stage_base.gd            # shared side-view stage scaffolding
assets/art/
  characters/              # 16 walk frames (down/left/up/right × 4) sliced from the sheets
  house/  props/  stage1/  fx/
  source_sheets/           # the original supplied walk sheets
tools/gen_assets.py        # regenerates all pixel art (see below)
```

---

## Art

The art is **chunky retro pixel art** in an **oblique 2.5D** style for the hub (you see the
wall faces and patterns, furniture has visible front faces) and dedicated camera angles per
stage. Everything except the character is generated procedurally and is fully reproducible:

```bash
python3 tools/gen_assets.py      # needs: pip install pillow numpy
```

The **character** is the artist-supplied silhouette. The three walk sheets
(`assets/art/source_sheets/`) were sliced into 4 frames each for front / side / back; the
**right** walk is the mirror of the supplied **left** walk. Re-slice with:

```bash
# (slicing logic lives in the asset notes; frames already committed under characters/)
```

To tune the pixel chunkiness, edit `pixelate()` / `grain()` and the base resolutions in
`tools/gen_assets.py`, then re-run it.

---

## Status (prototype)

This is a runnable vertical slice: the full emotional arc plays start to finish. Known
rough edges to polish next: no audio yet (the heartbeat/rain are described, not played),
collision boxes are approximate, and the stage mechanics are intentionally minimal. Sound,
controller support, and a save file are the natural next steps.
