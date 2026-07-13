import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState
    @Environment(AppLockController.self) private var appLock
    @Query(sort: \Opportunity.updatedAt, order: .reverse) private var opportunities: [Opportunity]

    @State private var exportURL: URL?
    @State private var preparedIncludesConfidential: Bool?
    @State private var includeConfidential = false
    @State private var isUpdatingLock = false
    @State private var errorMessage: String?
    @State private var showDeleteConfirmation = false
    @State private var showRemoveSampleConfirmation = false

    var body: some View {
        @Bindable var appState = appState

        Form {
            Section {
                NavigationLink(value: AppRoute.privacy) {
                    SettingsRow(title: "Privacy & data use", detail: "On-device by default", symbol: "hand.raised.fill", colour: BrandTheme.violet)
                }
                Toggle(isOn: Binding(
                    get: { appLock.isEnabled },
                    set: { value in Task { await updateLock(value) } }
                )) {
                    SettingsRow(title: "App Lock", detail: "Face ID, Touch ID, or passcode", symbol: "faceid", colour: BrandTheme.success)
                }
                .disabled(isUpdatingLock)
                .accessibilityIdentifier("app-lock-toggle")
                if appLock.isEnabled {
                    Button("Lock now", systemImage: "lock.fill") { appLock.lockNow() }
                }
            } header: {
                Text("Protection")
            } footer: {
                Text("App Lock uses iOS device-owner authentication. RoleReady never receives biometric or passcode data.")
            }

            Section("Experience") {
                Toggle("Haptic feedback", isOn: $appState.hapticsEnabled)
                Button {
                    scheduleReminder()
                } label: {
                    SettingsRow(title: "Interview reminder", detail: reminderDetail, symbol: "bell.badge.fill", colour: BrandTheme.amberText)
                }
                .disabled(nextInterview == nil)
            }

            Section {
                Toggle("Include all sensitive data", isOn: $includeConfidential)
                    .tint(BrandTheme.warning)
                Button {
                    prepareExport()
                } label: {
                    SettingsRow(title: "Prepare JSON export", detail: "Versioned, portable data copy", symbol: "arrow.down.doc.fill", colour: BrandTheme.violet)
                }
                if let exportURL {
                    ShareLink(item: exportURL) {
                        Label(
                            preparedIncludesConfidential == true ? "Share full export" : "Share reduced-sensitivity export",
                            systemImage: "square.and.arrow.up"
                        )
                            .font(.rrHeadline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryActionButtonStyle())
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }
            } header: {
                Text("Your data")
            } footer: {
                Text(includeConfidential
                     ? "Includes every story, full job-ad text, private role notes, and interview reflections. Review where you save or share it."
                     : "Omits confidential and highly sensitive stories, their derived answers and practice runs, full job-ad text, private role notes, and all interview reflections.")
            }

            if appState.isUsingSampleWorkspace {
                Section("Sample workspace") {
                    Button("Remove Maya’s sample data", systemImage: "person.crop.circle.badge.minus", role: .destructive) {
                        showRemoveSampleConfirmation = true
                    }
                }
            }

            Section {
                Button("Delete all RoleReady data", systemImage: "trash.fill", role: .destructive) {
                    showDeleteConfirmation = true
                }
                .accessibilityIdentifier("delete-all-data")
            } header: {
                Text("Permanent deletion")
            } footer: {
                Text("Deletes stories, roles, answers, practice history, and local preferences from this device. This cannot be undone.")
            }

            Section {
                HStack {
                    Wordmark()
                    Spacer()
                    Text(versionText)
                        .font(.rrCaption)
                        .foregroundStyle(BrandTheme.inkMuted)
                }
            }
            .listRowBackground(Color.clear)
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .screenBackground()
        .onChange(of: includeConfidential) { _, _ in
            clearPreparedExport()
        }
        .confirmationDialog("Remove the sample workspace?", isPresented: $showRemoveSampleConfirmation, titleVisibility: .visible) {
            Button("Remove sample data", role: .destructive, action: removeSample)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Maya’s fictional stories, role, and answer will be removed. Your own records remain.")
        }
        .confirmationDialog("Delete everything from this device?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete all data", role: .destructive, action: deleteAll)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Export first if you may need this information later.")
        }
        .alert("Settings", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) { Button("OK", role: .cancel) {} } message: { Text(errorMessage ?? "Try again.") }
    }

    private var nextInterview: Opportunity? {
        opportunities
            .filter {
                ($0.status == .preparing || $0.status == .interviewing)
                    && ($0.interviewDate ?? .distantPast) > Date()
            }
            .sorted { ($0.interviewDate ?? .distantFuture) < ($1.interviewDate ?? .distantFuture) }
            .first
    }

    private var reminderDetail: String {
        guard let date = nextInterview?.interviewDate else { return "Add an interview date first" }
        let interval = date.timeIntervalSinceNow
        if interval > 24 * 60 * 60 { return "24 hours before the interview" }
        if interval > 2 * 60 * 60 { return "1 hour before the interview" }
        if interval > 15 * 60 { return "10 minutes before the interview" }
        return "Interview starts soon"
    }

    private var versionText: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "Version \(short) (\(build))"
    }

    private func updateLock(_ enabled: Bool) async {
        isUpdatingLock = true
        let success = await appLock.setEnabled(enabled)
        if !success { errorMessage = appLock.lastError ?? "Authentication was cancelled." }
        isUpdatingLock = false
    }

    private func scheduleReminder() {
        guard let nextInterview else { return }
        Task {
            do {
                guard let interviewDate = nextInterview.interviewDate else { return }
                let reminderDate = try await NotificationService().scheduleInterviewReminder(
                    opportunityID: nextInterview.id,
                    interviewDate: interviewDate
                )
                appState.showToast(
                    "Reminder set for \(reminderDate.formatted(date: .abbreviated, time: .shortened))",
                    symbol: "bell.badge.fill"
                )
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func prepareExport() {
        do {
            clearPreparedExport()
            let data = try ExportService().makeExport(in: modelContext, includeConfidential: includeConfidential)
            exportURL = try ExportService().writeTemporaryExport(data)
            preparedIncludesConfidential = includeConfidential
            appState.showToast("Export prepared", symbol: "checkmark.shield.fill")
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func removeSample() {
        do {
            clearPreparedExport()
            opportunities.filter(\.isSample).forEach {
                NotificationService().cancelReminders(for: $0.id)
            }
            try SeedService().removeSampleWorkspace(from: modelContext)
            if try modelContext.fetch(FetchDescriptor<CareerProfile>()).isEmpty {
                try SeedService().createBlankWorkspace(in: modelContext)
            }
            appState.isUsingSampleWorkspace = false
            appState.showToast("Sample workspace removed")
        } catch {
            modelContext.rollback()
            errorMessage = error.localizedDescription
        }
    }

    private func deleteAll() {
        Task {
            if appLock.isEnabled {
                await appLock.unlock()
                guard appLock.state.isUnlocked else {
                    errorMessage = "Authentication is required to delete all data."
                    return
                }
            }
            do {
                NotificationService().cancelAllReminders()
                ExportService().removeTemporaryExports()
                try SeedService().deleteAll(from: modelContext)
                appLock.resetAfterDataDeletion()
                appState.resetAfterDataDeletion()
                appState.showToast("All local data deleted")
            } catch {
                modelContext.rollback()
                errorMessage = error.localizedDescription
            }
        }
    }

    private func clearPreparedExport() {
        if let exportURL {
            try? FileManager.default.removeItem(at: exportURL)
        }
        exportURL = nil
        preparedIncludesConfidential = nil
    }
}

private struct SettingsRow: View {
    let title: String
    let detail: String
    let symbol: String
    let colour: Color

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).foregroundStyle(BrandTheme.ink)
                Text(detail).font(.caption).foregroundStyle(BrandTheme.inkMuted)
            }
        } icon: {
            Image(systemName: symbol)
                .foregroundStyle(colour)
                .frame(width: 28)
        }
    }
}
