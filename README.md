# Build Settings Police

A small tool to extract builds settings from Xcode projects into hierarchical `xcconfig` files and police the project file to avoid inline build settings returning there.

## TODO

- [ ] **Comment on [tuist/XcodeProj#1078](https://github.com/tuist/XcodeProj/pull/1078)**
      with a focused note on the multiline behavior of
      `PBXFileSystemSynchronizedRootGroup` and the two related
      `*ExceptionSet` types.

      The current heuristic in `PBXFileSystemSynchronizedRootGroup.swift`
      is `multiline = (exceptions?.count ?? 0) < 2` (multi-line for 0–1
      exceptions, one-liner for 2+). PR #1078 removes the override
      entirely, falling back to `multiline: true` for all entries, which
      is the opposite of what Xcode 26 emits.

      **The comment must include a reproducible auto-setup so the PR
      author and maintainers can verify the Xcode-26 behavior without
      our environment.** Recommended shape:

      1. Public reference: `wordpress-mobile/woocommerce-ios @ trunk`
         (or whichever SHA is current at comment time). Its
         `WooCommerce/WooCommerce.xcodeproj` is a real Xcode 26 project
         using file-sync groups in production and is publicly
         accessible.
      2. Reproduction script: a self-contained shell snippet that
         (a) clones woocommerce-ios at a pinned SHA,
         (b) runs a tiny Swift program that opens the project via
         XcodeProj and calls `writePBXProj`,
         (c) `git diff`s the result,
         (d) opens the project in Xcode (manual, one-line instruction —
         cannot be automated) and adds a single empty Swift file under
         `WooCommerce/Classes/` to trigger Xcode's normalization,
         (e) `git diff`s again to show Xcode collapses everything to
         one-liner.
      3. Attached evidence: the two diffs side-by-side, demonstrating
         that XcodeProj produces multi-line where Xcode produces
         one-liner.
      4. Suggested fix: keep the override, change to `false`. (Or, if
         Xcode 16 and Xcode 26 disagree, document the version split.)

      A small standalone fixture project demonstrating the same
      behavior would be cleaner than depending on wcios — worth
      preparing one if the wcios reference proves controversial.
