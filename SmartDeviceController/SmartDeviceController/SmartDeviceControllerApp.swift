import SwiftUI

@main
struct SmartDeviceControllerApp: App {
    // Fix: Initialize MQTTBroker.shared at app launch to avoid multiple instances
    private let mqttBroker = MQTTBroker.shared
    
    // Use AppDelegate to ensure connection happens at the right time in the app lifecycle
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            DeviceGridView()
        }
    }
}

// App Delegate to handle connection at app launch
class AppDelegate: NSObject, UIApplicationDelegate {
    
    // Fix: Using a private property that references the shared instance
    private let mqttBroker = MQTTBroker.shared
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Connect to MQTT right at app launch
        print("App launched - connecting to MQTT broker")
        mqttBroker.autoConnect()
        return true
    }
    
    // Handle app moving to foreground
    func applicationWillEnterForeground(_ application: UIApplication) {
        // Try to reconnect when app comes back to foreground
        if !mqttBroker.isConnected {
            print("App entering foreground - reconnecting to MQTT broker")
            mqttBroker.autoConnect()
        }
    }
    
    // Fix: Handle app going to background and potentially disconnecting
    func applicationDidEnterBackground(_ application: UIApplication) {
        // Can optionally disconnect here to save battery
        // mqttBroker.disconnect()
    }
}
