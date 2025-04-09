import SwiftUI

struct AutomationsView: View {
    let deviceId: Int
    @ObservedObject private var automationManager = AutomationManager.shared
    @ObservedObject private var mqttBroker = MQTTBroker.shared
    @State private var showAddAutomation = false
    @State private var showDeleteAlert = false
    @State private var selectedRuleId: String? = nil
    
    var body: some View {
        NavigationView {
            VStack {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Automations")
                            .font(.title)
                            .fontWeight(.bold)
                    }
                    
                    Spacer()
                    
                    Toggle("", isOn: Binding(
                        get: { automationManager.isProcessingEnabled },
                        set: { automationManager.isProcessingEnabled = $0 }
                    ))
                    .labelsHidden()
                    .onChange(of: automationManager.isProcessingEnabled) { oldValue, newValue in
                        if newValue {
                            automationManager.startMonitoring()
                        } else {
                            automationManager.stopMonitoring()
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top)
                
                let rules = automationManager.getRules(forDevice: deviceId)
                
                if rules.isEmpty {
                    emptyStateView
                } else {
                    List {
                        ForEach(rules) { rule in
                            AutomationRuleRow(rule: rule)
                                .contextMenu {
                                    Button(action: {
                                    }) {
                                        Label("Edit", systemImage: "pencil")
                                    }
                                    
                                    Button(action: {
                                        automationManager.updateRule(id: rule.id, isEnabled: !rule.isEnabled)
                                    }) {
                                        Label(rule.isEnabled ? "Disable" : "Enable",
                                              systemImage: rule.isEnabled ? "pause.fill" : "play.fill")
                                    }
                                    
                                    Divider()
                                    
                                    Button(role: .destructive, action: {
                                        selectedRuleId = rule.id
                                        showDeleteAlert = true
                                    }) {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        selectedRuleId = rule.id
                                        showDeleteAlert = true
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                    }
                }
                
                Button(action: {
                    showAddAutomation = true
                }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                        Text("Add Automation")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .shadow(color: Color.blue.opacity(0.3), radius: 5, x: 0, y: 3)
                }
                .padding()
            }
            .navigationBarTitle("Automations", displayMode: .inline)
            .navigationBarItems(trailing: Button("Done") {
            })
            .alert(isPresented: $showDeleteAlert) {
                Alert(
                    title: Text("Delete Automation"),
                    message: Text("Are you sure you want to delete this automation rule?"),
                    primaryButton: .destructive(Text("Delete")) {
                        if let id = selectedRuleId {
                            automationManager.removeRule(id: id)
                            selectedRuleId = nil
                        }
                    },
                    secondaryButton: .cancel()
                )
            }
            .sheet(isPresented: $showAddAutomation) {
                AddAutomationView(deviceId: deviceId)
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "wand.and.stars")
                .font(.system(size: 50))
                .foregroundColor(.secondary)
            
            Text("No Automations")
                .font(.title2)
                .foregroundColor(.secondary)
        
            Spacer()
        }
    }
}

struct AutomationRuleRow: View {
    let rule: AutomationRule
    @ObservedObject private var mqttBroker = MQTTBroker.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {

            Text(rule.name)
                .font(.headline)
                .foregroundColor(rule.isEnabled ? .primary : .secondary)

            HStack {
                Text("Device:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 60, alignment: .leading)
                
                Text(getSourceDeviceName())
                    .font(.subheadline)
                    .foregroundColor(rule.isEnabled ? .blue : .gray)
            }
            
            HStack {
                Text("Control:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 60, alignment: .leading)
                
                HStack(spacing: 4) {
                    Text(getControlName())
                        .font(.subheadline)
                        .foregroundColor(rule.isEnabled ? .primary : .secondary)
                    
                    Text(getActionText())
                        .font(.subheadline)
                        .foregroundColor(rule.isEnabled ? .orange : .gray)
                }
            }
        }
        .padding(.vertical, 8)
        .opacity(rule.isEnabled ? 1.0 : 0.7)
    }
    
    private func getSourceDeviceName() -> String {
        
        if let device = DeviceManager.shared.getDevice(withId: rule.condition.sourceDeviceId) {
            return device.name
        }
        
        if let deviceContext = mqttBroker.deviceContexts[String(rule.condition.sourceDeviceId)] {
            return deviceContext.displayName
        }
        
        return "Device \(rule.condition.sourceDeviceId)"
    }
    
    private func getControlName() -> String {
        let controls = UserDefaultsManager.shared.getAllControlsFlat()
        if let control = controls.first(where: { $0.id == rule.action.targetControlId }) {
            return control.displayName
        }
        return "Control \(rule.action.targetControlId)"
    }
    
    private func getActionText() -> String {
        switch rule.action.actionType {
        case .turnOn:
            return "On"
        case .turnOff:
            return "Off"
        case .toggle:
            return "Toggle"
        case .setValue:
            if !rule.action.value.isEmpty {
                return "→ \(rule.action.value)"
            } else {
                return "→ Set Value"
            }
        }
    }
}
struct AddAutomationView: View {
    let deviceId: Int
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject private var mqttBroker = MQTTBroker.shared
    @ObservedObject private var automationManager = AutomationManager.shared
    
    @State private var ruleName = ""
    @State private var selectedSourceDeviceId: Int? = nil
    @State private var selectedDataPoint: MQTTBroker.DataPoint? = nil
    @State private var selectedComparator: RuleCondition.Comparator = .greaterThan
    @State private var conditionValue = ""
    
    @State private var selectedTargetControlId: Int? = nil
    @State private var selectedActionType: RuleAction.ActionType = .turnOn
    @State private var actionValue = ""
    
    @State private var showDataPointSelector = false
    @State private var showTargetControlSelector = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Rule Information")) {
                    TextField("Rule Name", text: $ruleName)
                }
                
                Section(header: Text("Condition")) {
                    Picker("Source Device", selection: $selectedSourceDeviceId) {
                        Text("Select a device").tag(Optional<Int>(nil))
                        ForEach(getAllDevices(), id: \.id) { device in
                            Text(device.name).tag(Optional(device.id))
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    
                    if let sourceDeviceId = selectedSourceDeviceId {
                        Button(action: {
                            showDataPointSelector = true
                        }) {
                            HStack {
                                Text("Data Point")
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                if let dataPoint = selectedDataPoint {
                                    Text(dataPoint.name)
                                        .foregroundColor(.secondary)
                                } else {
                                    Text("Select")
                                        .foregroundColor(.blue)
                                }
                                
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            }
                        }
                        
                        Picker("Condition", selection: $selectedComparator) {
                            ForEach(RuleCondition.Comparator.allCases, id: \.self) { comparator in
                                Text(comparator.displayName).tag(comparator)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        
                        TextField("Value", text: $conditionValue)
                            .keyboardType(getKeyboardType())
                    }
                }
                
                Section(header: Text("Action")) {
                    Button(action: {
                        showTargetControlSelector = true
                    }) {
                        HStack {
                            Text("Control")
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            if let controlId = selectedTargetControlId {
                                Text(getControlName(controlId))
                                    .foregroundColor(.secondary)
                            } else {
                                Text("Select")
                                    .foregroundColor(.blue)
                            }
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }
                    
                    if selectedTargetControlId != nil {
                        Picker("Action", selection: $selectedActionType) {
                            ForEach(RuleAction.ActionType.allCases, id: \.self) { actionType in
                                Text(actionType.displayName).tag(actionType)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        
                        if selectedActionType == .setValue {
                            TextField("Value", text: $actionValue)
                                .keyboardType(.decimalPad)
                        }
                    }
                }
                
                Section {
                    Button(action: saveRule) {
                        Text("Save Rule")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .disabled(!isFormValid)
                }
                .listRowInsets(EdgeInsets())
                .padding()
            }
            .navigationBarTitle("Add Automation", displayMode: .inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
            .sheet(isPresented: $showDataPointSelector) {
                DataPointSelectorSheet(
                    mqttBroker: mqttBroker,
                    selectedDataPoint: $selectedDataPoint
                )
            }
            .sheet(isPresented: $showTargetControlSelector) {
                ControlSelectorView(
                    selectedControlId: $selectedTargetControlId
                )
            }
        }
    }
    
    private var isFormValid: Bool {
        !ruleName.isEmpty &&
        selectedSourceDeviceId != nil &&
        selectedDataPoint != nil &&
        !conditionValue.isEmpty &&
        selectedTargetControlId != nil &&
        (selectedActionType != .setValue || !actionValue.isEmpty)
    }
    
    private func saveRule() {
        guard let sourceDeviceId = selectedSourceDeviceId,
              let dataPoint = selectedDataPoint,
              let targetControlId = selectedTargetControlId else {
            return
        }
        
        let condition = RuleCondition(
            sourceDeviceId: sourceDeviceId,
            dataPointId: dataPoint.id,
            comparator: selectedComparator,
            value: conditionValue
        )
        
        let action = RuleAction(
            targetControlId: targetControlId,
            actionType: selectedActionType,
            value: actionValue
        )
        
        let rule = AutomationRule(
            id: UUID().uuidString,
            name: ruleName,
            deviceId: deviceId,
            isEnabled: true,
            condition: condition,
            action: action
        )
        
        automationManager.addRule(rule)
        presentationMode.wrappedValue.dismiss()
    }
    
    private func getKeyboardType() -> UIKeyboardType {
        if let dataPoint = selectedDataPoint {
            switch dataPoint.type {
            case .numeric:
                return .decimalPad
            case .boolean:
                return .default
            default:
                return .default
            }
        }
        return .default
    }
    
    private func getAllDevices() -> [Device] {
        return DeviceManager.shared.loadDevices()
    }
    
    private func getControlName(_ controlId: Int) -> String {
        let controls = getAllControls()
        return controls.first(where: { $0.id == controlId })?.displayName ?? "Control \(controlId)"
    }
    
    private func getAllControls() -> [DeviceControl] {
        var allControls: [DeviceControl] = []
        
        let defaults = UserDefaults.standard
        let dictionaryRepresentation = defaults.dictionaryRepresentation()
        
        for (key, _) in dictionaryRepresentation {
            if key.starts(with: "controls_"),
               let savedData = defaults.data(forKey: key),
               let controls = try? JSONDecoder().decode([DeviceControl].self, from: savedData) {
                allControls.append(contentsOf: controls)
            }
        }
        
        return allControls
    }
}


struct ControlSelectorView: View {
    @Binding var selectedControlId: Int?
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            List {
                ForEach(getAllControls()) { control in
                    Button(action: {
                        selectedControlId = control.id
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        HStack {
                            Image(systemName: control.getIconName())
                                .foregroundColor(control.getCustomColor())
                                .frame(width: 24, height: 24)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(control.displayName)
                                    .font(.headline)
                                
                                Text(control.topic)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            if selectedControlId == control.id {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .navigationBarTitle("Select Control", displayMode: .inline)
            .navigationBarItems(trailing: Button("Cancel") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
    
    private func getAllControls() -> [DeviceControl] {
        var allControls: [DeviceControl] = []
        
        let defaults = UserDefaults.standard
        let dictionaryRepresentation = defaults.dictionaryRepresentation()
        
        for (key, _) in dictionaryRepresentation {
            if key.starts(with: "controls_"),
               let savedData = defaults.data(forKey: key),
               let controls = try? JSONDecoder().decode([DeviceControl].self, from: savedData) {
                allControls.append(contentsOf: controls)
            }
        }
        
        return allControls
    }
}


struct AutomationsView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            AutomationsView(deviceId: 1)
                .previewDisplayName("Empty State")
            
            AutomationsView(deviceId: 999)
                .previewDisplayName("Device 2")
                
            AddAutomationView(deviceId: 1)
                .previewDisplayName("Add Automation")
        }
    }
}

struct MenuRow: View {
    var title: String
    var icon: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .frame(width: 24, height: 24)
            
            Text(title)
                .font(.system(size: 16, weight: .medium))
            
            Spacer()
        }
        .foregroundColor(.primary)
        .padding(.vertical, 12)
        .padding(.horizontal)
        .contentShape(Rectangle())
    }
}

struct AllAutomationsView: View {
    @ObservedObject private var automationManager = AutomationManager.shared
    @Environment(\.presentationMode) var presentationMode
    @State private var showDeleteAlert = false
    @State private var selectedRuleId: String? = nil
    
    var body: some View {
        NavigationView {
            VStack {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("All Automations")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text("Manage your device automations")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Toggle("", isOn: Binding(
                        get: { automationManager.isProcessingEnabled },
                        set: { automationManager.isProcessingEnabled = $0 }
                    ))
                    .labelsHidden()
                    .onChange(of: automationManager.isProcessingEnabled) { oldValue, newValue in
                        if newValue {
                            automationManager.startMonitoring()
                        } else {
                            automationManager.stopMonitoring()
                        }
                    }
                }
                .padding()
                
                if automationManager.automationRules.isEmpty {
                    emptyStateView
                } else {
                    List {
                        ForEach(getDeviceGroups(), id: \.id) { device in
                            Section(header: Text(device.name)) {
                                let deviceRules = automationManager.getRules(forDevice: device.id)
                                ForEach(deviceRules) { rule in
                                    AutomationRuleRow(rule: rule)
                                        .contextMenu {
                                            Button(role: .destructive) {
                                                selectedRuleId = rule.id
                                                showDeleteAlert = true
                                            } label: {
                                                Label("Delete", systemImage: "trash")
                                            }
                                            
                                            Button(action: {
                                                automationManager.updateRule(id: rule.id, isEnabled: !rule.isEnabled)
                                            }) {
                                                Label(rule.isEnabled ? "Disable" : "Enable",
                                                      systemImage: rule.isEnabled ? "pause.fill" : "play.fill")
                                            }
                                        }
                                        .swipeActions(edge: .trailing) {
                                            Button(role: .destructive) {
                                                selectedRuleId = rule.id
                                                showDeleteAlert = true
                                            } label: {
                                                Label("Delete", systemImage: "trash")
                                            }
                                        }
                                }
                            }
                        }
                    }
                }
            }
            .navigationBarTitle("All Automations", displayMode: .inline)
            .navigationBarItems(trailing: Button("Done") {
                presentationMode.wrappedValue.dismiss()
            })
            .alert(isPresented: $showDeleteAlert) {
                Alert(
                    title: Text("Delete Automation"),
                    message: Text("Are you sure you want to delete this automation rule?"),
                    primaryButton: .destructive(Text("Delete")) {
                        if let id = selectedRuleId {
                            automationManager.removeRule(id: id)
                            selectedRuleId = nil
                        }
                    },
                    secondaryButton: .cancel()
                )
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "wand.and.stars")
                .font(.system(size: 50))
                .foregroundColor(.secondary)
            
            Text("No Automation Rules")
                .font(.title2)
                .foregroundColor(.secondary)
            
            Text("Create automations from within your device controls")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 32)
            
            Spacer()
        }
    }
    
    private func getDeviceGroups() -> [Device] {
        
        let deviceIds = Set(automationManager.automationRules.map { $0.deviceId })
        
        return deviceIds.map { deviceId in
            Device(
                id: deviceId,
                name: getDeviceName(deviceId),
                location: "",
                color: .blue,
                image: "devices.homekit",
                mqttTopic: nil
            )
        }.sorted { $0.name < $1.name }
    }
    
    private func getDeviceName(_ deviceId: Int) -> String {

        let sampleDevices = [
            1: "Smart Light",
            2: "Thermostat",
            3: "Smart Plug",
            4: "Humidity Sensor"
        ]
        
        return sampleDevices[deviceId] ?? "Device \(deviceId)"
    }
}


private func getAllDevices() -> [Device] {
    return DeviceManager.shared.loadDevices()
}

