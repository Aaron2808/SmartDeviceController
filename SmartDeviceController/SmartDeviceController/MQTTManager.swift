//
//  MQTTBroker.swift
//  SmartDeviceController
//
//  Created by Aaron Flynn on 13/01/2025.

import CocoaMQTT
import SwiftUI

class MQTTBroker {
    var mqtt: CocoaMQTT?
    var hiveMQ: HiveMQ
    
    init() {
        let clientID = "iOS_Client_\(UUID().uuidString)"
        hiveMQ = HiveMQ()
        
        // Initialize CocoaMQTT
        mqtt = CocoaMQTT(clientID: clientID, host: hiveMQ.host, port: hiveMQ.port)
        mqtt?.username = hiveMQ.username // Replace with your HiveMQ Cloud username
        mqtt?.password = hiveMQ.password // Replace with your HiveMQ Cloud password
        mqtt?.logLevel = .debug
        
        mqtt?.enableSSL = true
        mqtt?.allowUntrustCACertificate = false
        
        mqtt?.willMessage = CocoaMQTTMessage(topic: "/will", string: "dieout")
        mqtt?.cleanSession = true
        mqtt?.keepAlive = 60
        
        mqtt?.delegate = self
        
    }
    
    func connect() {
        if mqtt?.connState == .connected {
            print("Already connected, skipping connection attempt.")
        } else {
            mqtt?.connect()
        }
    }
    
    func disconnect() {
        mqtt?.disconnect()
    }
}

// Extend MQTTBroker to conform to CocoaMQTTDelegate
extension MQTTBroker: CocoaMQTTDelegate {
    func mqtt(_ mqtt: CocoaMQTT, didPublishAck id: UInt16) {
        print("")
    }
    
    func mqtt(_ mqtt: CocoaMQTT, didSubscribeTopics success: NSDictionary, failed: [String]) {
        print("")
    }
    
    func mqtt(_ mqtt: CocoaMQTT, didUnsubscribeTopics topics: [String]) {
        print("")
    }
    
    func mqttDidPing(_ mqtt: CocoaMQTT) {
        print("")
    }
    
    func mqttDidReceivePong(_ mqtt: CocoaMQTT) {
        print("")
    }
    
    func mqttDidDisconnect(_ mqtt: CocoaMQTT, withError err: (any Error)?) {
        print("")
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
        print("Received message: \(message.string ?? "") on topic: \(message.topic)")
    }

    func mqtt(_ mqtt: CocoaMQTT, didPublishMessage message: CocoaMQTTMessage, id: UInt16) {
        print("Message published successfully")
    }
}
