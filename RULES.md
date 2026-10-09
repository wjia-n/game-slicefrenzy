# Slice Frenzy — RULES.md

_Authoritative source of truth. If implementation conflicts with this document, fix the implementation._

## 1. Objective
Slice as much flying fruit as possible with swipe gestures. Avoid bombs. Score points per fruit; chain multi-fruit swipes for combo bonuses. Each mode ends differently — see §9.

## 2. Setup
- 1 player (renameable profile, persisted).
- Choose a mode: Classic / Zen / Blitz / Endless.
- Choose difficulty: Easy / Normal / Hard (Hard is Pro).
- 3-2-1 countdown, then fruit launches from the bottom of the screen.
- Customize: 12 market themes (4 need Pro), the custom theme creator (Pro),
  10 blade styles + custom blade creator (Pro).

## 3. Turn order
Single-player real-time. No turns.

## 4. Legal moves
- Swipe across one or more whole fruit: each fruit splits into two halves, +1 point each.
- One swipe slicing 3+ fruit at once scores a COMBO: bonus points equal to the combo size (n fruit → n bonus points), announced on screen.

## 5. Illegal moves
- There are no illegal swipes; swiping empty air does nothing.
- Sliced fruit cannot be sliced again; halves are not targets.

## 6. Captures
N/A — no capture mechanic.

## 7. Special rules
- **Bombs**: round black bombs with a lit fuse fly among the fruit.
  - Classic/Blitz: slicing a bomb = 1 strike. 3 strikes ends the run.
  - Zen: no bombs spawn.
  - Endless: slicing a bomb ends the run immediately.
- **Missed fruit** (fruit falling off the bottom unsliced):
  - Classic/Zen/Blitz: no penalty — the clock is the pressure.
  - Endless: costs 1 life (3 lives per run).
- **Combos**: only fruit sliced in a SINGLE swipe count toward the combo.

## 8. Scoring
- +1 per fruit sliced.
- Combo of n (n ≥ 3) in one swipe: +n bonus points.
- Best score is tracked per mode; beating it shows a NEW BEST badge.

## 9. Winning conditions
Arcade game — no win state. A run ends by:
- Classic/Blitz/Zen: the timer reaches zero.
- Classic/Blitz: 3rd bomb strike.
- Endless: bomb sliced, or lives reach zero.

## 10. Draw conditions
N/A.

## 11. AI strategy
N/A — no AI opponents.

## 12. Edge cases
- Pausing (pause button, app backgrounding) freezes physics, clock, countdown and spawning. Resuming continues exactly where it left off.
- A swipe that starts during the countdown does nothing until GO.
- Multiple bombs sliced in one swipe: each counts as a strike (Classic/Blitz); any bomb in Endless ends the run.
- Rapid successive swipes: each swipe is evaluated independently for combos.
- The engine must never get stuck: countdown always advances to GO; the timer always reaches zero; strikes/lives always resolve to game over. A watchdog restarts the engine tick if it ever dies mid-run.

## 13. Test cases
1. Start Classic → countdown 3-2-1 → GO, timer counts down from 60.
2. Swipe a fruit → splits, +1, juice splash, slice sound.
3. One swipe through 3 fruit → COMBO x3 announced, +3 bonus.
4. Slice a bomb in Classic → strike counter increments, red flash; 3rd strike → game over panel.
5. Let the timer expire → "Time's up!" panel with score and stats.
6. New high score → NEW BEST badge; best persists after restart.
7. Zen mode: 90 seconds, zero bombs.
8. Endless: drop 3 fruit → "Out of lives"; slice a bomb → instant game over.
9. Pause mid-run → resume continues with the same time/score/items.
10. Background the app mid-run → run is paused, not lost.
11. Custom theme creator: design a theme as Pro, restart the app — the
    custom colors are still the active theme; free users can't select it.
