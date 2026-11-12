# Pinch to zoom: build plan

Status: approved with the recommended zoom range, 2x to 4x (2026-11-12).

Spec: `docs/specs/2026-10-30-photo-cleanup-design.md`, section "Preview".

Kan wants to zoom into a photo in the full-screen viewer, so he can check sharpness and detail before he keeps or deletes it.
Today the viewer shows each photo only at screen size, and a pinch does nothing.

## Decision

Each photo page in the viewer gets its own UIKit zooming scroll view.
Pinch and double-tap zoom, a drag pans, and a swipe at the zoomed photo's edge moves to the next item, as in Photos.
When a zoom settles, the viewer loads a sharper copy of the photo.

A throwaway prototype built both candidates on the simulator and ran the same checks against each.

| Option | Result | Why not / why |
|---|---|---|
| UIKit zooming scroll view per page, chosen | Passed all 7 checks | A swipe at the zoomed edge hands off to paging with no extra code. The photo's accessibility frame follows the zoom, so UI tests can read it. Pan has momentum and rubber-banding. |
| SwiftUI pinch and pan gestures | Passed 6 of 7; paging back was not testable | Paging has to be off while zoomed, so you must zoom out before you can move on. No momentum or rubber band. The photo's accessibility frame stays the whole page when zoomed. |

## Data shape

- `ZoomMath` (pure, new, `PhotoCleanup/Domain/ZoomMath.swift`): four functions, so the rules are unit-tested without UIKit.
  - Max zoom: the zoom at which one photo pixel covers two screen pixels, kept between 2x and 4x.
    The 2x floor means a pinch always responds, even on a small photo.
  - Settle: a zoom that ends below 1.05x becomes exactly 1x, so no photo can rest just above fit.
  - Double-tap zoom: 2.5x, or the max zoom when that is lower.
  - Sharper request: the photo's fitted size on screen x zoom x display scale, capped at the photo's own pixel size.
    It uses the fitted size, not the page, so a letterboxed photo does not ask for pixels it cannot show.
- `ZoomablePhoto` (new view, `PhotoCleanup/Features/Shared/ZoomablePhoto.swift`): a `UIViewRepresentable` with a `UIScrollView` and a `UIImageView`.
  It takes the asset, whether its page is current, and loads its own images through `PhotoLibrary.thumbnail`.
  The image view is sized from the asset's pixel shape, never from the loaded image, so swapping in the sharper copy does not move the photo.
- `PreviewImage` stays as it is for video posters, so videos never zoom.
  `ZoomablePhoto` does its own loading because it loads two sizes and swaps them; the poster path keeps its one load untouched.
- Every viewer gets zoom, because they all use `AssetPreview`: the grids, Apply, Around this time and the swipe deck.

## Steps

1. **Zoom rules.**
   `ZoomMath` (`PhotoCleanup/Domain/ZoomMath.swift`) with Swift Testing unit tests (`PhotoCleanupTests/ZoomMathTests.swift`): max zoom for a 4032 x 3024 photo, a 1200 x 1600 photo and a 600 x 800 photo (the 2x floor); settle at 1.02x, 1.049x and 1.05x; the double-tap zoom when the max is below 2.5x; the sharper request for a letterboxed photo and for one capped at its own size.
   Check: unit tests pass.
2. **Zoomable photo** (`PhotoCleanup/Features/Shared/ZoomablePhoto.swift`, `PhotoCleanup/Features/Shared/AssetPreview.swift`).
   - `ZoomablePhoto` replaces `PreviewImage` on photo pages in `AssetPreview`, which passes it whether the page is current.
   - Minimum zoom is 1, and the maximum comes from `ZoomMath`.
   - At fit the scroll view neither scrolls nor bounces sideways, so the pager gets every horizontal swipe.
   - The photo is centred with content insets. Centring by moving the image view put the double-tap 37 pt off in the prototype.
   - A double-tap at fit zooms to the double-tap zoom with the tapped point in the centre. A double-tap while zoomed returns to fit.
   - Every zoom end runs through settle, including the double-tap's, which UIKit does not report as a zoom end when the zoom is set inside an animation.
   - When a zoom settles above 1x and the shown image is smaller than the sharper request, the photo loads the sharper copy.
     A result that arrives after the page left, or that is smaller than the image already shown, is thrown away.
     A failed load keeps the image already shown.
   - When its page stops being current, the photo returns to fit and drops the sharper copy.
   - `updateUIView` runs on every SwiftUI update, so it changes the zoom only when the page stops being current.
   - An asset with no pixel size shows at fit without zoom.
   - The image view is an accessibility image element with the label "Photo" and the identifier `preview.photo`.
   - No debug logging ships.
   Check: build passes with zero warnings, and the existing preview tests in `SwipeAndApplyUITests` and `AlbumUITests` pass.
3. **UI tests** (`PhotoCleanupUITests/ZoomUITests.swift`) on the busy seeded day or a big seed photo, reading the `preview.photo` frame and the "N of M" position:
   - A pinch makes the photo bigger and keeps the position. Pinching back returns the photo to its fit frame, and a swipe then pages.
   - A double-tap makes the photo bigger, and a drag moves it without changing the position. Swipes while zoomed reach the edge and then page. Paging back shows the photo at fit.
   - Close works while zoomed.
   - An album add while zoomed keeps the zoom, although the bar gets shorter.
   XCUITest pinches only about the element's centre and crashes on a pinch near scale 1, so the tests avoid both.
   The tests delete nothing, so they do not use up seed photos.
   Check: the new tests pass.
4. **Full run.**
   `xcodegen generate && xcodebuild clean test` on the simulator, zero warnings.
   Check: every test passes; the known flake is rerun alone and both results are reported.
5. **Look at it.**
   Simulator screenshots at fit, pinched, double-tapped, and handed off to the next photo.
6. **Review.**
   A fresh reviewer reads the diff, focused on the handoff to paging, the reset when a page leaves, the sharper-copy swap, and memory.
7. **Phone.**
   Install the Release build. Kan zooms a real 24 MP photo to check that the sharper copy loads, because the 1200 x 1600 seed photos cannot show it.
   An iCloud-only photo may take a moment to sharpen, because the sharper copy can need a download.

## Deviations

- Review found that adding a zoomed photo to an album reset the zoom: the photo becomes protected, the bar loses its button, and the taller page re-fitted the photo.
  A zoomed photo now keeps its zoom when the page changes size, and fits the new size on its next return to fit.
- The photo's fitted size is rounded down to whole device pixels, because a floating-point overshoot could make a photo at fit wider than the page.

## Not yet specified

- Whether 4x is enough to judge sharpness on 48 MP photos once Kan has used it.

## Out of scope

- Zooming videos or their posters.
- Zooming the swipe deck card, where a pinch already opens Around this time, and zooming grid tiles.
- Live Photo playback.
