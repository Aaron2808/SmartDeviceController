//
//  MQTTBroker.swift
//  SmartDeviceController
//
//  Created by Aaron Flynn on 13/01/2025.

import CocoaMQTT
import SwiftUI

class MQTTBroker: ObservableObject {
    static let shared = MQTTBroker()
    var mqtt: CocoaMQTT?
    var mqttConfig: MQTTConfig
    
    @Published var topics: Set<String> = Set()
    var clientID: String
    var hostAddress: String
    var port: UInt16
    
    @Published var groupedTopics: [String: [String: String]] = [:]
    @Published var topicData: [String: DataValue] = [:]
    @Published var deviceContexts: [String: DeviceContext] = [:]
    
    init() {
        
        clientID = "iOS_Client_\(UUID().uuidString)"
        mqttConfig = MQTTConfig()
        
        hostAddress = mqttConfig.host
        port = mqttConfig.port
        
        mqtt = CocoaMQTT(clientID: clientID, host: hostAddress, port: port)
        mqtt?.username = mqttConfig.username
        mqtt?.password = mqttConfig.password
        //mqtt?.logLevel = .debug
        
        //mqtt?.enableSSL = true
        //mqtt?.allowUntrustCACertificate = true
        
        mqtt?.willMessage = CocoaMQTTMessage(topic: "/will", string: "dieout")
        mqtt?.cleanSession = true
        mqtt?.keepAlive = 60
        
        mqtt?.delegate = self
        
        topics.insert("Test/Topic")
    }
    
    func connect() {
        if mqtt?.connState == .connected {
            print("Already connected, skipping connection attempt.")
        } else {
            let connectResult = mqtt?.connect() ?? false
            if !connectResult {
                print("Warning: Connection attempt failed")
            }
        }
    }
    
    func searchTopics() {
        mqtt?.subscribe("#")
    }
    
    func disconnect() {
        mqtt?.disconnect()
    }
    
    func publish(topic: String, message: String) {
        guard let mqtt = mqtt else {
            print("MQTT not initialized")
            return
        }
        mqtt.publish(topic, withString: message, qos: .qos1, retained: false)
        print("Message sent to topic \(topic): \(message)")
    }
    
    func subscribe(topic: String) {
        guard let mqtt = mqtt else {
            print("MQTT client is not initialized")
            return
        }
        
        mqtt.subscribe(topic, qos: .qos1)
        print("Subscribed to topic: \(topic)")
    }

    func autoConnect() {
        print("Starting MQTT auto-connection process")
        
        if mqtt?.connState == .connected {
            print("Already connected to MQTT broker")
            searchTopics()
            setupPeriodicTopicRefresh()
            return
        }
        
        if mqtt?.connState != .disconnected {
            print("MQTT in unexpected state: \(String(describing: mqtt?.connState)). Forcing disconnect.")
            disconnect()
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            print("Initiating connection to MQTT broker")
            self.connect()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                if self.mqtt?.connState == .connected {
                    print("Successfully connected to MQTT broker")
                    self.searchTopics()
                    self.setupPeriodicTopicRefresh()
                } else {
                    print("Failed to connect on first attempt, retrying...")
                    
                    self.connect()
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        if self.mqtt?.connState == .connected {
                            print("Successfully connected on second attempt")
                            self.searchTopics()
                            self.setupPeriodicTopicRefresh()
                        } else {
                            print("Failed to connect automatically after multiple attempts")
                        }
                    }
                }
            }
        }
    }
    
    private func setupPeriodicTopicRefresh() {
       
        NotificationCenter.default.post(name: NSNotification.Name("CancelExistingMQTTTimers"), object: nil)
        
        
        let timer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [self] _ in
            if self.mqtt?.connState == .connected {
                print("Performing periodic topic refresh")
                self.searchTopics()
            } else {
                print("MQTT not connected during refresh cycle, attempting reconnection")
                self.connect()
            }
        }
        
        RunLoop.current.add(timer, forMode: .common)
    }
    
    var isConnected: Bool {
        return mqtt?.connState == .connected
    }
}

extension MQTTBroker: CocoaMQTTDelegate {
    func mqtt(_ mqtt: CocoaMQTT, didPublishAck id: UInt16) {
        print("Publish is Acknowleged")
    }
    
    func mqtt(_ mqtt: CocoaMQTT, didSubscribeTopics success: NSDictionary, failed: [String]) {
        print("Subscribed to Topics")
    }
    
    func mqtt(_ mqtt: CocoaMQTT, didUnsubscribeTopics topics: [String]) {
        print("Unsubscribed to Topics")
    }
    
    func mqttDidPing(_ mqtt: CocoaMQTT) {
        print("Sent Ping")
    }
    
    func mqttDidReceivePong(_ mqtt: CocoaMQTT) {
        print("Recieved Pong")
    }
    
    func mqttDidDisconnect(_ mqtt: CocoaMQTT, withError err: (any Error)?) {
        print("Did Disconnect")
    }
    
    func mqtt(_ mqtt: CocoaMQTT, didConnectAck ack: CocoaMQTTConnAck) {
        if ack == .accept {
            print("Connected successfully to MQTT broker!")
        } else {
            print("Connection failed with ack: \(ack.rawValue).")
        }
    }

    func mqtt(_ mqtt: CocoaMQTT, didDisconnectWithError error: Error?) {
        if let error = error {
            print("Disconnected from Server. Error: \(error.localizedDescription)")
        } else {
            print("Disconnected successfully.")
        }
    }

    func mqtt(_ mqtt: CocoaMQTT, didReceiveMessage message: CocoaMQTTMessage, id: UInt16) {
            let topic = message.topic
            let payload = message.string ?? "N/A"
            
            print("MQTT Received: Topic: \(topic), Payload: \(payload)")
            
            DispatchQueue.main.async {
               
                let components = topic.split(separator: "/")
                guard components.count >= 1 else { return }
                
                let deviceID = String(components[0])
                let attribute = components.dropFirst().joined(separator: "/")
                
                if self.groupedTopics[deviceID] == nil {
                    self.groupedTopics[deviceID] = [:]
                }
                self.groupedTopics[deviceID]?[attribute] = payload
                self.processGenericMessage(topic: topic, payload: payload)
                self.topics.insert(topic)
                
                self.objectWillChange.send()
            }
        }

    func mqtt(_ mqtt: CocoaMQTT, didPublishMessage message: CocoaMQTTMessage, id: UInt16) {
        print("Message published successfully")
    }
    
}



extension MQTTBroker {
    
    enum DataValue: Equatable {
        case number(Double)
        case boolean(Bool)
        case text(String)
        case jsonObject([String: Any])
        case jsonArray([Any])
        case unknown
        
        func formattedString() -> String {
            switch self {
            case .number(let value):
                if value.truncatingRemainder(dividingBy: 1) == 0 {
                    return String(format: "%.0f", value)
                } else {
                    return String(format: "%.1f", value)
                }
            case .boolean(let value):
                return value ? "ON" : "OFF"
            case .text(let value):
                return value
            case .jsonObject:
                return "{...}"
            case .jsonArray:
                return "[...]"
            case .unknown:
                return "N/A"
            }
        }
        
        var isEmpty: Bool {
            switch self {
            case .number(let value): return value == 0
            case .boolean(let value): return !value
            case .text(let value): return value.isEmpty
            case .jsonObject(let dict): return dict.isEmpty
            case .jsonArray(let array): return array.isEmpty
            case .unknown: return true
            }
        }
        
        func asDouble() -> Double? {
            switch self {
            case .number(let value): return value
            case .boolean(let value): return value ? 1.0 : 0.0
            case .text(let value): return Double(value)
            default: return nil
            }
        }
        
        func asBool() -> Bool? {
            switch self {
            case .number(let value): return value != 0
            case .boolean(let value): return value
            case .text(let value):
                let lowercased = value.lowercased()
                if lowercased == "true" || lowercased == "on" || lowercased == "1" { return true }
                if lowercased == "false" || lowercased == "off" || lowercased == "0" { return false }
                return nil
            default: return nil
            }
        }
        
        func asString() -> String? {
            switch self {
            case .number(let value): return value.description
            case .boolean(let value): return value ? "true" : "false"
            case .text(let value): return value
            default: return nil
            }
        }
        
        static func == (lhs: DataValue, rhs: DataValue) -> Bool {
            switch (lhs, rhs) {
            case (.number(let l), .number(let r)): return l == r
            case (.boolean(let l), .boolean(let r)): return l == r
            case (.text(let l), .text(let r)): return l == r
            case (.jsonObject, .jsonObject), (.jsonArray, .jsonArray): return false
            case (.unknown, .unknown): return true
            default: return false
            }
        }
    }
    
    struct DataPoint: Identifiable, Hashable {
        var id: String
        var deviceId: String
        var name: String
        var path: String
        var type: DataType
        var unit: String?
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }
        
        static func == (lhs: DataPoint, rhs: DataPoint) -> Bool {
            return lhs.id == rhs.id
        }
    }
    
    enum DataType {
        case numeric
        case boolean
        case text
        case object
        case array
        case unknown
       
        var iconName: String {
            switch self {
            case .numeric: return "number"
            case .boolean: return "switch.2"
            case .text: return "text.alignleft"
            case .object: return "curlybraces"
            case .array: return "list.bullet"
            case .unknown: return "questionmark"
            }
        }
        
        var color: Color {
            switch self {
            case .numeric: return .blue
            case .boolean: return .green
            case .text: return .orange
            case .object: return .purple
            case .array: return .gray
            case .unknown: return .red
            }
        }
    }
    
    struct DeviceContext {
        var deviceId: String
        var lastSeen: Date = Date()
        var knownTopics: Set<String> = []
        var deviceType: String?
        var friendlyName: String?
        var isOnline: Bool = true
        
        var displayName: String {
            if let name = friendlyName, !name.isEmpty {
                return name
            }
            return deviceId
        }
    }
    var dataUpdateIdentifier: Int {
        
            var hasher = Hasher()
            hasher.combine(topicData.count)
        
            let sampleKeys = Array(topicData.keys.prefix(10))
            for key in sampleKeys {
                if let value = topicData[key] {
                    hasher.combine(key)
                    
                    switch value {
                    case .number(let num):
                        hasher.combine(num)
                    case .boolean(let bool):
                        hasher.combine(bool)
                    case .text(let text):
                        hasher.combine(text)
                    case .jsonObject, .jsonArray, .unknown:
                        hasher.combine(1)
                    }
                }
            }
            
            return hasher.finalize()
        }
        
    func processGenericMessage(topic: String, payload: String) {
        let topicComponents = topic.split(separator: "/")
        guard !topicComponents.isEmpty else { return }
        
        let deviceId = String(topicComponents[0])
        
        updateDeviceContext(deviceId: deviceId, topic: topic)
        
        print("Processing \(topic) with payload: \(payload.prefix(100))...")
        
        let previousValue = topicData[topic]
        var valueChanged = false
        
        if let jsonData = payload.data(using: .utf8),
           let jsonObject = try? JSONSerialization.jsonObject(with: jsonData) {
            
            if let dict = jsonObject as? [String: Any] {
               
                topicData[topic] = .jsonObject(dict)
                valueChanged = true
            
                for (key, value) in dict {
                    let keyPath = "\(topic)/\(key)"
                    
                    if let numValue = value as? Double {
                        topicData[keyPath] = .number(numValue)
                        print("Stored numeric value for \(keyPath): \(numValue)")
                    } else if let intValue = value as? Int {
                        topicData[keyPath] = .number(Double(intValue))
                        print("Stored integer value for \(keyPath): \(intValue)")
                    } else if let boolValue = value as? Bool {
                        topicData[keyPath] = .boolean(boolValue)
                        print("Stored boolean value for \(keyPath): \(boolValue)")
                    } else if let strValue = value as? String {
                        topicData[keyPath] = .text(strValue)
                        print("Stored text value for \(keyPath): \(strValue)")
                    } else if let objValue = value as? [String: Any] {
                        topicData[keyPath] = .jsonObject(objValue)
                        print("Stored nested object for \(keyPath)")
                        
                        processNestedObject(objValue, parentPath: keyPath)
                    }
                }
                
                let flatValues = flattenJSON(dict, parentPath: topic)
                for (path, value) in flatValues {
                    if topicData[path] == nil {
                        topicData[path] = value
                    }
                }
            } else if let array = jsonObject as? [Any] {
                topicData[topic] = .jsonArray(array)
                valueChanged = true
                
                for (index, element) in array.enumerated() {
                    let elementPath = "\(topic)[\(index)]"
                    
                    if let numValue = element as? Double {
                        topicData[elementPath] = .number(numValue)
                    } else if let intValue = element as? Int {
                        topicData[elementPath] = .number(Double(intValue))
                    } else if let boolValue = element as? Bool {
                        topicData[elementPath] = .boolean(boolValue)
                    } else if let strValue = element as? String {
                        topicData[elementPath] = .text(strValue)
                    } else if let objValue = element as? [String: Any] {
                        topicData[elementPath] = .jsonObject(objValue)
                        processNestedObject(objValue, parentPath: elementPath)
                    }
                }
            }
        } else if let numberValue = Double(payload) {
            topicData[topic] = .number(numberValue)
            valueChanged = previousValue != topicData[topic]
        } else if payload.lowercased() == "true" || payload.lowercased() == "false" {
            topicData[topic] = .boolean(payload.lowercased() == "true")
            valueChanged = previousValue != topicData[topic]
        } else {
            topicData[topic] = .text(payload)
            valueChanged = previousValue != topicData[topic]
            
            if topic.hasSuffix("/online") || topic.hasSuffix("/availability") {
                let isOnline = (payload.lowercased() == "online" || payload.lowercased() == "true")
                if var context = deviceContexts[deviceId] {
                    context.isOnline = isOnline
                    deviceContexts[deviceId] = context
                }
            }
        }
        
        if valueChanged {
            DispatchQueue.main.async {
                print("Sending objectWillChange notification due to data update")
                self.objectWillChange.send()
            }
        }
    }
    
    private func processNestedObject(_ object: [String: Any], parentPath: String) {
        for (key, value) in object {
            let keyPath = "\(parentPath)/\(key)"
            
            if let numValue = value as? Double {
                topicData[keyPath] = .number(numValue)
                print("Stored nested numeric value for \(keyPath): \(numValue)")
            } else if let intValue = value as? Int {
                topicData[keyPath] = .number(Double(intValue))
                print("Stored nested integer value for \(keyPath): \(intValue)")
            } else if let boolValue = value as? Bool {
                topicData[keyPath] = .boolean(boolValue)
                print("Stored nested boolean value for \(keyPath): \(boolValue)")
            } else if let strValue = value as? String {
                topicData[keyPath] = .text(strValue)
                print("Stored nested text value for \(keyPath): \(strValue)")
            } else if let nestedObj = value as? [String: Any] {
                topicData[keyPath] = .jsonObject(nestedObj)
                processNestedObject(nestedObj, parentPath: keyPath)
            } else if let nestedArray = value as? [Any] {
                topicData[keyPath] = .jsonArray(nestedArray)
                
                for (index, element) in nestedArray.enumerated() {
                    let elementPath = "\(keyPath)[\(index)]"
                    
                    if let numElement = element as? Double {
                        topicData[elementPath] = .number(numElement)
                    } else if let intElement = element as? Int {
                        topicData[elementPath] = .number(Double(intElement))
                    } else if let boolElement = element as? Bool {
                        topicData[elementPath] = .boolean(boolElement)
                    } else if let strElement = element as? String {
                        topicData[elementPath] = .text(strElement)
                    }
                }
            }
        }
    }
   
    private func updateDeviceContext(deviceId: String, topic: String) {
        if deviceContexts[deviceId] == nil {
            deviceContexts[deviceId] = DeviceContext(deviceId: deviceId)
        }
        
        var context = deviceContexts[deviceId]!
        context.lastSeen = Date()
        context.knownTopics.insert(topic)
        
        if context.deviceType == nil {
            if topic.contains("/temperature") || topic.contains("/humidity") {
                context.deviceType = "Sensor"
            } else if topic.contains("/switch") || topic.contains("/relay") {
                context.deviceType = "Switch"
            } else if topic.contains("/light") {
                context.deviceType = "Light"
            }
        }
    
        if context.friendlyName == nil && topic.hasSuffix("/name") {
            if case .text(let name) = topicData[topic] {
                context.friendlyName = name
            }
        }
        
        deviceContexts[deviceId] = context
    }
    
    private func flattenJSON(_ json: [String: Any], parentPath: String) -> [String: DataValue] {
            var result: [String: DataValue] = [:]
            
            for (key, value) in json {
                let currentPath = "\(parentPath)/\(key)"
                
                if let numberValue = value as? Double {
                    result[currentPath] = .number(numberValue)
                } else if let intValue = value as? Int {
                    result[currentPath] = .number(Double(intValue))
                } else if let boolValue = value as? Bool {
                    result[currentPath] = .boolean(boolValue)
                } else if let stringValue = value as? String {
                    result[currentPath] = .text(stringValue)
                }
                
                if let nestedDict = value as? [String: Any] {

                    let nestedResult = flattenJSON(nestedDict, parentPath: currentPath)
                    result.merge(nestedResult) { current, _ in current }
                    
                    result[currentPath] = .jsonObject(nestedDict)
                } else if let nestedArray = value as? [Any] {
                    result[currentPath] = .jsonArray(nestedArray)
                    
                    for (index, element) in nestedArray.enumerated() {
                        let elementPath = "\(currentPath)[\(index)]"
                        if let numberElement = element as? Double {
                            result[elementPath] = .number(numberElement)
                        } else if let intElement = element as? Int {
                            result[elementPath] = .number(Double(intElement))
                        } else if let boolElement = element as? Bool {
                            result[elementPath] = .boolean(boolElement)
                        } else if let stringElement = element as? String {
                            result[elementPath] = .text(stringElement)
                        } else if let objElement = element as? [String: Any] {
                            result[elementPath] = .jsonObject(objElement)
                            let nestedResult = flattenJSON(objElement, parentPath: elementPath)
                            result.merge(nestedResult) { current, _ in current }
                        }
                    }
                } else if value is NSNull {
                    result[currentPath] = .text("null")
                } else {
                    result[currentPath] = .unknown
                }
            }
            
            return result
        }
        
    
    func debugAllTopicData() {
            print("\n=== MQTT DATA DEBUG ===")
            print("Total topics in topicData: \(topicData.count)")
            
            for (topic, value) in topicData {
                print("• \(topic): \(value.formattedString())")
            }
            print("=======================\n")
        }
        
        func getDataByPath(_ path: String) -> DataValue? {
            if let value = topicData[path] {
               
                return value
            }
            
            let components = path.split(separator: "/")
            if components.count >= 3 {
                let baseTopic = components.dropLast().joined(separator: "/")
                let propertyName = String(components.last!)
                
                print("Looking for \(propertyName) in \(baseTopic)")
                
                if let baseValue = topicData[baseTopic], case .jsonObject(let dict) = baseValue {
                    if let propValue = dict[propertyName] {
                        print("Found \(propertyName) in JSON: \(propValue)")
                        
                        if let numValue = propValue as? Double {
                            return .number(numValue)
                        } else if let intValue = propValue as? Int {
                            return .number(Double(intValue))
                        } else if let boolValue = propValue as? Bool {
                            return .boolean(boolValue)
                        } else if let strValue = propValue as? String {
                            return .text(strValue)
                        } else if let objValue = propValue as? [String: Any] {
                            return .jsonObject(objValue)
                        } else if let arrValue = propValue as? [Any] {
                            return .jsonArray(arrValue)
                        }
                    }
                    
                    if propertyName.contains("/") {
                        let nestedPath = propertyName.split(separator: "/")
                        var current: Any = dict
                        
                        for part in nestedPath {
                            if let currentDict = current as? [String: Any],
                               let nextValue = currentDict[String(part)] {
                                current = nextValue
                            } else {
                                return nil
                            }
                        }
                        
                       
                        if let numValue = current as? Double {
                            return .number(numValue)
                        } else if let intValue = current as? Int {
                            return .number(Double(intValue))
                        } else if let boolValue = current as? Bool {
                            return .boolean(boolValue)
                        } else if let strValue = current as? String {
                            return .text(strValue)
                        }
                    }
                }
            }
            
            return nil
        }
    
    func getAllDataPoints(deviceId: String? = nil) -> [DataPoint] {
        var results: [DataPoint] = []
        
        for (topic, value) in topicData {
            let components = topic.split(separator: "/")
            guard !components.isEmpty else { continue }
            
            let topicDeviceId = String(components[0])
            if let deviceId = deviceId, topicDeviceId != deviceId {
                continue
            }
            
            let name = components.last.map { String($0) } ?? topic
            
            let (dataType, unit) = inferTypeAndUnit(topic: topic, value: value)
            
            let dataPoint = DataPoint(
                id: topic,
                deviceId: topicDeviceId,
                name: formatName(name),
                path: topic,
                type: dataType,
                unit: unit
            )
            
            results.append(dataPoint)
        }
        
        return results
    }
    
    private func inferTypeAndUnit(topic: String, value: DataValue) -> (DataType, String?) {
        let lowerTopic = topic.lowercased()
        var unit: String? = nil
        
        let dataType: DataType
        switch value {
        case .number:
            dataType = .numeric
            
            if lowerTopic.contains("temp") {
                unit = "°C"
            } else if lowerTopic.contains("humid") {
                unit = "%"
            } else if lowerTopic.contains("power") {
                unit = "W"
            } else if lowerTopic.contains("energy") {
                unit = "kWh"
            } else if lowerTopic.contains("voltage") {
                unit = "V"
            } else if lowerTopic.contains("current") {
                unit = "A"
            } else if lowerTopic.contains("pressure") {
                unit = "hPa"
            } else if lowerTopic.contains("level") || lowerTopic.contains("percent") {
                unit = "%"
            }
            
        case .boolean:
            dataType = .boolean
        case .text:
            dataType = .text
        case .jsonObject:
            dataType = .object
        case .jsonArray:
            dataType = .array
        case .unknown:
            dataType = .unknown
        }
        
        return (dataType, unit)
    }
    
    private func formatName(_ raw: String) -> String {
        let components = raw.split(separator: "_").map { String($0) }
        let formattedComponents = components.map {
            $0.prefix(1).uppercased() + $0.dropFirst()
        }
        return formattedComponents.joined(separator: " ")
    }
    
    func getFormattedValue(for dataPoint: DataPoint) -> String {
        guard let value = topicData[dataPoint.path] else {
            return "N/A"
        }
        
        let formattedValue = value.formattedString()
        if let unit = dataPoint.unit {
            return "\(formattedValue)\(unit)"
        }
        return formattedValue
    }
    
    func getValue(for dataPoint: DataPoint) -> DataValue? {
        return topicData[dataPoint.path]
    }
    
    func getValue(topic: String) -> DataValue? {
        return topicData[topic]
    }
    
    func getAllDevices() -> [String] {
        return Array(deviceContexts.keys).sorted()
    }
    
    func searchDataPoints(query: String, deviceId: String? = nil) -> [DataPoint] {
        let allPoints = getAllDataPoints(deviceId: deviceId)
        
        if query.isEmpty {
            return allPoints
        }
        
        return allPoints.filter { dataPoint in
            dataPoint.name.lowercased().contains(query.lowercased()) ||
            dataPoint.path.lowercased().contains(query.lowercased())
        }
    }
    
    func getDataPointById(_ dataPointId: String) -> DataPoint? {
            return getAllDataPoints().first(where: { $0.id == dataPointId })
        }
        
        func getAllDataPoints() -> [DataPoint] {
            var allPoints: [DataPoint] = []
            for deviceId in getAllDevices() {
                allPoints.append(contentsOf: getAllDataPoints(deviceId: deviceId))
            }
            return allPoints
        }
}

struct EnhancedDataPointSelector: View {
    @ObservedObject var mqttBroker: MQTTBroker
    @Binding var selectedDataPoint: MQTTBroker.DataPoint?
    @State private var searchText: String = ""
    @State private var selectedDevice: String? = nil
    @State private var filterType: MQTTBroker.DataType? = nil
    
    var devices: [String] {
        mqttBroker.getAllDevices()
    }
    
    var filteredDataPoints: [MQTTBroker.DataPoint] {
        var points = mqttBroker.searchDataPoints(query: searchText, deviceId: selectedDevice)
        
        if let type = filterType {
            points = points.filter { $0.type == type }
        }
        
        return points
    }
    
    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                Picker("Device", selection: $selectedDevice) {
                    Text("All Devices").tag(Optional<String>(nil))
                    ForEach(devices, id: \.self) { device in
                        HStack {
                            Text(mqttBroker.deviceContexts[device]?.displayName ?? device)
                            if let isOnline = mqttBroker.deviceContexts[device]?.isOnline, !isOnline {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 8, height: 8)
                            }
                        }
                        .tag(Optional(device))
                    }
                }
                .pickerStyle(MenuPickerStyle())
                
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    
                    TextField("Search data points", text: $searchText)
                        .disableAutocorrection(true)
                    
                    if !searchText.isEmpty {
                        Button(action: {
                            searchText = ""
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(8)
                .background(Color(.systemGray6))
                .cornerRadius(8)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        TypeFilterButton(
                            icon: "number",
                            label: "Numbers",
                            color: .blue,
                            isSelected: filterType == .numeric,
                            action: { toggleFilter(.numeric) }
                        )
                        
                        TypeFilterButton(
                            icon: "switch.2",
                            label: "Switches",
                            color: .green,
                            isSelected: filterType == .boolean,
                            action: { toggleFilter(.boolean) }
                        )
                        
                        TypeFilterButton(
                            icon: "text.alignleft",
                            label: "Text",
                            color: .orange,
                            isSelected: filterType == .text,
                            action: { toggleFilter(.text) }
                        )
                        
                        TypeFilterButton(
                            icon: "curlybraces",
                            label: "Objects",
                            color: .purple,
                            isSelected: filterType == .object,
                            action: { toggleFilter(.object) }
                        )
                    }
                }
            }
            .padding()
            .background(Color(.systemBackground))
            
            Divider()
            
            if filteredDataPoints.isEmpty {
                VStack(spacing: 16) {
                    Spacer()
                    
                    if searchText.isEmpty && filterType == nil {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        
                        Text("Waiting for MQTT Data")
                            .font(.headline)
                        
                        Text("Connect your devices and data will appear here")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    } else {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        
                        Text("No Matching Data Points")
                            .font(.headline)
                        
                        Text("Try adjusting your search or filters")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
            } else {
                List {
                    ForEach(filteredDataPoints) { dataPoint in
                        DataPointRow(dataPoint: dataPoint, mqttBroker: mqttBroker)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedDataPoint = dataPoint
                            }
                            .background(
                                selectedDataPoint?.id == dataPoint.id ?
                                    Color.blue.opacity(0.1) : Color.clear
                            )
                    }
                }
                .listStyle(PlainListStyle())
            }
        }
    }
    
    private func toggleFilter(_ type: MQTTBroker.DataType) {
        if filterType == type {
            filterType = nil
        } else {
            filterType = type
        }
    }
}

struct TypeFilterButton: View {
    let icon: String
    let label: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                Text(label)
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 12)
            .background(isSelected ? color.opacity(0.2) : Color(.systemGray6))
            .foregroundColor(isSelected ? color : .primary)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(isSelected ? color : Color.clear, lineWidth: 1)
            )
        }
    }
}

struct DataPointRow: View {
    let dataPoint: MQTTBroker.DataPoint
    let mqttBroker: MQTTBroker
    
    var body: some View {
        HStack {
            Image(systemName: dataPoint.type.iconName)
                .foregroundColor(dataPoint.type.color)
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(dataPoint.name)
                    .font(.headline)
                
                Text(dataPoint.path)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            Text(mqttBroker.getFormattedValue(for: dataPoint))
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 6)
    }
}

struct GenericModuleConfigSheet: View {
    let moduleType: ControlType
    @Binding var selectedDataPoint: MQTTBroker.DataPoint?
    @Binding var displayName: String
    @Binding var message: String
    @Binding var minValue: Double
    @Binding var maxValue: Double
    let onSave: () -> Void
    let onCancel: () -> Void
    
    @ObservedObject var mqttBroker = MQTTBroker.shared
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Module Configuration")) {
                    TextField("Display Name", text: $displayName)
                    
                    NavigationLink(destination: EnhancedDataPointSelector(
                        mqttBroker: mqttBroker,
                        selectedDataPoint: $selectedDataPoint
                    )) {
                        if let dataPoint = selectedDataPoint {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Selected Data Point")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                HStack {
                                    Image(systemName: dataPoint.type.iconName)
                                        .foregroundColor(dataPoint.type.color)
                                    
                                    VStack(alignment: .leading) {
                                        Text(dataPoint.name)
                                            .font(.body)
                                        
                                        Text(dataPoint.path)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        } else {
                            Text("Select a Data Point")
                                .foregroundColor(.blue)
                        }
                    }
                }
                
                Section(header: Text("Control Settings")) {
                    switch moduleType {
                    case .button:
                        TextField("Button Message", text: $message)
                    case .toggle:
                        TextField("ON Message", text: $message)
                    case .slider:
                        HStack {
                            Text("Min:")
                            TextField("Min Value", value: $minValue, formatter: NumberFormatter())
                        }
                        HStack {
                            Text("Max:")
                            TextField("Max Value", value: $maxValue, formatter: NumberFormatter())
                        }
                    case .dataDisplay:
                        Text("This module will display values from the selected data point")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                if let dataPoint = selectedDataPoint {
                    Section(header: Text("Current Value")) {
                        HStack {
                            Text(mqttBroker.getFormattedValue(for: dataPoint))
                                .font(.system(.body, design: .monospaced))
                            
                            Spacer()
                    
                            Button(action: {
                                mqttBroker.objectWillChange.send()
                            }) {
                                Image(systemName: "arrow.clockwise")
                            }
                        }
                    }
                }
            }
            .navigationBarTitle("Configure Module", displayMode: .inline)
            .navigationBarItems(
                leading: Button("Cancel", action: onCancel),
                trailing: Button("Save", action: onSave)
                    .disabled(selectedDataPoint == nil)
            )
        }
    }
}

