import SwiftUI
import UserNotifications

struct TimerAction: Codable, Identifiable, Equatable {
    let id: String
    let deviceId: Int
    let controlId: Int
    let timerType: TimerType
    let scheduledTime: Date
    let scheduledDuration: TimeInterval?
    let actionValue: String
    let isRepeating: Bool
    
    // Add notification identifier for background notifications
    let notificationId: String
    
    enum TimerType: String, Codable {
        case turnOff = "Turn Off"
        case turnOn = "Turn On"
        case setValue = "Set Value"
        case toggle = "Toggle"
    }
    
    static func == (lhs: TimerAction, rhs: TimerAction) -> Bool {
        return lhs.id == rhs.id
    }
}

import SwiftUI
import UserNotifications
import os.log
import BackgroundTasks

class TimerControlManager: ObservableObject {
    // MARK: - Shared Instance
    
    static let shared = TimerControlManager()
    
    // MARK: - Published Properties
    
    @Published var timerActions: [TimerAction] = []
    
    // MARK: - Private Properties
    
    private var activeTimers: [String: Timer] = [:]
    private let logger = Logger(subsystem: "com.aaronflynn.SmartDeviceController", category: "TimerControl")
    
    // MARK: - Initialization
    
    init() {
        // Load saved timer actions
        loadTimerActions()
        
        // Start any scheduled timers that should be running
        activateScheduledTimers()
        
        // Request notification permission
        requestNotificationPermission()
        
        // Set up notification handling
        setupNotificationHandling()
    }
    
    // MARK: - Public Methods
    
    /// Add a new timer action
    /// - Parameters:
    ///   - deviceId: The device ID
    ///   - controlId: The control ID
    ///   - timerType: The timer type
    ///   - scheduledTime: The scheduled time
    ///   - scheduledDuration: Optional duration for the timer
    ///   - actionValue: The action value
    ///   - isRepeating: Whether the timer repeats
    func addTimerAction(
        deviceId: Int,
        controlId: Int,
        timerType: TimerAction.TimerType,
        scheduledTime: Date,
        scheduledDuration: TimeInterval? = nil,
        actionValue: String,
        isRepeating: Bool = false
    ) {
        // Generate unique IDs for both the timer and its notification
        let timerId = UUID().uuidString
        let notificationId = "timer_notification_\(timerId)"
        
        let action = TimerAction(
            id: timerId,
            deviceId: deviceId,
            controlId: controlId,
            timerType: timerType,
            scheduledTime: scheduledTime,
            scheduledDuration: scheduledDuration,
            actionValue: actionValue,
            isRepeating: isRepeating,
            notificationId: notificationId
        )
        
        timerActions.append(action)
        saveTimerActions()
        
        // Schedule both in-app timer and notification
        scheduleTimer(for: action)
        scheduleNotification(for: action)
        
        logger.info("Added timer action: \(timerType.rawValue) at \(scheduledTime.formatted())")
    }
    
    /// Remove a timer action
    /// - Parameter id: The timer action ID
    func removeTimerAction(id: String) {
        // Find the timer action to get its notification ID
        if let timerAction = timerActions.first(where: { $0.id == id }) {
            // Cancel the notification
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [timerAction.notificationId])
            
            // Cancel the in-app timer if it's active
            if let timer = activeTimers[id] {
                timer.invalidate()
                activeTimers.removeValue(forKey: id)
            }
            
            // Remove from the array
            timerActions.removeAll { $0.id == id }
            saveTimerActions()
            
            logger.info("Removed timer action with ID: \(id)")
        }
    }
    
    /// Get timer actions for a device
    /// - Parameter deviceId: The device ID
    /// - Returns: Array of timer actions for this device
    func getTimerActions(forDevice deviceId: Int) -> [TimerAction] {
        return timerActions.filter { $0.deviceId == deviceId }
    }
    
    /// Get timer actions for a control
    /// - Parameter controlId: The control ID
    /// - Returns: Array of timer actions for this control
    func getTimerActions(forControl controlId: Int) -> [TimerAction] {
        return timerActions.filter { $0.controlId == controlId }
    }
    
    /// Check for and process any timers that need to be executed
    /// This method is called from background processing tasks
    func checkAndProcessDueTimers() {
        logger.info("Background timer check started")
        
        let now = Date()
        var timerIdsToRemove: [String] = []
        
        // Find timers that need to be executed
        for action in timerActions {
            // Check if this timer is due (or overdue)
            if action.scheduledTime <= now {
                logger.info("Background execution of timer: \(action.id)")
                
                // Execute the timer action
                executeTimerAction(action)
                
                // If not repeating, mark for removal
                if !action.isRepeating {
                    timerIdsToRemove.append(action.id)
                }
            }
        }
        
        // Clean up non-repeating timers that have been processed
        for timerId in timerIdsToRemove {
            removeTimerAction(id: timerId)
        }
        
        logger.info("Background timer check completed")
    }
    
    /// Execute a timer action
    /// - Parameter action: The timer action to execute
    func executeTimerAction(_ action: TimerAction) {
        logger.info("Executing timer action: \(action.id), type: \(action.timerType.rawValue)")
        
        // Get all device controls
        let controls = UserDefaultsManager.shared.loadControls(forDevice: action.deviceId)
        
        // Find the specific control
        if let control = controls.first(where: { $0.id == action.controlId }) {
            // Ensure MQTT broker is connected
            if !MQTTBroker.shared.isConnected {
                MQTTBroker.shared.connect()
                // Small delay to allow connection
                Thread.sleep(forTimeInterval: 0.5)
            }
            
            // Execute the action based on the timer type
            switch action.timerType {
            case .turnOn:
                let onMessage = ToggleUtils.getToggleOnMessage(from: control.message)
                MQTTBroker.shared.publish(topic: control.topic, message: onMessage)
                
            case .turnOff:
                let offMessage = ToggleUtils.getToggleOffMessage(from: control.message)
                MQTTBroker.shared.publish(topic: control.topic, message: offMessage)
                
            case .toggle:
                // For toggle, we need to check the current state
                if let currentValue = MQTTBroker.shared.getValue(topic: control.topic) {
                    if let boolValue = currentValue.asBool() {
                        // Send the opposite
                        let onOffConfig = ToggleUtils.getToggleMessages(from: control.message)
                        let messageToSend = boolValue ? onOffConfig.offMessage : onOffConfig.onMessage
                        MQTTBroker.shared.publish(topic: control.topic, message: messageToSend)
                    }
                } else {
                    // Default to sending the on message
                    let onMessage = ToggleUtils.getToggleOnMessage(from: control.message)
                    MQTTBroker.shared.publish(topic: control.topic, message: onMessage)
                }
                
            case .setValue:
                // Set a specific value (for sliders)
                MQTTBroker.shared.publish(topic: control.topic, message: action.actionValue)
            }
        } else {
            logger.error("Failed to find control with ID: \(action.controlId)")
        }
        
        // If this is a repeating timer, reschedule it
        if action.isRepeating {
            rescheduleRepeatingTimer(action)
        } else {
            // Remove the timer from active timers
            activeTimers.removeValue(forKey: action.id)
        }
    }
    
    // MARK: - Private Methods
    
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                self.logger.info("Notification permission granted")
            } else if let error = error {
                self.logger.error("Notification permission denied: \(error.localizedDescription)")
            }
        }
    }
    
    private func setupNotificationHandling() {
        // Listen for notifications when app is in foreground
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleForegroundNotification),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }
    
    @objc private func handleForegroundNotification() {
        // Check for any delivered notifications
        UNUserNotificationCenter.current().getDeliveredNotifications { notifications in
            for notification in notifications {
                let userInfo = notification.request.content.userInfo
                if let timerId = userInfo["timerId"] as? String,
                   let timer = self.timerActions.first(where: { $0.id == timerId }) {
                    self.executeTimerAction(timer)
                }
            }
            
            // Remove delivered notifications
            if !notifications.isEmpty {
                let identifiers = notifications.map { $0.request.identifier }
                UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: identifiers)
            }
        }
    }
    
    private func activateScheduledTimers() {
        for action in timerActions {
            // Only schedule in-app timers for future times
            if action.scheduledTime > Date() {
                scheduleTimer(for: action)
            }
            
            // Always schedule or reschedule notifications (they handle repeating better)
            scheduleNotification(for: action)
        }
    }
    
    private func scheduleTimer(for action: TimerAction) {
        // Cancel any existing timer for this action
        if let existingTimer = activeTimers[action.id] {
            existingTimer.invalidate()
        }
        
        let timeInterval = action.scheduledTime.timeIntervalSinceNow
        
        // Only schedule if the time is in the future
        if timeInterval > 0 {
            let timer = Timer.scheduledTimer(withTimeInterval: timeInterval, repeats: false) { [weak self] _ in
                self?.executeTimerAction(action)
            }
            
            activeTimers[action.id] = timer
            RunLoop.main.add(timer, forMode: .common)
            
            logger.debug("Scheduled timer \(action.id) to execute in \(timeInterval) seconds")
        } else if action.isRepeating {
            // For repeating timers that have passed, schedule for next occurrence
            rescheduleRepeatingTimer(action)
        }
    }
    
    private func rescheduleRepeatingTimer(_ action: TimerAction) {
        // Create next occurrence for repeating timers
        let nextOccurrence = createNextOccurrence(for: action)
        
        // Create a new notification ID for the rescheduled timer to avoid conflicts
        let newNotificationId = "timer_notification_\(action.id)_\(Date().timeIntervalSince1970)"
        
        let updatedAction = TimerAction(
            id: action.id,
            deviceId: action.deviceId,
            controlId: action.controlId,
            timerType: action.timerType,
            scheduledTime: nextOccurrence,
            scheduledDuration: action.scheduledDuration,
            actionValue: action.actionValue,
            isRepeating: action.isRepeating,
            notificationId: newNotificationId
        )
        
        // Update the action in the array
        if let index = timerActions.firstIndex(where: { $0.id == action.id }) {
            timerActions[index] = updatedAction
            saveTimerActions()
        }
        
        // Schedule the updated timer
        scheduleTimer(for: updatedAction)
        scheduleNotification(for: updatedAction)
        
        logger.info("Rescheduled repeating timer \(action.id) for \(nextOccurrence.formatted())")
    }
    
    private func scheduleNotification(for action: TimerAction) {
        // Remove any existing notification with this ID
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [action.notificationId])
        
        // Create a notification content
        let content = UNMutableNotificationContent()
        content.title = "Timer: \(getNotificationTitle(for: action))"
        content.body = getNotificationBody(for: action)
        content.sound = UNNotificationSound.default
        
        // Set category for action buttons
        content.categoryIdentifier = "TIMER_CATEGORY"
        
        // Add the timer action ID to the notification
        content.userInfo = [
            "timerNotificationId": action.notificationId,
            "timerId": action.id,
            "deviceId": action.deviceId,
            "controlId": action.controlId
        ]
        
        // Request a background fetch when notification is delivered
        content.targetContentIdentifier = "timerExecution"
        
        // Create a calendar-based trigger
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: action.scheduledTime)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        
        // Create the request
        let request = UNNotificationRequest(identifier: action.notificationId, content: content, trigger: trigger)
        
        // Add the notification request
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                self.logger.error("Failed to schedule notification: \(error.localizedDescription)")
            } else {
                self.logger.debug("Scheduled notification for timer \(action.id)")
            }
        }
    }
    
    private func getNotificationTitle(for action: TimerAction) -> String {
        // Get the control name for better user experience
        let controlName = getControlName(action.controlId)
        
        switch action.timerType {
        case .turnOn:
            return "Turn On: \(controlName)"
        case .turnOff:
            return "Turn Off: \(controlName)"
        case .toggle:
            return "Toggle: \(controlName)"
        case .setValue:
            return "Set \(controlName) to \(action.actionValue)"
        }
    }
    
    private func getControlName(_ controlId: Int) -> String {
        // Find the control to get its name
        let controls = UserDefaultsManager.shared.getAllControlsFlat()
        if let control = controls.first(where: { $0.id == controlId }) {
            return control.displayName
        }
        return "Control \(controlId)"
    }
    
    private func getNotificationBody(for action: TimerAction) -> String {
        // Get the device name for additional context
        let deviceName = getDeviceName(action.deviceId)
        return "Scheduled timer for \(deviceName) has triggered."
    }
    
    private func getDeviceName(_ deviceId: Int) -> String {
        if let device = DeviceManager.shared.getDevice(withId: deviceId) {
            return device.name
        }
        return "Device \(deviceId)"
    }
    
    private func createNextOccurrence(for action: TimerAction) -> Date {
        // Get the time components of the original scheduled time
        let calendar = Calendar.current
        let originalComponents = calendar.dateComponents([.hour, .minute, .second], from: action.scheduledTime)
        
        // Create a date for today with the same time components
        var dateComponents = calendar.dateComponents([.year, .month, .day], from: Date())
        dateComponents.hour = originalComponents.hour
        dateComponents.minute = originalComponents.minute
        dateComponents.second = originalComponents.second
        
        if let todayWithOriginalTime = calendar.date(from: dateComponents) {
            // If the time has already passed today, schedule for tomorrow
            if todayWithOriginalTime <= Date() {
                return calendar.date(byAdding: .day, value: 1, to: todayWithOriginalTime) ?? Date().addingTimeInterval(24 * 60 * 60)
            } else {
                return todayWithOriginalTime
            }
        }
        
        // Fallback: just add 24 hours from now
        return Date().addingTimeInterval(24 * 60 * 60)
    }
    
    // MARK: - Persistence
    
    private func saveTimerActions() {
        UserDefaultsManager.shared.saveTimerActions(timerActions)
    }
    
    private func loadTimerActions() {
        timerActions = UserDefaultsManager.shared.loadTimerActions()
    }
}
