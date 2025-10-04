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
                Text("✓ HealthKit Authorized")
                    .foregroundStyle(.green)
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
            } catch {
                print("HealthKit authorization failed: \(error)")
            }
        }
    }
}

#Preview {
    ContentView()
}
