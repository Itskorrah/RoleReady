import SwiftUI
import UIKit

struct AppShell: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var appState = appState

        TabView(selection: $appState.selectedTab) {
            ForEach(AppTab.allCases) { tab in
                Tab(tab.title, systemImage: tab.symbol, value: tab) {
                    TabRoot(tab: tab)
                }
            }
        }
        .privacySensitive()
        .sheet(item: $appState.presentedSheet) { destination in
            switch destination {
            case .prepareForRole:
                PreparationFlowView()
            case .addStory:
                ExperienceEditorView()
            case .editStory(let id):
                ExperienceEditorView(experienceID: id)
            case .addRole:
                RoleEditorView()
            case .addQuestion:
                NavigationStack {
                    AnswerStudioView(showsCloseButton: true)
                }
            }
        }
        .overlay(alignment: .top) {
            if let toast = appState.toast {
                ToastView(message: toast)
                    .padding(.top, RRSpacing.sm)
                    .padding(.horizontal, RRSpacing.md)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(10)
            }
        }
        .task(id: appState.toast?.id) {
            guard let toast = appState.toast else { return }
            UIAccessibility.post(notification: .announcement, argument: toast.title)
            let displaySeconds = UIAccessibility.isVoiceOverRunning ? 5.0 : 2.4
            try? await Task.sleep(for: .seconds(displaySeconds))
            guard !Task.isCancelled else { return }
            withAnimation(reduceMotion ? nil : .snappy) { appState.toast = nil }
        }
        .onChange(of: appState.selectedTab) { _, _ in
            HapticService.selection(enabled: appState.hapticsEnabled)
        }
    }
}

private struct TabRoot: View {
    let tab: AppTab
    @State private var router = AppRouter()
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var router = router

        NavigationStack(path: $router.path) {
            rootContent
                .navigationDestination(for: AppRoute.self, destination: destination)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        ComposeMenu()
                    }
                }
        }
        .environment(router)
    }

    @ViewBuilder
    private var rootContent: some View {
        switch tab {
        case .prepare: DashboardView()
        case .examples: EvidenceListView()
        case .practise: PracticeHomeView()
        }
    }

    @ViewBuilder
    private func destination(_ route: AppRoute) -> some View {
        switch route {
        case .experience(let id): ExperienceDetailView(experienceID: id)
        case .opportunity(let id): RoleDetailView(opportunityID: id)
        case .matchReport(let id): MatchReportView(opportunityID: id)
        case .answerStudio(let experienceID, let opportunityID):
            AnswerStudioView(experienceID: experienceID, opportunityID: opportunityID)
        case .answerStudioForRequirement(let experienceID, let opportunityID, let question):
            AnswerStudioView(
                experienceID: experienceID,
                opportunityID: opportunityID,
                initialQuestion: question
            )
        case .editAnswer(let answerID):
            AnswerStudioView(answerID: answerID)
        case .prepDeck(let opportunityID): PrepDeckView(opportunityID: opportunityID)
        case .reflection(let opportunityID): InterviewReflectionView(opportunityID: opportunityID)
        case .roles: RoleListView()
        case .profile: ProfileView()
        case .insights: InsightsView()
        case .settings: SettingsView()
        case .privacy: PrivacyView()
        }
    }
}

private struct ComposeMenu: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        Menu {
            Button {
                appState.presentedSheet = .prepareForRole
            } label: {
                Label("Prepare for a role", systemImage: "target")
            }
            Button {
                appState.presentedSheet = .addStory
            } label: {
                Label("Capture a story", systemImage: "square.and.pencil")
            }
            Button {
                appState.presentedSheet = .addRole
            } label: {
                Label("Add a role", systemImage: "briefcase.badge.plus")
            }
            Button {
                appState.presentedSheet = .addQuestion
            } label: {
                Label("Add a question", systemImage: "text.bubble")
            }
        } label: {
            Image(systemName: "plus")
                .font(.headline)
                .frame(width: 44, height: 44)
                .roleReadyGlass(cornerRadius: 22, tint: BrandTheme.amber, interactive: true)
        }
        .accessibilityLabel("Prepare or add")
        .accessibilityHint("Prepare for a role, capture an example, or add a question")
        .accessibilityIdentifier("global-compose")
    }
}
