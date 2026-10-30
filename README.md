<img src="assets/icon.svg" width="64" height="64" alt="">

# Photo Cleanup

Photo Cleanup is a free, open-source iPhone app that clears photo storage and keeps the photos that matter to you.

- **Swipe review.** Pick a month and swipe through it. Swipe right to keep a photo and left to queue it for deletion.
- **Free up space.** Delete everything older than a date you pick, except the photos you protect. Tap a photo to keep it.
- **Large videos.** Lists your videos biggest first, so you can pick the ones to delete.
- **Screenshots.** Every screenshot starts selected, so clearing them takes a few taps.
- **The Keep album.** Photos you keep go into a normal Photos album named Keep. It survives a reinstall, and you can edit it in Photos.
- **Albums and sharing.** Add the photo on screen to any album, or a new one, and share it through the iOS share sheet.
- **Protected albums.** Every album you made is protected by default. Switch one off in Settings to let its photos come up for deletion.

The app deletes nothing until you tap the delete button on the review screen.
To see a photo full screen, or play a video, before you decide, touch and hold it in a grid or tap the card in the swipe deck.

## Privacy

The app has no network code, no analytics and no accounts.
Your photos leave the phone only when you tap Share.
If iCloud Photos keeps only a small copy of a photo on the phone, iOS may download the full version from your iCloud library when the app shows it, plays it or shares it.

## Before you delete anything

- **Back up first.** The app cannot see your backup, so make sure it is complete before you delete.
- **iOS confirms every delete.** Every delete goes through iOS, which asks you to confirm it.
- **Deleted items go to Recently Deleted.** They stay there for 30 days and still use space until you empty it (in Photos, under Utilities > Recently Deleted).
- **Some photos are never deleted.** Favorites, hidden photos, the Keep album and protected albums never come up for deletion.
- **Delete in batches.** Delete a few thousand items at a time at most. In Free up space, start with an older cutoff and move it forward in steps.
- **iCloud Photos deletes everywhere.** If iCloud Photos is on, a delete here also deletes the photo from iCloud and your other devices.

## Install option A: sideload the app

1. Set up [AltStore](https://altstore.io) or [SideStore](https://sidestore.io) with your Apple ID, following the guide on their site.
2. Download `PhotoCleanup.ipa` from the Releases page of this repository.
3. Open the file in AltStore or SideStore to install it.

A free Apple ID signs the app for 7 days.
Refresh it in AltStore or SideStore before then, or it stops opening.
A free Apple ID allows 3 sideloaded apps at once, and AltStore or SideStore may use one of them.

## Install option B: build from source

You need a Mac with Xcode, [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`) and a free Apple ID.

1. In Xcode, open Settings > Accounts and add your Apple ID.
   Select it, click Manage Certificates, and add an Apple Development certificate.
2. Copy the example settings file:

   ```sh
   cp Config/Local.xcconfig.example Config/Local.xcconfig
   ```

3. In `Config/Local.xcconfig`, set `DEVELOPMENT_TEAM` to your team ID and `BUNDLE_ID_PREFIX` to a prefix you own, for example `com.yourname`.
   Your team ID is the Organizational Unit of your Apple Development certificate in Keychain Access.
   The app's bundle ID becomes `<prefix>.PhotoCleanup`.
   If someone else already uses that ID, the build fails with "bundle identifier not available"; pick another prefix.
4. Connect the iPhone and turn on Developer Mode (Settings > Privacy & Security > Developer Mode).
   Then build and install, using the iPhone name shown in Settings > General > About > Name:

   ```sh
   xcodegen generate
   xcodebuild build -project PhotoCleanup.xcodeproj -scheme PhotoCleanup -configuration Release \
     -destination 'platform=iOS,name=<iPhone name>' -derivedDataPath build/device \
     -allowProvisioningUpdates
   xcrun devicectl device install app --device '<iPhone name>' \
     build/device/Build/Products/Release-iphoneos/PhotoCleanup.app
   ```

5. The first time, open Settings > General > VPN & Device Management on the iPhone and trust your developer profile.

A free Apple ID profile expires after 7 days.
Build and install again when the app stops opening.
Installing over the old copy with the same `BUNDLE_ID_PREFIX` keeps its pending decisions, and the Keep album lives in Photos, so nothing is lost.

## Requirements

An iPhone with iOS 18 or later.

## Test

The UI tests need photos in the simulator library.
Seed them first, then run the unit and UI tests:

```sh
xcodegen generate
scripts/seed-simulator.sh <simulator-udid>
xcodebuild test -project PhotoCleanup.xcodeproj -scheme PhotoCleanup \
  -destination 'platform=iOS Simulator,id=<simulator-udid>'
```

The seed script grants photo access to `com.example.PhotoCleanup`, the default bundle ID.
If `Config/Local.xcconfig` sets another prefix, pass the same one to the script:

```sh
BUNDLE_ID_PREFIX=com.yourname scripts/seed-simulator.sh <simulator-udid>
```

The UI test accepts the photo access prompt if it appears.
`simctl privacy grant photos` writes an old-style grant that PhotoKit's read-write check does not accept on iOS 26.

The design notes are in `docs/specs/`, and the build plans are in `docs/plans/`.

## License

Copyright (C) 2026 kankunnawat

This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
See the GNU General Public License for more details.

The full license text is in [LICENSE](LICENSE).
