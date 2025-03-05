import SwiftUI

struct EditControlView: View {
    var control: DeviceControl
    let onSave: (DeviceControl) -> Void
    let onCancel: () -> Void
    
    @ObservedObject private var mqttBroker = MQTTBroker.shared
    @Environment(\.presentationMode) var presentationMode
    @State private var selectedTopic: String
    @State private var message: String
    @State private var minValue: Double
    @State private var maxValue: Double
    @State private var displayName: String
    @State private var selectedDataPoint: MQTTBroker.DataPoint?
    @State private var useDataPoint: Bool
    
    @State private var customColor: String?
    @State private var customIcon: String?
    @State private var customUnit: String?
    @State private var backgroundColor: String?
    @State private var textColor: String?

    @State private var customTopicInput: String = ""
    @State private var useCustomTopic: Bool = false
    
    @State private var showDataPointSelector = false
    @State private var showIconPicker = false
    @State private var showBackgroundColorPicker = false
    @State private var showTextColorPicker = false
    
    // Color slider value (0-1)
    @State private var colorValue: Double = 0.5
    
    // Color from the slider
    var selectedColor: Color {
        Color(hue: colorValue * 0.83, saturation: 1, brightness: 1)
    }
    
    var selectedBackgroundColor: Color {
        backgroundColor != nil ? Color(hex: backgroundColor!) ?? Color(.secondarySystemBackground) : Color(.secondarySystemBackground)
    }
    
    var selectedTextColor: Color {
        textColor != nil ? Color(hex: textColor!) ?? .primary : .primary
    }
    
    init(control: DeviceControl, onSave: @escaping (DeviceControl) -> Void, onCancel: @escaping () -> Void) {
        self.control = control
        self.onSave = onSave
        self.onCancel = onCancel
        
        _selectedTopic = State(initialValue: control.topic)
        _message = State(initialValue: control.message)
        _minValue = State(initialValue: control.minValue)
        _maxValue = State(initialValue: control.maxValue)
        _displayName = State(initialValue: control.displayName)
        _useDataPoint = State(initialValue: control.dataPointId != nil)
        
        // Initialize customization options
        _customColor = State(initialValue: control.customColor)
        _customIcon = State(initialValue: control.customIcon)
        _customUnit = State(initialValue: control.customUnit)
        _backgroundColor = State(initialValue: control.backgroundColor)
        _textColor = State(initialValue: control.textColor)
        
        // Initialize color slider value using shared helper
        _colorValue = State(initialValue: ControlHelpers.initializeColorValue(
            customColor: control.customColor,
            controlType: control.controlType
        ))
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Basic Configuration")) {
                    TextField("Display Name", text: $displayName)
                    
                    if control.controlType == .dataDisplay {
                        DataPointSelectionButton(
                            selectedDataPoint: selectedDataPoint,
                            dataPointId: control.dataPointId,
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
                                dataPointId: control.dataPointId,
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
                                    Text("Current: \(selectedTopic)").tag(selectedTopic)
                                    Divider()
                                    ForEach(mqttBroker.topics.sorted(), id: \.self) { topic in
                                        Text(topic).tag(topic)
                                    }
                                }
                            }
                        }
                    }
                }
                
                Section(header: Text("Control Settings")) {
                    switch control.controlType {
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
                        if selectedDataPoint == nil && control.dataPointId == nil {
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
                    // Icon selection
                    Button(action: {
                        showIconPicker = true
                    }) {
                        HStack {
                            Text("Module Icon")
                            Spacer()
                            Image(systemName: customIcon ?? control.getIconName())
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
                    
                    // Color slider using shared component
                    ColorSliderView(colorValue: $colorValue, customColor: $customColor)
                    
                }
                Section(header: Text("Preview")) {
                    VStack {
                        ControlView(
                            control: createUpdatedControl(),
                            onAction: { _ in }
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.vertical)
                    }
                }
                
                Section {
                    Button("Save Changes") {
                        saveChanges()
                    }
                    .frame(maxWidth: .infinity)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(10)
                    
                    Button("Cancel") {
                        onCancel()
                    }
                    .frame(maxWidth: .infinity)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.red)
                    .cornerRadius(10)
                }
                .listRowInsets(EdgeInsets())
                .padding()
            }
            .navigationBarTitle("Edit \(control.displayName)", displayMode: .inline)
            .navigationBarItems(trailing: Button("Save") {
                saveChanges()
            })
            .onAppear {
                if let dataPointId = control.dataPointId {
                    let dataPoints = mqttBroker.getAllDataPoints()
                    selectedDataPoint = dataPoints.first(where: { $0.id == dataPointId })
                }
                
                if !useDataPoint {
                    customTopicInput = selectedTopic
                }
                
                // Ensure we have a color set
                if customColor == nil {
                    customColor = selectedColor.toHex()
                }
            }
            .sheet(isPresented: $showDataPointSelector) {
                DataPointSelectorSheet(
                    mqttBroker: mqttBroker,
                    selectedDataPoint: $selectedDataPoint
                )
            }
        }
    }

    private func createUpdatedControl() -> DeviceControl {
        return DeviceControl(
            id: control.id,
            topic: selectedTopic,
            message: message,
            controlType: control.controlType,
            displayName: displayName,
            minValue: minValue,
            maxValue: maxValue,
            dataPointId: useDataPoint ? selectedDataPoint?.id ?? control.dataPointId : nil,
            customColor: customColor,
            customIcon: customIcon,
            customUnit: customUnit,
            backgroundColor: backgroundColor,
            textColor: textColor
        )
    }
    
    private func shouldDisableSave() -> Bool {
            // For data display, we need a data point
            if control.controlType == .dataDisplay {
                if useDataPoint {
                    return selectedDataPoint == nil
                }
                return selectedTopic.isEmpty
            }
            
            // For other modules
            if useDataPoint {
                return selectedDataPoint == nil
            }
            return selectedTopic.isEmpty
        }
        
        private func saveChanges() {
            if useDataPoint, let dataPoint = selectedDataPoint {
                selectedTopic = dataPoint.path
            } else if useCustomTopic {
                selectedTopic = customTopicInput
            }
            
            // Ensure we've set the custom color from the slider
            customColor = selectedColor.toHex()
            
            let updatedControl = createUpdatedControl()
            
            onSave(updatedControl)
        }
}
