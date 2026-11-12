import CoreGraphics
import Testing
@testable import PhotoCleanup

struct ZoomMathTests {
    /// The iPhone 16 Pro viewer page, in points at 3x.
    private let page = CGSize(width: 402, height: 610)
    private let scale: CGFloat = 3

    private func maxZoom(_ width: CGFloat, _ height: CGFloat) -> CGFloat {
        let pixels = CGSize(width: width, height: height)
        return ZoomMath.maxZoom(assetPixels: pixels, fitted: ZoomMath.fitted(pixels, in: page), displayScale: scale)
    }

    @Test func aFullSizePhotoZoomsToFourTimes() {
        #expect(ZoomMath.fitted(CGSize(width: 4032, height: 3024), in: page) == CGSize(width: 402, height: 301.5))
        #expect(maxZoom(4032, 3024) == 4)
    }

    @Test func maxZoomStopsAtTwoScreenPixelsPerPhotoPixel() {
        #expect(abs(maxZoom(1800, 2400) - 3600.0 / 1206) < 0.0001)
    }

    @Test func smallPhotosStillZoomToTwoTimes() {
        #expect(maxZoom(1200, 1600) == 2, "1200 x 1600 reaches two screen pixels at 1.99x")
        #expect(maxZoom(600, 800) == 2, "600 x 800 reaches two screen pixels at 0.995x")
    }

    @Test func aPhotoWithNoPixelSizeDoesNotZoom() {
        #expect(maxZoom(0, 0) == 1)
        #expect(ZoomMath.fitted(.zero, in: page) == .zero)
    }

    @Test func zoomsNeverRestJustAboveFit() {
        #expect(ZoomMath.settle(0.7, maxZoom: 4) == 1)
        #expect(ZoomMath.settle(1.02, maxZoom: 4) == 1)
        #expect(ZoomMath.settle(1.049, maxZoom: 4) == 1)
        #expect(ZoomMath.settle(1.05, maxZoom: 4) == 1.05)
        #expect(ZoomMath.settle(3, maxZoom: 2) == 2)
    }

    @Test func doubleTapZoomsToTwoAndAHalfOrTheMax() {
        #expect(ZoomMath.doubleTapZoom(maxZoom: 4) == 2.5)
        #expect(ZoomMath.doubleTapZoom(maxZoom: 2) == 2)
    }

    @Test func aLetterboxedPhotoAsksOnlyForThePixelsItShows() {
        let full = CGSize(width: 4032, height: 3024)
        let fitted = ZoomMath.fitted(full, in: page)
        #expect(
            ZoomMath.sharperPixels(fitted: fitted, zoom: 1.5, displayScale: scale, assetPixels: full) == CGSize(width: 1809, height: 1357),
            "402 x 301.5 pt at 1.5x and 3x is 1809 x 1356.75 pixels, not the page's 1809 x 2745"
        )
    }

    @Test func theSharperCopyIsCappedAtThePhotoSize() {
        let full = CGSize(width: 4032, height: 3024)
        #expect(ZoomMath.sharperPixels(fitted: ZoomMath.fitted(full, in: page), zoom: 4, displayScale: scale, assetPixels: full) == full)
        let seed = CGSize(width: 1200, height: 1600)
        #expect(ZoomMath.sharperPixels(fitted: ZoomMath.fitted(seed, in: page), zoom: 2, displayScale: scale, assetPixels: seed) == seed)
    }
}
