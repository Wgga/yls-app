import AppKit

@main
struct YLSStatusBarMain {
    static func main() {
        let app = NSApplication.shared
        let delegate = CodexMonitorBootstrap.makeAppDelegate()
        app.delegate = delegate
        app.run()
    }
}
