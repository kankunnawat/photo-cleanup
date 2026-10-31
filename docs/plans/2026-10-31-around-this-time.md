# Around this time: build plan

Spec: `docs/specs/2026-10-31-around-this-time-design.md`.

One builder makes it in its own worktree, because the batch album write runs through the library, the model, the picker and the new grid.
A fresh reviewer then checks the album writes, the pending decision rules and the deck's behavior around the grid.

## Steps

1. **Batch album writes.**
   `add` and `remove` take `[AssetID]` in `PhotoLibrary`, `PhotoKitLibrary`, the fake and `AppModel`; `createAlbum(titled:adding:)` takes `[AssetID]`.
   The single-item versions go, and the deck and viewer pass one item.
   Check: `AlbumTests` updated and passing, plus new batch tests.
2. **Keep twin.**
   `AppModel.queueKeep(_:)` skips protected items, like `queueTrash(_:)`.
   Check: unit test for both.
3. **Picker with many items.**
   `AlbumPicker` takes `[AssetID]`; rows show all, some or none; a tap adds the missing items or removes them all.
   Check: unit test for the row state; the existing album UI tests still pass.
4. **The window.**
   `NearbyDay` and `Nearby.days(around:in:calendar:)`.
   Check: unit tests for the window edges, the month end, undated assets, order and grouping.
5. **The grid screen.**
   `Route.around(AssetID)`, the grid with day headers, selection, badges and lock, the viewer, and the bottom bar.
   `AssetGridCell` gains the pick selection style and the lock.
   Check: build passes; screenshots of the grid in light and dark.
6. **Deck entry points.**
   The fifth round button, the pinch on the card, the accessibility action, and the guard that keeps the deck from jumping to Apply while the grid is open.
   Check: build passes; screenshot of the deck on a 375 pt wide simulator.
7. **UI tests and full run.**
   The grid album test and the pinch test from the spec.
   Check: the full `xcodebuild clean test` passes on the simulator.
8. **Review, then install on the iPhone.**

## Not yet specified

- Whether a 7-day window is the right width once Kan has used it on real days.

## Out of scope

- Opening the grid from the viewer, Free up space, Apply or the bulk screens.
- Selecting a whole day, or dragging across tiles to select many.
- Sharing many items at once.
- Detecting workouts or similar photos automatically.
- Changing the window width in the app.
