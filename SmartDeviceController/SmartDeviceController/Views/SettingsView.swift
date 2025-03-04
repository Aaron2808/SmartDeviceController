import SwiftUI

struct TopicDetails: Identifiable {
    let id = UUID()
    let topic: String
    let details: String
}

import SwiftUI


struct SettingsView: View {
    // Fix: Using a single consistent reference to the shared instance
    @ObservedObject private var mqttBroker = MQTTBroker.shared
    @State private var selectedTopicDetails: TopicDetails? = nil
    @State private var connectionStatus = "Not Connected"
    @State private var isConnected = false
    @State private var showDataPointBrowser = false
    @State private var selectedDataPoint: MQTTBroker.DataPoint? = nil
    @State private var selectedTabIndex = 0
    @State private var isRefreshing = false
    @State private var connectionTimer: Timer?
    
    func updateConnectionStatus() {
        connectionStatus = isConnected ? "Connected" : "Not Connected"
    }
    
    var body: some View {
        VStack {
            List {
                connectionInfoSection
                connectionButtons
            }
            
            TabView(selection: $selectedTabIndex) {
                // Raw Topic Explorer
                rawTopicExplorerView
                    .tag(0)
                    .tabItem {
                        Image(systemName: "list.bullet")
                        Text("Raw Topics")
                    }
                
                // Data Point Explorer
                dataPointExplorerView
                    .tag(1)
                    .tabItem {
                        Image(systemName: "chart.bar")
                        Text("Data Points")
                    }
            }
            
            HStack {
                Button("Search for Devices") {
                    isRefreshing = true
                    mqttBroker.searchTopics()
                    
                    // Auto-hide the refreshing indicator after 2 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        isRefreshing = false
                    }
                }
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
                
                if isRefreshing {
                    ProgressView()
                        .padding(.leading, 8)
                }
            }
            .padding()
        }
        .sheet(item: $selectedTopicDetails) { details in
            topicDetailsView(details: details)
        }
        .sheet(isPresented: $showDataPointBrowser) {
            DataPointSelectorSheet(
                mqttBroker: mqttBroker,
                selectedDataPoint: $selectedDataPoint
            )
            .onDisappear {
                if selectedDataPoint != nil {
                    showDataPointValue()
                }
            }
        }
        .onAppear {
            // Update connection status when view appears
            isConnected = mqttBroker.isConnected
            updateConnectionStatus()
            setupConnectionStatusUpdater()
        }
        // Fix: Properly invalidate timer when view disappears
        .onDisappear {
            connectionTimer?.invalidate()
            connectionTimer = nil
        }
    }
    
    // Setup a timer to periodically update connection status
    private func setupConnectionStatusUpdater() {
        // Fix: Make sure to invalidate any existing timer first
        connectionTimer?.invalidate()
        
        // Create a repeating timer with a simpler approach
        connectionTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            // Using direct property access
            let connected = self.mqttBroker.isConnected
            if self.isConnected != connected {
                self.isConnected = connected
                self.updateConnectionStatus()
            }
        }
        
        // Make sure timer fires even during scrolling
        if let timer = connectionTimer {
            RunLoop.current.add(timer, forMode: .common)
        }
    }
    
    // Raw topics view
    private var rawTopicExplorerView: some View {
        VStack {
            Text("Raw Topics")
                .font(.title2)
                .bold()
            
            if mqttBroker.groupedTopics.isEmpty {
                noDevicesFoundView
            } else {
                List {
                    ForEach(mqttBroker.groupedTopics.keys.sorted(), id: \.self) { deviceID in
                        DisclosureGroup(deviceID) {
                            ForEach(mqttBroker.groupedTopics[deviceID]!.keys.sorted(), id: \.self) { attribute in
                                Button(action: {
                                    loadTopicDetails(for: deviceID, attribute: attribute)
                                }) {
                                    HStack {
                                        Text(attribute)
                                        Spacer()
                                        Text(mqttBroker.groupedTopics[deviceID]?[attribute] ?? "N/A")
                                            .foregroundColor(.gray)
                                            .lineLimit(1)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    // Data points view
    private var dataPointExplorerView: some View {
        VStack {
            Text("Data Points")
                .font(.title2)
                .bold()
            
            if mqttBroker.deviceContexts.isEmpty {
                noDevicesFoundView
            } else {
                VStack {
                    // Display selected data point if available
                    if let dataPoint = selectedDataPoint {
                        selectedDataPointCard(dataPoint)
                    } else {
                        VStack(spacing: 16) {
                            Image(systemName: "chart.bar.doc.horizontal")
                                .font(.system(size: 50))
                                .foregroundColor(.blue)
                                .padding(.top, 40)
                            
                            Text("No Data Point Selected")
                                .font(.title3)
                            
                            Text("Browse available data points to view their values")
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                                .padding(.bottom, 20)
                        }
                        .frame(maxHeight: .infinity)
                    }
                    
                    // Button to browse data points
                    Button(action: {
                        showDataPointBrowser = true
                    }) {
                        HStack {
                            Image(systemName: "list.bullet.rectangle")
                            Text(selectedDataPoint == nil ? "Browse Data Points" : "Change Data Point")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .padding(.horizontal)
                    }
                }
            }
        }
    }
    
    // Display for "no devices found"
    private var noDevicesFoundView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 50))
                .foregroundColor(.secondary)
            
            Text("No MQTT Devices")
                .font(.title2)
                .foregroundColor(.secondary)
            
            if isConnected {
                Text("Connected but no devices found. Try searching for devices.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 32)
            } else {
                Text("Connect to your MQTT broker and search for devices")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 32)
            }
            
            Spacer()
        }
    }
    
    // Card to display selected data point
    private func selectedDataPointCard(_ dataPoint: MQTTBroker.DataPoint) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Image(systemName: dataPoint.type.iconName)
                    .foregroundColor(.white)
                    .padding(8)
                    .background(dataPoint.type.color)
                    .clipShape(Circle())
                
                VStack(alignment: .leading) {
                    Text(dataPoint.name)
                        .font(.headline)
                    Text(dataPoint.path)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Refresh button
                Button(action: {
                    mqttBroker.objectWillChange.send()
                }) {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(.blue)
                }
            }
            .padding()
            
            Divider()
            
            // Value display
            VStack(spacing: 10) {
                Text("Current Value")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text(mqttBroker.getFormattedValue(for: dataPoint))
                    .font(.system(size: 50, weight: .medium, design: .rounded))
                    .foregroundColor(dataPoint.type.color)
                    .padding()
                
                if let deviceContext = mqttBroker.deviceContexts[dataPoint.deviceId] {
                    HStack {
                        Circle()
                            .fill(deviceContext.isOnline ? Color.green : Color.red)
                            .frame(width: 8, height: 8)
                        
                        Text(deviceContext.displayName)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom)
            
            if let unit = dataPoint.unit {
                Text("Unit: \(unit)")
                    .font(.caption)
                    .padding(8)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(4)
                    .padding(.horizontal)
                    .padding(.bottom)
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        .padding()
    }
    
    private var connectionInfoSection: some View {
        Section(header: Text("Connection Info")) {
            HStack {
                Text("Connection Status:").bold()
                Spacer()
                Text(connectionStatus).foregroundColor(isConnected ? .green : .red)
            }
            HStack {
                Text("Client ID:").bold()
                Spacer()
                Text(mqttBroker.clientID).foregroundColor(.gray)
            }
            HStack {
                Text("Host Address:").bold()
                Spacer()
                Text(mqttBroker.hostAddress).foregroundColor(.gray)
            }
            HStack {
                Text("Port:").bold()
                Spacer()
                Text("\(mqttBroker.port)").foregroundColor(.gray)
            }
        }
    }
    
    private var connectionButtons: some View {
        HStack {
            Button("Connect") {
                mqttBroker.connect()
                
                // Set a short delay to give connection time to establish
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isConnected = mqttBroker.isConnected
                    updateConnectionStatus()
                    
                    // If connected, also search for topics
                    if isConnected {
                        mqttBroker.searchTopics()
                    }
                }
            }
            .frame(width: 150, height: 40)
            .background(isConnected ? Color.gray : Color.blue)
            .foregroundColor(.white)
            .disabled(isConnected)
            
            Spacer()
            
            Button("Disconnect") {
                mqttBroker.disconnect()
                isConnected = false
                updateConnectionStatus()
            }
            .frame(width: 150, height: 40)
            .background(!isConnected ? Color.gray : Color.red)
            .foregroundColor(.white)
            .disabled(!isConnected)
        }
    }
    
    private func loadTopicDetails(for deviceID: String, attribute: String) {
        if let rawMessage = mqttBroker.groupedTopics[deviceID]?[attribute] {
            let formattedDetails = JSONParser.parseAnyJSON(rawMessage)
            selectedTopicDetails = TopicDetails(topic: "\(deviceID)/\(attribute)", details: formattedDetails)
        } else {
            selectedTopicDetails = TopicDetails(topic: "\(deviceID)/\(attribute)", details: "No data available")
        }
    }
    
    private func showDataPointValue() {
        // Switch to data points tab if not already there
        selectedTabIndex = 1
    }
    
    private func topicDetailsView(details: TopicDetails) -> some View {
        VStack {
            Text("Topic Details")
                .font(.title)
                .bold()
            
            Text(details.topic)
                .font(.headline)
                .padding(.bottom)
            
            ScrollView {
                Text(details.details)
                    .padding()
                    .font(.body)
                    .multilineTextAlignment(.leading)
            }
            
            Button("Close") {
                selectedTopicDetails = nil
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
        .padding()
    }
}

// Helper function to format JSON
struct JSONParser {
    static func parseAnyJSON(_ rawJSON: String) -> String {
        // Basic implementation
        if let jsonData = rawJSON.data(using: .utf8),
           let jsonObject = try? JSONSerialization.jsonObject(with: jsonData),
           let prettyJsonData = try? JSONSerialization.data(withJSONObject: jsonObject, options: .prettyPrinted),
           let prettyString = String(data: prettyJsonData, encoding: .utf8) {
            return prettyString
        }
        return rawJSON // Return original if not parseable JSON
    }
}

#Preview {
    SettingsView()
}
