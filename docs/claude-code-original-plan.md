# Build Settings Police — Implementation Plan

High-level plan for the tool described in `README.md`:
extract inline build settings from an Xcode project into hierarchical `.xcconfig` files, then police the project to keep them from coming back.

## Goals

1. **Extract** inline build settings from `.pbxproj` into hierarchical `.xcconfig` files.
2. **Police** the project so settings don't leak back inline.

## 1. Pick a language + parser

- **Option A — Ruby + `xcodeproj` gem** (CocoaPods' parser). Battle-tested, easy mutation, fastest to prototype. Distribution: gem or vendored script.
- **Option B — Swift + `tuist/XcodeProj`**. Native to the Apple ecosystem, statically typed. Distribution: SwiftPM binary.

**Recommendation:** start with Ruby for v1. Revisit if distribution or performance pushes us to Swift.

**Decide before writing code** — it shapes distribution, CI integration, and who can contribute.

## 2. Design the xcconfig hierarchy

Tiered layout, each file `#include`-ing its parent:

```
Project.xcconfig
  └── Project-Debug.xcconfig
  └── Project-Release.xcconfig
Target.xcconfig                    (per target)
  └── Target-Debug.xcconfig
  └── Target-Release.xcconfig
```

**Hoisting rule:** a setting lives at the highest tier where all descendants agree on its value; overrides drop down to the tier that diverges.

**On-disk layout:** e.g. `Configs/<Target>/<Target>.xcconfig` etc. — pick one convention and stick with it.

Preserve `$(inherited)` semantics so chained resolution keeps working.

## 3. `extract` command

- Walk every `XCBuildConfiguration` at project and target scope.
- Compute common vs. diverging settings per tier; write xcconfig files accordingly.
- Rewrite the project:
  - Point each `buildConfiguration` at the right `baseConfigurationReference`.
  - Clear the inline `buildSettings` dict.
- **Correctness check:** `xcodebuild -showBuildSettings` output must match before vs. after for every target/config pair. This is the regression gate.
- Idempotence: running `extract` a second time is a no-op.
- Provide `--dry-run` / diff mode.

## 4. `check` command (the "police")

- Re-parse the project; fail if any `XCBuildConfiguration.buildSettings` is non-empty.
- Optional whitelist for pragmatic exceptions (e.g. `PRODUCT_BUNDLE_IDENTIFIER`) via a config file.
- Non-zero exit + a clear diagnostic: target name, configuration, offending keys.
- Designed for CI and a pre-commit hook.

## 5. Safety & ergonomics

- Dry-run / diff mode for `extract`.
- Idempotent `extract`.
- Golden-file tests against a small fixture Xcode project kept in the repo.
- Clear README with a before/after example.

## Suggested milestones

1. Decide language + scaffold CLI (one command, `--help` works).
2. Fixture project + golden tests in place.
3. `check` command (simpler — read-only).
4. `extract` command — project-tier settings only.
5. `extract` — target-tier + per-configuration hoisting.
6. Round-trip verification via `xcodebuild -showBuildSettings`.
7. Docs + CI integration example.
