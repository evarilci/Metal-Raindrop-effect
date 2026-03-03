import SwiftUI

/// A container view providing the animation timer, the Metal Shader, and a dynamic parallax glare
public struct RainDistortionView<Content: View>: View {
    @ViewBuilder let content: Content
    
    @State private var startDate = Date()
    
    // NEW: Properties to receive the normalized device motion
    public var motionX: Double
    public var motionY: Double
    
    // Added motion parameters with default values so it doesn't break existing code
    public init(motionX: Double = 0.0, motionY: Double = 0.0, @ViewBuilder content: () -> Content) {
        self.motionX = motionX
        self.motionY = motionY
        self.content = content()
    }
    
    public var body: some View {
        TimelineView(.animation) { timeline in
            let elapsedTime = timeline.date.timeIntervalSince(startDate)
            
            content
                .visualEffect { content, proxy in
                    content
                        .layerEffect(
                            ShaderLibrary.rainDistortion(
                                .float2(proxy.size),
                                .float(Float(elapsedTime))
                            ),
                            maxSampleOffset: CGSize(width: 150, height: 150)
                        )
                }
                // --- NEW: Dynamic Glass Glare Overlay ---
                .overlay(
                    LinearGradient(
                        colors: [
                            .clear,
                            .white.opacity(0.1),
                            .white.opacity(0.3),
                            .white.opacity(0.1),
                            .clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    // Scale it up significantly so we don't see the edges when it sweeps
                    .scaleEffect(2.5)
                    // Move the glare opposite to the device tilt for a realistic reflection
                    .offset(
                        x: CGFloat(-motionX * 250),
                        y: CGFloat(-motionY * 250)
                    )
                    .blendMode(.screen)
                    .allowsHitTesting(false) // Ensures the glare doesn't block interactions
                )
        }
    }
}

// SwiftUI Preview
#Preview {
    // Passing hardcoded mock tilt values so the glare shows up in the canvas
    RainDistortionView(motionX: 0.3, motionY: -0.2) {
        ZStack {
            LinearGradient(
                colors: [Color.blue, Color.purple, Color.orange, Color.pink],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 20) {
                Image(systemName: "cloud.rain.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.white.opacity(0.8))
                    .shadow(radius: 10)
                
                Text("Rainy Window")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(radius: 10)
            }
        }
    }
}
