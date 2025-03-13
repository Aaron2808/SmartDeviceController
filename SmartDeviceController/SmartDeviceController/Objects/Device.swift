//
//  Device.swift
//  SmartDeviceController
//
//  Created by Aaron Flynn on 04/03/2025.
//

import SwiftUI


struct Device: Identifiable {
    let id: Int
    let name: String
    let location: String
    let color: Color
    let image: String
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

struct DeviceControl: Codable, Identifiable {
    let id: Int
    let topic: String
    let message: String
    var offMessage: String = "off" // New field for toggle off message
    let controlType: ControlType
    var displayName: String = ""
    var minValue: Double = 0
    var maxValue: Double = 100
    var dataPointId: String? = nil

    var customColor: String? = nil
    var customIcon: String? = nil
    var customUnit: String? = nil
    var backgroundColor: String? = nil
    var textColor: String? = nil
    
    func getCustomColor() -> Color {
        guard let hexString = customColor, !hexString.isEmpty else {
            return colorForControlType(controlType)
        }
        
        return Color(hex: hexString) ?? colorForControlType(controlType)
    }

    func getBackgroundColor() -> Color {
        guard let hexString = backgroundColor, !hexString.isEmpty else {
            return Color(.secondarySystemBackground)
        }
        
        return Color(hex: hexString) ?? Color(.secondarySystemBackground)
    }

    func getTextColor() -> Color {
        guard let hexString = textColor, !hexString.isEmpty else {
            return .primary
        }
        
        return Color(hex: hexString) ?? .primary
    }

    func getIconName() -> String {
        return (customIcon != nil && !customIcon!.isEmpty)
            ? customIcon!
            : iconForControlType(controlType)
    }
    
    private func iconForControlType(_ type: ControlType) -> String {
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
    
    private func colorForControlType(_ type: ControlType) -> Color {
        switch type {
        case .button:
            return .blue
        case .slider:
            return .orange
        case .toggle:
            return .green
        case .dataDisplay:
            return .purple
        }
    }
}
