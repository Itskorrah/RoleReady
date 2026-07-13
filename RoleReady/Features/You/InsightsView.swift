import SwiftData
import SwiftUI

struct InsightsView: View {
    @Query(sort: \Experience.updatedAt, order: .reverse) private var experiences: [Experience]
    @Query(sort: \Opportunity.updatedAt, order: .reverse) private var opportunities: [Opportunity]
    @Query(sort: \GeneratedAnswer.updatedAt, order: .reverse) private var answers: [GeneratedAnswer]
    @Query(sort: \PracticeSession.practisedAt, order: .reverse) private var sessions: [PracticeSession]

    private let scorer = EvidenceScorer()

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: RRSpacing.xl) {
                intro
                if experiences.isEmpty {
                    EmptyStatePanel(
                        title: "Insights grow from your stories",
                        message: "Capture two or three pieces of evidence to see coverage, readiness, and practice patterns.",
                        symbol: "chart.bar.xaxis"
                    )
                } else {
                    readinessSection
                    capabilityCoverage
                    usefulObservations
                }
            }
            .padding(RRSpacing.md)
            .padding(.bottom, RRSpacing.xxl)
            .frame(maxWidth: 820)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("Insights")
        .navigationBarTitleDisplayMode(.inline)
        .screenBackground()
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: RRSpacing.xs) {
            Text("EVIDENCE COVERAGE")
                .font(.rrCaption)
                .tracking(0.8)
                .foregroundStyle(BrandTheme.violet)
            Text("Know where your proof is strong—and what to capture next.")
                .font(.rrHero)
            Text("These are preparation signals, not a score of your employability.")
                .font(.rrBody)
                .foregroundStyle(BrandTheme.inkMuted)
        }
    }

    private var readinessSection: some View {
        VStack(alignment: .leading, spacing: RRSpacing.md) {
            SectionHeading(title: "Story readiness")
            HStack(spacing: RRSpacing.md) {
                readinessMetric(.ready, tint: BrandTheme.success)
                readinessMetric(.nearlyReady, tint: BrandTheme.amberText)
                readinessMetric(.building, tint: BrandTheme.violet)
            }
            .cardSurface()
        }
    }

    private var capabilityCoverage: some View {
        VStack(alignment: .leading, spacing: RRSpacing.md) {
            SectionHeading(title: "Capability coverage", eyebrow: "\(coveredCapabilities.count) OF \(Capability.allCases.count)")
            VStack(spacing: RRSpacing.sm) {
                ForEach(sortedCapabilities, id: \.capability) { item in
                    CapabilityCoverageRow(capability: item.capability, count: item.count, maximum: maxCapabilityCount)
                }
            }
            .cardSurface()
        }
    }

    private var usefulObservations: some View {
        VStack(alignment: .leading, spacing: RRSpacing.md) {
            SectionHeading(title: "Useful observations")
            VStack(spacing: RRSpacing.sm) {
                observation(
                    title: strongestCapability.map { "Your strongest coverage is \($0.capability.title.lowercased())" } ?? "Your coverage is taking shape",
                    detail: strongestCapability.map { "You have \($0.count) stor\($0.count == 1 ? "y" : "ies") tagged to this capability." } ?? "Add capability tags to make matching more precise.",
                    symbol: "checkmark.seal.fill",
                    colour: BrandTheme.success
                )
                if let gap = nextGap {
                    observation(
                        title: "Capture one story about \(gap.title.lowercased())",
                        detail: "This capability has no direct example yet. A small, specific story is enough to start.",
                        symbol: "plus.circle.fill",
                        colour: BrandTheme.amberText
                    )
                }
                observation(
                    title: "\(currentApprovedAnswerCount) answers are approved for practice",
                    detail: sessions.isEmpty ? "A short practice run will create your first recall signal." : "You have completed \(sessions.count) practice run\(sessions.count == 1 ? "" : "s").",
                    symbol: "quote.bubble.fill",
                    colour: BrandTheme.violet
                )
            }
        }
    }

    private func readinessMetric(_ readiness: EvidenceReadiness, tint: Color) -> some View {
        let count = experiences.filter { scorer.score($0).readiness == readiness }.count
        return VStack(spacing: RRSpacing.xxs) {
            Text("\(count)")
                .font(.system(.title, design: .rounded, weight: .bold))
                .foregroundStyle(tint)
            Text(readiness.title)
                .font(.caption)
                .foregroundStyle(BrandTheme.inkMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private func observation(title: String, detail: String, symbol: String, colour: Color) -> some View {
        HStack(alignment: .top, spacing: RRSpacing.md) {
            Image(systemName: symbol)
                .foregroundStyle(colour)
                .font(.headline)
            VStack(alignment: .leading, spacing: RRSpacing.xxs) {
                Text(title).font(.rrHeadline)
                Text(detail).font(.subheadline).foregroundStyle(BrandTheme.inkMuted)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
    }

    private var capabilityCounts: [Capability: Int] {
        Dictionary(uniqueKeysWithValues: Capability.allCases.map { capability in
            (capability, experiences.filter { $0.capabilities.contains(capability) }.count)
        })
    }

    private var sortedCapabilities: [(capability: Capability, count: Int)] {
        capabilityCounts.map { ($0.key, $0.value) }.sorted { lhs, rhs in
            if lhs.1 == rhs.1 { return lhs.0.title < rhs.0.title }
            return lhs.1 > rhs.1
        }
    }

    private var currentApprovedAnswerCount: Int {
        let sources = Dictionary(uniqueKeysWithValues: experiences.map { ($0.id, $0) })
        let roles = Dictionary(uniqueKeysWithValues: opportunities.map { ($0.id, $0) })
        return answers.filter {
            $0.isApprovalCurrent(
                for: sources[$0.experienceID],
                opportunity: $0.opportunityID.flatMap { roles[$0] }
            )
        }.count
    }

    private var coveredCapabilities: [Capability] { capabilityCounts.filter { $0.value > 0 }.map(\.key) }
    private var maxCapabilityCount: Int { max(capabilityCounts.values.max() ?? 1, 1) }
    private var strongestCapability: (capability: Capability, count: Int)? { sortedCapabilities.first(where: { $0.count > 0 }) }
    private var nextGap: Capability? { sortedCapabilities.last(where: { $0.count == 0 })?.capability }
}

private struct CapabilityCoverageRow: View {
    let capability: Capability
    let count: Int
    let maximum: Int

    var body: some View {
        VStack(spacing: RRSpacing.xs) {
            HStack {
                Label(capability.title, systemImage: capability.symbol)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(count == 0 ? "No story yet" : "\(count) stor\(count == 1 ? "y" : "ies")")
                    .font(.rrCaption)
                    .foregroundStyle(count == 0 ? BrandTheme.warning : BrandTheme.inkMuted)
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(BrandTheme.surfaceMuted)
                    Capsule()
                        .fill(count == 0 ? BrandTheme.separator : BrandTheme.violet)
                        .frame(width: proxy.size.width * CGFloat(count) / CGFloat(max(maximum, 1)))
                }
            }
            .frame(height: 7)
        }
        .accessibilityElement(children: .combine)
    }
}
