import SwiftUI
import AVFoundation

struct AudioInputView: View {
    @StateObject private var audioRecorder = AudioRecordingService.shared
    @State private var selectedMode = "Custom Device"
    
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
                        .foregroundStyle(.white)
                    
                    Text("Configure your microphone preferences")
                        .foregroundStyle(.gray)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 40)
                
                // Input Mode Section
                VStack(alignment: .leading, spacing: 15) {
                    Text("Input Mode")
                        .font(.headline)
                        .foregroundStyle(.white)
                    
                    HStack(spacing: 20) {
                        InputModeCard(
                            title: "Custom Device",
                            desc: "Select a specific input device",
                            icon: "mic.fill",
                            isSelected: selectedMode == "Custom Device",
                            color: .appRed
                        )
                        .onTapGesture { selectedMode = "Custom Device" }
                        
                        InputModeCard(
                            title: "Prioritized (Coming Soon)",
                            desc: "Set up device priority order",
                            icon: "list.number",
                            isSelected: selectedMode == "Prioritized",
                            color: .gray
                        )
                        .onTapGesture { /* selectedMode = "Prioritized" */ }
                    }
                }
                .padding(.horizontal, 40)
                
                // Available Devices Section
                VStack(alignment: .leading, spacing: 15) {
                    HStack {
                        Text("Available Devices")
                            .font(.headline)
                            .foregroundStyle(.white)
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
        .background(Color.contentBackground)
        .onAppear {
            audioRecorder.fetchAvailableDevices()
        }
    }
}

struct InputModeCard: View {
    let title: String
    let desc: String
    let icon: String
    let isSelected: Bool
    let color: Color
    
    var body: some View {
        HStack(alignment: .top, spacing: 15) {
            ZStack {
                Circle()
                    .fill(isSelected ? color.opacity(0.2) : Color.white.opacity(0.1))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .foregroundStyle(isSelected ? color : .gray)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)
                Text(desc)
                    .font(.caption)
                    .foregroundStyle(.gray)
            }
            Spacer()
        }
        .padding()
        .frame(height: 100)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? color : Color.white.opacity(0.1), lineWidth: 1)
        )
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
                .foregroundStyle(.white)
            
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
        .background(isSelected ? Color.appRed.opacity(0.05) : Color.white.opacity(0.02))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.appRed.opacity(0.5) : Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}
