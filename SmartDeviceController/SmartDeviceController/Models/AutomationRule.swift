//
//  AutomationRule.swift
//  SmartDeviceController
//
//  Created by Aaron Flynn on 22/03/2025.
//


import SwiftUI

// Automation Rule Model
struct AutomationRule: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let deviceId: Int
    let isEnabled: Bool
    let condition: RuleCondition
    let action: RuleAction
    
    static func == (lhs: AutomationRule, rhs: AutomationRule) -> Bool {
        return lhs.id == rhs.id
    }
}

// Condition Model
struct RuleCondition: Codable, Equatable {
    let sourceDeviceId: Int
    let dataPointId: String
    let comparator: Comparator
    let value: String
    
    enum Comparator: String, Codable, CaseIterable {
        case greaterThan = ">"
        case lessThan = "<"
        case equalTo = "="
        case notEqualTo = "!="
        
        var displayName: String {
            switch self {
            case .greaterThan: return "is greater than"
            case .lessThan: return "is less than"
            case .equalTo: return "equals"
            case .notEqualTo: return "does not equal"
            }
        }
    }
}

// Action Model
struct RuleAction: Codable, Equatable {
    let targetControlId: Int
    let actionType: ActionType
    let value: String
    
    enum ActionType: String, Codable, CaseIterable {
        case turnOn = "Turn On"
        case turnOff = "Turn Off"
        case setValue = "Set Value"
        case toggle = "Toggle"
        
        var displayName: String {
            return self.rawValue
        }
    }
}

// Manager class for handling automations
import SwiftUI
import os.log

// Manager class for handling automations
class AutomationManager: ObservableObject {
    // MARK: - Shared Instance
    
    static let shared = AutomationManager()
    
    // MARK: - Published Properties
    
    @Published var automationRules: [AutomationRule] = []
    @Published var isProcessingEnabled = true
    
    // MARK: - Private Properties
    
    private var monitoringTimer: Timer?
    private let checkInterval: TimeInterval = 5.0 // Check every 5 seconds
    private let logger = Logger(subsystem: "com.aaronflynn.SmartDeviceController", category: "Automation")
    
    // MARK: - Initialization
    
    init() {
        loadRules()
        startMonitoring()
    }
    
    // MARK: - Public Methods
    
    /// Add a new automation rule
    /// - Parameter rule: The rule to add
    func addRule(_ rule: AutomationRule) {
        automationRules.append(rule)
        saveRules()
    }
    
    /// Update an existing rule's enabled state
    /// - Parameters:
    ///   - id: The rule ID to update
    ///   - isEnabled: The new enabled state
    func updateRule(id: String, isEnabled: Bool) {
        if let index = automationRules.firstIndex(where: { $0.id == id }) {
            let rule = automationRules[index]
            let updatedRule = AutomationRule(
                id: rule.id,
                name: rule.name,
                deviceId: rule.deviceId,
                isEnabled: isEnabled,
                condition: rule.condition,
                action: rule.action
            )
            automationRules[index] = updatedRule
            saveRules()
        }
    }
    
    /// Remove a rule
    /// - Parameter id: The rule ID to remove
    func removeRule(id: String) {
        automationRules.removeAll(where: { $0.id == id })
        saveRules()
    }
    
    /// Get rules for a specific device
    /// - Parameter deviceId: The device ID
    /// - Returns: Array of rules for this device
    func getRules(forDevice deviceId: Int) -> [AutomationRule] {
        return automationRules.filter { $0.deviceId == deviceId }
    }
    
    /// Start monitoring for automation conditions
    func startMonitoring() {
        stopMonitoring() // Ensure no duplicate timers
        
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: checkInterval, repeats: true) { [weak self] _ in
            self?.checkAndProcessRules()
        }
        
        if let timer = monitoringTimer {
            RunLoop.current.add(timer, forMode: .common)
        }
        
        logger.info("Automation monitoring started")
    }
    
    /// Stop monitoring for automation conditions
    func stopMonitoring() {
        monitoringTimer?.invalidate()
        monitoringTimer = nil
        
        logger.info("Automation monitoring stopped")
    }
    
    // MARK: - Private Methods
    
    /// Process all enabled rules
    private func checkAndProcessRules() {
        guard isProcessingEnabled else { return }
        
        for rule in automationRules where rule.isEnabled {
            evaluateRule(rule)
        }
    }
    
    /// Evaluate a single rule condition
    /// - Parameter rule: The rule to evaluate
    private func evaluateRule(_ rule: AutomationRule) {
        let mqttBroker = MQTTBroker.shared
        let condition = rule.condition
        
        // Get the value from the source data point
        if let dataPoint = mqttBroker.getDataPointById(condition.dataPointId),
           let currentValue = mqttBroker.getValue(for: dataPoint) {
            
            // Compare the current value with the condition value
            if compareValues(currentValue: currentValue, condition: condition) {
                // Condition met, execute the action
                logger.info("Rule '\(rule.name)' condition met, executing action")
                executeAction(rule.action)
            }
        }
    }
    
    /// Helper to compare values based on the comparator
    /// - Parameters:
    ///   - currentValue: The current value from the MQTT broker
    ///   - condition: The rule condition
    /// - Returns: True if the condition is met, false otherwise
    private func compareValues(currentValue: MQTTBroker.DataValue, condition: RuleCondition) -> Bool {
        let conditionValue = condition.value
        
        switch currentValue {
        case .number(let numValue):
            if let targetValue = Double(conditionValue) {
                switch condition.comparator {
                case .greaterThan: return numValue > targetValue
                case .lessThan: return numValue < targetValue
                case .equalTo: return abs(numValue - targetValue) < 0.001 // Use epsilon for floating point comparison
                case .notEqualTo: return abs(numValue - targetValue) >= 0.001
                }
            }
            
        case .boolean(let boolValue):
            let targetBool = conditionValue.lowercased() == "true" || conditionValue == "1" || conditionValue.lowercased() == "on"
            switch condition.comparator {
            case .equalTo: return boolValue == targetBool
            case .notEqualTo: return boolValue != targetBool
            default: return false // Greater/less than don't apply to booleans
            }
            
        case .text(let stringValue):
            switch condition.comparator {
            case .equalTo: return stringValue.lowercased() == conditionValue.lowercased() // Case-insensitive comparison
            case .notEqualTo: return stringValue.lowercased() != conditionValue.lowercased()
            default: return false // Greater/less than don't make sense for text
            }
            
        case .jsonObject(let dict):
            // Try to extract a specific property if condition value contains a path
            if conditionValue.contains(".") {
                let parts = conditionValue.split(separator: ".")
                if parts.count == 2 {
                    let key = String(parts[0])
                    let value = String(parts[1])
                    if let propValue = dict[key] {
                        if let numProp = propValue as? NSNumber {
                            return compareValues(currentValue: .number(numProp.doubleValue), condition: condition)
                        } else if let boolProp = propValue as? Bool {
                            return compareValues(currentValue: .boolean(boolProp), condition: condition)
                        } else if let strProp = propValue as? String {
                            return compareValues(currentValue: .text(strProp), condition: condition)
                        }
                    }
                }
            }
            return false
            
        default:
            return false // Other types not supported for comparison
        }
        
        return false
    }
    
    /// Execute the rule action
    /// - Parameter action: The action to execute
    private func executeAction(_ action: RuleAction) {
        // Find the control to act on
        let controls = UserDefaultsManager.shared.getAllControlsFlat()
        
        if let control = controls.first(where: { $0.id == action.targetControlId }) {
            let mqttBroker = MQTTBroker.shared
            
            switch action.actionType {
            case .turnOn:
                let onMessage = ToggleUtils.getToggleOnMessage(from: control.message)
                mqttBroker.publish(topic: control.topic, message: onMessage)
                
            case .turnOff:
                let offMessage = ToggleUtils.getToggleOffMessage(from: control.message)
                mqttBroker.publish(topic: control.topic, message: offMessage)
                
            case .toggle:
                if let currentValue = mqttBroker.getValue(topic: control.topic) {
                    if let boolValue = currentValue.asBool() {
                        let onOffConfig = ToggleUtils.getToggleMessages(from: control.message)
                        let messageToSend = boolValue ? onOffConfig.offMessage : onOffConfig.onMessage
                        mqttBroker.publish(topic: control.topic, message: messageToSend)
                    }
                } else {
                    let onMessage = ToggleUtils.getToggleOnMessage(from: control.message)
                    mqttBroker.publish(topic: control.topic, message: onMessage)
                }
                
            case .setValue:
                mqttBroker.publish(topic: control.topic, message: action.value)
            }
            
            logger.info("Action executed: \(action.actionType.rawValue) for control \(control.id)")
        } else {
            logger.error("Failed to find control with ID: \(action.targetControlId)")
        }
    }
    
    // MARK: - Persistence
    
    private func saveRules() {
        UserDefaultsManager.shared.saveAutomationRules(automationRules)
    }
    
    private func loadRules() {
        automationRules = UserDefaultsManager.shared.loadAutomationRules()
    }
}
