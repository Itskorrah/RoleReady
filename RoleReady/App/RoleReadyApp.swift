import SwiftData
import SwiftUI

@main
@MainActor
struct RoleReadyApp: App {
    @State private var appState = AppState()
    @State private var appLock = AppLockController()

    private let modelContainer: ModelContainer?
    private let startupError: String?

    init() {
        ExportService().removeTemporaryExports()
        do {
            let schema = Schema([
                CareerProfile.self,
                CareerSource.self,
                CareerSourceSpan.self,
                CareerPosition.self,
                CareerEducation.self,
                CareerCertification.self,
                CareerSkill.self,
                Experience.self,
                Opportunity.self,
                JobRequirement.self,
                ResumeVersion.self,
                CoverLetter.self,
                ApplicationActivity.self,
                CareerReminder.self,
                GeneratedAnswer.self,
                PracticeSession.self,
                InterviewReflection.self
            ])
            let configuration = ModelConfiguration(
                "RoleReady",
                schema: schema,
                isStoredInMemoryOnly: ProcessInfo.processInfo.arguments.contains("--ui-testing")
            )
            modelContainer = try ModelContainer(for: schema, configurations: [configuration])
            startupError = nil
        } catch {
            modelContainer = nil
            startupError = error.localizedDescription
        }
    }

    var body: some Scene {
        WindowGroup {
            if let modelContainer {
                SecureRootView()
                    .modelContainer(modelContainer)
                    .environment(appState)
                    .environment(appLock)
                    .tint(BrandTheme.violet)
            } else {
                DataRecoveryView(detail: startupError ?? "The local database could not be opened.")
            }
        }
    }
}

private struct SecureRootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(AppLockController.self) private var appLock
    @Environment(AppState.self) private var appState

    var body: some View {
        ZStack {
            if appLock.state.isUnlocked {
                if appState.hasCompletedOnboarding {
                    AppShell()
                } else {
                    OnboardingView()
                }
            } else {
                LockView()
            }

            if appLock.isPrivacyShieldVisible {
                PrivacyShieldView()
                    .transition(.opacity)
                    .zIndex(20)
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                Task { await appLock.sceneBecameActive() }
            case .inactive, .background:
                appLock.sceneBecameInactive()
            @unknown default:
                appLock.sceneBecameInactive()
            }
        }
    }
}

private struct LockView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppLockController.self) private var appLock
    @Environment(AppState.self) private var appState

    @State private var isConfirmingReset = false
    @State private var resetError: String?

    var body: some View {
        VStack(spacing: RRSpacing.lg) {
            Spacer()
            RoleReadyMark(size: 78)
            VStack(spacing: RRSpacing.xs) {
                Text("Your evidence is locked")
                    .font(.rrHero)
                    .multilineTextAlignment(.center)
                Text("Use Face ID, Touch ID, or your device passcode to continue.")
                    .font(.rrBody)
                    .foregroundStyle(BrandTheme.inkMuted)
                    .multilineTextAlignment(.center)
            }
            if case .unavailable(let message) = appLock.state {
                InfoBanner(title: "Device authentication unavailable", message: message, kind: .warning)
            }
            Button {
                Task { await appLock.unlock() }
            } label: {
                Label(appLock.state == .unlocking ? "Unlocking…" : "Unlock RoleReady", systemImage: "faceid")
            }
            .buttonStyle(PrimaryActionButtonStyle())
            .disabled(appLock.state == .unlocking)
            .accessibilityIdentifier("unlock-role-ready")
            if isAuthenticationUnavailable {
                Button("Reset local data", role: .destructive) {
                    isConfirmingReset = true
                }
                .font(.rrHeadline)
                .accessibilityHint("Permanently deletes the locked RoleReady workspace")
            }
            Spacer()
            Text("RoleReady never receives your biometric or passcode data.")
                .font(.footnote)
                .foregroundStyle(BrandTheme.inkMuted)
                .multilineTextAlignment(.center)
        }
        .padding(RRSpacing.lg)
        .screenBackground()
        .confirmationDialog(
            "Reset this locked workspace?",
            isPresented: $isConfirmingReset,
            titleVisibility: .visible
        ) {
            Button("Delete all local data", role: .destructive, action: resetWorkspace)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Use this only if device authentication is no longer available. Every RoleReady story, role, answer, and setting on this device will be permanently deleted.")
        }
        .alert("Workspace could not be reset", isPresented: Binding(
            get: { resetError != nil },
            set: { if !$0 { resetError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(resetError ?? "Try again.")
        }
    }

    private var isAuthenticationUnavailable: Bool {
        if case .unavailable = appLock.state { return true }
        return false
    }

    private func resetWorkspace() {
        do {
            NotificationService().cancelAllReminders()
            ExportService().removeTemporaryExports()
            try SeedService().deleteAll(from: modelContext)
            appLock.resetAfterDataDeletion()
            appState.resetAfterDataDeletion()
        } catch {
            resetError = error.localizedDescription
        }
    }
}

private struct PrivacyShieldView: View {
    var body: some View {
        ZStack {
            BrandTheme.canvas.ignoresSafeArea()
            VStack(spacing: RRSpacing.md) {
                RoleReadyMark(size: 60)
                Text("Private by default")
                    .font(.rrTitle)
                Text("Your career evidence is hidden while RoleReady is inactive.")
                    .font(.rrBody)
                    .foregroundStyle(BrandTheme.inkMuted)
                    .multilineTextAlignment(.center)
            }
            .padding(RRSpacing.xl)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("RoleReady content hidden for privacy")
    }
}

private struct DataRecoveryView: View {
    let detail: String

    var body: some View {
        VStack(spacing: RRSpacing.lg) {
            RoleReadyMark(size: 72)
            Text("RoleReady needs attention")
                .font(.rrHero)
                .multilineTextAlignment(.center)
            Text("Your local data was not changed. Close and reopen the app, then try again.")
                .font(.rrBody)
                .foregroundStyle(BrandTheme.inkMuted)
                .multilineTextAlignment(.center)
            DisclosureGroup("Technical detail") {
                Text(detail)
                    .font(.footnote.monospaced())
                    .textSelection(.enabled)
                    .padding(.top, RRSpacing.xs)
            }
            .cardSurface()
        }
        .padding(RRSpacing.lg)
        .screenBackground()
    }
}
