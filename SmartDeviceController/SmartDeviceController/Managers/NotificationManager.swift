import UIKit
import UserNotifications

class NotificationHandler: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationHandler()
    
    func setupNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound, .badge, .providesAppNotificationSettings]
        ) { granted, error in
            if granted {
                print("Notification permission granted")
            } else if let error = error {
                print("Notification permission denied: \(error.localizedDescription)")
            }
        }
        
        UNUserNotificationCenter.current().delegate = self
    }
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let userInfo = notification.request.content.userInfo
        if let timerId = userInfo["timerId"] as? String {
            let timerManager = TimerControlManager.shared
            if let timer = timerManager.timerActions.first(where: { $0.id == timerId }) {
                timerManager.executeTimerAction(timer)
                
                completionHandler([.banner, .sound])
            } else {
                completionHandler([.banner, .sound])
            }
        } else {
            completionHandler([.banner, .sound])
        }
    }
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        
        switch response.actionIdentifier {
        case "EXECUTE_TIMER":
            if let timerId = userInfo["timerId"] as? String {
                executeTimerWithBackground(timerId: timerId)
            }
            
        case "DELETE_TIMER":
            if let timerId = userInfo["timerId"] as? String {
                TimerControlManager.shared.removeTimerAction(id: timerId)
            }
            
        case UNNotificationDefaultActionIdentifier:
            if let timerId = userInfo["timerId"] as? String {
                executeTimerWithBackground(timerId: timerId)
            }
            
        default:
            break
        }
        
        completionHandler()
    }
    
    private func executeTimerWithBackground(timerId: String) {
        var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
        
        backgroundTaskID = UIApplication.shared.beginBackgroundTask {
            UIApplication.shared.endBackgroundTask(backgroundTaskID)
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            let timerManager = TimerControlManager.shared
            if let timer = timerManager.timerActions.first(where: { $0.id == timerId }) {
                timerManager.executeTimerAction(timer)
                
                let mqttBroker = MQTTBroker.shared
                if !mqttBroker.isConnected {
                    mqttBroker.connect()
                    
                    Thread.sleep(forTimeInterval: 1.0)
                    
                    timerManager.executeTimerAction(timer)
                }
            }
            
            UIApplication.shared.endBackgroundTask(backgroundTaskID)
        }
    }
    
    func setupNotificationCategories() {
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
        
        let timerCategory = UNNotificationCategory(
            identifier: "TIMER_CATEGORY",
            actions: [executeAction, deleteAction],
            intentIdentifiers: [],
            options: []
        )
        
        UNUserNotificationCenter.current().setNotificationCategories([timerCategory])
    }
}
