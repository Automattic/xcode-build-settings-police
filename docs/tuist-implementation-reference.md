# Tuist Implementation Reference

## Relevant Tuist Commands

Tuist ships two migration commands that overlap with this project:

```bash
tuist migration settings-to-xcconfig -p MyApp.xcodeproj -x Config/Project.xcconfig
tuist migration settings-to-xcconfig -p MyApp.xcodeproj -t TargetName -x Config/TargetName.xcconfig
tuist migration check-empty-settings -p MyApp.xcodeproj
tuist migration check-empty-settings -p MyApp.xcodeproj -t TargetName
```

These are useful references, but they do not implement the full behavior needed
for Build Settings Police.

## Source Files

Tuist source paths inspected:

- `cli/Sources/TuistMigration/Utilities/SettingsToXCConfigExtractor.swift`
- `cli/Sources/TuistMigration/Utilities/EmptyBuildSettingsChecker.swift`
- `cli/Sources/TuistKit/Commands/Migration/MigrationSettingsToXCConfigCommand.swift`
- `cli/Sources/TuistKit/Commands/Migration/MigrationCheckEmptyBuildSettingsCommand.swift`
- `cli/Sources/TuistKit/Services/Migration/MigrationSettingsToXCConfigService.swift`
- `cli/Sources/TuistKit/Services/Migration/MigrationCheckEmptyBuildSettingsService.swift`
- `Package.swift`

Primary repo:

- <https://github.com/tuist/tuist>

## Package Structure

Tuist has a `TuistMigration` SwiftPM target. It depends on Tuist-specific
modules plus `tuist/XcodeProj`.

The target is not exported as a standalone SwiftPM product in Tuist's
`Package.swift`, so another package cannot cleanly depend on it as
`.product(name: "TuistMigration", package: "tuist")`.

The useful implementation is small enough to reimplement directly instead of
vendoring Tuist internals.

## What `settings-to-xcconfig` Does

Tuist's extractor:

1. Checks that the `.xcodeproj` path exists.
2. Loads the project with `XcodeProj`.
3. Selects either:
   - project build configurations, or
   - one target's build configurations.
4. Reads each configuration's inline `buildSettings`.
5. Finds keys that exist in every configuration.
6. Treats keys with identical string values in every configuration as common.
7. Writes common settings as:

   ```xcconfig
   KEY=value
   ```

8. Writes divergent settings as:

   ```xcconfig
   KEY[config=Debug]=value
   ```

9. Flattens array values by joining elements with spaces.
10. Sorts output lines for stability.

## What `settings-to-xcconfig` Does Not Do

Tuist's extractor does not:

- read existing `.xcconfig` files
- resolve `baseConfigurationReference`
- preserve include chains
- generate a hierarchy of multiple `.xcconfig` files
- rewrite the `.pbxproj` to point at the generated file
- clear inline `buildSettings`
- add generated `.xcconfig` files to the Xcode project navigator
- compare effective settings before and after extraction

This means Tuist's command is closer to "dump inline settings into one file"
than a complete migration tool.

## What `check-empty-settings` Does

Tuist's checker:

1. Checks that the `.xcodeproj` path exists.
2. Loads the project with `XcodeProj`.
3. Selects project or target build configurations.
4. Fails if any selected `XCBuildConfiguration.buildSettings` dictionary is
   non-empty.
5. Logs each offending key and configuration name.

This behavior maps well to this project's `check` command, with two likely
improvements:

- check all targets by default
- report project, target, configuration, and key in structured output

## Important Limitation

Tuist does not know the effective values from existing `.xcconfig` files during
generation. Tuist maintainers have stated that reading `.xcconfig` files without
building is difficult and not currently supported by Tuist's generation logic.

For Build Settings Police, this means:

- `XcodeProj` can parse `buildSettings` and `baseConfigurationReference`
- existing `.xcconfig` files must be handled explicitly
- `xcodebuild -showBuildSettings` should be the source of truth for effective
  build settings

## What To Reuse Conceptually

Borrow these ideas:

- `XcodeProj` as the structured project parser/writer.
- A small extractor object separate from CLI wiring.
- A small checker object separate from CLI wiring.
- Stable sorted output.
- Common-vs-configuration-specific setting detection.
- Clear CI failure mode for non-empty inline settings.

Do not borrow these limitations:

- one flat `.xcconfig` output file
- no project rewrite
- no existing `.xcconfig` handling
- no effective-settings verification

## Recommended Adaptation

Build a Swift CLI with these internal components:

- `ProjectLoader`
- `BuildSettingsScanner`
- `InlineSettingsChecker`
- `XCConfigPlanBuilder`
- `XCConfigWriter`
- `PBXProjRewriter`
- `XcodebuildSettingsVerifier`

The Tuist implementation is a useful lower bound. Build Settings Police should
be stricter: hierarchical output, explicit project mutation, idempotence, and
verification via Xcode.
