import SwiftUI
import Combine

struct ControlInterfaceView: View {
    let control: DeviceControl
    let onAction: (String) -> Void
    var onLongPress: (() -> Void)? = nil
    var isPreview: Bool = false
    
    var deviceId: Int = 0
    
    var currentValue: Double?
    
    @State private var sliderValue: Double = 0
    @State private var isToggleOn: Bool = false
    @State private var displayValue: String = "--"
    @State private var timer: Timer? = nil
    @State private var isDragging: Bool = false
    
    @State private var showMotionConfigurator = false
    @State private var showTimerConfigurator = false
    
    @GestureState private var isDetectingLongPress = false
    @State private var isLongPressDetected = false
    
    @ObservedObject private var mqttBroker = MQTTBroker.shared
    @ObservedObject private var motionManager = MotionControlManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {

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
                renderSliderControl()
            } else {
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
                .stroke(control.getCustomColor().opacity(0.5), lineWidth: 2)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 1)
        .onTapGesture(count: 2) {
            if !isPreview && onLongPress != nil {
                onLongPress?()
            }
        }
        .gesture(
            LongPressGesture(minimumDuration: 0.75)
                .updating($isDetectingLongPress) { currentState, gestureState, _ in
                    gestureState = currentState
                }
                .onEnded { _ in
                    if !isPreview {
                        print("Long press detected on control")
                        
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.impactOccurred()
                        
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
    
    
    private func setupInitialValues() {
        if control.controlType == .slider {
            if let value = currentValue {
                sliderValue = value
            } else {
                updateSliderValueFromMQTT()
            }
            
            timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
                updateSliderValueFromMQTT()
            }
            
            if let timer = timer {
                RunLoop.current.add(timer, forMode: .common)
            }
        } else if control.controlType == .toggle {
            updateToggleValueFromMQTT()
            
            timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
                updateToggleValueFromMQTT()
            }
            
            if let timer = timer {
                RunLoop.current.add(timer, forMode: .common)
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
    
    private func updateSliderValueFromMQTT() {
        if let value = mqttBroker.getValue(topic: control.topic) {
            var numValue: Double?
            
            if case .number(let num) = value {
                numValue = num
            } else if case .text(let str) = value, let parsed = Double(str) {
                numValue = parsed
            } else if case .jsonObject(let dict) = value, !control.message.isEmpty {
                if let propertyValue = dict[control.message] as? Double {
                    numValue = propertyValue
                } else if let propertyValue = dict[control.message] as? Int {
                    numValue = Double(propertyValue)
                }
            }
            
            if let updatedValue = numValue, abs(updatedValue - sliderValue) > 0.1, !isDragging {
                withAnimation(.easeOut(duration: 0.3)) {
                    sliderValue = updatedValue
                }
            }
        }
    }
    
    private func updateToggleValueFromMQTT() {
        if let topicValue = mqttBroker.getValue(topic: control.topic) {
            let newToggleState: Bool
            
            if let boolValue = topicValue.asBool() {
                newToggleState = boolValue
            } else if case .text(let stringValue) = topicValue {
                let onMessage = getToggleOnMessage(from: control.message).lowercased()
                newToggleState = stringValue.lowercased() == onMessage
            } else if case .number(let numValue) = topicValue {
                newToggleState = numValue != 0
            } else {
                newToggleState = false
            }
            
            if isToggleOn != newToggleState {
                withAnimation {
                    isToggleOn = newToggleState
                }
            }
        }
    }
    
    private func cleanupOnDisappear() {
        timer?.invalidate()
        timer = nil
    }
    
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
                
                if topicParts.count >= 3 {
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
    
    
    private func renderSliderControl() -> some View {
        VStack(spacing: 8) {
            GeometryReader { geometry in
                let width = geometry.size.width
                
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 8)
                        .cornerRadius(4)
                    
                    let percentage = (sliderValue - control.minValue) / (control.maxValue - control.minValue)
                    let fillWidth = width * CGFloat(percentage)
                    
                    Rectangle()
                        .fill(control.getCustomColor())
                        .frame(width: max(0, min(fillWidth, width)), height: 8)
                        .cornerRadius(4)
                    
                    Circle()
                        .fill(control.getCustomColor())
                        .frame(width: 20, height: 20)
                        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                        .offset(x: max(0, min(fillWidth - 10, width - 20)))
                }
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            isDragging = true
                            let xPos = value.location.x
                            let percentage = Double(max(0, min(xPos, width)) / width)
                            sliderValue = control.minValue + (control.maxValue - control.minValue) * percentage
                        }
                        .onEnded { _ in
                            sendSliderValue()
                            isDragging = false
                        }
                )
            }
            .frame(height: 30)
            
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
    }
    
    private func sendSliderValue() {
        let messageToSend: String
        if !control.message.isEmpty && !control.message.contains("{") && !control.message.contains("}") {
            messageToSend = "{\"\(control.message)\": \(Int(sliderValue))}"
        } else if control.message.contains("{value}") {
            messageToSend = control.message.replacingOccurrences(
                of: "{value}",
                with: "\(Int(sliderValue))"
            )
        } else {
            messageToSend = "\(Int(sliderValue))"
        }
        
        onAction(messageToSend)
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
            .buttonStyle(BorderlessButtonStyle())
            
        case .slider:
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
