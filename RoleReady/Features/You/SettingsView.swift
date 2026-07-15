import SwiftData
import SwiftUI
import UniformTypeIdentifiers

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
    @State private var isRestoreImporterPresented = false
    @State private var isReadingRestore = false
    @State private var restoreCandidate: RestoreImportCandidate?

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
                ForEach(LanguageProviderSelection.allCases) { selection in
                    let descriptor = LanguageProviderRegistry().descriptor(for: selection)
                    Button {
                        appState.languageProvider = selection
                    } label: {
                        HStack(alignment: .top, spacing: RRSpacing.sm) {
                            Image(systemName: appState.languageProvider == selection ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(appState.languageProvider == selection ? BrandTheme.violet : BrandTheme.inkMuted)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(selection.title)
                                    .foregroundStyle(BrandTheme.ink)
                                Text(descriptor.modelName)
                                    .font(.rrCaption)
                                    .foregroundStyle(BrandTheme.inkMuted)
                                Text(descriptor.isAvailable ? descriptor.privacySummary : descriptor.unavailableReason ?? "Unavailable")
                                    .font(.caption)
                                    .foregroundStyle(descriptor.isAvailable ? BrandTheme.tealText : BrandTheme.inkMuted)
                            }
                            Spacer(minLength: 0)
                            if descriptor.requiresDownload {
                                Image(systemName: "arrow.down.circle")
                                    .foregroundStyle(BrandTheme.inkMuted)
                            }
                        }
                    }
                    .disabled(!descriptor.isAvailable)
                    .accessibilityIdentifier("settings.ai.\(selection.rawValue)")
                }
            } header: {
                Text("AI assistance")
            } footer: {
                Text("Automatic never sends career data off-device. Apple’s model is used only when available; RoleReady’s deterministic grounding and approval rules remain authoritative. Premium cloud requires a secure backend and explicit per-request consent.")
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

                Button {
                    isRestoreImporterPresented = true
                } label: {
                    SettingsRow(
                        title: isReadingRestore ? "Checking export…" : "Restore from JSON export",
                        detail: "Preview first, then add new records safely",
                        symbol: "arrow.up.doc.fill",
                        colour: BrandTheme.success
                    )
                }
                .disabled(isReadingRestore)
                .accessibilityIdentifier("settings.restore.button")

                if isReadingRestore {
                    HStack(spacing: RRSpacing.sm) {
                        ProgressView()
                        Text("Validating without changing your workspace…")
                            .font(.rrCaption)
                            .foregroundStyle(BrandTheme.inkMuted)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("settings.restore.loading")
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
        .onDisappear {
            clearPreparedExport()
        }
        .fileImporter(
            isPresented: $isRestoreImporterPresented,
            allowedContentTypes: [.json],
            onCompletion: handleRestoreImportResult
        )
        .sheet(item: $restoreCandidate) { candidate in
            WorkspaceRestorePreviewSheet(candidate: candidate) {
                clearPreparedExport()
            }
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

    private func handleRestoreImportResult(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            Task { @MainActor in
                isReadingRestore = true
                defer { isReadingRestore = false }
                do {
                    let data = try await Task.detached(priority: .userInitiated) {
                        try RestoreDocumentReader().readData(from: url)
                    }.value
                    try Task.checkCancellation()
                    let preview = try WorkspaceRestoreService().preview(data, in: modelContext)
                    restoreCandidate = RestoreImportCandidate(data: data, preview: preview)
                } catch is CancellationError {
                    return
                } catch {
                    errorMessage = workspaceRestoreMessage(for: error)
                }
            }
        case .failure(let error):
            if (error as NSError).code != NSUserCancelledError {
                errorMessage = workspaceRestoreMessage(for: error)
            }
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

private struct RestoreImportCandidate: Identifiable {
    let id = UUID()
    let data: Data
    let preview: WorkspaceRestorePreview
}

private struct WorkspaceRestorePreviewSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState

    let candidate: RestoreImportCandidate
    let onRestoreCompleted: () -> Void

    @State private var isRestoring = false
    @State private var showRestoreConfirmation = false
    @State private var result: WorkspaceRestoreResult?
    @State private var errorMessage: String?
    @AccessibilityFocusState private var statusIsFocused: Bool

    var body: some View {
        NavigationStack {
            Group {
                if let result {
                    successContent(result)
                } else {
                    previewContent
                }
            }
            .navigationTitle(result == nil ? "Restore preview" : "Restore complete")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(result == nil ? "Cancel" : "Done") { dismiss() }
                        .disabled(isRestoring)
                }
            }
            .screenBackground()
        }
        .interactiveDismissDisabled(isRestoring)
        .onChange(of: errorMessage) { _, value in
            if value != nil { statusIsFocused = true }
        }
        .onChange(of: result) { _, value in
            if value != nil { statusIsFocused = true }
        }
        .confirmationDialog(
            "Add these records to RoleReady?",
            isPresented: $showRestoreConfirmation,
            titleVisibility: .visible
        ) {
            Button("Restore \(candidate.preview.importable.total) items") {
                restore()
            }
            .accessibilityIdentifier("restore.confirm")
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This is add-only. Existing records stay in place, matching IDs are skipped, and only an empty starter profile may be filled.")
        }
        .accessibilityIdentifier("restore.preview")
    }

    private var previewContent: some View {
        Form {
            Section {
                Label {
                    VStack(alignment: .leading, spacing: RRSpacing.xxs) {
                        Text("Ready to review")
                            .font(.rrHeadline)
                            .foregroundStyle(BrandTheme.ink)
                        Text("No changes have been made yet.")
                            .font(.rrCaption)
                            .foregroundStyle(BrandTheme.inkMuted)
                    }
                } icon: {
                    Image(systemName: "checkmark.shield.fill")
                        .font(.title2)
                        .foregroundStyle(BrandTheme.success)
                }

                LabeledContent("Created", value: candidate.preview.createdAt.formatted(date: .abbreviated, time: .shortened))
                LabeledContent("Export format", value: "Version \(candidate.preview.sourceVersion)")
                LabeledContent(
                    "Data level",
                    value: candidate.preview.includesConfidential ? "Full export" : "Reduced sensitivity"
                )
            }

            RestoreCountSection(title: "Items to restore", counts: candidate.preview.importable)

            if candidate.preview.duplicates.total > 0 {
                RestoreCountSection(title: "Already present or repeated", counts: candidate.preview.duplicates)
            }

            if candidate.preview.rejected.total > 0 {
                RestoreCountSection(title: "Invalid records to skip", counts: candidate.preview.rejected)
            }

            if !candidate.preview.warnings.isEmpty || errorMessage != nil {
                Section("Before restoring") {
                    if let errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(BrandTheme.danger)
                            .accessibilityFocused($statusIsFocused)
                            .accessibilityIdentifier("restore.error")
                    }
                    ForEach(candidate.preview.warnings, id: \.self) { warning in
                        Label(warning, systemImage: "info.circle.fill")
                            .foregroundStyle(BrandTheme.inkMuted)
                    }
                }
            }

            Section {
                Button {
                    showRestoreConfirmation = true
                } label: {
                    HStack {
                        Spacer()
                        if isRestoring {
                            ProgressView()
                                .tint(BrandTheme.onAmber)
                        }
                        Text(isRestoring ? "Restoring…" : restoreButtonTitle)
                            .font(.rrHeadline)
                        Spacer()
                    }
                }
                .buttonStyle(PrimaryActionButtonStyle())
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .disabled(isRestoring || candidate.preview.importable.total == 0)
                .accessibilityIdentifier("restore.preview.restore")
            } footer: {
                Text("RoleReady adds valid new records and may fill an empty starter profile. It never replaces information you entered or deletes records during restore.")
            }
        }
        .scrollContentBackground(.hidden)
    }

    private func successContent(_ result: WorkspaceRestoreResult) -> some View {
        ScrollView {
            VStack(spacing: RRSpacing.lg) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(BrandTheme.success)
                    .accessibilityHidden(true)

                VStack(spacing: RRSpacing.xs) {
                    Text("Your workspace was restored")
                        .font(.rrTitle)
                        .foregroundStyle(BrandTheme.ink)
                        .multilineTextAlignment(.center)
                        .accessibilityFocused($statusIsFocused)
                    Text("\(result.restored.total) item\(result.restored.total == 1 ? "" : "s") restored. Existing career information you entered was left unchanged.")
                        .font(.rrBody)
                        .foregroundStyle(BrandTheme.inkMuted)
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: RRSpacing.sm) {
                    RestoreSummaryRow(title: "Restored", value: result.restored.total, symbol: "plus.circle.fill", colour: BrandTheme.success)
                    RestoreSummaryRow(title: "Existing or repeated", value: result.skippedDuplicates, symbol: "equal.circle.fill", colour: BrandTheme.violet)
                    RestoreSummaryRow(title: "Invalid and skipped", value: result.rejectedRecords, symbol: "exclamationmark.circle.fill", colour: BrandTheme.warning)
                }
                .cardSurface()

            }
            .padding(RRSpacing.xl)
            .frame(maxWidth: 620)
            .frame(maxWidth: .infinity)
        }
        .accessibilityIdentifier("restore.success")
    }

    private var restoreButtonTitle: String {
        let count = candidate.preview.importable.total
        return count == 0 ? "No new items to restore" : "Restore \(count) item\(count == 1 ? "" : "s")"
    }

    private func restore() {
        guard !isRestoring else { return }
        isRestoring = true
        errorMessage = nil

        Task { @MainActor in
            defer { isRestoring = false }
            do {
                let restoreResult = try WorkspaceRestoreService().restore(candidate.data, in: modelContext)
                result = restoreResult
                onRestoreCompleted()
                refreshSampleWorkspaceState()
                appState.showToast("Workspace restored", symbol: "checkmark.shield.fill")
            } catch {
                errorMessage = workspaceRestoreMessage(for: error)
            }
        }
    }

    private func refreshSampleWorkspaceState() {
        let hasSampleProfile = (try? modelContext.fetch(FetchDescriptor<CareerProfile>()))?.contains(where: \.isSample) == true
        let hasSampleExperience = (try? modelContext.fetch(FetchDescriptor<Experience>()))?.contains(where: \.isSample) == true
        let hasSampleOpportunity = (try? modelContext.fetch(FetchDescriptor<Opportunity>()))?.contains(where: \.isSample) == true
        appState.isUsingSampleWorkspace = hasSampleProfile || hasSampleExperience || hasSampleOpportunity
    }
}

private struct RestoreCountSection: View {
    let title: String
    let counts: RestoreRecordCounts

    var body: some View {
        Section(title) {
            if rows.isEmpty {
                Text("None")
                    .foregroundStyle(BrandTheme.inkMuted)
            } else {
                ForEach(rows) { row in
                    LabeledContent(row.title, value: row.value.formatted())
                }
            }
        }
    }

    private var rows: [RestoreCountRow] {
        [
            RestoreCountRow(title: "Profile", value: counts.profiles),
            RestoreCountRow(title: "Career sources", value: counts.careerSources),
            RestoreCountRow(title: "Source links", value: counts.sourceSpans),
            RestoreCountRow(title: "Employment and projects", value: counts.positions),
            RestoreCountRow(title: "Education", value: counts.education),
            RestoreCountRow(title: "Certifications", value: counts.certifications),
            RestoreCountRow(title: "Career skills", value: counts.careerSkills),
            RestoreCountRow(title: "Examples", value: counts.experiences),
            RestoreCountRow(title: "Roles", value: counts.opportunities),
            RestoreCountRow(title: "Requirements", value: counts.requirements),
            RestoreCountRow(title: "Résumé versions", value: counts.resumes),
            RestoreCountRow(title: "Cover letters", value: counts.coverLetters),
            RestoreCountRow(title: "Application updates", value: counts.activities),
            RestoreCountRow(title: "Reminders", value: counts.reminders),
            RestoreCountRow(title: "Answers", value: counts.answers),
            RestoreCountRow(title: "Practice sessions", value: counts.practiceSessions),
            RestoreCountRow(title: "Interview reflections", value: counts.reflections)
        ].filter { $0.value > 0 }
    }
}

private struct RestoreCountRow: Identifiable {
    var id: String { title }
    let title: String
    let value: Int
}

private struct RestoreSummaryRow: View {
    let title: String
    let value: Int
    let symbol: String
    let colour: Color

    var body: some View {
        HStack {
            Label(title, systemImage: symbol)
                .foregroundStyle(BrandTheme.ink)
            Spacer()
            Text(value.formatted())
                .font(.rrHeadline)
                .foregroundStyle(colour)
        }
        .accessibilityElement(children: .combine)
    }
}

private func workspaceRestoreMessage(for error: Error) -> String {
    if let restoreError = error as? WorkspaceRestoreError {
        return restoreError.localizedDescription
    }
    return "RoleReady couldn’t restore that export. Your current workspace was not changed. Try exporting it again."
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
