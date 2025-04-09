import SwiftUI

struct DataSelect: View {
    @ObservedObject var mqttBroker: MQTTBroker
    @Binding var selectedDataPoint: MQTTBroker.DataPoint?
    @State private var searchText: String = ""
    @State private var expandedDevices: Set<String> = []
    @State private var expandedCategories: [String: Set<String>] = [:]
    
    var devices: [String] {
        return mqttBroker.getAllDevices()
    }
    
    func groupedDataPoints(for deviceId: String) -> [String: [MQTTBroker.DataPoint]] {
        let dataPoints = mqttBroker.getAllDataPoints(deviceId: deviceId)
        let filteredPoints = searchText.isEmpty
            ? dataPoints
            : dataPoints.filter {
                $0.name.lowercased().contains(searchText.lowercased()) ||
                $0.path.lowercased().contains(searchText.lowercased())
              }
        
        var grouped: [String: [MQTTBroker.DataPoint]] = [:]
        
        for point in filteredPoints {
            var category = "Other"
            
            let path = point.path.lowercased()
            if path.contains("temp") {
                category = "Temperature"
            } else if path.contains("humid") {
                category = "Humidity"
            } else if path.contains("power") || path.contains("energy") || path.contains("current") || path.contains("voltage") {
                category = "Power"
            } else if path.contains("light") || path.contains("brightness") || path.contains("color") {
                category = "Lighting"
            } else if path.contains("switch") || path.contains("relay") || path.contains("output") {
                category = "Switches"
            } else if path.contains("sensor") {
                category = "Sensors"
            } else if path.contains("status") {
                category = "Status"
            } else {
                
                switch point.type {
                case .numeric: category = "Numeric Values"
                case .boolean: category = "Boolean Values"
                case .text: category = "Text Values"
                case .object: category = "Objects"
                case .array: category = "Arrays"
                case .unknown: category = "Unknown"
                }
            }
            
            if grouped[category] == nil {
                grouped[category] = []
            }
            grouped[category]?.append(point)
        }
        
        return grouped
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search data points", text: $searchText)
                    .disableAutocorrection(true)
                
                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(10)
            .background(Color(.systemGray6))
            .cornerRadius(8)
            .padding(.horizontal)
            .padding(.top)
            
            if devices.isEmpty {
                noDeviceView
            } else {
                dataView
            }
        }
    }
    
    private var noDeviceView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 50))
                .foregroundColor(.secondary)
            
            Text("No MQTT Devices")
                .font(.title2)
                .foregroundColor(.secondary)
            
            Text("Connect to your MQTT broker and search for devices")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 32)
            
            Spacer()
        }
    }
    
    private var dataView: some View {
        List {
            ForEach(devices, id: \.self) { deviceId in
                deviceSection(deviceId)
            }
        }
        .listStyle(InsetGroupedListStyle())
    }
    
    private func deviceSection(_ deviceId: String) -> some View {
        let isExpanded = expandedDevices.contains(deviceId)
        let grouped = groupedDataPoints(for: deviceId)
        
        return Section {
            if isExpanded {
                ForEach(Array(grouped.keys.sorted()), id: \.self) { category in
                    categoryRow(deviceId: deviceId, category: category, dataPoints: grouped[category] ?? [])
                }
            }
        } header: {
            deviceHeader(deviceId, isExpanded: isExpanded, hasDataPoints: !grouped.isEmpty)
        }
    }
    
    private func deviceHeader(_ deviceId: String, isExpanded: Bool, hasDataPoints: Bool) -> some View {
        Button(action: {
            toggleDeviceExpansion(deviceId)
        }) {
            HStack {
                Image(systemName: "chevron.right")
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    .animation(.spring(), value: isExpanded)
                
                Text(mqttBroker.deviceContexts[deviceId]?.displayName ?? deviceId)
                    .font(.headline)
                
                Spacer()
                
                HStack(spacing: 4) {
                    if hasDataPoints {
                        let totalPoints = groupedDataPoints(for: deviceId).values.reduce(0) { $0 + $1.count }
                        Text("\(totalPoints)")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.blue)
                            .cornerRadius(8)
                    }
                    
                    if let isOnline = mqttBroker.deviceContexts[deviceId]?.isOnline {
                        Circle()
                            .fill(isOnline ? Color.green : Color.red)
                            .frame(width: 8, height: 8)
                    }
                }
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func categoryRow(deviceId: String, category: String, dataPoints: [MQTTBroker.DataPoint]) -> some View {
        let isExpanded = expandedCategories[deviceId]?.contains(category) ?? false
        
        return Group {
            Button(action: {
                toggleCategoryExpansion(deviceId: deviceId, category: category)
            }) {
                HStack {
                    Image(systemName: "chevron.right")
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .animation(.spring(), value: isExpanded)
                        .font(.system(size: 12))
                    
                    Text(category)
                        .font(.subheadline)
                    
                    Spacer()
                    
                    Text("\(dataPoints.count)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 6)
                .padding(.leading, 20)
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            
            if isExpanded {
                ForEach(dataPoints) { dataPoint in
                    dataPointRow(dataPoint)
                        .padding(.leading, 40)
                }
            }
        }
    }
    
    private func dataPointRow(_ dataPoint: MQTTBroker.DataPoint) -> some View {
        Button(action: {
            selectedDataPoint = dataPoint
        }) {
            HStack {
                Image(systemName: dataPoint.type.iconName)
                    .foregroundColor(dataPoint.type.color)
                    .frame(width: 24, height: 24)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(dataPoint.name)
                        .font(.body)
                    
                    Text(dataPoint.path)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                Text(mqttBroker.getFormattedValue(for: dataPoint))
                    .font(.callout)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
            .background(selectedDataPoint?.id == dataPoint.id ?
                       Color.blue.opacity(0.1) : Color.clear)
            .cornerRadius(4)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
    private func toggleDeviceExpansion(_ deviceId: String) {
        if expandedDevices.contains(deviceId) {
            expandedDevices.remove(deviceId)
        } else {
            expandedDevices.insert(deviceId)
        }
    }
    
    private func toggleCategoryExpansion(deviceId: String, category: String) {
        if expandedCategories[deviceId] == nil {
            expandedCategories[deviceId] = []
        }
        
        if expandedCategories[deviceId]?.contains(category) ?? false {
            expandedCategories[deviceId]?.remove(category)
        } else {
            expandedCategories[deviceId]?.insert(category)
        }
    }
}

import SwiftUI

struct DataPointSelectorSheet: View {
    @ObservedObject var mqttBroker: MQTTBroker
    @Binding var selectedDataPoint: MQTTBroker.DataPoint?
    @Environment(\.presentationMode) var presentationMode
    
    @State private var searchText: String = ""
    @State private var selectedDevice: String? = nil
    @State private var filteredPoints: [MQTTBroker.DataPoint] = []
    
    // Optional device ID to filter data points
    var deviceId: Int? = nil
    
    var devices: [String] {
        mqttBroker.getAllDevices()
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                VStack(spacing: 12) {
                    Picker("Device", selection: $selectedDevice) {
                        Text("All Devices").tag(Optional<String>(nil))
                        ForEach(devices, id: \.self) { device in
                            HStack {
                                Text(mqttBroker.deviceContexts[device]?.displayName ?? device)
                                if let isOnline = mqttBroker.deviceContexts[device]?.isOnline, !isOnline {
                                    Circle()
                                        .fill(Color.red)
                                        .frame(width: 8, height: 8)
                                }
                            }
                            .tag(Optional(device))
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        
                        TextField("Search data points", text: $searchText)
                            .onChange(of: searchText) { _, _ in filterDataPoints() }
                            .onChange(of: selectedDevice) { _, _ in filterDataPoints() }
                        
                        if !searchText.isEmpty {
                            Button(action: {
                                searchText = ""
                                filterDataPoints()
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(10)
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                }
                .padding()
                .background(Color(.systemBackground))
                
                Divider()
                
                if filteredPoints.isEmpty {
                    emptyStateView
                } else {
                    List {
                        ForEach(filteredPoints) { dataPoint in
                            dataPointRow(dataPoint)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedDataPoint = dataPoint
                                    presentationMode.wrappedValue.dismiss()
                                }
                        }
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationBarTitle("Select Data Point", displayMode: .inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
            .onAppear {
                filterDataPoints()
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            if devices.isEmpty {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 50))
                    .foregroundColor(.secondary)
                
                Text("No MQTT Devices")
                    .font(.title2)
                    .foregroundColor(.secondary)
                
                Text("Connect to your MQTT broker and search for devices")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 32)
            } else {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 50))
                    .foregroundColor(.secondary)
                
                Text("No Matching Data Points")
                    .font(.title2)
                    .foregroundColor(.secondary)
                
                Text("Try adjusting your search or select a different device")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 32)
            }
            
            Spacer()
        }
    }
    
    private func dataPointRow(_ dataPoint: MQTTBroker.DataPoint) -> some View {
        HStack {
            Image(systemName: dataPoint.type.iconName)
                .foregroundColor(dataPoint.type.color)
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(dataPoint.name)
                    .font(.headline)
                
                Text(dataPoint.path)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            Text(mqttBroker.getFormattedValue(for: dataPoint))
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 6)
        .background(selectedDataPoint?.id == dataPoint.id ?
                    Color.blue.opacity(0.1) : Color.clear)
    }
    
    private func filterDataPoints() {
        var deviceTopicPrefix: String? = nil
        
        if let deviceId = deviceId {
            if let device = DeviceManager.shared.getDevice(withId: deviceId),
               let mqttTopic = device.mqttTopic, !mqttTopic.isEmpty {
                deviceTopicPrefix = mqttTopic
            }
        }
        
        let allPoints = mqttBroker.searchDataPoints(
            query: searchText,
            deviceId: selectedDevice
        )
        
        if let prefix = deviceTopicPrefix {
            filteredPoints = allPoints.filter { dataPoint in
                dataPoint.path.hasPrefix(prefix)
            }
        } else {
            filteredPoints = allPoints
        }
    }
}
