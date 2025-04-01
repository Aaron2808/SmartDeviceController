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
        
        // Set up notifications
        setupNotifications()
        
        // Register for background tasks
        registerBackgroundTasks()
        
        // Register for remote notifications (needed for background processing)
        application.registerForRemoteNotifications()
        
        // Schedule initial background processing
        scheduleBackgroundTimerProcessing()
        
        return true
    }
    
    func applicationWillEnterForeground(_ application: UIApplication) {
        if !mqttBroker.isConnected {
            print("App entering foreground - reconnecting to MQTT broker")
            mqttBroker.autoConnect()
        }
    }
    
    // Set up notifications
    func setupNotifications() {
        // Set up basic notifications
        NotificationHandler.shared.setupNotifications()
        
        // Set up notification categories for action buttons
        NotificationHandler.shared.setupNotificationCategories()
    }
    
    // Register for background processing
    func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.aaronflynn.SmartDeviceController.timerProcessing", using: nil) { task in
            self.handleTimerBackgroundTask(task: task as! BGProcessingTask)
        }
    }
    
    // Set up to receive remote notifications
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        // This is just to register for notifications - we don't need to do anything with the token
    }
    
    // This is called when a notification arrives while the app is in the background
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        // Process the timer if there's a timer ID
        if let timerId = userInfo["timerId"] as? String {
            handleBackgroundTimer(timerId: timerId)
            completionHandler(.newData)
        } else {
            completionHandler(.noData)
        }
    }
    
    // Handle timer actions in the background
    private func handleBackgroundTimer(timerId: String) {
        let timerManager = TimerControlManager.shared
        if let timer = timerManager.timerActions.first(where: { $0.id == timerId }) {
            timerManager.executeTimerAction(timer)
        }
    }
    
    // Handle background processing task
    private func handleTimerBackgroundTask(task: BGProcessingTask) {
        // Create a task to check for pending timers
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        
        let operation = BlockOperation {
            let timerManager = TimerControlManager.shared
            // Process any timers that need to be triggered
            timerManager.checkAndProcessDueTimers()
        }
        
        // Set up completion handler
        operation.completionBlock = {
            task.setTaskCompleted(success: !operation.isCancelled)
        }
        
        // Set up expiration handler
        task.expirationHandler = {
            queue.cancelAllOperations()
        }
        
        // Start the operation
        queue.addOperation(operation)
        
        // Schedule the next background task
        scheduleBackgroundTimerProcessing()
    }
    
    // Schedule background processing
    func scheduleBackgroundTimerProcessing() {
        let request = BGProcessingTaskRequest(identifier: "com.aaronflynn.SmartDeviceController.timerProcessing")
        request.earliestBeginDate = Date(timeIntervalSinceNow: 60) // Check every minute
        request.requiresNetworkConnectivity = true // MQTT requires network
        
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("Could not schedule background task: \(error)")
        }
    }
}
