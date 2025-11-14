//
//  ContentView.swift
//  HelloWorld
//
//  Created by Nick Christensen on 2025-10-04.
//

import SwiftUI
import Charts


private let activeEnergyColor: Color = Color(red: 254/255, green: 73/255, blue: 1/255)
private let goalColor: Color = Color(.systemGray)
private let lineWidth: CGFloat = 4

/// Debug: Override current time for testing. Set to nil to use real time.
/// Examples:
/// - Calendar.current.date(from: DateComponents(hour: 2, minute: 10))  // 2:10 AM
/// - Calendar.current.date(from: DateComponents(hour: 4, minute: 30))  // 4:30 AM
/// - Calendar.current.date(from: DateComponents(hour: 13, minute: 40)) // 1:40 PM
private let debugNowOverride: Date? = nil

/// Helper to get current time (or debug override)
private func getCurrentTime() -> Date {
    if let override = debugNowOverride {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let components = calendar.dateComponents([.hour, .minute], from: override)
        return calendar.date(byAdding: components, to: today) ?? Date()
    }
    return Date()
}

/// Helper to determine if NOW label collides with start/end of day labels
private func calculateLabelCollisions(chartWidth: CGFloat, now: Date) -> (hidesStart: Bool, hidesEnd: Bool) {
    let calendar = Calendar.current
    let startOfDay = calendar.startOfDay(for: now)
    let nowOffset = now.timeIntervalSince(startOfDay)
    let dayDuration = TimeInterval(24 * 60 * 60)
    let nowPosition = chartWidth * (nowOffset / dayDuration)

    let nowLabelWidth: CGFloat = 50  // "6:10 AM" with minutes
    let startEndLabelWidth: CGFloat = 35  // "12 AM" without minutes
    let minSeparation: CGFloat = 4

    let nowLeft = nowPosition - nowLabelWidth / 2
    let nowRight = nowPosition + nowLabelWidth / 2

    let startLabelRight = startEndLabelWidth
    let hidesStart = nowLeft < (startLabelRight + minSeparation)

    let endLabelLeft = chartWidth - startEndLabelWidth
    let hidesEnd = nowRight > (endLabelLeft - minSeparation)

    return (hidesStart, hidesEnd)
}

/// X-axis labels component (start of day, current hour, end of day)
private struct ChartXAxisLabels: View {
    let chartWidth: CGFloat

    private var calendar: Calendar { Calendar.current }
    private var now: Date { getCurrentTime() }

    var body: some View {
        ZStack(alignment: .bottom) {
            let startOfDay = calendar.startOfDay(for: Date())
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
            let collisions = calculateLabelCollisions(chartWidth: chartWidth, now: now)

            // Start of day - left aligned (hide if collides with current hour)
            if !collisions.hidesStart {
                Text(startOfDay, format: .dateTime.hour())
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            // NOW - centered at natural position, but edge-aligned if that would go out of bounds
            Text(now, format: .dateTime.hour().minute())
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: {
                    let startOfDay = calendar.startOfDay(for: now)
                    let nowOffset = now.timeIntervalSince(startOfDay)
                    let dayDuration = TimeInterval(24 * 60 * 60)
                    let nowPosition = chartWidth * (nowOffset / dayDuration)
                    let nowLabelWidth: CGFloat = 50

                    // Check if centering would put label out of bounds
                    let centeredLeft = nowPosition - nowLabelWidth / 2
                    let centeredRight = nowPosition + nowLabelWidth / 2

                    if centeredLeft < 0 {
                        return .leading  // Too close to left edge
                    } else if centeredRight > chartWidth {
                        return .trailing  // Too close to right edge
                    } else {
                        return .center  // Safe to center
                    }
                }())
                .offset(x: {
                    let startOfDay = calendar.startOfDay(for: now)
                    let nowOffset = now.timeIntervalSince(startOfDay)
                    let dayDuration = TimeInterval(24 * 60 * 60)
                    let nowPosition = chartWidth * (nowOffset / dayDuration)
                    let nowLabelWidth: CGFloat = 50

                    // Check if centering would put label out of bounds
                    let centeredLeft = nowPosition - nowLabelWidth / 2
                    let centeredRight = nowPosition + nowLabelWidth / 2

                    if centeredLeft < 0 || centeredRight > chartWidth {
                        return 0  // Edge-aligned, no offset needed
                    } else {
                        return nowPosition - chartWidth / 2  // Centered with offset
                    }
                }())

            // End of day - right aligned (hide if collides with current hour)
            if !collisions.hidesEnd {
                Text(endOfDay, format: .dateTime.hour())
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .frame(height: 20, alignment: .bottom) // Fixed height for labels
    }
}

struct EnergyChartView: View {
    let todayHourlyData: [HourlyEnergyData]
    let averageHourlyData: [HourlyEnergyData]
    let moveGoal: Double
    let projectedTotal: Double

    // Chart layout constants

    private var calendar: Calendar { Calendar.current }
    private var now: Date { getCurrentTime() }
    private var currentHour: Int { calendar.component(.hour, from: now) }
    private var startOfCurrentHour: Date {
        calendar.dateInterval(of: .hour, for: now)!.start
    }

    /// Renders an hourly tick mark with appropriate styling
    /// Returns nothing if the hour is too close to NOW (within 20 minutes)
    @AxisMarkBuilder
    private func hourlyTickMark(for date: Date, startOfDay: Date, endOfDay: Date, collisions: (hidesStart: Bool, hidesEnd: Bool), now: Date) -> some AxisMark {
        let minutesFromNow = abs(date.timeIntervalSince(now)) / 60
        if minutesFromNow >= 20 {
            let isStartOfDay = abs(date.timeIntervalSince(startOfDay)) < 60
            let isEndOfDay = abs(date.timeIntervalSince(endOfDay)) < 60
            let showTickLine = (isStartOfDay && !collisions.hidesStart) || (isEndOfDay && !collisions.hidesEnd)

            if showTickLine {
                // Visible labeled hours: tick line
                AxisTick(centered: true, length: 6, stroke: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .offset(CGSize(width: 0, height: 8))
            } else {
                // Unlabeled hours or hidden labels: dot
                AxisTick(centered: true, length: 0, stroke: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .offset(CGSize(width: 0, height: 11))
            }
        }
    }

    // Calculate max value for chart Y-axis
    private func chartMaxValue(chartHeight: CGFloat) -> Double {
        return max(
            todayHourlyData.last?.calories ?? 0,
            averageHourlyData.last?.calories ?? 0,
            moveGoal,
            projectedTotal
        )
    }


    @ChartContentBuilder
    private var averageLines: some ChartContent {
        // Average data - up to NOW (darker gray)
        ForEach(averageHourlyData.filter { $0.hour <= now }) { data in
            LineMark(x: .value("Hour", data.hour), y: .value("Calories", data.calories), series: .value("Series", "AverageUpToNow"))
                .foregroundStyle(Color(.systemGray4))
                .lineStyle(StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
        }
        // Average data - rest of day (lighter gray)
        ForEach(averageHourlyData.filter { $0.hour >= now }) { data in
            LineMark(x: .value("Hour", data.hour), y: .value("Calories", data.calories), series: .value("Series", "AverageRestOfDay"))
                .foregroundStyle(Color(.systemGray6))
                .lineStyle(StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
        }
    }

    @ChartContentBuilder
    private var todayLine: some ChartContent {
        // Single continuous line including current hour progress
        ForEach(todayHourlyData) { data in
            LineMark(x: .value("Hour", data.hour), y: .value("Calories", data.calories), series: .value("Series", "Today"))
                .foregroundStyle(activeEnergyColor)
                .lineStyle(StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
        }
    }

    @ChartContentBuilder
    private var averagePoint: some ChartContent {
        // Show average point at NOW (interpolated value)
        if let avg = averageHourlyData.last(where: { abs($0.hour.timeIntervalSince(now)) < 60 }) {
            PointMark(x: .value("Hour", avg.hour), y: .value("Calories", avg.calories)).foregroundStyle(.background).symbolSize(256)
            PointMark(x: .value("Hour", avg.hour), y: .value("Calories", avg.calories)).foregroundStyle(Color(.systemGray4)).symbolSize(100)
        }
    }

    @ChartContentBuilder
    private var todayPoint: some ChartContent {
        if let last = todayHourlyData.last {
            PointMark(x: .value("Hour", last.hour), y: .value("Calories", last.calories)).foregroundStyle(.background).symbolSize(256)
            PointMark(x: .value("Hour", last.hour), y: .value("Calories", last.calories)).foregroundStyle(activeEnergyColor).symbolSize(100)
        }
    }

    @ChartContentBuilder
    private var goalLine: some ChartContent {
        if moveGoal > 0 {
            RuleMark(y: .value("Goal", moveGoal))
                .foregroundStyle(goalColor.opacity(0.5))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
        }
    }

    @ChartContentBuilder
    private var nowLine: some ChartContent {
        RuleMark(x: .value("Now", now))
            .foregroundStyle(Color(.systemGray5))
            .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
    }

    var body: some View {
        GeometryReader { geometry in
            let chartWidth = geometry.size.width
            let chartHeight = geometry.size.height
            let maxValue = chartMaxValue(chartHeight: chartHeight)

            VStack(spacing: 0) {
                // Chart with flexible height
                Chart {
                    nowLine
                    averageLines
                    averagePoint
                    todayLine
                    todayPoint
                    goalLine
                }
                .frame(maxHeight: .infinity)
                .chartXScale(domain: Calendar.current.startOfDay(for: Date())...Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: Date()))!)
                .chartYScale(domain: 0...maxValue)
                .chartXAxis {
                    // Calculate constants once (not 24 times per render!)
                    let startOfDay = calendar.startOfDay(for: Date())
                    let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
                    let collisions = calculateLabelCollisions(chartWidth: chartWidth, now: now)

                    // Hourly tick marks
                    AxisMarks(values: .stride(by: .hour, count: 1)) { value in
                        if let date = value.as(Date.self) {
                            hourlyTickMark(for: date, startOfDay: startOfDay, endOfDay: endOfDay, collisions: collisions, now: now)
                        }
                    }

                    // NOW tick mark (matches labeled hour styling)
                    AxisMarks(values: [now]) { _ in
                        AxisTick(centered: true, length: 6, stroke: StrokeStyle(lineWidth: 2, lineCap: .round))
                            .offset(CGSize(width: 0, height: 8))
                    }
                }
                .chartYAxis {
                    AxisMarks {}
                }
                .overlay {
                    // Goal label
                    if moveGoal > 0 {
                        let goalYPosition = chartHeight * (1 - moveGoal / maxValue)

                        Text("\(Int(moveGoal)) cal")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(goalColor)
                            .padding(2)
                            .background(.background.opacity(0.5))
                            .cornerRadius(4)
                            .offset(
                                x: -2 /* padding */,
                                y: goalYPosition
                            )
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    }
                }

                // X-axis labels below chart (fixed height)
                ChartXAxisLabels(chartWidth: chartWidth)
                    .padding(.top, 8)
            }
        }
    }
}

/// Single statistic display with colored indicator and value
struct HeaderStatistic: View {
    let label: String
    let statistic: Double
    let color: Color
    let circleColor: Color

    init(label: String, statistic: Double, color: Color, circleColor: Color? = nil) {
        self.label = label
        self.statistic = statistic
        self.color = color
        self.circleColor = circleColor ?? color
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 4) {
                Circle()
                    .fill(circleColor)
                    .frame(width: 10, height: 10)
                Text(label)
                    .font(.caption)
                    .fontDesign(.rounded)
                    .foregroundStyle(color)
            }
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(Int(statistic), format: .number)
                    .font(.title2)
                    .fontDesign(.rounded)
                    .fontWeight(.bold)
                    .foregroundStyle(color)
                Text("cal")
                    .font(.caption)
                    .fontDesign(.rounded)
                    .fontWeight(.bold)
                    .foregroundStyle(color)
            }
        }
    }
}

/// Reusable view combining statistics header and energy chart
/// Can be used in both main app and widgets
/// Uses flexible height layout to adapt to container size
struct EnergyTrendView: View {
    let todayTotal: Double
    let averageAtCurrentHour: Double
    let todayHourlyData: [HourlyEnergyData]
    let averageHourlyData: [HourlyEnergyData]
    let moveGoal: Double
    let projectedTotal: Double

    var body: some View {
        GeometryReader { geometry in
            let spacing = geometry.size.height > 300 ? 16.0 : 8.0

            VStack(spacing: spacing) {
                // Header with statistics (fixed height)
                HStack(spacing: 0) {
                    HeaderStatistic(label: "Today", statistic: todayTotal, color: activeEnergyColor)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    HeaderStatistic(label: "Average", statistic: averageAtCurrentHour, color: Color(.systemGray))
                        .frame(maxWidth: .infinity, alignment: .center)

                    HeaderStatistic(label: "Total", statistic: projectedTotal, color: Color(.systemGray2), circleColor: Color(.systemGray4))
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .fixedSize(horizontal: false, vertical: true)

                // Energy Trend Chart (flexible height - takes remaining space)
                EnergyChartView(
                    todayHourlyData: todayHourlyData,
                    averageHourlyData: averageHourlyData,
                    moveGoal: moveGoal,
                    projectedTotal: projectedTotal
                )
                .frame(maxHeight: .infinity)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, spacing)
        }
    }
}

#if targetEnvironment(simulator)
/// Development tools sheet content (simulator only)
struct DevelopmentToolsSheet: View {
    @ObservedObject var healthKitManager: HealthKitManager
    @State private var isGeneratingData = false
    @State private var dataGenerated = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Button(action: {
                    Task {
                        isGeneratingData = true
                        do {
                            try await healthKitManager.generateSampleData()
                            // Refresh data after generating
                            try await healthKitManager.fetchEnergyData()
                            try await healthKitManager.fetchMoveGoal()
                            dataGenerated = true
                        } catch {
                            print("Failed to generate sample data: \(error)")
                        }
                        isGeneratingData = false
                    }
                }) {
                    HStack {
                        if isGeneratingData {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .padding(.trailing, 4)
                        }
                        Text(isGeneratingData ? "Generating..." : "Generate Sample Data")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundStyle(.white)
                    .cornerRadius(10)
                }
                .disabled(isGeneratingData)

                if dataGenerated {
                    Text("✓ Sample data added to Health app")
                        .font(.caption)
                        .foregroundStyle(.green)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Development Tools")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
#endif

struct ContentView: View {
    @StateObject private var healthKitManager = HealthKitManager()
    @State private var authorizationRequested = false
    #if targetEnvironment(simulator)
    @State private var showingDevTools = false
    #endif

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                if healthKitManager.isAuthorized {
                    // Medium Widget Preview
                    WidgetPreviewContainer(family: .systemMedium, label: "Medium Widget") {
                        EnergyTrendView(
                            todayTotal: healthKitManager.todayTotal,
                            averageAtCurrentHour: healthKitManager.averageAtCurrentHour,
                            todayHourlyData: healthKitManager.todayHourlyData,
                            averageHourlyData: healthKitManager.averageHourlyData,
                            moveGoal: healthKitManager.moveGoal,
                            projectedTotal: healthKitManager.projectedTotal
                        )
                    }

                    // Large Widget Preview
                    WidgetPreviewContainer(family: .systemLarge, label: "Large Widget") {
                        EnergyTrendView(
                            todayTotal: healthKitManager.todayTotal,
                            averageAtCurrentHour: healthKitManager.averageAtCurrentHour,
                            todayHourlyData: healthKitManager.todayHourlyData,
                            averageHourlyData: healthKitManager.averageHourlyData,
                            moveGoal: healthKitManager.moveGoal,
                            projectedTotal: healthKitManager.projectedTotal
                        )
                    }
                } else if authorizationRequested {
                    Text("⚠️ Waiting for authorization...")
                        .foregroundStyle(.orange)
                } else {
                    Text("Needs HealthKit access")
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
        }
        #if targetEnvironment(simulator)
        .onShake {
            showingDevTools = true
        }
        .sheet(isPresented: $showingDevTools) {
            DevelopmentToolsSheet(healthKitManager: healthKitManager)
        }
        #endif
        .task {
            // Request HealthKit authorization when view appears
            guard !authorizationRequested else { return }
            authorizationRequested = true

            do {
                try await healthKitManager.requestAuthorization()

                // Fetch data after authorization
                try await healthKitManager.fetchEnergyData()
                try await healthKitManager.fetchMoveGoal()
            } catch {
                print("HealthKit error: \(error)")
            }
        }
    }
}

#Preview {
    ContentView()
}
