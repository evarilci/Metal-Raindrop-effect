//
//  MotionManager 2.swift
//  MetalShaderExamples
//
//  Created by Eymen Varilci on 3.03.2026.
//


import SwiftUI
import CoreMotion
import Combine

class MotionManager: ObservableObject {
    private let motionManager = CMMotionManager()
    
    @Published var x: Double = 0.0
    @Published var y: Double = 0.0
    
    // Memorizes the user's "resting" angle.
    // We default y to -0.6 so the initial launch looks good before they calibrate.
    private var referenceX: Double = 0.0
    private var referenceY: Double = -0.6
    
    init() {
        startDeviceMotion()
    }
    
    private func startDeviceMotion() {
        guard motionManager.isDeviceMotionAvailable else { return }
        
        motionManager.deviceMotionUpdateInterval = 1.0 / 60.0
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] data, error in
            guard let data = data, let self = self else { return }
            
            withAnimation(.interactiveSpring(response: 0.3, dampingFraction: 0.8)) {
                // We calculate the tilt relative to the memorized zero-point
                self.x = data.gravity.x - self.referenceX
                self.y = data.gravity.y - self.referenceY
            }
        }
    }
    
    // --- NEW: Calibration Method ---
    // Reads the exact current angle of the phone and sets it as the new baseline
    func calibrate() {
        guard let gravity = motionManager.deviceMotion?.gravity else { return }
        referenceX = gravity.x
        referenceY = gravity.y
        
        // Snap the window back to center immediately
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
            self.x = 0
            self.y = 0
        }
    }
    
    deinit {
        motionManager.stopDeviceMotionUpdates()
    }
}
