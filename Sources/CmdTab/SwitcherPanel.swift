import AppKit
import SwiftUI
import CoreGraphics

final class SwitcherPanel: NSPanel {
    init(contentView: NSView) {
        super.init(contentRect: NSRect(x: 0, y: 0, width: 520, height: 360),
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered,
                   defer: false)
        self.isFloatingPanel = true
        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.isMovableByWindowBackground = true
        self.backgroundColor = .clear
        self.hasShadow = true
        self.contentView = contentView
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

final class PanelController: NSObject, @unchecked Sendable, NSWindowDelegate {
    let model = SwitcherModel()
    private var panel: SwitcherPanel?
    private var keyMonitor: Any?
    private var eventTap: CFMachPort?
    private var shortcutGesture = ShortcutGesture()
    private var hovering = false
    private var pendingShow: DispatchWorkItem?

    func setup() {
        let hosting = NSHostingView(rootView: SwitcherView(model: model))
        let container = TrackingView(frame: hosting.frame)
        container.addSubview(hosting)
        hosting.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hosting.topAnchor.constraint(equalTo: container.topAnchor),
            hosting.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            hosting.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            hosting.trailingAnchor.constraint(equalTo: container.trailingAnchor),
        ])
        let p = SwitcherPanel(contentView: container)
        container.controller = self
        panel = p
        p.delegate = self
        centerPanel(p)

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.model.isVisible else { return event }
            switch event.keyCode {
            case 123: // left
                self.model.moveSelection(-1); return nil
            case 124: // right
                self.model.moveSelection(1); return nil
            case 125: // down
                self.model.moveSelection(1); return nil
            case 126: // up
                self.model.moveSelection(-1); return nil
            case 36: // return
                self.hidePanel(); self.model.confirm(); return nil
            case 53: // escape
                self.model.hide(); self.hidePanel(); return nil
            default:
                return event
            }
        }

        installEventTap()

        NSEvent.addGlobalMonitorForEvents(matching: [.flagsChanged]) { [weak self] event in
            guard let self else { return }
            if !event.modifierFlags.contains(.command) {
                self.finishShortcut()
            }
        }
    }

    private func installEventTap() {
        let mask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue) | (1 << CGEventType.flagsChanged.rawValue)
        guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap,
                                          place: .headInsertEventTap,
                                          options: .defaultTap,
                                          eventsOfInterest: CGEventMask(mask),
                                          callback: { proxy, type, event, refcon in
            let ctrl = Unmanaged<PanelController>.fromOpaque(refcon!).takeUnretainedValue()
            return ctrl.handleEvent(proxy: proxy, type: type, event: event)
        }, userInfo: Unmanaged.passUnretained(self).toOpaque()) else {
            return
        }
        eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    func toggle() {
        if model.isVisible {
            model.hide()
            hidePanel()
        } else {
            show()
        }
    }

    func show() {
        pendingShow?.cancel()
        pendingShow = nil
        model.refresh()
        model.isVisible = true
        model.selectedIndex = (model.items.count > 1) ? 1 : 0
        hovering = false
        if let p = panel {
            restorePosition(p)
            p.makeKeyAndOrderFront(nil)
        }
    }

    func mouseEntered() {
        hovering = true
    }

    func mouseExited() {
        hovering = false
    }


    nonisolated func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags

        if type == .keyDown && keyCode == 48 && flags.contains(.maskCommand) {
            shortcutGesture.tabPressed(commandHeld: true)
            if !model.isVisible {
                if pendingShow == nil {
                    let work = DispatchWorkItem { [weak self] in
                        self?.show()
                    }
                    pendingShow = work
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: work)
                }
            } else {
                model.moveSelection(1)
            }
            return nil
        }

        if type == .flagsChanged {
            let cmdDown = flags.contains(.maskCommand)
            if !cmdDown {
                finishShortcut()
            }
        }

        return Unmanaged.passUnretained(event)
    }

    func cancel() {
        model.hide()
        hidePanel()
    }

    func hidePanel() {
        shortcutGesture.cancel()
        panel?.orderOut(nil)
    }

    private func finishShortcut() {
        guard shortcutGesture.commandReleased() else { return }
        if model.isVisible {
            hidePanel()
            model.confirm()
        } else {
            pendingShow?.cancel()
            pendingShow = nil
            model.refresh()
            if model.items.count > 1 {
                WindowEnumerator.focus(item: model.items[1])
            } else if let first = model.items.first {
                WindowEnumerator.focus(item: first)
            }
        }
    }

    func windowDidMove(_ notification: Notification) {
        if let p = panel {
            UserDefaults.standard.set(NSStringFromPoint(p.frame.origin), forKey: "CmdTabPanelOrigin")
        }
    }

    private func restorePosition(_ p: NSPanel) {
        if let s = UserDefaults.standard.string(forKey: "CmdTabPanelOrigin") {
            let pt = NSPointFromString(s)
            if pt != .zero { p.setFrameOrigin(pt); return }
        }
        centerPanel(p)
    }

    private func centerPanel(_ p: NSPanel) {
        if let screen = NSScreen.main {
            let sf = screen.visibleFrame
            let pf = p.frame
            let x = sf.midX - pf.width / 2
            let y = sf.midY - pf.height / 2
            p.setFrameOrigin(NSPoint(x: x, y: y))
        }
    }
}


final class TrackingView: NSView {
    weak var controller: PanelController?
    private var trackingArea: NSTrackingArea?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let ta = trackingArea { removeTrackingArea(ta) }
        let ta = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self, userInfo: nil)
        addTrackingArea(ta)
        trackingArea = ta
    }

    override func mouseEntered(with event: NSEvent) {
        controller?.mouseEntered()
    }
    override func mouseExited(with event: NSEvent) {
        controller?.mouseExited()
    }
}
