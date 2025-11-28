// import Cocoa
// import FlutterMacOS
//
// @main
// class AppDelegate: FlutterAppDelegate {
//   override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
//     return true
//   }
//
//   override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
//     return true
//   }
// }
import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {

  override func applicationDidFinishLaunching(_ notification: Notification) {
    super.applicationDidFinishLaunching(notification)

    // Set window size and center it
    if let window = mainFlutterWindow {
        window.setContentSize(NSSize(width: 1200, height: 800)) // Set your preferred size
        window.center() // Optional: centers the window on screen
        window.makeKeyAndOrderFront(nil)
    }
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return false
  }

  override func applicationShouldHandleReopen(_ application: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
    if !flag {
      for window in application.windows {
        window.makeKeyAndOrderFront(self)
      }
    }
    return true
  }
}