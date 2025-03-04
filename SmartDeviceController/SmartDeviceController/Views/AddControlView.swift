import SwiftUI

// Main view for adding controls
import SwiftUI

// Main view for adding controls
struct AddControlView: View {
    @Binding var controls: [DeviceControl]
    let deviceId: Int
    let saveControls: () -> Void
    
    // Fix: Use a consistent reference to the shared MQTT broker
    @ObservedObject private var mqttBroker = MQTTBroker.shared
    @Environment(\.presentationMode) var presentationMode
    
    // Current selection states
    @State private var selectedModule: ControlModule?
    @State private var selectedTopic: String = ""
    @State private var message: String = ""
    @State private var minValue: Double = 0
    @State private var maxValue: Double = 100
    @State private var displayName: String = ""
    @State private var selectedDataPoint: MQTTBroker.DataPoint? = nil
    @State private var useDataPoint: Bool = false
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
                                    // Initialize values
                                    displayName = module.name
                                    // Auto-enable data point selection for display modules
                                    useDataPoint = (module.type == .temperatureDisplay || module.type == .dataDisplay)
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
                        minValue: $minValue,
                        maxValue: $maxValue,
                        displayName: $displayName,
                        selectedDataPoint: $selectedDataPoint,
                        useDataPoint: $useDataPoint,
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
        // Print debug info
        print("Adding control with dataPointId: \(selectedDataPoint?.id ?? "nil")")
        print("Selected topic: \(selectedTopic)")
        print("Using data point: \(useDataPoint)")
        
        // Fix: Ensure we have a valid topic, either from direct selection or from a data point
        let topicToUse: String
        if useDataPoint, let dataPoint = selectedDataPoint {
            topicToUse = dataPoint.path
        } else {
            topicToUse = selectedTopic
        }
        
        // Create the new control with the data point ID if one was selected
        let newControl = DeviceControl(
            id: UUID().hashValue,
            topic: topicToUse,
            message: message,
            controlType: module.type,
            displayName: displayName.isEmpty ? module.name : displayName,
            minValue: minValue,
            maxValue: maxValue,
            dataPointId: useDataPoint ? selectedDataPoint?.id : nil  // Only use data point ID if useDataPoint is true
        )
        
        // Add to controls array and save
        controls.append(newControl)
        saveControls()
        presentationMode.wrappedValue.dismiss()
        
        // Reset selection states
        resetSelectionStates()
    }
    
    private func resetSelectionStates() {
        selectedModule = nil
        selectedTopic = ""
        message = ""
        minValue = 0
        maxValue = 100
        displayName = ""
        selectedDataPoint = nil
        useDataPoint = false
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
// Configuration sheet for the selected module
// Configuration sheet for the selected module
struct ModuleConfigSheet: View {
    let moduleType: ControlType
    let topics: [String]
    @Binding var selectedTopic: String
    @Binding var message: String
    @Binding var minValue: Double
    @Binding var maxValue: Double
    @Binding var displayName: String
    @Binding var selectedDataPoint: MQTTBroker.DataPoint?
    @Binding var useDataPoint: Bool
    let onSave: () -> Void
    let onCancel: () -> Void
    
    @State private var showDataPointSelector = false
    
    // Fix: Use a consistent reference to the shared MQTT broker
    @ObservedObject private var mqttBroker = MQTTBroker.shared
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Basic Configuration")) {
                    TextField("Display Name", text: $displayName)
                    
                    // Option to use a data point instead of a raw topic
                    if moduleType == .temperatureDisplay || moduleType == .dataDisplay {
                        // For display modules, always use data points
                        // We'll handle this in onAppear instead of direct assignment
                        dataPointSelectionButton
                    } else {
                        // For control modules, give the choice
                        Toggle("Use Data Point", isOn: $useDataPoint)
                            .onChange(of: useDataPoint) { newValue in
                                if !newValue {
                                    selectedDataPoint = nil
                                }
                            }
                        
                        if useDataPoint {
                            dataPointSelectionButton
                        } else {
                            Picker("MQTT Topic", selection: $selectedTopic) {
                                Text("Select a Topic").tag("")
                                ForEach(topics, id: \.self) { topic in
                                    Text(topic).tag(topic)
                                }
                            }
                        }
                    }
                }
                
                Section(header: Text("Control Settings")) {
                    switch moduleType {
                    case .button:
                        TextField("Button Message", text: $message)
                    case .toggle:
                        TextField("ON Message", text: $message)
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
                        if selectedDataPoint == nil {
                            Text("Please select a data point to display")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // Preview of selected data point value, if any
                if let dataPoint = selectedDataPoint {
                    Section(header: Text("Data Point Preview")) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(dataPoint.name)
                                    .font(.headline)
                                Text(dataPoint.path)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Text(mqttBroker.getFormattedValue(for: dataPoint))
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationBarTitle("Configure Module", displayMode: .inline)
            .navigationBarItems(
                leading: Button("Cancel", action: onCancel),
                trailing: Button("Save") {
                    saveModule()
                }
                .disabled(shouldDisableSaveButton)
            )
            .sheet(isPresented: $showDataPointSelector) {
                // Data point selector sheet
                DataPointSelectorSheet(
                    mqttBroker: mqttBroker,
                    selectedDataPoint: $selectedDataPoint
                )
            }
            .onAppear {
                // Set useDataPoint to true for display modules
                if moduleType == .temperatureDisplay || moduleType == .dataDisplay {
                    useDataPoint = true
                }
            }
        }
    }
    
    // Determine if Save button should be disabled
    private var shouldDisableSaveButton: Bool {
        if moduleType == .temperatureDisplay || moduleType == .dataDisplay {
            // For display modules, require a data point
            return selectedDataPoint == nil
        } else if useDataPoint {
            // If using a data point, require a selected data point
            return selectedDataPoint == nil
        } else {
            // If using a topic directly, require a selected topic
            return selectedTopic.isEmpty
        }
    }
    
    // Button to select a data point
    private var dataPointSelectionButton: some View {
        Button(action: {
            showDataPointSelector = true
        }) {
            HStack {
                if let dataPoint = selectedDataPoint {
                    Text(dataPoint.name)
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
    
    // Save the configured module
    private func saveModule() {
        // Fix: If we're using a data point, get the topic from the data point path directly
        if useDataPoint, let dataPoint = selectedDataPoint {
            selectedTopic = dataPoint.path
        }
        
        onSave()
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
    var dataPointId: String? = nil  // Add this line
}

