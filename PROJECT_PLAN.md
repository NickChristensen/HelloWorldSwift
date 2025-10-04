# Health Trends MVP - Project Plan

## Vision
Display Active Energy data from HealthKit as a widget, showing:
- Today's calories vs. average
- Comparison message ("You're burning more calories today than you normally do")
- Line chart comparing today (orange) vs average (gray) throughout the day

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
- [ ] Set up HealthKit framework and request permissions
- [ ] Configure simulator with mock health data
- [ ] Create HealthKit data service to read Active Energy
- [ ] Build basic UI to display Active Energy data
- [ ] Integrate Swift Charts for energy trend visualization
- [ ] Style chart to match Health app design
- [ ] Create widget extension
- [ ] Render chart in widget timeline
