//
//  UserDefaultsManager.swift
//  SmartDeviceController
//
//  Created by Aaron Flynn on 22/03/2025.
//


import Foundation
import SwiftUI

/// Centralized manager for UserDefaults storage operations
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
        
        // Energy monitoring keys
        static let energyCostDeviceSelections = "energyCostDeviceSelections"
        static let energyCostDeviceDataPoints = "energyCostDeviceDataPoints"
        static let energyCostPerKWh = "energyCostPerKWh"
        static let energyDataCollectionEnabled = "energyDataCollectionEnabled"
        static let energyDataCollectionInterval = "energyDataCollectionInterval"
        static func energyReadings(_ deviceId: String) -> String {
            return "energyReadings_\(deviceId)"
        }
    }
    
    // MARK: - Device Controls
    
    /// Save controls for a specific device
    /// - Parameters:
    ///   - controls: Array of DeviceControl objects
    ///   - deviceId: The device ID
    func saveControls(_ controls: [DeviceControl], forDevice deviceId: Int) {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(controls)
            UserDefaults.standard.set(data, forKey: Keys.deviceControls + "\(deviceId)")
            
            // Ensure changes are written immediately
            UserDefaults.standard.synchronize()
            
            print("Successfully saved \(controls.count) controls for device \(deviceId)")
        } catch {
            print("Error saving controls: \(error.localizedDescription)")
        }
    }
    
    /// Load controls for a specific device
    /// - Parameter deviceId: The device ID
    /// - Returns: Array of DeviceControl objects, or empty array if none found
    func loadControls(forDevice deviceId: Int) -> [DeviceControl] {
        if let savedData = UserDefaults.standard.data(forKey: Keys.deviceControls + "\(deviceId)"),
           let decoded = try? JSONDecoder().decode([DeviceControl].self, from: savedData) {
            return decoded
        }
        return []
    }
    
    /// Get all controls from all devices
    /// - Returns: Dictionary mapping device IDs to their controls
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
    
    /// Get all controls as a flat array
    /// - Returns: Array of all device controls
    func getAllControlsFlat() -> [DeviceControl] {
        var allControls: [DeviceControl] = []
        
        for (_, controls) in getAllControls() {
            allControls.append(contentsOf: controls)
        }
        
        return allControls
    }
    
    // MARK: - Automation Rules
    
    /// Save automation rules
    /// - Parameter rules: Array of automation rules
    func saveAutomationRules(_ rules: [AutomationRule]) {
        if let encoded = try? JSONEncoder().encode(rules) {
            UserDefaults.standard.set(encoded, forKey: Keys.savedAutomationRules)
        }
    }
    
    /// Load automation rules
    /// - Returns: Array of automation rules, or empty array if none found
    func loadAutomationRules() -> [AutomationRule] {
        if let savedData = UserDefaults.standard.data(forKey: Keys.savedAutomationRules),
           let decoded = try? JSONDecoder().decode([AutomationRule].self, from: savedData) {
            return decoded
        }
        return []
    }
    
    // MARK: - Motion Actions
    
    /// Save motion actions
    /// - Parameter actions: Array of motion actions
    func saveMotionActions(_ actions: [MotionAction]) {
        if let encoded = try? JSONEncoder().encode(actions) {
            UserDefaults.standard.set(encoded, forKey: Keys.savedMotionActions)
        }
    }
    
    /// Load motion actions
    /// - Returns: Array of motion actions, or empty array if none found
    func loadMotionActions() -> [MotionAction] {
        if let savedData = UserDefaults.standard.data(forKey: Keys.savedMotionActions),
           let decoded = try? JSONDecoder().decode([MotionAction].self, from: savedData) {
            return decoded
        }
        return []
    }
    
    // MARK: - Timer Actions
    
    /// Save timer actions
    /// - Parameter actions: Array of timer actions
    func saveTimerActions(_ actions: [TimerAction]) {
        if let encoded = try? JSONEncoder().encode(actions) {
            UserDefaults.standard.set(encoded, forKey: Keys.savedTimerActions)
        }
    }
    
    /// Load timer actions
    /// - Returns: Array of timer actions, or empty array if none found
    func loadTimerActions() -> [TimerAction] {
        if let savedData = UserDefaults.standard.data(forKey: Keys.savedTimerActions),
           let decoded = try? JSONDecoder().decode([TimerAction].self, from: savedData) {
            return decoded
        }
        return []
    }
    
    // MARK: - Motion Settings
    
    /// Save motion control settings
    /// - Parameters:
    ///   - enabled: Whether motion controls are enabled
    ///   - sensitivity: Motion sensitivity value
    func saveMotionSettings(enabled: Bool, sensitivity: Double) {
        UserDefaults.standard.set(enabled, forKey: Keys.motionControlsEnabled)
        UserDefaults.standard.set(sensitivity, forKey: Keys.motionControlsSensitivity)
    }
    
    /// Load motion control enabled setting
    /// - Returns: Whether motion controls are enabled
    func loadMotionEnabled() -> Bool {
        return UserDefaults.standard.bool(forKey: Keys.motionControlsEnabled)
    }
    
    /// Load motion control sensitivity setting
    /// - Returns: Motion sensitivity value, defaulting to 5.0 if not set
    func loadMotionSensitivity() -> Double {
        let sensitivity = UserDefaults.standard.double(forKey: Keys.motionControlsSensitivity)
        return sensitivity == 0 ? 5.0 : sensitivity
    }
    
    // MARK: - Device Locations
    
    /// Save device locations
    /// - Parameter locations: Array of location strings
    func saveDeviceLocations(_ locations: [String]) {
        UserDefaults.standard.set(locations, forKey: Keys.savedDeviceLocations)
    }
    
    /// Load device locations
    /// - Returns: Array of location strings, or empty array if none found
    func loadDeviceLocations() -> [String] {
        return UserDefaults.standard.stringArray(forKey: Keys.savedDeviceLocations) ?? []
    }
    
    // MARK: - UI Settings
    
    /// Save whether to show the motion control bar
    /// - Parameter show: Whether to show the bar
    func saveShowMotionControlBar(_ show: Bool) {
        UserDefaults.standard.set(show, forKey: Keys.showMotionControlBar)
    }
    
    /// Load whether to show the motion control bar
    /// - Returns: Whether to show the bar
    func loadShowMotionControlBar() -> Bool {
        return UserDefaults.standard.bool(forKey: Keys.showMotionControlBar)
    }
    
    // MARK: - Energy Monitoring
    
    /// Save energy cost device selections
    /// - Parameter selections: Dictionary mapping device IDs to selection state
    func saveEnergyCostDeviceSelections(_ selections: [String: Bool]) {
        if let encoded = try? JSONEncoder().encode(selections) {
            UserDefaults.standard.set(encoded, forKey: Keys.energyCostDeviceSelections)
        }
    }
    
    /// Load energy cost device selections
    /// - Returns: Dictionary mapping device IDs to selection state, or empty dictionary if none found
    func loadEnergyCostDeviceSelections() -> [String: Bool] {
        if let savedData = UserDefaults.standard.data(forKey: Keys.energyCostDeviceSelections),
           let decoded = try? JSONDecoder().decode([String: Bool].self, from: savedData) {
            return decoded
        }
        return [:]
    }
    
    /// Save energy cost device data points
    /// - Parameter dataPoints: Dictionary mapping device IDs to data point IDs
    func saveEnergyCostDeviceDataPoints(_ dataPoints: [String: String]) {
        if let encoded = try? JSONEncoder().encode(dataPoints) {
            UserDefaults.standard.set(encoded, forKey: Keys.energyCostDeviceDataPoints)
        }
    }
    
    /// Load energy cost device data points
    /// - Returns: Dictionary mapping device IDs to data point IDs, or empty dictionary if none found
    func loadEnergyCostDeviceDataPoints() -> [String: String] {
        if let savedData = UserDefaults.standard.data(forKey: Keys.energyCostDeviceDataPoints),
           let decoded = try? JSONDecoder().decode([String: String].self, from: savedData) {
            return decoded
        }
        return [:]
    }
    
    /// Save energy readings for a device
    /// - Parameters:
    ///   - readings: Array of energy readings
    ///   - deviceId: The device ID
    func saveEnergyReadings<T: Encodable>(_ readings: [T], forDevice deviceId: String) {
        if let encoded = try? JSONEncoder().encode(readings) {
            UserDefaults.standard.set(encoded, forKey: Keys.energyReadings(deviceId))
        }
    }
    
    /// Load energy readings for a device
    /// - Parameter deviceId: The device ID
    /// - Returns: Array of energy readings, or nil if none found
    func loadEnergyReadings<T: Decodable>(forDevice deviceId: String) -> [T]? {
        if let savedData = UserDefaults.standard.data(forKey: Keys.energyReadings(deviceId)),
           let decoded = try? JSONDecoder().decode([T].self, from: savedData) {
            return decoded
        }
        return nil
    }
    
    /// Save energy cost per kWh
    /// - Parameter cost: Cost per kWh
    func saveEnergyCostPerKWh(_ cost: Double) {
        UserDefaults.standard.set(cost, forKey: Keys.energyCostPerKWh)
    }
    
    /// Load energy cost per kWh
    /// - Returns: Cost per kWh, or 0.0 if not set
    func loadEnergyCostPerKWh() -> Double {
        return UserDefaults.standard.double(forKey: Keys.energyCostPerKWh)
    }
    
    /// Save energy data collection settings
    /// - Parameters:
    ///   - enabled: Whether data collection is enabled
    ///   - interval: Data collection interval raw value
    func saveEnergyDataCollectionSettings(enabled: Bool, interval: Int) {
        UserDefaults.standard.set(enabled, forKey: Keys.energyDataCollectionEnabled)
        UserDefaults.standard.set(interval, forKey: Keys.energyDataCollectionInterval)
    }
    
    /// Load energy data collection enabled setting
    /// - Returns: Whether data collection is enabled
    func loadEnergyDataCollectionEnabled() -> Bool {
        return UserDefaults.standard.bool(forKey: Keys.energyDataCollectionEnabled)
    }
    
    /// Load energy data collection interval
    /// - Returns: Data collection interval raw value, or 0 if not set
    func loadEnergyDataCollectionInterval() -> Int {
        return UserDefaults.standard.integer(forKey: Keys.energyDataCollectionInterval)
    }
    
    /// Clear all energy data
    func clearAllEnergyData() {
        // Delete all energy reading keys
        for key in UserDefaults.standard.dictionaryRepresentation().keys {
            if key.hasPrefix("energyReadings_") {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
    }
}
