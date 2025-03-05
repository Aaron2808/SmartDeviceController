import SwiftUI

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
    
    @State private var customColor: String? = nil
    @State private var customIcon: String? = nil
    @State private var customUnit: String? = nil
    @State private var backgroundColor: String? = nil
    @State private var textColor: String? = nil
    
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
                    
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 140))], spacing: 16) {
                        ForEach(ControlModule.allModules, id: \.name) { module in
                            ModuleCard(module: module, isSelected: selectedModule?.name == module.name)
                                .onTapGesture {
                                    selectedModule = module
                                
                                    displayName = module.name
                                    useDataPoint = (module.type == .dataDisplay)
                                    
                                    resetOptions(for: module.type)
                                    
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

                    ModuleSelect(
                        moduleType: module.type,
                        topics: mqttBroker.topics.sorted(),
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
    
    private func resetOptions(for controlType: ControlType) {
        customColor = nil
        customIcon = nil
        customUnit = nil
        backgroundColor = nil
        textColor = nil
    }
    
    private func addControl(module: ControlModule) {
        
        let topicToUse: String
        
        if useDataPoint, let dataPoint = selectedDataPoint {
            topicToUse = dataPoint.path
        } else {
            topicToUse = selectedTopic
        }
        
        let newControl = DeviceControl(
            id: UUID().hashValue,
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
        
        controls.append(newControl)
        saveControls()
        presentationMode.wrappedValue.dismiss()
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
