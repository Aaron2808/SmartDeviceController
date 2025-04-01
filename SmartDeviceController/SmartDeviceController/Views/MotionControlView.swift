import SwiftUI

struct MotionConfiguratorView: View {
    let deviceId: Int
    let control: DeviceControl
    @Environment(\.presentationMode) var presentationMode
    
    @ObservedObject private var motionManager = MotionControlManager.shared
    @ObservedObject private var mqttBroker = MQTTBroker.shared
    @State private var selectedMotionType: MotionType = .twist
    @State private var actionValue: String = ""
    @State private var showActionSheet = false
    @State private var showActionTypeSheet = false
    @State private var showHelp = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Configure Motion")) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Control: \(control.displayName)")
                            .font(.headline)
                        
                        Text("Topic: \(control.topic)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                    
                    Picker("Motion Type", selection: $selectedMotionType) {
                        ForEach(MotionType.allCases) { motionType in
                            HStack {
                                Image(systemName: motionType.iconName)
                                Text(motionType.rawValue)
                            }
                            .tag(motionType)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    
                }
                
                Section(header: Text("Action")) {
                    VStack(alignment: .leading, spacing: 12) {
                        switch control.controlType {
                        case .button:
                            TextField("Button Message", text: $actionValue)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                                .onAppear {
                                    if actionValue.isEmpty {
                                        actionValue = control.message
                                    }
                                }
        
                        case .toggle:
                            let onMessage = getToggleOnMessage(from: control.message)
                            let offMessage = getToggleOffMessage(from: control.message)
                            
                            Picker("Toggle Action", selection: $actionValue) {
                                Text("Turn ON").tag(onMessage)
                                Text("Turn OFF").tag(offMessage)
                                Text("Toggle").tag("toggle")
                            }
                            .pickerStyle(SegmentedPickerStyle())
                            .onAppear {
                                if actionValue.isEmpty {
                                    actionValue = "toggle"
                                }
                            }
                            
                            Text("Choose what happens when the motion is detected.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.top, 4)
                            
                        case .slider:
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Motion Control:")
                                    .font(.subheadline)
                                
                        
                                Button(action: {
                                    actionValue = "motion:enabled"
                                }) {
                                    HStack {
                                        Image(systemName: "gyroscope")
                                            .foregroundColor(.blue)
                                        Text("Enable Motion Control")
                                            .foregroundColor(.blue)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color.blue.opacity(0.1))
                                    )
                                    .padding(.vertical, 4)
                                }
                                .onAppear {
                                    // Default to motion enabled
                                    actionValue = "motion:enabled"
                                }
                                
                                Text("Motion direction controls slider: twist or tilt left to decrease, right to increase")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.top, 4)
                            }
                            
                        case .dataDisplay:
                            Text("Data display controls cannot have motion actions")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Section(header: Text("How to Use")) {
                    VStack(alignment: .leading, spacing: 8) {
                        switch selectedMotionType {
                        case .twist:
                            Text("Twist your device left or right like turning a steering wheel.")
                                .font(.callout)
                                .foregroundColor(.secondary)
                            
                            if control.controlType == .slider {
                                Text("• Twist left to decrease value")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Text("• Twist right to increase value")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                        case .tilt:
                            Text("Tilt your device left or right (side to side).")
                                .font(.callout)
                                .foregroundColor(.secondary)
                            
                            if control.controlType == .slider {
                                Text("• Tilt left to decrease value")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Text("• Tilt right to increase value")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                        case .shake:
                            Text("Shake your device to trigger the action.")
                                .font(.callout)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                Section {
                    Button(action: saveMotionAction) {
                        Text("Save")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    
                    let existingAction = motionManager.getMotionAction(forControl: control.id)
                    if existingAction != nil {
                        Button(action: {
                            if let action = existingAction {
                                motionManager.removeMotionAction(id: action.id)
                                presentationMode.wrappedValue.dismiss()
                            }
                        }) {
                            Text("Remove This Motion Action")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.red)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                    }
                }
                .listRowInsets(EdgeInsets())
                .padding()
            }
            .navigationBarTitle("Configure Motion", displayMode: .inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button(action: {
                    showHelp = true
                }) {
                    Image(systemName: "questionmark.circle")
                }
            )
            .onAppear(perform: loadExistingAction)
            .actionSheet(isPresented: $showActionSheet) {
                var buttons: [ActionSheet.Button] = []
                
                // Add buttons for different slider values
                let valueSteps = 5
                let valueRange = Int(control.maxValue - control.minValue)
                let stepSize = valueRange / valueSteps
                
                for i in 0...valueSteps {
                    let value = Int(control.minValue) + (i * stepSize)
                    buttons.append(.default(Text("\(value)")) {
                        actionValue = "set:\(value)"
                    })
                }
                
                buttons.append(.cancel())
                
                return ActionSheet(
                    title: Text("Set Slider Value"),
                    message: Text("Select a value to set when motion is detected"),
                    buttons: buttons
                )
            }
            
        }
    }
    
    private func loadExistingAction() {
        if let action = motionManager.getMotionAction(forControl: control.id) {
            if let motionType = MotionType.allCases.first(where: { $0.rawValue == action.motionType }) {
                selectedMotionType = motionType
            }
            actionValue = action.actionValue
        }
    }
    
    
    private func saveMotionAction() {
        if control.controlType == .dataDisplay {
            // Data display controls cannot have motion actions
            presentationMode.wrappedValue.dismiss()
            return
        }
        
        motionManager.addMotionAction(
            deviceId: deviceId,
            controlId: control.id,
            motionType: selectedMotionType,
            actionValue: actionValue
        )
        
        // Provide success feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        presentationMode.wrappedValue.dismiss()
    }
    
    // Added helper functions to fix the "cannot find in scope" errors
    private func getToggleOnMessage(from configString: String) -> String {
        if configString.contains("|") {
            let parts = configString.split(separator: "|", maxSplits: 1)
            return String(parts[0])
        }
        return configString.isEmpty ? "on" : configString
    }
    
    private func getToggleOffMessage(from configString: String) -> String {
        if configString.contains("|") {
            let parts = configString.split(separator: "|", maxSplits: 1)
            return parts.count > 1 ? String(parts[1]) : "off"
        }
        return "off"
    }
}

// Help sheet explaining motion controls

struct MotionConfiguratorView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Button control preview
            MotionConfiguratorView(
                deviceId: 1,
                control: sampleControl(type: .button)
            )
            .previewDisplayName("Button Control")
            
            // Toggle control preview
            MotionConfiguratorView(
                deviceId: 1,
                control: sampleControl(type: .toggle)
            )
            .previewDisplayName("Toggle Control")
            
            // Slider control preview
            MotionConfiguratorView(
                deviceId: 1,
                control: sampleControl(type: .slider)
            )
            .previewDisplayName("Slider Control")
            
            // Data display control preview
            MotionConfiguratorView(
                deviceId: 1,
                control: sampleControl(type: .dataDisplay)
            )
            .previewDisplayName("Data Display")
            
            // Dark mode preview
            MotionConfiguratorView(
                deviceId: 1,
                control: sampleControl(type: .slider)
            )
            .preferredColorScheme(.dark)
            .previewDisplayName("Dark Mode")
        }
    }
    
    // Helper function to create sample controls for previewing
    static func sampleControl(type: ControlType) -> DeviceControl {
        switch type {
        case .button:
            return DeviceControl(
                id: 1,
                topic: "home/living_room/light",
                message: "ON",
                controlType: .button,
                displayName: "Living Room Light",
                minValue: 0,
                maxValue: 0,
                dataPointId: nil,
                customColor: "#0066FF",
                customIcon: "lightbulb.fill",
                customUnit: nil,
                backgroundColor: nil,
                textColor: nil
            )
            
        case .toggle:
            return DeviceControl(
                id: 2,
                topic: "home/living_room/switch",
                message: "ON|OFF",
                controlType: .toggle,
                displayName: "Living Room Switch",
                minValue: 0,
                maxValue: 1,
                dataPointId: nil,
                customColor: "#00CC00",
                customIcon: "switch.2",
                customUnit: nil,
                backgroundColor: nil,
                textColor: nil
            )
            
        case .slider:
            return DeviceControl(
                id: 3,
                topic: "home/living_room/dimmer",
                message: "brightness",
                controlType: .slider,
                displayName: "Living Room Dimmer",
                minValue: 0,
                maxValue: 100,
                dataPointId: nil,
                customColor: "#FF9900",
                customIcon: "slider.horizontal.3",
                customUnit: nil,
                backgroundColor: nil,
                textColor: nil
            )
            
        case .dataDisplay:
            return DeviceControl(
                id: 4,
                topic: "home/living_room/temperature",
                message: "",
                controlType: .dataDisplay,
                displayName: "Living Room Temperature",
                minValue: 0,
                maxValue: 0,
                dataPointId: "home/living_room/temperature",
                customColor: "#9900CC",
                customIcon: "thermometer",
                customUnit: "°C",
                backgroundColor: nil,
                textColor: nil
            )
        }
    }
}
