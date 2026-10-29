import AppKit
import ApplicationServices

struct WindowItem: Identifiable, Hashable {
    let id: String
    let pid: pid_t
    let appName: String
    let title: String
    let icon: NSImage?
    let windowNumber: Int?

    static func == (lhs: WindowItem, rhs: WindowItem) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}


enum WindowEnumerator {
    nonisolated(unsafe) static var lastActivated: [pid_t: Date] = [:]

    static func startTracking() {
        let nc = NSWorkspace.shared.notificationCenter
        nc.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { note in
            if let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
                lastActivated[app.processIdentifier] = Date()
            }
        }
        if let front = NSWorkspace.shared.frontmostApplication {
            lastActivated[front.processIdentifier] = Date()
        }
    }
    static func listWindows() -> [WindowItem] {
        guard let info = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            return []
        }

        var items: [WindowItem] = []
        var seen = Set<String>()

        for dict in info {
            guard let layer = dict[kCGWindowLayer as String] as? Int, layer == 0 else { continue }
            guard let ownerPID = dict[kCGWindowOwnerPID as String] as? Int32 else { continue }
            let ownerName = dict[kCGWindowOwnerName as String] as? String ?? "Unknown"
            let title = dict[kCGWindowName as String] as? String ?? ""
            let windowNumber = dict[kCGWindowNumber as String] as? Int

            if ownerPID == ProcessInfo.processInfo.processIdentifier { continue }
            if title.isEmpty && ownerName.isEmpty { continue }

            let app = NSRunningApplication(processIdentifier: ownerPID)
            if app?.activationPolicy == .prohibited { continue }

            let id = "\(ownerPID)-\(windowNumber ?? 0)-\(title)"
            if seen.contains(id) { continue }
            seen.insert(id)

            items.append(WindowItem(
                id: id,
                pid: ownerPID,
                appName: ownerName,
                title: title.isEmpty ? ownerName : title,
                icon: app?.icon,
                windowNumber: windowNumber
            ))
        }

        items.sort { (a, b) in
            let ta = lastActivated[a.pid] ?? .distantPast
            let tb = lastActivated[b.pid] ?? .distantPast
            if ta != tb { return ta > tb }
            return (a.appName, a.title) < (b.appName, b.title)
        }
        return items
    }

    static func focus(item: WindowItem) {
        guard let app = NSRunningApplication(processIdentifier: item.pid) else { return }
        app.activate()
    }
}
