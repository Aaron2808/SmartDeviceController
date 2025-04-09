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

    static let shared = TimerControlManager()
    @Published var timerActions: [TimerAction] = []
        
    private var activeTimers: [String: Timer] = [:]
    private let logger = Logger(subsystem: "com.aaronflynn.SmartDeviceController", category: "TimerControl")
        
    init() {
        loadTimerActions()
        
        activateScheduledTimers()
        
        requestNotificationPermission()
        
        setupNotificationHandling()
    }
    
    func addTimerAction(
        deviceId: Int,
        controlId: Int,
        timerType: TimerAction.TimerType,
        scheduledTime: Date,
        scheduledDuration: TimeInterval? = nil,
        actionValue: String,
        isRepeating: Bool = false
    ) {
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
        
        scheduleTimer(for: action)
        scheduleNotification(for: action)
        
        logger.info("Added timer action: \(timerType.rawValue) at \(scheduledTime.formatted())")
    }
    
    
    func removeTimerAction(id: String) {
        if let timerAction = timerActions.first(where: { $0.id == id }) {
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [timerAction.notificationId])
            
            if let timer = activeTimers[id] {
                timer.invalidate()
                activeTimers.removeValue(forKey: id)
            }
            
            timerActions.removeAll { $0.id == id }
            saveTimerActions()
            
            logger.info("Removed timer action with ID: \(id)")
        }
    }
    
    func getTimerActions(forDevice deviceId: Int) -> [TimerAction] {
        return timerActions.filter { $0.deviceId == deviceId }
    }
    
   
    func getTimerActions(forControl controlId: Int) -> [TimerAction] {
        return timerActions.filter { $0.controlId == controlId }
    }
    
   
    func checkAndProcessDueTimers() {
        logger.info("Background timer check started")
        
        let now = Date()
        var timerIdsToRemove: [String] = []
        
        for action in timerActions {
            if action.scheduledTime <= now {
                logger.info("Background execution of timer: \(action.id)")
                
                executeTimerAction(action)
                
                if !action.isRepeating {
                    timerIdsToRemove.append(action.id)
                }
            }
        }
        
        for timerId in timerIdsToRemove {
            removeTimerAction(id: timerId)
        }
        
        logger.info("Background timer check completed")
    }
    
    func executeTimerAction(_ action: TimerAction) {
        logger.info("Executing timer action: \(action.id), type: \(action.timerType.rawValue)")
        
        let controls = UserDefaultsManager.shared.loadControls(forDevice: action.deviceId)
        
        if let control = controls.first(where: { $0.id == action.controlId }) {
            if !MQTTBroker.shared.isConnected {
                MQTTBroker.shared.connect()
                Thread.sleep(forTimeInterval: 0.5)
            }
            
            switch action.timerType {
            case .turnOn:
                let onMessage = ToggleUtils.getToggleOnMessage(from: control.message)
                MQTTBroker.shared.publish(topic: control.topic, message: onMessage)
                
            case .turnOff:
                let offMessage = ToggleUtils.getToggleOffMessage(from: control.message)
                MQTTBroker.shared.publish(topic: control.topic, message: offMessage)
                
            case .toggle:
                if let currentValue = MQTTBroker.shared.getValue(topic: control.topic) {
                    if let boolValue = currentValue.asBool() {
                        let onOffConfig = ToggleUtils.getToggleMessages(from: control.message)
                        let messageToSend = boolValue ? onOffConfig.offMessage : onOffConfig.onMessage
                        MQTTBroker.shared.publish(topic: control.topic, message: messageToSend)
                    }
                } else {
                    let onMessage = ToggleUtils.getToggleOnMessage(from: control.message)
                    MQTTBroker.shared.publish(topic: control.topic, message: onMessage)
                }
                
            case .setValue:
                MQTTBroker.shared.publish(topic: control.topic, message: action.actionValue)
            }
        } else {
            logger.error("Failed to find control with ID: \(action.controlId)")
        }
        
        if action.isRepeating {
            rescheduleRepeatingTimer(action)
        } else {
            activeTimers.removeValue(forKey: action.id)
        }
    }
    
    
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
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleForegroundNotification),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }
    
    @objc private func handleForegroundNotification() {
        UNUserNotificationCenter.current().getDeliveredNotifications { notifications in
            for notification in notifications {
                let userInfo = notification.request.content.userInfo
                if let timerId = userInfo["timerId"] as? String,
                   let timer = self.timerActions.first(where: { $0.id == timerId }) {
                    self.executeTimerAction(timer)
                }
            }
            
            if !notifications.isEmpty {
                let identifiers = notifications.map { $0.request.identifier }
                UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: identifiers)
            }
        }
    }
    
    private func activateScheduledTimers() {
        for action in timerActions {
            if action.scheduledTime > Date() {
                scheduleTimer(for: action)
            }
            
            scheduleNotification(for: action)
        }
    }
    
    private func scheduleTimer(for action: TimerAction) {
        if let existingTimer = activeTimers[action.id] {
            existingTimer.invalidate()
        }
        
        let timeInterval = action.scheduledTime.timeIntervalSinceNow
        
        if timeInterval > 0 {
            let timer = Timer.scheduledTimer(withTimeInterval: timeInterval, repeats: false) { [weak self] _ in
                self?.executeTimerAction(action)
            }
            
            activeTimers[action.id] = timer
            RunLoop.main.add(timer, forMode: .common)
            
            logger.debug("Scheduled timer \(action.id) to execute in \(timeInterval) seconds")
        } else if action.isRepeating {
            rescheduleRepeatingTimer(action)
        }
    }
    
    private func rescheduleRepeatingTimer(_ action: TimerAction) {
        let nextOccurrence = createNextOccurrence(for: action)
        
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
        
        if let index = timerActions.firstIndex(where: { $0.id == action.id }) {
            timerActions[index] = updatedAction
            saveTimerActions()
        }
        
        scheduleTimer(for: updatedAction)
        scheduleNotification(for: updatedAction)
        
        logger.info("Rescheduled repeating timer \(action.id) for \(nextOccurrence.formatted())")
    }
    
    private func scheduleNotification(for action: TimerAction) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [action.notificationId])
        
        let content = UNMutableNotificationContent()
        content.title = "Timer: \(getNotificationTitle(for: action))"
        content.body = getNotificationBody(for: action)
        content.sound = UNNotificationSound.default
        
        content.categoryIdentifier = "TIMER_CATEGORY"
        
        content.userInfo = [
            "timerNotificationId": action.notificationId,
            "timerId": action.id,
            "deviceId": action.deviceId,
            "controlId": action.controlId
        ]
        
        content.targetContentIdentifier = "timerExecution"
        
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: action.scheduledTime)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        
        let request = UNNotificationRequest(identifier: action.notificationId, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                self.logger.error("Failed to schedule notification: \(error.localizedDescription)")
            } else {
                self.logger.debug("Scheduled notification for timer \(action.id)")
            }
        }
    }
    
    private func getNotificationTitle(for action: TimerAction) -> String {
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
        let controls = UserDefaultsManager.shared.getAllControlsFlat()
        if let control = controls.first(where: { $0.id == controlId }) {
            return control.displayName
        }
        return "Control \(controlId)"
    }
    
    private func getNotificationBody(for action: TimerAction) -> String {
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
        let calendar = Calendar.current
        let originalComponents = calendar.dateComponents([.hour, .minute, .second], from: action.scheduledTime)
        
        var dateComponents = calendar.dateComponents([.year, .month, .day], from: Date())
        dateComponents.hour = originalComponents.hour
        dateComponents.minute = originalComponents.minute
        dateComponents.second = originalComponents.second
        
        if let todayWithOriginalTime = calendar.date(from: dateComponents) {
            if todayWithOriginalTime <= Date() {
                return calendar.date(byAdding: .day, value: 1, to: todayWithOriginalTime) ?? Date().addingTimeInterval(24 * 60 * 60)
            } else {
                return todayWithOriginalTime
            }
        }
        
        return Date().addingTimeInterval(24 * 60 * 60)
    }
    
    private func saveTimerActions() {
        UserDefaultsManager.shared.saveTimerActions(timerActions)
    }
    
    private func loadTimerActions() {
        timerActions = UserDefaultsManager.shared.loadTimerActions()
    }
}
