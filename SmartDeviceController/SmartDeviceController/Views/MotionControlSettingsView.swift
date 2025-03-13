//
//  MotionControlSettingsView.swift
//  SmartDeviceController
//
//  Created by Aaron Flynn on 13/03/2025.
//

import SwiftUI

struct MotionControlSettingsView: View {
    @ObservedObject private var motionManager = MotionControlManager.shared
    
    var body: some View {
        Form {
            Section(header: Text("Motion Controls")) {
                Toggle("Enable Motion Controls", isOn: $motionManager.isMotionEnabled)
                    .onChange(of: motionManager.isMotionEnabled) { _, _ in
                        motionManager.saveSettings()
                    }
                
                if motionManager.isMotionEnabled {
                    Text("Activate motion controls for sliders by tapping the gyroscope icon when adjusting a slider.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // You can add more settings for sensitivity, etc.
        }
        .navigationTitle("Motion Controls")
    }
}
