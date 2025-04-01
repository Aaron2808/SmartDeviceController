import UIKit
import UserNotifications

// This class handles notification setup and responses
class NotificationHandler: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationHandler()
    
    func setupNotifications() {
        // Request permission with options specifically for background processing
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound, .badge, .providesAppNotificationSettings]
        ) { granted, error in
            if granted {
                print("Notification permission granted")
            } else if let error = error {
                print("Notification permission denied: \(error.localizedDescription)")
            }
        }
        
        // Set this class as the delegate
        UNUserNotificationCenter.current().delegate = self
    }
    
    // This method is called when a notification is received while the app is in the foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Extract the timer ID
        let userInfo = notification.request.content.userInfo
        if let timerId = userInfo["timerId"] as? String {
            // Find the timer action and execute it
            let timerManager = TimerControlManager.shared
            if let timer = timerManager.timerActions.first(where: { $0.id == timerId }) {
                // Process the timer action
                timerManager.executeTimerAction(timer)
                
                // Still show the notification to the user
                completionHandler([.banner, .sound])
            } else {
                // If timer not found, still show notification
                completionHandler([.banner, .sound])
            }
        } else {
            // For other notifications, just show them
            completionHandler([.banner, .sound])
        }
    }
    
    // This method is called when the user taps on a notification
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        // Extract the timer ID
        let userInfo = response.notification.request.content.userInfo
        
        // Handle different notification actions
        switch response.actionIdentifier {
        case "EXECUTE_TIMER":
            // User tapped "Execute Now" button
            if let timerId = userInfo["timerId"] as? String {
                executeTimerWithBackground(timerId: timerId)
            }
            
        case "DELETE_TIMER":
            // User tapped "Delete Timer" button
            if let timerId = userInfo["timerId"] as? String {
                TimerControlManager.shared.removeTimerAction(id: timerId)
            }
            
        case UNNotificationDefaultActionIdentifier:
            // User tapped the notification itself
            if let timerId = userInfo["timerId"] as? String {
                executeTimerWithBackground(timerId: timerId)
            }
            
        default:
            break
        }
        
        // Complete the handling
        completionHandler()
    }
    
    // Helper method to execute timer action with background processing
    private func executeTimerWithBackground(timerId: String) {
        // Fixed: Define taskID variable before using it in closure
        var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
        
        // Request unlimited background time for MQTT operations
        backgroundTaskID = UIApplication.shared.beginBackgroundTask {
            // End the task if time expires
            UIApplication.shared.endBackgroundTask(backgroundTaskID)
        }
        
        // Find and execute the timer action
        DispatchQueue.global(qos: .userInitiated).async {
            let timerManager = TimerControlManager.shared
            if let timer = timerManager.timerActions.first(where: { $0.id == timerId }) {
                timerManager.executeTimerAction(timer)
                
                // Make sure MQTT broker is connected
                let mqttBroker = MQTTBroker.shared
                if !mqttBroker.isConnected {
                    mqttBroker.connect()
                    
                    // Wait a moment for connection
                    Thread.sleep(forTimeInterval: 1.0)
                    
                    // Try executing again
                    timerManager.executeTimerAction(timer)
                }
            }
            
            // End the background task
            UIApplication.shared.endBackgroundTask(backgroundTaskID)
        }
    }
    
    // Setup notification categories for action buttons
    func setupNotificationCategories() {
        // Create actions
        let executeAction = UNNotificationAction(
            identifier: "EXECUTE_TIMER",
            title: "Execute Now",
            options: [.foreground]
        )
        
        let deleteAction = UNNotificationAction(
            identifier: "DELETE_TIMER",
            title: "Delete Timer",
            options: [.destructive]
        )
        
        // Create category with actions
        let timerCategory = UNNotificationCategory(
            identifier: "TIMER_CATEGORY",
            actions: [executeAction, deleteAction],
            intentIdentifiers: [],
            options: []
        )
        
        // Register the category
        UNUserNotificationCenter.current().setNotificationCategories([timerCategory])
    }
}
