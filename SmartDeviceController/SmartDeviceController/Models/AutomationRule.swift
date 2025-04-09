//
//  AutomationRule.swift
//  SmartDeviceController
//
//  Created by Aaron Flynn on 22/03/2025.
//


import SwiftUI
import os.log

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


class AutomationManager: ObservableObject {
    
    static let shared = AutomationManager()
    @Published var automationRules: [AutomationRule] = []
    @Published var isProcessingEnabled = true
    
    
    private var monitoringTimer: Timer?
    private let checkInterval: TimeInterval = 5.0
    private let logger = Logger(subsystem: "com.aaronflynn.SmartDeviceController", category: "Automation")
    
    
    init() {
        loadRules()
        startMonitoring()
    }
    
    func addRule(_ rule: AutomationRule) {
        automationRules.append(rule)
        saveRules()
    }
    
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
    
    func removeRule(id: String) {
        automationRules.removeAll(where: { $0.id == id })
        saveRules()
    }
    
    func getRules(forDevice deviceId: Int) -> [AutomationRule] {
        return automationRules.filter { $0.deviceId == deviceId }
    }
    
    func startMonitoring() {
        stopMonitoring()
        
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: checkInterval, repeats: true) { [weak self] _ in
            self?.checkAndProcessRules()
        }
        
        if let timer = monitoringTimer {
            RunLoop.current.add(timer, forMode: .common)
        }
        
        logger.info("Automation monitoring started")
    }
    
    func stopMonitoring() {
        monitoringTimer?.invalidate()
        monitoringTimer = nil
        
        logger.info("Automation monitoring stopped")
    }
    
    private func checkAndProcessRules() {
        guard isProcessingEnabled else { return }
        
        for rule in automationRules where rule.isEnabled {
            evaluateRule(rule)
        }
    }
    
    private func evaluateRule(_ rule: AutomationRule) {
        let mqttBroker = MQTTBroker.shared
        let condition = rule.condition
        
        if let dataPoint = mqttBroker.getDataPointById(condition.dataPointId),
           let currentValue = mqttBroker.getValue(for: dataPoint) {
            
            if compareValues(currentValue: currentValue, condition: condition) {
                logger.info("Rule '\(rule.name)' condition met, executing action")
                executeAction(rule.action)
            }
        }
    }
    
    private func compareValues(currentValue: MQTTBroker.DataValue, condition: RuleCondition) -> Bool {
        let conditionValue = condition.value
        
        switch currentValue {
        case .number(let numValue):
            if let targetValue = Double(conditionValue) {
                switch condition.comparator {
                case .greaterThan: return numValue > targetValue
                case .lessThan: return numValue < targetValue
                case .equalTo: return abs(numValue - targetValue) < 0.001
                case .notEqualTo: return abs(numValue - targetValue) >= 0.001
                }
            }
            
        case .boolean(let boolValue):
            let targetBool = conditionValue.lowercased() == "true" || conditionValue == "1" || conditionValue.lowercased() == "on"
            switch condition.comparator {
            case .equalTo: return boolValue == targetBool
            case .notEqualTo: return boolValue != targetBool
            default: return false
            }
            
        case .text(let stringValue):
            switch condition.comparator {
            case .equalTo: return stringValue.lowercased() == conditionValue.lowercased()
            case .notEqualTo: return stringValue.lowercased() != conditionValue.lowercased()
            default: return false
            }
            
        case .jsonObject(let dict):
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
            return false
        }
        
        return false
    }
    
    
    private func executeAction(_ action: RuleAction) {
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
    
    private func saveRules() {
        UserDefaultsManager.shared.saveAutomationRules(automationRules)
    }
    
    private func loadRules() {
        automationRules = UserDefaultsManager.shared.loadAutomationRules()
    }
}
