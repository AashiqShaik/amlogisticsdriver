import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // Register iOS Core Location channels so Flutter's LocationServiceChannel
    // works identically on iOS and Android.
    if let registrar = registrar(forPlugin: "AMLocationManager") {
      AMLocationManager.shared.registerChannels(with: registrar)
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
