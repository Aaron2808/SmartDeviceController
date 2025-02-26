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
    var hiveMQ: HiveMQ
    
    @Published var topics: Set<String> = Set()
    var clientID: String
    var hostAddress: String
    var port: UInt16
    
    @Published var groupedTopics: [String: [String: String]] = [:]
    
    init() {
        
        clientID = "iOS_Client_\(UUID().uuidString)"
        hiveMQ = HiveMQ()
        
        hostAddress = hiveMQ.host
        port = hiveMQ.port
        // Initialize CocoaMQTT
        mqtt = CocoaMQTT(clientID: clientID, host: hostAddress, port: port)
        mqtt?.username = hiveMQ.username // Replace with your HiveMQ Cloud username
        mqtt?.password = hiveMQ.password // Replace with your HiveMQ Cloud password
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
            mqtt?.connect()
        }
    }
    
    func searchTopics() {
            mqtt?.subscribe("#") // Subscribe to all topics
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
    
}

// Extend MQTTBroker to conform to CocoaMQTTDelegate
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
            print("Disconnected from HiveMQ Cloud. Error: \(error.localizedDescription)")
        } else {
            print("Disconnected successfully.")
        }
    }

    func mqtt(_ mqtt: CocoaMQTT, didReceiveMessage message: CocoaMQTTMessage, id: UInt16) {
        let topic = message.topic
        let payload = message.string ?? "N/A"
        
        let components = topic.split(separator: "/")
        guard components.count >= 2 else { return }
        
        let deviceID = String(components[0])
        let attribute = components.dropFirst().joined(separator: "/")
        
        DispatchQueue.main.async {
            if self.groupedTopics[deviceID] == nil {
                self.groupedTopics[deviceID] = [:]
            }
            self.groupedTopics[deviceID]?[attribute] = payload
        }
        
        print("Grouped Topics Updated: \(self.groupedTopics)")
    }

    func mqtt(_ mqtt: CocoaMQTT, didPublishMessage message: CocoaMQTTMessage, id: UInt16) {
        print("Message published successfully")
    }
}
