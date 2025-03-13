import SwiftUI

struct ModuleSelect: View {
    let moduleType: ControlType
    let topics: [String]
    @Binding var selectedTopic: String
    @Binding var message: String
    @Binding var minValue: Double
    @Binding var maxValue: Double
    @Binding var displayName: String
    @Binding var selectedDataPoint: MQTTBroker.DataPoint?
    @Binding var useDataPoint: Bool
    @Binding var customColor: String?
    @Binding var customIcon: String?
    @Binding var customUnit: String?
    @Binding var backgroundColor: String?
    @Binding var textColor: String?
    
    @State private var customTopicInput: String = ""
    @State private var useCustomTopic: Bool = false
    @State private var colorValue: Double = 0.5
    
    let onSave: () -> Void
    let onCancel: () -> Void
    
    @State private var showDataPointSelector = false
    @State private var showIconPicker = false
    
    var selectedColor: Color {
        Color(hue: colorValue * 0.83, saturation: 1, brightness: 1)
    }
    
    @ObservedObject private var mqttBroker = MQTTBroker.shared
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Basic Configuration")) {
                    TextField("Display Name", text: $displayName)
                    
                    if moduleType == .dataDisplay {
                        DataPointSelectionButton(
                            selectedDataPoint: selectedDataPoint,
                            dataPointId: nil,
                            action: { showDataPointSelector = true }
                        )
                    } else {
                        Toggle("Use Data Point", isOn: $useDataPoint)
                            .onChange(of: useDataPoint) { oldValue, newValue in
                                if !newValue {
                                    selectedDataPoint = nil
                                }
                            }
                        
                        if useDataPoint {
                            DataPointSelectionButton(
                                selectedDataPoint: selectedDataPoint,
                                dataPointId: nil,
                                action: { showDataPointSelector = true }
                            )
                        } else {
                            Toggle("Enter Custom Topic", isOn: $useCustomTopic)
                                .onChange(of: useCustomTopic) { oldValue, newValue in
                                    if newValue {
                                        customTopicInput = selectedTopic
                                    } else {
                                        selectedTopic = customTopicInput
                                    }
                                }
                            
                            if useCustomTopic {
                                TextField("Custom MQTT Topic", text: $customTopicInput)
                                    .autocapitalization(.none)
                                    .disableAutocorrection(true)
                                    .onChange(of: customTopicInput) { oldValue, newValue in
                                        selectedTopic = newValue
                                    }
                            } else {
                                Picker("MQTT Topic", selection: $selectedTopic) {
                                    Text("Select a Topic").tag("")
                                    ForEach(topics, id: \.self) { topic in
                                        Text(topic).tag(topic)
                                    }
                                }
                            }
                        }
                    }
                }
                
                Section(header: Text("Control Settings")) {
                    switch moduleType {
                        case .button:
                            TextField("Button Message", text: $message)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                        case .toggle:
                            VStack(spacing: 12) {
                                Text("Configure the messages to send when toggled ON/OFF")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.bottom, 4)
                                    
                                TextField("ON Message", text: Binding(
                                    get: {
                                        if message.contains("|") {
                                            let parts = message.split(separator: "|", maxSplits: 1)
                                            return String(parts[0])
                                        }
                                        return message.isEmpty ? "on" : message
                                    },
                                    set: { newValue in
                                        if message.contains("|") {
                                            let parts = message.split(separator: "|", maxSplits: 1)
                                            let offPart = parts.count > 1 ? String(parts[1]) : "off"
                                            message = "\(newValue)|\(offPart)"
                                        } else {
                                            message = "\(newValue)|off"
                                        }
                                    }
                                ))
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                
                                TextField("OFF Message", text: Binding(
                                    get: {
                                        if message.contains("|") {
                                            let parts = message.split(separator: "|", maxSplits: 1)
                                            return parts.count > 1 ? String(parts[1]) : "off"
                                        }
                                        return "off"
                                    },
                                    set: { newValue in
                                        if message.contains("|") {
                                            let parts = message.split(separator: "|", maxSplits: 1)
                                            let onPart = parts[0].isEmpty ? "on" : String(parts[0])
                                            message = "\(onPart)|\(newValue)"
                                        } else {
                                            let onPart = message.isEmpty ? "on" : message
                                            message = "\(onPart)|\(newValue)"
                                        }
                                    }
                                ))
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                            }
                    case .slider:
                        HStack {
                            Text("Min:")
                            TextField("Min Value", value: $minValue, formatter: NumberFormatter())
                        }
                        HStack {
                            Text("Max:")
                            TextField("Max Value", value: $maxValue, formatter: NumberFormatter())
                        }
                    case .dataDisplay:
                        if selectedDataPoint == nil {
                            Text("Please select a data point to display")
                                .foregroundColor(.secondary)
                        } else {
                            let detectedUnit = selectedDataPoint?.unit ?? "None"
                            HStack {
                                Text("Detected Unit:")
                                Spacer()
                                Text(detectedUnit)
                                    .foregroundColor(.secondary)
                            }
                            
                            Toggle("Use Custom Unit", isOn: Binding(
                                get: { customUnit != nil },
                                set: { newValue in
                                    if !newValue {
                                        customUnit = nil
                                    } else if customUnit == nil {
                                        customUnit = ""
                                    }
                                }
                            ))
                            
                            if customUnit != nil {
                                TextField("Custom Unit", text: Binding(
                                    get: { customUnit ?? "" },
                                    set: { customUnit = $0.isEmpty ? nil : $0 }
                                ))
                            }
                        }
                    }
                }
                
                Section(header: Text("Appearance")) {
                    Button(action: {
                        showIconPicker = true
                    }) {
                        HStack {
                            Text("Module Icon").foregroundColor(.black)
                            Spacer()
                            Image(systemName: customIcon ?? ControlHelpers.iconForControlType(moduleType))
                                .foregroundColor(selectedColor)
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }
                    .sheet(isPresented: $showIconPicker) {
                        IconPickerView(
                            availableIcons: ControlHelpers.availableIcons,
                            customIcon: $customIcon,
                            selectedColor: selectedColor,
                            onClose: { showIconPicker = false }
                        )
                    }
                    
                    ColorSliderView(colorValue: $colorValue, customColor: $customColor)
                }
                
                Section(header: Text("Preview")) {
                    VStack {
                        ControlView(
                            control: createPreviewControl(),
                            onAction: { _ in },
                            isPreview: true
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.vertical)
                    }
                }
            }
            .navigationBarTitle("Configure Module", displayMode: .inline)
            .navigationBarItems(
                leading: Button("Cancel", action: onCancel),
                trailing: Button("Save") {
                    saveModule()
                }
                .disabled(shouldDisableSaveButton)
            )
            .sheet(isPresented: $showDataPointSelector) {
                DataPointSelectorSheet(
                    mqttBroker: mqttBroker,
                    selectedDataPoint: $selectedDataPoint
                )
            }
            .onAppear {
                if moduleType == .dataDisplay {
                    useDataPoint = true
                }
                
                colorValue = ControlHelpers.initializeColorValue(
                    customColor: customColor,
                    controlType: moduleType
                )
                
                if customColor == nil {
                    customColor = selectedColor.toHex()
                }
            }
        }
    }
    
    private func createPreviewControl() -> DeviceControl {
        let previewTopic: String
        if useDataPoint, let dataPoint = selectedDataPoint {
            previewTopic = dataPoint.path
        } else if useCustomTopic {
            previewTopic = customTopicInput
        } else {
            previewTopic = selectedTopic
        }
        
        let previewMessage: String
        switch moduleType {
        case .button:
            previewMessage = message.isEmpty ? "Press" : message
        case .toggle:
            previewMessage = message.isEmpty ? "on" : message
        case .slider:
            previewMessage = "\(Int((minValue + maxValue) / 2))"
        default:
            previewMessage = ""
        }
        
        return DeviceControl(
            id: 999,
            topic: previewTopic,
            message: previewMessage,
            controlType: moduleType,
            displayName: displayName.isEmpty ? "Preview" : displayName,
            minValue: minValue,
            maxValue: maxValue,
            dataPointId: useDataPoint ? selectedDataPoint?.id : nil,
            customColor: customColor,
            customIcon: customIcon,
            customUnit: customUnit,
            backgroundColor: backgroundColor,
            textColor: textColor
        )
    }
    
    private var shouldDisableSaveButton: Bool {
        if moduleType == .dataDisplay {
            return selectedDataPoint == nil
        } else if useDataPoint {
            return selectedDataPoint == nil
        } else {
            return selectedTopic.isEmpty
        }
    }
    
    private func saveModule() {
        if useDataPoint, let dataPoint = selectedDataPoint {
            selectedTopic = dataPoint.path
        } else if useCustomTopic {
            selectedTopic = customTopicInput
        }
        
        customColor = selectedColor.toHex()
        
        onSave()
    }
}
