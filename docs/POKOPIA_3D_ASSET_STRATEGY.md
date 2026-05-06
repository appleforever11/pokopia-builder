# Pokopia Builder 3D Asset Strategy

This project has two distribution tracks:

- **App Store build:** review-safe, local prompt generation by default, no API key requirement, and no experimental model-folder UI.
- **GitHub/personal build:** enables experimental model-folder tooling, OpenAI prompt generation, and user-provided or generated 3D assets.

Do not ship experimental model-generation features to App Store Connect unless they have been reviewed separately.

## Reality Check

The available Pokopia item images are useful references, but they are not enough to reconstruct accurate 3D models for every item. A single catalog icon usually lacks back, side, underside, dimensions, occluded geometry, and material maps. For exact assets, the project needs one of these:

- official or community-made 3D models with redistribution permission
- multiple reference angles per item
- hand-authored models
- user-provided local model files

Until then, the best result is a hybrid pipeline.

## Current GitHub Build Pipeline

The GitHub build searches for local models in the selected model folder and, by default, in:

```text
~/Documents/Pokopia Models
```

Supported extensions:

```text
.usdz
.scn
.dae
.obj
```

Use slugged model names:

```text
red-rock.scn
aged-stone-wall.usdz
arrow-sign.obj
crystal-wall.dae
```

The app also exposes a model-folder picker in the GitHub/personal build. That picker is hidden from the default App Store-safe build.

## Procedural Placeholder Generation

For blocks, walls, floors, signs, fences, lamps, stairs, ore, and crystal-style items, generate clean procedural `.scn` placeholders:

```bash
scripts/pokopia/generate-procedural-models.js "$HOME/Documents/Pokopia Models"
```

For a quick test:

```bash
scripts/pokopia/generate-procedural-models.js /tmp/pokopia-model-test --limit=5
```

This does not create perfect game-accurate models. It creates stable, clean, correctly oriented 3D geometry so the planning scene behaves like a real build editor instead of showing distorted icon billboards.

## AI Model Generation Options

For future replacement assets, use image-to-3D tools outside the app, then export `.usdz`, `.scn`, `.dae`, or `.obj` into the model folder. Good candidates to test:

- TripoSR for fast single-image mesh drafts.
- Stable Fast 3D for single-image 3D asset generation.
- Wonder3D-style pipelines when more GPU time is available.
- Blender for cleanup, decimation, retopology, scale normalization, and material fixes.

The expected workflow is:

1. Generate a draft mesh from the item image.
2. Clean it in Blender.
3. Normalize origin, scale, and orientation.
4. Export to `.usdz`, `.dae`, `.obj`, or `.scn`.
5. Name it with the item slug.
6. Drop it into the selected Pokopia model folder.

## Build Commands

Default App Store-safe build:

```bash
swift build -c release --arch arm64 --product PokopiaBuilder
```

GitHub/personal build with experimental model tooling:

```bash
scripts/build-pokopia-builder-github.sh
```

The GitHub build compiles with:

```bash
-Xswiftc -DPOKOPIA_GITHUB
```

This keeps model-folder tools and OpenAI prompt controls out of the default build unless explicitly requested.
