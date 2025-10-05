//
//  ContentView.swift
//  HelloWorld
//
//  Created by Nick Christensen on 2025-10-04.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var healthKitManager = HealthKitManager()
    @State private var authorizationRequested = false
    @State private var isGeneratingData = false
    @State private var dataGenerated = false

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "heart.fill")
                .imageScale(.large)
                .foregroundStyle(.red)
                .font(.system(size: 60))

            Text("Health Trends")
                .font(.largeTitle)
                .fontWeight(.bold)

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
