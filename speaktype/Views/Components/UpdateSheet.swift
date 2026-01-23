import SwiftUI

/// Update dialog sheet matching the VoiceInk design
struct UpdateSheet: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var updateService = UpdateService.shared
    @AppStorage("autoUpdate") private var autoUpdate = false
    
    let update: AppVersion
    let appName = "SpeakType"
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with app icon and title
            HStack(alignment: .top, spacing: 16) {
                // App Icon
                Image(nsImage: NSApplication.shared.applicationIconImage)
                    .resizable()
                    .frame(width: 80, height: 80)
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("A new version of \(appName) is available!")
                        .font(Typography.headlineLarge)
                        .foregroundStyle(.primary)
                    
                    Text("\(appName) \(update.version) is now available—you have \(AppVersion.currentVersion). Would you like to download it now?")
                        .font(Typography.bodyMedium)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(24)
            
            // What's New Section
            VStack(alignment: .leading, spacing: 16) {
                Text("What's New in Version \(update.version)")
                    .font(Typography.headlineMedium)
                    .foregroundStyle(.primary)
                
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(update.releaseNotes, id: \.self) { note in
                        HStack(alignment: .top, spacing: 8) {
                            Text("•")
                                .font(Typography.bodyMedium)
                                .foregroundStyle(.primary)
                            Text(note)
                                .font(Typography.bodyMedium)
                                .foregroundStyle(.primary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(12)
            .padding(.horizontal, 24)
            
            // Auto-update checkbox
            HStack(spacing: 8) {
                Toggle(isOn: $autoUpdate) {
                    Text("Automatically download and install updates in the future")
                        .font(Typography.bodySmall)
                        .foregroundStyle(.secondary)
                }
                .toggleStyle(.checkbox)
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            
            // Action buttons
            HStack(spacing: 12) {
                Button("Skip This Version") {
                    updateService.skipVersion(update.version)
                    dismiss()
                }
                .buttonStyle(SecondaryButtonStyle())
                
                Button("Remind Me Later") {
                    updateService.markReminderShown()
                    dismiss()
                }
                .buttonStyle(SecondaryButtonStyle())
                
                Button("Install Update") {
                    updateService.installUpdate(url: update.downloadURL)
                    dismiss()
                }
                .buttonStyle(PrimaryButtonStyle())
            }
            .padding(24)
        }
        .frame(width: 600)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

// MARK: - Button Styles

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Typography.labelMedium)
            .foregroundStyle(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 10)
            .background(Color.blue)
            .cornerRadius(8)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Typography.labelMedium)
            .foregroundStyle(.primary)
            .padding(.horizontal, 24)
            .padding(.vertical, 10)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
    }
}

// MARK: - Preview

#Preview {
    UpdateSheet(update: AppVersion.mockUpdate)
        .frame(width: 600, height: 500)
}
