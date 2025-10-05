# Health Trends MVP - Project Plan

## Vision
Display Active Energy data from HealthKit as a widget, showing:
- **Today**: Cumulative calories burned so far today (orange line)
- **Average**: Average cumulative calories by current hour over past 30 days (gray line)
- **Total**: Average of complete daily totals from past 30 days (green vertical line)
- **Goal**: Daily Move goal from Fitness app (pink dashed line)
- Line chart comparing all 4 metrics throughout the day

## Phase 1: HealthKit Setup

### 1. HealthKit Framework
- Add HealthKit capability to Xcode project
- Add privacy description for health data access
- Request read permissions for Active Energy

### 2. Mock Data for Simulator
**Challenge**: Simulator doesn't support HealthKit data

**Solutions**:
- Use a real iPhone (even an old one works)
- Create a mock data layer for development (recommended)
- Use sample/hardcoded data while building UI/charts

### 3. Data Service
- Create `HealthKitManager` to query Active Energy
- Fetch today's total and hourly breakdown
- Calculate average from past 7-30 days

## Phase 2: In-App Chart

### 4. Basic UI
- Display today vs average calories
- Show the comparison message ("burning more...")

### 5. Swift Charts
- Built into iOS 16+, no external dependency needed
- Create line chart with hourly data points
- Overlay today (orange) vs average (gray)

### 6. Styling
- Match Health app colors (SF Symbols flame icon)
- Card-style layout with rounded corners
- Typography matching Health app

## Phase 3: Widget

### 7. Widget Extension
- Add Widget Extension target in Xcode
- Share HealthKit manager between app and widget (App Groups)
- Create Widget timeline provider

### 8. Widget Chart
- Render Swift Chart in widget
- Handle small/medium/large widget sizes
- Update timeline (every 15min or hourly)

## Key Technical Decisions

### Swift Charts vs External Library
✅ Use native Swift Charts (iOS 16+)
- No external dependencies
- Better performance
- Matches iOS 26 deployment target

### Mock Data Strategy
```swift
// Development: Use protocol to swap real/mock data
protocol HealthDataProvider {
    func fetchActiveEnergy() async -> [EnergyData]
}

// Real implementation uses HealthKit
class HealthKitProvider: HealthDataProvider { }

// Mock for simulator/previews
class MockHealthProvider: HealthDataProvider { }
```

## Recommended Implementation Order
1. Start with mock data layer
2. Build UI + chart with hardcoded data
3. Add HealthKit (test on real device)
4. Build widget last (reuse existing chart code)

## Tasks
- [x] Set up HealthKit framework and request permissions
- [x] Configure simulator with mock health data
- [x] Create HealthKit data service to read Active Energy
- [x] Build basic UI to display Active Energy data
- [x] Refactor data model for cumulative metrics (Today, Average, Total)
- [x] Fetch Move goal from HealthKit ActivitySummary
- [x] Display all 4 statistics in UI
- [ ] Integrate Swift Charts for energy trend visualization
- [ ] Style chart to match Health app design
- [ ] Create widget extension
- [ ] Render chart in widget timeline

## Progress Log

### 2025-10-04: HealthKit Setup Complete ✅
- Created `HelloWorld.entitlements` with HealthKit capability
- Added `NSHealthShareUsageDescription` privacy key
- Created `HealthKitManager` class to handle authorization
- Updated `ContentView` to request permissions on launch
- **Result**: HealthKit authorization prompt working correctly in simulator

### 2025-10-04: Sample Data Generation ✅
- Added `NSHealthUpdateUsageDescription` for write permissions
- Implemented `generateSampleData()` with 60 days of realistic data
- Added morning workout spike (150-250 cal at 7 AM)
- Auto-clears existing data before generating (prevents duplicates)
- Simulator-only UI with `#if targetEnvironment(simulator)`
- **Result**: Can generate and view realistic Active Energy data in Health app

### 2025-10-04: Data Reading Service ✅
- Created `HourlyEnergyData` model
- Implemented `fetchEnergyData()` to read from HealthKit
- Fetches today's total and hourly breakdown
- Calculates 30-day average total and hourly pattern
- Added published properties for reactive UI updates
- Built basic UI showing today vs average calories
- **Result**: App successfully reads and displays Active Energy data (696 cal today, 901 cal average)

### 2025-10-04: Cumulative Metrics Refactor ✅
- Created `CLAUDE.md` to document terminology (Today/Average/Total definitions)
- Refactored `fetchTodayData()` to return cumulative hourly data (running sum)
- Implemented `fetchCumulativeAverageHourlyPattern()` for proper average calculation
- Renamed `averageTotal` → `projectedTotal` to match "Total" metric
- Added `averageAtCurrentHour` property for "Average" display
- Fixed mock data generator to not create future data (only up to current hour)
- **Result**: All 3 metrics correctly calculate cumulative values

### 2025-10-04: Move Goal Integration ✅
- Added `HKActivitySummaryType` permission to authorization
- Implemented `fetchMoveGoal()` to read from HealthKit Activity Summary
- Added `moveGoal` published property
- Updated UI to display all 4 statistics in 2x2 grid layout
- Added simulator-only mock goal (1,000 cal) for development
- **Result**: All 4 statistics displaying (Today: 757, Average: 805, Total: 894, Goal: 1,000)

### 2025-10-04: Documentation Organization ✅
- Moved `CLAUDE.md` to `.claude/CLAUDE.md` for proper project-specific settings location
- Added "Workflow Rules" section to document git commit workflow
- **Rule**: Always update PROJECT_PLAN.md before every git commit
