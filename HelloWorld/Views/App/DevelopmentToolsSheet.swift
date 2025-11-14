import SwiftUI

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
