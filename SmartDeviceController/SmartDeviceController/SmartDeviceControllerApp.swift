//
//  SmartDeviceControllerApp.swift
//  SmartDeviceController
//
//  Created by Aaron Flynn on 13/01/2025.
//

import SwiftUI

@main
struct SmartDeviceControllerApp: App {
    @StateObject private var mqttManager = MQTTBroker.shared
        
        var body: some Scene {
            WindowGroup {
                DeviceGridView()
                    .onAppear {
                        mqttManager.connect()
                    }
            }
        }
}
