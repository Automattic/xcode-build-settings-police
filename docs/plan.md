# Build Settings Police Implementation Plan

## Direction

Build this as a Swift CLI.

This is an Apple-only tool that operates on Xcode projects, so Swift is the
right default even if Ruby has mature project-file tooling. Use
`tuist/XcodeProj` for structured `.xcodeproj` parsing and writing, and use
`xcodebuild -showBuildSettings` as the authority for effective build-setting
verification.

## Reference Implementation

Tuist has similar migration commands:

- `tuist migration settings-to-xcconfig`
- `tuist migration check-empty-settings`

Use Tuist as a reference for the basic shape of the extractor and checker, but
do not treat it as complete for this tool. See
`tuist-implementation-reference.md` for details.

## Design Decisions

### Inheritance lives in xcconfig include chains only

An `XCBuildConfiguration` has only one `baseConfigurationReference` slot, so
multi-level inheritance has to live somewhere. We put it entirely inside the
xcconfig files:

- Each target-level `XCBuildConfiguration.baseConfigurationReference` points
  at the leaf xcconfig for that (target, configuration).
- That leaf `#include`s its parents up the chain.
- Project-level `XCBuildConfiguration` objects keep neither inline
  `buildSettings` nor a `baseConfigurationReference`; their contribution
  flows in through the target leaf's include chain.

Example chain:

```
pbxproj: target Debug -> Target-Debug.xcconfig
  Target-Debug.xcconfig
    #include "Target.xcconfig"
      #include "Project-Debug.xcconfig"
        #include "Project.xcconfig"
```

Include order is parent first, then local overrides:

```xcconfig
#include "Parent.xcconfig"

LOCAL_SETTING = value
```

That keeps override behavior visible in the file that owns the override.

**Rejected alternative:** attach *project* xcconfigs to the project's build
configs and *target* xcconfigs to the target's, letting Xcode's native
project-vs-target merge bridge the two layers. Valid, and arguably closer to
Xcode's mental model, but it splits inheritance across two places (pbxproj
attachments + xcconfig `#include`). Easy to double-include a file or skip a
level silently.

**Tradeoff we are accepting:** include chains are longer and every xcconfig
carries some boilerplate at the top. In exchange, one rule holds: reading any
tool-managed xcconfig gives the full tool-managed inheritance picture without
consulting the pbxproj. Xcode defaults, SDK/platform conditionals, environment
values, and build-action context still require `xcodebuild -showBuildSettings`.
That property is what makes this tool's future behaviour — detecting
duplication, handling existing xcconfigs, and explaining generated files —
tractable.

The extractor and `check --managed` command must both enforce this invariant:

- project-level `XCBuildConfiguration.baseConfigurationReference` is `nil`
- target-level `XCBuildConfiguration.baseConfigurationReference` is the
  per-(target, configuration) leaf xcconfig

A test must fail if either side of the invariant is violated.

### Other decisions

- CLI built on `swift-argument-parser`.
- `check` output: plain text + exit code by default; `--format json` for
  machine-readable output.
- Configuration file support is deferred. CLI flags only for v1; revisit
  once a real project needs selective rules.
- All target types (app, test, UI test, aggregate, legacy) treated equally.
- Generated xcconfig filenames derive from the target's name with
  non-standard characters replaced by `_`. If two targets normalize to the
  same filename, append a stable disambiguator and report it in dry-run output.

## Milestones

1. Create the Swift package
   - Add `Package.swift`.
   - Add a CLI executable target backed by `swift-argument-parser`.
   - Add test targets and fixture directories.
   - Add SwiftFormat/SwiftLint or other style configuration if selected.
   - Add repo instructions documenting build, test, and lint commands.

2. Add project parsing
   - Depend on `tuist/XcodeProj`.
   - Load `.xcodeproj` paths.
   - Traverse project and target `XCBuildConfiguration` objects.
   - Read inline `buildSettings`.
   - Read `baseConfigurationReference` paths, but do not assume they are
     resolved settings.

3. Implement `check`
   - Fail if project-level or target-level inline build settings are present.
   - Report target, configuration, and setting keys.
   - Plain-text output + non-zero exit status by default.
   - `--format json` emits machine-readable output for CI pipelines.
   - Check all targets by default.
   - **Release point:** after this milestone, the tool is usable standalone
     as a CI check even before `extract` lands.

4. Implement `check --managed`
   - Includes the default inline-settings checks.
   - Also fails if the generated-layout invariant is violated:
     - project-level `XCBuildConfiguration.baseConfigurationReference` is not
       `nil`
     - target-level `XCBuildConfiguration.baseConfigurationReference` is not
       the expected per-(target, configuration) leaf xcconfig
   - This mode is for projects already managed by Build Settings Police.

5. Implement `.xcconfig` serialization
   - Preserve Xcode-compatible syntax.
   - Handle scalar values and array values.
   - Preserve `$(inherited)`.
   - Quote values only when Xcode syntax requires it.
   - Emit stable sorted output to avoid noisy diffs.

6. Implement hierarchy planning
   - Model settings by scope:
     - project shared
     - project configuration-specific
     - target shared
     - target configuration-specific
   - Hoist settings to the highest level where descendants agree.
   - Keep lower-level files for real overrides only.

7. Decide existing `.xcconfig` handling
   - Detect existing `baseConfigurationReference` files.
   - Decide whether to include them, wrap them, or stop with a clear diagnostic.
   - Never silently discard existing `.xcconfig` behavior.
   - This decision must be made before the mutating `extract` command ships.

8. Implement `extract --dry-run`
   - Compute the generated `.xcconfig` file set.
   - Show planned file writes and project-file updates.
   - Show inline settings that would be removed.
   - Show filename normalization and collision disambiguation.
   - Do not mutate files.

9. Implement `extract`
   - Generate hierarchical `.xcconfig` files.
   - Add `#include` chains for inheritance.
   - Attach xcconfigs only at the target-level leaf (see Design Decisions);
     clear any `baseConfigurationReference` on project-level configs.
   - Remove migrated inline `buildSettings`.
   - Name generated files after the target, replacing non-standard
     characters with `_`, with stable disambiguation for collisions.
   - Add generated `.xcconfig` files to the project navigator if that proves
     useful for real projects.

10. Add verification
   - Capture `xcodebuild -showBuildSettings` before extraction.
   - Capture it again after extraction.
   - Compare effective settings per target and configuration.
   - Start with direct project builds:
     `xcodebuild -project App.xcodeproj -target Target -configuration Debug -showBuildSettings`.
   - Treat workspace and scheme support as follow-up unless needed by the first
     real fixture project.
   - Make this comparison the correctness gate.

11. Add tests
    - Minimal single-target project.
    - Multiple targets.
    - Debug and Release differences.
    - Existing `.xcconfig` references.
    - Shared settings that should be hoisted.
    - Values with spaces, quotes, lists, conditionals, and `$(inherited)`.
    - Filename normalization collisions.
    - Idempotence: running extraction twice should be a no-op.
    - Leaf-only invariant: assert project-level configs have no
      `baseConfigurationReference` and target-level configs point at the
      expected leaf file. This belongs to `check --managed` and protects the
      Design Decisions tradeoff from quiet regressions.

12. Document usage
    - Show `check` for CI.
    - Show `check --managed` for projects already migrated by this tool.
    - Show `extract --dry-run`.
    - Show full extraction workflow.
    - Document limitations around existing `.xcconfig` files and verification.

## Core Commands

```bash
build-settings-police check path/to/App.xcodeproj
build-settings-police check path/to/App.xcodeproj --managed
build-settings-police check path/to/App.xcodeproj --format json
build-settings-police extract path/to/App.xcodeproj --output Config
build-settings-police extract path/to/App.xcodeproj --output Config --dry-run
build-settings-police verify path/to/App.xcodeproj
```

## Non-Negotiables

- The tool must not rely on hand-written `.pbxproj` string editing.
- The tool must not claim semantic preservation without comparing
  `xcodebuild -showBuildSettings`.
- Existing `.xcconfig` references must be handled explicitly.
- Output must be stable and idempotent.
- `check` must be CI-friendly from the first usable version.
- Inheritance lives only in xcconfig `#include` chains. The pbxproj attaches
  an xcconfig only at the target-level leaf; project-level
  `XCBuildConfiguration` objects never carry a `baseConfigurationReference`
  after extraction. See Design Decisions for the rationale and the
  `check --managed` mode that enforces it.
