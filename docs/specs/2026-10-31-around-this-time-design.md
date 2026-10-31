# Around this time: design

Status: waiting for approval.

## Problem

In the swipe deck you see one photo at a time.
To keep a set of related photos, for example every photo from a workout, you swipe each one and add each one to the album on its own.
You also cannot see what else you shot that day, so you cannot tell which nearby photos belong to the set.

## Goal

From the swipe deck, zoom out to a grid of every photo and video taken around the card's date.
Pick the ones that belong together, then add them all to an album in one step.
The same grid can also keep or delete the picked photos in one step.

## Where it shows up

- **Swipe deck**: a fifth round button, "Around this time" (`square.grid.2x2`), between Undo and Album.
  The five buttons fit on a 375 pt wide screen.
- **Swipe deck card**: pinching the card closed (fingers together, as in Photos) opens the same grid.
  The card also gets an "Around this time" accessibility action.
- The button is off for a card with no date, because the grid has no day to center on.

## The grid

- It shows every photo and video taken from 3 days before the card's day to 3 days after it, 7 calendar days in all, in the phone's time zone.
  The window crosses month and year ends, so a card from April 29 also shows May 1 and May 2.
- It shows every kind, whatever the deck's Photos or Videos filter is, because the point is context.
- It shows decided and protected items too.
  A pending keep or delete shows the Keep or Delete badge the app already uses, and a protected item shows a small lock.
- Items run oldest first, as in Photos, under one header per day ("Wed, Apr 29").
  Days with no items have no header.
- The title is the date range ("Apr 26 – May 2").
  The grid opens scrolled to the card's photo, which starts selected.
- A tap selects or deselects a tile.
  A selected tile shows a blue check mark; unselected tiles keep full brightness.
  Touch and hold opens the full-screen viewer over the grid's items, as on the other grids.
  The viewer offers Select or Deselect for the item, and its Album and Share buttons work as they do today.
- The bottom bar holds three buttons: "Delete N", "Keep N" and "Add N to album".
  - Add to album opens the album picker for every selected item.
  - Keep and Delete count only selected items that are not protected, and are off at 0.
    Keep queues pending keeps; Delete queues pending deletes.
    Nothing is deleted until you confirm on the Apply screen, as everywhere else.
    Both clear the selection.
  - An album add leaves the selection as it is, so you can add the same photos to a second album.
- The back button returns to the deck.

## Album picker with many items

- The picker takes a list of items; the deck and the viewer pass one, the grid passes the selection.
- A row shows a check mark when every item is in that album, and a dash when some are.
- A tap adds the items that are missing, or removes them all when every item is already in the album.
  With one item this is the picker's behavior today.
- New album creates the album and adds every item.
- Each write is one Photos change for all the items.
- The title reads "Add to album" for one item and "Add 4 to album" for many.

## Rules

- The existing album rule applies to every item: an add to a protected album clears that item's pending delete, and a pending keep stays.
  The batch clears them in one write to the pending decisions.
- Recent albums update once per batch.
- Back in the deck, cards that the grid decided or protected are gone.
  Cards you did not select stay, and so do cards added to an album you switched off in Settings.
- While the grid is open, a deck emptied by the grid's decisions does not jump to Apply.
  When you go back to it, the deck shows "All done here".
- Undo in the deck takes back only deck swipes, as today; it never takes back a grid decision.
  Apply's Take back does.

## Data shapes

- `NearbyDay` (new): a day's start date and its assets, oldest first.
- `Nearby.days(around:in:calendar:)` (new, pure): picks the assets of the 7-day window from `model.assets` and groups them by day.
  It reads the whole library, not the deck's month, which is what lets the window cross months.
  Undated assets are never in it.
- The grid keeps its selection as `Set<AssetID>` and rebuilds its days when `model.revision` changes.
  Tiles are never removed by a decision, so the grid needs no frozen order.
- `Route` gains `around(AssetID)`; the deck pushes it.
- `PhotoLibrary.add(_:toAlbum:)` and `remove(_:fromAlbum:)` take `[AssetID]` and replace the single-item versions.
  `PhotoKitLibrary` does one `performChanges` per call and checks the album holds all of them, or none of them, afterwards.
  The fake follows.
- `AppModel.add`, `remove` and `createAlbum(titled:adding:)` take `[AssetID]`.
  `AppModel` gains `queueKeep(_:)`, the keep twin of `queueTrash(_:)`, which skips protected items.
- `AlbumPicker` takes `[AssetID]`.
  Its row state (all, some, none) is a pure function of the items and the album's members.
- `AssetGridCell` gains a selection style: delete (red check, unselected tiles washed, as today) or pick (blue check, no wash), and a protected lock.

## Verification

- Unit tests with the fake library:
  - The window holds days −3 to +3, drops day −4 and +4, crosses a month end, leaves out undated assets, runs oldest first, and groups by day.
  - Batch add puts every item in the album in one library call, clears every pending delete in one write, and keeps pending keeps.
  - Batch remove, and the all, some and none row states.
  - `queueKeep` and `queueTrash` skip protected items.
- UI test on the simulator, after `scripts/seed-simulator.sh`, which puts two photos on the same day each month:
  open a month deck, open the grid with the button, check the card's tile is selected, select the other photo of that day, add both to a "UI Test" album, go back and check the deck lost 2 cards, then remove both again so the test leaves no photo in any album.
- UI test: pinching the top card closed opens the grid.
- Full `xcodebuild clean test` on the simulator, then install on the iPhone.

## Deviations

- The albums design (2026-10-30) put "selecting many photos in a grid to add or share at once" out of scope.
  This design brings back adding many at once, from this grid only; sharing many stays out.
- If pinching the card fights the swipe gesture in testing, the pinch is dropped and logged here; the button stays.

## Not yet specified

- Whether a 7-day window is the right width once Kan has used it on real days.

## Out of scope

- Opening the grid from the viewer, Free up space, Apply or the bulk screens.
- Selecting a whole day, or dragging across tiles to select many.
- Sharing many items at once.
- Detecting workouts or similar photos automatically.
- Changing the window width in the app.
