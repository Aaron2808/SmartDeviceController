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
        VStack(spacing:0) {
            Rectangle()
                .fill()
                .foregroundStyle(device.color)
                .frame(height: 10)
                .frame(maxWidth: .infinity)
            
            Text(device.name)
                .font(.system(size: 16).bold())
                .foregroundColor(.primary)
                .padding(.top, 10)
               
            Spacer()
            
            Image(systemName: device.image)
                .resizable()
                .scaledToFit()
                .foregroundStyle(.black.opacity(0.6))
                .frame(width: 35, height: 35)
            
            Spacer()
            
            Text(device.location)
                .font(.subheadline)
                .foregroundColor(.black.opacity(0.7))
                .padding(.bottom, 10)
        }
        .frame(width: 150, height: 150, alignment: .top)
        .background(.white)
        .cornerRadius(10)
        .shadow(radius: 2)
    }

}

import SwiftUI

struct DeviceGridView: View {
    @State private var settingView: Bool = false
    @State private var showAddDeviceForm = false
    @State private var showMQTTDevices = false
    @State private var isConnecting = false
    
    // Fix: Use a consistent reference to the shared MQTTBroker instance
    @ObservedObject private var mqttBroker = MQTTBroker.shared
    
    @State private var devices: [Device] = [
        Device(id: 1, name: "Smart Light", location: "Kitchen", color: .blue, image: "lightbulb"),
        Device(id: 2, name: "Thermostat", location: "Living Room", color: .yellow, image: "lightbulb"),
        Device(id: 3, name: "Smart Plug", location: "Kitchen", color: .red, image: "lightbulb"),
        Device(id: 4, name: "Security Camera", location: "Camera" ,color: .orange, image: "lightbulb")
    ]
    
    let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]
    
    var body: some View {
        NavigationStack {
            
            VStack(spacing: 0) {
                HStack {
                    Button(action: {
                       
                    }) {
                        Image(systemName: "list.bullet")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 25, height: 25)
                            .foregroundColor(.black).opacity(0.5)
                            .padding(30)
                    }
                    
                    Spacer()
                    
                    Text("Devices")
                        .font(.system(size: 25))
                        .bold()
                        .padding(30)
                
                    
                    Spacer()
                    
                    Button(action: {
                        settingView = true
                    }) {
                        Image(systemName: "gearshape")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 25, height: 25)
                            .foregroundColor(.black).opacity(0.5)
                            .padding(30)
                    }
                    .navigationDestination(isPresented: $settingView) {
                        SettingsView()
                            .navigationTitle("Settings")
                    }
                    
                }
                .frame(maxWidth: .infinity, maxHeight: 40)
                
                // Add connection status view here
                connectionStatusView
                    .padding(.horizontal)
                    .padding(.top, 4)
                
                VStack {
                    if(!devices.isEmpty){
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
                        }
                        .padding()
                        .background(.gray.opacity(0.1))
                    }
                    else{
                       
                        VStack{
                            Spacer()
                            Text("No Devices Available")
                                .foregroundColor(.black)
                            Spacer()
                        }
                        .frame(maxWidth:.infinity, maxHeight: .infinity)
                        .background(.gray.opacity(0.1))
                    }
                            
                
                    VStack{
                        Button(action: {
                            showAddDeviceForm = true
                        }) {
                            Text("Add Device")
                                .foregroundColor(.white)
                                .frame(width: 200, height:50)
                                .background(Color.blue)
                                .cornerRadius(15)
                        }
                        .padding()
                        .sheet(isPresented: $showAddDeviceForm) {
                            AddDeviceView { newDevice in
                                devices.append(newDevice)
                            }
                        }
                    }.frame(maxWidth: .infinity, maxHeight: 70)
                }
            }
        }
        .onAppear {
            // Fix: Use a proper cancellable task for connection attempt
            ensureConnected()
        }
    }
    
    private func deleteDevice(_ device: Device) {
        devices.removeAll { $0.id == device.id }
    }
    
    // Fix: Improved connection handling
    private func ensureConnected() {
        if !mqttBroker.isConnected {
            isConnecting = true
            
            // Attempt connection
            mqttBroker.autoConnect()
            
            // Use a proper timeout mechanism
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                self.isConnecting = false
                
                // If still not connected after timeout, show an error
                if !self.mqttBroker.isConnected {
                    print("Failed to connect automatically")
                    // You could add an alert or notification here
                }
            }
        }
    }
    
    var connectionStatusView: some View {
        Group {
            if isConnecting {
                HStack {
                    Text("Connecting to MQTT...")
                    ProgressView()
                }
                .padding(6)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
            } else if !mqttBroker.isConnected {
                Button("Connect") {
                    ensureConnected()
                }
                .padding(6)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
        }
        .frame(height: isConnecting || !mqttBroker.isConnected ? 36 : 0)
        .opacity(isConnecting || !mqttBroker.isConnected ? 1 : 0)
        .animation(.easeInOut(duration: 0.3), value: isConnecting || !mqttBroker.isConnected)
    }
}

#Preview{
    DeviceGridView()
}
