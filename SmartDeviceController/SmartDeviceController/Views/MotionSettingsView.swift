import SwiftUI

struct MotionControlSettingsView: View {
    @ObservedObject private var motionManager = MotionControlManager.shared
    @State private var showMotionTestView = false
    @State private var showingDeleteAlert = false
    @State private var actionToDelete: MotionAction? = nil
    
    var body: some View {
        Form {
            Section(header: Text("Motion Controls")) {
                Toggle("Enable Motion Controls", isOn: $motionManager.isMotionEnabled)
                    .onChange(of: motionManager.isMotionEnabled) { oldValue, newValue in
                        motionManager.saveSettings()
                        
                        if !newValue {
                            motionManager.stopMotionTracking()
                        }
                    }
                
                
                if motionManager.isMotionEnabled {
                    if motionManager.isMotionAvailable {
                        Text("Use motion controls to interact with your devices using physical movements.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Sensitivity")
                                    .font(.headline)
                                
                                Spacer()
                                
                                Text("\(Int(motionManager.motionSensitivity))")
                                    .foregroundColor(.blue)
                                    .font(.headline)
                            }
                            
                            HStack {
                                Text("Low")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Slider(value: $motionManager.motionSensitivity, in: 1...10, step: 1)
                                    .onChange(of: motionManager.motionSensitivity) { oldValue, newValue in
                                        motionManager.saveSettings()
                                    }
                                
                                Text("High")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Text("Higher sensitivity = more responsive controls")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 4)
                        
                        Button(action: {
                            showMotionTestView = true
                        }) {
                            HStack {
                                Image(systemName: "gyroscope")
                                    .foregroundColor(.blue)
                                Text("Test Motion Controls")
                                    .foregroundColor(.blue)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                        }
                    } else {
                        Text("Motion control not available")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            }
            
            Section(header: Text("Motion Types")) {
                HStack {
                    Image(systemName: "rotate.right")
                        .foregroundColor(.blue)
                        .frame(width: 24, height: 24)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Twist Control")
                            .font(.headline)
                    }
                }
                .padding(.vertical, 4)
                
                HStack {
                    Image(systemName: "iphone.gen3")
                        .foregroundColor(.blue)
                        .frame(width: 24, height: 24)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Tilt Control")
                            .font(.headline)
                    }
                }
                .padding(.vertical, 4)
                
                HStack {
                    Image(systemName: "wave.3.right")
                        .foregroundColor(.blue)
                        .frame(width: 24, height: 24)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Shake Control")
                            .font(.headline)
                    }
                }
                .padding(.vertical, 4)
            }
            
            Section(header:
                HStack {
                    Text("Active Motions")
                    Spacer()
                    if !motionManager.motionActions.isEmpty {
                        Text("\(motionManager.motionActions.count)")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.blue)
                            .cornerRadius(8)
                    }
                }
            ) {
                if motionManager.motionActions.isEmpty {
                    Text("No motion actions configured")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 8)
                } else {
                    ForEach(motionManager.motionActions) { action in
                        MotionActionRow(action: action)
                            .contextMenu {
                                Button(role: .destructive) {
                                    actionToDelete = action
                                    showingDeleteAlert = true
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    actionToDelete = action
                                    showingDeleteAlert = true
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                }
            }
        }
        .navigationTitle("Motion Controls")
        .sheet(isPresented: $showMotionTestView) {
            MotionTestView()
        }
        .alert(isPresented: $showingDeleteAlert) {
            Alert(
                title: Text("Delete Motion Action"),
                message: Text("Are you sure you want to delete this motion control?"),
                primaryButton: .destructive(Text("Delete")) {
                    if let action = actionToDelete {
                        motionManager.removeMotionAction(id: action.id)
                        actionToDelete = nil
                    }
                },
                secondaryButton: .cancel()
            )
        }
    }
}

struct MotionActionRow: View {
    let action: MotionAction
    @ObservedObject private var motionManager = MotionControlManager.shared
    
    var body: some View {
        HStack {
            if let motionType = MotionType.allCases.first(where: { $0.rawValue == action.motionType }) {
                Image(systemName: motionType.iconName)
                    .foregroundColor(.blue)
                    .frame(width: 24, height: 24)
            } else {
                Image(systemName: "questionmark.circle")
                    .foregroundColor(.gray)
                    .frame(width: 24, height: 24)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(getControlName(action.controlId))
                    .font(.headline)
                
                HStack {
                    Text("Device: \(getDeviceName(action.deviceId))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("•")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("Type: \(action.motionType)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .contentShape(Rectangle())
    }
    
    private func getControlName(_ controlId: Int) -> String {
        let controls = getAllControls()
        return controls.first(where: { $0.id == controlId })?.displayName ?? "Control \(controlId)"
    }
    
    private func getDeviceName(_ deviceId: Int) -> String {
        if let device = DeviceManager.shared.getDevice(withId: deviceId) {
            return device.name
        }
        return "Device \(deviceId)"
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

struct MotionControlSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            MotionControlSettingsView()
        }
    }
}

struct MotionTestView: View {
    @ObservedObject private var motionManager = MotionControlManager.shared
    @Environment(\.presentationMode) var presentationMode
    
    @State private var isTracking = false
    @State private var twistValue: Double = 0
    @State private var tiltValue: Double = 0
    @State private var shakeDetected = false
    @State private var lastActionDetected: String = "None"
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Motion Test")
                    .font(.title)
                    .fontWeight(.bold)
                
                if isTracking {
                    Text("Move your device to see the values change")
                        .foregroundColor(.secondary)
                } else {
                    Text("Press Start to begin testing")
                        .foregroundColor(.secondary)
                }
                
                VStack(spacing: 30) {
                    MotionTestMeter(
                        title: "Twist",
                        iconName: "rotate.right",
                        value: $twistValue,
                        color: .blue,
                        isActive: isTracking
                    )
                    
                    MotionTestMeter(
                        title: "Tilt",
                        iconName: "iphone.gen3",
                        value: $tiltValue,
                        color: .green,
                        isActive: isTracking
                    )
                    
                    MotionTestMeter(
                        title: "Shake",
                        iconName: "wave.3.right",
                        value: Binding<Double>(
                            get: { shakeDetected ? 1.0 : 0.0 },
                            set: { _ in }
                        ),
                        color: .orange,
                        isActive: isTracking,
                        isBinary: true
                    )
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Last Detected Action:")
                            .font(.headline)
                        
                        Text(lastActionDetected)
                            .font(.body)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                    }
                    .padding(.top, 20)
                }
                .padding()
                
                Spacer()
                
                Button(action: {
                    if isTracking {
                        stopMotionTracking()
                    } else {
                        startMotionTracking()
                    }
                }) {
                    HStack {
                        Image(systemName: isTracking ? "stop.fill" : "play.fill")
                        Text(isTracking ? "Stop" : "Start")
                    }
                    .frame(width: 120, height: 44)
                    .background(isTracking ? Color.red : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .padding(.bottom, 30)
            }
            .padding()
            .navigationBarTitle("Test Motion Controls", displayMode: .inline)
            .navigationBarItems(trailing: Button("Done") {
                stopMotionTracking()
                presentationMode.wrappedValue.dismiss()
            })
            .onAppear {
                twistValue = 0
                tiltValue = 0
                
                let originalCallback = motionManager.onMotionActionTriggered
                motionManager.onMotionActionTriggered = { controlId, actionValue in
                    self.lastActionDetected = "Control ID: \(controlId), Action: \(actionValue)"
                    
                    originalCallback?(controlId, actionValue)
                }
            }
            .onDisappear {
                stopMotionTracking()
            }
        }
    }
    
    private func startMotionTracking() {
        isTracking = true
        
        motionManager.startMotionTracking()
        
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            guard isTracking else {
                timer.invalidate()
                return
            }
            
            twistValue = motionManager.rotationValue
            tiltValue = motionManager.tiltValue
            shakeDetected = motionManager.shakeDetected
        }
    }
    
    private func stopMotionTracking() {
        isTracking = false
        motionManager.stopMotionTracking()
    }
}

struct MotionTestView_Previews: PreviewProvider {
    static var previews: some View {
        MotionTestView()
    }
}

struct MotionTestMeter: View {
    let title: String
    let iconName: String
    @Binding var value: Double
    let color: Color
    let isActive: Bool
    var isBinary: Bool = false
    
    private var displayValue: Double {
        return max(min(value, 1), -1)
    }
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: iconName)
                    .foregroundColor(color)
                Text(title)
                    .font(.headline)
                
                Spacer()
                
                if !isBinary {
                    Text(String(format: "%.2f", value))
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                }
            }
            
            if isBinary {
                HStack {
                    Spacer()
                    
                    Circle()
                        .fill(displayValue > 0 ? color : Color.gray.opacity(0.3))
                        .frame(width: 30, height: 30)
                        .overlay(
                            Image(systemName: displayValue > 0 ? "checkmark" : "xmark")
                                .foregroundColor(.white)
                                .font(.system(size: 14, weight: .bold))
                        )
                        .shadow(color: displayValue > 0 ? color.opacity(0.5) : Color.clear, radius: 5)
                    
                    Spacer()
                }
                .frame(height: 30)
            } else {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 8)
                        
                        Rectangle()
                            .fill(Color.gray.opacity(0.5))
                            .frame(width: 2, height: 16)
                            .position(x: geometry.size.width / 2, y: 8)
                        
                        if isActive {
                            Circle()
                                .fill(color)
                                .frame(width: 16, height: 16)
                                .position(
                                    x: geometry.size.width / 2 + (displayValue * geometry.size.width / 2),
                                    y: 8
                                )
                                .animation(.interactiveSpring(), value: displayValue)
                        }
                    }
                }
                .frame(height: 16)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(10)
    }
}
