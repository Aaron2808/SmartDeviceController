//
//  MotionControlManager.swift
//  SmartDeviceController
//
//  Created by Aaron Flynn on 13/03/2025.
//


import CoreMotion
import SwiftUI
import Combine

class MotionControlManager: ObservableObject {
    static let shared = MotionControlManager()
    private let motionManager = CMMotionManager()
    
    @Published var isMotionEnabled = false
    @Published var rotationValue: Double = 0
    
    private init() {
        // Initialize with user preferences if needed
        loadSettings()
    }
    
    func loadSettings() {
        isMotionEnabled = UserDefaults.standard.bool(forKey: "motionControlsEnabled")
    }
    
    func saveSettings() {
        UserDefaults.standard.set(isMotionEnabled, forKey: "motionControlsEnabled")
    }
    
    func startRotationTracking() {
        guard isMotionEnabled, motionManager.isDeviceMotionAvailable else { return }
        
        motionManager.deviceMotionUpdateInterval = 0.1
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] (motion, error) in
            guard let self = self, let motion = motion else { return }
            
            // Extract rotation from device motion
            let roll = motion.attitude.roll
            self.rotationValue = roll
        }
    }
    
    func stopRotationTracking() {
        if motionManager.isDeviceMotionActive {
            motionManager.stopDeviceMotionUpdates()
        }
    }
}