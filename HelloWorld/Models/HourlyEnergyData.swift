import Foundation

/// Data model for hourly energy data
/// Represents cumulative calories burned at a specific hour
struct HourlyEnergyData: Identifiable {
    let id = UUID()
    let hour: Date
    let calories: Double
}
