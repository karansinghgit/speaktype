//
//  StatisticsView.swift
//  speaktype
//
//  Created on 2026-01-19.
//  Statistics view showing daily word transcription trends
//

import SwiftUI
import Charts

struct StatisticsView: View {
    @StateObject private var historyService = HistoryService.shared
    @ObservedObject private var audioRecorder = AudioRecordingService.shared
    @State private var selectedPeriod: StatisticsPeriod = .week
    @State private var timer: Timer? = nil
    @State private var timeTrigger = Date()
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                headerSection
                summaryCards
                barChartSection
                detailsSection
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 24)
        }
        .background(Color.clear)
        .onAppear {
            startTimer()
        }
        .onDisappear {
            stopTimer()
        }
        .onChange(of: audioRecorder.isRecording) { _, isRecording in
            if isRecording {
                startTimer()
            } else {
                stopTimer()
                // Force one last update
                timeTrigger = Date()
            }
        }
    }
    
    // MARK: - View Components
    
    private var headerSection: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Statistics")
                    .font(Typography.displayLarge)
                    .foregroundStyle(Color.textPrimary)
                
                Text("\(totalWords(for: selectedPeriod)) words this \(selectedPeriod.rawValue.lowercased())")
                    .font(Typography.bodySmall)
                    .foregroundStyle(Color.textSecondary)
            }
            
            Spacer()
            
            // Period selector
            HStack(spacing: 8) {
                ForEach(StatisticsPeriod.allCases) { period in
                    PeriodButton(
                        period: period,
                        isSelected: selectedPeriod == period,
                        action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                selectedPeriod = period
                            }
                        }
                    )
                }
            }
        }
    }
    
    private var summaryCards: some View {
        HStack(spacing: 16) {
            StatCard(
                icon: "doc.text.fill",
                label: "Total Words",
                value: "\(totalWords(for: selectedPeriod))"
            )
            
            StatCard(
                icon: "calendar",
                label: "Daily Average",
                value: "\(dailyAverage(for: selectedPeriod))"
            )
            
            StatCard(
                icon: "chart.line.uptrend.xyaxis",
                label: "Best Day",
                value: "\(bestDay(for: selectedPeriod))"
            )
            
            StatCard(
                icon: "number",
                label: "Transcriptions",
                value: "\(transcriptionCount(for: selectedPeriod))"
            )
        }
    }
    
    private var barChartSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .firstTextBaseline) {
                Text("Activity")
                    .font(Typography.headlineLarge)
                    .foregroundStyle(Color.textPrimary)
                
                Spacer()
                
                if !dailyData(for: selectedPeriod).isEmpty {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(transcriptionCount(for: selectedPeriod)) transcriptions")
                            .font(Typography.labelSmall)
                            .foregroundStyle(Color.textSecondary)
                        Text(formattedDuration(for: selectedPeriod))
                            .font(Typography.captionSmall)
                            .foregroundStyle(Color.textMuted)
                    }
                }
            }
            
            if dailyData(for: selectedPeriod).isEmpty {
                emptyChartView
            } else {
                chartView
            }
        }
        .padding(24)
        .background(Color.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.border.opacity(0.5), lineWidth: 1)
        )
        .cardShadow()
    }
    
    private var emptyChartView: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 48))
                .foregroundStyle(Color.textMuted.opacity(0.4))
            
            VStack(spacing: 6) {
                Text("No activity yet")
                    .font(Typography.headlineMedium)
                    .foregroundStyle(Color.textPrimary)
                
                Text("Your transcription statistics will appear here")
                    .font(Typography.bodySmall)
                    .foregroundStyle(Color.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 280)
    }
    
    private var chartView: some View {
        Chart {
            ForEach(dailyData(for: selectedPeriod)) { data in
                BarMark(
                    x: .value("Date", data.dateString),
                    y: .value("Words", data.wordCount)
                )
                .foregroundStyle(Color.textSecondary.opacity(0.3))
                .cornerRadius(8)
            }
        }
        .chartXAxis {
            if selectedPeriod == .year {
                // For year (monthly view), show months
                AxisMarks(values: .automatic) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(Color.border.opacity(0.2))
                    AxisValueLabel()
                        .font(Typography.captionSmall)
                        .foregroundStyle(Color.textMuted)
                }
            } else if selectedPeriod == .month {
                // For month view, show every 7 days
                AxisMarks(values: .stride(by: .day, count: 7)) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(Color.border.opacity(0.2))
                    AxisValueLabel()
                        .font(Typography.captionSmall)
                        .foregroundStyle(Color.textMuted)
                }
            } else {
                // For week view, show all days
                AxisMarks { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(Color.border.opacity(0.2))
                    AxisValueLabel()
                        .font(Typography.captionSmall)
                        .foregroundStyle(Color.textMuted)
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 5)) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(Color.border.opacity(0.2))
                AxisValueLabel()
                    .font(Typography.captionSmall)
                    .foregroundStyle(Color.textMuted)
            }
        }
        .chartPlotStyle { plotArea in
            plotArea.background(Color.clear)
        }
        .frame(height: 280)
        .padding(.top, 8)
    }
    
    private var detailsSection: some View {
        HStack(spacing: 16) {
            DetailCard(
                icon: "number",
                label: "Avg. words per note",
                value: "\(averageWordsPerTranscription(for: selectedPeriod))"
            )
            
            DetailCard(
                icon: "star.fill",
                label: "Most active day",
                value: mostActiveDay(for: selectedPeriod)
            )
            
            DetailCard(
                icon: "clock",
                label: "Total duration",
                value: formattedDuration(for: selectedPeriod)
            )
        }
    }
    
    // MARK: - Data Calculations
    
    private func dailyData(for period: StatisticsPeriod) -> [DailyWordCount] {
        let calendar = Calendar.current
        let now = Date()
        
        switch period {
        case .week:
            let startDate = calendar.date(byAdding: .day, value: -6, to: now)!
            return generateDailyData(from: startDate, to: now)
            
        case .month:
            let startDate = calendar.date(byAdding: .day, value: -29, to: now)!
            return generateDailyData(from: startDate, to: now)
            
        case .year:
            // For Year view, we aggregate by Month
            let startDate = calendar.date(byAdding: .day, value: -364, to: now)!
            return generateMonthlyData(from: startDate, to: now)
        }
    }
    
    private func generateDailyData(from startDate: Date, to endDate: Date) -> [DailyWordCount] {
        let calendar = Calendar.current
        var dailyCounts: [Date: Int] = [:]
        
        for item in historyService.items {
            guard item.date >= startDate else { continue }
            let day = calendar.startOfDay(for: item.date)
            let wordCount = item.transcript.components(separatedBy: .whitespacesAndNewlines)
                .filter { !$0.isEmpty }.count
            dailyCounts[day, default: 0] += wordCount
        }
        
        var result: [DailyWordCount] = []
        var currentDate = calendar.startOfDay(for: startDate)
        let end = calendar.startOfDay(for: endDate)
        
        while currentDate <= end {
            let count = dailyCounts[currentDate] ?? 0
            result.append(DailyWordCount(date: currentDate, wordCount: count, isMonthly: false))
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
        }
        return result
    }
    
    private func generateMonthlyData(from startDate: Date, to endDate: Date) -> [DailyWordCount] {
        let calendar = Calendar.current
        var monthlyCounts: [String: Int] = [:] // Key: "yyyy-MM"
        
        // Group items by month
        for item in historyService.items {
            guard item.date >= startDate else { continue }
            
            let components = calendar.dateComponents([.year, .month], from: item.date)
            let key = "\(components.year!)-\(components.month!)"
            
            let wordCount = item.transcript.components(separatedBy: .whitespacesAndNewlines)
                .filter { !$0.isEmpty }.count
            
            monthlyCounts[key, default: 0] += wordCount
        }
        
        // Generate last 12 months buckets
        var result: [DailyWordCount] = []
        var currentDate = calendar.date(from: calendar.dateComponents([.year, .month], from: startDate))!
        let end = calendar.date(from: calendar.dateComponents([.year, .month], from: endDate))!
        
        while currentDate <= end {
            let components = calendar.dateComponents([.year, .month], from: currentDate)
            let key = "\(components.year!)-\(components.month!)"
            let count = monthlyCounts[key] ?? 0
            
            result.append(DailyWordCount(date: currentDate, wordCount: count, isMonthly: true))
            
            currentDate = calendar.date(byAdding: .month, value: 1, to: currentDate)!
        }
        
        return result
    }
    
    private func totalWords(for period: StatisticsPeriod) -> Int {
        dailyData(for: period).reduce(0) { $0 + $1.wordCount }
    }
    
    private func dailyAverage(for period: StatisticsPeriod) -> Int {
        let data = dailyData(for: period)
        guard !data.isEmpty else { return 0 }
        return totalWords(for: period) / data.count
    }
    
    private func bestDay(for period: StatisticsPeriod) -> Int {
        dailyData(for: period).map(\.wordCount).max() ?? 0
    }
    
    private func transcriptionCount(for period: StatisticsPeriod) -> Int {
        let calendar = Calendar.current
        let now = Date()
        let startDate: Date
        
        switch period {
        case .week:
            startDate = calendar.date(byAdding: .day, value: -6, to: now)!
        case .month:
            startDate = calendar.date(byAdding: .day, value: -29, to: now)!
        case .year:
            startDate = calendar.date(byAdding: .day, value: -364, to: now)!
        }
        
        return historyService.items.filter { $0.date >= startDate }.count
    }
    
    private func formattedDuration(for period: StatisticsPeriod) -> String {
        let calendar = Calendar.current
        let now = Date()
        let startDate: Date
        
        switch period {
        case .week:
            startDate = calendar.date(byAdding: .day, value: -6, to: now)!
        case .month:
            startDate = calendar.date(byAdding: .day, value: -29, to: now)!
        case .year:
            startDate = calendar.date(byAdding: .day, value: -364, to: now)!
        }
        
        var totalSeconds = historyService.items
            .filter { $0.date >= startDate }
            .reduce(0.0) { $0 + $1.duration }
            
        // Add current recording duration if active
        if audioRecorder.isRecording, let recordingStart = audioRecorder.recordingStartTime {
            let currentDuration = timeTrigger.timeIntervalSince(recordingStart)
            // Only add if start date falls within period (usually true for 'now')
            if recordingStart >= startDate {
                totalSeconds += currentDuration
            }
        }
        
        // Formatting Logic
        if totalSeconds < 60 {
             return "\(Int(totalSeconds))s"
        }
        
        let minutes = Int(totalSeconds) / 60
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        
        if hours > 0 {
            return "\(hours)h \(remainingMinutes)m"
        } else {
            return "\(remainingMinutes)m"
        }
    }
    
    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            timeTrigger = Date()
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func averageWordsPerTranscription(for period: StatisticsPeriod) -> Int {
        let count = transcriptionCount(for: period)
        guard count > 0 else { return 0 }
        return totalWords(for: period) / count
    }
    
    private func mostActiveDay(for period: StatisticsPeriod) -> String {
        let data = dailyData(for: period)
        guard let maxData = data.max(by: { $0.wordCount < $1.wordCount }),
              maxData.wordCount > 0 else {
            return "N/A"
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: maxData.date)
    }
}

// MARK: - Supporting Types

enum StatisticsPeriod: String, CaseIterable, Identifiable {
    case week = "Week"
    case month = "Month"
    case year = "Year"
    
    var id: String { rawValue }
}

struct DailyWordCount: Identifiable {
    let id = UUID()
    let date: Date
    let wordCount: Int
    let isMonthly: Bool
    
    var dateString: String {
        let formatter = DateFormatter()
        if isMonthly {
            formatter.dateFormat = "MMM"
        } else {
            formatter.dateFormat = "MMM d"
        }
        return formatter.string(from: date)
    }
}

// MARK: - Supporting Views

struct StatCard: View {
    let icon: String
    let label: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(Color.textMuted)
            
            Text(value)
                .font(.system(size: 32, weight: .light, design: .serif))
                .foregroundStyle(Color.textPrimary)
            
            Text(label)
                .font(Typography.captionSmall)
                .foregroundStyle(Color.textSecondary)
                .textCase(.uppercase)
                .tracking(0.5)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.border.opacity(0.5), lineWidth: 1)
        )
    }
}

struct DetailCard: View {
    let icon: String
    let label: String
    let value: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(Color.textMuted)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(Typography.captionSmall)
                    .foregroundStyle(Color.textSecondary)
                Text(value)
                    .font(Typography.labelMedium)
                    .foregroundStyle(Color.textPrimary)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.border.opacity(0.5), lineWidth: 1)
        )
    }
}

struct PeriodButton: View {
    let period: StatisticsPeriod
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(period.rawValue)
                .font(Typography.labelMedium)
                .foregroundStyle(isSelected ? Color.textPrimary : Color.textMuted)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(isSelected ? Color.bgHover : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    StatisticsView()
}

