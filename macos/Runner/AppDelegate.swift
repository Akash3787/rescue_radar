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
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication!) -> Bool {
    return true
  }

  // ✅ ADD THIS METHOD (Single Window Fix)
  override func applicationShouldHandleReopen(_ application: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
    if !flag {
      // Focus existing window instead of creating new one
      for window in application.windows {
        window.makeKeyAndOrderFront(self)
      }
    }
    return true
  }
}
