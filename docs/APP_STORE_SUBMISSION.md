# Mac App Store Submission

This document tracks what is ready, what still needs Apple account access, and what should be reviewed before submitting Pokopia Builder to the Mac App Store.

## Current Readiness

- Native macOS SwiftUI app.
- Apple Silicon compatible.
- App icon is bundled as `PokopiaBuilder.icns`.
- Category is set to `public.app-category.games`.
- Bundle identifier is neutral: `dev.pokopia.builder`.
- Privacy manifest is bundled at `Sources/PokopiaBuilder/Resources/PrivacyInfo.xcprivacy`.
- App Store sandbox entitlements are drafted at `config/PokopiaBuilder-AppStore.entitlements`.

## Apple Account Requirements

You need:

- Active Apple Developer Program membership.
- App Store Connect access as Account Holder, Admin, App Manager, or Developer with upload permissions.
- A registered macOS bundle ID, preferably `dev.pokopia.builder` or a bundle ID owned by your developer team.
- Mac App Store distribution signing certificate and provisioning profile.
- App Store Connect app record for macOS.

## Important Technical Notes

The GitHub release DMG is for direct distribution only. The Mac App Store does not use that DMG. For App Store submission, create an App Store archive from Xcode and upload that archive/build to App Store Connect.

The app currently supports these network paths:

- `http://localhost:11434/api/generate` for optional local Ollama generation.
- `https://api.openai.com` for optional OpenAI generation when the user supplies an API key.

Because of that, the App Store entitlement file includes outgoing network access:

```text
com.apple.security.network.client
```

The app also has an external model override concept at:

```text
~/Documents/Pokopia Models
```

Under the Mac App Store sandbox, arbitrary access to that path will not be reliable without a user-selected folder flow and security-scoped bookmarks. The safest submission path is either:

- disable automatic external model loading for the App Store build, or
- add a user-facing "Choose Model Folder" button using `NSOpenPanel`, then store a security-scoped bookmark.

## Privacy

The included privacy manifest declares:

- no tracking
- no tracking domains
- no app-collected data types
- UserDefaults access for app-only settings storage

Before submission, review the App Store Connect privacy questionnaire carefully.

Suggested privacy answers for the current app:

- Tracking: No.
- Data used to track users: No.
- Diagnostics/analytics: No, unless you add analytics/crash reporting later.
- Contact info: No.
- Location: No.
- Purchases: No.
- User content: Review this carefully. If OpenAI mode remains in the App Store build, user prompts are sent to OpenAI only when the user chooses that provider and enters their API key. Apple may expect this to be disclosed as user content handled by a third-party service for app functionality.

If you want the cleanest privacy posture, ship the App Store build with Free Local mode only and keep OpenAI support in the GitHub/direct-download version.

## Legal / Review Risk

This is the largest submission risk.

Pokopia Builder is an unofficial fan/development tool. It references Pokemon Pokopia item names and uses Pokopia-related catalog data and imagery. Apple review may reject apps that appear to use third-party intellectual property without permission.

To reduce risk:

- Keep the app name as `Pokopia Builder` only if you are comfortable with IP review risk.
- Add clear unofficial-fan-tool language in the app description.
- Avoid official Nintendo, Pokemon, Game Freak, Creatures, or The Pokemon Company logos.
- Avoid official character art in the App Store screenshots if possible.
- Be ready to provide rights/permission information if Apple asks.

## App Store Product Page Draft

Name:

```text
Pokopia Builder
```

Subtitle:

```text
Build planner and idea generator
```

Promotional text:

```text
Plan cozy island builds, explore materials, and generate themed build ideas in a native macOS workspace.
```

Description:

```text
Pokopia Builder is a native macOS planning tool for creating build ideas, organizing materials, and experimenting with 3D layouts inspired by creature-collecting life-sim build projects.

Browse a local catalog of items, blocks, materials, recipes, and habitat ideas. Drag planned materials into a SceneKit build preview, generate themed layouts from prompts, and keep track of the pieces needed for your next project.

Features:
- Searchable item and material catalog
- 3D planning canvas with procedural block previews
- Drag-and-drop build planning
- Prompt-based build idea generation
- Optional local generation with Ollama
- Material quantity breakdowns
- Model override support for custom 3D assets

Pokopia Builder is an unofficial planning tool and is not affiliated with Nintendo, The Pokemon Company, Game Freak, or Creatures Inc.
```

Keywords:

```text
builder,planner,materials,crafting,blocks,3d,layout,ideas,cozy
```

Category:

```text
Games
```

Support URL:

```text
https://github.com/appleforever11/pokopia-builder/issues
```

Marketing URL:

```text
https://github.com/appleforever11/pokopia-builder
```

Copyright:

```text
Copyright 2026
```

## Submission Checklist

1. Decide whether the App Store build should include OpenAI mode.
2. Decide whether to keep the `Pokopia Builder` name for App Store review or use a less IP-sensitive name.
3. Add sandbox-safe folder picking for external 3D model folders, or disable external model lookup in App Store builds.
4. Create a real Xcode app project/scheme for archiving, or use an XcodeGen/Tuist setup.
5. Register the bundle ID in Certificates, Identifiers & Profiles.
6. Enable App Sandbox and outgoing network entitlement.
7. Create the app record in App Store Connect.
8. Archive with an App Store distribution signing identity.
9. Generate and review the privacy report in Xcode.
10. Upload the archive to App Store Connect.
11. Add screenshots, description, privacy answers, age rating, support URL, and review notes.
12. Submit first to TestFlight/internal testing.
13. Submit for App Review after testing.

## Reviewer Notes Draft

```text
Pokopia Builder is an unofficial build-planning and material organization tool. It does not include official game binaries or official 3D meshes. The 3D view uses procedural placeholder models and user-supplied model overrides.

Prompt generation can run locally through Ollama if available. OpenAI generation is optional and requires the user to supply their own API key.
```
