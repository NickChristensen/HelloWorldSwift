import Foundation
import HealthKit
import Combine

@MainActor
final class HealthKitManager: ObservableObject {
    private let healthStore = HKHealthStore()

    @Published var isAuthorized = false

    // Check if HealthKit is available on this device
    var isHealthKitAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    // Request authorization to read Active Energy data
    func requestAuthorization() async throws {
        guard isHealthKitAvailable else {
            throw HealthKitError.notAvailable
        }

        // Types we want to read
        let typesToRead: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!
        ]

        try await healthStore.requestAuthorization(toShare: [], read: typesToRead)

        // For read-only permissions, HealthKit doesn't reveal if user granted access (privacy protection)
        // We'll assume authorization completed successfully if no error was thrown
        isAuthorized = true
    }
}

enum HealthKitError: Error {
    case notAvailable
    case authorizationDenied
}
