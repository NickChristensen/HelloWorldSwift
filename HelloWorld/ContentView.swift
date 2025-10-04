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
