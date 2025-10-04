import Foundation
import HealthKit
import Combine

// Data model for hourly energy data
struct HourlyEnergyData: Identifiable {
    let id = UUID()
    let hour: Date
    let calories: Double
}

@MainActor
final class HealthKitManager: ObservableObject {
    private let healthStore = HKHealthStore()

    @Published var isAuthorized = false
    @Published var todayTotal: Double = 0
    @Published var averageTotal: Double = 0
    @Published var todayHourlyData: [HourlyEnergyData] = []
    @Published var averageHourlyData: [HourlyEnergyData] = []

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

    // MARK: - Data Fetching

    // Fetch all Active Energy data
    func fetchEnergyData() async throws {
        guard isHealthKitAvailable else {
            throw HealthKitError.notAvailable
        }

        async let todayData = fetchTodayData()
        async let averageData = fetchAverageData()

        let (today, average) = try await (todayData, averageData)

        self.todayTotal = today.total
        self.todayHourlyData = today.hourlyData
        self.averageTotal = average.total
        self.averageHourlyData = average.hourlyData
    }

    // Fetch today's Active Energy data
    private func fetchTodayData() async throws -> (total: Double, hourlyData: [HourlyEnergyData]) {
        let calendar = Calendar.current
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)

        let activeEnergyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!

        // Fetch hourly data
        let hourlyData = try await fetchHourlyData(from: startOfDay, to: now, type: activeEnergyType)

        // Calculate total
        let total = hourlyData.reduce(0) { $0 + $1.calories }

        return (total, hourlyData)
    }

    // Fetch average Active Energy data from past 30 days
    private func fetchAverageData() async throws -> (total: Double, hourlyData: [HourlyEnergyData]) {
        let calendar = Calendar.current
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)

        // Get data from 30 days ago to yesterday
        guard let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: startOfToday),
              let yesterday = calendar.date(byAdding: .day, value: -1, to: startOfToday) else {
            return (0, [])
        }

        let activeEnergyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!

        // Fetch daily totals for past 30 days
        let dailyTotals = try await fetchDailyTotals(from: thirtyDaysAgo, to: yesterday, type: activeEnergyType)

        // Calculate average daily total
        let averageTotal = dailyTotals.isEmpty ? 0 : dailyTotals.reduce(0, +) / Double(dailyTotals.count)

        // Fetch average hourly pattern
        let averageHourlyData = try await fetchAverageHourlyPattern(from: thirtyDaysAgo, to: yesterday, type: activeEnergyType)

        return (averageTotal, averageHourlyData)
    }

    // Fetch hourly data for a specific time range
    private func fetchHourlyData(from startDate: Date, to endDate: Date, type: HKQuantityType) async throws -> [HourlyEnergyData] {
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let calendar = Calendar.current

        var hourlyTotals: [Date: Double] = [:]

        let samples = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[HKQuantitySample], Error>) in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: samples as? [HKQuantitySample] ?? [])
            }
            healthStore.execute(query)
        }

        // Group by hour
        for sample in samples {
            let hourStart = calendar.dateInterval(of: .hour, for: sample.startDate)?.start ?? sample.startDate
            let calories = sample.quantity.doubleValue(for: .kilocalorie())
            hourlyTotals[hourStart, default: 0] += calories
        }

        // Convert to array and sort
        return hourlyTotals.map { HourlyEnergyData(hour: $0.key, calories: $0.value) }
            .sorted { $0.hour < $1.hour }
    }

    // Fetch daily totals for a date range
    private func fetchDailyTotals(from startDate: Date, to endDate: Date, type: HKQuantityType) async throws -> [Double] {
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let calendar = Calendar.current

        var dailyTotals: [Date: Double] = [:]

        let samples = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[HKQuantitySample], Error>) in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: samples as? [HKQuantitySample] ?? [])
            }
            healthStore.execute(query)
        }

        // Group by day
        for sample in samples {
            let dayStart = calendar.startOfDay(for: sample.startDate)
            let calories = sample.quantity.doubleValue(for: .kilocalorie())
            dailyTotals[dayStart, default: 0] += calories
        }

        return Array(dailyTotals.values)
    }

    // Fetch average hourly pattern across multiple days
    private func fetchAverageHourlyPattern(from startDate: Date, to endDate: Date, type: HKQuantityType) async throws -> [HourlyEnergyData] {
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let calendar = Calendar.current

        var hourlyData: [Int: (total: Double, count: Int)] = [:]

        let samples = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[HKQuantitySample], Error>) in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: samples as? [HKQuantitySample] ?? [])
            }
            healthStore.execute(query)
        }

        // Group by hour of day (0-23)
        for sample in samples {
            let hour = calendar.component(.hour, from: sample.startDate)
            let calories = sample.quantity.doubleValue(for: .kilocalorie())
            let current = hourlyData[hour] ?? (total: 0, count: 0)
            hourlyData[hour] = (total: current.total + calories, count: current.count + 1)
        }

        // Calculate averages and convert to HourlyEnergyData
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)

        return hourlyData.map { hour, data in
            let hourDate = calendar.date(byAdding: .hour, value: hour, to: startOfToday)!
            let averageCalories = data.count > 0 ? data.total / Double(data.count) : 0
            return HourlyEnergyData(hour: hourDate, calories: averageCalories)
        }.sorted { $0.hour < $1.hour }
    }
}

enum HealthKitError: Error {
    case notAvailable
    case authorizationDenied
}
