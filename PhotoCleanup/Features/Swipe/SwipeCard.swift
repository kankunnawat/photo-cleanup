import SwiftUI

struct SwipeCard: View {
    let asset: AssetInfo
    let bytes: Int64?
    let isTop: Bool
    let onDecide: (Decision) -> Void
    let onTap: () -> Void
    /// Nil when the card has no date, because the grid has no day to center on.
    let onZoomOut: (() -> Void)?

    @State private var offset: CGSize = .zero
    @State private var isFlyingOff = false
    @State private var pinchScale: CGFloat = 1
    @State private var isPinching = false

    private static let threshold: CGFloat = 110

    var body: some View {
        GeometryReader { proxy in
            AssetThumbnail(id: asset.id, pointSize: proxy.size)
                .frame(width: proxy.size.width, height: proxy.size.height)
                // The placeholder fill is translucent; without this the cards below show through until the photo loads.
                .background(Color(.secondarySystemGroupedBackground))
                .overlay(alignment: .bottom) { caption }
                .overlay { stamps }
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(.white.opacity(0.6), lineWidth: 1))
                .shadow(color: .black.opacity(isTop ? 0.2 : 0.08), radius: 12, y: 6)
        }
        .aspectRatio(3 / 4, contentMode: .fit)
        .scaleEffect(pinchScale)
        .offset(offset)
        .rotationEffect(.degrees(Double(offset.width / 18)), anchor: .bottom)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .gesture(isTop ? drag : nil)
        .simultaneousGesture(isTop && onZoomOut != nil ? pinch : nil)
        .allowsHitTesting(isTop && !isFlyingOff)
        .sensoryFeedback(.selection, trigger: pastThreshold)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(isTop ? "deck.card" : "deck.card.behind")
        .accessibilityActions {
            // allowsHitTesting does not gate accessibility actions, so cards behind the top one get none.
            if isTop {
                Button("Keep") { onDecide(.keep) }
                Button("Delete") { onDecide(.trash) }
                Button("Preview", action: onTap)
                if let onZoomOut {
                    Button("Around this time", action: onZoomOut)
                }
            }
        }
    }

    private var pastThreshold: Bool {
        abs(offset.width) > Self.threshold
    }

    private var drag: some Gesture {
        DragGesture()
            .onChanged { value in
                if !isPinching { offset = value.translation }
            }
            .onEnded { value in
                // The pinch's fingers also drive this drag; a pinch never decides the card.
                guard !isPinching else {
                    withAnimation(.spring(duration: 0.35, bounce: 0.4)) { offset = .zero }
                    return
                }
                let width = value.translation.width
                let predicted = value.predictedEndTranslation.width
                if width > Self.threshold || predicted > Self.threshold * 2.5 {
                    flyOff(.keep)
                } else if width < -Self.threshold || predicted < -Self.threshold * 2.5 {
                    flyOff(.trash)
                } else {
                    withAnimation(.spring(duration: 0.35, bounce: 0.4)) { offset = .zero }
                }
            }
    }

    /// Pinching the card closed, as in Photos, zooms out to the days around it.
    private var pinch: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                isPinching = true
                offset = .zero
                pinchScale = min(1, max(0.6, value.magnification))
            }
            .onEnded { value in
                withAnimation(.spring(duration: 0.3)) { pinchScale = 1 }
                if value.magnification < 0.8 { onZoomOut?() }
                // The drag of the same fingers can end after this; it must still see the pinch.
                Task { isPinching = false }
            }
    }

    private func flyOff(_ decision: Decision) {
        isFlyingOff = true
        let direction: CGFloat = decision == .keep ? 1 : -1
        withAnimation(.easeOut(duration: 0.22)) {
            offset = CGSize(width: direction * 700, height: offset.height + 40)
        } completion: {
            onDecide(decision)
        }
    }

    private var caption: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 2) {
                Text(Formatting.day(asset.creationDate))
                    .font(.headline)
                if let bytes {
                    Text(Formatting.bytes(bytes))
                        .font(.subheadline)
                }
            }
            Spacer()
            if asset.kind == .video {
                Label(Formatting.duration(asset.duration), systemImage: "play.fill")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.black.opacity(0.4), in: Capsule())
            }
        }
        .foregroundStyle(.white)
        .padding()
        .background(LinearGradient(colors: [.clear, .black.opacity(0.55)], startPoint: .top, endPoint: .bottom))
    }

    private var stamps: some View {
        let progress = min(abs(offset.width) / Self.threshold, 1)
        return ZStack {
            stamp("KEEP", color: .keepGreen, angle: -14)
                .opacity(offset.width > 0 ? progress : 0)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            stamp("DELETE", color: .red, angle: 14)
                .opacity(offset.width < 0 ? progress : 0)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        }
        .padding(28)
    }

    private func stamp(_ text: String, color: Color, angle: Double) -> some View {
        Text(text)
            .font(.system(size: 36, weight: .heavy, design: .rounded))
            .foregroundStyle(color)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(color, lineWidth: 5))
            .background(.white.opacity(0.75), in: RoundedRectangle(cornerRadius: 10))
            .rotationEffect(.degrees(angle))
    }
}
