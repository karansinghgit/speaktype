import SwiftUI

struct WateryWaveView: View {
    var audioLevel: Float
    
    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let time = timeline.date.timeIntervalSinceReferenceDate
                let midHeight = size.height / 2
                let width = size.width
                
                // Draw multiple waves for watery effect
                for i in 0..<3 {
                    var path = Path()
                    path.move(to: CGPoint(x: 0, y: midHeight))
                    
                    let frequency = 4.0 + Double(i) * 0.5
                    let phase = time * (3.0 + Double(i))
                    // Amplify the wave height based on audio level
                    // Base amplitude adds a subtle movement even when silent
                    let amplitude = (Double(audioLevel) * 25.0) + 2.0
                    
                    for x in stride(from: 0, to: width, by: 2) {
                        // Normalized position (0 to 1)
                        let relativeX = x / width
                        
                        // Signal envelope: Clamp ends to 0 to look like a signal between points
                        // Use a sine window for smooth clamping
                        let envelope = sin(relativeX * .pi)
                        
                        let sine = sin(relativeX * .pi * frequency + phase)
                        let y = midHeight + sine * amplitude * envelope
                        
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                    
                    context.stroke(
                        path,
                        with: .color(.white.opacity(0.6 - Double(i) * 0.15)),
                        lineWidth: 2
                    )
                }
            }
        }
        .frame(height: 40) // Constrain height for the signal look
    }
}

#Preview {
    ZStack {
        Color.black
        WateryWaveView(audioLevel: 0.5)
            .frame(width: 200)
    }
}
