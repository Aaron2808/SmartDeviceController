import SwiftUI
import UserNotifications
import BackgroundTasks

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
        
       
        setupNotifications()
        
        registerBackgroundTasks()
        
        application.registerForRemoteNotifications()
        
        scheduleBackgroundTimerProcessing()
        
        return true
    }
    
    func applicationWillEnterForeground(_ application: UIApplication) {
        if !mqttBroker.isConnected {
            print("App entering foreground - reconnecting to MQTT broker")
            mqttBroker.autoConnect()
        }
    }
    
    func setupNotifications() {
        NotificationHandler.shared.setupNotifications()
        NotificationHandler.shared.setupNotificationCategories()
    }
    
    func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.aaronflynn.SmartDeviceController.timerProcessing", using: nil) { task in
            self.handleTimerBackgroundTask(task: task as! BGProcessingTask)
        }
    }
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    }
    
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        if let timerId = userInfo["timerId"] as? String {
            handleBackgroundTimer(timerId: timerId)
            completionHandler(.newData)
        } else {
            completionHandler(.noData)
        }
    }
    
    private func handleBackgroundTimer(timerId: String) {
        let timerManager = TimerControlManager.shared
        if let timer = timerManager.timerActions.first(where: { $0.id == timerId }) {
            timerManager.executeTimerAction(timer)
        }
    }
    
    private func handleTimerBackgroundTask(task: BGProcessingTask) {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        
        let operation = BlockOperation {
            let timerManager = TimerControlManager.shared
            timerManager.checkAndProcessDueTimers()
        }
        
        operation.completionBlock = {
            task.setTaskCompleted(success: !operation.isCancelled)
        }
        
        task.expirationHandler = {
            queue.cancelAllOperations()
        }
        
        queue.addOperation(operation)
        
        scheduleBackgroundTimerProcessing()
    }
    
    func scheduleBackgroundTimerProcessing() {
        let request = BGProcessingTaskRequest(identifier: "com.aaronflynn.SmartDeviceController.timerProcessing")
        request.earliestBeginDate = Date(timeIntervalSinceNow: 60)
        request.requiresNetworkConnectivity = true 
        
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("Could not schedule background task: \(error)")
        }
    }
}
