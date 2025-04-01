import SwiftUI

struct DeviceControlView: View {
    let device: Device
    @State private var controls: [DeviceControl] = []
    @State private var isAddingControl = false
    
    // Combined edit state to ensure proper timing of state changes
    @State private var editState: EditState? = nil
    
    // Keep all state variables
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
    
    // Keep track of slider values for continuous motion
    @State private var sliderValues: [Int: Double] = [:]
    @State private var lastSliderUpdateTime: [Int: Date] = [:]
    
    // Flag to track if we need to refresh the view
    @State private var needsRefresh: Bool = false
    
    private let columns = [
        GridItem(.adaptive(minimum: 160), spacing: 16)
    ]
    
    // Structure to represent edit state with control and index together
    struct EditState: Identifiable {
        let id = UUID()
        let control: DeviceControl
        let index: Int
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Device header
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
            
            // Action buttons
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 15) {
                    // Motion settings button
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
                    
                    // Timer summary button
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
                    
                    // Automations button
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
                    
                    
                    // Motion activation button
                    Button(action: {
                        toggleMotionControls()
                    }) {
                        HStack {
                            Image(systemName: isMotionActive ? "gyroscope.fill" : "gyroscope")
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
            
            // Controls grid or empty state
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
                                    
                                    // Update the slider value state when the control is manually adjusted
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
                                // Edit button
                                Button(action: {
                                    print("Starting edit for control: \(control.displayName) at index: \(index)")
                                    editState = EditState(control: control, index: index)
                                }) {
                                    Label("Edit", systemImage: "pencil")
                                }
                                
                                // Configure Motion button
                                Button(action: {
                                    controlToConfigureMotion = control
                                    showMotionSettings = true
                                }) {
                                    Label("Configure Motion", systemImage: "gyroscope")
                                }
                                
                                // Configure Timer button
                                Button(action: {
                                    controlToConfigureTimer = control
                                    showTimerConfigurator = true
                                }) {
                                    Label("Configure Timer", systemImage: "timer")
                                }
                                
                                Divider()
                                
                                // Delete button
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
        .sheet(isPresented: $isAddingControl, onDismiss: {
            // Refresh controls when sheet is dismissed
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
                    // Still update the controls array
                    if let index = controls.firstIndex(where: { $0.id == updatedControl.id }) {
                        controls[index] = updatedControl
                    }
                    
                    // Clear edit state
                    editState = nil
                    
                    // Force immediate refresh after a short delay
                    // This ensures the sheet has time to dismiss
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
                // Show motion configurator for specific control
                MotionConfiguratorView(deviceId: device.id, control: control)
                    .onDisappear {
                        controlToConfigureMotion = nil
                    }
            } else {
                // Show general motion settings
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
                // Show timer configuration for specific control
                TimerConfiguratorView(control: control, deviceId: device.id)
                    .onDisappear {
                        controlToConfigureTimer = nil
                    }
            } else {
                // Show general timer summary
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
                        
                        // Force view refresh
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
                    // Use the editState for context menu edits too
                    editState = EditState(control: control, index: index)
                }
                
                Button("Configure Motion") {
                    controlToConfigureMotion = control
                    showMotionSettings = true
                }
                
                Button("Configure Timer") {
                    controlToConfigureTimer = control
                    showTimerConfigurator = true
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
            
            // Set up motion callback even if not active yet
            setupMotionCallback()
            
            // If motion was previously active, make sure the callback is properly set
            if motionManager.isMotionActivated {
                isMotionActive = true
            }
        }
    }
    
    // MARK: - Helper Methods
    
    // Force immediate refresh after editing a control
    private func forceImmediateRefresh() {
        // Force reload from UserDefault
        saveControlsToUserDefaults()
        loadControlsFromUserDefaults()
        
        // Toggle refresh state to force UI update
        needsRefresh.toggle()
        
        // Provide feedback that changes were applied
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        
        print("Forced immediate UI refresh after control edit")
    }
    
    // Extract numeric value from JSON string
    private func extractNumericValueFromJson(_ jsonString: String) -> Double? {
        // Try to extract a value like {"brightness": 50}
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
    
    /// Handle control save from edit view
    private func handleControlSave(updatedControl: DeviceControl, index: Int) {
        print("Handling control save: \(updatedControl.displayName) at index: \(index)")
        
        // Check if index is valid
        guard index >= 0 && index < controls.count else {
            print("Error: Invalid index \(index) for control update")
            return
        }
        
        // Update the control in the array
        controls[index] = updatedControl
        
        // Save changes to UserDefaults and refresh UI
        forceImmediateRefresh()
        
        // Clear edit state
        editState = nil
    }
    
    /// Save controls to UserDefaults with debug info
    @discardableResult
    private func saveControlsToUserDefaults() -> Bool {
        let key = "controls_\(device.id)"
        print("DeviceControlView: Saving \(controls.count) controls to UserDefaults with key: \(key)")
        
        do {
            let encoder = JSONEncoder()
            let encoded = try encoder.encode(controls)
            UserDefaults.standard.set(encoded, forKey: key)
            
            // Force immediate save
            UserDefaults.standard.synchronize()
            
            print("DeviceControlView: Successfully saved controls")
            return true
        } catch {
            print("DeviceControlView: Error saving controls: \(error.localizedDescription)")
            return false
        }
    }
    
    /// Load controls from UserDefaults
    private func loadControlsFromUserDefaults() {
        let key = "controls_\(device.id)"
        print("Loading controls from UserDefaults with key: \(key)")
        
        if let savedData = UserDefaults.standard.data(forKey: key) {
            do {
                let decoder = JSONDecoder()
                let decoded = try decoder.decode([DeviceControl].self, from: savedData)
                
                // Fix: Only update controls if we successfully decoded them
                if !decoded.isEmpty {
                    controls = decoded
                    
                    // Initialize slider values for newly loaded controls
                    for control in controls {
                        if control.controlType == .slider {
                            // Try to extract value from possible templated message
                            if control.message.contains("{value}") {
                                // Default to middle value for templated messages
                                sliderValues[control.id] = (control.minValue + control.maxValue) / 2
                            } else if let value = Double(control.message) {
                                sliderValues[control.id] = value
                            } else {
                                sliderValues[control.id] = control.minValue
                            }
                        }
                    }
                    
                    print("Successfully loaded \(controls.count) controls")
                } else {
                    print("Decoded controls array is empty")
                }
            } catch {
                print("Error decoding controls: \(error.localizedDescription)")
            }
        } else {
            print("No saved controls found for device \(device.id)")
            controls = []
        }
    }
    
    // Method to handle long press on control
    private func handleLongPress(control: DeviceControl, index: Int) {
        print("Long press detected on control: \(control.displayName)")
        
        // Set the selected control and its index
        selectedControl = (control, index)
        
        // Show the action sheet with options
        showActionSheet = true
        
        // Vibrate to indicate menu is shown
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
    
    private func toggleMotionControls() {
        isMotionActive.toggle()
        
        let motionManager = MotionControlManager.shared
        if isMotionActive {
            // Make sure the motion manager is enabled before starting tracking
            motionManager.isMotionEnabled = true
            motionManager.saveSettings()
            
            // This is critical - set up the callback BEFORE starting tracking
            setupMotionCallback()
            
            // Start tracking
            motionManager.startMotionTracking()
            
            // Provide feedback when activated
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
        } else {
            motionManager.stopMotionTracking()
        }
    }
    
    // IMPROVED: Update slider value function to better track and refresh UI
    private func updateSliderValue(controlId: Int, value: Double) {
        // Update our local state
        sliderValues[controlId] = value
        lastSliderUpdateTime[controlId] = Date()
        
        // Force a UI refresh if needed
        // This helps ensure the new value is displayed
        needsRefresh.toggle()
    }
    

    private func setupMotionCallback() {
        // Set the callback to handle motion actions
        motionManager.onMotionActionTriggered = { controlId, actionValue in
            print("Motion action triggered - Control ID: \(controlId), Action: \(actionValue)")
            
            // Find the control with this ID
            if let controlIndex = self.controls.firstIndex(where: { $0.id == controlId }) {
                let control = self.controls[controlIndex]
                print("Found matching control: \(control.displayName)")
                self.handleControlAction(control, actionValue: actionValue)
            } else {
                print("ERROR: Could not find control with ID: \(controlId)")
            }
        }
        
        // Set the callback for continuous motion adjustments
        motionManager.onContinuousMotion = { controlId, actionValue, intensity in
            // Find the control with this ID
            if let controlIndex = self.controls.firstIndex(where: { $0.id == controlId }) {
                let control = self.controls[controlIndex]
                
                // Only handle continuous adjustment for sliders
                if control.controlType == .slider {
                    // Get current value
                    var currentValue = self.sliderValues[controlId] ?? control.minValue
                    
                    // Calculate the range of the slider for determining step size
                    let range = control.maxValue - control.minValue
                    
                    // Determine step size based on slider range and intensity
                    // For a more natural feel, scale steps proportionally to the slider's range
                    let stepSize = (range * 0.01) * intensity * 2 // Adjust multiplier for desired sensitivity
                    
                    // Apply step in the right direction based on the actionValue direction
                    if actionValue.starts(with: "increase:") {
                        currentValue += stepSize
                    } else if actionValue.starts(with: "decrease:") {
                        currentValue -= stepSize
                    }
                    
                    // Clamp value to min/max range
                    currentValue = max(control.minValue, min(control.maxValue, currentValue))
                    
                    // Update local state
                    self.updateSliderValue(controlId: controlId, value: currentValue)
                    
                    // Format message to send to the device
                    let messageToSend = self.formatMessageForSlider(control, value: currentValue)
                    
                    // CRITICAL FIX: Always send the MQTT update, not just when timer elapsed
                    // This ensures the device gets updated even during motion control
                    self.mqttBroker.publish(topic: control.topic, message: messageToSend)
                    self.lastSliderUpdateTime[controlId] = Date()
                    
                    // Make sure UI gets refreshed on main thread
                    DispatchQueue.main.async {
                        self.needsRefresh.toggle()
                    }
                    
                    // Haptic feedback - simple and consistent
                    let now = Date()
                    let lastUpdate = self.lastSliderUpdateTime[controlId] ?? .distantPast
                    if now.timeIntervalSince(lastUpdate) >= 0.3 { // Less frequent feedback
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred(intensity: 0.5) // Consistent mild feedback
                    }
                }
            }
        }
    }
    // IMPROVED: Handle motion control actions with better formatting
    private func handleControlAction(_ control: DeviceControl, actionValue: String) {
        switch control.controlType {
        case .button:
            // For button, just send the message
            mqttBroker.publish(topic: control.topic, message: control.message)
            
        case .toggle:
            // For toggle, use the message based on the action
            if actionValue == "toggle" {
                // Need to determine current state to toggle it
                if let currentValue = mqttBroker.getValue(topic: control.topic) {
                    if let boolValue = currentValue.asBool() {
                        // Send the opposite
                        let onOffConfig = getToggleMessages(from: control.message)
                        let messageToSend = boolValue ? onOffConfig.offMessage : onOffConfig.onMessage
                        mqttBroker.publish(topic: control.topic, message: messageToSend)
                    }
                } else {
                    // Default to sending the on message
                    let onMessage = getToggleOnMessage(from: control.message)
                    mqttBroker.publish(topic: control.topic, message: onMessage)
                }
            } else if actionValue == "on" {
                let onMessage = getToggleOnMessage(from: control.message)
                mqttBroker.publish(topic: control.topic, message: onMessage)
            } else if actionValue == "off" {
                let offMessage = getToggleOffMessage(from: control.message)
                mqttBroker.publish(topic: control.topic, message: offMessage)
            }
            
        case .slider:
            // For slider, handle numeric adjustments
            if actionValue.starts(with: "increase:") {
                let percentString = actionValue.replacingOccurrences(of: "increase:", with: "")
                if let percent = Double(percentString) {
                    adjustSliderValue(control, by: percent/100.0)
                }
            } else if actionValue.starts(with: "decrease:") {
                let percentString = actionValue.replacingOccurrences(of: "decrease:", with: "")
                if let percent = Double(percentString) {
                    adjustSliderValue(control, by: -percent/100.0)
                }
            } else if actionValue.starts(with: "set:") {
                let valueString = actionValue.replacingOccurrences(of: "set:", with: "")
                if let value = Double(valueString) {
                    // Set absolute value, ensuring it's within range
                    let clampedValue = max(control.minValue, min(control.maxValue, value))
                    
                    // Update the local state tracker
                    updateSliderValue(controlId: control.id, value: clampedValue)
                    
                    // Format the message based on control configuration
                    let messageToSend = formatMessageForSlider(control, value: clampedValue)
                    mqttBroker.publish(topic: control.topic, message: messageToSend)
                }
            } else if actionValue.starts(with: "motion:") {
                // This is a general motion control action, do nothing specific here
                // The continuous motion callback will handle it
            }
            
        case .dataDisplay:
            // Data displays don't have actions
            break
        }
    }
    
    // ADDED: Helper function for slider message formatting
    private func formatMessageForSlider(_ control: DeviceControl, value: Double) -> String {
        // Check if message is a property name for JSON formatting
        if !control.message.isEmpty && !control.message.contains("{") && !control.message.contains("}") {
            // Create JSON payload with property name
            return "{\"\(control.message)\": \(Int(value))}"
        } else if control.message.contains("{value}") {
            // Legacy support for old format with {value} placeholder
            return control.message.replacingOccurrences(
                of: "{value}",
                with: "\(Int(value))"
            )
        } else {
            // Default to sending just the value
            return "\(Int(value))"
        }
    }
    
    // IMPROVED: Adjust slider value method
    private func adjustSliderValue(_ control: DeviceControl, by percentChange: Double) {
        // Get current value
        var currentValue: Double
        
        // First try to get from our tracking state
        if let trackedValue = sliderValues[control.id] {
            currentValue = trackedValue
        }
        // Then try to get from MQTT if available
        else if let value = mqttBroker.getValue(topic: control.topic),
                let numValue = value.asDouble() {
            currentValue = numValue
        }
        // Then try from control message
        else if let messageValue = Double(control.message) {
            currentValue = messageValue
        }
        // Finally fall back to minimum
        else {
            currentValue = control.minValue
        }
        
        // Calculate range and step
        let range = control.maxValue - control.minValue
        let changeAmount = range * percentChange
        
        // Calculate new value and clamp to range
        let newValue = max(control.minValue, min(control.maxValue, currentValue + changeAmount))
        
        // Update the slider value state
        updateSliderValue(controlId: control.id, value: newValue)
        
        // Format the message according to control configuration
        let messageToSend = formatMessageForSlider(control, value: newValue)
        
        // Send the message
        mqttBroker.publish(topic: control.topic, message: messageToSend)
        
        // Provide haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
    
    // Helper methods for toggle controls
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
