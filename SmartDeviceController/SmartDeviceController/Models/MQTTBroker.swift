import CocoaMQTT
import SwiftUI
import os.log

class MQTTBroker: ObservableObject {
    
    static let shared = MQTTBroker()
    
    
    private enum Constants {
        static let refreshInterval: TimeInterval = 30.0
        static let connectionRetryDelay: TimeInterval = 0.5
        static let connectionWaitTime: TimeInterval = 2.0
    }
    
    
    public var mqtt: CocoaMQTT?
    private var mqttConfig: MQTTConfig
    private var refreshTimer: Timer?
    private let logger = Logger(subsystem: "com.aaronflynn.SmartDeviceController", category: "MQTT")
    
    let clientID: String
    let hostAddress: String
    let port: UInt16
    
    @Published var topics: Set<String> = Set()
    @Published var groupedTopics: [String: [String: String]] = [:]
    @Published var topicData: [String: DataValue] = [:]
    @Published var deviceContexts: [String: DeviceContext] = [:]
    @Published var isConnected: Bool = false
    
    
    private init() {
        clientID = "iOS_Client_\(UUID().uuidString)"
        mqttConfig = MQTTConfig()
        
        hostAddress = mqttConfig.host
        port = mqttConfig.port
        
        setupMQTTClient()
    }
    
    private func setupMQTTClient() {
        mqtt = CocoaMQTT(clientID: clientID, host: hostAddress, port: port)
        mqtt?.username = mqttConfig.username
        mqtt?.password = mqttConfig.password
        
        mqtt?.willMessage = CocoaMQTTMessage(topic: "/will", string: "dieout")
        mqtt?.cleanSession = true
        mqtt?.keepAlive = 60
        
        mqtt?.delegate = self
    }
    
    func connect() {
        guard let mqtt = mqtt else {
            logger.error("MQTT client not initialized")
            return
        }
        
        if mqtt.connState == .connected {
            logger.info("Already connected, skipping connection attempt")
            return
        }
        
        let connectResult = mqtt.connect()
        if !connectResult {
            logger.error("Connection attempt failed")
        }
    }
    
    func disconnect() {
        guard let mqtt = mqtt else {
            logger.error("MQTT client not initialized")
            return
        }
        
        mqtt.disconnect()
        isConnected = false
        
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
    
    func searchTopics() {
        guard let mqtt = mqtt else {
            logger.error("MQTT client not initialized")
            return
        }
        
        logger.info("Subscribing to all topics")
        mqtt.subscribe("#")
    }
    
    
    func publish(topic: String, message: String) {
        guard let mqtt = mqtt else {
            logger.error("MQTT client not initialized")
            return
        }
        
        mqtt.publish(topic, withString: message, qos: .qos1, retained: false)
        logger.debug("Published message to topic \(topic): \(message)")
    }
    
    
    func subscribe(topic: String) {
        guard let mqtt = mqtt else {
            logger.error("MQTT client not initialized")
            return
        }
        
        mqtt.subscribe(topic, qos: .qos1)
        logger.info("Subscribed to topic: \(topic)")
    }
    
    func autoConnect() {
        logger.info("Starting MQTT auto-connection process")
        
        if mqtt?.connState == .connected {
            logger.info("Already connected to MQTT broker")
            isConnected = true
            searchTopics()
            setupPeriodicTopicRefresh()
            return
        }
        
        if mqtt?.connState != .disconnected {
            logger.warning("MQTT in unexpected state: \(String(describing: self.mqtt?.connState)). Forcing disconnect.")
            disconnect()
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + Constants.connectionRetryDelay) { [weak self] in
            guard let self = self else { return }
            
            logger.info("Initiating connection to MQTT broker")
            self.connect()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + Constants.connectionWaitTime) { [weak self] in
                guard let self = self else { return }
                
                if self.mqtt?.connState == .connected {
                    logger.info("Successfully connected to MQTT broker")
                    self.isConnected = true
                    self.searchTopics()
                    self.setupPeriodicTopicRefresh()
                } else {
                    logger.warning("Failed to connect on first attempt, retrying...")
                    
                    self.connect()
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + Constants.connectionWaitTime) { [weak self] in
                        guard let self = self else { return }
                        
                        if self.mqtt?.connState == .connected {
                            logger.info("Successfully connected on second attempt")
                            self.isConnected = true
                            self.searchTopics()
                            self.setupPeriodicTopicRefresh()
                        } else {
                            logger.error("Failed to connect automatically after multiple attempts")
                        }
                    }
                }
            }
        }
    }
    
    private func setupPeriodicTopicRefresh() {
        refreshTimer?.invalidate()
        
        refreshTimer = Timer.scheduledTimer(withTimeInterval: Constants.refreshInterval, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            if self.mqtt?.connState == .connected {
                logger.debug("Performing periodic topic refresh")
                self.searchTopics()
            } else {
                logger.warning("MQTT not connected during refresh cycle, attempting reconnection")
                self.connect()
            }
        }
        
        if let timer = refreshTimer {
            RunLoop.current.add(timer, forMode: .common)
        }
    }
    
    
    func getValue(topic: String) -> DataValue? {
        return topicData[topic]
    }
    
  
    func getValue(for dataPoint: DataPoint) -> DataValue? {
        return topicData[dataPoint.path]
    }
    
    
    func getDataByPath(_ path: String) -> DataValue? {
        if let value = topicData[path] {
            return value
        }
        
        let components = path.split(separator: "/")
        if components.count >= 3 {
            let baseTopic = components.dropLast().joined(separator: "/")
            let propertyName = String(components.last!)
            
            logger.debug("Looking for \(propertyName) in \(baseTopic)")
            
            if let baseValue = topicData[baseTopic], case .jsonObject(let dict) = baseValue {
                if let propValue = dict[propertyName] {
                    logger.debug("Found \(propertyName) in JSON: \(String(describing: propValue))")
                    
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
    
    
    func getAllDevices() -> [String] {
        return Array(deviceContexts.keys).sorted()
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
    
    private func processGenericMessage(topic: String, payload: String) {
        let topicComponents = topic.split(separator: "/")
        guard !topicComponents.isEmpty else { return }
        
        let deviceId = String(topicComponents[0])
        
        updateDeviceContext(deviceId: deviceId, topic: topic)
        
        logger.debug("Processing \(topic) with payload: \(payload.prefix(100))...")
        
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
                    } else if let intValue = value as? Int {
                        topicData[keyPath] = .number(Double(intValue))
                    } else if let boolValue = value as? Bool {
                        topicData[keyPath] = .boolean(boolValue)
                    } else if let strValue = value as? String {
                        topicData[keyPath] = .text(strValue)
                    } else if let objValue = value as? [String: Any] {
                        topicData[keyPath] = .jsonObject(objValue)
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
                self.objectWillChange.send()
            }
        }
    }
    
    private func processNestedObject(_ object: [String: Any], parentPath: String) {
        for (key, value) in object {
            let keyPath = "\(parentPath)/\(key)"
            
            if let numValue = value as? Double {
                topicData[keyPath] = .number(numValue)
            } else if let intValue = value as? Int {
                topicData[keyPath] = .number(Double(intValue))
            } else if let boolValue = value as? Bool {
                topicData[keyPath] = .boolean(boolValue)
            } else if let strValue = value as? String {
                topicData[keyPath] = .text(strValue)
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
}

// MARK: - CocoaMQTTDelegate Extension

extension MQTTBroker: CocoaMQTTDelegate {
    func mqtt(_ mqtt: CocoaMQTT, didPublishAck id: UInt16) {
        logger.debug("Publish acknowledged")
    }
    
    func mqtt(_ mqtt: CocoaMQTT, didSubscribeTopics success: NSDictionary, failed: [String]) {
        logger.debug("Subscribed to topics")
        if !failed.isEmpty {
            logger.error("Failed to subscribe to topics: \(failed)")
        }
    }
    
    func mqtt(_ mqtt: CocoaMQTT, didUnsubscribeTopics topics: [String]) {
        logger.debug("Unsubscribed from topics: \(topics)")
    }
    
    func mqttDidPing(_ mqtt: CocoaMQTT) {
        logger.debug("Sent ping")
    }
    
    func mqttDidReceivePong(_ mqtt: CocoaMQTT) {
        logger.debug("Received pong")
    }
    
    func mqttDidDisconnect(_ mqtt: CocoaMQTT, withError err: (any Error)?) {
        if let error = err {
            logger.error("Disconnected with error: \(error.localizedDescription)")
        } else {
            logger.info("Disconnected successfully")
        }
        
        DispatchQueue.main.async {
            self.isConnected = false
        }
    }
    
    func mqtt(_ mqtt: CocoaMQTT, didConnectAck ack: CocoaMQTTConnAck) {
        if ack == .accept {
            logger.info("Connected successfully to MQTT broker!")
            DispatchQueue.main.async {
                self.isConnected = true
            }
        } else {
            logger.error("Connection failed with ack: \(ack.rawValue).")
        }
    }

    func mqtt(_ mqtt: CocoaMQTT, didReceiveMessage message: CocoaMQTTMessage, id: UInt16) {
        let topic = message.topic
        let payload = message.string ?? "N/A"
        
        logger.debug("Received message on topic: \(topic)")
        
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
        logger.debug("Published message: \(message.topic)")
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
            case (.jsonObject, .jsonObject), (.jsonArray, .jsonArray): return false  // Cannot compare dictionaries/arrays
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
}
