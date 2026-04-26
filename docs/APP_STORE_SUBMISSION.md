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
- `PokopiaBuilder.xcodeproj` is generated from `project.yml` for Xcode archive/upload workflows.
- External model loading now uses a user-selected folder and a security-scoped bookmark.

## Apple Account Requirements

You need:

- Active Apple Developer Program membership.
- App Store Connect access as Account Holder, Admin, App Manager, or Developer with upload permissions.
- A registered macOS bundle ID, preferably `dev.pokopia.builder` or a bundle ID owned by your developer team.
- Mac App Store distribution signing certificate and provisioning profile.
- App Store Connect app record for macOS.
- `xcodegen` installed locally (`brew install xcodegen`) if regenerating the checked-in Xcode project.

## Important Technical Notes

The GitHub release DMG is for direct distribution only. The Mac App Store does not use that DMG. For App Store submission, create an App Store archive from Xcode and upload that archive/build to App Store Connect.

This repo now includes a generated Xcode project:

```text
PokopiaBuilder.xcodeproj
```

Regenerate it after changing `project.yml`:

```bash
xcodegen generate
```

Create an App Store archive/export:

```bash
DEVELOPMENT_TEAM=YOUR_TEAM_ID scripts/archive-app-store.sh
```

The script writes:

```text
build/AppStoreArchives/PokopiaBuilder.xcarchive
build/AppStoreExport/
```

Upload the latest archive to App Store Connect:

```bash
scripts/upload-app-store.sh
```

If signing fails, open Xcode, sign in to your Apple Developer account, register the bundle ID, and make sure an Apple Distribution or Mac App Distribution certificate is available.

## Current Submission Status

The App Store archive script was first tested with:

```bash
DEVELOPMENT_TEAM=SRGJ53HYRK scripts/archive-app-store.sh
```

That team did not have the required signing setup locally. The successful App Store archive/export used:

```bash
DEVELOPMENT_TEAM=6TYPWRK7SN scripts/archive-app-store.sh
```

Current local outputs:

```text
build/AppStoreArchives/PokopiaBuilder.xcarchive
build/AppStoreExport/Pokopia Builder.pkg
```

The archive is signed for team `6TYPWRK7SN`, uses bundle ID `dev.pokopia.builder`, and includes the sandbox, user-selected read-only file access, and outgoing network entitlements.

The upload helper currently reaches App Store Connect, but App Store Connect is still returning no app record for this bundle ID:

```text
IDEDistribution.DistributionAppRecordProviderError.missingApp(bundleId: "dev.pokopia.builder")
AppStoreConnectAppsResponse(data: [])
```

Next action in App Store Connect:

1. Open Xcode.
2. Go to **Xcode > Settings > Accounts**.
3. Confirm the signed-in account can access team `6TYPWRK7SN`.
4. Open App Store Connect > My Apps.
5. Create or verify a macOS app record with bundle ID `dev.pokopia.builder`.
6. Use SKU `pokopia-builder-macos` or another unique SKU.
7. Wait a minute for App Store Connect to refresh, then re-run:

```bash
scripts/upload-app-store.sh
```

If the app record was created with a different bundle ID, update `PRODUCT_BUNDLE_IDENTIFIER` in `project.yml`, regenerate the Xcode project, re-archive, and upload again.

The app currently supports these network paths:

- `http://localhost:11434/api/generate` for optional local Ollama generation.
- `https://api.openai.com` for optional OpenAI generation when the user supplies an API key.

Because of that, the App Store entitlement file includes outgoing network access:

```text
com.apple.security.network.client
```

The app supports external model overrides through a user-selected folder. This uses `NSOpenPanel` and a security-scoped bookmark instead of silently reading a fixed `~/Documents` path, which is safer for the Mac App Store sandbox.

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
3. Confirm sandbox-safe folder picking works in a signed App Store/TestFlight build.
4. Open or regenerate the real Xcode project with `xcodegen generate`.
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
