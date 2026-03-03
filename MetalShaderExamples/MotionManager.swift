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
    
    // We'll output normalized x and y tilt values (-1.0 to 1.0)
    @Published var x: Double = 0.0
    @Published var y: Double = 0.0
    
    init() {
        startDeviceMotion()
    }
    
    private func startDeviceMotion() {
        guard motionManager.isDeviceMotionAvailable else { return }
        
        motionManager.deviceMotionUpdateInterval = 1.0 / 60.0
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] data, error in
            guard let data = data else { return }
            
            withAnimation(.interactiveSpring(response: 0.3, dampingFraction: 0.8)) {
                // Gravity provides a much smoother, bounded metric for UI parallax
                self?.x = data.gravity.x
                // Gravity.y is roughly -0.5 to -0.8 when holding a phone normally.
                // We add 0.6 so the "neutral" resting state is closer to 0.
                self?.y = data.gravity.y + 0.6 
            }
        }
    }
    
    deinit {
        motionManager.stopDeviceMotionUpdates()
    }
}
