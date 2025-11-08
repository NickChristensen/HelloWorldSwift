//
//  ContentView.swift
//  HelloWorld
//
//  Created by Nick Christensen on 2025-10-04.
//

import SwiftUI
import Charts

struct EnergyChartView: View {
    let todayHourlyData: [HourlyEnergyData]
    let averageHourlyData: [HourlyEnergyData]
    let moveGoal: Double
    let projectedTotal: Double

    private let lineWidth: CGFloat = 4

    private var calendar: Calendar { Calendar.current }
    private var currentHour: Int { calendar.component(.hour, from: Date()) }

    @ChartContentBuilder
    private var averageLines: some ChartContent {
        // Average data - up to current hour (darker gray)
        ForEach(averageHourlyData.filter { calendar.component(.hour, from: $0.hour) <= currentHour }) { data in
            LineMark(x: .value("Hour", data.hour), y: .value("Calories", data.calories), series: .value("Series", "AverageUpToNow"))
                .foregroundStyle(.gray)
                .lineStyle(StrokeStyle(lineWidth: lineWidth))
        }
        // Average data - rest of day (lighter gray)
        ForEach(averageHourlyData.filter { calendar.component(.hour, from: $0.hour) >= currentHour }) { data in
            LineMark(x: .value("Hour", data.hour), y: .value("Calories", data.calories), series: .value("Series", "AverageRestOfDay"))
                .foregroundStyle(.gray.opacity(0.5))
                .lineStyle(StrokeStyle(lineWidth: lineWidth))
        }
    }

    @ChartContentBuilder
    private var averagePoint: some ChartContent {
        if let avg = averageHourlyData.first(where: { calendar.component(.hour, from: $0.hour) == currentHour }) {
            PointMark(x: .value("Hour", avg.hour), y: .value("Calories", avg.calories)).foregroundStyle(.gray).symbolSize(100)
            PointMark(x: .value("Hour", avg.hour), y: .value("Calories", avg.calories)).foregroundStyle(.background).symbolSize(60)
            PointMark(x: .value("Hour", avg.hour), y: .value("Calories", avg.calories)).foregroundStyle(.gray).symbolSize(50)
        }
    }

    @ChartContentBuilder
    private var todayLine: some ChartContent {
        ForEach(todayHourlyData) { data in
            LineMark(x: .value("Hour", data.hour), y: .value("Calories", data.calories), series: .value("Series", "Today"))
                .foregroundStyle(.orange)
                .lineStyle(StrokeStyle(lineWidth: lineWidth))
        }
    }

    @ChartContentBuilder
    private var todayPoint: some ChartContent {
        if let last = todayHourlyData.last {
            PointMark(x: .value("Hour", last.hour), y: .value("Calories", last.calories)).foregroundStyle(.orange).symbolSize(100)
            PointMark(x: .value("Hour", last.hour), y: .value("Calories", last.calories)).foregroundStyle(.background).symbolSize(60)
            PointMark(x: .value("Hour", last.hour), y: .value("Calories", last.calories)).foregroundStyle(.orange).symbolSize(50)
        }
    }

    @ChartContentBuilder
    private var goalLine: some ChartContent {
        if moveGoal > 0 {
            RuleMark(y: .value("Goal", moveGoal))
                .foregroundStyle(.pink)
                .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))
        }
    }

    @ChartContentBuilder
    private var totalBar: some ChartContent {
        if projectedTotal > 0 {
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: Date()))!
            RectangleMark(x: .value("End", endOfDay), yStart: .value("Min", 0), yEnd: .value("Total", projectedTotal), width: .fixed(lineWidth))
                .foregroundStyle(.green)
                .cornerRadius(lineWidth / 2)
        }
    }

    var body: some View {
        Chart {
            averageLines
            averagePoint
            todayLine
            todayPoint
            goalLine
            totalBar
        }
        .frame(height: 400)
        .chartXScale(domain: Calendar.current.startOfDay(for: Date())...Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: Date()))!)
        .chartYScale(domain: 0...max(
            todayHourlyData.last?.calories ?? 0,
            averageHourlyData.last?.calories ?? 0,
            moveGoal,
            projectedTotal
        ))
        .chartXAxis {
            AxisMarks(values: .stride(by: .hour, count: 6)) { value in
                AxisGridLine()
                AxisTick()
                AxisValueLabel(format: .dateTime.hour())
            }
        }
        .chartYAxis {
            AxisMarks { value in
                AxisGridLine()
            }
        }
        .overlay {
            if moveGoal > 0 {
                GeometryReader { geometry in
                    let chartHeight = geometry.size.height
                    let maxValue = max(
                        todayHourlyData.last?.calories ?? 0,
                        averageHourlyData.last?.calories ?? 0,
                        moveGoal,
                        projectedTotal
                    )
                    let goalYPosition = chartHeight * (1 - moveGoal / maxValue)

                    Text("\(Int(moveGoal)) cal")
                        .font(.caption)
                        .foregroundStyle(.pink)
                        .offset(x: 0, y: goalYPosition + 0)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
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
                                        .fill(.orange)
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

                        HStack(spacing: 20) {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Circle()
                                        .fill(.green)
                                        .frame(width: 8, height: 8)
                                    Text("Total")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                Text("\(Int(healthKitManager.projectedTotal)) cal")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.secondary)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Circle()
                                        .fill(.pink)
                                        .frame(width: 8, height: 8)
                                    Text("Goal")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                Text("\(Int(healthKitManager.moveGoal)) cal")
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
