import SwiftUI

enum MenuBarLabelStyle: String {
    case percent
    case bar
}

struct MenuLabelView: View {
    @EnvironmentObject private var store: UsageStore
    @AppStorage("menuBarLabelStyle") private var style = MenuBarLabelStyle.percent.rawValue

    private var entry: LimitEntry? { store.primaryEntry }

    var body: some View {
        let resolved = MenuBarLabelStyle(rawValue: style) ?? .percent
        return HStack(spacing: 3) {
            switch resolved {
            case .percent:
                percentLabel
            case .bar:
                if let image = barImage {
                    Image(nsImage: image)
                } else {
                    Text("--%")
                        .font(.system(size: 11, weight: .semibold).monospacedDigit())
                }
            }
            if let marker = entry?.shortMarker {
                Text(marker)
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.secondary)
            }
        }
        .opacity(store.isStale ? 0.45 : 1)
    }

    private var percentLabel: some View {
        let text = entry?.percentText ?? "--%"
        return Text(text)
            .font(.system(size: 11, weight: .semibold).monospacedDigit())
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                Capsule().strokeBorder(.primary, lineWidth: 1)
            )
    }

    // MenuBarExtra labels ignore fixed frames on arbitrary SwiftUI content
    // (text sizes naturally, but shapes/canvas collapse), so the bar gauge is
    // rendered offscreen into an NSImage and shown as an Image instead.
    // Colors (yellow fill / red pointer) require non-template rendering, so
    // the base color is resolved against the current menu bar appearance.
    private var barImage: NSImage? {
        guard let entry else { return nil }
        let dark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let size = CGSize(width: 30, height: 12)
        let renderer = ImageRenderer(
            content: BarGaugeDrawing(
                ratio: entry.usedRatio ?? 0,
                elapsed: entry.elapsedFraction(at: store.now),
                dark: dark
            )
            .frame(width: size.width, height: size.height)
        )
        renderer.scale = 2
        guard let image = renderer.nsImage else { return nil }
        image.size = size
        return image
    }
}

private struct BarGaugeDrawing: View {
    let ratio: Double
    let elapsed: Double?
    let dark: Bool

    // Usage within this margin of the pace pointer counts as "approaching".
    private static let nearMargin = 0.03

    private var nearPace: Bool {
        guard let elapsed else { return false }
        return ratio >= elapsed - Self.nearMargin
    }

    var body: some View {
        let base = dark ? Color.white : Color.black
        let fill = nearPace ? Color.yellow : base
        return GeometryReader { geo in
            let size = geo.size
            Canvas { ctx, _ in
                let outline = Capsule().path(
                    in: CGRect(origin: .zero, size: size).insetBy(dx: 0.5, dy: 0.5))
                ctx.stroke(outline, with: .color(base), lineWidth: 1)
                let trackWidth = max(size.width - 4, 0)
                let fillWidth = trackWidth * min(max(ratio, 0), 1)
                if fillWidth > 0 {
                    let fillPath = Capsule().path(
                        in: CGRect(x: 2, y: 2, width: fillWidth, height: size.height - 4))
                    ctx.fill(fillPath, with: .color(fill))
                }
                if let elapsed {
                    let x = 2 + trackWidth * min(max(elapsed, 0), 1)
                    var pointer = Path()
                    pointer.move(to: CGPoint(x: x, y: 1))
                    pointer.addLine(to: CGPoint(x: x, y: size.height - 1))
                    ctx.stroke(pointer, with: .color(.red), lineWidth: 1.5)
                }
            }
        }
    }
}
