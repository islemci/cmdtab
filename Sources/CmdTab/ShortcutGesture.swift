struct ShortcutGesture {
    private(set) var isActive = false

    mutating func tabPressed(commandHeld: Bool) {
        guard commandHeld else { return }
        isActive = true
    }

    mutating func commandReleased() -> Bool {
        defer { isActive = false }
        return isActive
    }

    mutating func cancel() {
        isActive = false
    }
}
