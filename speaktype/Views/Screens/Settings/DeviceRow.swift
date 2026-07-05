import SwiftUI
import AVFoundation

// Row component used by the Audio tab in SettingsView.
struct DeviceRow: View {
    let name: String
    let isActive: Bool
    let isSelected: Bool

    var body: some View {
        HStack {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isSelected ? Color.accentPrimary : Color.textMuted)
                .font(.title3)

            Text(name)
                .font(Typography.bodyMedium)
                .foregroundStyle(Color.textPrimary)

            Spacer()

            if isActive {
                HStack(spacing: 4) {
                    Image(systemName: "waveform")
                    Text("Active")
                }
                .font(Typography.labelSmall)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.accentSuccess.opacity(0.15))
                .foregroundStyle(Color.accentSuccess)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
        .padding(16)
        .background(isSelected ? Color.bgSelected : Color.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.bgSelected : Color.border, lineWidth: 1)
        )
        .cardShadow()
    }
}
