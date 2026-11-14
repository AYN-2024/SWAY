# GONG

Pop them all. Gong the wall.

A one-thumb arcade game. You are a comet shut in ten rooms, one inside the next. Add `?all` to the link to open every room, and `?slow=0.1` to watch it at a tenth of the speed.
Clear a room, hit its wall at full speed, and it rings like a gong and lets you out.
If you stop, you die.

**Play:** https://ayn-2024.github.io/SWAY/

## How to play

- Drag to fly. On a phone the comet aims above your thumb, never under it.
- Let go to coast.
- Only a glowing comet (rainbow tail) pops things. Touch an enemy without glowing and it throws you back. Walls just bounce you.
- Getting pinned between two bodies, or a body and a wall, costs a heart. Three hearts per room.
- Dust fills the ring around you. When you turn green, double-tap for Super.
- Three stars per room: get out, lose no heart, keep a chain of 75% of the room.

## Endless

Ring all ten rooms and Endless opens. Same rule, crowds made on the spot, harder every wall.
Hearts, dust and your chain carry through each wall. The score is walls rung in one run.

Stars buy perks that only work in Endless: 10 stars start you with Super ready, 20 give a fourth heart,
30 bring dust from twice as far.

Keyboard: arrows or WASD to fly, Space for Super, P to pause, R to restart the room.
Add `?all` to the address to open every room and Endless.

## Files

- `index.html`: page, menus, styles
- `js/core.js`: palette, movement numbers, shared state
- `js/audio.js`: all sound, synthesised in the browser
- `js/fx.js`: particles and dust
- `js/player.js`: the comet
- `js/enemies.js`: enemy types and rules
- `js/rooms.js`: the ten rooms (edit `ROOMS` to rebalance) and Endless (edit `ENDLESS`)
- `js/render.js`: drawing
- `js/ui.js`: screens, input, the loop

No build step and no dependencies. Open `index.html`.

The movement numbers are carried over from the v07-1l and Onboarding F builds.
