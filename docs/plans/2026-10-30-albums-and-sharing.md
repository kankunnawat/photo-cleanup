# Albums and sharing: build plan

Spec: `docs/specs/2026-10-30-albums-and-sharing-design.md`.

One builder makes it as one change, because the library, the model and both entry points share the new album operations.
A fresh reviewer then checks every album write and the delete queue rule.

## Steps

1. **Library operations.**
   `createAlbum(title:)`, `add(_:toAlbum:)`, `remove(_:fromAlbum:)` and `exportOriginal(for:)` on `PhotoLibrary`, in `PhotoKitLibrary` and in the fake.
   Check: unit tests on the fake pass.
2. **Model.**
   Album lookups, album writes, the clear-pending-delete rule, recent albums.
   Check: unit tests for the rule and for recents.
3. **Album picker.**
   The sheet with New album, search, Recent and every album, with check marks and "Not protected".
   Check: build passes; screenshots light and dark.
4. **Entry points.**
   Album and Share in the viewer's top bar; the Album round button in the swipe deck.
   Check: build passes.
5. **Sharing.**
   Export the file first while the Share button shows a spinner and a Cancel that stops the export, then present the system share sheet.
   Remove the file when the sheet closes, and clear the export folder at launch.
   Check: share a seeded photo to Files on the simulator.
6. **UI test and full run.**
   Check: the full `xcodebuild clean test` passes on the iOS 26.4 simulator.
7. **Review, then install on an iPhone.**

## Not yet specified

- Whether the Recent list should also learn from albums used in Photos.

## Out of scope

- Browsing an album's photos in the app.
- Selecting many photos in a grid to add or share at once.
- Renaming, deleting or nesting albums.
