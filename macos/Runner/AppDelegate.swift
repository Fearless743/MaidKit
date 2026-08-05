import Cocoa
import FlutterMacOS
import ServiceManagement

@main
class AppDelegate: FlutterAppDelegate {
  private static let serialBridgeChannel = "dev.solsynth.maidKit/serial_bridge"
  private static let serialBridgePlist = "dev.solsynth.maidKit.serial-bridge.plist"

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  override func applicationDidFinishLaunching(_ notification: Notification) {
    super.applicationDidFinishLaunching(notification)
    guard let controller = mainFlutterWindow?.contentViewController as? FlutterViewController else {
      return
    }
    let channel = FlutterMethodChannel(
      name: Self.serialBridgeChannel,
      binaryMessenger: controller.engine.binaryMessenger)
    channel.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "ensureRegistered":
        self?.ensureSerialBridgeRegistered(result: result)
      case "openLoginItemsSettings":
        self?.openLoginItemsSettings(result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  /// Registers the serial-bridge LaunchAgent with Service Management and
  /// reports its status. Registration can only be initiated from the main
  /// app; the agent itself runs unsandboxed because the main app is
  /// sandboxed and cannot open serial devices.
  private func ensureSerialBridgeRegistered(result: @escaping FlutterResult) {
    guard #available(macOS 13.0, *) else {
      result("unsupported")
      return
    }
    let service = SMAppService.agent(plistName: Self.serialBridgePlist)
    if service.status == .notRegistered || service.status == .notFound {
      do {
        try service.register()
      } catch {
        result("error:\(error.localizedDescription)")
        return
      }
    }
    switch service.status {
    case .enabled:
      result("enabled")
    case .requiresApproval:
      result("requiresApproval")
    case .notRegistered:
      result("notRegistered")
    case .notFound:
      result("notFound")
    @unknown default:
      result("error:unknown status")
    }
  }

  private func openLoginItemsSettings(result: @escaping FlutterResult) {
    guard #available(macOS 13.0, *) else {
      result(FlutterError(
        code: "unsupported",
        message: "Serial ports require macOS 13 or later",
        details: nil))
      return
    }
    SMAppService.openSystemSettingsLoginItems()
    result(nil)
  }
}
