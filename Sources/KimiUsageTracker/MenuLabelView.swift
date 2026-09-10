import SwiftUI

struct MenuLabelView: View {
    @EnvironmentObject private var store: UsageStore

    var body: some View {
        let text: String = {
            guard let entry = store.primaryEntry,
                  let percent = entry.remainingPercent else { return "--%" }
            return entry.isFiveHour ? "\(percent)%" : "\(percent)% W"
        }()
        Text(text)
            .font(.system(size: 11, weight: .semibold).monospacedDigit())
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                Capsule().strokeBorder(.primary, lineWidth: 1)
            )
            .opacity(store.isStale ? 0.45 : 1)
    }
}
