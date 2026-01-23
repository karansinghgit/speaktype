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
            VStack(alignment: .leading, spacing: 30) {
                headerSection
                periodSelector
                summaryCards
                barChartSection
                detailsSection
            }
        }
        .background(Color.clear)
        .onAppear {
            startTimer()
        }
        .onDisappear {
            stopTimer()
        }
        .onChange(of: audioRecorder.isRecording) { isRecording in
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
        VStack(spacing: 12) {
            Image(systemName: "chart.bar.fill")
                .font(.system(size: 36))
                .foregroundStyle(Color.accentPrimary)
            
            Text("Statistics")
                .font(Typography.displayLarge)
                .foregroundStyle(Color.textPrimary)
            
            Text("Track your transcription activity")
                .font(Typography.bodyMedium)
                .foregroundStyle(Color.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 32)
    }
    
    private var periodSelector: some View {
        HStack(spacing: 12) {
            ForEach(StatisticsPeriod.allCases) { period in
                PeriodButton(
                    period: period,
                    isSelected: selectedPeriod == period,
                    action: {
                        withAnimation {
                            selectedPeriod = period
                        }
                    }
                )
            }
        }
        .padding(.horizontal, 40)
    }
    
    private var summaryCards: some View {
        ViewThatFits(in: .horizontal) {
            // Wide Layout
            HStack(spacing: 16) {
                SummaryCard(
                    icon: "doc.text",
                    title: "Total Words",
                    value: "\(totalWords(for: selectedPeriod))",
                    color: Color.chartRed
                )
                
                SummaryCard(
                    icon: "calendar",
                    title: "Daily Average",
                    value: "\(dailyAverage(for: selectedPeriod))",
                    color: Color.chartBlue
                )
                
                SummaryCard(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "Best Day",
                    value: "\(bestDay(for: selectedPeriod))",
                    color: Color.green
                )
            }
            
            // Narrow Layout (Vertical)
            VStack(spacing: 16) {
                SummaryCard(
                    icon: "doc.text",
                    title: "Total Words",
                    value: "\(totalWords(for: selectedPeriod))",
                    color: Color.chartRed
                )
                
                SummaryCard(
                    icon: "calendar",
                    title: "Daily Average",
                    value: "\(dailyAverage(for: selectedPeriod))",
                    color: Color.chartBlue
                )
                
                SummaryCard(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "Best Day",
                    value: "\(bestDay(for: selectedPeriod))",
                    color: Color.green
                )
            }
        }
        .padding(.horizontal, 40)
    }
    
    private var barChartSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Words Transcribed Per Day")
                .font(Typography.headlineMedium)
                .foregroundStyle(Color.textPrimary)
            
            if dailyData(for: selectedPeriod).isEmpty {
                emptyChartView
            } else {
                chartView
            }
        }
        .themedCard(padding: 20)
        .padding(.horizontal, 40)
    }
    
    private var emptyChartView: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 50))
                .foregroundStyle(.gray.opacity(0.5))
            
            Text("No transcriptions yet")
                .font(.headline)
                .foregroundStyle(.gray)
            
            Text("Start recording to see your statistics")
                .font(.subheadline)
                .foregroundStyle(.gray.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .frame(height: 300)
        .background(Color.bgCard)
        .cornerRadius(12)
        .padding(.horizontal, 40)
    }
    
    private var chartView: some View {
        Chart {
            ForEach(dailyData(for: selectedPeriod)) { data in
                BarMark(
                    x: .value("Date", data.dateString),
                    y: .value("Words", data.wordCount)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.chartRed, Color.chartBlue],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                )
                .cornerRadius(6)
            }
        }
        .chartXAxis {
            if selectedPeriod == .year {
                 // For year (monthly view), show months
                AxisMarks(values: .automatic) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(Color.white.opacity(0.1))
                    AxisValueLabel()
                        .font(.caption)
                        .foregroundStyle(.gray)
                }
            } else {
                // For week/month (daily view), stride to avoid overlap
                AxisMarks(values: .stride(by: selectedPeriod == .month ? .day : .day, count: selectedPeriod == .month ? 7 : 1)) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(Color.white.opacity(0.1))
                    AxisValueLabel()
                        .font(.caption)
                        .foregroundStyle(.gray)
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(Color.white.opacity(0.1))
                AxisValueLabel()
                    .font(.caption)
                    .foregroundStyle(.gray)
            }
        }
        .frame(height: 300)
        .padding(.horizontal, 40)
    }
    
    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Details")
                .font(Typography.headlineMedium)
                .foregroundStyle(Color.textPrimary)
            
            ViewThatFits(in: .horizontal) {
                HStack {
                    StatRow(label: "Total Transcriptions", value: "\(transcriptionCount(for: selectedPeriod))")
                    Spacer()
                    StatRow(label: "Total Duration", value: formattedDuration(for: selectedPeriod))
                }
                
                VStack(alignment: .leading, spacing: 16) {
                    StatRow(label: "Total Transcriptions", value: "\(transcriptionCount(for: selectedPeriod))")
                    StatRow(label: "Total Duration", value: formattedDuration(for: selectedPeriod))
                }
            }
            
            Divider()
                .background(Color.border)
            
            ViewThatFits(in: .horizontal) {
                HStack {
                    StatRow(label: "Average Words Per Transcription", value: "\(averageWordsPerTranscription(for: selectedPeriod))")
                    Spacer()
                    StatRow(label: "Most Active Day", value: mostActiveDay(for: selectedPeriod))
                }
                
                VStack(alignment: .leading, spacing: 16) {
                    StatRow(label: "Average Words Per Transcription", value: "\(averageWordsPerTranscription(for: selectedPeriod))")
                    StatRow(label: "Most Active Day", value: mostActiveDay(for: selectedPeriod))
                }
            }
        }
        .themedCard()
        .padding(.horizontal, 40)
        .padding(.bottom, 40)
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

struct SummaryCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)
                Spacer()
            }
            
            Text(value)
                .font(Typography.statValue)
                .foregroundStyle(Color.textPrimary)
            
            Text(title)
                .font(Typography.bodySmall)
                .foregroundStyle(Color.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .themedCard(padding: 20)
    }
}

struct StatRow: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(Typography.labelSmall)
                .foregroundStyle(Color.textSecondary)
            Text(value)
                .font(Typography.headlineSmall)
                .foregroundStyle(Color.textPrimary)
        }
    }
}

struct PeriodButton: View {
    let period: StatisticsPeriod
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(period.rawValue)
                .font(Typography.bodyMedium)
                .fontWeight(isSelected ? .semibold : .medium)
                .foregroundStyle(isSelected ? .white : Color.textSecondary)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isSelected ? Color.accentPrimary : Color.bgCard)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? Color.clear : Color.border, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    StatisticsView()
}

