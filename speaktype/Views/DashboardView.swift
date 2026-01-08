import SwiftUI

struct DashboardView: View {
    var body: some View {
        VStack {
            // Header removed for cleaner look
            
            // Placeholder content
            Spacer()
            
            Image(systemName: "waveform")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 100, height: 100)
                .foregroundStyle(Color.appRed)
            
            Text("No Transcriptions Yet")
                .font(.headline)
                .foregroundStyle(.white)
                .padding(.top)
             
            Text("Start your first recording to unlock value insights.")
                .font(.subheadline)
                .foregroundStyle(.gray)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.contentBackground)
    }
}
