import SwiftUI

struct MotionControlSettingsView: View {
    @ObservedObject private var motionManager = MotionControlManager.shared
    @State private var showMotionTestView = false
    
    var body: some View {
        Form {
            Section(header: Text("Motion Controls")) {
                Toggle("Enable Motion Controls", isOn: $motionManager.isMotionEnabled)
                    .onChange(of: motionManager.isMotionEnabled) { _, newValue in
                        motionManager.saveSettings()
                        
                        // Stop motion tracking if disabling
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
                                    .onChange(of: motionManager.motionSensitivity) { _, _ in
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
                        
                        Text("Twist left = decrease value")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("Twist right = increase value")
                            .font(.caption)
                            .foregroundColor(.secondary)
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
                        
                        Text("Tilt left = decrease value")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("Tilt right = increase value")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
            
            Section(header: Text("Active Motions")) {
                if motionManager.motionActions.isEmpty {
                    Text("No motion actions configured")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 8)
                } else {
                    ForEach(motionManager.motionActions) { action in
                        MotionActionRow(action: action)
                    }
                }
            }
        }
        .navigationTitle("Motion Controls")
        .sheet(isPresented: $showMotionTestView) {
            MotionTestView()
        }
    }
}

struct MotionActionRow: View {
    let action: MotionAction
    
    var body: some View {
        HStack {
            // Get the motion type icon
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
                Text(action.motionType)
                
                HStack {
                    Text("Device: \(action.deviceId)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("•")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("Control: \(action.controlId)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Text(action.actionValue)
                .font(.caption)
                .padding(4)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(4)
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
                    // Twist (rotation)
                    MotionTestMeter(
                        title: "Twist",
                        iconName: "rotate.right",
                        value: $twistValue,
                        color: .blue,
                        isActive: isTracking
                    )
                    
                    // Tilt
                    MotionTestMeter(
                        title: "Tilt",
                        iconName: "iphone.gen3",
                        value: $tiltValue,
                        color: .green,
                        isActive: isTracking
                    )
                    
                    // Shake
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
                // Reset values
                twistValue = 0
                tiltValue = 0
            }
            .onDisappear {
                stopMotionTracking()
            }
        }
    }
    
    private func startMotionTracking() {
        isTracking = true
        
        // Start actual motion tracking
        motionManager.startMotionTracking()
        
        // Set up timer to update our local values from the motion manager
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

struct MotionTestMeter: View {
    let title: String
    let iconName: String
    @Binding var value: Double
    let color: Color
    let isActive: Bool
    var isBinary: Bool = false
    
    private var displayValue: Double {
        // Normalize the value to be between -1 and 1 for display
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
                // Binary indicator (on/off)
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
                // Continuous meter
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background track
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 8)
                        
                        // Zero marker (center)
                        Rectangle()
                            .fill(Color.gray.opacity(0.5))
                            .frame(width: 2, height: 16)
                            .position(x: geometry.size.width / 2, y: 8)
                        
                        // Value indicator
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

struct MotionControlSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Preview with motion enabled
            NavigationView {
                MotionControlSettingsView()
                    .onAppear {
                        // Set up preview state (doesn't affect actual app state)
                        MotionControlManager.shared.isMotionEnabled = true
                        MotionControlManager.shared.motionSensitivity = 5.0
                    }
            }
            .previewDisplayName("Motion Enabled")
            
            // Preview with motion disabled
            NavigationView {
                MotionControlSettingsView()
                    .onAppear {
                        // Set up preview state
                        MotionControlManager.shared.isMotionEnabled = false
                    }
            }
            .previewDisplayName("Motion Disabled")
            
            // Preview with some motion actions
            NavigationView {
                MotionControlSettingsView()
                    .onAppear {
                        // For preview purposes only, add some sample motion actions
                        // Note: This won't affect the actual app state
                        MotionControlManager.shared.isMotionEnabled = true
                        // Preview actions would be set up here if needed
                    }
            }
            .previewDisplayName("With Motion Actions")
            
            // Dark mode preview
            NavigationView {
                MotionControlSettingsView()
            }
            .preferredColorScheme(.dark)
            .previewDisplayName("Dark Mode")
            
            // Preview of the motion test view
            MotionTestView()
                .previewDisplayName("Motion Test View")
        }
    }
}

// Add a preview for the MotionActionRow
struct MotionActionRow_Previews: PreviewProvider {
    static var previews: some View {
        List {
            // Sample twist action
            MotionActionRow(action: sampleAction(type: "Twist", value: "increase:10"))
                .previewDisplayName("Twist Action")
            
            // Sample tilt action
            MotionActionRow(action: sampleAction(type: "Tilt", value: "toggle"))
                .previewDisplayName("Tilt Action")
            
            // Sample shake action
            MotionActionRow(action: sampleAction(type: "Shake", value: "ON"))
                .previewDisplayName("Shake Action")
        }
        .previewLayout(.sizeThatFits)
    }
    
    // Helper to create sample motion actions for preview
    static func sampleAction(type: String, value: String) -> MotionAction {
        return MotionAction(
            id: "preview-action",
            deviceId: 1,
            controlId: 123,
            motionType: type,
            actionValue: value
        )
    }
}

// Add a preview for the MotionTestMeter component
struct MotionTestMeter_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            // Active meter with positive value
            MotionTestMeter(
                title: "Twist Right",
                iconName: "rotate.right",
                value: .constant(0.75),
                color: .blue,
                isActive: true
            )
            
            // Active meter with negative value
            MotionTestMeter(
                title: "Twist Left",
                iconName: "rotate.left",
                value: .constant(-0.50),
                color: .blue,
                isActive: true
            )
            
            // Binary meter (on)
            MotionTestMeter(
                title: "Shake",
                iconName: "wave.3.right",
                value: .constant(1.0),
                color: .orange,
                isActive: true,
                isBinary: true
            )
            
            // Binary meter (off)
            MotionTestMeter(
                title: "Shake (Off)",
                iconName: "wave.3.right",
                value: .constant(0.0),
                color: .orange,
                isActive: true,
                isBinary: true
            )
            
            // Inactive meter
            MotionTestMeter(
                title: "Inactive",
                iconName: "stopwatch",
                value: .constant(0.0),
                color: .gray,
                isActive: false
            )
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
