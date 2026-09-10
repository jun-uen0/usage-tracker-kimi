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
            if let entry, !entry.isFiveHour {
                Text("W")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.secondary)
            }
        }
        .opacity(store.isStale ? 0.45 : 1)
    }

    private var percentLabel: some View {
        let text: String = {
            guard let percent = entry?.usedPercent else { return "--%" }
            return "\(percent)%"
        }()
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
    // Template rendering lets the menu bar tint it for light/dark mode.
    private var barImage: NSImage? {
        let ratio = entry?.usedRatio ?? 0
        let size = CGSize(width: 28, height: 12)
        let renderer = ImageRenderer(
            content: BarGaugeDrawing(ratio: ratio)
                .frame(width: size.width, height: size.height)
        )
        renderer.scale = 2
        guard let image = renderer.nsImage else { return nil }
        image.size = size
        image.isTemplate = true
        return image
    }
}

private struct BarGaugeDrawing: View {
    let ratio: Double

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            Canvas { ctx, _ in
                let outline = Capsule().path(
                    in: CGRect(origin: .zero, size: size).insetBy(dx: 0.5, dy: 0.5))
                ctx.stroke(outline, with: .color(.black), lineWidth: 1)
                let fillWidth = max(size.width - 4, 0) * min(max(ratio, 0), 1)
                if fillWidth > 0 {
                    let fill = Capsule().path(
                        in: CGRect(x: 2, y: 2, width: fillWidth, height: size.height - 4))
                    ctx.fill(fill, with: .color(.black))
                }
            }
        }
    }
}
