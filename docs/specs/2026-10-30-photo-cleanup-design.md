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
- `SwipeDeck`: the cards one swipe deck dealt when it opened, decided ones included, in display order.
  A sort only reorders them, so Undo can always bring a swiped card back.
- `MediaFilter` (all, photos, videos) and `AssetOrder` (oldest first, newest first, biggest first): the kind filter and the sorts a screen can offer.
  `AssetOrder` holds the one sort every screen uses.
- `FrozenOrder`: the item order Screenshots and Large videos fix when they open or the sort changes.
- `ProtectedSet`: a set of `AssetID`s, rebuilt from the library (Keep album ∪ Favorites ∪ switched-on albums).
- `LibrarySnapshot`: the assets, months and protected set, built off the main thread and swapped in at once after each library change.
- `TileToggles`: the fixed tile order of a Free up grid plus which tiles the user flipped, so taps never shift the grid.
- `ApplySection`: one section of the Apply grid, with its tile order (fixed until you pick a sort), the section's decision, and each tile's current decision, or none once taken back.
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
- Above the months, pick a kind: All, Photos or Videos (All by default).
  The list leaves out months that hold none of that kind, the month counts ("N of M") count only that kind, and Shuffle deals only that kind.
  When the library holds none of that kind, the list says so ("No videos in your library.") and Shuffle is off.
  A month whose items of that kind all have a decision shows as done.
  Home's "to review" count always covers every kind.
- The deck shows only undecided, unprotected assets of that month and kind.
  With Photos or Videos picked, the deck header says "Photos only" or "Videos only", and a finished deck says "Every video in this deck has a decision." for videos.
- Sort from the toolbar.
  A month deck offers newest first (the default), oldest first and biggest first; the shuffle deck offers shuffled (the default) and biggest first.
  Biggest first puts unknown sizes last, and equal sizes oldest first.
- A sort reorders the cards the deck dealt when it opened, decided ones included, so Undo still brings back a card swiped before the sort.
  Undo puts the card it brings back on top of the deck, whatever the sort.
  The order is set when the deck opens or when you pick a sort; sizes measured later never move a card.
- The kind and the month deck sort stay picked from deck to deck until the app quits; they are not saved.
  The shuffle deck always opens shuffled.
- Swipe right: keep. Swipe left: delete. Buttons do the same. Undo reverts the last swipe.
- Videos show a duration badge, and a tap opens any card full screen (see Preview).
- Each card shows date and size.
- Finishing a deck, or tapping Done, opens the apply screen.

### Free up space

- Pick a cutoff: older than 1, 3, 6 or 12 months, or a custom date.
- Pick a kind under the cutoff: All, Photos or Videos (All by default).
  The filter decides what gets deleted: with Videos picked, Delete queues only the shown videos and leaves every photo alone.
  Assets that are neither photo nor video show only under All.
- Candidates: every asset of the picked kind before the cutoff that is not protected; pending keeps show as kept tiles.
- Shows how many tiles will be deleted (candidates not kept), their total size ("up to"), and how many assets of the picked kind were skipped as protected.
- Sort from the toolbar: oldest first (the default) or biggest first.
  Biggest first puts unknown sizes last, and equal sizes oldest first.
  The order is fixed when the screen opens or when the cutoff, kind or sort changes; sizes measured later never move a tile.
- A grid of candidates that never reflows while you tap; tapping a tile marks it keep in place (saved as a pending keep at once), and tapping again clears it.
  Kept tiles stay kept when the cutoff, kind or sort changes.
  A tile whose photo your album add in the viewer protected leaves when the viewer closes.
- An empty grid names what is missing, for example "No videos before this date."
- Kind and sort reset to All and oldest first on every visit, as the cutoff does.
- "Delete N items" adds the shown tiles that are not kept to pending trash and opens the apply screen.
- Copy states that the app cannot see the user's backup, so the user confirms it is complete.

### Screenshots and large videos

- Screenshots: grid of screenshot assets that are not protected, all selected; tap to deselect.
- Large videos: grid of videos that are not protected, none selected; tap to select.
- Both offer a Select control that turns on drag-to-multi-select across tiles (same `DragMultiSelect` logic as Around this time), with edge auto-scroll while dragging.
- Sort from the toolbar: Screenshots offer newest first (the default) and biggest first; Large videos offer biggest first (the default) and newest first.
  The Large videos hint names the picked order.
- The order is set when the screen opens or when you pick a sort, so sizes measured later never move a tile.
  A decided or protected item leaves the grid, and a new one goes last.
- Both add the selection to pending trash and open the apply screen.

### Apply screen

- Lists pending keeps and pending deletes with sizes, in a grid fixed when the screen opens, so tiles never move while you tap.
  One exception: a tile leaves when the viewer closes after your own album add cleared its pending delete (see the albums and sharing spec).
- Sort from the toolbar: the order the decisions were made in (the default) or biggest first.
  Both sections sort together, and a sort only moves tiles: each keeps its decision, so taps, Take back all, Restore all and the counts work as before.
  There is no kind filter, so every item Apply deletes stays on screen.
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

- Unit tests (Swift Testing) on pure logic with the fake library: state transitions and undo, persistence round trip, free-up candidate selection and protected exclusion, month grouping and month counts under a kind filter, screenshot and video buckets, the shared sort and its tie rules, deck sorts with undo, Apply section sorts, apply ordering and the re-check of protection.
- UI test on the iOS 26.4 simulator, seeded with `xcrun simctl addmedia` and pre-granted photo access: swipe one left and one right, apply, accept the system delete alert, and check that the library shrank and the Keep album holds the kept asset.
- UI tests for the sorts: a month deck sorted biggest first shows its biggest card on top with the same card count, Undo after a sort brings the swiped card back on top, and the month list's Videos filter changes the month counts but not Home's count.
- Build, install and launch on the iPhone with the Personal Team.

## Deviations

- `xcrun simctl privacy grant photos` does not give full access on the iOS 26.4 simulator, so the UI test taps through the system permission prompt.
- The UI test target uses `nonisolated` default isolation, because `XCTestCase` does not compile with `MainActor` as the default.
- Undo moved out of `PendingDecisions` into a per-deck `DeckHistory` after review found a shared undo stack could re-queue a photo taken back on another screen.
- Free up and Apply tiles toggle in place after review found that removing a tile shifted the grid under the next tap.
- The Apply tap moved from taking a decision back to switching it to the other decision, after the user expected a tapped delete to move to Keep.
- Apply and Free up tiles are no longer fixed for the whole visit: the albums feature lets the viewer protect a photo, and its tile leaves when the viewer closes, so neither screen counts a photo whose pending delete the add cleared.
  A tile taken back before the add stays, and Restore all can queue it again; Apply skips it and reports it.
- Large videos no longer re-sorts while sizes are measured: like every other screen, it sets its order when it opens or when you pick a sort.
  A video whose size arrives later stays where it is, even if it is bigger than the videos above it; reopening the screen or picking another sort re-sorts the grid.

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
