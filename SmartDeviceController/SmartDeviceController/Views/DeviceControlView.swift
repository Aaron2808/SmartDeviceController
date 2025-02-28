//
//  DeviceControlView.swift
//  SmartDeviceController
//
//  Created by Aaron Flynn on 02/02/2025.
//

import SwiftUI

struct Device: Identifiable {
    let id: Int
    let name: String
    let location: String
    let color: Color
    let image: String
}

struct DeviceControlView: View {
    let device: Device
    @State private var controls: [DeviceControl] = []
    @State private var isAddingControl = false
    @ObservedObject var mqttBroker = MQTTBroker.shared
    
    // Add grid layout for better control display
    private let columns = [
        GridItem(.adaptive(minimum: 160), spacing: 16)
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Header with device info
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(device.name)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text(device.location)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: device.image)
                    .font(.title)
                    .foregroundColor(device.color)
                    .padding(12)
                    .background(device.color.opacity(0.2))
                    .clipShape(Circle())
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            
            // Controls display - use ScrollView instead of List for better customization
            if controls.isEmpty {
                VStack(spacing: 20) {
                    Spacer()
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 60))
                        .foregroundColor(.secondary)
                    
                    Text("No controls added yet")
                        .font(.title3)
                        .foregroundColor(.secondary)
                    
                    Text("Tap the button below to add your first control")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(controls) { control in
                            ControlModuleView(control: control, onAction: { message in
                                sendMessage(control, message)
                            })
                            .contextMenu {
                                Button(role: .destructive, action: {
                                    if let index = controls.firstIndex(where: { $0.id == control.id }) {
                                        controls.remove(at: index)
                                        saveControls()
                                    }
                                }) {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
            
            // Add control button
            Button(action: { isAddingControl = true }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                    Text("Add Control Module")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(device.color)
                .foregroundColor(.white)
                .cornerRadius(12)
                .shadow(color: device.color.opacity(0.3), radius: 5, x: 0, y: 3)
            }
            .padding()
        }
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isAddingControl) {
            AddControlView(controls: $controls, deviceId: device.id, saveControls: saveControls)
        }
        .onAppear {
            loadControls()
        }
    }

    private func sendMessage(_ control: DeviceControl, _ customMessage: String? = nil) {
        let messageToSend = customMessage ?? control.message
        print("Sending '\(messageToSend)' to topic '\(control.topic)'")
        mqttBroker.publish(topic: control.topic, message: messageToSend)
    }

    private func saveControls() {
        if let encoded = try? JSONEncoder().encode(controls) {
            UserDefaults.standard.set(encoded, forKey: "controls_\(device.id)")
        }
    }

    private func loadControls() {
        if let savedData = UserDefaults.standard.data(forKey: "controls_\(device.id)"),
           let decoded = try? JSONDecoder().decode([DeviceControl].self, from: savedData) {
            controls = decoded
        }
    }
}

// Individual control module view
struct ControlModuleView: View {
    let control: DeviceControl
    let onAction: (String) -> Void
    
    @State private var sliderValue: Double = 0
    @State private var isToggleOn: Bool = false
    @State private var dataValue: String = "--"
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header with title and icon
            HStack {
                Text(control.displayName.isEmpty ? control.topic : control.displayName)
                    .font(.headline)
                    .lineLimit(1)
                
                Spacer()
                
                Image(systemName: iconForControlType(control.controlType))
                    .foregroundColor(colorForControlType(control.controlType))
            }
            .padding(.bottom, 4)
            
            // Control specific UI
            renderControlContent()
                .frame(height: 60)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(colorForControlType(control.controlType).opacity(0.5), lineWidth: 2)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 1)
        .onAppear {
            // Initialize state values based on control properties
            if control.controlType == .slider {
                sliderValue = Double(control.message) ?? control.minValue
            } else if control.controlType == .toggle {
                isToggleOn = control.message.lowercased() == "on"
            } else if control.controlType == .temperatureDisplay || control.controlType == .dataDisplay {
                
                Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
                    if control.controlType == .temperatureDisplay {
                        dataValue = "\(Int.random(in: 18...28))°C"
                    } else {
                        dataValue = "\(Int.random(in: 30...95))%"
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private func renderControlContent() -> some View {
        switch control.controlType {
        case .button:
            Button(action: {
                onAction(control.message)
            }) {
                Text(control.message.isEmpty ? "Send" : control.message)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(colorForControlType(.button))
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            
        case .slider:
            VStack {
                Slider(
                    value: Binding(
                        get: { sliderValue },
                        set: { newValue in
                            sliderValue = newValue
                            onAction("\(Int(newValue))")
                        }
                    ),
                    in: control.minValue...control.maxValue
                )
                
                Text("\(Int(sliderValue))")
                    .font(.caption)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            
        case .toggle:
            Toggle("", isOn: Binding(
                get: { isToggleOn },
                set: { newValue in
                    isToggleOn = newValue
                    onAction(newValue ? "ON" : "OFF")
                }
            ))
            .labelsHidden()
            .tint(colorForControlType(.toggle))
            
        case .temperatureDisplay:
            VStack {
                Text(dataValue)
                    .font(.system(size: 32, weight: .medium))
                    .foregroundColor(colorForControlType(.temperatureDisplay))
                
                Text("Temperature")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            
        case .dataDisplay:
            VStack {
                Text(dataValue)
                    .font(.system(size: 32, weight: .medium))
                    .foregroundColor(colorForControlType(.dataDisplay))
                
                Text("Humidity")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
        }
    }
    
    // Helper functions for styling controls
    private func iconForControlType(_ type: ControlType) -> String {
        switch type {
        case .button:
            return "button.programmable"
        case .slider:
            return "slider.horizontal.3"
        case .toggle:
            return "switch.2"
        case .temperatureDisplay:
            return "thermometer"
        case .dataDisplay:
            return "chart.bar"
        }
    }
    
    private func colorForControlType(_ type: ControlType) -> Color {
        switch type {
        case .button:
            return .blue
        case .slider:
            return .orange
        case .toggle:
            return .green
        case .temperatureDisplay:
            return .red
        case .dataDisplay:
            return .purple
        }
    }
}

#Preview {
    NavigationView {
        DeviceControlView(device: Device(id: 1, name: "Smart Light", location: "Living Room", color: .blue, image: "lightbulb.fill"))
    }
}
