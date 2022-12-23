import Cocoa
import FlutterMacOS
import workmanager

WorkmanagerPlugin.registerTask(withIdentifier: "pesta-workmanager")

@NSApplicationMain
class AppDelegate: FlutterAppDelegate {
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }
}
