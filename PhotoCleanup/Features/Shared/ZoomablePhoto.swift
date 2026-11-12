import SwiftUI
import UIKit

/// A photo page that zooms with a pinch or a double-tap, pans while zoomed, and loads a sharper copy when a zoom settles.
struct ZoomablePhoto: View {
    @Environment(AppModel.self) private var model
    @Environment(\.displayScale) private var displayScale

    let asset: AssetInfo
    let isCurrent: Bool

    @State private var image: UIImage?
    @State private var sharper: UIImage?
    @State private var wanted: CGSize?

    private var assetPixels: CGSize { CGSize(width: asset.pixelWidth, height: asset.pixelHeight) }

    var body: some View {
        GeometryReader { proxy in
            let fitted = ZoomMath.fitted(assetPixels, in: proxy.size)
            ZStack {
                if let shown = sharper ?? image {
                    ZoomingImage(
                        image: shown,
                        shape: assetPixels,
                        maxZoom: ZoomMath.maxZoom(assetPixels: assetPixels, fitted: fitted, displayScale: displayScale),
                        isCurrent: isCurrent
                    ) { zoom in
                        requestSharper(fitted: fitted, zoom: zoom)
                    }
                } else {
                    ProgressView()
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .task(id: asset.id) {
                let pixels = CGSize(width: proxy.size.width * displayScale, height: proxy.size.height * displayScale)
                let loaded = await model.library.thumbnail(for: asset.id, targetSize: pixels)
                guard !Task.isCancelled else { return }
                image = loaded
            }
        }
        .task(id: wanted) {
            guard let wanted else { return }
            let loaded = await model.library.thumbnail(for: asset.id, targetSize: wanted)
            // Leaving the page clears `wanted`, which cancels this load.
            guard !Task.isCancelled, let loaded, let shown = sharper ?? image,
                  Self.pixels(of: loaded).width > Self.pixels(of: shown).width else { return }
            sharper = loaded
        }
        .onChange(of: isCurrent) {
            guard !isCurrent else { return }
            sharper = nil
            wanted = nil
        }
        .onDisappear {
            image = nil
            sharper = nil
            wanted = nil
        }
    }

    private func requestSharper(fitted: CGSize, zoom: CGFloat) {
        guard zoom > 1, let shown = sharper ?? image else { return }
        let target = ZoomMath.sharperPixels(fitted: fitted, zoom: zoom, displayScale: displayScale, assetPixels: assetPixels)
        let have = Self.pixels(of: shown)
        if target.width > have.width || target.height > have.height {
            wanted = target
        }
    }

    private static func pixels(of image: UIImage) -> CGSize {
        CGSize(width: image.size.width * image.scale, height: image.size.height * image.scale)
    }
}

private struct ZoomingImage: UIViewRepresentable {
    let image: UIImage
    /// The photo's pixel size, which sets the image view's shape.
    let shape: CGSize
    let maxZoom: CGFloat
    let isCurrent: Bool
    /// Called with the zoom each time a zoom settles.
    let settled: (CGFloat) -> Void

    func makeUIView(context: Context) -> ZoomScrollView {
        ZoomScrollView()
    }

    func updateUIView(_ view: ZoomScrollView, context: Context) {
        view.settled = settled
        view.maximumZoomScale = maxZoom
        view.photoShape = shape
        if view.imageView.image !== image { view.imageView.image = image }
        // This runs on every SwiftUI update, so it touches the zoom only when the page stops being current.
        if !isCurrent, view.zoomScale != 1 { view.showFit() }
    }
}

private final class ZoomScrollView: UIScrollView, UIScrollViewDelegate {
    let imageView = UIImageView()
    var settled: (CGFloat) -> Void = { _ in }
    /// The image view takes its shape from this, never from the loaded image, so swapping in a sharper copy never moves it.
    var photoShape: CGSize = .zero {
        didSet { if photoShape != oldValue { setNeedsLayout() } }
    }
    private var fittedFor: (bounds: CGSize, shape: CGSize)?

    init() {
        super.init(frame: .zero)
        delegate = self
        minimumZoomScale = 1
        showsHorizontalScrollIndicator = false
        showsVerticalScrollIndicator = false
        contentInsetAdjustmentBehavior = .never
        imageView.contentMode = .scaleAspectFit
        imageView.isAccessibilityElement = true
        imageView.accessibilityTraits = .image
        imageView.accessibilityLabel = "Photo"
        imageView.accessibilityIdentifier = "preview.photo"
        addSubview(imageView)
        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(doubleTapped))
        doubleTap.numberOfTapsRequired = 2
        addGestureRecognizer(doubleTap)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override func layoutSubviews() {
        super.layoutSubviews()
        // Scrolling lays out too; fit again only when the page size or the photo's shape changes.
        guard fittedFor?.bounds != bounds.size || fittedFor?.shape != photoShape else { return }
        fittedFor = (bounds.size, photoShape)
        zoomScale = 1
        let fitted = ZoomMath.fitted(photoShape, in: bounds.size)
        imageView.frame = CGRect(origin: .zero, size: fitted == .zero ? bounds.size : fitted)
        contentSize = imageView.frame.size
        showFit()
    }

    func showFit() {
        zoomScale = 1
        centre()
        contentOffset = CGPoint(x: -contentInset.left, y: -contentInset.top)
    }

    /// Centres the photo with insets while it is smaller than the page. Moving the image view instead would throw off
    /// the double-tap's offset by the letterbox. Rounding down keeps a photo at fit from scrolling by a fraction.
    private func centre() {
        let x = max(((bounds.width - contentSize.width) / 2).rounded(.down), 0)
        let y = max(((bounds.height - contentSize.height) / 2).rounded(.down), 0)
        contentInset = UIEdgeInsets(top: y, left: x, bottom: y, right: x)
    }

    func viewForZooming(in scrollView: UIScrollView) -> UIView? { imageView }

    func scrollViewDidZoom(_ scrollView: UIScrollView) { centre() }

    func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
        endZoom(at: scale)
    }

    private func endZoom(at scale: CGFloat) {
        let rest = ZoomMath.settle(scale, maxZoom: maximumZoomScale)
        if rest == 1 {
            UIView.animate(withDuration: 0.2) { self.showFit() }
        } else if rest != scale {
            setZoomScale(rest, animated: true)
        }
        settled(rest)
    }

    @objc private func doubleTapped(_ tap: UITapGestureRecognizer) {
        guard maximumZoomScale > 1 else { return }
        guard zoomScale == 1 else {
            UIView.animate(withDuration: 0.3) { self.showFit() } completion: { _ in self.endZoom(at: 1) }
            return
        }
        let point = tap.location(in: imageView)
        let scale = ZoomMath.doubleTapZoom(maxZoom: maximumZoomScale)
        let fitted = imageView.bounds.size
        // Setting the zoom inside an animation skips scrollViewDidEndZooming, so the completion ends the zoom itself.
        UIView.animate(withDuration: 0.3) {
            self.zoomScale = scale
            self.centre()
            self.contentOffset = CGPoint(
                x: Self.offset(centring: point.x * scale, content: fitted.width * scale, page: self.bounds.width, inset: self.contentInset.left),
                y: Self.offset(centring: point.y * scale, content: fitted.height * scale, page: self.bounds.height, inset: self.contentInset.top)
            )
        } completion: { _ in
            self.endZoom(at: self.zoomScale)
        }
    }

    /// The offset along one axis that puts `point` in the middle of the page, kept within the photo's edges.
    private static func offset(centring point: CGFloat, content: CGFloat, page: CGFloat, inset: CGFloat) -> CGFloat {
        guard content > page else { return -inset }
        return min(max(point - page / 2, 0), content - page)
    }
}
