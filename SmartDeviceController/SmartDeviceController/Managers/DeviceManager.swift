import SwiftUI

class DeviceManager {
    static let shared = DeviceManager()
    
    private let devicesKey = "savedDevices"
    
    private init() {}
    
    func saveDevices(_ devices: [Device]) {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(devices)
            UserDefaults.standard.set(data, forKey: devicesKey)
            UserDefaults.standard.synchronize()
            print("Successfully saved \(devices.count) devices")
        } catch {
            print("Error saving devices: \(error.localizedDescription)")
        }
    }
    
    func loadDevices() -> [Device] {
        guard let data = UserDefaults.standard.data(forKey: devicesKey) else {
            return []
        }
        
        do {
            let decoder = JSONDecoder()
            let devices = try decoder.decode([Device].self, from: data)
            return devices
        } catch {
            print("Error loading devices: \(error.localizedDescription)")
            return []
        }
    }
    
    func getDevice(withId id: Int) -> Device? {
        return loadDevices().first { $0.id == id }
    }
    
    func addDevice(_ device: Device) {
        var devices = loadDevices()
        devices.append(device)
        saveDevices(devices)
    }
    
    func updateDevice(_ device: Device) {
        var devices = loadDevices()
        if let index = devices.firstIndex(where: { $0.id == device.id }) {
            devices[index] = device
            saveDevices(devices)
        }
    }
    
    func removeDevice(withId id: Int) {
        var devices = loadDevices()
        devices.removeAll { $0.id == id }
        saveDevices(devices)
    }
    
    func getFilteredTopics(for deviceId: Int, from allTopics: [String]) -> [String] {
        guard let device = getDevice(withId: deviceId),
              let deviceTopic = device.mqttTopic,
              !deviceTopic.isEmpty else {
            return allTopics
        }
        
        return allTopics.filter { topic in
            topic.hasPrefix(deviceTopic)
        }
    }
}
