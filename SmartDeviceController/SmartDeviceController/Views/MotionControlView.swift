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
    @State private var showMotionTestView = false
    @State private var showMotionSettings = false
    @State private var sliderValue: Double = 50

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
                    if control.controlType == .button {
                        buttonActionConfig()
                    } else if control.controlType == .toggle {
                        toggleActionConfig()
                    } else if control.controlType == .slider {
                        sliderActionConfig()
                    } else {
                        Text("Data display controls cannot have motion actions")
                            .foregroundColor(.secondary)
                    }
                }
                
                if control.controlType == .slider {
                    Section(header: Text("Preview")) {
                        VStack(spacing: 12) {
                            Text("Motion will control the slider:")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Slider(value: $sliderValue, in: control.minValue...control.maxValue)
                                .accentColor(control.getCustomColor())
                                .disabled(true)
                            
                            HStack {
                                VStack {
                                    Image(systemName: selectedMotionType == .twist ? "rotate.left" : "iphone.gen3.slash")
                                        .foregroundColor(.blue)
                                    Text("Decrease")
                                        .font(.caption)
                                }
                                
                                Spacer()
                                
                                VStack {
                                    Image(systemName: selectedMotionType == .twist ? "rotate.right" : "iphone.gen3")
                                        .foregroundColor(.blue)
                                    Text("Increase")
                                        .font(.caption)
                                }
                            }
                            .padding(.horizontal, 8)
                        }
                    }
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
                }
            )
            .onAppear(perform: loadExistingAction)
        }
    }
        
    private func buttonActionConfig() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(selectedMotionType.rawValue) your device to press the button")
                .font(.body)
        }
        .onAppear {
            actionValue = control.message
        }
    }
    
    private func toggleActionConfig() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(selectedMotionType.rawValue) your device to toggle the control")
                .font(.body)
        }
        .onAppear {
            actionValue = "toggle"
        }
    }
    
    private func sliderActionConfig() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(selectedMotionType.rawValue) your device to control the slider value")
                .font(.body)
        }
        .onAppear {
            actionValue = "motion:enabled"
        }
    }
    
    private func loadExistingAction() {
        if let action = motionManager.getMotionAction(forControl: control.id) {
            if let motionType = MotionType.allCases.first(where: { $0.rawValue == action.motionType }) {
                selectedMotionType = motionType
            }
            actionValue = action.actionValue
        } else {
            if control.controlType == .button {
                actionValue = control.message
            } else if control.controlType == .toggle {
                actionValue = "toggle"
            } else if control.controlType == .slider {
                actionValue = "motion:enabled"
            }
        }
    }
    
    private func saveMotionAction() {
        if control.controlType == .dataDisplay {
            presentationMode.wrappedValue.dismiss()
            return
        }
        
        motionManager.addMotionAction(
            deviceId: deviceId,
            controlId: control.id,
            motionType: selectedMotionType,
            actionValue: actionValue
        )
        
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        presentationMode.wrappedValue.dismiss()
    }
}

struct MotionConfiguratorView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            MotionConfiguratorView(
                deviceId: 1,
                control: sampleControl(type: .button)
            )
            .previewDisplayName("Button Control")
            
            MotionConfiguratorView(
                deviceId: 1,
                control: sampleControl(type: .toggle)
            )
            .previewDisplayName("Toggle Control")
            
            MotionConfiguratorView(
                deviceId: 1,
                control: sampleControl(type: .slider)
            )
            .previewDisplayName("Slider Control")
            
            MotionConfiguratorView(
                deviceId: 1,
                control: sampleControl(type: .dataDisplay)
            )
            .previewDisplayName("Data Display")
        }
    }
    
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
