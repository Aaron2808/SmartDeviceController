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
    let type: String
}

struct DeviceControlView: View {
    let device: Device
    @State private var controls: [DeviceControl] = []
    @State private var isAddingControl = false
    @ObservedObject var mqttBroker = MQTTBroker.shared

    var body: some View {
        VStack {
            List {
                ForEach(controls) { control in
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Topic: \(control.topic)")
                                .font(.headline)
                            Text("Type: \(control.controlType.rawValue)")
                                .foregroundColor(.gray)
                        }
                        Spacer()
                        renderControl(control)
                    }
                    .padding(.vertical, 5)
                }
                .onDelete(perform: deleteControl)
            }
            
            Spacer()
            
            Button(action: { isAddingControl = true }) {
                Label("Add Control", systemImage: "plus")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding()
        }
        .navigationTitle(device.name)
        .sheet(isPresented: $isAddingControl) {
            AddControlView(controls: $controls, deviceId: device.id, saveControls: saveControls)
        }
        .onAppear {
            loadControls()
        }
    }

    @ViewBuilder
    private func renderControl(_ control: DeviceControl) -> some View {
        let controlIndex = controls.firstIndex(where: { $0.id == control.id })!

        switch control.controlType {
        case .button:
            Button("Send Message") {
                sendMessage(control)
            }
            .buttonStyle(.bordered)
        
        case .slider:
            Slider(
                value: Binding(
                    get: { Double(controls[controlIndex].message) ?? 0 },
                    set: { newValue in
                        controls[controlIndex].message = "\(Int(newValue))"
                        sendMessage(controls[controlIndex], "\(Int(newValue))")
                    }
                ),
                in: 0...100
            )
            .padding()

        case .toggle:
            Toggle("Toggle", isOn: Binding(
                get: { controls[controlIndex].message.lowercased() == "on" },
                set: { newValue in
                    controls[controlIndex].message = newValue ? "ON" : "OFF"
                    sendMessage(controls[controlIndex], newValue ? "ON" : "OFF")
                }
            ))
        }
    }



    private func sendMessage(_ control: DeviceControl, _ customMessage: String? = nil) {
        let messageToSend = customMessage ?? control.message
        print("Sending '\(messageToSend)' to topic '\(control.topic)'")
        mqttBroker.publish(topic: control.topic, message: messageToSend)
    }

    private func deleteControl(at offsets: IndexSet) {
        controls.remove(atOffsets: offsets)
        saveControls()
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

#Preview{
    DeviceControlView(device: Device(id: 1, name: "Smart Light", type: "Light"))
}
