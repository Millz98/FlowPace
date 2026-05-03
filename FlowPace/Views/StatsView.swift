import SwiftUI

struct StatsView: View {
    @EnvironmentObject var routineManager: RoutineManager
    @EnvironmentObject var backgroundColorManager: BackgroundColorManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
                        // Dynamic gradient background based on user preference
            backgroundColorManager.backgroundGradient
                .ignoresSafeArea()
            
            ScrollView {
                LazyVStack(spacing: 28) {
                    // Close button (top-left)
                    HStack {
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark")
                                .font(.title2)
                                .foregroundColor(.primary)
                                .frame(width: 44, height: 44)
                                .background(Circle().fill(Color.white.opacity(0.15)))
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    
                    // Hero header with exciting design
                    VStack(spacing: 20) {
                        // Large circular icon with gradient
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [Color.blue, Color.purple]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 120, height: 120)
                                .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
                            
                            Image(systemName: "chart.bar.fill")
                                .font(.system(size: 50, weight: .bold))
                                .foregroundColor(.white)
                        }
                        
                        Text("Your Progress")
                            .font(.system(size: 36, weight: .heavy, design: .rounded))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                        
                        Text("Momentum beats procrastination. Keep going!")
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.9))
                            .tracking(0.5)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 20)
                    
                    // Main Stats Cards
                    VStack(spacing: 16) {
                        // This Month Summary
                        StatsCard(
                            title: "This Month",
                            stats: [
                                StatItem(label: "Total Time", value: formatTotalTime(thisMonthTime), color: .blue),
                                StatItem(label: "Sessions", value: "\(thisMonthSessions)", color: .green),
                                StatItem(label: "Current Streak", value: "\(currentStreak) days", color: .purple)
                            ]
                        )
                        
                        // Today's Progress
                        StatsCard(
                            title: "Today",
                            stats: [
                                StatItem(label: "Time Invested", value: formatTotalTime(todayTime), color: .orange),
                                StatItem(label: "Sessions", value: "\(todaySessions)", color: .teal)
                            ]
                        )
                    }
                    .padding(.horizontal, 20)
                    
                    // Recent Activity
                    if !recentActivity.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Recent Activity")
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)
                                .padding(.horizontal, 20)
                            
                            LazyVStack(spacing: 12) {
                                ForEach(recentActivity.prefix(10), id: \.id) { activity in
                                    ActivityRow(activity: activity)
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                    
                    // Share & Bottom spacing
                    ShareLink(item: shareText) {
                        HStack(spacing: 12) {
                            Image(systemName: "square.and.arrow.up.fill")
                                .font(.title2)
                                .fontWeight(.bold)
                            Text("Share Progress")
                                .font(.title3)
                                .fontWeight(.bold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [Color.blue, Color.purple]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .shadow(color: .black.opacity(0.2), radius: 12, x: 0, y: 6)
                        )
                        .padding(.horizontal, 20)
                    }
                    
                    Color.clear.frame(height: 28)
                }
            }
        }
        .navigationBarHidden(true)
    }
    
    // MARK: - Computed Properties
    
    private var thisMonthTime: TimeInterval {
        let calendar = Calendar.current
        let now = Date()
        _ = calendar.dateInterval(of: .month, for: now)?.start ?? now
        
        return routineManager.completedRoutines
            .filter { calendar.isDate($0.completedAt, equalTo: now, toGranularity: .month) }
            .reduce(0) { $0 + $1.totalDuration }
    }
    
    private var thisMonthSessions: Int {
        let calendar = Calendar.current
        let now = Date()
        
        return routineManager.completedRoutines
            .filter { calendar.isDate($0.completedAt, equalTo: now, toGranularity: .month) }
            .count
    }
    
    private var todayTime: TimeInterval {
        let calendar = Calendar.current
        let now = Date()
        
        return routineManager.completedRoutines
            .filter { calendar.isDate($0.completedAt, equalTo: now, toGranularity: .day) }
            .reduce(0) { $0 + $1.totalDuration }
    }
    
    private var todaySessions: Int {
        let calendar = Calendar.current
        let now = Date()
        
        return routineManager.completedRoutines
            .filter { calendar.isDate($0.completedAt, equalTo: now, toGranularity: .day) }
            .count
    }
    
    private var currentStreak: Int {
        guard !routineManager.completedRoutines.isEmpty else { return 0 }
        
        let calendar = Calendar.current
        let sortedRoutines = routineManager.completedRoutines.sorted { $0.completedAt > $1.completedAt }
        
        var streak = 0
        var currentDate = Date()
        
        // Check if we have activity today, if not start from yesterday
        let hasActivityToday = sortedRoutines.contains { calendar.isDate($0.completedAt, equalTo: currentDate, toGranularity: .day) }
        if !hasActivityToday {
            currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate) ?? currentDate
        }
        
        // Count consecutive days with activity
        while let dayStart = calendar.dateInterval(of: .day, for: currentDate)?.start {
            let hasActivity = sortedRoutines.contains { calendar.isDate($0.completedAt, equalTo: dayStart, toGranularity: .day) }
            if hasActivity {
                streak += 1
                currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate) ?? currentDate
            } else {
                break
            }
        }
        
        return streak
    }
    
    private var recentActivity: [CompletedRoutine] {
        routineManager.completedRoutines
            .sorted { $0.completedAt > $1.completedAt }
    }
    
    private func formatTotalTime(_ time: TimeInterval) -> String {
        let hours = Int(time) / 3600
        let minutes = (Int(time) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    private var shareText: String {
        let month = formatTotalTime(thisMonthTime)
        return "This month with FlowPace: \(month), \(thisMonthSessions) sessions, streak \(currentStreak) days."
    }
}

// MARK: - Supporting Views

struct StatsCard: View {
    let title: String
    let stats: [StatItem]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(title)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: stats.count > 2 ? 3 : 2), spacing: 16) {
                ForEach(stats, id: \.label) { stat in
                    VStack(spacing: 8) {
                        Text(stat.value)
                            .font(.system(size: 32, weight: .heavy, design: .rounded))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.4), radius: 3, x: 0, y: 2)
                        
                        Text(stat.label)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.9))
                    }
                }
            }
        }
        .padding(28)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.white.opacity(0.25))
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color.white.opacity(0.4), lineWidth: 2)
                )
        )
        .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
    }
}

struct StatItem {
    let label: String
    let value: String
    let color: Color
}

struct ActivityRow: View {
    let activity: CompletedRoutine
    
    var body: some View {
        HStack(spacing: 16) {
            // Color indicator
            Circle()
                .fill(Color.blue)
                .frame(width: 12, height: 12)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(activity.routineName)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                
                Text(formatDuration(activity.totalDuration))
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.9))
            }
            
            Spacer()
            
            Text(formatDate(activity.completedAt))
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.9))
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.2))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        
        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        } else {
            return "\(seconds)s"
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let calendar = Calendar.current
        
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return formatter.string(from: date)
        }
    }
}

// MARK: - Data Models
// CompletedRoutine is defined in Models.swift

#Preview {
    StatsView()
        .environmentObject(RoutineManager())
        .environmentObject(BackgroundColorManager())
}
