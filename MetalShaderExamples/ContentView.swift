import SwiftUI
import CoreMotion
import Combine
import AVFoundation

import SwiftUI
import AVFoundation

enum WindowMode: String, CaseIterable {
    case frontCamera = "Front"
    case backCamera = "Back"
    case staticImage = "Static"
}

// 1. The top-level view now ONLY handles the Picker.
// It does NOT observe the 60fps motion data, so it remains perfectly responsive.
struct ContentView: View {
    @State private var selectedMode: WindowMode = .frontCamera
    
    var body: some View {
        ZStack {
            // Far background
            LinearGradient(
                colors: [Color(white: 0.1), Color(white: 0.2)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 40) {
                // --- Safe from 60fps Redraws! ---
                Picker("Window Mode", selection: $selectedMode) {
                    ForEach(WindowMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 30)
                .padding(.top, 60)
                .colorScheme(.dark)
                .zIndex(1) // Ensures it stays on top for hit-testing
                
                // --- The Isolated Physics Container ---
                // We pass the selected mode down into the container
                MotionContainerView(selectedMode: selectedMode)
            }
        }
    }
}

// 2. This container traps all the 60fps updates inside itself
struct MotionContainerView: View {
    // The MotionManager is now owned HERE. Only this view and its children redraw.
    @StateObject private var motion = MotionManager()
    var selectedMode: WindowMode
    
    var body: some View {
        ZStack {
            VStack {
                // The Parallax Window
                ParallaxWindowView(motion: motion, selectedMode: selectedMode)
                Spacer()
            }
            
            // Floating Calibration Button
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: {
                        motion.calibrate()
                    }) {
                        Image(systemName: "gyroscope")
                            .font(.title2)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.black.opacity(0.4))
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 1))
                            .shadow(radius: 5)
                    }
                    .padding(30)
                }
            }
        }
    }
}

// 3. The physical window (Same as before)
struct ParallaxWindowView: View {
    @ObservedObject var motion: MotionManager
    var selectedMode: WindowMode
    
    var body: some View {
        ZStack {
            RainDistortionView(motionX: motion.x, motionY: motion.y) {
                ZStack {
                    switch selectedMode {
                    case .frontCamera:
                        CameraView(position: .front)
                    case .backCamera:
                        CameraView(position: .back)
                    case .staticImage:
                        LinearGradient(
                            colors: [Color.blue, Color.mint, Color.teal],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        VStack(spacing: 20) {
                            Image(systemName: "cloud.rain.fill")
                                .font(.system(size: 80))
                                .foregroundColor(.white.opacity(0.8))
                                .shadow(radius: 10)
                            Text("Spring Showers")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .shadow(color: .black.opacity(0.3), radius: 5, y: 3)
                        }
                    }
                }
                .scaleEffect(1.3)
                .offset(
                    x: CGFloat(motion.x * 40),
                    y: CGFloat(motion.y * 40)
                )
            }
            .frame(width: 300, height: 300)
            .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.5), .white.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
                    .blendMode(.overlay)
            )
            .shadow(color: .black.opacity(0.5), radius: 30, x: 0, y: 20)
            
            // 3D Parallax Tilt
            .rotation3DEffect(.radians(motion.y * 0.5), axis: (x: 1, y: 0, z: 0), perspective: 0.8)
            .rotation3DEffect(.radians(motion.x * 0.5), axis: (x: 0, y: 1, z: 0), perspective: 0.8)
        }
    }
}
