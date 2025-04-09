import SwiftUI

struct TimerConfiguratorView: View {
    let control: DeviceControl
    let deviceId: Int
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject private var timerManager = TimerControlManager.shared
    
    @State private var selectedTimerType: TimerAction.TimerType = .turnOn
    @State private var scheduledDate = Date().addingTimeInterval(3600)
    @State private var actionValue: String = ""
    @State private var isRepeating: Bool = false
    @State private var showingDeleteAlert = false
    @State private var timerToDelete: TimerAction? = nil
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Control Information")) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Image(systemName: control.getIconName())
                                .foregroundColor(control.getCustomColor())
                                .imageScale(.large)
                            
                            Text(control.displayName)
                                .font(.headline)
                        }
                        
                        Text("Topic: \(control.topic)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                
                Section(header: Text("Timer Configuration")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("What should happen?")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Picker("Timer Action", selection: $selectedTimerType) {
                            switch control.controlType {
                            case .button:
                                Text("Press Button").tag(TimerAction.TimerType.turnOn)
                                
                            case .toggle:
                                Text("Turn ON").tag(TimerAction.TimerType.turnOn)
                                Text("Turn OFF").tag(TimerAction.TimerType.turnOff)
                                Text("Toggle").tag(TimerAction.TimerType.toggle)
                                
                            case .slider:
                                Text("Set Value").tag(TimerAction.TimerType.setValue)
                                
                            default:
                                Text("Not applicable").tag(TimerAction.TimerType.turnOn)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .padding(.bottom, 4)
                    }
                    
                    if control.controlType == .slider && selectedTimerType == .setValue {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Value to set:")
                                    .font(.subheadline)
                                
                                Spacer()
                                
                                TextField("Enter value", text: $actionValue)
                                    .keyboardType(.numberPad)
                                    .multilineTextAlignment(.trailing)
                                    .frame(width: 80)
                                    .padding(8)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(8)
                            }
                            
                            if let doubleValue = Double(actionValue) {
                                Slider(value: Binding(
                                    get: { doubleValue },
                                    set: { actionValue = String(Int($0)) }
                                ), in: control.minValue...control.maxValue, step: 1)
                                .accentColor(control.getCustomColor())
                            } else {
                                Slider(value: Binding(
                                    get: { (control.minValue + control.maxValue) / 2 },
                                    set: { actionValue = String(Int($0)) }
                                ), in: control.minValue...control.maxValue, step: 1)
                                .accentColor(control.getCustomColor())
                            }
                            
                            Text("Valid range: \(Int(control.minValue)) - \(Int(control.maxValue))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("When should it happen?")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.top, 8)
                        
                        DatePicker("Scheduled Time", selection: $scheduledDate, displayedComponents: [.date, .hourAndMinute])
                            .datePickerStyle(DefaultDatePickerStyle())
                        
                        Toggle(isOn: $isRepeating) {
                            HStack {
                                Image(systemName: isRepeating ? "repeat" : "clock")
                                    .foregroundColor(isRepeating ? .blue : .secondary)
                                
                                Text(isRepeating ? "Repeats Daily" : "One-time Event")
                                    .foregroundColor(isRepeating ? .blue : .primary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                Section {
                    Button(action: addTimer) {
                        HStack {
                            Spacer()
                            Image(systemName: "timer")
                                .font(.headline)
                                .padding(.trailing, 4)
                            Text("Schedule Timer")
                                .font(.headline)
                            Spacer()
                        }
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .disabled(!isFormValid)
                    .listRowInsets(EdgeInsets())
                }
                
                Section(header:
                    HStack {
                        Text("Existing Timers")
                        Spacer()
                        Text("\(getExistingTimers().count)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(10)
                    }
                ) {
                    let timers = getExistingTimers()
                    
                    if timers.isEmpty {
                        Text("No timers configured for this control")
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 8)
                    } else {
                        ForEach(timers) { timer in
                            TimerActionRow(timer: timer)
                                .contextMenu {
                                    Button(role: .destructive) {
                                        timerToDelete = timer
                                        showingDeleteAlert = true
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        timerToDelete = timer
                                        showingDeleteAlert = true
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                    }
                }
            }
            .navigationBarTitle("Timer Configuration", displayMode: .inline)
            .navigationBarItems(trailing: Button("Done") {
                presentationMode.wrappedValue.dismiss()
            })
            .alert(isPresented: $showingDeleteAlert) {
                Alert(
                    title: Text("Delete Timer"),
                    message: Text("Are you sure you want to delete this timer?"),
                    primaryButton: .destructive(Text("Delete")) {
                        if let timer = timerToDelete {
                            timerManager.removeTimerAction(id: timer.id)
                        }
                    },
                    secondaryButton: .cancel()
                )
            }
        }
    }
    
    private var isFormValid: Bool {
        if control.controlType == .slider && selectedTimerType == .setValue {
            guard let value = Double(actionValue) else { return false }
            return value >= control.minValue && value <= control.maxValue
        }
        return true
    }
    
    private func getExistingTimers() -> [TimerAction] {
        return timerManager.getTimerActions(forControl: control.id)
    }
    
    private func addTimer() {
        let finalActionValue: String
        
        switch control.controlType {
        case .button:
            finalActionValue = control.message
            
        case .toggle:
            if selectedTimerType == .turnOn {
                finalActionValue = getToggleOnMessage(from: control.message)
            } else if selectedTimerType == .turnOff {
                finalActionValue = getToggleOffMessage(from: control.message)
            } else {
                finalActionValue = "toggle"
            }
            
        case .slider:
            finalActionValue = actionValue
            
        default:
            finalActionValue = ""
        }
        
        timerManager.addTimerAction(
            deviceId: deviceId,
            controlId: control.id,
            timerType: selectedTimerType,
            scheduledTime: scheduledDate,
            actionValue: finalActionValue,
            isRepeating: isRepeating
        )
        
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        if control.controlType == .slider && selectedTimerType == .setValue {
            actionValue = ""
        }
        
        scheduledDate = Date().addingTimeInterval(3600)
    }
    
    private func getToggleOnMessage(from configString: String) -> String {
        if configString.contains("|") {
            let parts = configString.split(separator: "|", maxSplits: 1)
            return String(parts[0])
        }
        return configString.isEmpty ? "on" : configString
    }
    
    private func getToggleOffMessage(from configString: String) -> String {
        if configString.contains("|") {
            let parts = configString.split(separator: "|", maxSplits: 1)
            return parts.count > 1 ? String(parts[1]) : "off"
        }
        return "off"
    }
}

struct TimerActionRow: View {
    let timer: TimerAction
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }
    
    private var isFutureTimer: Bool {
        return timer.scheduledTime > Date()
    }
    
    private var timeRemainingText: String {
        let interval = timer.scheduledTime.timeIntervalSince(Date())
        
        if interval < 0 {
            return timer.isRepeating ? "Repeats tomorrow" : "Expired"
        }
        
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        
        if hours > 0 {
            return "in \(hours)h \(minutes)m"
        } else {
            return "in \(minutes)m"
        }
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: iconForTimerType(timer.timerType))
                        .foregroundColor(colorForTimerType(timer.timerType))
                    
                    Text(timer.timerType.rawValue)
                        .font(.headline)
                    
                    if timer.isRepeating {
                        Image(systemName: "repeat")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
                
                Text(dateFormatter.string(from: timer.scheduledTime))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                if !timer.actionValue.isEmpty && timer.timerType == .setValue {
                    Text(timer.actionValue)
                        .font(.system(.body, design: .rounded))
                        .fontWeight(.semibold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(colorForTimerType(timer.timerType).opacity(0.1))
                        .cornerRadius(8)
                }
                
                Text(timeRemainingText)
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(isFutureTimer ? Color.green.opacity(0.1) : Color.gray.opacity(0.1))
                    )
                    .foregroundColor(isFutureTimer ? .green : .gray)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func iconForTimerType(_ type: TimerAction.TimerType) -> String {
        switch type {
        case .turnOn: return "power"
        case .turnOff: return "power.slash"
        case .toggle: return "switch.2"
        case .setValue: return "slider.horizontal.3"
        }
    }
    
    private func colorForTimerType(_ type: TimerAction.TimerType) -> Color {
        switch type {
        case .turnOn: return .green
        case .turnOff: return .red
        case .toggle: return .blue
        case .setValue: return .orange
        }
    }
}

struct TimerSummaryView: View {
    let deviceId: Int
    @ObservedObject private var timerManager = TimerControlManager.shared
    @Environment(\.presentationMode) var presentationMode
    @State private var showingDeleteAlert = false
    @State private var timerToDelete: TimerAction? = nil
    @State private var sortOption: TimerSortOption = .time
    @State private var filterOption: TimerFilterOption = .all
    
    enum TimerSortOption {
        case time, type
    }
    
    enum TimerFilterOption {
        case all, upcoming, repeating
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                HStack {
                    Picker("Filter", selection: $filterOption) {
                        Text("All").tag(TimerFilterOption.all)
                        Text("Upcoming").tag(TimerFilterOption.upcoming)
                        Text("Repeating").tag(TimerFilterOption.repeating)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    
                    Spacer()
                    
                    Menu {
                        Button(action: { sortOption = .time }) {
                            Label("By Time", systemImage: "clock")
                        }
                        Button(action: { sortOption = .type }) {
                            Label("By Type", systemImage: "tag")
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
                    }
                    .padding(8)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                
                List {
                    let timers = getFilteredAndSortedTimers()
                    
                    if timers.isEmpty {
                        Text("No active timers for this device")
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 8)
                    } else {
                        if sortOption == .time {
                            let grouped = Dictionary(grouping: timers) { timer -> String in
                                let date = timer.scheduledTime
                                let calendar = Calendar.current
                                
                                if calendar.isDateInToday(date) {
                                    return "Today"
                                } else if calendar.isDateInTomorrow(date) {
                                    return "Tomorrow"
                                } else {
                                    let formatter = DateFormatter()
                                    formatter.dateFormat = "EEEE, MMM d"
                                    return formatter.string(from: date)
                                }
                            }
                            
                            ForEach(grouped.keys.sorted(), id: \.self) { key in
                                Section(header: Text(key)) {
                                    ForEach(grouped[key] ?? []) { timer in
                                        TimerActionRow(timer: timer)
                                            .contextMenu {
                                                Button(role: .destructive) {
                                                    timerToDelete = timer
                                                    showingDeleteAlert = true
                                                } label: {
                                                    Label("Delete", systemImage: "trash")
                                                }
                                            }
                                            .swipeActions(edge: .trailing) {
                                                Button(role: .destructive) {
                                                    timerToDelete = timer
                                                    showingDeleteAlert = true
                                                } label: {
                                                    Label("Delete", systemImage: "trash")
                                                }
                                            }
                                    }
                                }
                            }
                        } else {
                            let grouped = Dictionary(grouping: timers) { timer -> String in
                                return timer.timerType.rawValue
                            }
                            
                            ForEach(grouped.keys.sorted(), id: \.self) { key in
                                Section(header: Text(key)) {
                                    ForEach(grouped[key] ?? []) { timer in
                                        TimerActionRow(timer: timer)
                                            .contextMenu {
                                                Button(role: .destructive) {
                                                    timerToDelete = timer
                                                    showingDeleteAlert = true
                                                } label: {
                                                    Label("Delete", systemImage: "trash")
                                                }
                                            }
                                            .swipeActions(edge: .trailing) {
                                                Button(role: .destructive) {
                                                    timerToDelete = timer
                                                    showingDeleteAlert = true
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
            }
            .navigationTitle("Device Timers")
            .navigationBarItems(trailing: Button("Done") {
                presentationMode.wrappedValue.dismiss()
            })
            .alert(isPresented: $showingDeleteAlert) {
                Alert(
                    title: Text("Delete Timer"),
                    message: Text("Are you sure you want to delete this timer?"),
                    primaryButton: .destructive(Text("Delete")) {
                        if let timer = timerToDelete {
                            timerManager.removeTimerAction(id: timer.id)
                        }
                    },
                    secondaryButton: .cancel()
                )
            }
        }
    }
    
    private func getFilteredAndSortedTimers() -> [TimerAction] {
        let timers = timerManager.getTimerActions(forDevice: deviceId)
        
        let filtered = timers.filter { timer in
            switch filterOption {
            case .all:
                return true
            case .upcoming:
                return timer.scheduledTime > Date()
            case .repeating:
                return timer.isRepeating
            }
        }
        
        return filtered.sorted { first, second in
            switch sortOption {
            case .time:
                return first.scheduledTime < second.scheduledTime
            case .type:
                if first.timerType.rawValue == second.timerType.rawValue {
                    return first.scheduledTime < second.scheduledTime
                }
                return first.timerType.rawValue < second.timerType.rawValue
            }
        }
    }
}
