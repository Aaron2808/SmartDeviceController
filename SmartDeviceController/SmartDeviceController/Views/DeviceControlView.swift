import SwiftUI

struct DeviceControlView: View {
    let device: Device
    @State private var controls: [DeviceControl] = []
    @State private var isAddingControl = false
    
    @State private var editState: EditState? = nil
    @State private var showActionSheet = false
    @State private var showDeleteAlert = false
    @State private var selectedControl: (DeviceControl, Int)? = nil
    
    @ObservedObject var mqttBroker = MQTTBroker.shared
    @ObservedObject private var motionManager = MotionControlManager.shared
    @ObservedObject private var automationManager = AutomationManager.shared
    
    @State private var showMotionSettings = false
    @State private var showTimerSummary = false
    @State private var showTimerConfigurator = false
    @State private var showAutomations = false
    @State private var isMotionActive: Bool = false
    @State private var controlToConfigureMotion: DeviceControl? = nil
    @State private var controlToConfigureTimer: DeviceControl? = nil
    
    @State private var advancedModeEnabled: Bool = false
    
    @State private var sliderValues: [Int: Double] = [:]
    @State private var lastSliderUpdateTime: [Int: Date] = [:]
    
    @State private var needsRefresh: Bool = false
    
    private let columns = [
        GridItem(.adaptive(minimum: 160), spacing: 16)
    ]
    
    struct EditState: Identifiable {
        let id = UUID()
        let control: DeviceControl
        let index: Int
    }
    
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
            
            if advancedModeEnabled {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 15) {
                        Button(action: {
                            showMotionSettings = true
                        }) {
                            HStack {
                                Image(systemName: "gyroscope")
                                    .font(.system(size: 14))
                                Text("Motion")
                                    .font(.subheadline)
                            }
                            .padding(8)
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.blue)
                            .cornerRadius(8)
                        }
                        
                        Button(action: {
                            showTimerSummary = true
                        }) {
                            HStack {
                                Image(systemName: "timer")
                                    .font(.system(size: 14))
                                Text("Timers")
                                    .font(.subheadline)
                            }
                            .padding(8)
                            .background(Color.orange.opacity(0.1))
                            .foregroundColor(.orange)
                            .cornerRadius(8)
                        }
                        
                        Button(action: {
                            showAutomations = true
                        }) {
                            HStack {
                                Image(systemName: "wand.and.stars")
                                    .font(.system(size: 14))
                                Text("Automations")
                                    .font(.subheadline)
                            }
                            .padding(8)
                            .background(Color.purple.opacity(0.1))
                            .foregroundColor(.purple)
                            .cornerRadius(8)
                        }
                        
                        Button(action: {
                            toggleMotionControls()
                        }) {
                            HStack {
                                Image(systemName: isMotionActive ? "gyroscope" : "gyroscope")
                                    .font(.system(size: 14))
                            }
                            .padding(8)
                            .background(isMotionActive ? Color.green.opacity(0.2) : Color.gray.opacity(0.1))
                            .foregroundColor(isMotionActive ? .green : .gray)
                            .cornerRadius(8)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
            }
            
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
                            ControlInterfaceView(
                                control: control,
                                onAction: { message in
                                    let messageToSend = message.isEmpty ? control.message : message
                                    print("Sending '\(messageToSend)' to topic '\(control.topic)'")
                                    mqttBroker.publish(topic: control.topic, message: messageToSend)
                                    
                                    if control.controlType == .slider {
                                        if let value = Double(messageToSend) {
                                            updateSliderValue(controlId: control.id, value: value)
                                        } else if let jsonValue = extractNumericValueFromJson(messageToSend) {
                                            updateSliderValue(controlId: control.id, value: jsonValue)
                                        }
                                    }
                                },
                                onLongPress: {
                                    handleLongPress(control: control, index: index)
                                },
                                deviceId: device.id,
                                currentValue: sliderValues[control.id]
                            )
                            .contextMenu {
                                Button(action: {
                                    print("Starting edit for control: \(control.displayName) at index: \(index)")
                                    editState = EditState(control: control, index: index)
                                }) {
                                    Label("Edit", systemImage: "pencil")
                                }
                                
                                if advancedModeEnabled {
                                    Button(action: {
                                        controlToConfigureMotion = control
                                        showMotionSettings = true
                                    }) {
                                        Label("Configure Motion", systemImage: "gyroscope")
                                    }
                                    
                                    Button(action: {
                                        controlToConfigureTimer = control
                                        showTimerConfigurator = true
                                    }) {
                                        Label("Configure Timer", systemImage: "timer")
                                    }
                                }
                                
                                Divider()
                                
                                Button(role: .destructive, action: {
                                    selectedControl = (control, index)
                                    showDeleteAlert = true
                                }) {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .padding()
                }
                .id("control_grid_\(needsRefresh ? "refresh" : "normal")_\(mqttBroker.dataUpdateIdentifier)")
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
        .sheet(isPresented: $isAddingControl, onDismiss: {
            forceImmediateRefresh()
        }) {
            AddControlView(controls: $controls, deviceId: device.id, saveControls: {
                saveControlsToUserDefaults()
            })
        }
        .sheet(item: $editState) { state in
            EditControlView(
                control: state.control,
                deviceId: device.id,
                onSave: { updatedControl in
                    if let index = controls.firstIndex(where: { $0.id == updatedControl.id }) {
                        controls[index] = updatedControl
                    }
                    
                    editState = nil
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        forceImmediateRefresh()
                    }
                },
                onCancel: {
                    editState = nil
                }
            )
        }
        .sheet(isPresented: $showMotionSettings) {
            if let control = controlToConfigureMotion {
                MotionConfiguratorView(deviceId: device.id, control: control)
                    .onDisappear {
                        controlToConfigureMotion = nil
                    }
            } else {
                NavigationView {
                    MotionControlSettingsView()
                        .navigationBarItems(trailing: Button("Done") {
                            showMotionSettings = false
                        })
                }
            }
        }
        .sheet(isPresented: $showTimerSummary) {
            if let control = controlToConfigureTimer {
                TimerConfiguratorView(control: control, deviceId: device.id)
                    .onDisappear {
                        controlToConfigureTimer = nil
                    }
            } else {
                TimerSummaryView(deviceId: device.id)
            }
        }
        .sheet(isPresented: $showTimerConfigurator) {
            if let control = controlToConfigureTimer {
                TimerConfiguratorView(control: control, deviceId: device.id)
                    .onDisappear {
                        controlToConfigureTimer = nil
                    }
            }
        }
        .sheet(isPresented: $showAutomations) {
            AutomationsView(deviceId: device.id)
        }
        .alert(isPresented: $showDeleteAlert) {
            Alert(
                title: Text("Delete Control"),
                message: Text("Are you sure you want to delete this control?"),
                primaryButton: .destructive(Text("Delete")) {
                    if let (_, index) = selectedControl, index < controls.count {
                        controls.remove(at: index)
                        saveControlsToUserDefaults()
                        
                        needsRefresh.toggle()
                    }
                },
                secondaryButton: .cancel()
            )
        }
        .confirmationDialog(
            "Control Options",
            isPresented: $showActionSheet,
            titleVisibility: .visible
        ) {
            if let (control, index) = selectedControl {
                Button("Edit") {
                    editState = EditState(control: control, index: index)
                }
                
                if advancedModeEnabled {
                    Button("Configure Motion") {
                        controlToConfigureMotion = control
                        showMotionSettings = true
                    }
                    
                    Button("Configure Timer") {
                        controlToConfigureTimer = control
                        showTimerConfigurator = true
                    }
                }
                
                Button("Delete", role: .destructive) {
                    selectedControl = (control, index)
                    showDeleteAlert = true
                }
                
                Button("Cancel", role: .cancel) { }
            }
        }
        .onAppear {
            loadControlsFromUserDefaults()
            
            advancedModeEnabled = UserDefaults.standard.bool(forKey: "advancedModeEnabled")
            
            setupMotionCallback()
            
            if motionManager.isMotionActivated {
                isMotionActive = true
            }
        }
    }
    
    
    private func forceImmediateRefresh() {
        loadControlsFromUserDefaults()

        needsRefresh.toggle()
        
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        
        print("Forced immediate UI refresh after control edit")
    }
    
    private func extractNumericValueFromJson(_ jsonString: String) -> Double? {
        if jsonString.hasPrefix("{") && jsonString.hasSuffix("}") {
            let content = jsonString.dropFirst().dropLast()
            let parts = content.split(separator: ":")
            if parts.count == 2 {
                let valueStr = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                return Double(valueStr)
            }
        }
        return nil
    }
    
    private func handleControlSave(updatedControl: DeviceControl, index: Int) {
        print("Handling control save: \(updatedControl.displayName) at index: \(index)")
        
        guard index >= 0 && index < controls.count else {
            print("Error: Invalid index \(index) for control update")
            return
        }
        
        controls[index] = updatedControl
        
        let success = saveControlsToUserDefaults()
        print("Saved controls successfully: \(success)")
        
        editState = nil
        
        needsRefresh.toggle()
    }
    
    @discardableResult
    private func saveControlsToUserDefaults() -> Bool {
        let key = "controls_\(device.id)"
        print("DeviceControlView: Saving \(controls.count) controls to UserDefaults with key: \(key)")
        
        do {
            let encoder = JSONEncoder()
            let encoded = try encoder.encode(controls)
            UserDefaults.standard.set(encoded, forKey: key)
            
            UserDefaults.standard.synchronize()
            
            print("DeviceControlView: Successfully saved controls")
            return true
        } catch {
            print("DeviceControlView: Error saving controls: \(error.localizedDescription)")
            return false
        }
    }
    
    private func loadControlsFromUserDefaults() {
        let key = "controls_\(device.id)"
        print("Loading controls from UserDefaults with key: \(key)")
        
        if let savedData = UserDefaults.standard.data(forKey: key) {
            do {
                let decoder = JSONDecoder()
                let decoded = try decoder.decode([DeviceControl].self, from: savedData)
                controls = decoded
                
                for control in controls {
                    if control.controlType == .slider {
                        if control.message.contains("{value}") {
                            sliderValues[control.id] = (control.minValue + control.maxValue) / 2
                        } else if let value = Double(control.message) {
                            sliderValues[control.id] = value
                        } else {
                            sliderValues[control.id] = control.minValue
                        }
                    }
                }
                
                print("Successfully loaded \(controls.count) controls")
            } catch {
                print("Error decoding controls: \(error.localizedDescription)")
            }
        } else {
            print("No saved controls found for device \(device.id)")
            controls = []
        }
    }
    
    private func handleLongPress(control: DeviceControl, index: Int) {
        print("Long press detected on control: \(control.displayName)")
        
        selectedControl = (control, index)
        
        showActionSheet = true
        
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
    
    private func toggleMotionControls() {
        isMotionActive.toggle()
        
        let motionManager = MotionControlManager.shared
        if isMotionActive {
            motionManager.isMotionEnabled = true
            motionManager.saveSettings()
            
            setupMotionCallback()
            
            motionManager.startMotionTracking()
            
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
        } else {
            motionManager.stopMotionTracking()
        }
    }
    
    private func updateSliderValue(controlId: Int, value: Double) {
        sliderValues[controlId] = value
        lastSliderUpdateTime[controlId] = Date()
        needsRefresh.toggle()
    }
    
    private func setupMotionCallback() {
        motionManager.onMotionActionTriggered = { controlId, actionValue in
            print("Motion action triggered - Control ID: \(controlId), Action: \(actionValue)")
            
            if let controlIndex = self.controls.firstIndex(where: { $0.id == controlId }) {
                let control = self.controls[controlIndex]
                print("Found matching control: \(control.displayName)")
                
                self.handleControlAction(control, actionValue: actionValue)
            } else {
                print("ERROR: Could not find control with ID: \(controlId)")
            }
        }
    }
    
    
    private func handleControlAction(_ control: DeviceControl, actionValue: String) {
        switch control.controlType {
        case .button:
            if actionValue.hasPrefix("shake:") {
                let message = actionValue.replacingOccurrences(of: "shake:", with: "")
                mqttBroker.publish(topic: control.topic, message: message)
            } else {
                mqttBroker.publish(topic: control.topic, message: control.message)
            }
            
        case .toggle:
            if actionValue == "toggle" {
                if let currentValue = mqttBroker.getValue(topic: control.topic) {
                    if let boolValue = currentValue.asBool() {
                        let onOffConfig = getToggleMessages(from: control.message)
                        let messageToSend = boolValue ? onOffConfig.offMessage : onOffConfig.onMessage
                        mqttBroker.publish(topic: control.topic, message: messageToSend)
                    }
                } else {
                    let onMessage = getToggleOnMessage(from: control.message)
                    mqttBroker.publish(topic: control.topic, message: onMessage)
                }
            }
            
        case .slider:
            if actionValue.starts(with: "increase:") {
                let valueString = actionValue.replacingOccurrences(of: "increase:", with: "")
                if let step = Double(valueString) {
                    adjustSliderValueByFixedStep(control, step: step)
                }
            } else if actionValue.starts(with: "decrease:") {
                let valueString = actionValue.replacingOccurrences(of: "decrease:", with: "")
                if let step = Double(valueString) {
                    adjustSliderValueByFixedStep(control, step: -step)
                }
            } else if actionValue.starts(with: "set:") {
                let valueString = actionValue.replacingOccurrences(of: "set:", with: "")
                if let value = Double(valueString) {
                    let clampedValue = max(control.minValue, min(control.maxValue, value))
                    updateSliderValue(controlId: control.id, value: clampedValue)
                    
                    let messageToSend = formatMessageForSlider(control, value: clampedValue)
                    mqttBroker.publish(topic: control.topic, message: messageToSend)
                }
            }
            
        case .dataDisplay:
            break
        }
    }
    
    private func formatMessageForSlider(_ control: DeviceControl, value: Double) -> String {
        if !control.message.isEmpty && !control.message.contains("{") && !control.message.contains("}") {
            return "{\"\(control.message)\": \(Int(value))}"
        } else if control.message.contains("{value}") {
            return control.message.replacingOccurrences(
                of: "{value}",
                with: "\(Int(value))"
            )
        } else {
            return "\(Int(value))"
        }
    }
    
    private func adjustSliderValueByFixedStep(_ control: DeviceControl, step: Double) {
        var currentValue: Double
        if let trackedValue = sliderValues[control.id] {
            currentValue = trackedValue
        }
        else if let value = mqttBroker.getValue(topic: control.topic),
                let numValue = value.asDouble() {
            currentValue = numValue
        }
        else if let messageValue = Double(control.message) {
            currentValue = messageValue
        }
        else {
            currentValue = control.minValue
        }
        
        let newValue = max(control.minValue, min(control.maxValue, currentValue + step))
        
        updateSliderValue(controlId: control.id, value: newValue)
        
        let messageToSend = formatMessageForSlider(control, value: newValue)
        mqttBroker.publish(topic: control.topic, message: messageToSend)
        
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
    
    private func getToggleMessages(from configString: String) -> (onMessage: String, offMessage: String) {
        return ToggleUtils.getToggleMessages(from: configString)
    }
    
    private func getToggleOnMessage(from configString: String) -> String {
        return ToggleUtils.getToggleOnMessage(from: configString)
    }
    
    private func getToggleOffMessage(from configString: String) -> String {
        return ToggleUtils.getToggleOffMessage(from: configString)
    }
}
