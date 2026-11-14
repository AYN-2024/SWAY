# GONG (Godot port)

The whole web game, rebuilt in Godot 4.7, in the clay look.

## Open it
1. Run `Godot_v4.7.2-stable_win64.exe`.
2. Project Manager -> **Import** -> pick `project.godot` in this folder (if the old feel test is already listed, just open it).
3. Press **F5**.

## Controls
- Drag to fly, let go to coast. Double-click / double-tap or Space = Super (when green).
- WASD / arrows also fly. Esc or P = pause. R = restart.
- `1` = slow-mo at 0.1 speed. `F2` on the title = open every room and Endless (for testing).

## What is in
All ten rooms, every enemy kind, hearts, dust, Super, the gong, Endless, stars and perks,
saved progress, all screens. Plus one new test room, **The yard**: fences, rocks and
sleepers to smash. It has no waves and no gong.

## Same rules as the web build
`scripts/game.gd` is the live code (AYN-2024/SWAY, commit d6564a2) carried over function
by function, with the same numbers and the same random number generator. It was checked by
running the real web code and this port on the same scripted input, all ten rooms,
up to 3000 ticks each: positions agree to 0.0001 of a unit or better.

## What is new
- The look: clay pucks with engraved rings, cream ball, slate floor, soft shadows.
- A popped puck breaks into arcs that lie on the floor for about two seconds, then shrink away. Rocks, planks and the rung wall break too.
  The comet shoves loose pieces around; Super throws them. Pieces never affect the rules.

## Not in yet
- Sound (none at all).
- The enemy mouths (smug smile when you are slow) and the faint halo around enemies.

## Files
- `scripts/game.gd` rules, clock, input
- `scripts/view.gd` the 3D picture and the loose pieces
- `scripts/overlay.gd` sparks, words, hints, HUD
- `scripts/ui.gd` the screens
