import SwiftUI
import CoreMotion
import Combine




struct ContentView: View {
    @StateObject private var motion = MotionManager()
    
    var body: some View {
        ZStack {
            // Far background behind the window
            LinearGradient(
                colors: [Color(white: 0.1), Color(white: 0.2)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            RainDistortionView(motionX: motion.x, motionY: motion.y) {
                // We swap the ZStack gradient for our live camera!
                CameraView()
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
            
            // 3D Tilt stays exactly the same
            .rotation3DEffect(.radians(motion.y * 0.5), axis: (x: 1, y: 0, z: 0), perspective: 0.8)
            .rotation3DEffect(.radians(motion.x * 0.5), axis: (x: 0, y: 1, z: 0), perspective: 0.8)
        }
    }
}
