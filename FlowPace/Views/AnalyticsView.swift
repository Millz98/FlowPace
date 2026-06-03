import SwiftUI
import Charts

struct AnalyticsView: View {
    @EnvironmentObject var routineManager: RoutineManager
    @EnvironmentObject var storeKitManager: StoreKitManager
    @EnvironmentObject var backgroundColorManager: BackgroundColorManager

    @State private var selectedTimeRange: TimeRange = .week
    @State private var selectedMetric: MetricType = .duration
    @State private var showingShareSheet = false
    @State private var shareURL: URL?

    enum TimeRange: String, CaseIterable {
        case week = "Week"
        case month = "Month"
        case year = "Year"
    }

    enum MetricType: String, CaseIterable {
        case duration = "Duration"
        case count = "Sessions"
        case streak = "Streak"
    }

    var body: some View {
        ZStack {
            backgroundColorManager.backgroundGradient
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    if !storeKitManager.isPro {
                        ProFeatureTeaser()
                    }

                    // Time range selector
                    Picker("Time Range", selection: $selectedTimeRange) {
                        ForEach(TimeRange.allCases, id: \.self) { range in
                            Text(range.rawValue).tag(range)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal)

                    // Metric selector
                    Picker("Metric", selection: $selectedMetric) {
                        ForEach(MetricType.allCases, id: \.self) { metric in
                            Text(metric.rawValue).tag(metric)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal)

                    // Stats cards with week-over-week badges
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        StatCard(
                            title: "Total Sessions",
                            value: "\(filteredCompletions.count)",
                            icon: "checkmark.circle.fill",
                            color: .green,
                            trend: weekOverWeekSessionsDiff
                        )
                        StatCard(
                            title: "Total Time",
                            value: totalTimeFormatted,
                            icon: "clock.fill",
                            color: .blue,
                            trend: weekOverWeekDurationDiff
                        )
                        StatCard(
                            title: "Current Streak",
                            value: "\(currentStreak) days",
                            icon: "flame.fill",
                            color: .orange,
                            trend: nil
                        )
                        StatCard(
                            title: "Avg Duration",
                            value: averageDurationFormatted,
                            icon: "chart.bar.fill",
                            color: .purple,
                            trend: weekOverWeekAvgDiff
                        )
                    }
                    .padding(.horizontal)

                    // Chart with last week overlay
                    VStack(alignment: .leading, spacing: 12) {
                        Text("\(selectedMetric.rawValue) Over Time")
                            .font(.headline)
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                            .padding(.horizontal)

                        if #available(iOS 16.0, *) {
                            Chart(chartData) { item in
                                BarMark(
                                    x: .value("Date", item.date, unit: .day),
                                    y: .value(selectedMetric.rawValue, item.value)
                                )
                                .foregroundStyle(
                                    item.isLastWeek
                                        ? AnyShapeStyle(Color.white.opacity(0.25))
                                        : AnyShapeStyle(Color.blue.gradient)
                                )
                                .opacity(item.isLastWeek ? 0.5 : 1.0)
                            }
                                .frame(height: 200)
                                .padding(.horizontal)
                        } else {
                            Text("Charts require iOS 16+")
                                .foregroundColor(.secondary)
                                .padding()
                        }
                    }
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.ultraThinMaterial)
                            .opacity(0.6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(
                                        LinearGradient(
                                            colors: [
                                                Color.white.opacity(0.3),
                                                Color.white.opacity(0.1)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1
                                    )
                            )
                            .shadow(color: .black.opacity(0.1), radius: 12, x: 0, y: 6)
                    )
                    .padding(.horizontal)

                    // Routine breakdown
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Routine Breakdown")
                            .font(.headline)
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                            .padding(.horizontal)

                        ForEach(routineBreakdown, id: \.name) { item in
                            HStack {
                                Text(item.name)
                                    .font(.subheadline)
                                    .foregroundColor(.white)
                                Spacer()
                                Text("\(item.count) sessions")
                                    .foregroundColor(.white.opacity(0.7))
                                Text("(\(formatTime(item.totalTime)))")
                                    .foregroundColor(.white.opacity(0.7))
                                    .font(.caption)
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(.ultraThinMaterial)
                                    .opacity(0.4)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                    )
                            )
                            .padding(.horizontal)
                        }
                    }
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.ultraThinMaterial)
                            .opacity(0.6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(
                                        LinearGradient(
                                            colors: [
                                                Color.white.opacity(0.3),
                                                Color.white.opacity(0.1)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1
                                    )
                            )
                            .shadow(color: .black.opacity(0.1), radius: 12, x: 0, y: 6)
                    )
                    .padding(.horizontal)

                    // Export button (Pro only)
                    if storeKitManager.isPro {
                        Button(action: exportData) {
                            Label("Export Data (CSV)", systemImage: "square.and.arrow.up")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(
                                            LinearGradient(
                                                gradient: Gradient(colors: [Color.blue, Color.purple]),
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 16)
                                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                        )
                                )
                                .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                        }
                        .padding(.horizontal)
                        .padding(.top)
                    }

                    Color.clear.frame(height: 30)
                }
                .padding(.vertical)
            }
        }
        .navigationTitle("Analytics")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingShareSheet) {
            if let url = shareURL {
                ShareSheet(activityItems: [url])
            }
        }
    }

    // MARK: - Chart Data

    struct ChartData: Identifiable {
        let id = UUID()
        let date: Date
        let value: Double
        let isLastWeek: Bool
    }

    var chartData: [ChartData] {
        var result: [ChartData] = []
        for completion in lastWeekCompletions {
            result.append(ChartData(
                date: completion.completedAt,
                value: metricValue(for: completion),
                isLastWeek: true
            ))
        }
        for completion in filteredCompletions {
            result.append(ChartData(
                date: completion.completedAt,
                value: metricValue(for: completion),
                isLastWeek: false
            ))
        }
        return result
    }

    // MARK: - Week over Week Computed Properties

    var lastWeekCompletions: [CompletedRoutine] {
        let calendar = Calendar.current
        let now = Date()
        guard let lastWeek = calendar.date(byAdding: .weekOfYear, value: -1, to: now) else { return [] }

        return routineManager.completedRoutines.filter { completion in
            calendar.isDate(completion.completedAt, equalTo: lastWeek, toGranularity: .weekOfYear)
        }
    }

    var weekOverWeekSessionsDiff: Int? {
        let lastWeekCount = lastWeekCompletions.count
        let thisWeekCount = filteredCompletions.count
        let diff = thisWeekCount - lastWeekCount
        return diff != 0 ? diff : nil
    }

    var weekOverWeekDurationDiff: Int? {
        let lastWeekTotal = lastWeekCompletions.reduce(0) { $0 + $1.totalDuration }
        let thisWeekTotal = filteredCompletions.reduce(0) { $0 + $1.totalDuration }
        let diff = thisWeekTotal - lastWeekTotal
        guard abs(diff) >= 60 else { return nil } // Only show if >= 1 min difference
        return Int(diff / 60) // Return diff in minutes
    }

    var weekOverWeekAvgDiff: Int? {
        guard !filteredCompletions.isEmpty else { return nil }
        let thisWeekAvg = filteredCompletions.reduce(0) { $0 + $1.totalDuration } / Double(filteredCompletions.count)

        guard !lastWeekCompletions.isEmpty else { return nil }
        let lastWeekAvg = lastWeekCompletions.reduce(0) { $0 + $1.totalDuration } / Double(lastWeekCompletions.count)

        let diff = thisWeekAvg - lastWeekAvg
        guard abs(diff) >= 60 else { return nil } // Only show if >= 1 min difference
        return Int(diff / 60) // Return diff in minutes
    }

    // MARK: - Existing Computed Properties

    var filteredCompletions: [CompletedRoutine] {
        let calendar = Calendar.current
        let now = Date()

        return routineManager.completedRoutines.filter { completion in
            switch selectedTimeRange {
            case .week:
                return calendar.isDate(completion.completedAt, equalTo: now, toGranularity: .weekOfYear)
            case .month:
                return calendar.isDate(completion.completedAt, equalTo: now, toGranularity: .month)
            case .year:
                return calendar.isDate(completion.completedAt, equalTo: now, toGranularity: .year)
            }
        }
    }

    var totalTimeFormatted: String {
        let total = filteredCompletions.reduce(0) { $0 + $1.totalDuration }
        return formatTime(total)
    }

    var averageDurationFormatted: String {
        guard !filteredCompletions.isEmpty else { return "0m" }
        let total = filteredCompletions.reduce(0) { $0 + $1.totalDuration }
        let avg = total / Double(filteredCompletions.count)
        return formatTime(avg)
    }

    var currentStreak: Int {
        let calendar = Calendar.current
        let sortedCompletions = routineManager.completedRoutines.sorted { $0.completedAt > $1.completedAt }

        guard !sortedCompletions.isEmpty else { return 0 }

        var streak = 0
        var checkDate: Date = Date()

        var completionDays = Set<Date>()
        for completion in sortedCompletions {
            let day = calendar.startOfDay(for: completion.completedAt)
            completionDays.insert(day)
        }

        for _ in 0..<365 {
            let currentDay = calendar.startOfDay(for: checkDate)
            if completionDays.contains(currentDay) {
                streak += 1
            } else if calendar.isDateInToday(checkDate) {
                // Allow today to not have a completion yet
            } else {
                break
            }
            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: checkDate) else { break }
            checkDate = previousDay
        }

        return streak
    }

    var routineBreakdown: [(name: String, count: Int, totalTime: TimeInterval)] {
        var breakdown: [String: (count: Int, totalTime: TimeInterval)] = [:]

        for completion in filteredCompletions {
            let current = breakdown[completion.routineName] ?? (0, 0)
            breakdown[completion.routineName] = (current.count + 1, current.totalTime + completion.totalDuration)
        }

        return breakdown.map { ($0.key, $0.value.count, $0.value.totalTime) }
            .sorted { $0.count > $1.count }
    }

    // MARK: - Helper Methods

    func metricValue(for completion: CompletedRoutine) -> Double {
        switch selectedMetric {
        case .duration:
            return completion.totalDuration / 60.0
        case .count:
            return 1.0
        case .streak:
            return Double(currentStreak)
        }
    }

    func formatTime(_ timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let hours = minutes / 60
        let remainingMinutes = minutes % 60

        if hours > 0 {
            return "\(hours)h \(remainingMinutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    func exportData() {
        var csv = "Date,Routine Name,Duration (minutes)\n"

        for completion in routineManager.completedRoutines {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd HH:mm"
            let dateStr = dateFormatter.string(from: completion.completedAt)
            let durationMinutes = completion.totalDuration / 60.0
            csv += "\(dateStr),\(completion.routineName),\(String(format: "%.1f", durationMinutes))\n"
        }

        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("FlowPace_Analytics.csv")

        do {
            try csv.write(to: fileURL, atomically: true, encoding: .utf8)
            shareURL = fileURL
            showingShareSheet = true
        } catch {
            print("Failed to export CSV: \(error)")
        }
    }
}

// MARK: - Supporting Views

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    let trend: Int? // week-over-week diff (sessions count or minutes)

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Spacer()
            }

            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)

            Text(title)
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))

            // Week-over-week trend badge
            if let trend = trend {
                HStack(spacing: 3) {
                    Image(systemName: trend > 0 ? "arrow.up" : "arrow.down")
                        .font(.system(size: 9, weight: .bold))
                    Text(formatTrendLabel(trend))
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundColor(trend > 0 ? .green : .red)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .opacity(0.5)
                        .overlay(
                            Capsule()
                                .stroke(
                                    trend > 0
                                        ? Color.green.opacity(0.3)
                                        : Color.red.opacity(0.3),
                                    lineWidth: 1
                                )
                        )
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .opacity(0.6)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.3),
                                    Color.white.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .shadow(color: .black.opacity(0.1), radius: 12, x: 0, y: 6)
    }

    private func formatTrendLabel(_ diff: Int) -> String {
        let absDiff = abs(diff)
        // For sessions (small numbers), show as count. For duration (minutes), show as time.
        if absDiff >= 60 {
            let hours = absDiff / 60
            let mins = absDiff % 60
            if hours > 0 {
                return "\(hours)h \(mins)m"
            } else {
                return "\(mins)m"
            }
        } else {
            return "\(absDiff)"
        }
    }
}

struct ProFeatureTeaser: View {
    @EnvironmentObject var storeKitManager: StoreKitManager

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 40))
                .foregroundColor(.blue)

            Text("Unlock Advanced Analytics")
                .font(.headline)
                .foregroundColor(.white)

            Text("Track streaks, trends, and export your data with FlowPace Pro")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)

            Button(action: {
                // Show purchase options
            }) {
                Text("Upgrade to Pro")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color.blue, Color.purple]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                    )
                    .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .opacity(0.6)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.3),
                                    Color.white.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .shadow(color: .black.opacity(0.1), radius: 12, x: 0, y: 6)
        .padding(.horizontal)
    }
}

/// A simple UIActivityViewController wrapper for sharing files
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Preview

struct AnalyticsView_Previews: PreviewProvider {
    static var previews: some View {
        AnalyticsView()
            .environmentObject(RoutineManager())
            .environmentObject(StoreKitManager())
            .environmentObject(BackgroundColorManager())
    }
}
