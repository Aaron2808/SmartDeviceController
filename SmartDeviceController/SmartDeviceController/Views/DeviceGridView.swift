//
//  DeviceGridView.swift
//  SmartDeviceController
//
//  Created by Aaron Flynn on 02/02/2025.
//

import SwiftUI

struct DeviceCard: View {
    let device: Device
    
    var body: some View {
        VStack {
            Text(device.name)
                .font(.headline)
                .foregroundColor(.primary)
            Image("light").frame(width:30, height:30)
            Text(device.type)
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .shadow(radius: 2)
    }
}

struct DeviceGridView: View {
    @State private var settingView: Bool = false
    
    @State private var devices: [Device] = [
        Device(id: 1, name: "Smart Light", type: "Light"),
        Device(id: 2, name: "Thermostat", type: "HVAC"),
        Device(id: 3, name: "Smart Plug", type: "Plug"),
        Device(id: 4, name: "Security Camera", type: "Camera")
    ]
    
    let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]
    
    var body: some View {
        NavigationStack { 
            VStack {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 20) {
                        ForEach(devices) { device in
                            NavigationLink(destination: DeviceControlView(device: device)) {
                                DeviceCard(device: device)
                            }
                            .contextMenu {
                                Button(role: .destructive) {
                                    deleteDevice(device)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .padding()
                }
                .navigationTitle("Devices")
                
                Button(action: {
                    settingView = true
                }) {
                    Text("Settings")
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.red)
                        .cornerRadius(8)
                }
                .padding()
                .navigationDestination(isPresented: $settingView) {
                    SettingsView()
                }
            }
        }
    }
    
    private func deleteDevice(_ device: Device) {
        devices.removeAll { $0.id == device.id }
    }
}

#Preview{
    DeviceGridView()
}
