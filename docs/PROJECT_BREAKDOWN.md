# Project Breakdown

## App Structure

- `Sources/PokopiaBuilder/PokopiaBuilderApp.swift`
  - macOS app entry point.
- `Sources/PokopiaBuilder/ContentView.swift`
  - main SwiftUI layout, sidebar, item library, generator controls, build workspace.
- `Sources/PokopiaBuilder/BuildSceneView.swift`
  - SceneKit 3D build canvas and rendering fallback system.
- `Sources/PokopiaBuilder/Models.swift`
  - app state, build materials, prompt application, catalog filtering, placement logic.
- `Sources/PokopiaBuilder/PokopiaData.swift`
  - generated catalog loading and fallback data.
- `Sources/PokopiaBuilder/LocalBuildIdeaClient.swift`
  - free prompt generator using Ollama or local heuristic generation.
- `Sources/PokopiaBuilder/OpenAIBuildIdeaClient.swift`
  - optional OpenAI Responses API integration.
- `Sources/PokopiaBuilder/Resources/pokopia-catalog.json`
  - generated catalog.
- `Sources/PokopiaBuilder/Resources/PokopiaBuilder.icns`
  - app icon.

## Packaging

- `scripts/build-pokopia-builder-app.sh`
  - builds arm64 release binary
  - creates `.app` bundle
  - copies `Info.plist`
  - copies app icon
  - copies SwiftPM resource bundle
  - optionally copies local Pokopedia assets if installed
  - creates compressed DMG with Applications shortcut
  - applies `dist/assets/pokopia-dmg-background.png` as the drag-and-drop installer background
  - writes Finder layout metadata for the app icon and Applications shortcut

## Catalog Generation

- `scripts/pokopia/build-pokopia-catalog.js`
  - scans the local Pokopedia app bundle
  - merges public recipe/material metadata
  - writes `pokopia-catalog.json`

Generated counts:

- 948 item/material records
- 714 craftable recipes
- 43 recipe materials
- 213 habitats
- 313 sprites
- 31 specialties
- 11 abilities
- 10 CDs
- 6 locations
- 5 categories

## Current Rendering Strategy

Rendering priority:

1. Real local model file if available.
2. Procedural construction block profile.
3. PNG cutout fallback.
4. Generic SceneKit block fallback.

Real model search path:

```text
~/Documents/Pokopia Models
```

Bundled model search path:

```text
Sources/PokopiaBuilder/Resources/Models
```

## Known Gaps

- No official mesh assets are bundled.
- Many items still need proper shape profiles.
- PNG icons are not enough to reconstruct accurate 3D geometry.
- Prompt generation can create useful material sets, but layout quality depends heavily on model/shape coverage.
- Ollama integration depends on a local model being installed and running.
- OpenAI mode requires paid API credits.

## Best Next Tasks

1. Build a starter model pack for the top 50 blocks/items.
2. Add explicit `ShapeProfile` metadata per item.
3. Add UI controls for rotate/move/delete/duplicate in the 3D scene.
4. Add project save/load.
5. Add exportable build plans with screenshots and materials.
6. Improve prompt generator by requiring structured zones: terrain, shell, path, focal objects, lighting, decor.
