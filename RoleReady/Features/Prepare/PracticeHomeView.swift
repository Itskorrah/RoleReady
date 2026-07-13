import SwiftData
import SwiftUI

struct PracticeHomeView: View {
    @Environment(AppRouter.self) private var router
    @Environment(AppState.self) private var appState
    @Query(sort: \GeneratedAnswer.updatedAt, order: .reverse) private var answers: [GeneratedAnswer]
    @Query(sort: \Opportunity.updatedAt, order: .reverse) private var opportunities: [Opportunity]
    @Query(sort: \Experience.updatedAt, order: .reverse) private var experiences: [Experience]
    @Query(sort: \PracticeSession.practisedAt, order: .reverse) private var sessions: [PracticeSession]

    @State private var searchText = ""

    var body: some View {
        let visibleAnswers = filteredAnswers

        ScrollView {
            LazyVStack(alignment: .leading, spacing: RRSpacing.xl) {
                intro
                if let activeOpportunity { activeRoleCard(activeOpportunity) }
                if visibleAnswers.isEmpty {
                    EmptyStatePanel(
                        title: searchText.isEmpty ? "Build your first answer" : "No answers match that search",
                        message: searchText.isEmpty
                            ? "Choose a real story, shape it for one interview question, then approve the facts for practice."
                            : "Try the role, capability, or a phrase from the question.",
                        symbol: searchText.isEmpty ? "quote.bubble" : "magnifyingglass",
                        actionTitle: searchText.isEmpty ? "Create an answer" : nil,
                        action: searchText.isEmpty ? { router.navigate(to: .answerStudio(experienceID: nil, opportunityID: activeOpportunity?.id)) } : nil
                    )
                } else {
                    answerLibrary(visibleAnswers)
                }
            }
            .padding(.horizontal, RRSpacing.md)
            .padding(.top, RRSpacing.sm)
            .padding(.bottom, RRSpacing.xxl)
            .frame(maxWidth: 920)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("Practise")
        .searchable(text: $searchText, prompt: "Questions, roles, or stories")
        .screenBackground()
        .accessibilityIdentifier("practice-home")
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: RRSpacing.xs) {
            Text("PREPARE TO RECALL")
                .font(.rrCaption)
                .tracking(0.8)
                .foregroundStyle(BrandTheme.violet)
            Text("Prompts, not scripts.")
                .font(.rrHero)
            Text("Practise the shape of your story so the words still sound like you.")
                .font(.rrBody)
                .foregroundStyle(BrandTheme.inkMuted)
        }
    }

    private func activeRoleCard(_ opportunity: Opportunity) -> some View {
        let readyAnswers = confirmedAnswers(for: opportunity)
        let completedRuns = sessionCount(for: opportunity)

        VStack(alignment: .leading, spacing: RRSpacing.md) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: RRSpacing.xxs) {
                    Text("ACTIVE PREP DECK")
                        .font(.rrCaption)
                        .tracking(0.8)
                        .foregroundStyle(BrandTheme.amberText)
                    Text(opportunity.roleTitle)
                        .font(.rrTitle)
                    Text(opportunity.organisation)
                        .font(.subheadline)
                        .foregroundStyle(BrandTheme.inkMuted)
                }
                Spacer()
                Image(systemName: "rectangle.stack.fill")
                    .foregroundStyle(BrandTheme.violet)
                    .font(.title2)
            }

            HStack(spacing: RRSpacing.sm) {
                Label("\(readyAnswers.count) ready", systemImage: "checkmark.seal.fill")
                Label("\(completedRuns) runs", systemImage: "timer")
            }
            .font(.rrCaption)
            .foregroundStyle(BrandTheme.inkMuted)

            Button {
                router.navigate(to: .prepDeck(opportunity.id))
            } label: {
                Label("Start a 5-minute practice", systemImage: "play.fill")
            }
            .buttonStyle(PrimaryActionButtonStyle())
            .disabled(readyAnswers.isEmpty)
        }
        .cardSurface(tint: BrandTheme.violetSoft.opacity(0.56))
    }

    private func answerLibrary(_ visibleAnswers: [GeneratedAnswer]) -> some View {
        let experiencesByID = Dictionary(uniqueKeysWithValues: experiences.map { ($0.id, $0) })
        let opportunitiesByID = Dictionary(uniqueKeysWithValues: opportunities.map { ($0.id, $0) })
        let opportunityTitles = Dictionary(uniqueKeysWithValues: opportunities.map { ($0.id, $0.roleTitle) })

        return VStack(alignment: .leading, spacing: RRSpacing.md) {
            SectionHeading(title: "Answer library", eyebrow: "\(visibleAnswers.count) SAVED", actionTitle: "New answer") {
                router.navigate(to: .answerStudio(experienceID: nil, opportunityID: activeOpportunity?.id))
            }
            ForEach(visibleAnswers) { answer in
                Button {
                    router.navigate(to: .editAnswer(answer.id))
                } label: {
                    AnswerLibraryRow(
                        answer: answer,
                        experienceTitle: experiencesByID[answer.experienceID]?.title ?? "Story unavailable",
                        opportunityTitle: answer.opportunityID.flatMap { opportunityTitles[$0] } ?? "General preparation",
                        isReady: answer.isApprovalCurrent(
                            for: experiencesByID[answer.experienceID],
                            opportunity: answer.opportunityID.flatMap { opportunitiesByID[$0] }
                        )
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var activeOpportunity: Opportunity? {
        OpportunityPlanner().activeOpportunity(from: opportunities)
    }

    private var filteredAnswers: [GeneratedAnswer] {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return answers }
        let query = searchText.lowercased()
        let experienceTitles = Dictionary(uniqueKeysWithValues: experiences.map { ($0.id, $0.title.lowercased()) })
        let opportunityTitles = Dictionary(uniqueKeysWithValues: opportunities.map { ($0.id, $0.roleTitle.lowercased()) })
        return answers.filter { answer in
            answer.question.lowercased().contains(query)
                || answer.content.lowercased().contains(query)
                || experienceTitles[answer.experienceID, default: ""].contains(query)
                || answer.opportunityID.map { opportunityTitles[$0, default: ""].contains(query) } == true
        }
    }

    private func confirmedAnswers(for opportunity: Opportunity) -> [GeneratedAnswer] {
        let sources = Dictionary(uniqueKeysWithValues: experiences.map { ($0.id, $0) })
        let roles = Dictionary(uniqueKeysWithValues: opportunities.map { ($0.id, $0) })
        return answers.filter {
            $0.opportunityID == opportunity.id
                && $0.isApprovalCurrent(for: sources[$0.experienceID], opportunity: roles[opportunity.id])
        }
    }

    private func sessionCount(for opportunity: Opportunity) -> Int {
        let ids = Set(answers.filter { $0.opportunityID == opportunity.id }.map(\.id))
        return sessions.filter {
            $0.opportunityID == opportunity.id
                || ($0.opportunityID == nil && ids.contains($0.answerID))
        }.count
    }

}

private struct AnswerLibraryRow: View {
    let answer: GeneratedAnswer
    let experienceTitle: String
    let opportunityTitle: String
    let isReady: Bool

    var body: some View {
        HStack(alignment: .top, spacing: RRSpacing.md) {
            Image(systemName: isReady ? "checkmark.seal.fill" : "doc.text")
                .foregroundStyle(isReady ? BrandTheme.success : BrandTheme.warning)
                .font(.headline)
                .frame(width: 42, height: 42)
                .background((isReady ? BrandTheme.success : BrandTheme.warning).opacity(0.10), in: RoundedRectangle(cornerRadius: RRRadius.small))
            VStack(alignment: .leading, spacing: RRSpacing.xs) {
                Text(answer.question)
                    .font(.rrHeadline)
                    .foregroundStyle(BrandTheme.ink)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Text(experienceTitle)
                    .font(.subheadline)
                    .foregroundStyle(BrandTheme.inkMuted)
                    .lineLimit(2)
                HStack(spacing: RRSpacing.xs) {
                    Text(answer.format.title)
                    Text("·")
                    Text(isReady ? "Ready for practice" : "Needs reconfirmation")
                    Text("·")
                    Text(opportunityTitle)
                }
                .font(.rrCaption)
                .foregroundStyle(isReady ? BrandTheme.success : BrandTheme.inkMuted)
                .lineLimit(1)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundStyle(BrandTheme.inkMuted)
                .padding(.top, RRSpacing.xs)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens answer studio")
    }
}
