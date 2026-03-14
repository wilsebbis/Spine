import SwiftUI
import SwiftData

// MARK: - Settings View
// Account, reading preferences, aids, notifications, about.
// Slim and respectful — not a commerce dashboard.

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var settings: [UserSettings]
    
    private var appSettings: UserSettings? { settings.first }
    
    var body: some View {
        List {
            // MARK: - Account
            accountSection
            
            // MARK: - Daily Ritual
            ritualSection
            
            // MARK: - Reader Preferences
            readerSection
            
            // MARK: - Reading Aids
            aidsSection
            
            // MARK: - Notifications
            notificationsSection
            
            // MARK: - About
            aboutSection
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
    }
    
    // MARK: - Account Section
    
    private var accountSection: some View {
        Section {
            // Membership status
            HStack(spacing: SpineTokens.Spacing.sm) {
                Image(systemName: PremiumManager.shared.isPremium ? "crown.fill" : "crown")
                    .foregroundStyle(SpineTokens.Colors.accentGold)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(PremiumManager.shared.isPremium ? "Spine Premium" : "Free Plan")
                        .font(SpineTokens.Typography.caption2)
                        .foregroundStyle(SpineTokens.Colors.espresso)
                    Text(PremiumManager.shared.isPremium ? "Active membership" : "Upgrade for unlimited access")
                        .font(.system(size: 11))
                        .foregroundStyle(SpineTokens.Colors.subtleGray)
                }
                
                Spacer()
            }
            
            Button("Restore Purchases") {
                Task { await PremiumManager.shared.restorePurchases() }
            }
            .font(SpineTokens.Typography.caption2)
            .foregroundStyle(SpineTokens.Colors.accentGold)
        } header: {
            Text("Account")
        }
    }
    
    // MARK: - Daily Ritual
    
    private var ritualSection: some View {
        Section {
            if let s = appSettings {
                // Reading goal
                Picker("Daily Goal", selection: Binding(
                    get: { s.readingGoal },
                    set: { s.readingGoal = $0; try? modelContext.save() }
                )) {
                    ForEach(ReadingGoal.allCases, id: \.self) { goal in
                        Text(goal.displayLabel).tag(goal)
                    }
                }
                .font(SpineTokens.Typography.caption2)
                
                // XP goal
                HStack {
                    Text("Daily XP Goal")
                        .font(SpineTokens.Typography.caption2)
                    Spacer()
                    Picker("", selection: Binding(
                        get: { s.dailyXPGoal },
                        set: { s.dailyXPGoal = $0; try? modelContext.save() }
                    )) {
                        Text("20 XP").tag(20)
                        Text("30 XP").tag(30)
                        Text("50 XP").tag(50)
                    }
                    .pickerStyle(.menu)
                }
            }
        } header: {
            Text("Daily Ritual")
        } footer: {
            Text("Your daily commitment. Smaller goals build bigger streaks.")
        }
    }
    
    // MARK: - Reader Preferences
    
    private var readerSection: some View {
        Section {
            if let s = appSettings {
                // Theme
                Picker("Theme", selection: Binding(
                    get: { s.readerTheme },
                    set: { s.readerTheme = $0; try? modelContext.save() }
                )) {
                    ForEach(ReaderTheme.allCases, id: \.self) { theme in
                        Text(theme.displayName).tag(theme)
                    }
                }
                .font(SpineTokens.Typography.caption2)
                
                // Font size
                HStack {
                    Text("Font Size")
                        .font(SpineTokens.Typography.caption2)
                    Spacer()
                    Text("\(Int(s.fontSize))pt")
                        .font(SpineTokens.Typography.caption)
                        .foregroundStyle(SpineTokens.Colors.subtleGray)
                    Stepper("", value: Binding(
                        get: { s.fontSize },
                        set: { s.fontSize = $0; try? modelContext.save() }
                    ), in: 14...28, step: 1)
                    .labelsHidden()
                }
                
                // Serif toggle
                Toggle("Serif Font", isOn: Binding(
                    get: { s.useSerifFont },
                    set: { s.useSerifFont = $0; try? modelContext.save() }
                ))
                .font(SpineTokens.Typography.caption2)
                
                // Dyslexia-friendly
                Toggle("Dyslexia-Friendly Font", isOn: Binding(
                    get: { s.useDyslexiaFont },
                    set: { s.useDyslexiaFont = $0; try? modelContext.save() }
                ))
                .font(SpineTokens.Typography.caption2)
                
                // Line height
                HStack {
                    Text("Line Spacing")
                        .font(SpineTokens.Typography.caption2)
                    Spacer()
                    Text(String(format: "%.1f×", s.lineHeightMultiplier))
                        .font(SpineTokens.Typography.caption)
                        .foregroundStyle(SpineTokens.Colors.subtleGray)
                    Stepper("", value: Binding(
                        get: { s.lineHeightMultiplier },
                        set: { s.lineHeightMultiplier = $0; try? modelContext.save() }
                    ), in: 1.2...2.2, step: 0.1)
                    .labelsHidden()
                }
                
                // Margins
                HStack {
                    Text("Margins")
                        .font(SpineTokens.Typography.caption2)
                    Spacer()
                    Text("\(Int(s.marginSize))pt")
                        .font(SpineTokens.Typography.caption)
                        .foregroundStyle(SpineTokens.Colors.subtleGray)
                    Stepper("", value: Binding(
                        get: { s.marginSize },
                        set: { s.marginSize = $0; try? modelContext.save() }
                    ), in: 16...48, step: 4)
                    .labelsHidden()
                }
            }
        } header: {
            Text("Reader")
        }
    }
    
    // MARK: - Reading Aids
    
    private var aidsSection: some View {
        Section {
            if let s = appSettings {
                Toggle("Reading Ruler", isOn: Binding(
                    get: { s.lineGuideEnabled },
                    set: { s.lineGuideEnabled = $0; try? modelContext.save() }
                ))
                .font(SpineTokens.Typography.caption2)
                
                if s.lineGuideEnabled {
                    // Band height
                    Picker("Ruler Height", selection: Binding(
                        get: { s.lineGuideBandHeight },
                        set: { s.lineGuideBandHeight = $0; try? modelContext.save() }
                    )) {
                        Text("1 line").tag(1)
                        Text("2 lines").tag(2)
                        Text("3 lines").tag(3)
                    }
                    .font(SpineTokens.Typography.caption2)
                    
                    // Dim amount
                    HStack {
                        Text("Dim Intensity")
                            .font(SpineTokens.Typography.caption2)
                        Slider(value: Binding(
                            get: { s.lineGuideDimAmount },
                            set: { s.lineGuideDimAmount = $0; try? modelContext.save() }
                        ), in: 0.3...0.8)
                        .tint(SpineTokens.Colors.accentGold)
                    }
                }
                
                // Words per minute
                HStack {
                    Text("Reading Speed")
                        .font(SpineTokens.Typography.caption2)
                    Spacer()
                    Text("\(s.wordsPerMinute) WPM")
                        .font(SpineTokens.Typography.caption)
                        .foregroundStyle(SpineTokens.Colors.subtleGray)
                    Stepper("", value: Binding(
                        get: { s.wordsPerMinute },
                        set: { s.wordsPerMinute = $0; try? modelContext.save() }
                    ), in: 100...400, step: 25)
                    .labelsHidden()
                }
            }
        } header: {
            Text("Reading Aids")
        } footer: {
            Text("The reading ruler highlights the current line to reduce eye drift.")
        }
    }
    
    // MARK: - Notifications
    
    private var notificationsSection: some View {
        Section {
            if let s = appSettings {
                Toggle("Daily Reminder", isOn: Binding(
                    get: { s.dailyReminderEnabled },
                    set: {
                        s.dailyReminderEnabled = $0
                        try? modelContext.save()
                        if $0 { requestNotificationPermission() }
                    }
                ))
                .font(SpineTokens.Typography.caption2)
                
                if s.dailyReminderEnabled {
                    DatePicker(
                        "Reminder Time",
                        selection: Binding(
                            get: {
                                Calendar.current.date(
                                    from: DateComponents(hour: s.reminderHour, minute: s.reminderMinute)
                                ) ?? Date()
                            },
                            set: {
                                let comps = Calendar.current.dateComponents([.hour, .minute], from: $0)
                                s.reminderHour = comps.hour ?? 20
                                s.reminderMinute = comps.minute ?? 0
                                try? modelContext.save()
                            }
                        ),
                        displayedComponents: .hourAndMinute
                    )
                    .font(SpineTokens.Typography.caption2)
                }
            }
        } header: {
            Text("Notifications")
        } footer: {
            Text("A gentle nudge to continue your reading ritual.")
        }
    }
    
    // MARK: - About
    
    private var aboutSection: some View {
        Section {
            HStack {
                Text("Version")
                    .font(SpineTokens.Typography.caption2)
                Spacer()
                Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                    .font(SpineTokens.Typography.caption)
                    .foregroundStyle(SpineTokens.Colors.subtleGray)
            }
            
            Link(destination: URL(string: "mailto:support@wilsebbis.com")!) {
                HStack {
                    Text("Send Feedback")
                        .font(SpineTokens.Typography.caption2)
                        .foregroundStyle(SpineTokens.Colors.espresso)
                    Spacer()
                    Image(systemName: "envelope")
                        .foregroundStyle(SpineTokens.Colors.subtleGray)
                }
            }
            
            Button("Rate Spine") {
                if let url = URL(string: "https://apps.apple.com/app/spine") {
                    UIApplication.shared.open(url)
                }
            }
            .font(SpineTokens.Typography.caption2)
            .foregroundStyle(SpineTokens.Colors.espresso)
        } header: {
            Text("About")
        }
    }
    
    // MARK: - Helpers
    
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }
}
