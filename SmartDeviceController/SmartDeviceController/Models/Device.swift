import SwiftUI

struct Device: Identifiable, Codable {
    let id: Int
    let name: String
    let location: String
    let color: Color
    let image: String
    let mqttTopic: String?
    
    enum CodingKeys: String, CodingKey {
        case id, name, location, image, mqttTopic
        case color
    }
    
    init(id: Int, name: String, location: String, color: Color, image: String, mqttTopic: String?) {
        self.id = id
        self.name = name
        self.location = location
        self.color = color
        self.image = image
        self.mqttTopic = mqttTopic
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(location, forKey: .location)
        try container.encode(image, forKey: .image)
        try container.encode(mqttTopic, forKey: .mqttTopic)
        
        if let hexString = color.toHex() {
            try container.encode(hexString, forKey: .color)
        }
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        location = try container.decode(String.self, forKey: .location)
        image = try container.decode(String.self, forKey: .image)
        mqttTopic = try container.decodeIfPresent(String.self, forKey: .mqttTopic)
        
        let hexString = try container.decode(String.self, forKey: .color)
        color = Color(hex: hexString) ?? .blue
    }
}

struct DeviceCard: View {
    let device: Device
    
    var body: some View {
        VStack(spacing:0) {
            Rectangle()
                .fill()
                .foregroundStyle(device.color)
                .frame(height: 10)
                .frame(maxWidth: .infinity)
            
            Text(device.name)
                .font(.system(size: 16).bold())
                .foregroundColor(.primary)
                .padding(.top, 10)
               
            Spacer()
            
            Image(systemName: device.image)
                .resizable()
                .scaledToFit()
                .foregroundStyle(.black.opacity(0.6))
                .frame(width: 35, height: 35)
            
            Spacer()
            
            Text(device.location)
                .font(.subheadline)
                .foregroundColor(.black.opacity(0.7))
                .padding(.bottom, 10)
        }
        .frame(width: 150, height: 150, alignment: .top)
        .background(.white)
        .cornerRadius(10)
        .shadow(radius: 2)
    }
}

struct DeviceControl: Codable, Identifiable, Hashable {
    let id: Int
    let topic: String
    let message: String
    let controlType: ControlType
    let displayName: String
    let minValue: Double
    let maxValue: Double
    let dataPointId: String?
    let customColor: String?
    let customIcon: String?
    let customUnit: String?
    let backgroundColor: String?
    let textColor: String?
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: DeviceControl, rhs: DeviceControl) -> Bool {
        return lhs.id == rhs.id
    }
    
    func getCustomColor() -> Color {
        if let hexColor = customColor, !hexColor.isEmpty {
            return Color(hex: hexColor) ?? .blue
        }
        
        switch controlType {
        case .button:
            return .blue
        case .toggle:
            return .green
        case .slider:
            return .orange
        case .dataDisplay:
            return .purple
        }
    }
    
    func getBackgroundColor() -> Color {
        if let hexColor = backgroundColor, !hexColor.isEmpty {
            return Color(hex: hexColor) ?? Color(.secondarySystemBackground)
        }
        return Color(.secondarySystemBackground)
    }
    
    func getTextColor() -> Color {
        if let hexColor = textColor, !hexColor.isEmpty {
            return Color(hex: hexColor) ?? .primary
        }
        return .primary
    }
    
    func getIconName() -> String {
        if let icon = customIcon, !icon.isEmpty {
            return icon
        }
        
        return ControlHelpers.iconForControlType(controlType)
    }
}
