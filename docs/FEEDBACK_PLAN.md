# The Last Morning — Interactivity & Feedback Plan

A plan to make the game feel responsive so that **every input produces a noticeable
response** — visual, audio, or UI. Scope for this pass: **visual juice, audio, and
UI/menu feedback**. Haptics/controller rumble is owned by your dev and is only
referenced where it should hook into the same events.

This is a plan, not a code change. Nothing below has been applied yet.

---

## 1. The core principle

Right now the game leans almost entirely on **one feedback channel: captions**
(`Game.say` / `Game.flash`). There are ~100 caption calls across the scripts and
comparatively little else. That makes inputs feel like they "trigger text" rather than
"do something." The fix isn't more text — it's giving each input a fast, physical
response *before* (or instead of) a line appears: a sound, a small motion, a flash.

The golden rule to design against: **no input should ever feel swallowed.** If the
player presses a key and nothing visibly or audibly changes within ~80 ms, that input
failed, even if it "worked" logically.

---

## 2. What already works (keep it)

The project is further along than the README suggests. These are already good:

- **Movement** — code-driven 4-direction walk animation + looping `walksound.wav`
  (`player.gd`), with footsteps starting/stopping cleanly with motion.
- **Floating interact hint** — the bobbing `E`/`A` label that follows the nearest
  interactable and restyles per input device (`player.gd._make_hint`).
- **Device awareness** — `InputManager` already detects keyboard↔controller and emits
  `device_changed`, and most prompts already swap glyphs. This is a strong foundation.
- **Anger sequence** — already has a `_screen_shake()` and an SFX hit on the throw.
- **Cinematic title card** — already plays `Titlecard_hit_sound.mp3` on the slam-in.
- **Some ambience** — park ambience loops in Bargaining; the heartbeat/flatline plays in
  the cold open.

The job is to extend this coverage to *every* input, and to standardise it so it's
consistent and easy to maintain.

---

## 3. Audit — every input and its current feedback

Legend: 🟢 has good feedback · 🟡 partial / text-only · 🔴 silent or invisible

| Where | Input | Current response | Gap |
|---|---|---|---|
| All scenes | Move (WASD/stick) | Walk anim + footstep loop 🟢 | No footstep variation; no bump/wall feedback 🟡 |
| All scenes | Press E/A to interact | Action fires; floating hint stays static 🟡 | No press sound, no "button down" state, no object reaction 🔴 |
| House hub | Walk near active memory | Caption "Something here is awake" 🟡 | Glow doesn't react to proximity/press 🟡 |
| House hub | Interact a *locked* memory | Caption "I'm not ready" 🟡 | No soft "denied" sound/shake 🔴 |
| House hub | Interact ambient prop | Caption idle line 🟡 | No sound 🔴 |
| Cold open | Press E/B to begin | Sequence starts 🟡 | The press itself has no confirm sound/flash 🔴 |
| Denial | Straighten an object (it undoes) | Object resets 🟡 | No sound/motion on the "undo"; the core joke lands silently 🔴 |
| Denial | Sit at the table (the exit) | Transition 🟢 | Could use a settling sound + breath 🟡 |
| Bargaining (hub) | Press E to sit on couch | Sits, dialogue 🟢 | Press has no sound 🟡 |
| Bargaining (park) | Pick a dialogue choice | Dialogic default button 🟡 | No hover sound, no select sound, no emphasis 🔴 |
| Depression | Press E to play voicemail | Dialogue + room darkens 🟢 | Press has no sound; darkening has no audio cue 🟡 |
| Depression | Try to walk (pinned) | Caption "I can't" 🟡 | No tired sound/tiny shudder 🔴 |
| Depression | Reach the front door | Transition + dawn 🟢 | Door open has no creak/light sound 🟡 |
| Sympathy letters | Advance / read | Paper rustle 🟢 | Per-letter turn could be crisper 🟡 |
| Anger | Aim + throw | SFX + screen shake 🟢 | Good — template for the rest 🟢 |
| Acceptance | Presence beats | Captions 🟡 | Intentionally minimal — leave mostly as-is 🟢 |
| Any menu/UI | Hover / focus / click | None 🔴 | No UI sound layer exists at all 🔴 |

The pattern is clear: **the two most-used inputs in the game — "press E to interact"
and "pick a choice" — are exactly the two with the weakest feedback.** Fixing those two
will be felt everywhere.

---

## 4. The plan

### Phase 0 — Foundations (do these first; everything else plugs into them)

These are small, central pieces of plumbing. Without them you end up copy-pasting
`AudioStreamPlayer` setup into a dozen scripts (which is already starting to happen —
every sound currently hard-codes `bus = "Master"`).

1. **Audio bus layout.** Create a `default_bus_layout.tres` with `Master → Music`,
   `SFX`, `Ambience`. Route existing players to the right bus instead of `Master`. This
   gives you independent volume control and a place to duck music under dialogue later.

2. **A global `Sfx` autoload** (or extend `Game`). One function:
   `Sfx.play("ui_confirm")` with a small dictionary mapping names → streams, a pool of
   `AudioStreamPlayer`s so overlapping sounds don't cut each other off, and optional
   random pitch (±5%) so repeated sounds don't feel robotic. Every input handler then
   becomes a one-liner.

3. **A global screen-shake + hit-pause utility.** `anger_sequence.gd` already proves the
   pattern — lift `_screen_shake()` into a reusable `Game.shake(amount, duration)` that
   any scene's camera can call. Add an optional `Game.hit_pause(ms)` (very short
   `Engine.time_scale` dip) for impactful beats like the mug breaking.

4. **An interact-feedback helper on the player.** When `ui_accept` fires in
   `player.gd._unhandled_input`, before calling `target.interact()`:
   - play a UI/confirm sound,
   - pop the floating `E`/`A` hint to a "pressed" state (quick scale-down + brighten,
     then back), and
   - send a `pulse()` to the target object if it has one.

   This single change makes **every interaction in the game** feel responsive at once.

> Haptics hook (for your dev): Phase 0's `Sfx.play` and `Game.shake` calls are the exact
> spots to also fire controller rumble — same event, same call site.

### Phase 1 — Make the two core inputs feel great

This is the highest-leverage work and where most of the "wow, it feels alive now" comes
from.

**A. Universal interact feedback** (uses Phase 0 #2 and #4)
- Press E/A anywhere → soft confirm "tick" + hint button-press animation.
- Add an optional `pulse()` method to `memory_object.gd` and `interactable.gd`: a quick
  scale bump (1.0 → 1.08 → 1.0 over ~0.15 s) + brightness flash on the sprite/glow.
- **Locked memory** → a distinct, softer "denied" sound (lower, muffled) + a tiny
  horizontal shake of the object instead of a bump. The "I'm not ready" line stays, but
  now the *no* is felt before it's read.
- **Active memory** → on proximity, gently intensify the existing glow pulse; on press,
  a warm bloom as it accepts the touch.

**B. Dialogue choices (Bargaining)** — currently the weakest UI moment
- Add hover/focus sound on each Dialogic choice button.
- Add a select/confirm sound distinct from hover.
- Add visual emphasis: the focused choice scales slightly and warms in colour; unfocused
  choices dim. (Dialogic styles support hover state — wire it through the styled box you
  already build in `bargaining_controller._style_dialog_box`.)
- Because every path "ends the same," the *feel* of choosing is the whole mechanic —
  this is worth polishing more than anywhere else.

### Phase 2 — Wire up the unused/under-used audio per stage

You already have these assets sitting in `assets/Sound/` — most are not yet hooked up:

| Asset | Wire it to |
|---|---|
| `Cooking_sound_denial_BGM.mp3` | Denial kitchen BGM (loop on Music bus) |
| `Mug_Breaking.mp3` | Denial — the object that "won't stay fixed" resetting + a hit-pause |
| `Rain_Fl_studio.wav` | House hub + Depression rain bed (Ambience, fades with the grey) |
| `Oldies Playing In Another Room…mp3` | Depression — the voicemail/record player room tone |
| `Park ambience…mp3` | already in Bargaining park 🟢 |
| `Heartbeat flatline…mp3` | already in cold open 🟢 |
| `paper_rustle.mp3` | already in sympathy letters 🟢 |
| `walksound.wav` | already on player 🟢 |

Per-stage cues to add:
- **Denial** — each failed "fix" plays a small reset sound (mug clink / cloth); the room
  refusing to be fixed becomes audible, not just visual.
- **Depression** — each voicemail replay deepens the room tone as it darkens; the "I
  can't get up" attempts get a tired exhale.
- **House hub** — a low ambient rain/room tone that *warms and quietens* one notch each
  time a stage resolves (tie its volume/filter to `GameState.warmth()`), so progress is
  something you hear, not just see in the grade shader.
- **Door open (Depression→Acceptance)** — a creak + a swell of morning birdsong/light as
  the dawn blooms.

### Phase 3 — Ambient polish & accessibility

- **Footstep variety** — alternate 2–3 footstep samples (or pitch-randomise the one you
  have) and optionally change timbre on different "floors" if stages warrant it.
- **Caption pacing** — captions currently fade on timers. Consider a tiny "text appears"
  blip so even a pure-text beat has an onset sound.
- **An options surface** — once the bus layout exists, a minimal pause menu with
  Music/SFX/Ambience sliders. This is also the natural home for the haptics toggle your
  dev adds.
- **Consistency pass** — every prompt/sound should respect the `device_changed` glyph
  swap that already exists, so a player on a controller never sees an `E`.

---

## 5. Suggested order & effort

| Step | Item | Effort | Payoff |
|---|---|---|---|
| 1 | Audio buses + `Sfx` autoload | S | Unblocks everything |
| 2 | Global `Game.shake` / `hit_pause` | S | Reusable juice |
| 3 | Universal interact feedback (sound + hint press + `pulse()`) | M | **Felt in every scene** |
| 4 | Locked/active memory reactions | S | Hub feels alive |
| 5 | Bargaining choice hover/select feedback | M | Fixes weakest UI moment |
| 6 | Per-stage audio wiring (unused assets) | M | Each dream gets identity |
| 7 | Hub ambience tied to `warmth()` | S | Progress you can hear |
| 8 | Footsteps, caption blip, options menu | M | Final polish |

S = small (under ~30 min), M = medium (a focused session). Steps 1–4 alone would
transform how the game feels and are low-risk.

---

## 6. One concrete "before/after" to anchor it

**Locked memory today:** player walks up, presses E, a line of grey text fades in
("…Not yet. I can't look at that one yet."), nothing else moves. It reads as a dead end.

**After Phase 1:** the `E` hint pushes down like a real button with a soft click; the
memory object gives a small reluctant shake and a low, muffled tone; *then* the line
fades in. The refusal is now something the player **feels their own hand do** — which is
exactly the emotional point of that interaction.

That's the whole plan in miniature: same content, but the input lands.
