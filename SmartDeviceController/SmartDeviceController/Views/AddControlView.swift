import SwiftUI
import Combine

enum ControlType: String, Codable, CaseIterable {
    case button = "Button"
    case slider = "Slider"
    case toggle = "Toggle"
    case dataDisplay = "Data Display"
}

struct AddControlView: View {
    @Binding var controls: [DeviceControl]
    let deviceId: Int
    let saveControls: () -> Void
    
    @ObservedObject private var mqttBroker = MQTTBroker.shared
    @Environment(\.presentationMode) var presentationMode
    
    @State private var selectedModule: ControlModule?
    @State private var selectedTopic: String = ""
    @State private var message: String = ""
    @State private var minValue: Double = 0
    @State private var maxValue: Double = 100
    @State private var displayName: String = ""
    
    @State private var selectedDataPoint: MQTTBroker.DataPoint? = nil
    @State private var useDataPoint: Bool = false
    
    @State private var showingConfigSheet = false
    @State private var isSheetPresented = false // Track sheet presentation for better state management
    
    @State private var customColor: String? = nil
    @State private var customIcon: String? = nil
    @State private var customUnit: String? = nil
    @State private var backgroundColor: String? = nil
    @State private var textColor: String? = nil
    
    // The device we're configuring
    private var device: Device? {
        return DeviceManager.shared.getDevice(withId: deviceId)
    }
    
    // Filter topics based on device's mqtt topic if available
    private var filteredTopics: [String] {
        return DeviceManager.shared.getFilteredTopics(for: deviceId, from: mqttBroker.topics.sorted())
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    
                    Text("Add Control Modules")
                        .font(.title)
                        .fontWeight(.bold)
                        .padding(.horizontal)
                    
                    Text("Select a module to add to your device")
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                    
                    // Display device topic info if available
                    if let device = device, let deviceTopic = device.mqttTopic, !deviceTopic.isEmpty {
                        HStack {
                            Image(systemName: "link")
                                .foregroundColor(.blue)
                            Text("Filtering topics for: \(deviceTopic)")
                                .font(.subheadline)
                                .foregroundColor(.blue)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                        .padding(.horizontal)
                    }
                    
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 140))], spacing: 16) {
                        ForEach(ControlModule.allModules, id: \.name) { module in
                            ModuleCard(module: module, isSelected: selectedModule?.name == module.name)
                                .onTapGesture {
                                    selectedModule = module
                                    displayName = module.name
                                    useDataPoint = (module.type == .dataDisplay)
                                    
                                    resetOptions(for: module.type)
                                    
                                    // Ensure keyboard is dismissed before presenting sheet
                                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                                    
                                    // Use this state variable to control when the sheet is presented
                                    // Add a slight delay to ensure UI is ready
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                        isSheetPresented = true
                                    }
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
            .fullScreenCover(isPresented: $isSheetPresented, onDismiss: {
                // Make sure we correctly handle the state when the sheet is dismissed
                if !showingConfigSheet {
                    resetSelection()
                }
            }) {
                if let module = selectedModule {
                    // Present as a full screen cover for better keyboard handling
                    ModuleSelect(
                        moduleType: module.type,
                        topics: filteredTopics, // Use filtered topics here
                        deviceId: deviceId,     // Pass the device ID for data point filtering
                        selectedTopic: $selectedTopic,
                        message: $message,
                        minValue: $minValue,
                        maxValue: $maxValue,
                        displayName: $displayName,
                        selectedDataPoint: $selectedDataPoint,
                        useDataPoint: $useDataPoint,
                        customColor: $customColor,
                        customIcon: $customIcon,
                        customUnit: $customUnit,
                        backgroundColor: $backgroundColor,
                        textColor: $textColor,
                        onSave: {
                            addControl(module: module)
                            isSheetPresented = false
                        },
                        onCancel: {
                            isSheetPresented = false
                        }
                    )
                } else {
                    // Fallback empty view - should never happen
                    EmptyView()
                        .onAppear {
                            isSheetPresented = false
                        }
                }
            }
        }
    }
    
    private func resetOptions(for controlType: ControlType) {
        customColor = nil
        customIcon = nil
        customUnit = nil
        backgroundColor = nil
        textColor = nil
    }
    
    /// Add a control with robust saving logic
    func addControl(module: ControlModule) {
        // Determine the topic to use
        let topicToUse: String
        
        if useDataPoint, let dataPoint = selectedDataPoint {
            topicToUse = dataPoint.path
        } else {
            topicToUse = selectedTopic
        }
        
        // Make sure color is set
        if customColor == nil {
            customColor = selectedColor()?.toHex()
        }
        
        // Generate a unique ID
        let controlId = UUID().hashValue
        
        // Create the new control
        let newControl = DeviceControl(
            id: controlId,
            topic: topicToUse,
            message: message,
            controlType: module.type,
            displayName: displayName.isEmpty ? module.name : displayName,
            minValue: minValue,
            maxValue: maxValue,
            dataPointId: useDataPoint ? selectedDataPoint?.id : nil,
            customColor: customColor,
            customIcon: customIcon,
            customUnit: customUnit,
            backgroundColor: backgroundColor,
            textColor: textColor
        )
        
        // Add to controls collection
        controls.append(newControl)
        
        // Save changes
        saveControls()
        
        // Dismiss the view
        presentationMode.wrappedValue.dismiss()
        
        // Reset selection
        resetSelection()
    }
    
    private func resetSelection() {
        selectedModule = nil
        selectedTopic = ""
        message = ""
        minValue = 0
        maxValue = 100
        displayName = ""
        selectedDataPoint = nil
        useDataPoint = false
        
        customColor = nil
        customIcon = nil
        customUnit = nil
        backgroundColor = nil
        textColor = nil
    }
    
    /// Helper to get the selected color
    func selectedColor() -> Color? {
        // Get the color for the selected module
        if let module = selectedModule {
            return module.color
        }
        return nil
    }
}

struct AddControlView_Previews: PreviewProvider {
    static var previews: some View {
        // Create a state object to hold the controls array for the preview
        @State var previewControls: [DeviceControl] = []
        
        // Return the AddControlView with necessary parameters
        return AddControlView(
            controls: .constant([]), // Use a constant binding for the preview
            deviceId: 1,  // Use a sample device ID
            saveControls: { /* Preview doesn't need to save */ }
        )
    }
}
