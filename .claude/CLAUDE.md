# Health Trends - Technical Documentation

## Workflow Rules

We track work in Beads instead of Markdown. Run `bd quickstart` to see how.

### Git Commits
- **Always update beads task status before every git commit**
  - Close completed issues with `bd close <issue-id>`
  - Update in-progress work with `bd update <issue-id> --status in_progress`
  - This ensures issues.jsonl stays in sync with code changes

### Documentation
- **apple-docs MCP server is available** for Swift, SwiftUI, Swift Charts, and other Apple framework documentation
  - Use it to look up APIs, best practices, and implementation details
  - Available tools: search_apple_docs, get_apple_doc_content, list_technologies, etc.

## Terminology
This document defines the key metrics used throughout the app to avoid confusion.

### "Today"
**Definition:** Cumulative calories burned from midnight to the current time.

**Example:** At 1:00 PM, if you've burned:
- 0-1 AM: 10 cal
- 1-2 AM: 5 cal
- ...
- 12-1 PM: 217 cal

Then "Today" = 467 cal (total from midnight to 1 PM)

**In Code:**
- `todayTotal: Double` - Current cumulative total
- `todayHourlyData: [HourlyEnergyData]` - Cumulative values at each hour
  - Example: `[10, 15, ..., 250, 467]` (running sum)

---

### "Average"
**Definition:** The average cumulative calories burned BY each hour, calculated across the last 30 days (excluding today).

**Example:** At 1:00 PM:
- Day 1: burned 400 cal by 1 PM
- Day 2: burned 380 cal by 1 PM
- ...
- Day 30: burned 395 cal by 1 PM

Then "Average" at 1 PM = (400 + 380 + ... + 395) / 30 = 389 cal

**In Code:**
- `averageHourlyData: [HourlyEnergyData]` - Average cumulative values at each hour
  - For hour H: average of (day1_total_by_H + day2_total_by_H + ... + day30_total_by_H) / 30
  - Example: `[8, 12, ..., 350, 389]` (cumulative averages)

**Display:** Show the value at the current hour (e.g., 389 cal at 1 PM)

---

### "Total"
**Definition:** The average of complete daily totals from the last 30 days (excluding today).

**Example:**
- Day 1: burned 1,050 cal (full day)
- Day 2: burned 1,020 cal (full day)
- ...
- Day 30: burned 1,032 cal (full day)

Then "Total" = (1,050 + 1,020 + ... + 1,032) / 30 = 1,034 cal

**In Code:**
- `projectedTotal: Double` - Average of complete daily totals
  - This represents where you'd end up at midnight if you follow the average pattern

**Visual:** Shown as a horizontal green line on the chart and a green statistic

---

## Why This Matters

These three metrics answer different questions:

1. **"Today"**: How much have I burned so far?
2. **"Average"**: How much had I typically burned by this time of day?
3. **"Total"**: If I follow my average pattern, where will I end up?

The distinction between "Average" (cumulative by hour) and "Total" (daily average) is critical for accurate graphing and projections.
