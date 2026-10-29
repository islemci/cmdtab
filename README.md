# CmdTab

A native macOS window switcher inspired by Windows Alt+Tab, built with SwiftUI.
Press **Option+Tab** (or use the menu-bar icon) to open the switcher, then use
arrow keys to navigate and Return to focus a window. Escape dismisses it.

## Open in Xcode

Open `CmdTab.xcodeproj` in Xcode and run the **CmdTab** scheme.

The project targets macOS 14 and later. You can also build from the command
line with:

```sh
xcodebuild -project CmdTab.xcodeproj -scheme CmdTab -configuration Debug build
```

For a quick Swift package build, run `swift build`.

## Notes

- Uses `CGWindowListCopyWindowInfo` to enumerate on-screen windows and the
  Accessibility API (when permitted) to raise a specific window.
- Runs as a menu-bar (accessory) app.
