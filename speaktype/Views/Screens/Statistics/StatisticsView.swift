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
    @State private var selectedPeriod: StatisticsPeriod = .week
    
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
    }
    
    // MARK: - View Components
    
    private var headerSection: some View {
        VStack(spacing: 15) {
            Image(systemName: "chart.bar.fill")
                .font(.system(size: 40))
                .foregroundStyle(Color.appRed)
            
            Text("Statistics")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundStyle(.white)
            
            Text("Track your transcription activity")
                .foregroundStyle(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
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
        HStack(spacing: 16) {
            SummaryCard(
                icon: "doc.text",
                title: "Total Words",
                value: "\(totalWords(for: selectedPeriod))",
                color: Color(hex: "A62D35")
            )
            
            SummaryCard(
                icon: "calendar",
                title: "Daily Average",
                value: "\(dailyAverage(for: selectedPeriod))",
                color: Color(hex: "2D5DA6")
            )
            
            SummaryCard(
                icon: "chart.line.uptrend.xyaxis",
                title: "Best Day",
                value: "\(bestDay(for: selectedPeriod))",
                color: Color.green
            )
        }
        .padding(.horizontal, 40)
    }
    
    private var barChartSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Words Transcribed Per Day")
                .font(.headline)
                .foregroundStyle(.white)
                .padding(.horizontal, 40)
            
            if dailyData(for: selectedPeriod).isEmpty {
                emptyChartView
            } else {
                chartView
            }
        }
        .padding(.vertical, 20)
        .background(Color.white.opacity(0.03))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
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
        .background(Color.white.opacity(0.05))
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
                        colors: [Color(hex: "A62D35"), Color(hex: "2D5DA6")],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                )
                .cornerRadius(6)
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(Color.white.opacity(0.1))
                AxisValueLabel()
                    .font(.caption)
                    .foregroundStyle(.gray)
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
                .font(.headline)
                .foregroundStyle(.white)
            
            HStack {
                StatRow(label: "Total Transcriptions", value: "\(transcriptionCount(for: selectedPeriod))")
                Spacer()
                StatRow(label: "Total Duration", value: formattedDuration(for: selectedPeriod))
            }
            
            Divider()
                .background(Color.white.opacity(0.1))
            
            HStack {
                StatRow(label: "Average Words Per Transcription", value: "\(averageWordsPerTranscription(for: selectedPeriod))")
                Spacer()
                StatRow(label: "Most Active Day", value: mostActiveDay(for: selectedPeriod))
            }
        }
        .padding(24)
        .background(Color.white.opacity(0.03))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .padding(.horizontal, 40)
        .padding(.bottom, 40)
    }
    
    // MARK: - Data Calculations
    
    private func dailyData(for period: StatisticsPeriod) -> [DailyWordCount] {
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
        
        // Group items by day
        var dailyCounts: [Date: Int] = [:]
        
        for item in historyService.items {
            guard item.date >= startDate else { continue }
            
            let day = calendar.startOfDay(for: item.date)
            let wordCount = item.transcript.components(separatedBy: .whitespacesAndNewlines)
                .filter { !$0.isEmpty }.count
            dailyCounts[day, default: 0] += wordCount
        }
        
        // Create array for all days in period
        var result: [DailyWordCount] = []
        var currentDate = calendar.startOfDay(for: startDate)
        let endDate = calendar.startOfDay(for: now)
        
        while currentDate <= endDate {
            let wordCount = dailyCounts[currentDate] ?? 0
            result.append(DailyWordCount(date: currentDate, wordCount: wordCount))
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
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
        
        let totalSeconds = historyService.items
            .filter { $0.date >= startDate }
            .reduce(0.0) { $0 + $1.duration }
        
        let minutes = Int(totalSeconds) / 60
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        
        if hours > 0 {
            return "\(hours)h \(remainingMinutes)m"
        } else {
            return "\(remainingMinutes)m"
        }
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
    
    var dateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
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
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(.white)
            
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.gray)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}

struct StatRow: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.gray)
            Text(value)
                .font(.headline)
                .foregroundStyle(.white)
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
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .medium)
                .foregroundStyle(isSelected ? .white : .gray)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(buttonBackground)
        }
        .buttonStyle(.plain)
    }
    
    private var buttonBackground: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(isSelected ? 
                  AnyShapeStyle(LinearGradient(
                    colors: [Color(hex: "A62D35"), Color(hex: "2D5DA6")],
                    startPoint: .leading,
                    endPoint: .trailing
                  )) : 
                  AnyShapeStyle(Color.white.opacity(0.05))
            )
    }
}

#Preview {
    StatisticsView()
}

