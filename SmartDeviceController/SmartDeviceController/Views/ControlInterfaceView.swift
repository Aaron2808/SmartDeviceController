import SwiftUI

struct ControlInterfaceView: View {
    let control: DeviceControl
    let onAction: (String) -> Void
    // Add an optional onLongPress handler with default value of nil
    var onLongPress: (() -> Void)? = nil
    var isPreview: Bool = false
    
    // Device ID for this control (default to 0 if not known)
    var deviceId: Int = 0
    
    // Add a way to pass in the current value from parent
    var currentValue: Double?
    
    @State private var sliderValue: Double = 0
    @State private var isToggleOn: Bool = false
    @State private var displayValue: String = "--"
    @State private var timer: Timer? = nil
    
    // Context menu and sheet states
    @State private var showMotionConfigurator = false
    @State private var showTimerConfigurator = false
    
    // Motion control states
    @State private var isMotionControlActive = false
    @State private var previousRotation: Double = 0
    @State private var previousTilt: Double = 0
    @State private var motionFeedback = false
    
    // Add a state variable to track if long press is in progress
    @GestureState private var isDetectingLongPress = false
    @State private var isLongPressDetected = false
    
    @ObservedObject private var mqttBroker = MQTTBroker.shared
    @ObservedObject private var motionManager = MotionControlManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header row with title and icons
            HStack {
                Text(control.displayName.isEmpty ? control.topic : control.displayName)
                    .font(.headline)
                    .foregroundColor(control.getTextColor())
                    .lineLimit(1)
                
                Spacer()
                
                Image(systemName: control.getIconName())
                    .foregroundColor(control.getCustomColor())
            }
            .padding(.bottom, 4)
            
            if control.controlType == .slider {
                // Special handling for slider with motion control
                renderSliderWithMotionControl()
            } else {
                // Original control rendering for other types
                renderControlContent()
                    .frame(height: 60)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(control.getBackgroundColor())
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    control.controlType == .slider && isMotionControlActive
                        ? control.getCustomColor()
                        : control.getCustomColor().opacity(0.5),
                    lineWidth: control.controlType == .slider && isMotionControlActive ? 3 : 2
                )
        )
        .overlay(
            // Motion control indicator overlay - only for active motion feedback
            Group {
                if control.controlType == .slider && isMotionControlActive && motionFeedback {
                    Text("Twist/tilt left to decrease, right to increase")
                        .font(.caption)
                        .padding(6)
                        .background(control.getCustomColor().opacity(0.2))
                        .cornerRadius(4)
                        .transition(.opacity)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                        .padding(.bottom, 8)
                }
            }
        )
        .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 1)
        // Double-tap as an alternative to long press for edit
        .onTapGesture(count: 2) {
            if !isPreview && onLongPress != nil {
                onLongPress?()
            }
        }
        // Apply long press gesture for edit
        .gesture(
            LongPressGesture(minimumDuration: 0.75)
                .updating($isDetectingLongPress) { currentState, gestureState, _ in
                    gestureState = currentState
                }
                .onEnded { _ in
                    if !isPreview {
                        print("Long press detected on control")
                        
                        // Trigger the haptic feedback
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.impactOccurred()
                        
                        // Call the onLongPress handler
                        if let onLongPress = onLongPress {
                            onLongPress()
                        }
                    }
                }
        )
        .onAppear {
            setupInitialValues()
        }
        .onDisappear {
            cleanupOnDisappear()
        }
        .sheet(isPresented: $showMotionConfigurator) {
            MotionConfiguratorView(deviceId: deviceId, control: control)
        }
        .sheet(isPresented: $showTimerConfigurator) {
            TimerConfiguratorView(control: control, deviceId: deviceId)
        }
        .onChange(of: currentValue) { oldValue, newValue in
            if let value = newValue, control.controlType == .slider {
                sliderValue = value
            }
        }
    }
    
    // MARK: - Setup Methods
    
    private func setupInitialValues() {
        if control.controlType == .slider {
            // If parent provided a value, use it
            if let value = currentValue {
                sliderValue = value
            } else if let valueFromMessage = Double(control.message) {
                // Try to parse a direct number from the message
                sliderValue = valueFromMessage
            } else if let jsonValue = extractValueFromJson(control.message) {
                // Try to extract from JSON if the message is a property name
                sliderValue = jsonValue
            } else {
                // Fall back to min value
                sliderValue = control.minValue
            }
            
            // Set up a timer to check for MQTT value changes
            timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
                // Don't use weak self here since ControlView is a struct
                if let value = mqttBroker.getValue(topic: control.topic) {
                    var numValue: Double?
                    
                    // Try to get numeric value based on data type
                    if case .number(let num) = value {
                        numValue = num
                    } else if case .text(let str) = value, let parsed = Double(str) {
                        numValue = parsed
                    } else if case .jsonObject(let dict) = value, !control.message.isEmpty {
                        // Try to extract from a JSON object if message is a property name
                        if let propertyValue = dict[control.message] as? Double {
                            numValue = propertyValue
                        } else if let propertyValue = dict[control.message] as? Int {
                            numValue = Double(propertyValue)
                        }
                    }
                    
                    // Update the slider value if we got a number and it's significantly different
                    if let updatedValue = numValue, abs(updatedValue - sliderValue) > 0.5 {
                        withAnimation(.easeOut(duration: 0.3)) {
                            sliderValue = updatedValue
                        }
                    }
                }
            }
            
            if let timer = timer {
                RunLoop.current.add(timer, forMode: .common)
            }
        } else if control.controlType == .toggle {
            if let topicValue = mqttBroker.getValue(topic: control.topic) {
                if let boolValue = topicValue.asBool() {
                    isToggleOn = boolValue
                } else if case .text(let stringValue) = topicValue {
                    isToggleOn = stringValue.lowercased() == control.message.lowercased()
                }
            } else {
                isToggleOn = false
            }
        } else if control.controlType == .dataDisplay {
            updateDisplayValue()
            timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                updateDisplayValue()
            }
            
            if let timer = timer {
                RunLoop.current.add(timer, forMode: .common)
            }
        }
    }
    
    private func cleanupOnDisappear() {
        timer?.invalidate()
        timer = nil
        
        // Always stop motion tracking when leaving the view
        if isMotionControlActive {
            isMotionControlActive = false
            motionManager.stopMotionTracking()
        }
    }
    
    // MARK: - Helper function to extract value from JSON
    
    private func extractValueFromJson(_ message: String) -> Double? {
        // If message is a property name for JSON control
        if !message.isEmpty && !message.contains("{") && !message.contains("}") {
            // Try to get the current value from MQTT
            if let value = mqttBroker.getValue(topic: control.topic),
               case .jsonObject(let dict) = value,
               let propertyValue = dict[message] as? Double {
                return propertyValue
            } else if let value = mqttBroker.getValue(topic: control.topic),
                     case .jsonObject(let dict) = value,
                     let propertyValue = dict[message] as? Int {
                return Double(propertyValue)
            }
        }
        return nil
    }
    
    // MARK: - Display Value Methods
    
    private func updateDisplayValue() {
        var updatedValue: String? = nil
        
        if let dataPointId = control.dataPointId, !dataPointId.isEmpty {
            if let dataPoint = mqttBroker.getDataPointById(dataPointId),
               let value = mqttBroker.getValue(for: dataPoint) {
                updatedValue = formatValue(value)
            } else if let value = mqttBroker.getDataByPath(dataPointId) {
                updatedValue = formatValue(value)
            }
        }
        
        if updatedValue == nil && !control.topic.isEmpty {
            if let value = mqttBroker.getValue(topic: control.topic) {
                updatedValue = formatValue(value)
            } else {
                let topicParts = control.topic.split(separator: "/")
                let displayNameLower = control.displayName.lowercased()
                
                if topicParts.count >= 2 {
                    let possibleJsonTopic = control.topic
                    if let jsonValue = mqttBroker.getValue(topic: possibleJsonTopic),
                       case .jsonObject(let dict) = jsonValue {
                        
                        for (key, value) in dict {
                            if key.lowercased() == displayNameLower {
                                if let numValue = value as? Double {
                                    updatedValue = formatValue(.number(numValue))
                                } else if let intValue = value as? Int {
                                    updatedValue = formatValue(.number(Double(intValue)))
                                } else if let boolValue = value as? Bool {
                                    updatedValue = formatValue(.boolean(boolValue))
                                } else if let strValue = value as? String {
                                    updatedValue = formatValue(.text(strValue))
                                }
                            }
                        }
                        
                        if updatedValue == nil && displayNameLower == "temperature" {
                            if let tempObj = dict["temperature"] as? [String: Any],
                               let tempC = tempObj["tC"] as? Double {
                                updatedValue = formatValue(.number(tempC))
                            }
                        } else if updatedValue == nil && displayNameLower == "power" {
                            if let power = dict["apower"] as? Double {
                                updatedValue = formatValue(.number(power))
                            }
                        }
                    }
                }
            }
        }
        
        if updatedValue == nil {
            updatedValue = "--"
        }
        
        if let newValue = updatedValue, newValue != displayValue {
            displayValue = newValue
        }
    }
    
    private func formatValue(_ value: MQTTBroker.DataValue) -> String {
        if let numValue = value.asDouble() {
            if control.controlType == .dataDisplay {
                return formatWithUnit(numValue, defaultUnit: "")
            }
        }
        
        return value.formattedString()
    }

    private func formatWithUnit(_ value: Double, defaultUnit: String) -> String {
        let formattedNumber: String
        
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            formattedNumber = String(format: "%.0f", value)
        } else {
            formattedNumber = String(format: "%.1f", value)
        }
        
        let unitToShow: String
        if let customUnit = control.customUnit, !customUnit.isEmpty {
            unitToShow = customUnit
        } else if let dataPointId = control.dataPointId,
                  let dataPoint = mqttBroker.getDataPointById(dataPointId),
                  let unit = dataPoint.unit, !unit.isEmpty {
            unitToShow = unit
        } else {
            unitToShow = defaultUnit
        }
        
        return "\(formattedNumber)\(unitToShow)"
    }

    private func formatPreviewValue(_ value: String, _ defaultUnit: String) -> String {
        let unit: String
        if let customUnit = control.customUnit, !customUnit.isEmpty {
            unit = customUnit
        } else {
            unit = defaultUnit
        }
        
        return "\(value)\(unit)"
    }
    
    // MARK: - UI Rendering
    
    private func renderSliderWithMotionControl() -> some View {
        VStack(spacing: 8) {
            HStack {
                Slider(
                    value: Binding(
                        get: { sliderValue },
                        set: { newValue in
                            // Update the local state first
                            sliderValue = newValue
                            
                            // Prepare the message to send
                            let messageToSend: String
                            
                            // Check if message is a property name for JSON formatting
                            if !control.message.isEmpty && !control.message.contains("{") && !control.message.contains("}") {
                                // Create JSON payload with property name
                                messageToSend = "{\"\(control.message)\": \(Int(newValue))}"
                            } else if control.message.contains("{value}") {
                                // Legacy support for old format with {value} placeholder
                                messageToSend = control.message.replacingOccurrences(
                                    of: "{value}",
                                    with: "\(Int(newValue))"
                                )
                            } else {
                                // Default to sending just the value
                                messageToSend = "\(Int(newValue))"
                            }
                            
                            // Send the MQTT message
                            onAction(messageToSend)
                        }
                    ),
                    in: control.minValue...control.maxValue
                )
                .accentColor(control.getCustomColor())
            }
            
            HStack {
                Text("\(Int(control.minValue))")
                    .font(.caption2)
                    .foregroundColor(control.getTextColor().opacity(0.6))
                
                Spacer()
                
                Text("\(Int(sliderValue))")
                    .font(.system(.body, design: .rounded))
                    .fontWeight(.medium)
                    .foregroundColor(control.getTextColor())
                
                Spacer()
                
                Text("\(Int(control.maxValue))")
                    .font(.caption2)
                    .foregroundColor(control.getTextColor().opacity(0.6))
            }
        }
        .frame(height: 60)
    }
    
    private func toggleMotionControl() {
        isMotionControlActive.toggle()
        
        if isMotionControlActive {
            // Show feedback briefly
            motionFeedback = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                motionFeedback = false
            }
        } else {
            motionFeedback = false
        }
    }
    
    @ViewBuilder
    private func renderControlContent() -> some View {
        switch control.controlType {
        case .button:
            Button(action: {
                onAction(control.message)
            }) {
                Text("Send")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(control.getCustomColor())
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .buttonStyle(BorderlessButtonStyle()) // This is important to allow the overlay to catch gestures
            
        case .slider:
            // This case is handled separately in renderSliderWithMotionControl()
            EmptyView()
            
        case .toggle:
            let onOffConfig = getToggleMessages(from: control.message)
            
            Toggle("", isOn: Binding(
                get: { isToggleOn },
                set: { newValue in
                    isToggleOn = newValue
                    let messageToSend = newValue ? onOffConfig.onMessage : onOffConfig.offMessage
                    onAction(messageToSend)
                }
            ))
            .labelsHidden()
            .tint(control.getCustomColor())
            
        case .dataDisplay:
            VStack {
                if isPreview && (control.message.isEmpty || control.message == "--") {
                    let previewValue = "0"
                    let previewUnit = control.customUnit ?? "°"
                    let displayText = "\(previewValue)\(previewUnit)"
                    
                    Text(displayText)
                        .font(.system(size: 32, weight: .medium))
                        .foregroundColor(control.getCustomColor())
                        .opacity(0.7)
                } else {
                    Text(isPreview ? formatPreviewValue(control.message, "") : displayValue)
                        .font(.system(size: 32, weight: .medium))
                        .foregroundColor(control.getCustomColor())
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
    
    private func getToggleMessages(from configString: String) -> (onMessage: String, offMessage: String) {
        if configString.contains("|") {
            let parts = configString.split(separator: "|", maxSplits: 1).map { String($0) }
            
            let onMessage = parts[0].isEmpty ? "on" : parts[0]
            
            let offMessage = parts.count > 1 ?
                (parts[1].isEmpty ? "off" : parts[1]) :
                "off"
            
            return (onMessage, offMessage)
        }
        
        return (configString.isEmpty ? "on" : configString, "off")
    }
    
    private func getToggleOnMessage() -> String {
        if control.message.contains("|") {
            let parts = control.message.split(separator: "|", maxSplits: 1)
            return String(parts[0])
        }
        return control.message.isEmpty ? "on" : control.message
    }
    
    private func getToggleOffMessage() -> String {
        if control.message.contains("|") {
            let parts = control.message.split(separator: "|", maxSplits: 1)
            return parts.count > 1 ? String(parts[1]) : "off"
        }
        return "off"
    }
}

