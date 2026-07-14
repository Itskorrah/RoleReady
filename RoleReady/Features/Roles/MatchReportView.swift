import SwiftData
import SwiftUI

@MainActor
struct MatchReportView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppRouter.self) private var router
    @Environment(AppState.self) private var appState

    let opportunityID: UUID

    @Query private var opportunities: [Opportunity]
    @Query private var requirements: [JobRequirement]
    @Query(sort: \Experience.updatedAt, order: .reverse)
    private var experiences: [Experience]

    @State private var loadState: MatchReportLoadState = .loading

    init(opportunityID: UUID) {
        self.opportunityID = opportunityID
        let id = opportunityID
        _opportunities = Query(
            filter: #Predicate<Opportunity> { opportunity in
                opportunity.id == id
            }
        )
        _requirements = Query(
            filter: #Predicate<JobRequirement> { requirement in
                requirement.opportunityID == id
            },
            sort: [
                SortDescriptor(\JobRequirement.importance, order: .reverse),
                SortDescriptor(\JobRequirement.createdAt)
            ]
        )
    }

    init(opportunity: Opportunity) {
        self.init(opportunityID: opportunity.id)
    }

    var body: some View {
        Group {
            switch loadState {
            case .loading:
                loadingState
            case .failed(let message):
                errorState(message)
            case .loaded(let reports):
                loadedState(reports)
            }
        }
        .navigationTitle("Evidence match")
        .navigationBarTitleDisplayMode(.inline)
        .screenBackground()
        .task(id: dataSignature) {
            await buildReport()
        }
        .accessibilityIdentifier("matchReport.root")
    }

    private var dataSignature: String {
        let opportunityRevision = opportunities.first.map {
            "\($0.id.uuidString):\($0.updatedAt.timeIntervalSinceReferenceDate)"
        } ?? "missing"
        let requirementRevision = requirements.map {
            "\($0.id.uuidString):\($0.isConfirmed):\($0.importance):\($0.kindRaw):\($0.text):\($0.capabilityRaw):\($0.keywordsRaw)"
        }.joined(separator: "|")
        let experienceRevision = experiences.map {
            "\($0.id.uuidString):\($0.updatedAt.timeIntervalSinceReferenceDate):\($0.isApprovedForMatching):\($0.confidentialityRaw)"
        }.joined(separator: "|")
        return [opportunityRevision, requirementRevision, experienceRevision].joined(separator: "::")
    }

    @ViewBuilder
    private func loadedState(_ reports: [RequirementEvidenceReport]) -> some View {
        if let opportunity = opportunities.first {
            let confirmedRequirements = requirements.filter(\.isConfirmed)
            if confirmedRequirements.isEmpty {
                noRequirementsState(opportunity)
            } else if experiences.isEmpty {
                noEvidenceState(opportunity)
            } else {
                reportContent(opportunity: opportunity, reports: reports)
            }
        } else {
            errorState("This role no longer exists. It may have been deleted while the report was open.")
        }
    }

    private func reportContent(
        opportunity: Opportunity,
        reports: [RequirementEvidenceReport]
    ) -> some View {
        let experiencesByID = Dictionary(uniqueKeysWithValues: experiences.map { ($0.id, $0) })
        return ScrollView {
            LazyVStack(alignment: .leading, spacing: RRSpacing.lg) {
                MatchReportSummary(opportunity: opportunity, reports: reports)

                InfoBanner(
                    title: "A match is evidence, not a verdict",
                    message: "RoleReady compares verified detail and capabilities with this requirement. The result describes your evidence—not your chance of being hired.",
                    kind: .information
                )

                if reports.allSatisfy({ $0.matches.isEmpty }) {
                    InfoBanner(
                        title: "No evidence is currently eligible",
                        message: "Your saved stories are either excluded from matching or marked highly sensitive. Review their privacy and matching settings, or add a new story.",
                        kind: .warning
                    )
                }

                VStack(alignment: .leading, spacing: RRSpacing.md) {
                    SectionHeading(
                        title: "What the role needs",
                        eyebrow: "\(reports.count) reviewed"
                    )
                    Text("Open the reasoning to see why an example ranked first, then compare the alternatives before using it in an answer.")
                        .font(.rrBody)
                        .foregroundStyle(BrandTheme.inkMuted)
                        .fixedSize(horizontal: false, vertical: true)

                    ForEach(reports) { report in
                        if let requirement = requirements.first(where: { $0.id == report.requirementID }) {
                            RequirementMatchCard(
                                requirement: requirement,
                                matches: report.matches,
                                experiencesByID: experiencesByID,
                                onOpenExperience: { experienceID in
                                    router.navigate(to: .experience(experienceID))
                                },
                                onBuildAnswer: { experienceID in
                                    router.navigate(
                                        to: .answerStudioForRequirement(
                                            experienceID: experienceID,
                                            opportunityID: opportunity.id,
                                            question: interviewQuestion(for: requirement)
                                        )
                                    )
                                }
                            )
                            .accessibilityIdentifier("matchReport.requirement.\(requirement.id.uuidString)")
                        }
                    }
                }
            }
            .padding(.horizontal, RRSpacing.md)
            .padding(.vertical, RRSpacing.lg)
            .frame(maxWidth: 920)
            .frame(maxWidth: .infinity)
        }
        .accessibilityIdentifier("matchReport.loaded")
    }

    private var loadingState: some View {
        ScrollView {
            VStack(spacing: RRSpacing.md) {
                RoundedRectangle(cornerRadius: RRRadius.hero, style: .continuous)
                    .fill(BrandTheme.surface)
                    .frame(height: 245)
                ForEach(0..<3, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: RRRadius.large, style: .continuous)
                        .fill(BrandTheme.surface)
                        .frame(height: 180)
                }
            }
            .padding(RRSpacing.md)
            .redacted(reason: .placeholder)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Building evidence match report")
        .accessibilityIdentifier("matchReport.loading")
    }

    private func errorState(_ message: String) -> some View {
        ContentUnavailableView {
            Label("Match report unavailable", systemImage: "exclamationmark.triangle.fill")
        } description: {
            Text(message)
        } actions: {
            Button("Try again") {
                Task { await buildReport() }
            }
            .buttonStyle(.borderedProminent)
            .tint(BrandTheme.violet)
            Button("Back") { dismiss() }
                .buttonStyle(.bordered)
        }
        .accessibilityIdentifier("matchReport.error")
    }

    private func noRequirementsState(_ opportunity: Opportunity) -> some View {
        ContentUnavailableView {
            Label("No confirmed requirements", systemImage: "checklist")
        } description: {
            Text("Review the advertisement for \(opportunity.roleTitle) and confirm at least one requirement before matching evidence.")
        } actions: {
            Button("Back to role") { dismiss() }
                .buttonStyle(.borderedProminent)
                .tint(BrandTheme.violet)
        }
        .accessibilityIdentifier("matchReport.requirements.empty")
    }

    private func noEvidenceState(_ opportunity: Opportunity) -> some View {
        EmptyStatePanel(
            title: "Your evidence bank is ready for its first story",
            message: "Add a real project, achievement or challenge. Then RoleReady can compare it with the requirements for \(opportunity.roleTitle).",
            symbol: "square.stack.3d.up.fill",
            actionTitle: "Add an evidence story"
        ) {
            appState.presentedSheet = .addStory
        }
        .padding(RRSpacing.md)
        .accessibilityIdentifier("matchReport.evidence.empty")
    }

    private func buildReport() async {
        loadState = .loading
        await Task.yield()
        guard !Task.isCancelled else { return }
        guard opportunities.first != nil else {
            loadState = .failed("This role could not be found.")
            return
        }

        let matcher = EvidenceMatcher()
        let confirmedRequirements = requirements.filter(\.isConfirmed)
        let reports = confirmedRequirements.map { requirement in
            RequirementEvidenceReport(
                requirementID: requirement.id,
                importance: requirement.importance,
                matches: matcher.rank(requirement: requirement, against: experiences)
            )
        }
        guard !Task.isCancelled else { return }
        loadState = .loaded(reports)
    }

    private func interviewQuestion(for requirement: JobRequirement) -> String {
        let text = requirement.text.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: ".!?"))
        guard let first = text.first else {
            return "Tell me about an example that demonstrates this requirement."
        }
        let normalised = first.uppercased() + String(text.dropFirst())
        return "What example best demonstrates your fit for this requirement: \(normalised)?"
    }
}

private enum MatchReportLoadState {
    case loading
    case loaded([RequirementEvidenceReport])
    case failed(String)
}

private struct RequirementEvidenceReport: Identifiable {
    let requirementID: UUID
    let importance: Int
    let matches: [EvidenceMatch]

    var id: UUID { requirementID }

    var tier: MatchTier {
        matches.first?.tier ?? .none
    }
}

private struct MatchReportSummary: View {
    let opportunity: Opportunity
    let reports: [RequirementEvidenceReport]

    private var directCount: Int {
        reports.reduce(into: 0) { count, report in
            if case .direct = report.tier { count += 1 }
        }
    }

    private var transferableCount: Int {
        reports.reduce(into: 0) { count, report in
            if case .transferable = report.tier { count += 1 }
        }
    }

    private var weakCount: Int {
        reports.reduce(into: 0) { count, report in
            if case .weak = report.tier { count += 1 }
        }
    }

    private var noneCount: Int {
        reports.reduce(into: 0) { count, report in
            if case .none = report.tier { count += 1 }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: RRSpacing.lg) {
            HStack(alignment: .center, spacing: RRSpacing.md) {
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(.title, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 58, height: 58)
                    .background(.white.opacity(0.16), in: RoundedRectangle(cornerRadius: RRRadius.medium))
                VStack(alignment: .leading, spacing: RRSpacing.xs) {
                    Text("HONEST EVIDENCE VIEW")
                        .font(.rrCaption)
                        .tracking(0.9)
                        .foregroundStyle(Color.white.opacity(0.76))
                    Text(opportunity.roleTitle.isEmpty ? "Role match" : opportunity.roleTitle)
                        .font(.rrTitle)
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                    if !opportunity.organisation.isEmpty {
                        Text(opportunity.organisation)
                            .font(.rrBody)
                            .foregroundStyle(Color.white.opacity(0.82))
                    }
                }
                Spacer(minLength: 0)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 118), spacing: RRSpacing.sm)], spacing: RRSpacing.sm) {
                summaryMetrics
            }
        }
        .padding(RRSpacing.lg)
        .background(BrandTheme.heroGradient, in: RoundedRectangle(cornerRadius: RRRadius.hero, style: .continuous))
        .shadow(color: BrandTheme.violet.opacity(0.20), radius: 22, y: 11)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Evidence summary. \(directCount) direct, \(transferableCount) transferable, \(weakCount) weak or partial, \(noneCount) with no verified evidence.")
    }

    @ViewBuilder
    private var summaryMetrics: some View {
        MatchSummaryMetric(value: directCount, label: "Direct", colour: BrandTheme.success)
        MatchSummaryMetric(value: transferableCount, label: "Transferable", colour: BrandTheme.teal)
        MatchSummaryMetric(value: weakCount, label: "Weak / partial", colour: BrandTheme.amber)
        MatchSummaryMetric(value: noneCount, label: "No evidence", colour: .white)
    }
}

private struct MatchSummaryMetric: View {
    let value: Int
    let label: String
    let colour: Color

    var body: some View {
        VStack(alignment: .leading, spacing: RRSpacing.xxs) {
            Text("\(value)")
                .font(.system(.title3, design: .rounded, weight: .bold))
            Text(label)
                .font(.rrCaption)
                .lineLimit(2)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
        .padding(RRSpacing.sm)
        .background(colour.opacity(0.18), in: RoundedRectangle(cornerRadius: RRRadius.small, style: .continuous))
    }
}

private struct RequirementMatchCard: View {
    let requirement: JobRequirement
    let matches: [EvidenceMatch]
    let experiencesByID: [UUID: Experience]
    let onOpenExperience: (UUID) -> Void
    let onBuildAnswer: (UUID) -> Void

    @State private var isReasoningExpanded = false
    @State private var areAlternativesExpanded = false

    private var bestMatch: EvidenceMatch? { matches.first }
    private var alternatives: [EvidenceMatch] { Array(matches.dropFirst().prefix(3)) }

    var body: some View {
        VStack(alignment: .leading, spacing: RRSpacing.md) {
            requirementHeader

            Divider().overlay(BrandTheme.separator)

            if let bestMatch, let experience = experiencesByID[bestMatch.experienceID] {
                bestEvidence(match: bestMatch, experience: experience)
            } else {
                evidenceGap(
                    title: "No approved evidence found",
                    message: "None of your matching-approved stories can support this requirement yet. Add a real example or keep this visible as an honest gap."
                )
            }

            if !alternatives.isEmpty {
                DisclosureGroup(isExpanded: $areAlternativesExpanded) {
                    VStack(spacing: RRSpacing.xs) {
                        ForEach(alternatives) { match in
                            if let experience = experiencesByID[match.experienceID] {
                                AlternativeEvidenceRow(
                                    match: match,
                                    experience: experience
                                ) {
                                    onOpenExperience(experience.id)
                                }
                            }
                        }
                    }
                    .padding(.top, RRSpacing.sm)
                } label: {
                    Label("Compare alternatives", systemImage: "arrow.triangle.branch")
                        .font(.rrHeadline)
                        .foregroundStyle(BrandTheme.ink)
                }
                .tint(BrandTheme.violet)
                .accessibilityIdentifier("matchReport.alternatives.\(requirement.id.uuidString)")
            }
        }
        .cardSurface()
    }

    private var requirementHeader: some View {
        VStack(alignment: .leading, spacing: RRSpacing.sm) {
            HStack {
                Text(requirement.kind.title)
                    .font(.rrCaption)
                    .foregroundStyle(requirementColour)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .background(requirementColour.opacity(0.11), in: Capsule())
                Spacer()
                Label(importanceLabel, systemImage: "flag.fill")
                    .font(.rrCaption)
                    .foregroundStyle(BrandTheme.inkMuted)
            }
            Text(requirement.text)
                .font(.rrHeadline)
                .foregroundStyle(BrandTheme.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(requirement.kind.title), \(importanceLabel) importance. \(requirement.text)")
    }

    @ViewBuilder
    private func bestEvidence(match: EvidenceMatch, experience: Experience) -> some View {
        VStack(alignment: .leading, spacing: RRSpacing.md) {
            HStack(alignment: .top, spacing: RRSpacing.sm) {
                Image(systemName: experience.kind.symbol)
                    .font(.headline)
                    .foregroundStyle(BrandTheme.violet)
                    .frame(width: 38, height: 38)
                    .background(BrandTheme.violetSoft, in: RoundedRectangle(cornerRadius: RRRadius.small, style: .continuous))
                VStack(alignment: .leading, spacing: RRSpacing.xxs) {
                    Text("Best available evidence")
                        .font(.rrCaption)
                        .foregroundStyle(BrandTheme.inkMuted)
                    Text(experience.title)
                        .font(.rrHeadline)
                        .foregroundStyle(BrandTheme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    if !experience.organisation.isEmpty {
                        Text(experience.organisation)
                            .font(.rrCaption)
                            .foregroundStyle(BrandTheme.inkMuted)
                    }
                }
                Spacer(minLength: RRSpacing.xs)
                VStack(alignment: .trailing, spacing: RRSpacing.xs) {
                    MatchTierBadge(tier: match.tier)
                }
            }

            Text(match.explanation)
                .font(.rrBody)
                .foregroundStyle(BrandTheme.inkMuted)
                .fixedSize(horizontal: false, vertical: true)

            if !match.matchedCapabilities.isEmpty || !match.matchedTerms.isEmpty {
                matchSignals(match)
            }

            if match.tier == .weak || match.tier == .none {
                evidenceGap(
                    title: match.tier == .none ? "No verified evidence yet" : "Closest example, but not proof yet",
                    message: "Treat this as a prompt to capture stronger detail, not as permission to stretch the claim."
                )
            }

            if !match.cautions.isEmpty {
                VStack(alignment: .leading, spacing: RRSpacing.xs) {
                    Label("Before you use this story", systemImage: "exclamationmark.triangle.fill")
                        .font(.rrHeadline)
                        .foregroundStyle(BrandTheme.warning)
                    ForEach(match.cautions, id: \.self) { caution in
                        Label(caution, systemImage: "circle.fill")
                            .font(.rrCaption)
                            .foregroundStyle(BrandTheme.inkMuted)
                            .symbolRenderingMode(.monochrome)
                    }
                }
                .padding(RRSpacing.sm)
                .background(BrandTheme.amberSoft.opacity(0.65), in: RoundedRectangle(cornerRadius: RRRadius.small, style: .continuous))
            }

            DisclosureGroup(isExpanded: $isReasoningExpanded) {
                MatchReasoningView(factors: match.factors)
                    .padding(.top, RRSpacing.sm)
            } label: {
                Label("Why this ranked first", systemImage: "chart.bar.xaxis")
                    .font(.rrHeadline)
                    .foregroundStyle(BrandTheme.ink)
            }
            .tint(BrandTheme.violet)
            .accessibilityIdentifier("matchReport.reasoning.\(requirement.id.uuidString)")

            ViewThatFits(in: .horizontal) {
                HStack(spacing: RRSpacing.sm) {
                    evidenceActions(match: match, experience: experience)
                }
                VStack(spacing: RRSpacing.sm) {
                    evidenceActions(match: match, experience: experience)
                }
            }
        }
    }

    private func matchSignals(_ match: EvidenceMatch) -> some View {
        VStack(alignment: .leading, spacing: RRSpacing.xs) {
            if !match.matchedCapabilities.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: RRSpacing.xs) {
                        ForEach(match.matchedCapabilities) { capability in
                            CapabilityChip(capability: capability, selected: true)
                        }
                    }
                }
            }
            if !match.matchedTerms.isEmpty {
                Label(match.matchedTerms.prefix(6).joined(separator: " · "), systemImage: "text.magnifyingglass")
                    .font(.rrCaption)
                    .foregroundStyle(BrandTheme.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func evidenceGap(title: String, message: String) -> some View {
        HStack(alignment: .top, spacing: RRSpacing.sm) {
            Image(systemName: "circle.dashed")
                .font(.headline)
                .foregroundStyle(BrandTheme.inkMuted)
            VStack(alignment: .leading, spacing: RRSpacing.xxs) {
                Text(title)
                    .font(.rrHeadline)
                    .foregroundStyle(BrandTheme.ink)
                Text(message)
                    .font(.rrCaption)
                    .foregroundStyle(BrandTheme.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(RRSpacing.sm)
        .background(BrandTheme.surfaceMuted, in: RoundedRectangle(cornerRadius: RRRadius.small, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private var requirementColour: Color {
        switch requirement.kind {
        case .mustHave: BrandTheme.danger
        case .responsibility: BrandTheme.violet
        case .signal: BrandTheme.tealText
        }
    }

    private var importanceLabel: String {
        switch requirement.importance {
        case 3: "High"
        case 2: "Medium"
        default: "Supporting"
        }
    }

    @ViewBuilder
    private func evidenceActions(match: EvidenceMatch, experience: Experience) -> some View {
        Button {
            onOpenExperience(experience.id)
        } label: {
            Label("Open story", systemImage: "arrow.up.right.square")
        }
        .buttonStyle(.bordered)
        .tint(BrandTheme.violet)

        Button {
            onBuildAnswer(experience.id)
        } label: {
            Label("Build answer", systemImage: "wand.and.stars")
        }
        .buttonStyle(.borderedProminent)
        .tint(BrandTheme.violet)
        .disabled(!match.tier.allowsAnswer)
        .accessibilityHint(
            !match.tier.allowsAnswer
                ? "Capture stronger evidence before building an answer"
                : "Uses this story in the answer studio"
        )
    }
}

private struct AlternativeEvidenceRow: View {
    let match: EvidenceMatch
    let experience: Experience
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: RRSpacing.sm) {
                Image(systemName: experience.kind.symbol)
                    .foregroundStyle(BrandTheme.violet)
                    .frame(width: 32, height: 32)
                    .background(BrandTheme.violetSoft, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(experience.title)
                        .font(.rrHeadline)
                        .foregroundStyle(BrandTheme.ink)
                        .lineLimit(2)
                    Text(match.explanation)
                        .font(.rrCaption)
                        .foregroundStyle(BrandTheme.inkMuted)
                        .lineLimit(2)
                }
                Spacer(minLength: RRSpacing.xs)
                VStack(alignment: .trailing, spacing: RRSpacing.xs) {
                    MatchTierBadge(tier: match.tier)
                }
            }
            .padding(RRSpacing.sm)
            .background(BrandTheme.canvasRaised, in: RoundedRectangle(cornerRadius: RRRadius.small, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Alternative: \(experience.title), \(match.tier.title)")
    }
}

private struct MatchReasoningView: View {
    let factors: MatchFactors

    var body: some View {
        VStack(alignment: .leading, spacing: RRSpacing.sm) {
            factorRow("Shared language", value: factors.lexical)
            factorRow("Capability fit", value: factors.capability)
            factorRow("Tool overlap", value: factors.tools)
            factorRow("Story readiness", value: factors.readiness)
            factorRow("Recency", value: factors.recency)
            factorRow("Personal ownership", value: factors.ownership)
            Text("These signals are weighted by the on-device matcher. You still decide whether the story is truthful and persuasive for this requirement.")
                .font(.caption2)
                .foregroundStyle(BrandTheme.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func factorRow(_ title: String, value: Double) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(title)
                    .font(.rrCaption)
                    .foregroundStyle(BrandTheme.ink)
                Spacer()
                Text("\(Int((value * 100).rounded()))%")
                    .font(.caption2.monospacedDigit().weight(.semibold))
                    .foregroundStyle(BrandTheme.inkMuted)
            }
            ProgressView(value: value)
                .tint(factorColour(value))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(Int((value * 100).rounded())) percent")
    }

    private func factorColour(_ value: Double) -> Color {
        if value >= 0.7 { return BrandTheme.success }
        if value >= 0.4 { return BrandTheme.amberText }
        return BrandTheme.violet
    }
}
