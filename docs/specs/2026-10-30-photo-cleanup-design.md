# Photo Cleanup: design

Status: approved (2026-10-30).

## Problem

Backup services such as Google Photos offer a "Free up space" button that deletes every backed-up photo from the phone, including the few special photos you want to keep on the device.
Going through the Photos app by hand to delete the rest is too slow.
Paid cleaner apps (for example "Cleanup: Clean Storage Space") solve part of this behind a subscription.

## Goal

An iOS app, built for one person's library first, that:

1. Lets you mark special photos as keepers, quickly, in a swipe deck that is fun to use in spare minutes.
2. Frees space by deleting everything else in a chosen date range, except the keepers.
3. Clears the obvious junk (screenshots, large videos) in a few taps.

No paywall, no account, no network.

## Users and surfaces

- One user on their own iPhone.
- Native SwiftUI app, iOS 18.0 deployment target, so it also runs on the iOS 18.6 simulator.
- Signed with a free Personal Team.
  Free provisioning expires after 7 days, so the user reinstalls from Xcode weekly.
  A paid Apple Developer account removes the expiry.

## Core idea: the protected set

The protected set is every asset the app must never offer for deletion:

- Assets in the **Keep** album (a normal Photos album the app creates or reuses by title).
- Favorites.
- Assets in any other user album that the user leaves switched on in Settings (all user albums are on by default).
- Hidden assets (the default fetch never returns them).

The Keep album lives in the Photos library, not in app storage.
So it survives an app reinstall, it syncs where Photos syncs, and the user can edit it in the Photos app.

## Data shapes

- `AssetID`: a wrapper around `PHAsset.localIdentifier`.
- `AssetInfo`: a value snapshot of one asset (id, media kind, screenshot flag, creation date, pixel size, duration, favorite flag).
  Pure logic and tests use `AssetInfo`, never `PHAsset`.
- `Decision`: `keep` or `trash`.
- `PendingDecisions`: an ordered map `AssetID -> Decision`.
  Persisted as JSON in Application Support (saved on a 0.5 s debounce and flushed when the app leaves the foreground), so closing the app never loses swipe work.
- `DeckHistory`: the undo history of one swipe deck, discarded when the deck closes.
  Undo only clears a decision that deck made, so it can never queue a delete.
- `ProtectedSet`: a set of `AssetID`s, rebuilt from the library (Keep album ∪ Favorites ∪ switched-on albums).
- `LibrarySnapshot`: the assets, months and protected set, built off the main thread and swapped in at once after each library change.
- `TileToggles`: the fixed tile order of a Free up grid plus which tiles the user flipped, so taps never shift the grid.
- `ApplySection`: one section of the Apply grid, with its fixed tile order, the section's decision, and each tile's current decision, or none once taken back.
- `PreviewChoice`: the optional status (text and tint) and the actions (title, tint, closure) that the preview shows for one asset, built by each screen from the state it already owns.
- `SizeCache`: `AssetID -> byte count`, persisted, filled in the background from `PHAssetResource` (`fileSize` key).
- `CleanupLog`: one entry per applied cleanup (date, items deleted, bytes).
- `PhotoLibrary`: a protocol over PhotoKit (fetch, thumbnails, add to album, delete).
  The app uses the PhotoKit implementation; tests use an in-memory fake.

An asset is in exactly one of these states:

| State | Where it lives |
|---|---|
| Undecided | Library only |
| Pending keep | `PendingDecisions` |
| Pending trash | `PendingDecisions` |
| Kept | Keep album |
| Deleted | Recently Deleted for 30 days, then gone |

## Features (v1)

### Home

- Library totals (photos, videos) and a size total once the size cache is filled.
- Entry tiles: Swipe review, Free up space, Screenshots, Large videos.
- Pending bar: "N to keep, M to delete (about X MB). Review and apply."
- Total space freed, from `CleanupLog`.

### Swipe review

- Pick a month (newest first, with counts) or "Shuffle".
- The deck shows only undecided, unprotected assets of that month.
- Swipe right: keep. Swipe left: delete. Buttons do the same. Undo reverts the last swipe.
- Videos show a duration badge, and a tap opens any card full screen (see Preview).
- Each card shows date and size.
- Finishing a deck, or tapping Done, opens the apply screen.

### Free up space

- Pick a cutoff: older than 1, 3, 6 or 12 months, or a custom date.
- Candidates: every asset before the cutoff that is not protected and not pending keep.
- Shows candidate count, total size ("up to"), and how many assets were skipped as protected.
- A grid of candidates that never reflows while you tap; tapping a tile marks it keep in place (saved as a pending keep at once), and tapping again clears it.
  A tile whose photo your album add in the viewer protected leaves when the viewer closes.
- "Delete N items" adds the candidates to pending trash and opens the apply screen.
- Copy states that the app cannot see the user's backup, so the user confirms it is complete.

### Screenshots and large videos

- Screenshots: grid of screenshot assets that are not protected, all selected; tap to deselect.
- Large videos: videos sorted by size, biggest first, none selected; tap to select.
- Both add the selection to pending trash and open the apply screen.

### Apply screen

- Lists pending keeps and pending deletes with sizes, in a grid fixed when the screen opens, so tiles never move while you tap.
  One exception: a tile leaves when the viewer closes after your own album add cleared its pending delete (see the albums and sharing spec).
- A tap switches a tile between keep and delete in place.
  A delete switched to keep shows a green "Keep" badge, and a keep switched to delete shows a red "Delete" badge.
- Each section has one button in its header.
  It reads "Take back all" while any tile in the section has a decision, and "Restore all" once none does.
- "Take back all" clears every decision in the section, and the tiles dim with a "Taken back" badge.
  Those photos stay on the phone and are not added to the Keep album.
- "Restore all" gives every tile its section's decision again, and a tap on one taken-back tile does the same for that tile.
- The section headers and the Apply button count by decision across the whole screen, so a switched tile counts under its new decision.
  The Delete header's "Up to" size covers exactly the photos that will be deleted.
- Every change writes through to the pending decisions right away, so leaving the screen keeps it.
- Apply runs in order: add pending keeps to the Keep album, then delete pending trash in one `deleteAssets` call.
- iOS always shows its own confirmation for the delete.
  If the user cancels it, the pending trash stays queued.
- After a delete, the app says plainly that the items sit in Recently Deleted for 30 days and still use space until the user empties it there.

### Preview

- Touch and hold any tile in Free up, Screenshots, Large videos or Apply to open it full screen.
  A tap keeps its current meaning.
- Tap any card in the swipe deck to open it full screen.
- Photos show at screen size.
  Videos play with the system controls, and only the item on screen plays.
- Swipe left or right to move through the same items, in grid order.
- A bar shows the date, size, video length and position, plus the item's decision on that screen and a button that flips it, the same as a tile tap.
  In the swipe deck the bar has Keep and Delete, which decide the card like a swipe and close the viewer.
- Closing the viewer scrolls the grid to the last item shown.

### Settings

- Protected albums: one switch per user album, all on by default. Keep album and Favorites are always on.
- One-time notice at first launch: if iCloud Photos is on, deleting here deletes from iCloud and other devices too.

## Permissions

- Request `.readWrite` photo access.
- Limited access shows a screen explaining that the app needs full access, with a button to Settings.

## Safety rules

- The app deletes only through `PHAssetChangeRequest.deleteAssets`, so iOS confirms every delete and items go to Recently Deleted.
- No protected asset ever reaches pending trash from a bulk mode.
- Before apply, the app drops any pending-trash asset that became protected since it was queued.
- Freed space is labelled "up to", because "Optimize iPhone Storage" keeps only small local copies of some originals.

## Verification

- Unit tests (Swift Testing) on pure logic with the fake library: state transitions and undo, persistence round trip, free-up candidate selection and protected exclusion, month grouping, screenshot and video buckets, apply ordering and the re-check of protection.
- UI test on the iOS 26.4 simulator, seeded with `xcrun simctl addmedia` and pre-granted photo access: swipe one left and one right, apply, accept the system delete alert, and check that the library shrank and the Keep album holds the kept asset.
- Build, install and launch on the iPhone with the Personal Team.

## Deviations

- `xcrun simctl privacy grant photos` does not give full access on the iOS 26.4 simulator, so the UI test taps through the system permission prompt.
- The UI test target uses `nonisolated` default isolation, because `XCTestCase` does not compile with `MainActor` as the default.
- Undo moved out of `PendingDecisions` into a per-deck `DeckHistory` after review found a shared undo stack could re-queue a photo taken back on another screen.
- Free up and Apply tiles toggle in place after review found that removing a tile shifted the grid under the next tap.
- The Apply tap moved from taking a decision back to switching it to the other decision, after the user expected a tapped delete to move to Keep.
- Apply and Free up tiles are no longer fixed for the whole visit: the albums feature lets the viewer protect a photo, and its tile leaves when the viewer closes, so neither screen counts a photo whose pending delete the add cleared.
  A tile taken back before the add stays, and Restore all can queue it again; Apply skips it and reports it.

## Not yet specified

- How "Shuffle" weights old versus recent assets.
- Whether the size cache should refresh when Photos edits an asset in place.
- Pinch to zoom on photos.

## Out of scope

- Similar and duplicate photo detection (phase 2, Vision feature prints over time-adjacent assets).
- Contacts, calendar and email cleanup.
- Emptying Recently Deleted (no public API).
- Reading backup status from a backup service (for example, the Google Photos API only exposes media the calling app created).
- App Store release, iPad layout, widgets.
- Live Photo playback.
