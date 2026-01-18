import SwiftUI

struct AmbientBackground: View {
    var body: some View {
        ZStack {
            // Base Color
            Color.bgApp.ignoresSafeArea()
            
            GeometryReader { proxy in
                ZStack {
                    // Red Glow (Top Right)
                    Circle()
                        .fill(Color.accentRed.opacity(0.25))
                        .frame(width: 600, height: 600)
                        .blur(radius: 120)
                        .offset(x: proxy.size.width * 0.3, y: -250)
                    
                    // Blue Glow (Slightly left of Red)
                    Circle()
                        .fill(Color.accentBlue.opacity(0.2))
                        .frame(width: 500, height: 500)
                        .blur(radius: 100)
                        .offset(x: proxy.size.width * 0.1, y: -200)
                }
            }
            .ignoresSafeArea()
        }
    }
}
