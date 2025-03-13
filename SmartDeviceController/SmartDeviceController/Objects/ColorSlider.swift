import SwiftUI

extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        
        var rgb: UInt64 = 0
        
        guard !hexSanitized.isEmpty, Scanner(string: hexSanitized).scanHexInt64(&rgb) else {
            return nil
        }
        
        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double(rgb & 0x0000FF) / 255.0
        
        self.init(red: r, green: g, blue: b)
    }
    
    func toHex() -> String? {
        let uic = UIColor(self)
        guard let components = uic.cgColor.components, components.count >= 3 else {
            return nil
        }
        
        let r = Float(components[0])
        let g = Float(components[1])
        let b = Float(components[2])
        
        return String(format: "#%02lX%02lX%02lX",
                      lroundf(r * 255),
                      lroundf(g * 255),
                      lroundf(b * 255))
    }
}

struct ColorSliderView: View {
    @Binding var colorValue: Double
    @Binding var customColor: String?
    
    var selectedColor: Color {
        Color(hue: colorValue * 0.83, saturation: 1, brightness: 1)
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                let sliderWidth = max(50, geometry.size.width)
                let circleSize: CGFloat = 24
                let trackHeight: CGFloat = 16
                let offsetRange = sliderWidth - circleSize
                
                RoundedRectangle(cornerRadius: trackHeight / 2)
                    .fill(LinearGradient(
                        gradient: Gradient(colors: [
                            .red, .orange, .yellow, .green, .blue, .purple, .pink
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    ))
                    .frame(height: trackHeight)
                
                Circle()
                    .fill(selectedColor)
                    .frame(width: circleSize, height: circleSize)
                    .overlay(Circle().stroke(Color.white, lineWidth: 2))
                    .shadow(color: Color.black.opacity(0.15), radius: 2, x: 0, y: 1)
                    .offset(x: colorValue * offsetRange)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                if sliderWidth > 0 {
                                    let rawValue = value.location.x / sliderWidth
                                    colorValue = min(max(0, rawValue), 1)
                                    // Always update the custom color when slider moves
                                    customColor = selectedColor.toHex()
                                }
                            }
                    )
            }
            .frame(height: 40)
            .onChange(of: colorValue) { _, _ in
                // Ensure custom color is updated whenever color value changes
                customColor = selectedColor.toHex()
            }
        }
        .frame(height: 40)
        .onAppear {
            // Initialize custom color if it's nil or empty
            if customColor == nil || customColor?.isEmpty == true {
                customColor = selectedColor.toHex()
            }
        }
    }
}

struct IconPickerView: View {
    let availableIcons: [String]
    @Binding var customIcon: String?
    var selectedColor: Color
    let onClose: () -> Void
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 20) {
                    ForEach(availableIcons, id: \.self) { iconName in
                        Button(action: {
                            customIcon = iconName
                            onClose()
                        }) {
                            VStack {
                                Image(systemName: iconName)
                                    .font(.system(size: 30))
                                    .foregroundColor(selectedColor)
                                    .frame(height: 40)
                                
                                Text(iconName)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.gray.opacity(0.1))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(
                                        (customIcon == iconName) ? selectedColor : Color.clear,
                                        lineWidth: 2
                                    )
                            )
                        }
                    }
                }
                .padding()
            }
            .navigationBarTitle("Choose Icon", displayMode: .inline)
            .navigationBarItems(
                leading: Button("Reset") {
                    customIcon = nil
                    onClose()
                },
                trailing: Button("Cancel") {
                    onClose()
                }
            )
        }
    }
}

struct DataPointSelectionButton: View {
    let selectedDataPoint: MQTTBroker.DataPoint?
    let dataPointId: String?
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                if let dataPoint = selectedDataPoint {
                    Text(dataPoint.name)
                        .foregroundColor(.primary)
                } else if let dataPointId = dataPointId, !dataPointId.isEmpty {
                    Text("Current: \(dataPointId)")
                        .foregroundColor(.primary)
                } else {
                    Text("Select Data Point")
                        .foregroundColor(.blue)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct CustomColorPickerView: View {
    let title: String
    @Binding var selectedColor: Color
    @Binding var colorHexValue: String?
    let onClose: () -> Void
    
    var body: some View {
        NavigationView {
            VStack {
                ColorPicker(title, selection: Binding(
                    get: { selectedColor },
                    set: { newValue in
                        selectedColor = newValue
                        colorHexValue = newValue.toHex()
                    }
                ))
                .padding()
                
                Button("Apply Color") {
                    onClose()
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
                .padding()
                
                Button("Reset to Default") {
                    colorHexValue = nil
                    onClose()
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.gray.opacity(0.2))
                .foregroundColor(.primary)
                .cornerRadius(10)
                .padding(.horizontal)
            }
            .navigationBarTitle(title, displayMode: .inline)
            .navigationBarItems(trailing: Button("Cancel") {
                onClose()
            })
        }
    }
}

struct ControlHelpers {
    static func iconForControlType(_ type: ControlType) -> String {
        switch type {
        case .button:
            return "button.programmable"
        case .slider:
            return "slider.horizontal.3"
        case .toggle:
            return "switch.2"
        case .dataDisplay:
            return "chart.bar"
        }
    }
    
    static func initializeColorValue(customColor: String?, controlType: ControlType) -> Double {
        if let hexColor = customColor, !hexColor.isEmpty, let color = Color(hex: hexColor) {
            if let components = UIColor(color).hsbColorComponents {
                return min(max(components.hue / 0.83, 0), 1)
            }
        }
        
        switch controlType {
        case .button:
            return 0.5  // Blue
        case .toggle:
            return 0.3  // Green
        case .slider:
            return 0.18 // Orange
        case .dataDisplay:
            return 0.67 // Purple
        }
    }
    
    static let availableIcons = [
        "button.programmable", "switch.2", "slider.horizontal.3",
        "thermometer", "chart.bar", "gauge", "dial.min",
        "lightbulb.fill", "power","sensor.fill"
    ]
}

extension UIColor {
    struct HSBComponents {
        let hue: CGFloat
        let saturation: CGFloat
        let brightness: CGFloat
        let alpha: CGFloat
    }
    
    var hsbColorComponents: HSBComponents? {
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        
        if self.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) {
            return HSBComponents(hue: hue, saturation: saturation, brightness: brightness, alpha: alpha)
        }
        return nil
    }
}
