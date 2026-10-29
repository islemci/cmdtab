import SwiftUI

struct SwitcherView: View {
    @ObservedObject var model: SwitcherModel

    let columns = [GridItem(.adaptive(minimum: 110, maximum: 140), spacing: 12)]

    var body: some View {
        VStack(spacing: 12) {
            Text("CmdTab")
                .font(.headline)
                .foregroundStyle(.secondary)

            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(Array(model.items.enumerated()), id: \.element.id) { index, item in
                        WindowCard(item: item, isSelected: index == model.selectedIndex)
                            .onTapGesture { model.selectedIndex = index; model.confirm() }
                    }
                }
                .padding(8)
            }

            if model.items.isEmpty {
                Text("No windows")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(16)
        .frame(width: 520, height: 360)
        .background {
            if #available(macOS 26.0, *) {
                Color.clear.glassEffect(in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            } else {
                Color.clear.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            }
        }
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(.white.opacity(0.25), lineWidth: 1))
    }
}

struct WindowCard: View {
    let item: WindowItem
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 8) {
            if let icon = item.icon {
                Image(nsImage: icon)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 48, height: 48)
            } else {
                Image(systemName: "app")
                    .font(.system(size: 36))
                    .frame(width: 48, height: 48)
            }
            Text(item.appName)
                .font(.caption.bold())
                .lineLimit(1)
            Text(item.title)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .padding(8)
        .frame(width: 120, height: 120)
        .background(isSelected ? Color.accentColor.opacity(0.25) : Color.clear)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
        )
        .cornerRadius(10)
    }
}

final class SwitcherModel: ObservableObject, @unchecked Sendable {
    @Published var items: [WindowItem] = []
    @Published var selectedIndex: Int = 0
    @Published var isVisible: Bool = false

    func refresh() {
        items = WindowEnumerator.listWindows()
        if selectedIndex >= items.count { selectedIndex = max(0, items.count - 1) }
    }

    func moveSelection(_ delta: Int) {
        guard !items.isEmpty else { return }
        selectedIndex = (selectedIndex + delta + items.count) % items.count
    }

    func confirm() {
        guard items.indices.contains(selectedIndex) else { return }
        let item = items[selectedIndex]
        hide()
        WindowEnumerator.focus(item: item)
    }

    func hide() {
        isVisible = false
    }
}
