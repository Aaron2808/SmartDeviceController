import SwiftUI

struct ControlModule {
    let name: String
    let description: String
    let type: ControlType
    let icon: Image
    let color: Color
    
    static let allModules: [ControlModule] = [
        ControlModule(
            name: "Button",
            description: "Send commands to your device",
            type: .button,
            icon: Image(systemName: "button.programmable"),
            color: .blue
        ),
        ControlModule(
            name: "Toggle Switch",
            description: "Turn your device on or off",
            type: .toggle,
            icon: Image(systemName: "switch.2"),
            color: .green
        ),
        ControlModule(
            name: "Slider",
            description: "Control levels and values",
            type: .slider,
            icon: Image(systemName: "slider.horizontal.3"),
            color: .orange
        ),
        ControlModule(
            name: "Data Monitor",
            description: "Display sensor readings",
            type: .dataDisplay,
            icon: Image(systemName: "chart.bar"),
            color: .purple
        )
    ]
}

struct ModuleCard: View {
    let module: ControlModule
    let isSelected: Bool
    
    var body: some View {
        VStack {
            module.icon
                .font(.system(size: 36))
                .foregroundColor(module.color)
                .frame(height: 60)
                .padding(.top)
            
            Text(module.name)
                .font(.headline)
                .multilineTextAlignment(.center)
            
            Text(module.description)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity, minHeight: 180)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? module.color : Color.clear, lineWidth: 3)
                )
        )
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}
