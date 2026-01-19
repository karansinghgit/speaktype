import SwiftUI
import AVFoundation

struct AudioInputView: View {
    @StateObject private var audioRecorder = AudioRecordingService.shared
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                // Header
                VStack(spacing: 15) {
                    Image(systemName: "waveform")
                        .font(.system(size: 40))
                        .foregroundStyle(Color.appRed)
                    
                    Text("Audio Input")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.textPrimary)
                    
                    Text("Configure your microphone preferences")
                        .foregroundStyle(.gray)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 40)
                
                // Input Mode Section Removed

                    


                
                // Available Devices Section
                VStack(alignment: .leading, spacing: 15) {
                    HStack {
                        Text("Available Devices")
                            .font(.headline)
                            .foregroundStyle(Color.textPrimary)
                        Spacer()
                        Button(action: {
                            audioRecorder.fetchAvailableDevices()
                        }) {
                            HStack {
                                Image(systemName: "arrow.clockwise")
                                Text("Refresh")
                            }
                            .font(.subheadline)
                            .foregroundStyle(.gray)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    Text("Note: SpeakType will use the selected device for all recordings.")
                        .font(.caption)
                        .foregroundStyle(.gray)
                    
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
                .foregroundStyle(isSelected ? Color.appRed : .gray)
                .font(.title3)
            
            Text(name)
                .font(.body)
                .foregroundStyle(Color.textPrimary)
            
            Spacer()
            
            if isActive {
                HStack(spacing: 4) {
                    Image(systemName: "waveform")
                    Text("Active")
                }
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.green.opacity(0.2))
                .foregroundStyle(.green)
                .cornerRadius(12)
            }
        }
        .padding()
        .background(isSelected ? Color.appRed.opacity(0.05) : Color.bgCard)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.appRed.opacity(0.5) : Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}
