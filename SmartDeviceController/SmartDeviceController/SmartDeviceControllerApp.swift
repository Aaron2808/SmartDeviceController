import SwiftUI

@main
struct SmartDeviceControllerApp: App {
    private let mqttBroker = MQTTBroker.shared
    
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            DeviceGridView()
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    
    private let mqttBroker = MQTTBroker.shared
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        print("App launched - connecting to MQTT broker")
        mqttBroker.autoConnect()
        return true
    }
    
    func applicationWillEnterForeground(_ application: UIApplication) {
        if !mqttBroker.isConnected {
            print("App entering foreground - reconnecting to MQTT broker")
            mqttBroker.autoConnect()
        }
    }
    
}
