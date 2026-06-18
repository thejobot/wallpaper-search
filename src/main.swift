import AppKit

let CACHE = (NSHomeDirectory() as NSString).appendingPathComponent("Library/Caches/WallpaperSearch")

final class PromptDelegate: NSObject, NSApplicationDelegate, NSTextFieldDelegate {
    var window: NSPanel!
    var field: NSTextField!
    var wallToggle: NSButton!

    func applicationDidFinishLaunching(_ n: Notification) {
        // Open the box on whichever screen the mouse is on.
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main!
        let f = screen.frame
        let w: CGFloat = 480, h: CGFloat = 176
        let rect = NSRect(x: f.midX - w/2, y: f.midY - h/2, width: w, height: h)

        window = NSPanel(contentRect: rect,
                         styleMask: [.titled, .closable, .nonactivatingPanel],
                         backing: .buffered, defer: false)
        window.title = "Wallpaper Search"
        window.level = .floating
        window.isFloatingPanel = true
        window.hidesOnDeactivate = false

        let label = NSTextField(labelWithString: "Type a theme. It finds a big image and sets this space's wallpaper:")
        label.frame = NSRect(x: 18, y: 136, width: 444, height: 18)
        label.font = NSFont.systemFont(ofSize: 12)
        label.textColor = .secondaryLabelColor

        field = NSTextField(frame: NSRect(x: 18, y: 92, width: 444, height: 30))
        // Greyed example so the eye lands here and reads "this is where my wallpaper theme goes".
        // It is a placeholder, not real text -- the field starts empty and hitting return on it does nothing.
        field.placeholderString = "example wallpaper"
        field.font = NSFont.systemFont(ofSize: 16)
        field.delegate = self
        field.target = self
        field.action = #selector(go)

        // On by default: append the word "wallpaper" to the search for desktop-shaped results.
        wallToggle = NSButton(checkboxWithTitle: "Add the word \u{201C}wallpaper\u{201D} to the search",
                              target: nil, action: nil)
        wallToggle.frame = NSRect(x: 16, y: 56, width: 444, height: 22)
        wallToggle.state = .on
        wallToggle.font = NSFont.systemFont(ofSize: 12)

        // Built-in command hint: typing this instead of a theme resets every display.
        let hint = NSTextField(labelWithString:
            "Command: type \u{201C}reset all\u{201D} to set every monitor to a solid light blue.")
        hint.frame = NSRect(x: 18, y: 16, width: 444, height: 18)
        hint.font = NSFont.systemFont(ofSize: 11)
        hint.textColor = .tertiaryLabelColor

        window.contentView?.addSubview(label)
        window.contentView?.addSubview(field)
        window.contentView?.addSubview(wallToggle)
        window.contentView?.addSubview(hint)
        window.makeFirstResponder(field)

        // Accessory apps don't always come forward on a plain makeKeyAndOrderFront,
        // which reads as "it won't launch" (no Dock icon, no visible panel). Force it.
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }

    // If the app is re-opened while a stale instance is still alive, re-show the box
    // instead of silently doing nothing.
    func applicationShouldHandleReopen(_ s: NSApplication, hasVisibleWindows: Bool) -> Bool {
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
        window?.orderFrontRegardless()
        return true
    }

    func control(_ c: NSControl, textView: NSTextView, doCommandBy sel: Selector) -> Bool {
        if sel == #selector(NSResponder.cancelOperation(_:)) { NSApp.terminate(nil); return true }
        return false
    }

    @objc func go() {
        let raw = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if raw.isEmpty { NSApp.terminate(nil); return }
        let script = (Bundle.main.resourcePath! as NSString).appendingPathComponent("wallpaper.py")

        // Run the engine fully detached so this box can close immediately.
        // $WP_FLAGS is unquoted so an empty value adds no argument.
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/sh")
        p.arguments = ["-c", "nohup /usr/bin/python3 \"$WP_SCRIPT\" \"$WP_KW\" $WP_FLAGS >/dev/null 2>&1 &"]
        var env = ProcessInfo.processInfo.environment
        env["WP_SCRIPT"] = script
        env["WP_KW"] = raw
        env["WP_FLAGS"] = (wallToggle.state == .on) ? "" : "--no-wallpaper-word"
        p.environment = env
        try? p.run()
        p.waitUntilExit()
        NSApp.terminate(nil)
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let d = PromptDelegate()
app.delegate = d
app.run()
