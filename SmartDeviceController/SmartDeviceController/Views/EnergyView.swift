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
    
    
    struct EnergyReading: Identifiable, Codable, Equatable {
        let id = UUID()
        let deviceId: String
        let timestamp: Date
        let power: Double
        
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
            case .hourly: return 60 * 60
            case .daily: return 24 * 60 * 60
            case .weekly: return 7 * 24 * 60 * 60
            case .monthly: return 30 * 24 * 60 * 60
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
    
    
    private var energyGraphView: some View {
        VStack(spacing: 0) {
            Picker("Timeframe", selection: $selectedTimeframe) {
                ForEach(TimeframeOption.allCases) { option in
                    Text(option.rawValue).tag(option)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal)
            .padding(.top, 16)
            .padding(.bottom, 8)
            
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Power Usage")
                        .font(.headline)
                    
                    Spacer()
                    
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
    
    private var energySummaryView: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                summaryCard(
                    title: "Current Power",
                    value: "\(String(format: "%.1f", totalPowerUsage)) W",
                    icon: "bolt.fill",
                    iconColor: .yellow
                )
                
                summaryCard(
                    title: "Energy Used",
                    value: "\(String(format: "%.2f", totalEnergyConsumption)) kWh",
                    icon: "chart.bar.fill",
                    iconColor: .blue
                )
            }
            
            HStack(spacing: 16) {
                summaryCard(
                    title: "Current Cost",
                    value: "$\(String(format: "%.2f", totalEnergyCost))",
                    icon: "dollarsign.circle.fill",
                    iconColor: .green
                )
                
                summaryCard(
                    title: "Projected Month",
                    value: "$\(String(format: "%.2f", calculateMonthlyProjection()))",
                    icon: "calendar",
                    iconColor: .purple
                )
            }
        }
        .padding()
    }
    
    private func calculateMonthlyProjection() -> Double {
        // Daily average consumption based on current timeframe data
        let daysInPeriod: Double
        switch selectedTimeframe {
        case .hourly:
            daysInPeriod = 1.0/24.0  // fraction of a day
        case .daily:
            daysInPeriod = 1.0
        case .weekly:
            daysInPeriod = 7.0
        case .monthly:
            daysInPeriod = 30.0
        }
        
        // Cost per day
        let dailyCost = totalEnergyCost / daysInPeriod
        
        // Cost per month (30 days)
        return dailyCost * 30.0
    }
    
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
    
    private func getCurrentGraphSelectionName() -> String {
        if showCombinedGraph {
            return "Combined View"
        } else if let selectedDeviceId = currentSingleDeviceId {
            return mqttBroker.deviceContexts[selectedDeviceId]?.displayName ?? selectedDeviceId
        } else {
            return "Select Device"
        }
    }
    
    private func getSelectedDeviceIds() -> [String] {
        return selectedDevices.filter { $0.value && deviceDataPoints[$0.key] != nil }.map { $0.key }
    }
    
    @State private var currentSingleDeviceId: String? = nil
    
    private func showSingleDeviceGraph(_ deviceId: String) {
        currentSingleDeviceId = deviceId
    }
    
    private var singleDeviceGraph: some View {
        Group {
            if let deviceId = currentSingleDeviceId {
                let deviceReadings = energyReadings.filter { $0.deviceId == deviceId }
                
                if !deviceReadings.isEmpty {
                    let yAxisRange = calculateYAxisRange()
                    let aggregatedReadings = aggregateReadings(deviceReadings, for: selectedTimeframe)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Chart {
                            ForEach(aggregatedReadings) { reading in
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
        .onChange(of: selectedTimeframe) { _, _ in
            refreshEnergyData()
        }
    }
    
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
    
    private var combinedEnergyGraph: some View {
        let yAxisRange = calculateYAxisRange()
        
        let aggregatedByDevice: [String: [EnergyReading]] = Dictionary(
            grouping: energyReadings,
            by: { $0.deviceId }
        ).mapValues { readings in
            aggregateReadings(readings, for: selectedTimeframe)
        }
        
        return Chart {
            ForEach(Array(aggregatedByDevice.keys), id: \.self) { deviceId in
                if let readings = aggregatedByDevice[deviceId] {
                    ForEach(readings) { reading in
                        LineMark(
                            x: .value("Time", reading.timestamp),
                            y: .value("Power (W)", reading.power)
                        )
                        .foregroundStyle(by: .value("Device", reading.deviceDisplayName))
                    }
                }
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
        .onChange(of: selectedTimeframe) { _, _ in
            refreshEnergyData()
        }
    }
    
    // Aggregate readings based on timeframe to avoid overcrowding the chart
    private func aggregateReadings(_ readings: [EnergyReading], for timeframe: TimeframeOption) -> [EnergyReading] {
        guard !readings.isEmpty else { return [] }
        
        // Different aggregation intervals based on timeframe
        let calendar = Calendar.current
        let dateComponents: Set<Calendar.Component>
        
        switch timeframe {
        case .hourly:
            // For hourly view, group by minute
            dateComponents = [.year, .month, .day, .hour, .minute]
        case .daily:
            // For daily view, group by 15-minute intervals
            dateComponents = [.year, .month, .day, .hour, .minute]
            // We'll handle the 15-minute intervals separately
        case .weekly:
            // For weekly view, group by hour
            dateComponents = [.year, .month, .day, .hour]
        case .monthly:
            // For monthly view, group by day
            dateComponents = [.year, .month, .day]
        }
        
        // Sort readings by timestamp
        let sortedReadings = readings.sorted(by: { $0.timestamp < $1.timestamp })
        
        // Group readings by time periods
        var groupedReadings: [Date: [EnergyReading]] = [:]
        
        for reading in sortedReadings {
            var components = calendar.dateComponents(dateComponents, from: reading.timestamp)
            
            // Handle 15-minute intervals for daily view
            if timeframe == .daily {
                let minute = components.minute ?? 0
                components.minute = (minute / 15) * 15  // Round to nearest 15-minute interval
            }
            
            if let date = calendar.date(from: components) {
                if groupedReadings[date] == nil {
                    groupedReadings[date] = []
                }
                groupedReadings[date]?.append(reading)
            }
        }
        
        // Calculate average power for each time period
        var aggregatedReadings: [EnergyReading] = []
        
        for (date, readings) in groupedReadings {
            let totalPower = readings.reduce(0.0) { $0 + $1.power }
            let averagePower = totalPower / Double(readings.count)
            
            let aggregatedReading = EnergyReading(
                deviceId: readings[0].deviceId,
                timestamp: date,
                power: averagePower
            )
            aggregatedReadings.append(aggregatedReading)
        }
        
        return aggregatedReadings.sorted(by: { $0.timestamp < $1.timestamp })
    }
    
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
            formatter.dateFormat = "d MMM"
        }
        
        return formatter.string(from: date)
    }
    
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
    
    private func initializeDeviceSelection() {
        if let savedData = UserDefaults.standard.data(forKey: "energyCostDeviceSelections"),
           let decoded = try? JSONDecoder().decode([String: Bool].self, from: savedData) {
            for deviceId in mqttBroker.getAllDevices() {
                if decoded[deviceId] == nil {
                    selectedDevices[deviceId] = false
                } else {
                    selectedDevices[deviceId] = decoded[deviceId]
                }
            }
        } else {
            for deviceId in mqttBroker.getAllDevices() {
                selectedDevices[deviceId] = false
            }
        }
        
        if let savedData = UserDefaults.standard.data(forKey: "energyCostDeviceDataPoints"),
           let decoded = try? JSONDecoder().decode([String: String].self, from: savedData) {
            
            for (deviceId, dataPointId) in decoded {
                if let dataPoint = mqttBroker.getDataPointById(dataPointId) {
                    deviceDataPoints[deviceId] = dataPoint
                }
            }
        }
    }
    
    private func saveDeviceSelections() {
        if let encoded = try? JSONEncoder().encode(selectedDevices) {
            UserDefaults.standard.set(encoded, forKey: "energyCostDeviceSelections")
        }
    }
    
    private func saveDeviceDataPoints() {
        var dataPointIds: [String: String] = [:]
        
        for (deviceId, dataPoint) in deviceDataPoints {
            dataPointIds[deviceId] = dataPoint.id
        }
        
        if let encoded = try? JSONEncoder().encode(dataPointIds) {
            UserDefaults.standard.set(encoded, forKey: "energyCostDeviceDataPoints")
        }
    }
    
    private func startDataCollection() {
        guard dataCollectionEnabled, !isCollectingData else { return }
        
        isCollectingData = true
        
        let interval = TimeInterval(collectionInterval.rawValue)
        dataCollectionTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            collectCurrentReadings()
        }
        
        if let timer = dataCollectionTimer {
            RunLoop.current.add(timer, forMode: .common)
        }
        
        collectCurrentReadings()
        
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
            refreshEnergyData()
        }
        
        if let timer = refreshTimer {
            RunLoop.current.add(timer, forMode: .common)
        }
    }
    
    private func stopDataCollection() {
        isCollectingData = false
        dataCollectionTimer?.invalidate()
        dataCollectionTimer = nil
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
    
    private func restartDataCollection() {
        stopDataCollection()
        startDataCollection()
    }
    
    private func collectCurrentReadings() {
        let now = Date()
        
        updateTotalPowerUsage()
        
        for (deviceId, isSelected) in selectedDevices {
            guard isSelected, let dataPoint = deviceDataPoints[deviceId] else { continue }
            
            if let value = mqttBroker.getValue(for: dataPoint),
               let powerValue = value.asDouble() {
                
                let reading = EnergyReading(
                    deviceId: deviceId,
                    timestamp: now,
                    power: powerValue
                )
                
                if historicalReadings[deviceId] == nil {
                    historicalReadings[deviceId] = []
                }
                
                historicalReadings[deviceId]?.append(reading)
            }
        }
        
        trimHistoricalReadings()
    }
    
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
    
    private func trimHistoricalReadings() {
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
        if energyReadings.isEmpty {
            return 0...100
        }
        
        let powerValues = energyReadings.map { $0.power }
        let minPower = powerValues.min() ?? 0
        let maxPower = powerValues.max() ?? 100
        
        if maxPower <= 0 {
            return 0...10
        }
        
        if maxPower < 1 {
            return 0...1
        } else if maxPower < 10 {
            return 0...10
        }
        
        let upperBound = maxPower * 1.1
        
        let roundedUpperBound: Double
        if upperBound < 50 {
            roundedUpperBound = ceil(upperBound / 5) * 5
        } else if upperBound < 100 {
            roundedUpperBound = ceil(upperBound / 10) * 10
        } else if upperBound < 500 {
            roundedUpperBound = ceil(upperBound / 50) * 50
        } else if upperBound < 1000 {
            roundedUpperBound = ceil(upperBound / 100) * 100
        } else {
            roundedUpperBound = ceil(upperBound / 500) * 500
        }
        
        return 0...roundedUpperBound
    }
    
    private func formatPowerValue(_ value: Double) -> String {
        if value < 1.0 {
            return String(format: "%.2f W", value)
        } else if value < 10.0 {
            return String(format: "%.1f W", value)
        } else {
            return "\(Int(value)) W"
        }
    }
    
    private func refreshEnergyData() {
        let now = Date()
        let startDate = now.addingTimeInterval(-selectedTimeframe.timeInterval)
        
        var filteredReadings: [EnergyReading] = []
        deviceEnergies = [:]
        deviceCosts = [:]
        var totalEnergy: Double = 0
        
        for (deviceId, isSelected) in selectedDevices {
            guard isSelected else { continue }
            
            if let deviceReadings = historicalReadings[deviceId] {
                let timeframeReadings = deviceReadings.filter {
                    $0.timestamp >= startDate && $0.timestamp <= now
                }
                
                filteredReadings.append(contentsOf: timeframeReadings)
                
                let deviceEnergy = calculateEnergy(from: timeframeReadings)
                deviceEnergies[deviceId] = deviceEnergy
                deviceCosts[deviceId] = deviceEnergy * costPerKWh
                totalEnergy += deviceEnergy
            }
        }
        
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
            
            let timeDiff = currentReading.timestamp.timeIntervalSince(prevReading.timestamp) / 3600  // Convert to hours
            
            let avgPower = (prevReading.power + currentReading.power) / 2 / 1000  // Convert W to kW
            
            let energyKWh = avgPower * timeDiff
            
            totalEnergy += energyKWh
        }
        
        return totalEnergy
    }
    
    private func saveHistoricalReadings() {
        let encoder = JSONEncoder()
        
        for (deviceId, readings) in historicalReadings {
            if let encoded = try? encoder.encode(readings) {
                UserDefaults.standard.set(encoded, forKey: "energyReadings_\(deviceId)")
            }
        }
    }
    
    private func loadHistoricalReadings() {
        let decoder = JSONDecoder()
        
        for deviceId in mqttBroker.getAllDevices() {
            if let savedData = UserDefaults.standard.data(forKey: "energyReadings_\(deviceId)"),
               let decoded = try? decoder.decode([EnergyReading].self, from: savedData) {
                historicalReadings[deviceId] = decoded
            }
        }
    }
    
    private func loadSettings() {
        let savedCost = UserDefaults.standard.double(forKey: "energyCostPerKWh")
        if savedCost > 0 {
            costPerKWh = savedCost
        }
        
        dataCollectionEnabled = UserDefaults.standard.bool(forKey: "energyDataCollectionEnabled")
        
        let savedIntervalValue = UserDefaults.standard.integer(forKey: "energyDataCollectionInterval")
        if savedIntervalValue > 0, let savedInterval = DataCollectionInterval(rawValue: savedIntervalValue) {
            collectionInterval = savedInterval
        }
    }
    
    private func saveSettings() {
        UserDefaults.standard.set(costPerKWh, forKey: "energyCostPerKWh")
        UserDefaults.standard.set(dataCollectionEnabled, forKey: "energyDataCollectionEnabled")
        UserDefaults.standard.set(collectionInterval.rawValue, forKey: "energyDataCollectionInterval")
    }
}

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
                
                if showAvailableDataPoints {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Available Data Points:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                        
                        ForEach(getAvailableDataPoints(), id: \.id) { dataPoint in
                            HStack {
                                Image(systemName: getDataPointIcon(for: dataPoint))
                                    .foregroundColor(getDataPointColor(for: dataPoint))
                                    .font(.caption)
                                
                                Text(dataPoint.name)
                                    .font(.caption)
                                
                                Spacer()
                                
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
            .padding(.leading, 34)
        }
        .padding(.vertical, 4)
    }
    
    private func getAvailableDataPoints() -> [MQTTBroker.DataPoint] {
        return mqttBroker.getAllDataPoints(deviceId: deviceId)
    }
    
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

struct EnergySettingsView: View {
    @Environment(\.dismiss) var dismiss
    
    @Binding var costPerKWh: Double
    @Binding var selectedDevices: [String: Bool]
    @Binding var deviceDataPoints: [String: MQTTBroker.DataPoint]
    @Binding var dataCollectionEnabled: Bool
    @Binding var collectionInterval: DataCollectionInterval
    @Binding var historicalReadings: [String: [EnergyCostView.EnergyReading]]
    
    @State private var showingDataPointSelector = false
    @State private var currentDeviceForDataPoint: String = ""
    @State private var showConfirmationDialog = false
    @ObservedObject private var mqttBroker = MQTTBroker.shared
    
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
    
    private func countDataPoints() -> String {
        var total = 0
        for (_, readings) in historicalReadings {
            total += readings.count
        }
        return "\(total) readings"
    }
    
    private func estimateStorageSize() -> String {
        let averageBytesPerReading = 40
        var totalReadings = 0
        
        for (_, readings) in historicalReadings {
            totalReadings += readings.count
        }
        
        let totalBytes = totalReadings * averageBytesPerReading
        
        if totalBytes < 1024 {
            return "\(totalBytes) bytes"
        } else if totalBytes < 1024 * 1024 {
            return "\(totalBytes / 1024) KB"
        } else {
            return "\(totalBytes / (1024 * 1024)) MB"
        }
    }
    
    private func clearAllData() {
        historicalReadings.removeAll()
        
        for key in UserDefaults.standard.dictionaryRepresentation().keys {
            if key.hasPrefix("energyReadings_") {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
    }
}

struct EnergyCostView_Previews: PreviewProvider {
    static var previews: some View {
        EnergyCostView()
    }
}
