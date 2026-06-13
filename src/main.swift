import AppKit

let CACHE = (NSHomeDirectory() as NSString).appendingPathComponent("Library/Caches/WallpaperSearch")

func lastKeyword() -> String {
    let p = (CACHE as NSString).appendingPathComponent("state.json")
    guard let d = try? Data(contentsOf: URL(fileURLWithPath: p)),
          let j = try? JSONSerialization.jsonObject(with: d) as? [String: Any],
          let k = j["last_keyword"] as? String else { return "" }
    return k
}

final class PromptDelegate: NSObject, NSApplicationDelegate, NSTextFieldDelegate {
    var window: NSPanel!
    var field: NSTextField!

    func applicationDidFinishLaunching(_ n: Notification) {
        // Open the box on whichever screen the mouse is on.
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main!
        let f = screen.frame
        let w: CGFloat = 480, h: CGFloat = 104
        let rect = NSRect(x: f.midX - w/2, y: f.midY - h/2, width: w, height: h)

        window = NSPanel(contentRect: rect,
                         styleMask: [.titled, .closable, .nonactivatingPanel],
                         backing: .buffered, defer: false)
        window.title = "Wallpaper Search"
        window.level = .floating
        window.isFloatingPanel = true
        window.hidesOnDeactivate = false

        let label = NSTextField(labelWithString: "Type a theme. It finds a big image and sets this space's wallpaper:")
        label.frame = NSRect(x: 18, y: 62, width: 444, height: 18)
        label.font = NSFont.systemFont(ofSize: 12)
        label.textColor = .secondaryLabelColor

        field = NSTextField(frame: NSRect(x: 18, y: 20, width: 444, height: 30))
        field.placeholderString = "e.g. the matrix"
        field.font = NSFont.systemFont(ofSize: 16)
        field.delegate = self
        field.target = self
        field.action = #selector(go)
        let prev = lastKeyword()
        if !prev.isEmpty {
            field.stringValue = prev
            field.currentEditor()?.selectAll(nil)
        }

        window.contentView?.addSubview(label)
        window.contentView?.addSubview(field)
        window.makeFirstResponder(field)
        field.selectText(nil)

        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
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
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/sh")
        p.arguments = ["-c", "nohup /usr/bin/python3 \"$WP_SCRIPT\" \"$WP_KW\" >/dev/null 2>&1 &"]
        var env = ProcessInfo.processInfo.environment
        env["WP_SCRIPT"] = script
        env["WP_KW"] = raw
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
