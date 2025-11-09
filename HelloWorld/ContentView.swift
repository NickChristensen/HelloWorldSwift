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
private let lineWidth: CGFloat = 5

struct EnergyChartView: View {
    let todayHourlyData: [HourlyEnergyData]
    let averageHourlyData: [HourlyEnergyData]
    let moveGoal: Double
    let projectedTotal: Double

    private var calendar: Calendar { Calendar.current }
    private var currentHour: Int { calendar.component(.hour, from: Date()) }
    // Start of current hour (e.g., if it's 2:30 PM, this is 2:00 PM)
    private var startOfCurrentHour: Date {
        let now = Date()
        return calendar.dateInterval(of: .hour, for: now)!.start
    }

    // Check if current hour label would overlap with start/end labels
    private func labelCollisions(chartWidth: CGFloat) -> (hidesStart: Bool, hidesEnd: Bool) {
        let startOfDay = calendar.startOfDay(for: Date())
        let currentHourOffset = startOfCurrentHour.timeIntervalSince(startOfDay)
        let dayDuration = TimeInterval(24 * 60 * 60)
        let currentHourPosition = chartWidth * (currentHourOffset / dayDuration)

        // Estimate label widths and minimum spacing
        let labelWidth: CGFloat = 40
        let minSeparation: CGFloat = 8

        // Calculate boundaries for current hour label
        let currentHourLeft = currentHourPosition - labelWidth / 2
        let currentHourRight = currentHourPosition + labelWidth / 2

        // Check collision with start label (left edge + label width)
        let startLabelRight = labelWidth
        let hidesStart = currentHourLeft < (startLabelRight + minSeparation)

        // Check collision with end label (right edge - label width)
        let endLabelLeft = chartWidth - labelWidth
        let hidesEnd = currentHourRight > (endLabelLeft - minSeparation)

        return (hidesStart, hidesEnd)
    }

    @ChartContentBuilder
    private var averageLines: some ChartContent {
        // Average data - up to current hour (darker gray)
        ForEach(averageHourlyData.filter { $0.hour <= startOfCurrentHour }) { data in
            LineMark(x: .value("Hour", data.hour), y: .value("Calories", data.calories), series: .value("Series", "AverageUpToNow"))
                .foregroundStyle(Color(.systemGray4))
                .lineStyle(StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
        }
        // Average data - rest of day (lighter gray)
        ForEach(averageHourlyData.filter { $0.hour > startOfCurrentHour }) { data in
            LineMark(x: .value("Hour", data.hour), y: .value("Calories", data.calories), series: .value("Series", "AverageRestOfDay"))
                .foregroundStyle(Color(.systemGray6))
                .lineStyle(StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
        }
    }

    @ChartContentBuilder
    private var todayLine: some ChartContent {
        ForEach(todayHourlyData) { data in
            LineMark(x: .value("Hour", data.hour), y: .value("Calories", data.calories), series: .value("Series", "Today"))
                .foregroundStyle(activeEnergyColor)
                .lineStyle(StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
        }
    }

    @ChartContentBuilder
    private var averagePoint: some ChartContent {
        if let avg = averageHourlyData.first(where: { $0.hour == startOfCurrentHour }) {
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
                .foregroundStyle(goalColor)
                .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))
        }
    }

    @ChartContentBuilder
    private var nowLine: some ChartContent {
        RuleMark(x: .value("Now", startOfCurrentHour))
            .foregroundStyle(Color(.systemGray5))
            .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
    }

    var body: some View {
        Chart {
            nowLine
            averageLines
            averagePoint
            todayLine
            todayPoint
            goalLine
        }
        .frame(height: 300)
        .chartXScale(domain: Calendar.current.startOfDay(for: Date())...Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: Date()))!)
        .chartYScale(domain: 0...max(
            todayHourlyData.last?.calories ?? 0,
            averageHourlyData.last?.calories ?? 0,
            moveGoal,
            projectedTotal
        ))
        .chartXAxis {
            AxisMarks(values: .stride(by: .hour, count: 1)) { value in
                if let date = value.as(Date.self) {
                    let startOfDay = calendar.startOfDay(for: Date())
                    let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

                    // Check if this is a labeled hour (start of day, current hour, or end of day)
                    let isStartOfDay = abs(date.timeIntervalSince(startOfDay)) < 60
                    let isEndOfDay = abs(date.timeIntervalSince(endOfDay)) < 60
                    let isCurrentHour = abs(date.timeIntervalSince(startOfCurrentHour)) < 60
                    let isLabeledHour = isStartOfDay || isEndOfDay || isCurrentHour

                    if isLabeledHour {
                        // Labeled hours: tick line
                        AxisTick(centered: true, length: 6, stroke: StrokeStyle(lineWidth: 2, lineCap: .round))
                            .offset(CGSize(width: 0, height: 8))
                    } else {
                        // Unlabeled hours: dot
                        AxisTick(centered: true, length: 0, stroke: StrokeStyle(lineWidth: 2, lineCap: .round))
                            .offset(CGSize(width: 0, height: 11))
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks {}
        }
        .overlay {
            GeometryReader { geometry in
                let chartHeight = geometry.size.height
                let chartWidth = geometry.size.width
                let maxValue = max(
                    todayHourlyData.last?.calories ?? 0,
                    averageHourlyData.last?.calories ?? 0,
                    moveGoal,
                    projectedTotal
                )

                // Goal label
                if moveGoal > 0 {
                    let goalYPosition = chartHeight * (1 - moveGoal / maxValue)

                    Text("\(Int(moveGoal)) cal")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(goalColor)
                        .offset(x: 0, y: goalYPosition + 4)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }

                // Total label (positioned at right side, below average line end)
                if projectedTotal > 0 {
                    let totalYPosition = chartHeight * (1 - projectedTotal / maxValue)

                    Text("\(Int(projectedTotal)) cal")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .offset(y: totalYPosition + 15)
                        .frame(maxHeight: .infinity, alignment: .top)
                }

                // X-axis labels (positioned below chart)
                VStack {
                    Spacer()
                    ZStack(alignment: .bottom) {
                        let startOfDay = calendar.startOfDay(for: Date())
                        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
                        let collisions = labelCollisions(chartWidth: chartWidth)

                        // Start of day - left aligned (hide if collides with current hour)
                        if !collisions.hidesStart {
                            Text(startOfDay, format: .dateTime.hour())
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        // Current hour - aligned to edge if replacing start/end, otherwise centered
                        Text(startOfCurrentHour, format: .dateTime.hour())
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: collisions.hidesStart ? .leading : (collisions.hidesEnd ? .trailing : .center))
                            .offset(x: (!collisions.hidesStart && !collisions.hidesEnd) ? {
                                // Center at natural position only if not replacing an edge label
                                let startOfDay = calendar.startOfDay(for: Date())
                                let currentHourOffset = startOfCurrentHour.timeIntervalSince(startOfDay)
                                let dayDuration = TimeInterval(24 * 60 * 60)
                                let currentHourPosition = chartWidth * (currentHourOffset / dayDuration)
                                return currentHourPosition - chartWidth / 2
                            }() : 0)

                        // End of day - right aligned (hide if collides with current hour)
                        if !collisions.hidesEnd {
                            Text(endOfDay, format: .dateTime.hour())
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                    }
                    .offset(y: 8) // Match tick offset
                }
                .padding(.bottom, -20) // Position below axis ticks
            }
        }
    }
}

struct ContentView: View {
    @StateObject private var healthKitManager = HealthKitManager()
    @State private var authorizationRequested = false
    @State private var isGeneratingData = false
    @State private var dataGenerated = false

    var body: some View {
        VStack(spacing: 20) {
            if healthKitManager.isAuthorized {
                VStack(spacing: 16) {
                    // Today vs Average vs Total
                    VStack(spacing: 12) {
                        HStack(spacing: 20) {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Circle()
                                        .fill(activeEnergyColor)
                                        .frame(width: 8, height: 8)
                                    Text("Today")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                Text("\(Int(healthKitManager.todayTotal)) cal")
                                    .font(.title2)
                                    .fontWeight(.bold)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Circle()
                                        .fill(.gray)
                                        .frame(width: 8, height: 8)
                                    Text("Average")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                Text("\(Int(healthKitManager.averageAtCurrentHour)) cal")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.secondary)
                            }
                        }

                    }

                    // Energy Trend Chart
                    EnergyChartView(
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

            // Sample data generation button (for development/testing)
            // Only show in simulator, not on real devices
            #if targetEnvironment(simulator)
            if healthKitManager.isAuthorized {
                Divider()
                    .padding(.vertical)

                VStack(spacing: 12) {
                    Text("Development Tools")
                        .font(.headline)
                        .foregroundStyle(.secondary)

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
                }
            }
            #endif
        }
        .padding()
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
