import CoreGraphics

/// Zoom rules for a photo in the viewer.
nonisolated enum ZoomMath {
    /// A zoom that ends below this rests at fit, so no photo stays just above fit.
    private static let fitSnap: CGFloat = 1.05

    /// The size `content` takes when scaled to fit `container`; zero when `content` has no area.
    static func fitted(_ content: CGSize, in container: CGSize) -> CGSize {
        guard content.width > 0, content.height > 0 else { return .zero }
        let scale = min(container.width / content.width, container.height / content.height)
        return CGSize(width: content.width * scale, height: content.height * scale)
    }

    /// The zoom at which one photo pixel covers two screen pixels, kept between 2x and 4x so a pinch always responds.
    /// A photo with no pixel size does not zoom.
    static func maxZoom(assetPixels: CGSize, fitted: CGSize, displayScale: CGFloat) -> CGFloat {
        guard assetPixels.width > 0, assetPixels.height > 0, fitted.width > 0, displayScale > 0 else { return 1 }
        let twoScreenPixels = 2 * assetPixels.width / (fitted.width * displayScale)
        return min(max(twoScreenPixels, 2), 4)
    }

    /// The zoom a finished zoom rests at: exactly fit below `fitSnap`, otherwise at most `maxZoom`.
    static func settle(_ zoom: CGFloat, maxZoom: CGFloat) -> CGFloat {
        zoom < fitSnap ? 1 : min(zoom, maxZoom)
    }

    static func doubleTapZoom(maxZoom: CGFloat) -> CGFloat {
        min(2.5, maxZoom)
    }

    /// The pixels a sharper copy needs at `zoom`, in whole pixels: the photo's fitted size on screen times the zoom
    /// and the display scale, capped at the photo's own size.
    static func sharperPixels(fitted: CGSize, zoom: CGFloat, displayScale: CGFloat, assetPixels: CGSize) -> CGSize {
        CGSize(
            width: min((fitted.width * zoom * displayScale).rounded(.up), assetPixels.width),
            height: min((fitted.height * zoom * displayScale).rounded(.up), assetPixels.height)
        )
    }
}
