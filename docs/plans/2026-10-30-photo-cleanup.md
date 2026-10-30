# Photo Cleanup: build plan

Spec: `docs/specs/2026-10-30-photo-cleanup-design.md`.

One builder makes the app as one change, because every layer shares the same data shapes.
A fresh reviewer that did not write the code then checks the delete path and the protected set.

## Steps

Each step ends with its check and a commit.

1. **Scaffold.**
   `project.yml` (XcodeGen), app target `PhotoCleanup`, unit test target, UI test target.
   iOS 18.0, Swift 6, default actor isolation `MainActor`.
   `Config/Base.xcconfig` includes an optional, git-ignored `Config/Local.xcconfig` that sets `DEVELOPMENT_TEAM`.
   The generated `.xcodeproj` is git-ignored.
   `Info.plist` carries `NSPhotoLibraryUsageDescription` and `NSPhotoLibraryAddUsageDescription`.
   Check: `xcodegen generate` and a simulator build pass with zero warnings.
2. **Domain core.**
   `AssetID`, `AssetInfo`, `Decision`, `PendingDecisions` (with undo and JSON persistence), `ProtectedSet`, `CleanupLog`, the `PhotoLibrary` protocol and an in-memory fake.
   Pure functions for month grouping, free-up candidates, screenshot and large-video buckets, and apply planning.
   Check: unit tests pass.
3. **PhotoKit adapter.**
   Fetch, Keep album find-or-create, protected-album listing, thumbnails, video player items, file sizes, add to album, delete.
   Library change observer refreshes the snapshot.
   Check: build passes; the UI test in step 6 covers it end to end.
4. **Screens.**
   Permission gate, Home, Swipe review, Free up space, Screenshots, Large videos, Apply, Settings, first-launch iCloud notice.
   Check: build passes; manual run on the simulator with seeded media.
5. **Size cache.**
   Background fill with progress, persisted, used by Home, cards, free-up totals and large videos.
   Check: unit test for persistence; sizes show on the simulator.
6. **UI test.**
   Seed media with `xcrun simctl addmedia`, grant access with `xcrun simctl privacy <udid> grant photos <bundle id>`, run the swipe and apply flow, accept the springboard delete alert.
   Check: `xcodebuild test` passes on the iOS 26.4 simulator.
7. **Review.**
   Fresh reviewer reads the diff, focused on the delete path and the protected set.
   Fix confirmed findings.
8. **Device install.**
   Build with the Personal Team and install on the iPhone with `xcrun devicectl`.

## Not yet specified

- Shuffle weighting (see spec).

## Out of scope

- Similar and duplicate detection (phase 2).
