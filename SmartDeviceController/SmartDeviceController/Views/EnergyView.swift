import SwiftUI
import Charts

enum DataCollectionInterval: Int, CaseIterable, Identifiable {
    case oneMinute = 60
    case fiveMinutes = 300
    case fifteenMinutes = 900
    case thirtyMinutes = 1800
    
    var id: Int { self.rawValue }
    
    var description: String {
        switch self {
        case .oneMinute: return "1 Minute"
        case .fiveMinutes: return "5 Minutes"
        case .fifteenMinutes: return "15 Minutes"
        case .thirtyMinutes: return "30 Minutes"
        }
    }
}

struct EnergyCostView: View {
    @ObservedObject private var mqttBroker = MQTTBroker.shared
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedTimeframe: TimeframeOption = .daily
    @State private var showCombinedGraph: Bool = true
    @State private var showSettings = false
    @State private var isExporting = false
    
    @State private var costPerKWh: Double = 0.20
    @State private var selectedDevices: [String: Bool] = [:]
    @State private var deviceDataPoints: [String: MQTTBroker.DataPoint] = [:]
    
    @State private var collectionInterval: DataCollectionInterval = .fiveMinutes
    
    @State private var energyReadings: [EnergyReading] = []
    @State private var historicalReadings: [String: [EnergyReading]] = [:]
    @State private var dataCollectionEnabled: Bool = true
    @State private var isCollectingData: Bool = false
    @State private var refreshTimer: Timer? = nil
    @State private var dataCollectionTimer: Timer? = nil
    
    @State private var totalPowerUsage: Double = 0
    @State private var totalEnergyConsumption: Double = 0
    @State private var totalEnergyCost: Double = 0
    @State private var deviceEnergies: [String: Double] = [:]
    @State private var deviceCosts: [String: Double] = [:]
    
    // MARK: - Data Structures
    
    struct EnergyReading: Identifiable, Codable, Equatable {
        let id = UUID()
        let deviceId: String
        let timestamp: Date
        let power: Double // in watts
        
        var deviceDisplayName: String {
            MQTTBroker.shared.deviceContexts[deviceId]?.displayName ?? deviceId
        }
    }
    
    enum TimeframeOption: String, CaseIterable, Identifiable {
        case hourly = "Hour"
        case daily = "Day"
        case weekly = "Week"
        case monthly = "Month"
        
        var id: String { self.rawValue }
        
        var timeInterval: TimeInterval {
            switch self {
            case .hourly: return 60 * 60 // 1 hour
            case .daily: return 24 * 60 * 60 // 1 day
            case .weekly: return 7 * 24 * 60 * 60 // 1 week
            case .monthly: return 30 * 24 * 60 * 60 // 1 month
            }
        }
        
        var recordingInterval: TimeInterval {
            switch self {
            case .hourly: return 60 // 1 minute
            case .daily: return 60 * 60 // 1 hour
            case .weekly: return 6 * 60 * 60 // 6 hours
            case .monthly: return 24 * 60 * 60 // 1 day
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                energyGraphView
                energySummaryView
            }
            .navigationTitle("Energy Monitor")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        refreshEnergyData()
                    }) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showSettings = true
                    }) {
                        Image(systemName: "gear")
                    }
                }
            }
            .onAppear {
                initializeDeviceSelection()
                loadHistoricalReadings()
                loadSettings()
                startDataCollection()
                refreshEnergyData()
            }
            .onDisappear {
                refreshTimer?.invalidate()
                refreshTimer = nil
                stopDataCollection()
                saveHistoricalReadings()
            }
            .sheet(isPresented: $showSettings) {
                EnergySettingsView(
                    costPerKWh: $costPerKWh,
                    selectedDevices: $selectedDevices,
                    deviceDataPoints: $deviceDataPoints,
                    dataCollectionEnabled: $dataCollectionEnabled,
                    collectionInterval: $collectionInterval,
                    historicalReadings: $historicalReadings,
                    onSettingsSaved: {
                        if dataCollectionEnabled {
                            restartDataCollection()
                        }
                        saveSettings()
                        saveDeviceSelections()
                        saveDeviceDataPoints()
                        refreshEnergyData()
                    }
                )
            }
            .alert("Data Exported", isPresented: $isExporting) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Energy data has been exported as CSV.")
            }
        }
    }
    
    // MARK: - View Components
    
    /// Energy Graph View
    private var energyGraphView: some View {
        VStack(spacing: 0) {
            // Timeframe selector
            Picker("Timeframe", selection: $selectedTimeframe) {
                ForEach(TimeframeOption.allCases) { option in
                    Text(option.rawValue).tag(option)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal)
            .padding(.top, 16)
            .padding(.bottom, 8)
            
            // Graph View
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Power Usage")
                        .font(.headline)
                    
                    Spacer()
                    
                    // Device selection menu
                    Menu {
                        Button(action: {
                            withAnimation {
                                showCombinedGraph = true
                            }
                        }) {
                            Label("Combined View", systemImage: "chart.line.uptrend.xyaxis")
                        }
                        
                        Divider()
                        
                        ForEach(getSelectedDeviceIds(), id: \.self) { deviceId in
                            Button(action: {
                                withAnimation {
                                    showCombinedGraph = false
                                    showSingleDeviceGraph(deviceId)
                                }
                            }) {
                                let deviceName = mqttBroker.deviceContexts[deviceId]?.displayName ?? deviceId
                                Label(deviceName, systemImage: "chart.bar.xaxis")
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(getCurrentGraphSelectionName())
                                .font(.caption)
                            
                            Image(systemName: "chevron.down")
                                .font(.caption)
                        }
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(12)
                    }
                }
                
                if !energyReadings.isEmpty {
                    if showCombinedGraph {
                        combinedEnergyGraph
                            .frame(height: 250)
                    } else {
                        singleDeviceGraph
                            .frame(height: 250)
                    }
                } else {
                    VStack {
                        noDataView
                    }
                    .frame(height: 250)
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground))
        }
    }
    
    /// Energy summary view with cards
    private var energySummaryView: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                // Current Power Usage
                summaryCard(
                    title: "Current Power",
                    value: "\(String(format: "%.1f", totalPowerUsage)) W",
                    icon: "bolt.fill",
                    iconColor: .yellow
                )
                
                // Total Energy Usage
                summaryCard(
                    title: "Energy Used",
                    value: "\(String(format: "%.2f", totalEnergyConsumption)) kWh",
                    icon: "chart.bar.fill",
                    iconColor: .blue
                )
            }
            
            HStack(spacing: 16) {
                // Current Cost
                summaryCard(
                    title: "Current Cost",
                    value: "$\(String(format: "%.2f", totalEnergyCost))",
                    icon: "dollarsign.circle.fill",
                    iconColor: .green
                )
                
                // Projected Cost (Monthly)
                summaryCard(
                    title: "Projected \(projectedTimeframe)",
                    value: "$\(String(format: "%.2f", projectedCost))",
                    icon: "calendar",
                    iconColor: .purple
                )
            }
        }
        .padding()
    }
    
    /// NEW: Data collection info card
    
    
    /// Get the most recent reading timestamp
    private func getLastReadingTimestamp() -> Date? {
        let timestamps = energyReadings.map { $0.timestamp }
        return timestamps.max()
    }
    
    /// Format the last updated time relative to now
    private func formatLastUpdated(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    /// Card view for summary items
    private func summaryCard(title: String, value: String, icon: String, iconColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(iconColor)
                    .font(.headline)
                
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Text(value)
                .font(.title2)
                .fontWeight(.semibold)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.tertiarySystemBackground))
        .cornerRadius(12)
    }
    
    // Other view components remain unchanged...
    
    // MARK: - Data Management
    
    /// Start collecting data at regular intervals
    private func startDataCollection() {
        guard dataCollectionEnabled, !isCollectingData else { return }
        
        isCollectingData = true
        
        // Use the user-selected collection interval
        let interval = TimeInterval(collectionInterval.rawValue)
        dataCollectionTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            collectCurrentReadings()
        }
        
        if let timer = dataCollectionTimer {
            RunLoop.current.add(timer, forMode: .common)
        }
        
        // Collect initial readings
        collectCurrentReadings()
        
        // Set up a timer to refresh the UI periodically
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
            refreshEnergyData()
        }
        
        if let timer = refreshTimer {
            RunLoop.current.add(timer, forMode: .common)
        }
    }
    
    // Additional necessary methods for EnergyCostView

    /// Get the name for the current graph selection
    private func getCurrentGraphSelectionName() -> String {
        if showCombinedGraph {
            return "Combined View"
        } else if let selectedDeviceId = currentSingleDeviceId {
            return mqttBroker.deviceContexts[selectedDeviceId]?.displayName ?? selectedDeviceId
        } else {
            return "Select Device"
        }
    }

    /// Get array of selected device IDs that have data points
    private func getSelectedDeviceIds() -> [String] {
        return selectedDevices.filter { $0.value && deviceDataPoints[$0.key] != nil }.map { $0.key }
    }

    // State for single device graph
    @State private var currentSingleDeviceId: String? = nil

    /// Show graph for a single device
    private func showSingleDeviceGraph(_ deviceId: String) {
        currentSingleDeviceId = deviceId
    }

    /// Single device graph view
    private var singleDeviceGraph: some View {
        Group {
            if let deviceId = currentSingleDeviceId {
                let deviceReadings = energyReadings.filter { $0.deviceId == deviceId }
                
                if !deviceReadings.isEmpty {
                    let yAxisRange = calculateYAxisRange()
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Chart {
                            ForEach(deviceReadings) { reading in
                                LineMark(
                                    x: .value("Time", reading.timestamp),
                                    y: .value("Power (W)", reading.power)
                                )
                                .foregroundStyle(Color.blue)
                            }
                        }
                        .chartYScale(domain: yAxisRange)
                        .chartXAxis {
                            AxisMarks(values: .automatic) { value in
                                AxisGridLine()
                                AxisTick()
                                AxisValueLabel {
                                    if let date = value.as(Date.self) {
                                        Text(formatDate(date, for: selectedTimeframe))
                                    }
                                }
                            }
                        }
                        .chartYAxis {
                            AxisMarks(values: .automatic) { value in
                                AxisGridLine()
                                AxisTick()
                                AxisValueLabel {
                                    if let doubleValue = value.as(Double.self) {
                                        Text(formatPowerValue(doubleValue))
                                    }
                                }
                            }
                        }
                        
                        // Device energy summary
                        HStack {
                            Text("Energy: \(String(format: "%.2f kWh", deviceEnergies[deviceId] ?? 0))")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Text("Cost: $\(String(format: "%.2f", deviceCosts[deviceId] ?? 0))")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                } else {
                    Text("No data available for this device in the selected timeframe")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            } else {
                Text("Select a device from the dropdown menu")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
        .onChange(of: selectedTimeframe) { oldValue, newValue in
            refreshEnergyData()
        }
    }
    
    /// No data placeholder view
    private var noDataView: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.xyaxis.line")
                .font(.system(size: 40))
                .foregroundColor(.secondary.opacity(0.5))
            
            Text(getEmptyStateMessage())
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    /// Combined energy graph
    private var combinedEnergyGraph: some View {
        let yAxisRange = calculateYAxisRange()
        
        return Chart {
            ForEach(energyReadings) { reading in
                LineMark(
                    x: .value("Time", reading.timestamp),
                    y: .value("Power (W)", reading.power)
                )
                .foregroundStyle(by: .value("Device", reading.deviceDisplayName))
            }
        }
        .chartYScale(domain: yAxisRange)
        .chartXAxis {
            AxisMarks(values: .automatic) { value in
                AxisGridLine()
                AxisTick()
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(formatDate(date, for: selectedTimeframe))
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(values: .automatic) { value in
                AxisGridLine()
                AxisTick()
                AxisValueLabel {
                    if let doubleValue = value.as(Double.self) {
                        Text(formatPowerValue(doubleValue))
                    }
                }
            }
        }
        .chartLegend(position: .bottom, alignment: .center)
        .onChange(of: selectedTimeframe) { oldValue, newValue in
            refreshEnergyData()
        }
    }

    /// Format dates for chart axis based on timeframe
    private func formatDate(_ date: Date, for timeframe: TimeframeOption) -> String {
        let formatter = DateFormatter()
        
        switch timeframe {
        case .hourly:
            formatter.dateFormat = "HH:mm"
        case .daily:
            formatter.dateFormat = "HH:mm"
        case .weekly:
            formatter.dateFormat = "E"
        case .monthly:
            formatter.dateFormat = "d"
        }
        
        return formatter.string(from: date)
    }

    /// Empty state message based on current selection
    private func getEmptyStateMessage() -> String {
        let anyDeviceSelected = selectedDevices.values.contains(true)
        
        if !anyDeviceSelected {
            return "Select devices to monitor their energy usage in Settings"
        }
        
        let anyDataPointSelected = !deviceDataPoints.isEmpty
        if !anyDataPointSelected {
            return "Select a power data point for at least one device in Settings"
        }
        
        return "No energy data available for the selected timeframe"
    }

    /// Get projected timeframe string
    private var projectedTimeframe: String {
        switch selectedTimeframe {
        case .hourly: return "Day"
        case .daily: return "Month"
        case .weekly: return "Month"
        case .monthly: return "Year"
        }
    }

    /// Get projected cost value
    private var projectedCost: Double {
        switch selectedTimeframe {
        case .hourly: return totalEnergyCost * 24
        case .daily: return totalEnergyCost * 30
        case .weekly: return totalEnergyCost * 4
        case .monthly: return totalEnergyCost * 12
        }
    }

    /// Initialize device selection and data points
    private func initializeDeviceSelection() {
        // Load saved device selections
        if let savedData = UserDefaults.standard.data(forKey: "energyCostDeviceSelections"),
           let decoded = try? JSONDecoder().decode([String: Bool].self, from: savedData) {
            // Update with new devices if needed
            for deviceId in mqttBroker.getAllDevices() {
                if decoded[deviceId] == nil {
                    selectedDevices[deviceId] = false
                } else {
                    selectedDevices[deviceId] = decoded[deviceId]
                }
            }
        } else {
            // Initialize selected devices to false if no saved data
            for deviceId in mqttBroker.getAllDevices() {
                selectedDevices[deviceId] = false
            }
        }
        
        // Load saved device data points
        if let savedData = UserDefaults.standard.data(forKey: "energyCostDeviceDataPoints"),
           let decoded = try? JSONDecoder().decode([String: String].self, from: savedData) {
            
            for (deviceId, dataPointId) in decoded {
                if let dataPoint = mqttBroker.getDataPointById(dataPointId) {
                    deviceDataPoints[deviceId] = dataPoint
                }
            }
        }
    }

    /// Save device selections to UserDefaults
    private func saveDeviceSelections() {
        if let encoded = try? JSONEncoder().encode(selectedDevices) {
            UserDefaults.standard.set(encoded, forKey: "energyCostDeviceSelections")
        }
    }

    /// Save device data points to UserDefaults
    private func saveDeviceDataPoints() {
        var dataPointIds: [String: String] = [:]
        
        for (deviceId, dataPoint) in deviceDataPoints {
            dataPointIds[deviceId] = dataPoint.id
        }
        
        if let encoded = try? JSONEncoder().encode(dataPointIds) {
            UserDefaults.standard.set(encoded, forKey: "energyCostDeviceDataPoints")
        }
    }

    /// Stop data collection
    private func stopDataCollection() {
        isCollectingData = false
        dataCollectionTimer?.invalidate()
        dataCollectionTimer = nil
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    /// Restart data collection with updated settings
    private func restartDataCollection() {
        stopDataCollection()
        startDataCollection()
    }

    /// Collect current power readings from all selected devices
    private func collectCurrentReadings() {
        let now = Date()
        
        // Update total power
        updateTotalPowerUsage()
        
        // Collect readings for each selected device
        for (deviceId, isSelected) in selectedDevices {
            guard isSelected, let dataPoint = deviceDataPoints[deviceId] else { continue }
            
            // Get the current power value
            if let value = mqttBroker.getValue(for: dataPoint),
               let powerValue = value.asDouble() {
                
                // Create a new reading
                let reading = EnergyReading(
                    deviceId: deviceId,
                    timestamp: now,
                    power: powerValue
                )
                
                // Add to historical readings
                if historicalReadings[deviceId] == nil {
                    historicalReadings[deviceId] = []
                }
                
                historicalReadings[deviceId]?.append(reading)
            }
        }
        
        // Trim historical readings to keep memory usage reasonable
        trimHistoricalReadings()
    }

    /// Update total power usage across all selected devices
    private func updateTotalPowerUsage() {
        var totalPower: Double = 0
        for (deviceId, isSelected) in selectedDevices {
            if isSelected, let dataPoint = deviceDataPoints[deviceId],
               let value = mqttBroker.getValue(for: dataPoint),
               let power = value.asDouble() {
                totalPower += power
            }
        }
        
        totalPowerUsage = totalPower
    }

    /// Trim historical readings to last 30 days
    private func trimHistoricalReadings() {
        // Keep 30 days of data
        let retentionPeriod = 30
        
        let now = Date()
        let cutoffDate = now.addingTimeInterval(-Double(retentionPeriod) * 24 * 60 * 60)
        
        for deviceId in historicalReadings.keys {
            historicalReadings[deviceId] = historicalReadings[deviceId]?.filter {
                $0.timestamp >= cutoffDate
            }
        }
    }

    
    private func calculateYAxisRange() -> ClosedRange<Double> {
        // Start with default range if there's no data
        if energyReadings.isEmpty {
            return 0...100
        }
        
        // Get min and max power values
        let powerValues = energyReadings.map { $0.power }
        let minPower = powerValues.min() ?? 0
        let maxPower = powerValues.max() ?? 100
        
        // Handle case where all values are 0
        if maxPower == 0 {
            return 0...10 // Show a small range
        }
        
        // For very small values, use a scale that makes them visible
        if maxPower < 1 {
            return 0...1 // Show from 0 to 1W for very small devices
        } else if maxPower < 10 {
            return 0...10 // Show from 0 to 10W for small devices
        }
        
        // Add 10% headroom above max
        let upperBound = maxPower * 1.1
        
        // Round to nice number for upper bound
        let roundedUpperBound: Double
        if upperBound < 50 {
            roundedUpperBound = ceil(upperBound / 5) * 5 // Round to nearest 5
        } else if upperBound < 100 {
            roundedUpperBound = ceil(upperBound / 10) * 10 // Round to nearest 10
        } else if upperBound < 500 {
            roundedUpperBound = ceil(upperBound / 50) * 50 // Round to nearest 50
        } else if upperBound < 1000 {
            roundedUpperBound = ceil(upperBound / 100) * 100 // Round to nearest 100
        } else {
            roundedUpperBound = ceil(upperBound / 500) * 500 // Round to nearest 500
        }
        
        return 0...roundedUpperBound
    }

    /// Formats power values for display with appropriate precision
    private func formatPowerValue(_ value: Double) -> String {
        if value < 1.0 {
            return String(format: "%.2f W", value) // Two decimal places for <1W
        } else if value < 10.0 {
            return String(format: "%.1f W", value) // One decimal place for <10W
        } else {
            return "\(Int(value)) W" // Integer for ≥10W
        }
    }
    
    /// Refresh energy data for the selected timeframe
    private func refreshEnergyData() {
        // Get current date for filtering
        let now = Date()
        
        // Calculate start date based on selected timeframe
        let startDate = now.addingTimeInterval(-selectedTimeframe.timeInterval)
        
        var filteredReadings: [EnergyReading] = []
        deviceEnergies = [:]
        deviceCosts = [:]
        var totalEnergy: Double = 0
        
        for (deviceId, isSelected) in selectedDevices {
            guard isSelected else { continue }
            
            if let deviceReadings = historicalReadings[deviceId] {
                // Filter readings for the selected timeframe
                let timeframeReadings = deviceReadings.filter {
                    $0.timestamp >= startDate && $0.timestamp <= now
                }
                
                filteredReadings.append(contentsOf: timeframeReadings)
                
                // Calculate energy for this device
                let deviceEnergy = calculateEnergy(from: timeframeReadings)
                deviceEnergies[deviceId] = deviceEnergy
                deviceCosts[deviceId] = deviceEnergy * costPerKWh
                totalEnergy += deviceEnergy
            }
        }
        
        // Update state with the filtered readings
        energyReadings = filteredReadings.sorted { $0.timestamp < $1.timestamp }
        totalEnergyConsumption = totalEnergy
        totalEnergyCost = totalEnergy * costPerKWh
    }
    
    
    private func calculateEnergy(from readings: [EnergyReading]) -> Double {
        guard readings.count >= 2 else { return 0 }
        
        let sortedReadings = readings.sorted { $0.timestamp < $1.timestamp }
        var totalEnergy: Double = 0
        
        for i in 1..<sortedReadings.count {
            let prevReading = sortedReadings[i-1]
            let currentReading = sortedReadings[i]
            
            // Calculate time difference in hours
            let timeDiff = currentReading.timestamp.timeIntervalSince(prevReading.timestamp) / 3600
            
            // Average power in kW (trapezoidal integration)
            let avgPower = (prevReading.power + currentReading.power) / 2 / 1000
            
            // Energy in kWh = Power (kW) * Time (h)
            let energyKWh = avgPower * timeDiff
            
            totalEnergy += energyKWh
        }
        
        return totalEnergy
    }

    /// Save historical readings to UserDefaults
    private func saveHistoricalReadings() {
        let encoder = JSONEncoder()
        
        for (deviceId, readings) in historicalReadings {
            if let encoded = try? encoder.encode(readings) {
                UserDefaults.standard.set(encoded, forKey: "energyReadings_\(deviceId)")
            }
        }
    }

    /// Load historical readings from UserDefaults
    private func loadHistoricalReadings() {
        let decoder = JSONDecoder()
        
        for deviceId in mqttBroker.getAllDevices() {
            if let savedData = UserDefaults.standard.data(forKey: "energyReadings_\(deviceId)"),
               let decoded = try? decoder.decode([EnergyReading].self, from: savedData) {
                historicalReadings[deviceId] = decoded
            }
        }
    }
    /// Load settings from UserDefaults
    private func loadSettings() {
        // Load cost per kWh
        let savedCost = UserDefaults.standard.double(forKey: "energyCostPerKWh")
        if savedCost > 0 {
            costPerKWh = savedCost
        }
        
        // Load data collection enabled state
        dataCollectionEnabled = UserDefaults.standard.bool(forKey: "energyDataCollectionEnabled")
        
        // NEW: Load collection interval
        let savedIntervalValue = UserDefaults.standard.integer(forKey: "energyDataCollectionInterval")
        if savedIntervalValue > 0, let savedInterval = DataCollectionInterval(rawValue: savedIntervalValue) {
            collectionInterval = savedInterval
        }
    }
    
    /// Save settings to UserDefaults
    private func saveSettings() {
        UserDefaults.standard.set(costPerKWh, forKey: "energyCostPerKWh")
        UserDefaults.standard.set(dataCollectionEnabled, forKey: "energyDataCollectionEnabled")
        UserDefaults.standard.set(collectionInterval.rawValue, forKey: "energyDataCollectionInterval")
    }
    
    // Other data management methods remain unchanged...
}

// MARK: - Energy Settings View

struct EnergySettingsView: View {
    @Environment(\.dismiss) var dismiss
    
    // Bindings to the parent view
    @Binding var costPerKWh: Double
    @Binding var selectedDevices: [String: Bool]
    @Binding var deviceDataPoints: [String: MQTTBroker.DataPoint]
    @Binding var dataCollectionEnabled: Bool
    @Binding var collectionInterval: DataCollectionInterval
    @Binding var historicalReadings: [String: [EnergyCostView.EnergyReading]]
    
    // State variables
    @State private var showingDataPointSelector = false
    @State private var currentDeviceForDataPoint: String = ""
    @State private var showConfirmationDialog = false
    @ObservedObject private var mqttBroker = MQTTBroker.shared
    
    // Callback when settings are saved
    var onSettingsSaved: () -> Void
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Energy Cost")) {
                    HStack {
                        Text("Cost per kWh")
                        Spacer()
                        TextField("$", value: $costPerKWh, format: .number.precision(.fractionLength(2)))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                    }
                }
                
                Section(header: Text("Data Collection")) {
                    Toggle("Record Data", isOn: $dataCollectionEnabled)
                    
                    if dataCollectionEnabled {
                        Picker("Collection Interval", selection: $collectionInterval) {
                            ForEach(DataCollectionInterval.allCases) { interval in
                                Text(interval.description).tag(interval)
                            }
                        }
                    }
                }
                
                Section(header: Text("Device Power Monitoring")) {
                    if mqttBroker.getAllDevices().isEmpty {
                        Text("No MQTT devices available")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(mqttBroker.getAllDevices(), id: \.self) { deviceId in
                            DeviceSettingsRow(
                                deviceId: deviceId,
                                mqttBroker: mqttBroker,
                                selectedDevices: $selectedDevices,
                                deviceDataPoints: $deviceDataPoints,
                                currentDeviceForDataPoint: $currentDeviceForDataPoint,
                                showingDataPointSelector: $showingDataPointSelector
                            )
                        }
                    }
                }
                
                Section(header: Text("Data Management")) {
                    Button(action: {
                        showConfirmationDialog = true
                    }) {
                        HStack {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                            Text("Clear All Energy Data")
                                .foregroundColor(.red)
                        }
                    }
                    
                    HStack {
                        Text("Data Points")
                        Spacer()
                        Text(countDataPoints())
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Estimated Storage")
                        Spacer()
                        Text(estimateStorageSize())
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Energy Settings")
            .navigationBarItems(
                leading: Button("Cancel") {
                    dismiss()
                },
                trailing: Button("Save") {
                    onSettingsSaved()
                    dismiss()
                }
            )
            .confirmationDialog(
                "Clear All Energy Data?",
                isPresented: $showConfirmationDialog,
                titleVisibility: .visible
            ) {
                Button("Clear Data", role: .destructive) {
                    clearAllData()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will delete all stored energy readings. This action cannot be undone.")
            }
            .sheet(isPresented: $showingDataPointSelector) {
                if !currentDeviceForDataPoint.isEmpty {
                    let tempBinding = Binding<MQTTBroker.DataPoint?>(
                                            get: { deviceDataPoints[currentDeviceForDataPoint] },
                                            set: { newValue in
                                                if let newValue = newValue {
                                                    deviceDataPoints[currentDeviceForDataPoint] = newValue
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
                        
                        /// Count total number of data points across all devices
                        private func countDataPoints() -> String {
                            var total = 0
                            for (_, readings) in historicalReadings {
                                total += readings.count
                            }
                            return "\(total) readings"
                        }
                        
                        /// Estimate storage size used by energy data
                        private func estimateStorageSize() -> String {
                            // Estimate size based on reading count and average size per reading
                            let averageBytesPerReading = 40 // Rough estimate: timestamp (8) + deviceId (16) + power (8) + overhead (8)
                            var totalReadings = 0
                            
                            for (_, readings) in historicalReadings {
                                totalReadings += readings.count
                            }
                            
                            let totalBytes = totalReadings * averageBytesPerReading
                            
                            // Format for display
                            if totalBytes < 1024 {
                                return "\(totalBytes) bytes"
                            } else if totalBytes < 1024 * 1024 {
                                return "\(totalBytes / 1024) KB"
                            } else {
                                return "\(totalBytes / (1024 * 1024)) MB"
                            }
                        }
                        
                        /// Clear all energy data
                        private func clearAllData() {
                            // Clear all historical readings
                            historicalReadings.removeAll()
                            
                            // Delete stored data from UserDefaults
                            for key in UserDefaults.standard.dictionaryRepresentation().keys {
                                if key.hasPrefix("energyReadings_") {
                                    UserDefaults.standard.removeObject(forKey: key)
                                }
                            }
                        }
                    }

                    // MARK: - Device Settings Row

                    /// Dedicated view for device settings with data point selector
                    struct DeviceSettingsRow: View {
                        let deviceId: String
                        let mqttBroker: MQTTBroker
                        
                        @Binding var selectedDevices: [String: Bool]
                        @Binding var deviceDataPoints: [String: MQTTBroker.DataPoint]
                        @Binding var currentDeviceForDataPoint: String
                        @Binding var showingDataPointSelector: Bool
                        
                        @State private var showAvailableDataPoints = false
                        
                        var body: some View {
                            VStack(alignment: .leading, spacing: 8) {
                                // Device toggle
                                Toggle(isOn: Binding(
                                    get: { selectedDevices[deviceId] ?? false },
                                    set: { selectedDevices[deviceId] = $0 }
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
                                
                                // Always show power data point selector for better discoverability
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Power Data Point:")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
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
                                                Label("Select Power Data Point", systemImage: "plus.circle")
                                                    .font(.subheadline)
                                                    .foregroundColor(.blue)
                                            }
                                            
                                            Spacer()
                                            
                                            Image(systemName: "chevron.right")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        .padding(.vertical, 6)
                                        .padding(.horizontal, 8)
                                        .background(Color.blue.opacity(0.05))
                                        .cornerRadius(8)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    
                                    // Show all available data points if the disclosure button is tapped
                                    if showAvailableDataPoints {
                                        VStack(alignment: .leading, spacing: 8) {
                                            Text("Available Data Points:")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                                .padding(.top, 4)
                                            
                                            // List all data points for this device
                                            ForEach(getAvailableDataPoints(), id: \.id) { dataPoint in
                                                HStack {
                                                    Image(systemName: getDataPointIcon(for: dataPoint))
                                                        .foregroundColor(getDataPointColor(for: dataPoint))
                                                        .font(.caption)
                                                    
                                                    Text(dataPoint.name)
                                                        .font(.caption)
                                                    
                                                    Spacer()
                                                    
                                                    // Show current value if available
                                                    if let value = mqttBroker.getValue(for: dataPoint) {
                                                        Text(value.formattedString())
                                                            .font(.caption)
                                                            .foregroundColor(.secondary)
                                                    }
                                                }
                                                .padding(.vertical, 4)
                                            }
                                        }
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 8)
                                        .background(Color(.tertiarySystemBackground))
                                        .cornerRadius(8)
                                    }
                                    
                                    // Button to toggle showing all data points
                                    Button(action: {
                                        withAnimation {
                                            showAvailableDataPoints.toggle()
                                        }
                                    }) {
                                        HStack {
                                            Text(showAvailableDataPoints ? "Hide Data Points" : "Show All Data Points")
                                                .font(.caption)
                                                .foregroundColor(.blue)
                                            
                                            Spacer()
                                            
                                            Image(systemName: showAvailableDataPoints ? "chevron.up" : "chevron.down")
                                                .font(.caption)
                                                .foregroundColor(.blue)
                                        }
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    .padding(.top, 4)
                                }
                                .padding(.leading, 34) // Indent to align with toggle text
                            }
                            .padding(.vertical, 4)
                        }
                        
                        /// Get all available data points for this device
                        private func getAvailableDataPoints() -> [MQTTBroker.DataPoint] {
                            return mqttBroker.getAllDataPoints(deviceId: deviceId)
                        }
                        
                        /// Get an appropriate icon for a data point based on name/type
                        private func getDataPointIcon(for dataPoint: MQTTBroker.DataPoint) -> String {
                            let name = dataPoint.name.lowercased()
                            
                            if name.contains("power") || name.contains("watt") {
                                return "bolt.fill"
                            } else if name.contains("temp") {
                                return "thermometer"
                            } else if name.contains("humidity") {
                                return "humidity"
                            } else if name.contains("light") || name.contains("brightness") {
                                return "sun.max.fill"
                            } else if name.contains("battery") {
                                return "battery.100"
                            } else if name.contains("status") || name.contains("state") {
                                return "info.circle"
                            } else {
                                return "circle.fill"
                            }
                        }
                        
                        /// Get an appropriate color for a data point based on name/type
                        private func getDataPointColor(for dataPoint: MQTTBroker.DataPoint) -> Color {
                            let name = dataPoint.name.lowercased()
                            
                            if name.contains("power") || name.contains("watt") {
                                return .yellow
                            } else if name.contains("temp") {
                                return .red
                            } else if name.contains("humidity") {
                                return .blue
                            } else if name.contains("light") || name.contains("brightness") {
                                return .orange
                            } else if name.contains("battery") {
                                return .green
                            } else if name.contains("status") || name.contains("state") {
                                return .purple
                            } else {
                                return .gray
                            }
                        }
                    }

                    // MARK: - Preview

                    struct EnergyCostView_Previews: PreviewProvider {
                        static var previews: some View {
                            EnergyCostView()
                        }
                    }
