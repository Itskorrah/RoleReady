import SwiftData
import SwiftUI

@MainActor
struct EvidenceListView: View {
    @Environment(AppState.self) private var appState
    @Query(sort: \Experience.updatedAt, order: .reverse) private var experiences: [Experience]

    @State private var searchText = ""
    @State private var scope: EvidenceListScope = .all

    private let scorer = EvidenceScorer()

    var body: some View {
        let summaries = makeSummaries()
        let filteredSummaries = filter(summaries)

        List {
            if !summaries.isEmpty {
                EvidenceLibraryOverview(summaries: summaries)
                    .listRowInsets(.init(top: RRSpacing.sm, leading: RRSpacing.md, bottom: RRSpacing.md, trailing: RRSpacing.md))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .accessibilityIdentifier("evidence.overview")
            }

            if filteredSummaries.isEmpty {
                emptyState
                    .listRowInsets(.init(top: RRSpacing.sm, leading: RRSpacing.md, bottom: RRSpacing.lg, trailing: RRSpacing.md))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            } else {
                Section {
                    ForEach(filteredSummaries) { summary in
                        NavigationLink(value: AppRoute.experience(summary.experience.id)) {
                            EvidenceRow(summary: summary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(summary.experience.title)
                        .accessibilityIdentifier("evidence.link.\(summary.experience.id.uuidString)")
                        .listRowInsets(.init(top: RRSpacing.xs, leading: RRSpacing.md, bottom: RRSpacing.xs, trailing: RRSpacing.md))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button {
                                appState.presentedSheet = .editStory(summary.experience.id)
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            .tint(BrandTheme.violet)
                        }
                    }
                } header: {
                    Text(resultHeader(count: filteredSummaries.count))
                        .font(.rrCaption)
                        .foregroundStyle(BrandTheme.inkMuted)
                        .textCase(nil)
                        .accessibilityIdentifier("evidence.resultCount")
                }
            }
        }
        .frame(maxWidth: 900)
        .frame(maxWidth: .infinity)
        .listStyle(.plain)
        .environment(\.defaultMinListRowHeight, 1)
        .scrollContentBackground(.hidden)
        .screenBackground()
        .navigationTitle("My Examples")
        .searchable(
            text: $searchText,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "Projects, skills, tools or outcomes"
        )
        .searchScopes($scope) {
            ForEach(EvidenceListScope.allCases) { option in
                Text(option.title).tag(option)
            }
        }
        .accessibilityIdentifier("evidence.list")
    }

    private func makeSummaries() -> [EvidenceListSummary] {
        experiences.map { experience in
            EvidenceListSummary(experience: experience, score: scorer.score(experience))
        }
    }

    private func filter(_ summaries: [EvidenceListSummary]) -> [EvidenceListSummary] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        return summaries.filter { summary in
            scope.includes(summary) && (query.isEmpty || summary.experience.searchableText.localizedStandardContains(query))
        }
    }

    private func resultHeader(count: Int) -> String {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || scope != .all else {
            return count == 1 ? "1 story" : "\(count) stories"
        }
        return count == 1 ? "1 matching story" : "\(count) matching stories"
    }

    @ViewBuilder
    private var emptyState: some View {
        if experiences.isEmpty {
            EmptyStatePanel(
                title: "Start with one real story",
                message: "Capture a project, achievement, difficult problem or lesson. RoleReady will help you turn it into a reusable example.",
                symbol: "square.stack.3d.up",
                actionTitle: "Add your first story"
            ) {
                appState.presentedSheet = .addStory
            }
            .accessibilityIdentifier("evidence.empty")
        } else if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            EmptyStatePanel(
                title: "No matching examples",
                message: "Try an organisation, capability, tool, result or a broader phrase.",
                symbol: "magnifyingglass",
                actionTitle: "Clear search"
            ) {
                searchText = ""
            }
            .accessibilityIdentifier("evidence.noSearchResults")
        } else {
            EmptyStatePanel(
                title: "Nothing in this view",
                message: scope.emptyMessage,
                symbol: scope.symbol,
                actionTitle: "Show all examples"
            ) {
                scope = .all
            }
            .accessibilityIdentifier("evidence.noFilteredResults")
        }
    }
}

private enum EvidenceListScope: String, CaseIterable, Identifiable {
    case all
    case ready
    case strengthen
    case unused

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: "All"
        case .ready: "Ready"
        case .strengthen: "Strengthen"
        case .unused: "Unused"
        }
    }

    var symbol: String {
        switch self {
        case .all: "square.stack.3d.up"
        case .ready: "checkmark.seal"
        case .strengthen: "hammer"
        case .unused: "arrow.counterclockwise"
        }
    }

    var emptyMessage: String {
        switch self {
        case .all: "Add a story to begin building your example library."
        case .ready: "No stories are ready yet. Open one to see the most useful next improvement."
        case .strengthen: "Every story in your bank is ready to use."
        case .unused: "You have already reused every story at least once."
        }
    }

    func includes(_ summary: EvidenceListSummary) -> Bool {
        switch self {
        case .all: true
        case .ready: summary.score.readiness == .ready
        case .strengthen: summary.score.readiness != .ready
        case .unused: summary.experience.useCount == 0
        }
    }
}

private struct EvidenceListSummary: Identifiable {
    let experience: Experience
    let score: EvidenceScore

    var id: UUID { experience.id }
}

private struct EvidenceLibraryOverview: View {
    let summaries: [EvidenceListSummary]

    private var readyCount: Int {
        summaries.filter { $0.score.readiness == .ready }.count
    }

    private var averageScore: Int {
        guard !summaries.isEmpty else { return 0 }
        return Int((Double(summaries.reduce(0) { $0 + $1.score.total }) / Double(summaries.count)).rounded())
    }

    private var usedCount: Int {
        summaries.filter { $0.experience.useCount > 0 }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: RRSpacing.md) {
            SectionHeading(
                title: "Your reusable proof",
                eyebrow: "Example library"
            )

            Text("Search what you have done, strengthen the missing detail, then reuse only the facts you approve.")
                .font(.rrBody)
                .foregroundStyle(BrandTheme.inkMuted)
                .fixedSize(horizontal: false, vertical: true)

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 105), spacing: RRSpacing.sm)],
                alignment: .leading,
                spacing: RRSpacing.sm
            ) {
                EvidenceMetric(value: "\(summaries.count)", label: "Stories")
                EvidenceMetric(value: "\(readyCount)", label: "Ready")
                EvidenceMetric(value: "\(averageScore)", label: "Avg score")
                EvidenceMetric(value: "\(usedCount)", label: "Reused")
            }
        }
        .cardSurface(tint: BrandTheme.canvasRaised)
    }
}

private struct EvidenceMetric: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: RRSpacing.xxs) {
            Text(value)
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(BrandTheme.ink)
                .contentTransition(.numericText())
            Text(label)
                .font(.rrCaption)
                .foregroundStyle(BrandTheme.inkMuted)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label): \(value)")
    }
}

private struct EvidenceRow: View {
    let summary: EvidenceListSummary

    private var experience: Experience { summary.experience }

    private var capabilitySummary: String {
        let names = experience.capabilities.prefix(3).map(\.title)
        guard !names.isEmpty else { return "Capabilities not tagged yet" }
        return names.joined(separator: ", ")
    }

    var body: some View {
        HStack(alignment: .top, spacing: RRSpacing.md) {
            EvidenceScoreRing(score: summary.score, size: 58)
                .padding(.top, RRSpacing.xxs)

            VStack(alignment: .leading, spacing: RRSpacing.xs) {
                Text(experience.title)
                    .font(.rrHeadline)
                    .foregroundStyle(BrandTheme.ink)
                    .lineLimit(2)

                Text("\(experience.organisation) | \(experience.occurredAt.formatted(.dateTime.month(.abbreviated).year()))")
                    .font(.subheadline)
                    .foregroundStyle(BrandTheme.inkMuted)
                    .lineLimit(1)

                HStack(spacing: RRSpacing.xs) {
                    ReadinessBadge(readiness: summary.score.readiness)
                    ConfidentialityBadge(level: experience.confidentiality)
                    Spacer(minLength: 0)
                }

                Label(capabilitySummary, systemImage: experience.kind.symbol)
                    .font(.rrCaption)
                    .foregroundStyle(BrandTheme.inkMuted)
                    .lineLimit(2)

                if experience.useCount > 0 {
                    Label(
                        experience.useCount == 1 ? "Used once" : "Used \(experience.useCount) times",
                        systemImage: "arrow.trianglehead.2.clockwise.rotate.90"
                    )
                    .font(.rrCaption)
                    .foregroundStyle(BrandTheme.tealText)
                }
            }

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(BrandTheme.inkMuted.opacity(0.65))
                .padding(.top, RRSpacing.xs)
                .accessibilityHidden(true)
        }
        .cardSurface()
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
        .accessibilityHint("Opens the saved example")
        .accessibilityIdentifier("evidence.row.\(experience.id.uuidString)")
    }

    private var accessibilitySummary: String {
        [
            experience.title,
            summary.score.readiness.title,
            "score \(summary.score.total) out of 100",
            experience.organisation,
            "privacy \(experience.confidentiality.title)"
        ]
        .joined(separator: ", ")
    }
}
