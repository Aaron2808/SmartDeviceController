import SwiftUI

struct ModuleSelect: View {
    let moduleType: ControlType
    let topics: [String]  // These topics should be pre-filtered for the device
    let deviceId: Int?    // Optional device ID for data point filtering
    
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
    @State private var readyToSave: Bool = false
    
    var selectedColor: Color {
        Color(hue: colorValue * 0.83, saturation: 1, brightness: 1)
    }
    
    @ObservedObject private var mqttBroker = MQTTBroker.shared
    
    // Initialize without deviceId for backward compatibility
    init(moduleType: ControlType, topics: [String], selectedTopic: Binding<String>, message: Binding<String>, minValue: Binding<Double>, maxValue: Binding<Double>, displayName: Binding<String>, selectedDataPoint: Binding<MQTTBroker.DataPoint?>, useDataPoint: Binding<Bool>, customColor: Binding<String?>, customIcon: Binding<String?>, customUnit: Binding<String?>, backgroundColor: Binding<String?>, textColor: Binding<String?>, onSave: @escaping () -> Void, onCancel: @escaping () -> Void) {
        self.moduleType = moduleType
        self.topics = topics
        self.deviceId = nil
        self._selectedTopic = selectedTopic
        self._message = message
        self._minValue = minValue
        self._maxValue = maxValue
        self._displayName = displayName
        self._selectedDataPoint = selectedDataPoint
        self._useDataPoint = useDataPoint
        self._customColor = customColor
        self._customIcon = customIcon
        self._customUnit = customUnit
        self._backgroundColor = backgroundColor
        self._textColor = textColor
        self.onSave = onSave
        self.onCancel = onCancel
    }
    
    // Initialize with deviceId for device-specific filtering
    init(moduleType: ControlType, topics: [String], deviceId: Int, selectedTopic: Binding<String>, message: Binding<String>, minValue: Binding<Double>, maxValue: Binding<Double>, displayName: Binding<String>, selectedDataPoint: Binding<MQTTBroker.DataPoint?>, useDataPoint: Binding<Bool>, customColor: Binding<String?>, customIcon: Binding<String?>, customUnit: Binding<String?>, backgroundColor: Binding<String?>, textColor: Binding<String?>, onSave: @escaping () -> Void, onCancel: @escaping () -> Void) {
        self.moduleType = moduleType
        self.topics = topics
        self.deviceId = deviceId
        self._selectedTopic = selectedTopic
        self._message = message
        self._minValue = minValue
        self._maxValue = maxValue
        self._displayName = displayName
        self._selectedDataPoint = selectedDataPoint
        self._useDataPoint = useDataPoint
        self._customColor = customColor
        self._customIcon = customIcon
        self._customUnit = customUnit
        self._backgroundColor = backgroundColor
        self._textColor = textColor
        self.onSave = onSave
        self.onCancel = onCancel
    }
    
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
                                if topics.isEmpty {
                                    Text("No topics available for this device")
                                        .foregroundColor(.secondary)
                                        .italic()
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
                    
                    // If a device is specified, show the device topic as info
                    if let deviceId = deviceId,
                       let device = DeviceManager.shared.getDevice(withId: deviceId),
                       let deviceTopic = device.mqttTopic,
                       !deviceTopic.isEmpty {
                        HStack {
                            Image(systemName: "link")
                                .foregroundColor(.blue)
                            Text("Device topic: \(deviceTopic)")
                                .font(.caption)
                                .foregroundColor(.blue)
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
                            VStack(spacing: 12) {
                                HStack {
                                    Text("Min:")
                                    TextField("Min Value", value: $minValue, formatter: NumberFormatter())
                                        .keyboardType(.numberPad)
                                }
                                
                                HStack {
                                    Text("Max:")
                                    TextField("Max Value", value: $maxValue, formatter: NumberFormatter())
                                        .keyboardType(.numberPad)
                                }
                                
                                // Add a test slider to verify configuration
                                if minValue < maxValue {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Test slider:")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        
                                        // Local state for test slider
                                        let testBinding = Binding<Double>(
                                            get: { (minValue + maxValue) / 2 },
                                            set: { _ in }
                                        )
                                        
                                        Slider(value: testBinding, in: minValue...maxValue)
                                            .accentColor(selectedColor)
                                            .disabled(true)
                                        
                                        HStack {
                                            Text("\(Int(minValue))")
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                            
                                            Spacer()
                                            
                                            Text("\(Int((minValue + maxValue) / 2))")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                            
                                            Spacer()
                                            
                                            Text("\(Int(maxValue))")
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    .padding(.vertical, 8)
                                }
                                
                                Divider()
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("JSON Payload (Optional)")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    
                                    HStack {
                                        Text("Property name:")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        
                                        TextField("brightness", text: $message)
                                            .autocapitalization(.none)
                                            .disableAutocorrection(true)
                                            .onChange(of: message) { oldValue, newValue in
                                                // Remove any JSON characters if user starts typing them
                                                if newValue.contains("{") || newValue.contains("}") || newValue.contains(":") {
                                                    let cleanedText = newValue
                                                        .replacingOccurrences(of: "{", with: "")
                                                        .replacingOccurrences(of: "}", with: "")
                                                        .replacingOccurrences(of: "\"", with: "")
                                                        .replacingOccurrences(of: ":", with: "")
                                                    message = cleanedText
                                                }
                                            }
                                    }
                                    
                                    if !message.isEmpty {
                                        // Show preview of the formatted payload
                                        let formattedPayload = "{\"\(message)\": \(Int((minValue + maxValue) / 2))}"
                                        
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Preview:")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                            
                                            Text(formattedPayload)
                                                .font(.system(.caption, design: .monospaced))
                                                .padding(6)
                                                .background(Color.blue.opacity(0.1))
                                                .cornerRadius(4)
                                        }
                                        .padding(.top, 8)
                                        
                                        Text("The value will be automatically inserted when slider moves")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    } else {
                                        Text("Leave empty to send raw value without JSON formatting")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
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
                            Text("Module Icon").foregroundColor(.primary)
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
                        ControlInterfaceView(
                            control: createPreviewControl(),
                            onAction: { _ in },
                            isPreview: true
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.vertical)
                    }
                }
                
                Section {
                    Button("Save") {
                        saveModule()
                    }
                    .frame(maxWidth: .infinity)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(10)
                    .disabled(shouldDisableSaveButton)
                }
                .listRowInsets(EdgeInsets())
                .padding()
            }
            .navigationBarTitle("Configure Module", displayMode: .inline)
            .navigationBarItems(
                leading: Button("Cancel", action: onCancel),
                trailing: Button("Save") {
                    prepareAndSave()
                }
                .disabled(shouldDisableSaveButton)
            )
            .sheet(isPresented: $showDataPointSelector) {
                DataPointSelectorSheet(
                    mqttBroker: mqttBroker,
                    selectedDataPoint: $selectedDataPoint,
                    deviceId: deviceId  // Pass device ID for filtering
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
            // For slider, handle the property name format correctly
            if !message.isEmpty && !message.contains("{") {
                // If message is a property name, we'll use a middle value
                previewMessage = message
            } else {
                // Otherwise use a raw value
                previewMessage = "\(Int((minValue + maxValue) / 2))"
            }
        case .dataDisplay:
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
    
    private func prepareAndSave() {
        // Collect debug info before saving
        print("Saving module: \(moduleType.rawValue)")
        print("Selected topic: \(selectedTopic)")
        print("Use data point: \(useDataPoint)")
        if let dataPoint = selectedDataPoint {
            print("Selected data point: \(dataPoint.name)")
        }
        
        // Update all necessary values
        if customColor == nil {
            customColor = selectedColor.toHex()
            print("Set custom color to: \(customColor ?? "nil")")
        }
        
        if useDataPoint, let dataPoint = selectedDataPoint {
            selectedTopic = dataPoint.path
            print("Updated topic to data point path: \(selectedTopic)")
        } else if useCustomTopic {
            selectedTopic = customTopicInput
            print("Updated topic to custom input: \(selectedTopic)")
        }
        
        // Call the onSave closure
        onSave()
    }
    
    private func saveModule() {
        prepareAndSave()
    }
}
