# Pokopia 3D Model Pipeline

Pokopia Builder now looks for real model files before using procedural fallbacks.

## Where To Put Models

Use **Choose Model Folder** in the app and select the folder that contains your item models. This keeps local model loading compatible with the macOS App Sandbox.

Supported extensions:

- `.usdz`
- `.scn`
- `.dae`
- `.obj`

Name the file with the item's slug. Examples:

- `coarse-rock.scn`
- `red-rock.scn`
- `crystal-wall.usdz`
- `pokemon-center-wall-lower.obj`
- `cube-light.usdz`

The app automatically matches by item name.

## Procedural Starter Models

Generate a simple SceneKit model:

```bash
scripts/pokopia/make-procedural-model.swift coarse-rock cube B8CBC5
scripts/pokopia/make-procedural-model.swift red-rock cube 9B503B
scripts/pokopia/make-procedural-model.swift crystal-wall crystal 74D8FF
```

Shapes currently supported:

- `cube`
- `floor`
- `wall`
- `crystal`
- `cylinder`
- `lamp`

## What Helps Most

For each important item, provide one of:

- a `.usdz`, `.scn`, `.dae`, or `.obj` model
- 2-3 in-game screenshots from different angles
- a note describing the correct shape profile, such as `cube`, `wall`, `floor`, `crystal`, `lamp`, `table`, or `chair`

Start with 20-50 high-value blocks and furniture items instead of all 948 at once.
