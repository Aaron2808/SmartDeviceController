import CoreMotion
import SwiftUI
import Combine
import os.log

enum MotionType: String, CaseIterable, Identifiable {
    case twist = "Twist"
    case tilt = "Tilt"
    case shake = "Shake"
    
    var id: String { self.rawValue }
    
    var description: String {
        switch self {
        case .twist: return "Rotate your device left or right"
        case .tilt: return "Tilt your device forward or backward"
        case .shake: return "Shake your device"
        }
    }
    
    var iconName: String {
        switch self {
        case .twist: return "rotate.right"
        case .tilt: return "iphone.gen3"
        case .shake: return "wave.3.right"
        }
    }
}

struct MotionAction: Codable, Identifiable, Equatable {
    let id: String
    let deviceId: Int
    let controlId: Int
    let motionType: String
    let actionValue: String
    
    static func == (lhs: MotionAction, rhs: MotionAction) -> Bool {
        return lhs.id == rhs.id
    }
}

class MotionControlManager: ObservableObject {
    // MARK: - Static Properties
    
    static let shared = MotionControlManager()
    
    // MARK: - Private Properties
    
    private let motionManager = CMMotionManager()
    private let defaultSensitivity: Double = 5.0
    private let logger = Logger(subsystem: "com.aaronflynn.SmartDeviceController", category: "MotionControl")
    
    // Threshold for shake detection
    private let shakeThreshold: Double = 2.0
    private var lastShakeTime: Date = Date()
    private var shakeTimeout: TimeInterval = 0.5 // Seconds between shake detections
    
    // Control activation parameters
    private var lastRotationValue: Double = 0
    private var lastTiltValue: Double = 0
    private var rotationThreshold: Double = 0.1
    private var tiltThreshold: Double = 0.1
    
    // Neutral zone and response curve variables
    private var neutralZone: Double = 0.08
    private var responseCurve: Double = 1.2
    
    // For continuous adjustment, track active sliders
    private var activeMotionControls: [Int: (MotionType, Date)] = [:]
    private let continuousAdjustInterval: TimeInterval = 0.12  // Faster updates for smoother motion
    
    // Add timestamps to avoid too-frequent triggers
    private var lastActionTimes: [Int: Date] = [:]
    private let actionCooldown: TimeInterval = 0.5  // 0.5 second between initial actions
    
    // Timer for continuous adjustment checking
    private var continuousAdjustmentTimer: Timer?
    
    // MARK: - Published Properties
    
    @Published var isMotionEnabled = false
    @Published var isMotionActivated = false
    @Published var motionSensitivity: Double = 5.0 {
        didSet {
            updateThresholds()
            updateNeutralZone()
        }
    }
    @Published var isMotionAvailable: Bool = false
    
    // Motion values
    @Published var rotationValue: Double = 0     // For twist
    @Published var tiltValue: Double = 0         // For tilt
    @Published var shakeDetected: Bool = false   // For shake
    
    // Active motion type (for filtering)
    @Published var activeMotionType: MotionType? = nil
    
    // Motion actions
    @Published var motionActions: [MotionAction] = []
    
    // MARK: - Callbacks
    
    /// Callback for when a motion action is triggered
    var onMotionActionTriggered: ((Int, String) -> Void)?
    
    /// Callback for continuous motion (for sliders)
    var onContinuousMotion: ((Int, String, Double) -> Void)?
    
    // MARK: - Initialization
    
    private init() {
        // Check if motion is available
        isMotionAvailable = motionManager.isDeviceMotionAvailable
        
        // Initialize with user preferences
        loadSettings()
        
        // Load saved actions from UserDefaults
        loadActions()
        
        // Update thresholds based on sensitivity
        updateThresholds()
        updateNeutralZone()
    }
    
    // MARK: - Public Methods
    
    /// Load settings from UserDefaults
    func loadSettings() {
        if let savedData = UserDefaults.standard.data(forKey: "motionControlsEnabled") {
            isMotionEnabled = UserDefaults.standard.bool(forKey: "motionControlsEnabled")
        }
        
        let sensitivity = UserDefaults.standard.double(forKey: "motionControlsSensitivity")
        motionSensitivity = sensitivity == 0 ? defaultSensitivity : sensitivity
        
        updateThresholds()
        updateNeutralZone()
    }
    
    /// Save settings to UserDefaults
    func saveSettings() {
        UserDefaults.standard.set(isMotionEnabled, forKey: "motionControlsEnabled")
        UserDefaults.standard.set(motionSensitivity, forKey: "motionControlsSensitivity")
    }
    
    /// Add a motion action
    /// - Parameters:
    ///   - deviceId: The device ID
    ///   - controlId: The control ID
    ///   - motionType: The motion type
    ///   - actionValue: The action value
    func addMotionAction(deviceId: Int, controlId: Int, motionType: MotionType, actionValue: String) {
        var updatedActions = motionActions
        
        // Check if there's already an action for this control
        if let existingIndex = updatedActions.firstIndex(where: { $0.controlId == controlId }) {
            // Update the existing action with new values
            updatedActions.remove(at: existingIndex)
        }
        
        let action = MotionAction(
            id: UUID().uuidString,
            deviceId: deviceId,
            controlId: controlId,
            motionType: motionType.rawValue,
            actionValue: actionValue
        )
        
        updatedActions.append(action)
        motionActions = updatedActions
        saveActions()
    }
    
    /// Remove a motion action
    /// - Parameter id: The action ID to remove
    func removeMotionAction(id: String) {
        motionActions.removeAll { $0.id == id }
        saveActions()
    }
    
    /// Get motion actions for a device
    /// - Parameter deviceId: The device ID
    /// - Returns: Array of motion actions
    func getMotionActions(forDevice deviceId: Int) -> [MotionAction] {
        return motionActions.filter { $0.deviceId == deviceId }
    }
    
    /// Get motion action for a control
    /// - Parameter controlId: The control ID
    /// - Returns: The motion action, or nil if none found
    func getMotionAction(forControl controlId: Int) -> MotionAction? {
        return motionActions.first { $0.controlId == controlId }
    }
    
    /// Start motion tracking
    func startMotionTracking() {
        guard isMotionEnabled, motionManager.isDeviceMotionAvailable, !motionManager.isDeviceMotionActive else {
            logger.error("Cannot start motion tracking - conditions not met")
            return
        }
        
        isMotionActivated = true
        lastRotationValue = 0
        lastTiltValue = 0
        lastActionTimes.removeAll()
        activeMotionControls.removeAll()
        
        // Debug check for callback
        if onMotionActionTriggered == nil {
            logger.warning("No motion action callback is set!")
        }
        
        motionManager.deviceMotionUpdateInterval = 0.1
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] (motion, error) in
            guard let self = self, let motion = motion else { return }
            
            // Extract rotation (twist)
            let roll = motion.attitude.roll
            self.rotationValue = roll
            
            // Extract tilt
            let pitch = motion.attitude.pitch
            self.tiltValue = pitch
            
            // Detect shake
            let acceleration = motion.userAcceleration
            let accelerationMagnitude = sqrt(
                acceleration.x * acceleration.x +
                acceleration.y * acceleration.y +
                acceleration.z * acceleration.z
            )
            
            if accelerationMagnitude > self.shakeThreshold {
                let now = Date()
                if now.timeIntervalSince(self.lastShakeTime) > self.shakeTimeout {
                    self.shakeDetected = true
                    self.lastShakeTime = now
                    
                    // Trigger shake actions
                    self.checkAndTriggerShakeActions()
                    
                    // Reset after brief period
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        self.shakeDetected = false
                    }
                }
            }
            
            // Check for significant changes in rotation or tilt
            self.checkAndTriggerMotionActions()
            
            // Update last values
            self.lastRotationValue = roll
            self.lastTiltValue = pitch
        }
        
        // Start the continuous adjustment timer
        startContinuousAdjustmentTimer()
        
        logger.info("Motion tracking started")
    }
    
    /// Stop motion tracking
    func stopMotionTracking() {
        if motionManager.isDeviceMotionActive {
            motionManager.stopDeviceMotionUpdates()
            isMotionActivated = false
            
            // Reset action times and active controls
            lastActionTimes.removeAll()
            activeMotionControls.removeAll()
            
            // Stop the continuous adjustment timer
            continuousAdjustmentTimer?.invalidate()
            continuousAdjustmentTimer = nil
            
            logger.info("Motion tracking stopped")
        }
    }
    
    // MARK: - Private Methods
    
    private func updateThresholds() {
        // Scale thresholds based on sensitivity (1-10)
        // Higher sensitivity means lower threshold with improved scaling
        rotationThreshold = 0.25 - (motionSensitivity * 0.022)
        tiltThreshold = 0.25 - (motionSensitivity * 0.022)
    }
    
    private func updateNeutralZone() {
        // Scale neutral zone inversely with sensitivity
        // Higher sensitivity means smaller neutral zone for faster response
        neutralZone = 0.15 - (motionSensitivity * 0.01)
        
        // Also adjust response curve - more sensitive = more linear response
        responseCurve = 1.4 - (motionSensitivity * 0.03)
    }
    
    private func saveActions() {
        if let encoded = try? JSONEncoder().encode(motionActions) {
            UserDefaults.standard.set(encoded, forKey: "savedMotionActions")
        }
    }
    
    private func loadActions() {
        if let savedData = UserDefaults.standard.data(forKey: "savedMotionActions"),
           let decoded = try? JSONDecoder().decode([MotionAction].self, from: savedData) {
            motionActions = decoded
        }
    }
    
    private func startContinuousAdjustmentTimer() {
        // Cancel any existing timer
        continuousAdjustmentTimer?.invalidate()
        
        // Create a new timer that checks active motion controls and applies continuous adjustment
        continuousAdjustmentTimer = Timer.scheduledTimer(withTimeInterval: continuousAdjustInterval, repeats: true) { [weak self] _ in
            guard let self = self, self.isMotionActivated else { return }
            
            // Process continuous slider adjustments
            self.processContinuousMotionAdjustments()
        }
        
        if let timer = continuousAdjustmentTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }
    
    private func processContinuousMotionAdjustments() {
        let now = Date()
        var controlsToRemove: [Int] = []
        
        // Process each active control
        for (controlId, (motionType, activationTime)) in activeMotionControls {
            // Find the control's action
            guard let action = motionActions.first(where: { $0.controlId == controlId }) else {
                controlsToRemove.append(controlId)
                continue
            }
            
            // Process sliders with increment/decrement actions
            if action.actionValue.starts(with: "increase:") || action.actionValue.starts(with: "decrease:") || action.actionValue.starts(with: "motion:") {
                // For twist and tilt, directly map the motion to increase/decrease instead of using stored action
                // This makes the control more intuitive - twist or tilt right to increase, left to decrease
                switch motionType {
                case .twist:
                    // Twist control - positive values (right) increase, negative values (left) decrease
                    if abs(rotationValue) > neutralZone {
                        // Direction is determined by the rotation value itself
                        let direction = rotationValue > 0 ? "increase" : "decrease"
                        
                        // Calculate intensity - how fast to change based on rotation amount
                        let normalizedValue = abs(rotationValue) - neutralZone
                        // Use a smooth curve for better control
                        let intensityFactor = min(1.0, pow(normalizedValue / (1.0 - neutralZone), responseCurve))
                        
                        // Create simple increase/decrease action directly from the motion
                        // Rather than using a percentage, we'll use the intensity directly
                        let actionValue = "\(direction):\(intensityFactor)"
                        
                        // Call the continuous motion callback with the determined direction and intensity
                        onContinuousMotion?(action.controlId, actionValue, intensityFactor)
                    }
                    
                case .tilt:
                    // We can use rotation value (roll) rather than tilt (pitch) for left/right control
                    if abs(rotationValue) > neutralZone {
                        // Left/right tilt is handled the same way as twist
                        let direction = rotationValue > 0 ? "increase" : "decrease"
                        let normalizedValue = abs(rotationValue) - neutralZone
                        let intensityFactor = min(1.0, pow(normalizedValue / (1.0 - neutralZone), responseCurve))
                        
                        let actionValue = "\(direction):\(intensityFactor)"
                        onContinuousMotion?(action.controlId, actionValue, intensityFactor)
                    }
                    
                default:
                    // Shake doesn't have continuous adjustment
                    break
                }
                
                // Simple haptic feedback when motion is detected
                if now.timeIntervalSince(activationTime) > 0.5 {
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred(intensity: 0.5)
                    
                    // Update the activation time to throttle feedback
                    activeMotionControls[controlId] = (motionType, now)
                }
            }
        }
        
        // Clean up any controls that need to be removed
        for controlId in controlsToRemove {
            activeMotionControls.removeValue(forKey: controlId)
        }
    }
    
    private func checkAndTriggerMotionActions() {
        // Use DispatchQueue.main.async to ensure UI updates happen on main thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Check for twist actions
            let rotationDelta = abs(self.rotationValue - self.lastRotationValue)
            if rotationDelta > self.rotationThreshold {
                // Determine direction
                let direction = self.rotationValue > self.lastRotationValue ? "right" : "left"
                let motionType = MotionType.twist.rawValue
                
                // Only trigger if no active type is set, or if the active type matches
                if self.activeMotionType == nil || self.activeMotionType?.rawValue == motionType {
                    // Find and trigger actions that match twist
                    for action in self.motionActions where action.motionType == motionType {
                        // Pass the direction to properly handle increase/decrease based on twist direction
                        self.triggerAction(action, motionDirection: direction)
                        
                        // For sliders, mark as active for continuous adjustment
                        if action.actionValue.starts(with: "increase:") ||
                           action.actionValue.starts(with: "decrease:") ||
                           action.actionValue.starts(with: "motion:") {
                            self.activeMotionControls[action.controlId] = (.twist, Date())
                        }
                    }
                }
            }
            
            // Check for tilt actions - similar fix applied
            let tiltDelta = abs(self.tiltValue - self.lastTiltValue)
            if tiltDelta > self.tiltThreshold {
                // Determine direction
                let direction = self.tiltValue > self.lastTiltValue ? "forward" : "backward"
                let motionType = MotionType.tilt.rawValue
                
                // Only trigger if no active type is set, or if the active type matches
                if self.activeMotionType == nil || self.activeMotionType?.rawValue == motionType {
                    // Find and trigger actions that match tilt
                    for action in self.motionActions where action.motionType == motionType {
                        // Pass the direction to properly handle increase/decrease based on tilt direction
                        self.triggerAction(action, motionDirection: direction)
                        
                        // For sliders, mark as active for continuous adjustment
                        if action.actionValue.starts(with: "increase:") ||
                           action.actionValue.starts(with: "decrease:") ||
                           action.actionValue.starts(with: "motion:") {
                            self.activeMotionControls[action.controlId] = (.tilt, Date())
                        }
                    }
                }
            }
        }
    }
    
    private func checkAndTriggerShakeActions() {
        let motionType = MotionType.shake.rawValue
        
        // Only trigger if no active type is set, or if the active type matches
        if activeMotionType == nil || activeMotionType?.rawValue == motionType {
            // Find and trigger actions that match shake
            for action in motionActions where action.motionType == motionType {
                triggerAction(action, motionDirection: nil)
            }
        }
    }
    
    private func triggerAction(_ action: MotionAction, motionDirection: String?) {
        // Check if this control is on cooldown
        let now = Date()
        if let lastActionTime = lastActionTimes[action.controlId],
           now.timeIntervalSince(lastActionTime) < actionCooldown {
            // Still on cooldown, skip this action
            return
        }
        
        // Get action value
        var actionValue = action.actionValue
        
        // If it's a directional action (for slider), adjust based on direction
        if actionValue.starts(with: "increase:") || actionValue.starts(with: "decrease:") {
            // For sliders, direction might determine whether to increase or decrease
            if let direction = motionDirection {
                if direction == "right" || direction == "forward" {
                    if actionValue.starts(with: "decrease:") {
                        // Convert decrease to increase for right/forward motion
                        let value = actionValue.replacingOccurrences(of: "decrease:", with: "")
                        actionValue = "increase:\(value)"
                    }
                } else if direction == "left" || direction == "backward" {
                    if actionValue.starts(with: "increase:") {
                        // Convert increase to decrease for left/backward motion
                        let value = actionValue.replacingOccurrences(of: "increase:", with: "")
                        actionValue = "decrease:\(value)"
                    }
                }
            }
        }
        
        // Call the callback with the control ID and action value
        logger.debug("Triggering motion action: \(action.controlId), value: \(actionValue)")
        onMotionActionTriggered?(action.controlId, actionValue)
        
        // Record this action time for cooldown
        lastActionTimes[action.controlId] = now
        
        // Provide haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
}
