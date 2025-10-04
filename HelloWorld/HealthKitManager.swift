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

    // Request authorization to read and write Active Energy data
    func requestAuthorization() async throws {
        guard isHealthKitAvailable else {
            throw HealthKitError.notAvailable
        }

        // Types we want to read and write
        let activeEnergyType = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!

        let typesToRead: Set<HKObjectType> = [activeEnergyType]
        let typesToWrite: Set<HKSampleType> = [activeEnergyType]

        try await healthStore.requestAuthorization(toShare: typesToWrite, read: typesToRead)

        // For read-only permissions, HealthKit doesn't reveal if user granted access (privacy protection)
        // We'll assume authorization completed successfully if no error was thrown
        isAuthorized = true
    }

    // Delete all existing Active Energy data
    func clearSampleData() async throws {
        guard isHealthKitAvailable else {
            throw HealthKitError.notAvailable
        }

        let activeEnergyType = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!

        // Delete all samples from our app
        let predicate = HKQuery.predicateForObjects(from: [HKSource.default()])
        try await healthStore.deleteObjects(of: activeEnergyType, predicate: predicate)
    }

    // Generate realistic sample Active Energy data
    func generateSampleData() async throws {
        guard isHealthKitAvailable else {
            throw HealthKitError.notAvailable
        }

        // Clear existing data first to avoid duplicates
        try await clearSampleData()

        let activeEnergyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
        let calendar = Calendar.current
        let now = Date()

        // Generate data for the past 60 days
        var samplesToSave: [HKQuantitySample] = []

        for dayOffset in 0..<60 {
            guard let dayStart = calendar.date(byAdding: .day, value: -dayOffset, to: calendar.startOfDay(for: now)) else {
                continue
            }

            // Generate hourly data points for each day
            for hour in 0..<24 {
                guard let hourStart = calendar.date(byAdding: .hour, value: hour, to: dayStart) else {
                    continue
                }

                // Generate realistic calories per hour
                let baseCalories = generateRealisticCalories(for: hour)
                let calories = baseCalories + Double.random(in: -10...10)

                let quantity = HKQuantity(unit: .kilocalorie(), doubleValue: max(0, calories))
                let sample = HKQuantitySample(
                    type: activeEnergyType,
                    quantity: quantity,
                    start: hourStart,
                    end: calendar.date(byAdding: .hour, value: 1, to: hourStart)!
                )

                samplesToSave.append(sample)
            }
        }

        try await healthStore.save(samplesToSave)
    }

    // Generate realistic calorie burn based on time of day
    private func generateRealisticCalories(for hour: Int) -> Double {
        switch hour {
        case 0..<6:   return Double.random(in: 5...15)     // Sleep/early morning
        case 6..<7:   return Double.random(in: 20...40)    // Wake up
        case 7:       return Double.random(in: 150...250)  // Morning workout
        case 8..<9:   return Double.random(in: 20...40)    // Post-workout
        case 9..<12:  return Double.random(in: 25...50)    // Morning activity
        case 12..<14: return Double.random(in: 30...60)    // Lunch/midday
        case 14..<17: return Double.random(in: 25...55)    // Afternoon
        case 17..<20: return Double.random(in: 35...70)    // Evening activity
        case 20..<22: return Double.random(in: 20...40)    // Evening
        default:      return Double.random(in: 10...20)    // Late night
        }
    }
}

enum HealthKitError: Error {
    case notAvailable
    case authorizationDenied
}
