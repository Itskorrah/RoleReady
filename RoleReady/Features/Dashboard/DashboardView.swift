import SwiftData
import SwiftUI

struct DashboardView: View {
    @Environment(AppRouter.self) private var router
    @Environment(AppState.self) private var appState
    @Query(sort: \CareerProfile.updatedAt, order: .reverse) private var profiles: [CareerProfile]
    @Query(sort: \Experience.updatedAt, order: .reverse) private var experiences: [Experience]
    @Query(sort: \Opportunity.updatedAt, order: .reverse) private var opportunities: [Opportunity]
    @Query(sort: \GeneratedAnswer.updatedAt, order: .reverse) private var answers: [GeneratedAnswer]
    @Query(sort: \PracticeSession.practisedAt, order: .reverse) private var practiceSessions: [PracticeSession]
    @Query(sort: \InterviewReflection.updatedAt, order: .reverse) private var reflections: [InterviewReflection]

    private let scorer = EvidenceScorer()

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: RRSpacing.xl) {
                welcome
                if experiences.isEmpty, opportunities.isEmpty {
                    activationCard
                } else {
                    if let activeOpportunity {
                        interviewHero(activeOpportunity)
                    } else if let opportunityToReflect {
                        reflectionHero(opportunityToReflect)
                    }
                    readinessOverview
                    nextBestAction
                    recentStories
                }
            }
            .padding(.horizontal, RRSpacing.md)
            .padding(.top, RRSpacing.sm)
            .padding(.bottom, RRSpacing.xxl)
            .frame(maxWidth: 920)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("Today")
        .screenBackground()
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    router.navigate(to: .profile)
                } label: {
                    AvatarView(name: profile?.name ?? "")
                }
                .accessibilityLabel("Open profile")
                .accessibilityIdentifier("open-profile")
            }
            ToolbarItemGroup(placement: .secondaryAction) {
                Button("Insights", systemImage: "chart.bar.xaxis") { router.navigate(to: .insights) }
                Button("Settings", systemImage: "gearshape") { router.navigate(to: .settings) }
            }
        }
    }

    private var profile: CareerProfile? { profiles.first }

    private var activeOpportunity: Opportunity? {
        OpportunityPlanner().activeOpportunity(from: opportunities)
    }

    private var opportunityToReflect: Opportunity? {
        OpportunityPlanner().latestUnreflectedInterview(
            from: opportunities,
            reflectedOpportunityIDs: Set(reflections.filter { reflection in
                !reflection.questions.isEmpty
                    || !reflection.experienceIDs.isEmpty
                    || !reflection.strongestMoment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    || !reflection.difficultMoment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    || !reflection.feedback.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    || !reflection.nextImprovement.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }.map(\.opportunityID))
        )
    }

    private var welcome: some View {
        VStack(alignment: .leading, spacing: RRSpacing.xs) {
            HStack(spacing: RRSpacing.xs) {
                Text(greeting)
                    .font(.rrCaption)
                    .tracking(0.8)
                    .foregroundStyle(BrandTheme.violet)
                if appState.isUsingSampleWorkspace {
                    Text("SAMPLE")
                        .font(.caption2.bold())
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(BrandTheme.amberSoft, in: Capsule())
                        .accessibilityLabel("Sample workspace")
                }
            }
            Text(displayName.isEmpty ? "Build an answer from something real." : "Ready for what’s next, \(firstName)?")
                .font(.rrHero)
                .fixedSize(horizontal: false, vertical: true)
            Text(todaySummary)
                .font(.rrBody)
                .foregroundStyle(BrandTheme.inkMuted)
        }
    }

    private var activationCard: some View {
        EmptyStatePanel(
            title: "Start with one useful story",
            message: "Choose a project, challenge, achievement, or mistake you learnt from. Guided prompts will shape the facts into evidence you can reuse.",
            symbol: "square.stack.3d.up.fill",
            actionTitle: "Capture my first story",
            action: { appState.presentedSheet = .addStory }
        )
        .accessibilityIdentifier("dashboard-empty")
    }

    private func interviewHero(_ opportunity: Opportunity) -> some View {
        Button {
            router.navigate(to: .prepDeck(opportunity.id))
        } label: {
            VStack(alignment: .leading, spacing: RRSpacing.lg) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: RRSpacing.xs) {
                        Label(opportunity.status.title, systemImage: opportunity.status.symbol)
                            .font(.rrCaption)
                            .foregroundStyle(.white.opacity(0.82))
                        Text(opportunity.roleTitle)
                            .font(.system(.title, design: .rounded, weight: .bold))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.leading)
                        Text(opportunity.organisation)
                            .font(.rrBody)
                            .foregroundStyle(.white.opacity(0.82))
                    }
                    Spacer(minLength: RRSpacing.md)
                    Image(systemName: "arrow.up.right")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(RRSpacing.sm)
                        .background(.white.opacity(0.15), in: Circle())
                }

                HStack(spacing: RRSpacing.lg) {
                    if let interviewDate = opportunity.interviewDate {
                        HeroMetric(value: relativeDate(interviewDate), label: interviewDate.formatted(date: .abbreviated, time: .shortened))
                    } else if let closingDate = opportunity.closingDate {
                        HeroMetric(value: relativeDate(closingDate), label: "Closes \(closingDate.formatted(date: .abbreviated, time: .omitted))")
                    }
                    HeroMetric(value: "\(confirmedAnswerCount(for: opportunity))", label: "answers ready")
                    HeroMetric(value: "\(practiceCount(for: opportunity))", label: "practice runs")
                }

                Label("Open pre-interview prep deck", systemImage: "rectangle.stack.fill")
                    .font(.rrHeadline)
                    .foregroundStyle(.white)
            }
            .padding(RRSpacing.lg)
            .background(BrandTheme.heroGradient, in: RoundedRectangle(cornerRadius: RRRadius.hero, style: .continuous))
            .shadow(color: BrandTheme.violet.opacity(0.24), radius: 22, y: 12)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("active-role-card")
    }

    private func reflectionHero(_ opportunity: Opportunity) -> some View {
        Button {
            router.navigate(to: .reflection(opportunity.id))
        } label: {
            HStack(alignment: .top, spacing: RRSpacing.md) {
                Image(systemName: "square.and.pencil")
                    .font(.title2)
                    .foregroundStyle(BrandTheme.violet)
                    .frame(width: 48, height: 48)
                    .background(BrandTheme.violetSoft, in: RoundedRectangle(cornerRadius: RRRadius.small))
                VStack(alignment: .leading, spacing: RRSpacing.xs) {
                    Text("WHILE IT’S FRESH")
                        .font(.rrCaption)
                        .tracking(0.8)
                        .foregroundStyle(BrandTheme.violet)
                    Text("Reflect on your \(opportunity.roleTitle) interview")
                        .font(.rrTitle)
                        .foregroundStyle(BrandTheme.ink)
                        .multilineTextAlignment(.leading)
                    Text("Capture the questions, stories you used, and one improvement for next time.")
                        .font(.rrBody)
                        .foregroundStyle(BrandTheme.inkMuted)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .foregroundStyle(BrandTheme.inkMuted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardSurface(tint: BrandTheme.amberSoft.opacity(0.55))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("interview-reflection-card")
    }

    private var readinessOverview: some View {
        VStack(alignment: .leading, spacing: RRSpacing.md) {
            SectionHeading(title: "Your preparation", eyebrow: "AT A GLANCE", actionTitle: "Insights") {
                router.navigate(to: .insights)
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: RRSpacing.sm)], spacing: RRSpacing.sm) {
                DashboardMetric(
                    value: "\(experiences.filter { scorer.score($0).readiness == .ready }.count)",
                    label: "stories ready",
                    symbol: "checkmark.seal.fill",
                    tint: BrandTheme.success
                )
                DashboardMetric(
                    value: "\(Set(experiences.flatMap(\.capabilities)).count)/\(Capability.allCases.count)",
                    label: "capabilities covered",
                    symbol: "circle.hexagongrid.fill",
                    tint: BrandTheme.violet
                )
                DashboardMetric(
                    value: "\(currentApprovedAnswers.count)",
                    label: "answers confirmed",
                    symbol: "text.badge.checkmark",
                    tint: BrandTheme.amberText
                )
            }
        }
    }

    @ViewBuilder
    private var nextBestAction: some View {
        if let item = storyToStrengthen {
            VStack(alignment: .leading, spacing: RRSpacing.md) {
                SectionHeading(title: "One useful next step", eyebrow: "COACHING")
                Button {
                    appState.presentedSheet = .editStory(item.experience.id)
                } label: {
                    HStack(alignment: .top, spacing: RRSpacing.md) {
                        EvidenceScoreRing(score: item.score, size: 58)
                        VStack(alignment: .leading, spacing: RRSpacing.xs) {
                            Text(item.experience.title)
                                .font(.rrHeadline)
                                .foregroundStyle(BrandTheme.ink)
                                .multilineTextAlignment(.leading)
                            Text(item.score.nextPrompt ?? "Review the story and confirm the facts.")
                                .font(.rrBody)
                                .foregroundStyle(BrandTheme.inkMuted)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                            Label("Strengthen this story", systemImage: "arrow.right")
                                .font(.rrCaption)
                                .foregroundStyle(BrandTheme.violet)
                        }
                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .cardSurface(tint: BrandTheme.amberSoft.opacity(0.56))
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private var recentStories: some View {
        if !experiences.isEmpty {
            VStack(alignment: .leading, spacing: RRSpacing.md) {
                SectionHeading(title: "Recent stories", actionTitle: "See all") {
                    appState.selectedTab = .evidence
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: RRSpacing.sm) {
                        ForEach(experiences.prefix(5)) { experience in
                            Button {
                                router.navigate(to: .experience(experience.id))
                            } label: {
                                StoryMiniCard(experience: experience, score: scorer.score(experience))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.viewAligned)
                .contentMargins(.horizontal, 1, for: .scrollContent)
            }
        }
    }

    private var storyToStrengthen: (experience: Experience, score: EvidenceScore)? {
        experiences
            .map { ($0, scorer.score($0)) }
            .filter { $0.1.readiness != .ready }
            .sorted { $0.1.total > $1.1.total }
            .first
    }

    private var displayName: String { profile?.name.trimmingCharacters(in: .whitespacesAndNewlines) ?? "" }
    private var firstName: String { displayName.split(separator: " ").first.map(String.init) ?? "there" }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        return hour < 12 ? "GOOD MORNING" : (hour < 17 ? "GOOD AFTERNOON" : "GOOD EVENING")
    }

    private var todaySummary: String {
        if let activeOpportunity, let date = activeOpportunity.interviewDate {
            return "Your next interview is \(relativeDate(date).lowercased()). Focus on recall, not memorisation."
        }
        if experiences.isEmpty { return "Capture one recent piece of work and let the evidence lead." }
        return "Your evidence bank is building. Strengthen one story or add a role when you’re ready."
    }

    private func relativeDate(_ date: Date) -> String {
        let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()), to: Calendar.current.startOfDay(for: date)).day ?? 0
        if days == 0 { return "Today" }
        if days == 1 { return "Tomorrow" }
        if days > 1 { return "In \(days) days" }
        return date.formatted(date: .abbreviated, time: .omitted)
    }

    private func confirmedAnswerCount(for opportunity: Opportunity) -> Int {
        currentApprovedAnswers.filter { $0.opportunityID == opportunity.id }.count
    }

    private var currentApprovedAnswers: [GeneratedAnswer] {
        let sources = Dictionary(uniqueKeysWithValues: experiences.map { ($0.id, $0) })
        let roles = Dictionary(uniqueKeysWithValues: opportunities.map { ($0.id, $0) })
        return answers.filter {
            $0.isApprovalCurrent(
                for: sources[$0.experienceID],
                opportunity: $0.opportunityID.flatMap { roles[$0] }
            )
        }
    }

    private func practiceCount(for opportunity: Opportunity) -> Int {
        let answerIDs = Set(answers.filter { $0.opportunityID == opportunity.id }.map(\.id))
        return practiceSessions.filter {
            $0.opportunityID == opportunity.id
                || ($0.opportunityID == nil && answerIDs.contains($0.answerID))
        }.count
    }
}

private struct AvatarView: View {
    let name: String

    var body: some View {
        Text(initials)
            .font(.system(.caption, design: .rounded, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 34, height: 34)
            .background(BrandTheme.violet, in: Circle())
            .overlay {
                Circle().stroke(BrandTheme.amber, lineWidth: 2)
            }
    }

    private var initials: String {
        let words = name.split(separator: " ")
        let value = words.prefix(2).compactMap(\.first).map(String.init).joined()
        return value.isEmpty ? "RR" : value.uppercased()
    }
}

private struct HeroMetric: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(.headline, design: .rounded, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(label)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.72))
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct DashboardMetric: View {
    let value: String
    let label: String
    let symbol: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: RRSpacing.sm) {
            Image(systemName: symbol)
                .font(.headline)
                .foregroundStyle(tint)
                .frame(width: 38, height: 38)
                .background(tint.opacity(0.11), in: RoundedRectangle(cornerRadius: RRRadius.small))
            Text(value)
                .font(.system(.title2, design: .rounded, weight: .bold))
            Text(label)
                .font(.subheadline)
                .foregroundStyle(BrandTheme.inkMuted)
        }
        .frame(maxWidth: .infinity, minHeight: 116, alignment: .leading)
        .cardSurface(padding: RRSpacing.md)
        .accessibilityElement(children: .combine)
    }
}

private struct StoryMiniCard: View {
    let experience: Experience
    let score: EvidenceScore

    var body: some View {
        VStack(alignment: .leading, spacing: RRSpacing.md) {
            HStack {
                Image(systemName: experience.kind.symbol)
                    .foregroundStyle(BrandTheme.violet)
                Spacer()
                ReadinessBadge(readiness: score.readiness)
            }
            Text(experience.title)
                .font(.rrHeadline)
                .foregroundStyle(BrandTheme.ink)
                .multilineTextAlignment(.leading)
                .lineLimit(3)
            Text(experience.organisation)
                .font(.subheadline)
                .foregroundStyle(BrandTheme.inkMuted)
                .lineLimit(1)
            Spacer(minLength: 0)
            ConfidentialityBadge(level: experience.confidentiality)
        }
        .frame(width: 240, height: 196, alignment: .leading)
        .cardSurface()
    }
}
