import Foundation
import SwiftUI

class UserDefaultsManager {
    static let shared = UserDefaultsManager()
    
    private init() {}
    
    struct Keys {
        static let deviceControls = "controls_"
        static let savedAutomationRules = "savedAutomationRules"
        static let savedMotionActions = "savedMotionActions"
        static let savedTimerActions = "savedTimerActions"
        static let motionControlsEnabled = "motionControlsEnabled"
        static let motionControlsSensitivity = "motionControlsSensitivity"
        static let savedDeviceLocations = "savedDeviceLocations"
        static let showMotionControlBar = "showMotionControlBar"
        static let advancedModeEnabled = "advancedModeEnabled"
        
        static let energyCostDeviceSelections = "energyCostDeviceSelections"
        static let energyCostDeviceDataPoints = "energyCostDeviceDataPoints"
        static let energyCostPerKWh = "energyCostPerKWh"
        static let energyDataCollectionEnabled = "energyDataCollectionEnabled"
        static let energyDataCollectionInterval = "energyDataCollectionInterval"
        static func energyReadings(_ deviceId: String) -> String {
            return "energyReadings_\(deviceId)"
        }
    }
    
    func saveControls(_ controls: [DeviceControl], forDevice deviceId: Int) {
        if let encoded = try? JSONEncoder().encode(controls) {
            UserDefaults.standard.set(encoded, forKey: Keys.deviceControls + "\(deviceId)")
            UserDefaults.standard.synchronize()
        }
    }
    
    func loadControls(forDevice deviceId: Int) -> [DeviceControl] {
        if let savedData = UserDefaults.standard.data(forKey: Keys.deviceControls + "\(deviceId)"),
           let decoded = try? JSONDecoder().decode([DeviceControl].self, from: savedData) {
            return decoded
        }
        return []
    }
    
    
    func getAllControls() -> [Int: [DeviceControl]] {
        var result: [Int: [DeviceControl]] = [:]
        
        let defaults = UserDefaults.standard
        let dictionaryRepresentation = defaults.dictionaryRepresentation()
        
        for (key, _) in dictionaryRepresentation {
            if key.starts(with: Keys.deviceControls),
               let deviceIdString = key.split(separator: "_").last,
               let deviceId = Int(deviceIdString),
               let savedData = defaults.data(forKey: key),
               let controls = try? JSONDecoder().decode([DeviceControl].self, from: savedData) {
                result[deviceId] = controls
            }
        }
        
        return result
    }
    
    
    func getAllControlsFlat() -> [DeviceControl] {
        var allControls: [DeviceControl] = []
        
        for (_, controls) in getAllControls() {
            allControls.append(contentsOf: controls)
        }
        
        return allControls
    }
    
   
    func saveAutomationRules(_ rules: [AutomationRule]) {
        if let encoded = try? JSONEncoder().encode(rules) {
            UserDefaults.standard.set(encoded, forKey: Keys.savedAutomationRules)
        }
    }
    
    
    func loadAutomationRules() -> [AutomationRule] {
        if let savedData = UserDefaults.standard.data(forKey: Keys.savedAutomationRules),
           let decoded = try? JSONDecoder().decode([AutomationRule].self, from: savedData) {
            return decoded
        }
        return []
    }
    
    
    func saveMotionActions(_ actions: [MotionAction]) {
        if let encoded = try? JSONEncoder().encode(actions) {
            UserDefaults.standard.set(encoded, forKey: Keys.savedMotionActions)
        }
    }
    
    
    func loadMotionActions() -> [MotionAction] {
        if let savedData = UserDefaults.standard.data(forKey: Keys.savedMotionActions),
           let decoded = try? JSONDecoder().decode([MotionAction].self, from: savedData) {
            return decoded
        }
        return []
    }
    
   
    func saveTimerActions(_ actions: [TimerAction]) {
        if let encoded = try? JSONEncoder().encode(actions) {
            UserDefaults.standard.set(encoded, forKey: Keys.savedTimerActions)
        }
    }
    
    
    func loadTimerActions() -> [TimerAction] {
        if let savedData = UserDefaults.standard.data(forKey: Keys.savedTimerActions),
           let decoded = try? JSONDecoder().decode([TimerAction].self, from: savedData) {
            return decoded
        }
        return []
    }
    

    func saveMotionSettings(enabled: Bool, sensitivity: Double) {
        UserDefaults.standard.set(enabled, forKey: Keys.motionControlsEnabled)
        UserDefaults.standard.set(sensitivity, forKey: Keys.motionControlsSensitivity)
    }
    
   
    func loadMotionEnabled() -> Bool {
        return UserDefaults.standard.bool(forKey: Keys.motionControlsEnabled)
    }
    
   
    func loadMotionSensitivity() -> Double {
        let sensitivity = UserDefaults.standard.double(forKey: Keys.motionControlsSensitivity)
        return sensitivity == 0 ? 5.0 : sensitivity
    }
    
    
    func saveDeviceLocations(_ locations: [String]) {
        UserDefaults.standard.set(locations, forKey: Keys.savedDeviceLocations)
    }
    
    
    func loadDeviceLocations() -> [String] {
        return UserDefaults.standard.stringArray(forKey: Keys.savedDeviceLocations) ?? []
    }
    
    
    func saveShowMotionControlBar(_ show: Bool) {
        UserDefaults.standard.set(show, forKey: Keys.showMotionControlBar)
    }
    
   
    func loadShowMotionControlBar() -> Bool {
        return UserDefaults.standard.bool(forKey: Keys.showMotionControlBar)
    }
    
   
    func saveAdvancedMode(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: Keys.advancedModeEnabled)
        UserDefaults.standard.synchronize()
    }
    
    func loadAdvancedMode() -> Bool {
        return UserDefaults.standard.bool(forKey: Keys.advancedModeEnabled)
    }
    
   
    func saveEnergyCostDeviceSelections(_ selections: [String: Bool]) {
        if let encoded = try? JSONEncoder().encode(selections) {
            UserDefaults.standard.set(encoded, forKey: Keys.energyCostDeviceSelections)
        }
    }
    
    
    func loadEnergyCostDeviceSelections() -> [String: Bool] {
        if let savedData = UserDefaults.standard.data(forKey: Keys.energyCostDeviceSelections),
           let decoded = try? JSONDecoder().decode([String: Bool].self, from: savedData) {
            return decoded
        }
        return [:]
    }
    
    
    func saveEnergyCostDeviceDataPoints(_ dataPoints: [String: String]) {
        if let encoded = try? JSONEncoder().encode(dataPoints) {
            UserDefaults.standard.set(encoded, forKey: Keys.energyCostDeviceDataPoints)
        }
    }
    
    
    func loadEnergyCostDeviceDataPoints() -> [String: String] {
        if let savedData = UserDefaults.standard.data(forKey: Keys.energyCostDeviceDataPoints),
           let decoded = try? JSONDecoder().decode([String: String].self, from: savedData) {
            return decoded
        }
        return [:]
    }
    
    
    func saveEnergyReadings<T: Encodable>(_ readings: [T], forDevice deviceId: String) {
        if let encoded = try? JSONEncoder().encode(readings) {
            UserDefaults.standard.set(encoded, forKey: Keys.energyReadings(deviceId))
        }
    }
    
    
    func loadEnergyReadings<T: Decodable>(forDevice deviceId: String) -> [T]? {
        if let savedData = UserDefaults.standard.data(forKey: Keys.energyReadings(deviceId)),
           let decoded = try? JSONDecoder().decode([T].self, from: savedData) {
            return decoded
        }
        return nil
    }
    
    func saveEnergyCostPerKWh(_ cost: Double) {
        UserDefaults.standard.set(cost, forKey: Keys.energyCostPerKWh)
    }
    
    func loadEnergyCostPerKWh() -> Double {
        return UserDefaults.standard.double(forKey: Keys.energyCostPerKWh)
    }
    
    func saveEnergyDataCollectionSettings(enabled: Bool, interval: Int) {
        UserDefaults.standard.set(enabled, forKey: Keys.energyDataCollectionEnabled)
        UserDefaults.standard.set(interval, forKey: Keys.energyDataCollectionInterval)
    }
    
    func loadEnergyDataCollectionEnabled() -> Bool {
        return UserDefaults.standard.bool(forKey: Keys.energyDataCollectionEnabled)
    }
    
    func loadEnergyDataCollectionInterval() -> Int {
        return UserDefaults.standard.integer(forKey: Keys.energyDataCollectionInterval)
    }
    
  
    func clearAllEnergyData() {
        for key in UserDefaults.standard.dictionaryRepresentation().keys {
            if key.hasPrefix("energyReadings_") {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
    }
}
