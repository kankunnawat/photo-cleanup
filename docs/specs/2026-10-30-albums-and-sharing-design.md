# Albums and sharing: design

Status: approved with both recommendations (2026-10-30).

## Problem

The user wants some photos kept on the phone in named groups (for example "Pets"), not only in the Keep album.
Today the app can only keep a photo (Keep album) or delete it.
Putting a photo into another album means leaving the app for Photos, finding the photo again, and coming back.
While reviewing, the user also wants to send a photo to someone, which today also means leaving the app.

## Goal

1. Add the photo on screen to any album, or a new one, without leaving the app.
   Every album is protected by default, so the photo then drops out of Free up, Screenshots, Large videos and the swipe deck.
2. Share the photo or video on screen through the system share sheet.

## Where it shows up

- **Full-screen viewer**, on every screen that opens it.
  Two buttons sit in the top bar beside Close, "Album" (`rectangle.stack.badge.plus`) and "Share" (`square.and.arrow.up`).
- **Swipe deck**: a fourth round button, "Album", between Undo and Keep, acting on the top card.
  Sharing from the deck goes through the viewer (tap the card).

## Album picker

- A sheet with medium and large detents, opened by the Album button.
- Top row "New album": asks for a name, creates the album in Photos, and adds the photo.
- A search field, then "Recent" (the last 3 albums used from this app), then every user album by title.
- Each row shows the title, the item count, a check mark if the photo is already in that album, and "Not protected" if the album is switched off in Settings.
- A tap on a row adds the photo to that album, or removes it if it is already there.
  The check mark updates at once.
- The Keep album is not listed, because Keep has its own action everywhere.
- Done closes the sheet.
  In the swipe deck, closing the sheet after an add moves to the next card, because the photo is now protected.

## Rules

- Album changes go to Photos at once.
  There is no Apply step, because adding to or removing from an album never deletes a photo.
- Adding a photo to a protected album clears a pending delete for that photo, so the Apply screen never counts a photo that Apply would skip.
  A pending keep stays.
- Removing a photo from an album never queues it for deletion.
- In the viewer, a protected photo shows "Protected" and no Keep, Delete or Restore button, whichever screen opened the viewer.
  So after an add from the viewer, no tap there can queue the photo again.
  Taking the photo out of the album brings the buttons back.
- Apply and Free up space keep their tiles still while you tap, so they catch up once, when the viewer closes:
  - Apply drops each tile whose decision no longer matches the pending decisions.
    That is a tile whose pending delete an album add cleared.
    It also leaves "Take back all" and "Restore all", so neither can queue it again.
  - Free up space drops each tile that is now protected and adds it to "protected, skipped".
    The other tiles, and the ones you tapped to keep, stay as they were, so the Delete count matches what it queues.
- Album writes use `PHAssetCollectionChangeRequest` (create, add, remove).
  iOS shows no prompt for these.
- Shared and smart albums are not listed (PhotoKit cannot add to them).

## Sharing

- Share first exports the file, then opens the system share sheet with it.
  A photo with edits goes as its edited version, and a photo without edits goes as its original (HEIC or JPEG).
  A video goes as a movie file, edited if it has edits.
  A Live Photo shares as its still image.
- While the file exports (for example, while an original downloads from iCloud), the Share button shows a spinner and reads "Cancel".
  A tap on it cancels the export and the download.
- Exported files live in the app's temporary folder.
  They are removed after the share sheet closes, and the app clears that folder at launch.

## Data shapes

- `AlbumInfo` (exists): id, title, member IDs.
- `PhotoLibrary` gains `createAlbum(title:)`, `add(_:toAlbum:)`, `remove(_:fromAlbum:)` and `exportOriginal(for:)`, implemented in `PhotoKitLibrary` and in the test fake.
- `AppModel` gains the album writes and a small persisted list of recent album IDs.
  The picker reads each album's member IDs for its check mark.
- After each album write, `AppModel` updates its albums and protected set at once, and the library change observer refreshes them again later.
  The deck, Screenshots and Large videos read live lists, so they update from that.
  Apply and Free up space freeze their tiles, so they reconcile when the viewer closes (see Rules).
  `ApplySection` gains `dropTiles(disagreeingWith:)` for this.

## Verification

- Unit tests with the fake library: add, remove, create; a pending delete cleared on add to a protected album; a pending keep kept; recents order and cap.
- UI test on the iOS 26.4 simulator: from the swipe deck, add the top card to a new album, check the card leaves the deck and Home's Protected count grows by one, then remove it again from the viewer's picker.
- Manual on the simulator: share a photo to Files or Save to Files, screenshot the share sheet.
- Install on an iPhone.

## Deviations

- Sharing exports the file before the share sheet opens, instead of a share sheet that loads the file lazily.
  With the file in hand, the app knows when to delete it, and the Share button can cancel an iCloud download.
- The UI test opens the viewer from Free up space and adds and removes a photo in a "UI Test" album, so it leaves no photo in any album.
  A second UI test checks that the deck's Album button opens and closes the picker.
  Adding the top card from the deck, and Home's Protected count, were checked by hand on the simulator.
- The viewer's "Protected" state, and the reconcile in Apply and Free up space when the viewer closes, were not in the approved design.
  Review found that after an add from the viewer, Apply and Free up space still counted the photo, and a Delete, Keep or Restore tap could queue it again.
  Apply then skipped it, so nothing was deleted, but the counts were wrong.
- `AppModel` has no "albums holding an asset" lookup; the picker checks each album's member IDs.
- The design said the change observer updates Free up space without new plumbing.
  That was wrong, because Free up space freezes its tiles; it now drops protected tiles when the viewer closes.
- The UI test also checks that the viewer shows "Protected" with no Keep or Delete after the add, and that the buttons come back after the photo leaves the album.

## Not yet specified

- Whether the Recent list should also learn from albums used in Photos.

## Out of scope

- Browsing an album's photos in the app (Photos does this).
- Selecting many photos in a grid to add or share at once.
- Renaming, deleting or nesting albums.
- Sharing Live Photos as live.
