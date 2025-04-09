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
    
    static let shared = MotionControlManager()
    private let motionManager = CMMotionManager()
    private let defaultSensitivity: Double = 5.0
    private let logger = Logger(subsystem: "com.aaronflynn.SmartDeviceController", category: "MotionControl")
    
    private var neutralRotation: Double = 0.0
    private var neutralTilt: Double = 0.0
    private var deadZone: Double = 0.1
    
    private var sliderUpdateTimer: Timer? = nil
    private let updateInterval: TimeInterval = 0.1
    
    private var lastAcceleration: CMAcceleration = CMAcceleration(x: 0, y: 0, z: 0)
    private var shakeCount: Int = 0
    private var lastShakeTime: Date = Date(timeIntervalSince1970: 0)
    private let shakeThreshold: Double = 2.0
    private let shakeCooldown: TimeInterval = 1.0
    
    @Published var isMotionEnabled = false
    @Published var isMotionActivated = false
    @Published var motionSensitivity: Double = 5.0
    @Published var isMotionAvailable: Bool = true
    
    @Published var rotationValue: Double = 0
    @Published var tiltValue: Double = 0
    @Published var shakeDetected: Bool = false
    
    @Published var motionActions: [MotionAction] = []
    
    var onMotionActionTriggered: ((Int, String) -> Void)?
    
    private init() {
        isMotionAvailable = motionManager.isDeviceMotionAvailable
        loadSettings()
        loadActions()
    }
    
    func loadSettings() {
        isMotionEnabled = UserDefaults.standard.bool(forKey: "motionControlsEnabled")
        let sensitivity = UserDefaults.standard.double(forKey: "motionControlsSensitivity")
        motionSensitivity = sensitivity == 0 ? defaultSensitivity : sensitivity
    }
    
    func saveSettings() {
        UserDefaults.standard.set(isMotionEnabled, forKey: "motionControlsEnabled")
        UserDefaults.standard.set(motionSensitivity, forKey: "motionControlsSensitivity")
    }
    
    func addMotionAction(deviceId: Int, controlId: Int, motionType: MotionType, actionValue: String) {
        var updatedActions = motionActions
        
        if let existingIndex = updatedActions.firstIndex(where: { $0.controlId == controlId }) {
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
        
        print("Added motion action for control \(controlId) with type \(motionType.rawValue)")
    }
    
    func removeMotionAction(id: String) {
        motionActions.removeAll { $0.id == id }
        saveActions()
    }
    
    func getMotionActions(forDevice deviceId: Int) -> [MotionAction] {
        return motionActions.filter { $0.deviceId == deviceId }
    }
    
    func getMotionAction(forControl controlId: Int) -> MotionAction? {
        return motionActions.first { $0.controlId == controlId }
    }
    
    func startMotionTracking() {
        guard isMotionEnabled, motionManager.isDeviceMotionAvailable, !motionManager.isDeviceMotionActive else {
            logger.error("Cannot start motion tracking - conditions not met")
            return
        }
        
        motionManager.deviceMotionUpdateInterval = 0.05
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] (motion, error) in
            guard let self = self, let motion = motion else { return }
            
            self.rotationValue = motion.attitude.roll
            self.tiltValue = motion.attitude.pitch
            
            let acceleration = motion.userAcceleration
            let deltaX = abs(acceleration.x - self.lastAcceleration.x)
            let deltaY = abs(acceleration.y - self.lastAcceleration.y)
            let deltaZ = abs(acceleration.z - self.lastAcceleration.z)
            
            self.lastAcceleration = acceleration
            
            if (deltaX + deltaY + deltaZ) > self.shakeThreshold {
                self.shakeCount += 1
                
                if self.shakeCount >= 2 && Date().timeIntervalSince(self.lastShakeTime) > self.shakeCooldown {
                    self.shakeDetected = true
                    self.lastShakeTime = Date()
                    self.handleShake()
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.shakeDetected = false
                    }
                }
            } else {
                self.shakeCount = max(0, self.shakeCount - 1)
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            guard let self = self else { return }
            
            self.neutralRotation = self.rotationValue
            self.neutralTilt = self.tiltValue
            
            print("Motion tracking started with neutral rotation: \(self.neutralRotation), neutral tilt: \(self.neutralTilt)")
            self.isMotionActivated = true
            
            self.startSliderUpdateTimer()
        }
        
        logger.info("Motion tracking started")
    }
    
    func stopMotionTracking() {
        if motionManager.isDeviceMotionActive {
            motionManager.stopDeviceMotionUpdates()
            isMotionActivated = false
            
            sliderUpdateTimer?.invalidate()
            sliderUpdateTimer = nil
            
            logger.info("Motion tracking stopped")
        }
    }
    
    private func startSliderUpdateTimer() {
        sliderUpdateTimer?.invalidate()
        
        sliderUpdateTimer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { [weak self] _ in
            guard let self = self, self.isMotionActivated else { return }
            self.updateMotionControls()
        }
        
        if let timer = sliderUpdateTimer {
            RunLoop.current.add(timer, forMode: .common)
        }
    }
    
    private func updateMotionControls() {
        for action in motionActions {
            let controlId = action.controlId
            
            if action.actionValue == "motion:enabled" {
                if action.motionType == MotionType.twist.rawValue {
                    let rotationDelta = rotationValue - neutralRotation
                    
                    if abs(rotationDelta) > deadZone {
                        let increment = calculateIncrement(delta: rotationDelta)
                        let actionValue = rotationDelta > 0 ? "increase:\(increment)" : "decrease:\(increment)"
                        
                        onMotionActionTriggered?(controlId, actionValue)
                    }
                } else if action.motionType == MotionType.tilt.rawValue {
                    let tiltDelta = tiltValue - neutralTilt
                    
                    if abs(tiltDelta) > deadZone {
                        let increment = calculateIncrement(delta: tiltDelta)
                        let actionValue = tiltDelta > 0 ? "increase:\(increment)" : "decrease:\(increment)"
                        
                        onMotionActionTriggered?(controlId, actionValue)
                    }
                }
            }
            else if action.actionValue == "toggle" {
                if action.motionType == MotionType.twist.rawValue {
                    let rotationDelta = rotationValue - neutralRotation
                    if abs(rotationDelta) > 0.5 && abs(rotationValue) > abs(neutralRotation) + 0.5 {
                        onMotionActionTriggered?(controlId, "toggle")
                        
                        neutralRotation = rotationValue
                    }
                } else if action.motionType == MotionType.tilt.rawValue {
                    let tiltDelta = tiltValue - neutralTilt
                    if abs(tiltDelta) > 0.5 && abs(tiltValue) > abs(neutralTilt) + 0.5 {
                        onMotionActionTriggered?(controlId, "toggle")
                        
                        neutralTilt = tiltValue
                    }
                }
            }
            else if !action.actionValue.contains(":") {
                if action.motionType == MotionType.twist.rawValue {
                    let rotationDelta = rotationValue - neutralRotation
                    if abs(rotationDelta) > 0.5 && abs(rotationValue) > abs(neutralRotation) + 0.5 {
                        onMotionActionTriggered?(controlId, action.actionValue)
                        
                        neutralRotation = rotationValue
                    }
                } else if action.motionType == MotionType.tilt.rawValue {
                    let tiltDelta = tiltValue - neutralTilt
                    if abs(tiltDelta) > 0.5 && abs(tiltValue) > abs(neutralTilt) + 0.5 {
                        onMotionActionTriggered?(controlId, action.actionValue)
                        
                        neutralTilt = tiltValue
                    }
                }
            }
        }
    }
    
    private func handleShake() {
        print("Shake detected!")
        shakeDetected = true
        
        let shakeActions = motionActions.filter { $0.motionType == MotionType.shake.rawValue }
        for action in shakeActions {
            let controlId = action.controlId
            
            if action.actionValue.hasPrefix("shake:") {
                let message = action.actionValue.replacingOccurrences(of: "shake:", with: "")
                onMotionActionTriggered?(controlId, message)
            }
            else if action.actionValue == "toggle" {
                onMotionActionTriggered?(controlId, "toggle")
            }
            else if action.actionValue == "motion:enabled" {
                let isCurrentlyMax = UserDefaults.standard.bool(forKey: "motion_slider_\(action.controlId)_isMax")
                if isCurrentlyMax {
                    onMotionActionTriggered?(controlId, "set:0")
                } else {
                    onMotionActionTriggered?(controlId, "set:100")
                }
                UserDefaults.standard.set(!isCurrentlyMax, forKey: "motion_slider_\(action.controlId)_isMax")
            }
            else {
                onMotionActionTriggered?(controlId, action.actionValue)
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.shakeDetected = false
        }
    }
    
    private func calculateIncrement(delta: Double) -> Int {
        let baseIncrement = 1
        
        let speed = Int(motionSensitivity)
        
        let motionFactor = min(abs(delta) / 0.5, 1.0) 
        
        return baseIncrement * max(1, Int(motionFactor * Double(speed)))
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
}
