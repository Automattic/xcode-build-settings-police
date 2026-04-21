# Build Settings Police Implementation Plan

## Goal

Build a small CLI tool that extracts inline Xcode build settings from
`project.pbxproj` files into hierarchical `.xcconfig` files, then provides a
CI-friendly check that prevents inline build settings from returning.

## Plan

1. Create the project skeleton
   - Choose the implementation language and package layout.
   - Add CLI entry point, tests, fixtures, and lint/style configuration.
   - Document local build and test commands in repo instructions.

2. Parse Xcode project files
   - Read `project.pbxproj` using a structured parser where possible.
   - Locate `XCBuildConfiguration` objects.
   - Extract project-level and target-level build settings for each
     configuration, such as `Debug` and `Release`.

3. Model the build-setting hierarchy
   - Represent settings by scope:
     - project shared settings
     - project configuration settings
     - target shared settings
     - target configuration settings
   - Detect common settings that can be lifted upward.
   - Preserve only the overrides that differ at lower levels.

4. Generate `.xcconfig` files
   - Produce a predictable hierarchy, for example:
     - `Config/Project.xcconfig`
     - `Config/Project-Debug.xcconfig`
     - `Config/Project-Release.xcconfig`
     - `Config/Targets/App.xcconfig`
     - `Config/Targets/App-Debug.xcconfig`
   - Use `#include` chains to express inheritance.
   - Serialize values without changing Xcode semantics.

5. Rewrite project references
   - Remove inline `buildSettings` entries from the `.pbxproj`.
   - Set each `XCBuildConfiguration` object's `baseConfigurationReference`.
   - Add generated `.xcconfig` files to the project structure if needed.

6. Add policing mode
   - Provide a command that fails when inline build settings are present.
   - Make output clear enough for CI logs.
   - Return a non-zero exit status on violations.
   - Consider an allowlist only if real projects require exceptions.

7. Add CLI commands
   - `extract`: generate `.xcconfig` files and update the project.
   - `check`: fail if inline build settings are found.
   - `dry-run`: show planned changes without writing files.
   - Optional `verify`: compare effective settings before and after extraction.

8. Test with fixtures
   - Minimal single-target project.
   - Multiple targets.
   - Debug and Release differences.
   - Existing `.xcconfig` references.
   - Shared settings that should be lifted.
   - Values containing spaces, quotes, lists, and `$(inherited)`.

9. Verify behavior
   - Run unit tests.
   - Run the CLI against fixture projects.
   - Where possible, compare `xcodebuild -showBuildSettings` output before and
     after extraction to confirm effective settings are preserved.

## Main Risks

- Rewriting `.pbxproj` files without corrupting object references.
- Serializing `.xcconfig` values while preserving Xcode behavior.
- Correctly handling existing `.xcconfig` files and include chains.
- Avoiding noisy diffs from unstable ordering or formatting.
