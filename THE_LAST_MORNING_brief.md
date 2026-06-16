# THE LAST MORNING — Full Game Design & Build Brief

A 2D top-down (oblique) narrative game about moving through the five stages of grief.
Engine: **Godot 4** · Scope: **~20-hour gamejam (solo, AI-accelerated)** · Theme: **Peace**

---

## 0. How to read this brief

This document is split into three layers so you can build fast and cut safely:

- **STORY** — the fixed narrative and the fixes that make it coherent.
- **SYSTEMS** — the reusable mechanics every stage shares (movement, interaction, dialogue, UI, audio). Build these **once**.
- **STAGES** — each level described shot-by-shot: triggers, objects, puzzle logic, dialogue lines, SFX, exit condition.

Every section is tagged with a scope marker:

- **[MVP]** — must exist or the game doesn't read as finished. Build first.
- **[POLISH]** — do only if time remains.
- **[CUT-OK]** — nice idea, drop without guilt if the clock is against you.

A realistic 20-hour cut is given at the very end (Section 9). **Read that first if you're worried about time.**

---

## 1. STORY — review, fixes, and the locked canon

### 1.1 What's strong already
The core conceit is excellent and should not change: **grief is the antagonist, acceptance is the only "win," and every puzzle is solved by relinquishing control rather than exerting it.** The cold-open-as-ending-payoff and the "glowing object → sleep → dream → wake" grammar are both strong, cheap, and emotionally legible.

### 1.2 The three problems to fix

**Problem 1 — Who died, and who is the player? (the big one).**
The draft is ambiguous and the ambiguity hurts, not helps. The house objects (a shared mug, a coat that "smells like rain," falling asleep in the chair *waiting* for someone, "the last morning") all read as a **life partner / spouse**. But Stage 2 (Bargaining) says "a relative they lost… did not leave on good terms," which reads as an estranged parent or sibling. These feel like two different dead people, which quietly confuses the player.

> **FIX — Lock one lost person.** Make the lost person a **spouse/partner named ELI** (gender-neutral; pick art to taste). The "we didn't leave on good terms" beat in Bargaining becomes **their last ordinary argument** — small, stupid, unresolved, the kind every couple has — not a lifelong estrangement. This keeps the domestic objects consistent *and* gives Bargaining its "if only the last words were different" engine. One person, one home, one loss.

**Problem 2 — Whose heart monitor is in the cold open?**
Two readings: (a) Eli died and the player was at the bedside; (b) the *player* is dying and the whole game is their deathbed dream. Reading (b) is the "they were dead all along" twist — overused and it cheapens the grief.

> **FIX — It's Eli's monitor, and the player's unfinished line.** The cold open is the player's memory of Eli's last moment in hospital: the player whispered *"Stay with me,"* the monitor flatlined, and the sentence was never finished. The whole game is the player, weeks later, asleep in the chair at home, dreaming back through grief until they can finally *complete* that goodbye in the Acceptance dream. No "it was all a dream" gotcha — just a sentence the player gets to finish.

**Problem 3 — The dream grammar breaks after Stage 1.**
Stage 1 uses the clean "sleep → dream → wake" gateway. But Anger happens awake in the house, Bargaining triggers from pulling out a photo, Depression from failing to sleep. The grammar looks broken.

> **FIX — Make the broken grammar the point.** Formalize it as the **Bleed**: as grief deepens, the wall between the waking house and the memory dreams *dissolves*. Denial is a clean, contained dream (control still feels possible). By Anger and Bargaining the memories **intrude into the waking house** without permission (loss of control). Depression is the player *unable* to cross the threshold at all (can't sleep, can't escape). Acceptance is the **one willing, peaceful sleep** — control returns not by force but by surrender. This turns an inconsistency into the emotional throughline. State it once on screen and let the mechanics carry it.

### 1.3 Locked canon (use these everywhere)
- **Player character:** unnamed widow/widower. Never named on screen — the player is them.
- **Lost person:** **ELI**, the player's spouse/partner. Died after illness; the player was present.
- **The home:** a small apartment, top-down. The player fell asleep in the chair by the window, waiting out the rain, weeks after the funeral.
- **The sealed line:** *"Stay with me."* Spoken in the cold open, finishable only in Acceptance.
- **Recurring motif:** **rain on glass** (present = grief is near) and **warm light** (present = a memory is ready to be faced). The house de-saturates with grief and re-saturates as stages resolve.

### 1.4 Stage order (locked)
Cold Open → Intro (the house) → **1. Denial** → *(Anger bleed)* → **2. Anger** → **3. Bargaining** → **4. Depression** → **5. Acceptance** → Ending.

> Note: in the draft, Anger was only an "inter-level." It's promoted to a **real stage** with its own mechanic (Section 6.2). It's short, but it shouldn't be a hallway.

---

## 2. SYSTEMS — build these once, reuse everywhere

### 2.1 Camera & perspective
- **Top-down oblique (¾ tilt).** Floors read as ground plane; furniture/walls have a short front face so the room reads as a *room*, not a blueprint.
- `Camera2D` follows the player with **smoothing enabled** (`position_smoothing_speed ≈ 4`). Never snap.
- Slight **dead-zone** so micro-movements don't jitter the frame.
- Fixed zoom in the house; Acceptance is allowed a slow **zoom-out** at the very end (Section 6.5).

### 2.2 Movement mechanic **[MVP]**
- 8-directional, analog-friendly. `CharacterBody2D` + `velocity`.
- **Walk speed deliberately slow** (≈ 70–85 px/s). This is a grief game; the player should never feel they're rushing.
- **No run, no dash.** The inability to hurry is thematic.
- Acceleration/deceleration smoothing (`velocity = velocity.lerp(target, 0.2)`) so starts and stops feel heavy, like wading.
- Input map: `move_up/down/left/right` bound to **WASD + arrows + left stick**. `interact` bound to **E / Space / South button**. `advance` (dialogue) bound to the same `interact` plus **Enter / left-click**. One confirm verb keeps it legible.
- **Footstep cadence** scales with the grade: muffled, slow steps in the grey house; slightly warmer/clearer in resolved memories.
- Subtle **idle animation**: if the player stops for 3s, the character's shoulders fall on a slow breath loop. Sells weight at zero art cost.

### 2.3 Interaction mechanic **[MVP]**
- Each interactable is an `Area2D` named `Interactable` carrying exported fields:
  - `prompt_text : String` (e.g. "look")
  - `is_locked : bool`
  - `locked_line : String` (the "I'm not ready" line)
  - `dialogue_id : String` (which sequence to play when unlocked)
  - `glow : bool` (warm highlight on/off)
- **Proximity prompt:** when the player overlaps an interactable, a small floating prompt fades in above the object — a single soft glyph + word, e.g. `◦ look`. No giant tooltip.
- **One button.** Press `interact` → if `is_locked`, play `locked_line` as a one-shot subtitle and a soft denial tone; else start `dialogue_id`.
- **Glow** = the one object that advances the stage. Implement as an additive-blend sprite or a `PointLight2D` with warm color, gently pulsing (`modulate.a` sine, period ≈ 2.5s). It is the **only warm thing** in a grey room — this *is* the navigation system. No arrows, no quest markers, ever.

### 2.4 Interactive dialogue system **[MVP]**
This is the spine of the whole game. Build it well; everything else hangs off it.

**Visual layout**
- Dialogue is **diegetic, not a boxed RPG textbox.** Two registers:
  1. **Inner-voice subtitles** — the player character's thoughts. Centered low on screen, small, soft serif, off-white, no name tag, no border. Fades in word-by-word (typewriter, ~30 chars/s). Used for object thoughts and the "I'm not ready" lines.
  2. **Floating ambient text** — used in Anger. Near-transparent words drift in *world space* around the character, attached to the things that provoke them, then fade. Not subtitles — environmental.
- **Choice dialogue (Bargaining)** uses a minimal vertical list of 2–3 options, low-center, each option a plain line of text that brightens on hover/select. No box, no portraits. A faint underline marks the focused option.

**Behaviour**
- Text advances on `advance`. Never auto-advance important lines; *do* auto-advance ambient floats.
- **SFX on dialogue open:** a single soft, low **felt-piano note + a breath of air / paper rustle**, volume low, one-shot. Different memories get a slightly different note (see per-stage audio). This is the "a memory is speaking" cue. Inner-voice lines get a quieter version; choice prompts get a slightly colder, hesitant note.
- **Per-character text speed and pauses:** commas and ellipses insert real pauses (`…` = 600ms hold). Grief lives in the pauses.
- Implement as a small **JSON/`Resource`-driven sequence player**: a sequence is an array of steps `{speaker, text, choices?, sets_flag?, requires_flag?}`. One autoload `DialogueManager` reads it, emits `line_started/line_finished/choice_made`, and pauses player movement during blocking lines.
- **Accessibility:** text is skippable per-line but not the whole scene; a `dyslexia/large-text` toggle is a cheap win if time allows **[POLISH]**.

### 2.5 UI — the whole on-screen language **[MVP]**
The design rule is **near-zero UI**. The screen should look like a quiet film, not a game.

- **No HUD.** No health, no inventory bar, no minimap, no objective text — ever.
- **No main menu at boot.** The game opens on black (Section 5). The title appears ~90s in, earned. A real menu (Continue / New / Quit) only appears *after* the first session, or via Esc.
- **Pause menu (Esc):** dead simple — three centered words: *Resume · Settings · Quit*. Same soft serif. Dim the game behind it; do not stop the rain audio (it bleeds through, quieter).
- **Settings:** Master / Music / SFX sliders, text-speed, fullscreen, the large-text toggle. That's all.
- **Subtitles** are the only persistent text element and they live low-center.
- **Vignette + rain-on-glass** are rendered as full-screen shader overlays (Section 2.7), not UI nodes, so they sit *over* the world but *under* subtitles.
- **One inventory-ish exception:** the **photograph** the player pockets in Anger (Section 6.2). It is *not* shown as a UI item; it's a story object the character "has," surfaced only when they pull it out in Bargaining. Track it as a single boolean flag, not an inventory screen.

### 2.6 The grief/color-grade system **[MVP]**
A single global `grief_level` float (0.0 → 1.0, or a discrete 0–5 by stage) drives the whole game's mood:
- A `CanvasModulate` or post-process shader controls **saturation** and **warmth**: high grief = desaturated, cool, heavy vignette; resolving a stage nudges the house toward color and light.
- Drives **rain intensity** (opacity + audio bed), **footstep tone**, and **ambient volume**.
- The house has **two grades**: the *waking-house grade* (set by how many stages are resolved) and each *memory's own grade* (warmer, sepia-ish). Crossing the sleep threshold lerps between them.
- Resolving Stage N: lerp the house grade one notch warmer, set the resolved object's glow to a steady calm (not pulsing), and begin the next object's pulse.

### 2.7 The transition system ("drift to sleep / wake") **[MVP]**
This is reused at every stage boundary, so make it a single reusable scene `Transition.tscn` with two methods `close_eyes()` and `open_eyes()`:
- **close_eyes():** an iris/eyelid vignette closes (two soft horizontal bars meeting, or a radial mask shrinking). Simultaneously: audio low-pass sweeps down (`AudioEffectLowPassFilter` cutoff 20kHz → ~400Hz), rain fades to a dull hush, a slow breath + heartbeat rises, and the grade lerps toward the target memory's warmth.
- **open_eyes():** exact reverse. Un-mute, un-filter, breath fades, control returns.
- Both take a `target_grade` and a `duration` (~1.5–2.5s). The title card and "rule line" text can be drawn over the closed-eyes black.
- **The Bleed variant** (Anger/Bargaining): a *partial, involuntary* version — the vignette twitches closed and snaps back, color desaturates in a pulse, used when a memory intrudes without the player choosing sleep.

### 2.8 Audio architecture **[MVP]**
- Buses: **Master → {Music, SFX, Ambience}**, with the Low-Pass effect on a group bus so transitions can muffle everything at once.
- **Persistent rain bed** that never fully stops until the very end; its volume/brightness tracks `grief_level`.
- **Heartbeat/monitor motif:** the cold-open monitor tone is a recurring instrument — it returns, softened, at each death-adjacent beat and resolves to silence in Acceptance.
- **Stingers:** the dialogue-open note (Section 2.4), the soft denial tone (locked object), the glass-shatter (Anger), the insomnia drone (Depression).
- Keep everything **quiet and sparse.** Silence is a tool here; don't fill it.

---

## 3. Global flags & progression (implementation checklist)

Single autoload `GameState` holds:
```
grief_stage : int        # 0 intro, 1 denial … 5 acceptance, 6 ending
resolved : { denial:false, anger:false, bargaining:false, depression:false }
has_photo : bool         # picked up in Anger
house_grade : float      # 0..1 warmth, derived from resolved count
seen_title : bool
```
Stage gating is purely **emotional/flag-based** — no keys, no locked doors. An object's `is_locked` is just `not ready_for(this_stage)`. When a stage resolves, flip the next object's `glow` on and `is_locked` off.

---

## 4. Art & asset checklist (gamejam-minimal)
- **Tileset:** one apartment interior set (floor, walls with short front face, rug, doorways). Greyscale base so the grade system can recolor it. **[MVP]**
- **Props/interactables:** chair (sleep spot), window, **photograph/frame**, coat on a hook, **coffee mug**, record player, half-finished book, breakfast table + setting, water bottle + nightstand, bed. Each needs a "normal" and (for Denial) a "displaced" position. **[MVP]**
- **Characters:** player sprite (idle + walk, 4–8 directions or a simple 4-dir), **Eli** sprite (appears in memories; can be a soft, slightly translucent figure to read as memory). **[MVP for player; Eli MVP for Bargaining/Acceptance]**
- **Hospital vignette** for the cold open: can be near-black with only a monitor line + IV silhouette. Cheap. **[MVP]**
- **Shaders:** vignette, rain-on-glass, saturation/warmth grade. **[MVP]**
- If art time is short: **silhouette + warm/cool lighting** carries enormous emotional weight at near-zero cost. Lean on light, not detail.

---

## 5. THE INTRO — shot by shot (mostly as drafted, tightened)

> Design intent unchanged: teach everything by *feeling*. By Stage 1 the player understands move, interact, "most memories are sealed," and "one is open now." The ending is planted in the first ten seconds.

**Phase 0 — Cold Open (black) ~15s [MVP]**
- Pure black. Faint *"press any key"* before audio starts (so it isn't auto-playing into silence).
- On key: heart-rate monitor, slow and steady; faint rain under it.
- Hold the black a beat too long. Centered small text fades in: **"Stay with me."**
- It lingers. Monitor **flatlines** — one long tone. Text fades out. Tone stops. Only rain remains.
- *(Replay payoff: this is Eli's death and the player's unfinished line.)*

**Phase 1 — Wake in the house ~10s [MVP]**
- Slow fade from black into the house, top-down, **fully desaturated**, rain running down the screen edges.
- Camera rests on the player **asleep in the chair by the window** (not a bed — they fell asleep waiting). Hold on the sleeping figure. Rain only. No voice.

**Phase 2 — Control, taught silently ~30–60s [MVP]**
- Character stirs and stands. Control hands over with **no text, no prompt**.
- **One warm pull:** across the room, the **photograph glows** — the only warm thing in a grey house. Instinct walks the player toward it.
- On the way they pass dim memory-objects (coat, mug, record player, half-finished book). Each shows the soft proximity prompt. Pressing gives a single melancholy thought — teaching `interact` safely.

**Phase 3 — The soft constraint [MVP]**
- Every dim object returns its locked line, e.g.:
  - *"Their coat. Still smells like rain. …Not yet. I can't look at that one yet."*
  - *"Their mug. Half a ring of coffee, dried. I'm not ready."*
- One or two touches teach the whole gating grammar: most memories are sealed behind "I'm not ready"; the game will tell you when one opens. The warm object is the one you *can* face.

**Phase 4 — Falling asleep + Title [MVP]**
- Player reaches the **glowing photograph** and interacts. **The act of touching the memory is what makes them tired enough to sleep** — the object pulls them under (no backtracking to the chair).
- `Transition.close_eyes()` runs (Section 2.7): eyes close, audio muffles, rain hushes, grade bleeds toward the memory's warm grade.
- Over the closed-eyes dark, the title lands — **THE LAST MORNING** — first and only appearance, ~90s in, after emotional buy-in.
- As the title fades, one quiet rule line establishes the conceit: **"In the dream, it's that morning again."**

**Phase 5 — Into Stage 1 [MVP]**
- `open_eyes()` into the Stage 1 memory; the player "wakes" inside the dream. Control returns inside the level. Intro over.
- On completing any stage, the transition reverses — the player wakes back into the house, now a notch less grey, the resolved object calm and warm, the next object beginning to glow.

---

## 6. THE STAGES

Each stage below gives: **memory · entry · mechanic · the puzzle (truth) · key dialogue · SFX · exit · fragment gained.**

### 6.1 Stage 1 — DENIAL · "The Ordinary Morning" **[MVP]**
- **Memory:** a completely mundane breakfast with Eli — the last normal day.
- **Entry:** via the photograph sleep gateway (Section 5, Phase 4–5). Clean, contained dream — control still *feels* total.
- **Mechanic — the room won't let things be wrong.** Objects are subtly out of place: a tipped cup, a chair pushed out, a door ajar, a small spill. The instinct (and what the game *seems* to reward) is to tidy them. **Every fix silently undoes itself ~1s later**, and the exit stays sealed.
- **The puzzle (the truth):** **stop fixing.** Walk to the breakfast table and **sit down with everything still wrong.** The instant the player stops trying to restore "normal" and accepts the room as it is, the distortion releases and the exit opens.
  - *Implementation:* each displaced object has a `reset_timer` that snaps it back. The chair at the table is the one true interactable; sitting fires `resolve(denial)`. Optionally require the player to have *tried* to fix ≥2 objects first, so the lesson lands by contrast.
- **Key dialogue (inner voice):**
  - On fixing something: *"There. …That's better. That's how it should be."* → it slides back → *"…No. That's not—"*
  - On sitting: *"Maybe it doesn't have to be fixed. Maybe I just… sit here. With all of it. Like this."* (distortion releases)
- **SFX:** warm low note on entry; a tiny *wrong* dissonant tick each time a fix undoes itself; on sitting, the ticks resolve into a single held warm chord, rain softens.
- **Why it's denial:** denial is the compulsion to restore normal. The mechanic *is* that compulsion; beating it is relinquishing it. Perfect first lesson: **solutions here are acceptance, not control.**
- **Exit:** `close_eyes → open_eyes` back to the house; house warms one notch; photograph calm; **coat** begins to glow.
- **Fragment gained:** *the ordinary* — recognition that the last normal day mattered.

### 6.2 Stage 2 — ANGER · "Everything in the Way" **[MVP]** (promoted from inter-level)
- **Memory/Setting:** this one happens in the **waking house** — the first **Bleed**. Already agitated after the Denial dream, the player roams a house that has turned hostile.
- **Mechanic — ambient irritation + a breaking point.**
  - Instead of one big dialogue, **small, near-transparent floating words** drift around the character, attached to provoking things: *the rain that won't stop, the clock that's too loud, the chair pushed wrong again, the phone that won't ring, the casseroles people left.* They accumulate, overlapping, raising the noise.
  - Movement feels heavier; the grade pulses colder with each float.
  - **Trigger:** while moving, the player nudges some objects and **accidentally knocks a picture frame off a shelf — it shatters.** (Scripted on contact with a specific shelf, or on the 3rd object-bump.)
  - **The act:** the player picks up the photo from the broken glass. A surge — the player is prompted to **throw an object across the room** (one forced, cathartic interaction: press `interact` on any object, the character hurls it; glass/crash SFX, screen shake).
  - Then: **stillness.** The floats all fade at once. A long breath. The rain returns to normal volume.
- **The puzzle (truth):** anger isn't solved by a clever action — it's *spent*. The player must **let the outburst happen and then stop**, pick the photograph back up, and **pocket it** (`has_photo = true`). Pocketing the photo is the resolve action and the literal bridge to Bargaining.
- **Key dialogue (floating, then inner):**
  - Floats (auto-fade): *won't stop · too quiet · still here · their chair · why · not fair*
  - On the shatter: *"No—no no no—"*
  - After the throw, quiet: *"…I'm sorry. I'm not angry at you. I'm angry that you're gone."* → picks up photo → *"I'll keep this. I'm not done looking at it."* (pockets it)
- **SFX:** rising layered irritants (clock tick, rain swell, a phone that never rings) → **glass shatter** stinger + screen shake on the throw → sudden drop to near-silence + single breath.
- **Exit:** no sleep gateway here (it's a waking Bleed). Pocketing the photo warms the house one notch and **arms Bargaining** — the next time the player sits, they'll pull the photo out.
- **Fragment gained:** *the unfair* — permission to be angry without being angry *at* Eli.

> **Scope note:** Anger is short by design. The MVP version can skip the throw screen-shake polish but **must** keep: floats → shatter → pick up → pocket. That chain is the stage.

### 6.3 Stage 3 — BARGAINING · "If Only I'd Said" **[MVP]**
- **Entry:** after Anger, the player carries the photo. When they **sit down in a chair (or simply stand still and pull the photo out)**, interacting with the photo triggers a **Bleed flashback** — *not* a clean sleep, an intrusion. (Resolves the draft's open question: the photo-in-pocket from Anger is the trigger; sitting/looking pulls it out.)
- **Memory:** the **last ordinary conversation with Eli** — the small, stupid, unresolved argument from the last good morning (per the canon fix: not a lifelong estrangement, just the last words that landed wrong).
- **Mechanic — fix the conversation, multiple-choice.** The scene replays as branching dialogue. The player is offered kinder, wiser, more loving lines — *"What if I said this instead?"* They pick options trying to steer the morning to a warm goodbye.
  - **It is unwinnable by design.** Every branch, however kind, **collapses back to the same outcome** — Eli still leaves for the day, the morning still ends the way it did. The player can re-try branches; the system always routes to the fixed ending. Make the *near-misses* ache: one branch gets *so close* before reality reasserts.
  - *Implementation:* a branching tree where all leaves point to the same `bargain_fail` node. Track attempts; after 2–3, unlock the resolve line.
- **The puzzle (truth):** stop trying to rewrite it. The resolve is choosing the option **"I can't change this."** / **"It happened. I can't take it back."** — accepting authorship of the past instead of negotiating it. This pivots into the seed of Depression: *"…It was my fault. If I'd just—"* — but the *healthy* resolve is recognizing the past is fixed, not blaming the self. (Let the player feel the self-blame; the game gently shows it as a *stage*, not a verdict.)
- **Key dialogue:**
  - Prompt header (inner): *"If only we'd had a better morning. What if I said—"*
  - Choices (examples): *"I love you, be safe."* / *"Don't go yet — stay."* / *"Let's not fight, it's nothing."*
  - Every branch → Eli: *"…I'll see you tonight."* (the unchangeable line) → leaves.
  - Resolve option after attempts: *"I can't change this. I never could."* → the flashback releases.
- **SFX:** the dialogue-open note here is **colder, hesitant**; each failed branch ends on the soft monitor motif (one beat); the resolve lands on a low, exhausted exhale.
- **Exit:** Bleed reverses; house warms a notch; **leads directly into Depression** (the player is left drained — see entry of 6.4). Mug/record player resolve as calm.
- **Fragment gained:** *the unchangeable* — the past is fixed, and that is not the same as it being your fault.

### 6.4 Stage 4 — DEPRESSION · "The Long Night" **[MVP, trimmed]**
- **Entry:** drained from Bargaining, the player suddenly feels **heavy/tired** and goes to **bed** — but **can't fall asleep** (the Bleed has cost them the sleep gateway; they can no longer cross the threshold). This is the inversion: in Denial sleep was easy and a doorway; now it's denied.
- **Setting:** the bedroom at night. The screen **darkens, vignette heavies**, sound thins to an **insomnia drone** + clock + rain. Movement is at its slowest and heaviest.
- **Mechanic — the weight.** There is almost nothing to *do*, and that's the point — depression as the absence of momentum. Two beats:
  1. The player lies down; the "sleep" prompt appears but **interacting does nothing** (a few attempts; each returns a flatter inner line). Insomnia.
  2. They get up and **listen to Eli's voice recording** (the record player / phone) — a short, warm, ordinary message. It's meant to comfort but it makes the room **darker and quieter**, not lighter. Sadness deepens.
- **(Optional) the water beat [POLISH / handle with care]:** the character is thirsty, gets up, reaches for a water bottle on the nightstand. A **gentle hold-to-reach** interaction (hold `interact`, a small meter fills slowly) — the arm reaches, **falls short**, the character sinks down and **passes out** from exhaustion, drifting — finally — toward Acceptance.
  - **Caution:** keep this readable as *exhaustion/grief collapse*, **not** self-harm. No pills, no implication of intent. If it reads ambiguous in playtest, **cut it** and replace with: the player simply lies back down and *this time* sleep finally takes them (the recording fades, eyes close on their own). Either path leads to the Acceptance dream.
- **The puzzle (truth):** there is no clever solution and the game is honest about that. Depression "resolves" not by an action the player wins, but by **enduring it until the body finally rests.** The agency returns in Acceptance. The lesson: you don't fix this stage, you survive it.
- **Key dialogue (inner, sparse, flat):**
  - On failed sleep: *"…I can't."* / *"Just sleep. Please."* / *"…"*
  - On the recording — Eli's voice: *"Hey, it's me. Don't wait up, okay? …Love you."* → inner: *"Play it again."* → (room darkens) → *"…again."*
  - On collapse/finally sleeping: *"I'm so tired."* → eyes close (this time gently, not denied).
- **SFX:** insomnia drone (low sine + tape hiss), clock too loud, rain; Eli's recording is the only warm sound and it's *too* warm against the dark. On collapse, drone resolves into the breath/heartbeat of the sleep transition.
- **Exit:** `close_eyes()` — but this is the **one willing, peaceful sleep** the player has been unable to reach. It opens into Acceptance.
- **Fragment gained:** *the depth* — having gone all the way down and survived it.

### 6.5 Stage 5 — ACCEPTANCE · "The Last Morning" **[MVP — this is the missing finale]**
> Tone (locked by you): **quiet peace / letting go.** This stage pays off the cold open and returns the house to color.

- **Entry:** `open_eyes()` from Depression's true sleep into the warmest, fullest version of the memory yet. The grade is no longer sepia-faded — it's **soft morning light, full color**, rain easing.
- **Memory:** **that morning, one more time** — but now **nothing is out of place, nothing needs fixing, no line needs correcting.** Denial's distortion is gone. Bargaining's branches are gone. The kitchen is just the kitchen, warm and whole. **Eli is there** (or just-present — a soft figure at the table, by the window, light through them).
- **Mechanic — presence, not puzzle.** There is exactly **one thing to do, and it's gentle.** The player walks to Eli and **sits with them.** No fail state, no distortion, no timer. Just proximity. The whole game has trained "stop trying to control" — this is the reward for having learned it.
  - As the player crosses the room, the **previously sealed objects** (coat, mug, record, book) are each warm and at peace in the background — visual confirmation every stage is resolved.
- **The sealed line finishes.** When the player sits with Eli, the cold-open line returns — **and this time the player can complete it.** Present it as the game's final, only *meaningful* choice, where both options are "right" (no wrong ending), e.g.:
  - *"Stay with me."* → Eli, softly: *"…I can't. You know I can't."* → choice: **"I know."** / **"…Okay. You can go."**
  - Either choice resolves to the same peace: *"It's okay. I'm okay. …Thank you."*
- **The monitor motif returns — and resolves.** As Eli's figure gently fades into the morning light, the heart-monitor tone from the cold open rises one last time — but instead of flatlining as a shock, it **softens and dissolves into silence and birdsong/rain-easing.** The death is re-met, and this time it's allowed to be peaceful. *This* is the payoff of planting it in the first ten seconds.
- **The true wake.** `open_eyes()` — but now into the house **fully restored to color**, rain **stopped**, real morning light through the window. This is the **one true awakening** (every prior wake was into a still-grey house).
  - The player **rises from the chair** (the same chair from the very first shot). Optional last interaction: walk to each resolved object once — each gives a single line of peace, not pain. The photograph now reads: *"Their coat. Still smells like rain. …And that's alright. I can look now."*
  - The player walks to the **front door** — sealed all game — and it's now openable. They open it. **Cut to soft white / morning.** Title returns once: **THE LAST MORNING.** Credits over rain that has finally stopped.
- **Fragment gained / theme close:** *peace* — not forgetting, not "moving on," but carrying it and still opening the door.
- **SFX:** the warmest dialogue note of the game on entry; the monitor motif resolving to silence is the emotional climax — mix it carefully; final birdsong + a single held warm chord as the door opens.

---

## 7. The five fragments (optional connective tissue) **[CUT-OK]**
If you want a light collectible spine without HUD: each stage grants a **fragment** (the ordinary / the unfair / the unchangeable / the depth / peace). They're never shown as UI; they simply appear as **one warm word over the resolving object** at each wake, and all five are spoken together in the final door beat. Pure flavor — cut freely.

---

## 8. Dialogue master list (drop-in, edit to taste)
Keep every line short. Grief is laconic.

**Cold open:** "Stay with me."
**Locked objects (intro):**
- Coat: "Their coat. Still smells like rain. …Not yet. I can't look at that one yet."
- Mug: "Their mug. Half a ring of coffee, dried. I'm not ready."
- Record: "Our record. If I play it, I'll hear it in the kitchen. …Not yet."
- Book: "Page forty-one. They never finished it. …I can't."
**Title rule line:** "In the dream, it's that morning again."
**Denial:** "There. That's better." / "…No. That's not—" / "Maybe it doesn't have to be fixed. Maybe I just… sit here. With all of it."
**Anger floats:** won't stop · too quiet · still here · their chair · why · not fair
**Anger resolve:** "I'm not angry at you. I'm angry that you're gone." / "I'll keep this. I'm not done looking at it."
**Bargaining header:** "If only we'd had a better morning. What if I said—"
**Bargaining choices:** "I love you, be safe." / "Don't go yet — stay." / "Let's not fight."
**Bargaining fixed line (Eli):** "…I'll see you tonight."
**Bargaining resolve:** "I can't change this. I never could."
**Depression:** "Just sleep. Please." / Eli recording: "Hey, it's me. Don't wait up, okay? …Love you." / "Play it again." / "I'm so tired."
**Acceptance:** "Stay with me." / Eli: "…I can't. You know I can't." / "I know." / "It's okay. I'm okay. …Thank you."
**Final door:** "I can look now." (over the photograph) → door opens → THE LAST MORNING.

---

## 9. The realistic 20-hour build order (do it in THIS order)

Build **systems first, content second, polish last.** If you run out of time, you still have a playable, emotionally complete game because the MVP path is front-loaded.

**Hours 0–5 — Skeleton [MVP]**
1. Project setup, input map, one apartment scene, `CharacterBody2D` movement + camera smoothing.
2. `Interactable` Area2D + proximity prompt + one-button interact.
3. `DialogueManager` autoload (inner-voice subtitles + the dialogue-open note). Test with one object.

**Hours 5–9 — The shell that sells it [MVP]**
4. `Transition.tscn` (close/open eyes + low-pass + grade lerp).
5. Grief/grade system (saturation + warmth + rain bed).
6. Cold open + intro (Section 5) end-to-end, including the title card. **At hour ~9 you have a vertical slice: boot → cold open → walk → glowing photo → sleep → title.** This alone is demo-able.

**Hours 9–15 — Stages [MVP]**
7. **Denial** (displaced objects + reset timers + sit-to-resolve). The fullest mechanic — do it first.
8. **Acceptance** (presence + finish-the-line + monitor resolve + true wake). Do the *ending* second — never let the finale be the thing that got cut.
9. **Bargaining** (branch-all-roads-to-one tree).
10. **Anger** (floats → shatter → pocket photo).
11. **Depression** (insomnia + recording + finally-sleep; skip/decide the water beat).

**Hours 15–18 — Connective tissue [MVP→POLISH]**
12. Wire all five into one flow with the wake-back-to-house grade steps between them.
13. Audio pass: rain bed, the four stingers, monitor motif return.

**Hours 18–20 — Polish & ship [POLISH/CUT-OK]**
14. Screen shake on the throw, idle breathing, footstep tone shifts, large-text toggle.
15. Pause menu, settings sliders, export build, **playtest the whole run once start to finish** and cut anything that drags.

**If you're behind at hour 15:** ship **Intro → Denial → Acceptance** only. That three-beat arc (set up the loss, learn "stop controlling," finish the goodbye) is a complete, moving game on its own. Anger/Bargaining/Depression are enrichment, not load-bearing.

---

## 10. One-paragraph pitch (for the jam page)
*The Last Morning is a quiet top-down game about grief. You wake alone in a greying house where every memory of the person you lost is sealed behind "I'm not ready." One by one, the memories open — and each is a stage of grief you can't solve by force: a morning you keep trying to tidy until you learn to let it be broken, an argument you can't rewrite no matter what you say, a night you simply have to survive. Only when you stop trying to control the past can you finish the sentence you never got to say. Then the house returns to color, the rain stops, and you open the door.*
