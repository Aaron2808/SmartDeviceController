import SwiftUI

struct ControlView: View {
    let control: DeviceControl
    let onAction: (String) -> Void
    var isPreview: Bool = false
    
    @State private var sliderValue: Double = 0
    @State private var isToggleOn: Bool = false
    @State private var displayValue: String = "--"
    @State private var timer: Timer? = nil
    
    @ObservedObject private var mqttBroker = MQTTBroker.shared
    
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
            
            renderControlContent()
                .frame(height: 60)
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
        .onAppear {
            if control.controlType == .slider {
                if let currentValue = Double(control.message) {
                    sliderValue = currentValue
                } else {
                    sliderValue = control.minValue
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
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
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
            
        case .slider:
            VStack {
                Slider(
                    value: Binding(
                        get: { sliderValue },
                        set: { newValue in
                            sliderValue = newValue
                            onAction("\(Int(newValue))")
                        }
                    ),
                    in: control.minValue...control.maxValue
                )
                .accentColor(control.getCustomColor())
                
                Text("\(Int(sliderValue))")
                    .font(.caption)
                    .foregroundColor(control.getTextColor())
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            
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
}
