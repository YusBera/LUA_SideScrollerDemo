# The Dimensional Traveler — Starter Template

This starter template includes a basic LÖVE2D project structure that follows the assignment requirements from `midterm_project.md`.

## Included structure

- `main.lua` — initializes the game, virtual resolution, and state manager
- `conf.lua` — window configuration for Love2D
- `lib/push.lua` — minimal push-style screen scaler stub
- `lib/hump/gamestate.lua` — simple state manager implementation
- `states/` — game states: `Menu`, `Play`, `GameOver`, `HighScore`
- `objects/` — core game objects: `Player`, `Bullet`, `Enemy`, `Boss`
- `assets/sprites/` and `assets/sounds/` — placeholder directories for art and audio

## How to use

1. Open this folder in VS Code.
2. Add the real `push.lua` and `hump.gamestate.lua` libraries if you prefer to use the official versions.
3. Fill in assets under `assets/sprites` and `assets/sounds`.
4. Run with LÖVE.

## Notes

This template is intentionally minimal and focused on structure. It includes the key gameplay systems from the assignment:

- state-driven game flow
- player health and lives system
- crouching/hitbox management
- bullet lifecycle handling
- HUD and score persistence
- simplified boss phase logic
