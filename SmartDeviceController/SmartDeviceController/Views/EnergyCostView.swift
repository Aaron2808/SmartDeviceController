import SwiftUI
import Charts

struct EnergyCostView: View {
    @ObservedObject private var mqttBroker = MQTTBroker.shared
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedDevices: [String: Bool] = [:]
    @State private var deviceDataPoints: [String: MQTTBroker.DataPoint] = [:]
    @State private var costPerKWh: Double = 0.20
    @State private var timeframe: TimeframeOption = .hourly
    @State private var showIndividualGraphs: Bool = false
    @State private var energyReadings: [EnergyReading] = []
    @State private var refreshTimer: Timer? = nil
    @State private var showingDataPointSelector = false
    @State private var currentDeviceForDataPoint: String? = nil
    
    // Energy consumption and cost calculations
    @State private var totalPowerUsage: Double = 0
    @State private var estimatedHourlyCost: Double = 0
    @State private var estimatedDailyCost: Double = 0
    @State private var estimatedMonthlyCost: Double = 0
    
    enum TimeframeOption: String, CaseIterable, Identifiable {
        case hourly = "Hourly"
        case daily = "Daily"
        case weekly = "Weekly"
        case monthly = "Monthly"
        
        var id: String { self.rawValue }
    }
    
    struct EnergyReading: Identifiable {
        let id = UUID()
        let deviceId: String
        let timestamp: Date
        let power: Double // in watts
        
        // Add a display name computed property for the chart
        var deviceDisplayName: String {
            MQTTBroker.shared.deviceContexts[deviceId]?.displayName ?? deviceId
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header with cost settings and summary
                VStack(spacing: 12) {
                    // Cost configuration row
                    HStack(spacing: 16) {
                        HStack {
                            Text("Cost/kWh:")
                                .font(.subheadline)
                            
                            TextField("Cost", value: $costPerKWh, format: .number.precision(.fractionLength(2)))
                                .keyboardType(.decimalPad)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .frame(width: 60)
                            
                            Text("$")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Divider()
                            .frame(height: 24)
                        
                        // Total power display
                        HStack {
                            Image(systemName: "bolt.fill")
                                .foregroundColor(.yellow)
                                .font(.subheadline)
                            
                            Text("\(String(format: "%.1f", totalPowerUsage)) W")
                                .font(.headline)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Timeframe selector replaces cost summary row
                    Picker("Timeframe", selection: $timeframe) {
                        ForEach(TimeframeOption.allCases) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal)
                    
                    // Space for spacing only
                    Spacer()
                        .frame(height: 0)
                }
                .padding(.vertical, 12)
                .background(Color(.secondarySystemBackground))
                
                // Energy graph
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Energy Usage")
                            .font(.headline)
                        
                        Spacer()
                        
                        Toggle("Individual", isOn: $showIndividualGraphs)
                            .labelsHidden()
                        
                        Text("Individual")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    .padding(.top, 16)
                    
                    if !energyReadings.isEmpty {
                        // Combined graph
                        if !showIndividualGraphs {
                            VStack(spacing: 10) {
                                combinedEnergyGraph
                                    .frame(height: 220)
                                    .padding(.horizontal, 8)
                                
                                // Cost for selected timeframe
                                costSummaryForTimeframe
                            }
                        } else {
                            // Individual graphs for each device
                            VStack(spacing: 10) {
                                individualEnergyGraphs
                                    .padding(.horizontal, 8)
                                
                                // Cost for selected timeframe
                                costSummaryForTimeframe
                            }
                        }
                    } else {
                        VStack(spacing: 10) {
                            Text("No energy data to display")
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .frame(height: 220)
                            
                            // Cost for selected timeframe even if no data
                            costSummaryForTimeframe
                        }
                    }
                }
                .padding(.bottom)
                
                // Device list
                List {
                    Section(header: Text("Monitored Devices")) {
                        if mqttBroker.getAllDevices().isEmpty {
                            Text("No MQTT devices available")
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .listRowBackground(Color.clear)
                        } else {
                            ForEach(mqttBroker.getAllDevices(), id: \.self) { deviceId in
                                deviceRow(deviceId)
                            }
                        }
                    }
                }
                .listStyle(InsetGroupedListStyle())
            }
            .navigationTitle("Energy Costs")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        refreshEnergyReadings()
                    }) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .onAppear {
                initializeDeviceSelection()
                startPeriodicRefresh()
            }
            .onDisappear {
                refreshTimer?.invalidate()
                refreshTimer = nil
            }
            .sheet(isPresented: $showingDataPointSelector) {
                if let deviceId = currentDeviceForDataPoint {
                    // Temporary binding for the sheet
                    let tempBinding = Binding<MQTTBroker.DataPoint?>(
                        get: { deviceDataPoints[deviceId] },
                        set: { newValue in
                            if let newValue = newValue {
                                deviceDataPoints[deviceId] = newValue
                            }
                        }
                    )
                    
                    DataPointSelectorSheet(
                        mqttBroker: mqttBroker,
                        selectedDataPoint: tempBinding
                    )
                }
            }
        }
    }
    
    // Cost summary specific to the selected timeframe
    private var costSummaryForTimeframe: some View {
        HStack {
            Spacer()
            
            VStack(alignment: .center, spacing: 4) {
                Text("\(timeframe.rawValue) Cost Estimate")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text(costValueForTimeframe)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
        .background(Color(.tertiarySystemBackground))
        .cornerRadius(10)
        .padding(.horizontal)
    }
    
    private var costValueForTimeframe: String {
        switch timeframe {
        case .hourly:
            return "$\(String(format: "%.2f", estimatedHourlyCost))"
        case .daily:
            return "$\(String(format: "%.2f", estimatedDailyCost))"
        case .weekly:
            return "$\(String(format: "%.2f", estimatedDailyCost * 7))"
        case .monthly:
            return "$\(String(format: "%.2f", estimatedMonthlyCost))"
        }
    }
    
    private func deviceRow(_ deviceId: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Toggle(isOn: Binding(
                    get: { selectedDevices[deviceId] ?? false },
                    set: {
                        selectedDevices[deviceId] = $0
                        if $0 && deviceDataPoints[deviceId] == nil {
                            // Auto-find power data point when enabling a device
                            findPowerDataPoint(for: deviceId)
                        }
                        // Refresh after toggling
                        refreshEnergyReadings()
                    }
                )) {
                    HStack {
                        Text(mqttBroker.deviceContexts[deviceId]?.displayName ?? deviceId)
                            .fontWeight(.medium)
                        
                        if let isOnline = mqttBroker.deviceContexts[deviceId]?.isOnline {
                            Circle()
                                .fill(isOnline ? Color.green : Color.red)
                                .frame(width: 8, height: 8)
                        }
                    }
                }
            }
            
            if selectedDevices[deviceId] == true {
                HStack {
                    // Data point selection button
                    Button(action: {
                        currentDeviceForDataPoint = deviceId
                        showingDataPointSelector = true
                    }) {
                        HStack {
                            if let dataPoint = deviceDataPoints[deviceId] {
                                Label(dataPoint.name, systemImage: "bolt.fill")
                                    .font(.subheadline)
                                    .foregroundColor(.primary)
                            } else {
                                Label("Select Data Point", systemImage: "plus.circle")
                                    .font(.subheadline)
                                    .foregroundColor(.blue)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Spacer()
                    
                    // Current power reading
                    if let dataPoint = deviceDataPoints[deviceId],
                       let value = mqttBroker.getValue(for: dataPoint),
                       let powerValue = value.asDouble() {
                        Text("\(String(format: "%.1f", powerValue)) W")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(4)
                    }
                }
                .padding(.leading, 34) // Indent to align with toggle text
            }
        }
    }
    
    private var combinedEnergyGraph: some View {
        Chart {
            ForEach(energyReadings) { reading in
                LineMark(
                    x: .value("Time", reading.timestamp),
                    y: .value("Power (W)", reading.power)
                )
                .foregroundStyle(by: .value("Device", reading.deviceDisplayName))
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic) { value in
                AxisGridLine()
                AxisTick()
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(timeString(for: date))
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(values: .automatic) { value in
                AxisGridLine()
                AxisTick()
                if let doubleValue = value.as(Double.self) {
                    AxisValueLabel {
                        Text("\(Int(doubleValue)) W")
                    }
                }
            }
        }
        .chartLegend(position: .bottom, alignment: .center)
    }
    
    private func timeString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: date)
    }
    
    private var individualEnergyGraphs: some View {
        let deviceIds = Set(energyReadings.map { $0.deviceId })
        
        return VStack(spacing: 20) {
            ForEach(Array(deviceIds), id: \.self) { deviceId in
                let deviceReadings = energyReadings.filter { $0.deviceId == deviceId }
                
                if !deviceReadings.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(mqttBroker.deviceContexts[deviceId]?.displayName ?? deviceId)
                            .font(.headline)
                        
                        Chart {
                            ForEach(deviceReadings) { reading in
                                LineMark(
                                    x: .value("Time", reading.timestamp),
                                    y: .value("Power (W)", reading.power)
                                )
                                .foregroundStyle(Color.blue)
                            }
                        }
                        .frame(height: 120)
                        .chartXAxis {
                            AxisMarks(values: .automatic) { value in
                                AxisGridLine()
                                AxisTick()
                                AxisValueLabel {
                                    if let date = value.as(Date.self) {
                                        Text(timeString(for: date))
                                    }
                                }
                            }
                        }
                        .chartYAxis {
                            AxisMarks(values: .automatic) { value in
                                AxisGridLine()
                                AxisTick()
                                if let doubleValue = value.as(Double.self) {
                                    AxisValueLabel {
                                        Text("\(Int(doubleValue)) W")
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                    .background(Color(.tertiarySystemBackground))
                    .cornerRadius(10)
                }
            }
        }
    }
    
    private func initializeDeviceSelection() {
        // Initialize selected devices to false if not already set
        for deviceId in mqttBroker.getAllDevices() {
            if selectedDevices[deviceId] == nil {
                selectedDevices[deviceId] = false
            }
        }
        
        // Try to automatically detect power data points
        for deviceId in mqttBroker.getAllDevices() {
            if deviceDataPoints[deviceId] == nil {
                findPowerDataPoint(for: deviceId)
            }
        }
        
        refreshEnergyReadings()
    }
    
    private func findPowerDataPoint(for deviceId: String) {
        let dataPoints = mqttBroker.getAllDataPoints(deviceId: deviceId)
        
        // Look for data points that might represent power
        let powerKeywords = ["power", "watt", "energy", "consumption", "apower"]
        
        for dataPoint in dataPoints {
            let path = dataPoint.path.lowercased()
            let name = dataPoint.name.lowercased()
            
            // Check if this is a numeric data point
            if dataPoint.type == .numeric {
                // Check if the path or name contains any of the power keywords
                for keyword in powerKeywords {
                    if path.contains(keyword) || name.contains(keyword) {
                        deviceDataPoints[deviceId] = dataPoint
                        return
                    }
                }
            }
        }
    }
    
    private func refreshEnergyReadings() {
        // Generate sample data based on current power readings
        // In a real app, you would maintain historical data
        
        var newReadings: [EnergyReading] = []
        var totalPower: Double = 0
        
        for (deviceId, isSelected) in selectedDevices {
            if isSelected, let dataPoint = deviceDataPoints[deviceId],
               let value = mqttBroker.getValue(for: dataPoint),
               let powerValue = value.asDouble() {
                
                // Add current reading
                let now = Date()
                newReadings.append(EnergyReading(
                    deviceId: deviceId,
                    timestamp: now,
                    power: powerValue
                ))
                
                // Generate some historical data for visualization
                for i in 1...10 {
                    let pastTime = now.addingTimeInterval(Double(-i * 5 * 60)) // 5-minute intervals
                    // Add some random variation to the power value for visualization
                    let variation = Double.random(in: 0.9...1.1)
                    newReadings.append(EnergyReading(
                        deviceId: deviceId,
                        timestamp: pastTime,
                        power: powerValue * variation
                    ))
                }
                
                // Add to total power
                totalPower += powerValue
            }
        }
        
        // Sort readings by timestamp
        newReadings.sort { $0.timestamp < $1.timestamp }
        
        // Update state
        energyReadings = newReadings
        totalPowerUsage = totalPower
        
        // Calculate estimated costs
        calculateCosts()
    }
    
    private func calculateCosts() {
        // Power is in watts, convert to kilowatts
        let totalKW = totalPowerUsage / 1000.0
        
        // Calculate hourly cost
        estimatedHourlyCost = totalKW * costPerKWh
        
        // Calculate daily cost (assuming 24 hours)
        estimatedDailyCost = estimatedHourlyCost * 24
        
        // Calculate monthly cost (assuming 30 days)
        estimatedMonthlyCost = estimatedDailyCost * 30
    }
    
    private func startPeriodicRefresh() {
        // Refresh data periodically (every 30 seconds)
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
            refreshEnergyReadings()
        }
        
        if let timer = refreshTimer {
            RunLoop.current.add(timer, forMode: .common)
        }
    }
}

struct EnergyCostView_Previews: PreviewProvider {
    static var previews: some View {
        EnergyCostView()
    }
}
