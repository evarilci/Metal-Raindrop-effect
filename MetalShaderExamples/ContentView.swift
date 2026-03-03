import SwiftUI
import CoreMotion
import Combine



struct ContentView: View {
    @StateObject private var motion = MotionManager()
    
    var body: some View {
        ZStack {
            // Background Wallpaper (Far Plane)
            LinearGradient(
                colors: [Color(white: 0.1), Color(white: 0.2)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            // The Raining Window (Mid Plane)
            // We pass the motion data to drive the glass glare overlay
            RainDistortionView(motionX: motion.x, motionY: motion.y) {
                ZStack {
                    // The vibrant view "outside" the window being refracted
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
                // Scale up so when it offsets we don't see the edges of the gradient
                .scaleEffect(1.3)
                // Offset the interior background opposite to device tilt to fake deep depth behind the glass
                .offset(
                    x: CGFloat(motion.x * 40),
                    y: CGFloat(motion.y * 40)
                )
            }
            .frame(width: 300, height: 300) // Square cropped window
            .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
            // Outer Window Frame Styling
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
            
            // --- 3D Parallax Rotation ---
            // Tilts the view up/down based on the Y axis
            .rotation3DEffect(
                .radians(motion.y * 0.5),
                axis: (x: 1, y: 0, z: 0),
                perspective: 0.8
            )
            // Tilts the view left/right based on the X axis
            .rotation3DEffect(
                .radians(motion.x * 0.5),
                axis: (x: 0, y: 1, z: 0),
                perspective: 0.8
            )
        }
    }
}

#Preview {
    ContentView()
}
