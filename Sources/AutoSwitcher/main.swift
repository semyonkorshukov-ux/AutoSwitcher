import AppKit

let app = NSApplication.shared
app.delegate = sharedAppDelegate
app.setActivationPolicy(.accessory)
app.run()
