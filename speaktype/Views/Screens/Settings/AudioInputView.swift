import SwiftUI
import AVFoundation

struct AudioInputView: View {
    @StateObject private var audioRecorder = AudioRecordingService.shared
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "waveform")
                        .font(.system(size: 36))
                        .foregroundStyle(Color.accentPrimary)
                    
                    Text("Audio Input")
                        .font(Typography.displayLarge)
                        .foregroundStyle(Color.textPrimary)
                    
                    Text("Configure your microphone preferences")
                        .font(Typography.bodyMedium)
                        .foregroundStyle(Color.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 32)
                
                // Input Mode Section Removed

                    


                
                // Available Devices Section
                VStack(alignment: .leading, spacing: 15) {
                    HStack {
                        Text("Available Devices")
                            .font(Typography.headlineMedium)
                            .foregroundStyle(Color.textPrimary)
                        Spacer()
                        Button(action: {
                            audioRecorder.fetchAvailableDevices()
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.clockwise")
                                Text("Refresh")
                            }
                            .font(Typography.bodySmall)
                            .foregroundStyle(Color.textSecondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.bgHover)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        .buttonStyle(.plain)
                    }
                    
                    Text("Note: SpeakType will use the selected device for all recordings.")
                        .font(Typography.bodySmall)
                        .foregroundStyle(Color.textSecondary)
                    
                    VStack(spacing: 12) {
                        if audioRecorder.availableDevices.isEmpty {
                            Text("No input devices found.")
                                .foregroundStyle(.gray)
                                .padding()
                        } else {
                            ForEach(audioRecorder.availableDevices, id: \.uniqueID) { device in
                                DeviceRow(
                                    name: device.localizedName,
                                    isActive: audioRecorder.selectedDeviceId == device.uniqueID, // Simple check
                                    isSelected: audioRecorder.selectedDeviceId == device.uniqueID
                                )
                                .onTapGesture {
                                    audioRecorder.selectedDeviceId = device.uniqueID
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 40)
            }
            .padding(.bottom, 40)
        }
        .background(Color.clear)
        .onAppear {
            audioRecorder.fetchAvailableDevices()
        }
    }
}



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
