import SwiftUI

// Main view for adding controls
struct AddControlView: View {
    @Binding var controls: [DeviceControl]
    let deviceId: Int
    let saveControls: () -> Void
    @ObservedObject private var mqttBroker = MQTTBroker.shared
    @Environment(\.presentationMode) var presentationMode
    
    // Current selection states
    @State private var selectedModule: ControlModule?
    @State private var selectedTopic: String = ""
    @State private var message: String = ""
    @State private var showingConfigSheet = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Header section
                    Text("Add Control Modules")
                        .font(.title)
                        .fontWeight(.bold)
                        .padding(.horizontal)
                    
                    Text("Select a module to add to your device")
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                    
                    // Control modules grid
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 160))], spacing: 16) {
                        ForEach(ControlModule.allModules, id: \.name) { module in
                            ModuleCard(module: module, isSelected: selectedModule?.name == module.name)
                                .onTapGesture {
                                    selectedModule = module
                                    showingConfigSheet = true
                                }
                        }
                    }
                    .padding()
                }
            }
            .navigationBarTitle("Add Control", displayMode: .inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
            .sheet(isPresented: $showingConfigSheet) {
                if let module = selectedModule {
                    ModuleConfigSheet(
                        moduleType: module.type,
                        topics: mqttBroker.topics.sorted(),
                        selectedTopic: $selectedTopic,
                        message: $message,
                        onSave: {
                            addControl(module: module)
                            showingConfigSheet = false
                        },
                        onCancel: {
                            showingConfigSheet = false
                        }
                    )
                }
            }
        }
    }
    
    private func addControl(module: ControlModule) {
        let newControl = DeviceControl(
            id: UUID().hashValue,
            topic: selectedTopic,
            message: message,
            controlType: module.type,
            displayName: module.name
        )
        controls.append(newControl)
        saveControls()
        presentationMode.wrappedValue.dismiss()
    }
}

// Card view for each control module
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

// Configuration sheet for the selected module
struct ModuleConfigSheet: View {
    let moduleType: ControlType
    let topics: [String]
    @Binding var selectedTopic: String
    @Binding var message: String
    let onSave: () -> Void
    let onCancel: () -> Void
    
    @State private var displayName: String = ""
    @State private var minValue: Double = 0
    @State private var maxValue: Double = 100
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Basic Configuration")) {
                    Picker("MQTT Topic", selection: $selectedTopic) {
                        ForEach(topics, id: \.self) { topic in
                            Text(topic).tag(topic)
                        }
                    }
                    
                    TextField("Display Name", text: $displayName)
                }
                
                Section(header: Text("Control Settings")) {
                    switch moduleType {
                    case .button:
                        TextField("Button Message", text: $message)
                    case .toggle:
                        TextField("ON Message", text: $message)
                        // You could add another field for OFF message
                    case .slider:
                        HStack {
                            Text("Min:")
                            TextField("Min Value", value: $minValue, formatter: NumberFormatter())
                        }
                        HStack {
                            Text("Max:")
                            TextField("Max Value", value: $maxValue, formatter: NumberFormatter())
                        }
                    case .temperatureDisplay, .dataDisplay:
                        EmptyView() // These are display-only modules
                    }
                }
            }
            .navigationBarTitle("Configure Module", displayMode: .inline)
            .navigationBarItems(
                leading: Button("Cancel", action: onCancel),
                trailing: Button("Save", action: onSave)
                    .disabled(selectedTopic.isEmpty)
            )
        }
    }
}

// Expanded control types
enum ControlType: String, Codable, CaseIterable {
    case button = "Button"
    case slider = "Slider"
    case toggle = "Toggle"
    case temperatureDisplay = "Temperature Display"
    case dataDisplay = "Data Display"
}

// Control module model
struct ControlModule {
    let name: String
    let description: String
    let type: ControlType
    let icon: Image
    let color: Color
    
    // Predefined modules
    static let allModules: [ControlModule] = [
        ControlModule(
            name: "Push Button",
            description: "Simple button that sends a command when pressed",
            type: .button,
            icon: Image(systemName: "button.programmable"),
            color: .blue
        ),
        ControlModule(
            name: "Toggle Switch",
            description: "Switch for turning devices on and off",
            type: .toggle,
            icon: Image(systemName: "switch.2"),
            color: .green
        ),
        ControlModule(
            name: "Slider Control",
            description: "Adjustable slider for dimming or levels",
            type: .slider,
            icon: Image(systemName: "slider.horizontal.3"),
            color: .orange
        ),
        ControlModule(
            name: "Temperature Display",
            description: "Show temperature readings from sensors",
            type: .temperatureDisplay,
            icon: Image(systemName: "thermometer"),
            color: .red
        ),
        ControlModule(
            name: "Data Monitor",
            description: "Display sensor readings and data",
            type: .dataDisplay,
            icon: Image(systemName: "chart.bar"),
            color: .purple
        )
    ]
}

// Updated DeviceControl model
struct DeviceControl: Codable, Identifiable {
    let id: Int
    let topic: String
    let message: String
    let controlType: ControlType
    var displayName: String = ""
    var minValue: Double = 0
    var maxValue: Double = 100
}

