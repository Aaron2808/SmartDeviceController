//
//  DeviceControlView.swift
//  SmartDeviceController
//
//  Created by Aaron Flynn on 02/02/2025.
//

import SwiftUI


struct DeviceControlView: View {
    let device: Device
    @State private var controls: [DeviceControl] = []
    @State private var isAddingControl = false
    @State private var isEditingControl = false
    @State private var controlToEdit: DeviceControl? = nil
    @State private var editIndex: Int = -1
    
    @ObservedObject var mqttBroker = MQTTBroker.shared
    
    private let columns = [
        GridItem(.adaptive(minimum: 160), spacing: 16)
    ]

    var body: some View {
        VStack(spacing: 0) {
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
            
            if controls.isEmpty {
                VStack(spacing: 20) {
                    Spacer()
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 60))
                        .foregroundColor(.secondary)
                    
                    Text("No controls")
                        .font(.title3)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(Array(controls.enumerated()), id: \.element.id) { index, control in
                            ControlView(control: control, onAction: { message in
                                sendMessage(control, message)
                            })
                            .contextMenu {
                                Button(action: {
                                    editControl(control, at: index)
                                }) {
                                    Label("Edit", systemImage: "pencil")
                                }
                                
                                Button(role: .destructive, action: {
                                    if index < controls.count {
                                        controls.remove(at: index)
                                        saveControls()
                                    }
                                }) {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .onLongPressGesture(minimumDuration: 0.5) {
                                editControl(control, at: index)
                            }
                        }
                    }
                    .padding()
                }
                .id("control_grid_\(mqttBroker.dataUpdateIdentifier)")
            }
            
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
        .sheet(
            isPresented: $isEditingControl,
            onDismiss: {
                editIndex = -1
            }
        ) {
            if let controlToEdit = self.controlToEdit, editIndex >= 0 && editIndex < controls.count {
                EditControlView(
                    control: controlToEdit,
                    onSave: { updatedControl in
                        controls[editIndex] = updatedControl
                        saveControls()
                        isEditingControl = false
                    },
                    onCancel: {
                        isEditingControl = false
                    }
                )
            } else {
                Text("Error: No control selected for editing")
                    .padding()
                    .onAppear {
                        isEditingControl = false
                    }
            }
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
    
    private func editControl(_ control: DeviceControl, at index: Int) {
        let editableControl = control
        self.controlToEdit = editableControl
        self.editIndex = index
        self.isEditingControl = true
    }
}

struct EditModule: View {
    let control: DeviceControl
    let onEdit: () -> Void
    let onAction: (String) -> Void
    
    @State private var isLongPressing = false
    @State private var animationAmount: CGFloat = 1.0
    
    var body: some View {
        ControlView(control: control, onAction: onAction)
            .scaleEffect(animationAmount)
            .shadow(color: isLongPressing ? control.getCustomColor().opacity(0.5) : Color.clear,
                    radius: isLongPressing ? 8 : 0)
            .gesture(
                LongPressGesture(minimumDuration: 0.5)
                    .onChanged { _ in
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isLongPressing = true
                            animationAmount = 0.95
                        }
                    }
                    .onEnded { _ in
                        withAnimation(.spring()) {
                            isLongPressing = false
                            animationAmount = 1.0
                        }
                        onEdit()
                    }
            )
            .overlay(
                ZStack {
                    if isLongPressing {
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(control.getCustomColor(), lineWidth: 2)
                            .background(Color.black.opacity(0.1).cornerRadius(12))
                        
                        Image(systemName: "pencil.circle.fill")
                            .font(.system(size: 36))
                            .foregroundColor(control.getCustomColor())
                            .opacity(0.8)
                    }
                }
            )
    }
}



#Preview {
    NavigationView {
        DeviceControlView(device: Device(id: 1, name: "Smart Light", location: "Living Room", color: .blue, image: "lightbulb.fill"))
    }
}
