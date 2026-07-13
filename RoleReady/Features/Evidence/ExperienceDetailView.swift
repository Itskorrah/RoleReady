import SwiftData
import SwiftUI

@MainActor
struct ExperienceDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppRouter.self) private var router
    @Environment(AppState.self) private var appState

    @Query private var experiences: [Experience]

    @State private var isConfirmingDeletion = false
    @State private var issue: ExperienceDetailIssue?

    private let experienceID: UUID
    private let scorer = EvidenceScorer()

    init(experienceID: UUID) {
        self.experienceID = experienceID
        let id = experienceID
        _experiences = Query(
            filter: #Predicate<Experience> { experience in
                experience.id == id
            }
        )
    }

    var body: some View {
        Group {
            if let experience {
                ExperienceDetailContent(
                    experience: experience,
                    score: scorer.score(experience),
                    buildAnswer: {
                        router.navigate(
                            to: .answerStudio(
                                experienceID: experience.id,
                                opportunityID: nil
                            )
                        )
                    }
                )
            } else {
                ContentUnavailableView {
                    Label("Story unavailable", systemImage: "square.stack.3d.up.slash")
                } description: {
                    Text("This evidence record may have been deleted from your bank.")
                }
                .accessibilityIdentifier("experienceDetail.missing")
            }
        }
        .screenBackground()
        .navigationTitle(experience?.title ?? "Evidence")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let experience {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Edit") {
                        appState.presentedSheet = .editStory(experience.id)
                    }
                    .fontWeight(.semibold)
                    .accessibilityIdentifier("experienceDetail.edit")
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button(role: .destructive) {
                            isConfirmingDeletion = true
                        } label: {
                            Label("Delete story", systemImage: "trash")
                        }
                    } label: {
                        Label("More actions", systemImage: "ellipsis.circle")
                    }
                    .accessibilityIdentifier("experienceDetail.more")
                }
            }
        }
        .confirmationDialog(
            "Delete this evidence story?",
            isPresented: $isConfirmingDeletion,
            titleVisibility: .visible
        ) {
            Button("Delete story", role: .destructive) {
                deleteExperience()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This also removes answers and practice runs grounded in this story. Role reflections keep their notes but no longer link to it.")
        }
        .alert(issue?.title ?? "Evidence", isPresented: Binding(
            get: { issue != nil },
            set: { if !$0 { issue = nil } }
        )) {
            Button("OK", role: .cancel) { issue = nil }
        } message: {
            Text(issue?.message ?? "Try again.")
        }
        .accessibilityIdentifier("experienceDetail.root")
    }

    private var experience: Experience? { experiences.first }

    private func deleteExperience() {
        guard let experience else { return }
        do {
            let answers = try modelContext.fetch(FetchDescriptor<GeneratedAnswer>())
                .filter { $0.experienceID == experience.id }
            let answerIDs = Set(answers.map(\.id))
            try modelContext.fetch(FetchDescriptor<PracticeSession>())
                .filter { answerIDs.contains($0.answerID) }
                .forEach(modelContext.delete)
            try modelContext.fetch(FetchDescriptor<InterviewReflection>())
                .filter { $0.experienceIDs.contains(experience.id) }
                .forEach { reflection in
                    reflection.experienceIDs = reflection.experienceIDs.filter { $0 != experience.id }
                    reflection.updatedAt = Date()
                }
            answers.forEach(modelContext.delete)
            modelContext.delete(experience)
            try modelContext.save()
            HapticService.success(enabled: appState.hapticsEnabled)
            appState.showToast("Evidence story deleted", symbol: "trash")
            if router.path.last == .experience(experienceID) {
                router.path.removeLast()
            }
        } catch {
            modelContext.rollback()
            issue = .deleteFailed(error.localizedDescription)
        }
    }
}

private enum ExperienceDetailIssue: Identifiable {
    case deleteFailed(String)

    var id: String {
        switch self {
        case .deleteFailed: "delete-failed"
        }
    }

    var title: String {
        switch self {
        case .deleteFailed: "Could not delete story"
        }
    }

    var message: String {
        switch self {
        case .deleteFailed(let detail):
            "Your story is still in the evidence bank. \(detail)"
        }
    }
}

private struct ExperienceDetailContent: View {
    let experience: Experience
    let score: EvidenceScore
    let buildAnswer: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: RRSpacing.lg) {
                ExperienceDetailHero(
                    experience: experience,
                    score: score,
                    buildAnswer: buildAnswer
                )

                if let nextPrompt = score.nextPrompt {
                    InfoBanner(
                        title: "Best next improvement",
                        message: nextPrompt,
                        kind: score.readiness == .ready ? .success : .information
                    )
                    .accessibilityIdentifier("experienceDetail.nextPrompt")
                }

                VStack(alignment: .leading, spacing: RRSpacing.sm) {
                    SectionHeading(title: "The story", eyebrow: "Stored facts")
                    ExperienceStoryCard(experience: experience)
                }

                VStack(alignment: .leading, spacing: RRSpacing.sm) {
                    SectionHeading(title: "Evidence strength", eyebrow: "Constructive score")
                    EvidenceScoreBreakdown(score: score)
                }

                VStack(alignment: .leading, spacing: RRSpacing.sm) {
                    SectionHeading(title: "Capabilities & tools", eyebrow: "Reusable signals")
                    ExperienceSignalsCard(experience: experience)
                }

                VStack(alignment: .leading, spacing: RRSpacing.sm) {
                    SectionHeading(title: "Source trail", eyebrow: "Provenance")
                    ExperienceProvenanceCard(experience: experience)
                }

                VStack(alignment: .leading, spacing: RRSpacing.sm) {
                    SectionHeading(title: "Privacy & matching", eyebrow: "Your control")
                    ExperiencePrivacyCard(experience: experience)
                }
            }
            .padding(.horizontal, RRSpacing.md)
            .padding(.top, RRSpacing.sm)
            .padding(.bottom, RRSpacing.xxl)
        }
        .scrollDismissesKeyboard(.immediately)
    }
}

private struct ExperienceDetailHero: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let experience: Experience
    let score: EvidenceScore
    let buildAnswer: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: RRSpacing.lg) {
            heroSummary

            Button(action: buildAnswer) {
                Label("Build an answer from this story", systemImage: "wand.and.stars")
            }
            .buttonStyle(PrimaryActionButtonStyle())
            .disabled(isBlockedForAnswer)
            .accessibilityIdentifier("experienceDetail.buildAnswer")

            if let privacyNotice {
                Label(
                    privacyNotice,
                    systemImage: "hand.raised.fill"
                )
                .font(.rrCaption)
                .foregroundStyle(BrandTheme.warning)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .cardSurface(padding: RRSpacing.lg, tint: BrandTheme.canvasRaised)
        .accessibilityIdentifier("experienceDetail.hero")
    }

    @ViewBuilder
    private var heroSummary: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: RRSpacing.md) {
                EvidenceScoreRing(score: score, size: 84)
                heading
            }
        } else {
            HStack(alignment: .top, spacing: RRSpacing.md) {
                EvidenceScoreRing(score: score, size: 84)
                heading
                Spacer(minLength: 0)
            }
        }
    }

    private var heading: some View {
        VStack(alignment: .leading, spacing: RRSpacing.xs) {
            Label(experience.kind.title, systemImage: experience.kind.symbol)
                .font(.rrCaption)
                .foregroundStyle(BrandTheme.violet)

            Text(experience.title)
                .font(.rrTitle)
                .foregroundStyle(BrandTheme.ink)
                .fixedSize(horizontal: false, vertical: true)

            Text("\(experience.organisation) | \(experience.occurredAt.formatted(.dateTime.month(.wide).year()))")
                .font(.subheadline)
                .foregroundStyle(BrandTheme.inkMuted)
                .fixedSize(horizontal: false, vertical: true)

            ReadinessBadge(readiness: score.readiness)
        }
    }

    private var isBlockedForAnswer: Bool {
        experience.confidentiality.blocksAutomaticUse && !experience.isApprovedForMatching
    }

    private var privacyNotice: String? {
        if isBlockedForAnswer {
            return "Edit this story and explicitly approve answer use before building from highly sensitive facts."
        }
        if experience.confidentiality.blocksAutomaticUse {
            return "Explicit answer use is approved, but this story remains excluded from automatic role matching. "
                + "Review every sensitive detail before sharing."
        }
        if !experience.isApprovedForMatching {
            return "Automatic matching is off. You can still choose this story manually when building an answer."
        }
        return nil
    }
}

private struct ExperienceStoryCard: View {
    let experience: Experience

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ExperienceFact(
                title: "Situation",
                source: "Situation",
                text: experience.situation,
                symbol: "map.fill"
            )
            StoryDivider()
            ExperienceFact(
                title: "Responsibility",
                source: "Responsibility",
                text: experience.task,
                symbol: "scope"
            )
            StoryDivider()
            ExperienceActionsFact(actions: experience.actions)
            StoryDivider()
            ExperienceFact(
                title: "Result",
                source: "Result",
                text: experience.result,
                symbol: "flag.checkered"
            )
            StoryDivider()
            ExperienceFact(
                title: "Proof",
                source: "Evidence",
                text: experience.evidence,
                symbol: "checkmark.seal.fill",
                missingMessage: "No verification captured yet"
            )
            StoryDivider()
            ExperienceFact(
                title: "Reflection",
                source: "Learning",
                text: experience.learning,
                symbol: "lightbulb.fill",
                missingMessage: "No reflection captured yet"
            )
        }
        .cardSurface(padding: 0)
        .accessibilityIdentifier("experienceDetail.story")
    }
}

private struct ExperienceFact: View {
    let title: String
    let source: String
    let text: String
    let symbol: String
    var missingMessage = "Not captured yet"

    private var isMissing: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: RRSpacing.xs) {
            HStack {
                Label(title, systemImage: symbol)
                    .font(.rrHeadline)
                    .foregroundStyle(BrandTheme.ink)
                Spacer(minLength: RRSpacing.sm)
                Text(source)
                    .font(.rrCaption)
                    .foregroundStyle(BrandTheme.violet)
                    .padding(.horizontal, RRSpacing.xs)
                    .padding(.vertical, RRSpacing.xxs)
                    .background(BrandTheme.violetSoft, in: Capsule())
                    .accessibilityLabel("Source field: \(source)")
            }

            Group {
                if isMissing {
                    Text(missingMessage).italic()
                } else {
                    Text(text)
                }
            }
            .font(.rrBody)
            .foregroundStyle(isMissing ? BrandTheme.warning : BrandTheme.inkMuted)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(RRSpacing.md)
    }
}

private struct ExperienceActionsFact: View {
    let actions: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: RRSpacing.sm) {
            HStack {
                Label("Actions", systemImage: "figure.run")
                    .font(.rrHeadline)
                Spacer(minLength: RRSpacing.sm)
                Text("Action")
                    .font(.rrCaption)
                    .foregroundStyle(BrandTheme.violet)
                    .padding(.horizontal, RRSpacing.xs)
                    .padding(.vertical, RRSpacing.xxs)
                    .background(BrandTheme.violetSoft, in: Capsule())
                    .accessibilityLabel("Source field: Action")
            }

            if actions.isEmpty {
                Text("No personal actions captured yet")
                    .font(.rrBody)
                    .foregroundStyle(BrandTheme.warning)
                    .italic()
            } else {
                ForEach(Array(actions.enumerated()), id: \.offset) { index, action in
                    HStack(alignment: .top, spacing: RRSpacing.sm) {
                        Text("\(index + 1)")
                            .font(.rrCaption)
                            .foregroundStyle(BrandTheme.violet)
                            .frame(width: 26, height: 26)
                            .background(BrandTheme.violetSoft, in: Circle())
                            .accessibilityHidden(true)

                        Text(action)
                            .font(.rrBody)
                            .foregroundStyle(BrandTheme.inkMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Action \(index + 1): \(action)")
                }
            }
        }
        .padding(RRSpacing.md)
    }
}

private struct StoryDivider: View {
    var body: some View {
        Divider()
            .overlay(BrandTheme.separator)
            .padding(.horizontal, RRSpacing.md)
    }
}

private struct EvidenceScoreBreakdown: View {
    let score: EvidenceScore

    var body: some View {
        VStack(alignment: .leading, spacing: RRSpacing.md) {
            HStack(spacing: RRSpacing.md) {
                EvidenceScoreRing(score: score, size: 72)
                VStack(alignment: .leading, spacing: RRSpacing.xs) {
                    ReadinessBadge(readiness: score.readiness)
                    Text("The score reflects the detail already stored. It is a coaching signal, not a judgement of your experience.")
                        .font(.subheadline)
                        .foregroundStyle(BrandTheme.inkMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Divider().overlay(BrandTheme.separator)

            ForEach(score.dimensions) { dimension in
                VStack(alignment: .leading, spacing: RRSpacing.xs) {
                    HStack {
                        Text(dimension.dimension.title)
                            .font(.rrHeadline)
                        Spacer(minLength: RRSpacing.sm)
                        Text("\(dimension.percentage)%")
                            .font(.rrCaption)
                            .foregroundStyle(scoreColour(for: dimension.value))
                            .monospacedDigit()
                    }

                    ProgressView(value: dimension.value)
                        .tint(scoreColour(for: dimension.value))

                    if dimension.value < 0.78 {
                        Text(dimension.guidance)
                            .font(.caption)
                            .foregroundStyle(BrandTheme.inkMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(dimension.dimension.title), \(dimension.percentage) percent")
                .accessibilityHint(dimension.value < 0.78 ? dimension.guidance : "This part of the story is strong")
            }
        }
        .cardSurface()
        .accessibilityIdentifier("experienceDetail.score")
    }

    private func scoreColour(for value: Double) -> Color {
        if value >= 0.78 { return BrandTheme.success }
        if value >= 0.55 { return BrandTheme.amberText }
        return BrandTheme.violet
    }
}

private struct ExperienceSignalsCard: View {
    let experience: Experience

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: RRSpacing.xs)]

    var body: some View {
        VStack(alignment: .leading, spacing: RRSpacing.md) {
            Text("Capabilities")
                .font(.rrHeadline)

            if experience.capabilities.isEmpty {
                MissingSignalLabel(text: "No capabilities tagged")
            } else {
                LazyVGrid(columns: columns, alignment: .leading, spacing: RRSpacing.xs) {
                    ForEach(experience.capabilities) { capability in
                        CapabilityChip(capability: capability)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }

            Divider().overlay(BrandTheme.separator)

            Text("Tools and methods")
                .font(.rrHeadline)

            if experience.tools.isEmpty {
                MissingSignalLabel(text: "No tools or methods captured")
            } else {
                LazyVGrid(columns: columns, alignment: .leading, spacing: RRSpacing.xs) {
                    ForEach(experience.tools, id: \.self) { tool in
                        Label(tool, systemImage: "wrench.and.screwdriver")
                            .font(.rrCaption)
                            .foregroundStyle(BrandTheme.ink)
                            .padding(.horizontal, RRSpacing.sm)
                            .padding(.vertical, RRSpacing.xs)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(BrandTheme.surfaceMuted, in: Capsule())
                    }
                }
            }
        }
        .cardSurface()
        .accessibilityIdentifier("experienceDetail.signals")
    }
}

private struct MissingSignalLabel: View {
    let text: String

    var body: some View {
        Label(text, systemImage: "plus.circle.dashed")
            .font(.subheadline)
            .foregroundStyle(BrandTheme.warning)
    }
}

private struct ExperienceProvenanceCard: View {
    let experience: Experience

    private var sourceFields: [ExperienceSourceField] {
        [
            ExperienceSourceField(title: "Story title", isPresent: !isBlank(experience.title)),
            ExperienceSourceField(title: "Situation", isPresent: !isBlank(experience.situation)),
            ExperienceSourceField(title: "Responsibility", isPresent: !isBlank(experience.task)),
            ExperienceSourceField(title: "Action", isPresent: !experience.actions.isEmpty),
            ExperienceSourceField(title: "Result", isPresent: !isBlank(experience.result)),
            ExperienceSourceField(title: "Evidence", isPresent: !isBlank(experience.evidence)),
            ExperienceSourceField(title: "Learning", isPresent: !isBlank(experience.learning))
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: RRSpacing.md) {
            InfoBanner(
                title: "Grounded at the source",
                message: "Generated claims point back to these named fields, so you can verify what was used and correct the record once.",
                kind: .information
            )

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 132), spacing: RRSpacing.xs)],
                alignment: .leading,
                spacing: RRSpacing.xs
            ) {
                ForEach(sourceFields) { field in
                    Label(
                        field.title,
                        systemImage: field.isPresent ? "checkmark.circle.fill" : "circle.dashed"
                    )
                    .font(.rrCaption)
                    .foregroundStyle(field.isPresent ? BrandTheme.success : BrandTheme.warning)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityLabel("\(field.title) source field, \(field.isPresent ? "captured" : "missing")")
                }
            }

            Divider().overlay(BrandTheme.separator)

            MetadataRow(
                label: "Created",
                value: experience.createdAt.formatted(date: .abbreviated, time: .omitted),
                symbol: "calendar.badge.plus"
            )
            MetadataRow(
                label: "Last updated",
                value: experience.updatedAt.formatted(date: .abbreviated, time: .shortened),
                symbol: "clock.arrow.circlepath"
            )
            MetadataRow(
                label: "Answer uses",
                value: "\(experience.useCount)",
                symbol: "arrow.trianglehead.2.clockwise.rotate.90"
            )
            MetadataRow(
                label: "Origin",
                value: experience.isSample ? "Sample workspace" : "Your evidence bank",
                symbol: experience.isSample ? "sparkles" : "person.crop.circle"
            )
        }
        .cardSurface()
        .accessibilityIdentifier("experienceDetail.provenance")
    }

    private func isBlank(_ value: String) -> Bool {
        value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

private struct ExperienceSourceField: Identifiable {
    let title: String
    let isPresent: Bool

    var id: String { title }
}

private struct MetadataRow: View {
    let label: String
    let value: String
    let symbol: String

    var body: some View {
        HStack(spacing: RRSpacing.sm) {
            Image(systemName: symbol)
                .foregroundStyle(BrandTheme.violet)
                .frame(width: 22)
                .accessibilityHidden(true)
            Text(label)
                .font(.subheadline)
                .foregroundStyle(BrandTheme.inkMuted)
            Spacer(minLength: RRSpacing.md)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(BrandTheme.ink)
                .multilineTextAlignment(.trailing)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label): \(value)")
    }
}

private struct ExperiencePrivacyCard: View {
    let experience: Experience

    var body: some View {
        VStack(alignment: .leading, spacing: RRSpacing.md) {
            HStack {
                ConfidentialityBadge(level: experience.confidentiality)
                Spacer(minLength: RRSpacing.sm)
                matchingBadge
            }

            Text(privacyExplanation)
                .font(.rrBody)
                .foregroundStyle(BrandTheme.inkMuted)
                .fixedSize(horizontal: false, vertical: true)

            Divider().overlay(BrandTheme.separator)

            Label("Stored locally on this device", systemImage: "iphone.gen3")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(BrandTheme.tealText)

            Text("RoleReady does not send this record to a remote account or analytics service. You decide when to use or export it.")
                .font(.caption)
                .foregroundStyle(BrandTheme.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .cardSurface(tint: privacyTint)
        .accessibilityIdentifier("experienceDetail.privacy")
    }

    private var matchingBadge: some View {
        Label(matchingTitle, systemImage: matchingSymbol)
            .font(.rrCaption)
            .foregroundStyle(canMatchAutomatically ? BrandTheme.success : BrandTheme.warning)
            .padding(.horizontal, RRSpacing.sm)
            .padding(.vertical, 7)
            .background(
                (canMatchAutomatically ? BrandTheme.success : BrandTheme.warning).opacity(0.11),
                in: Capsule()
            )
    }

    private var canMatchAutomatically: Bool {
        experience.isApprovedForMatching && !experience.confidentiality.blocksAutomaticUse
    }

    private var matchingTitle: String {
        canMatchAutomatically ? "Matching on" : "Matching off"
    }

    private var matchingSymbol: String {
        canMatchAutomatically ? "checkmark.circle.fill" : "nosign"
    }

    private var privacyExplanation: String {
        if experience.confidentiality.blocksAutomaticUse {
            if experience.isApprovedForMatching {
                return "This highly sensitive story is excluded from automatic role matching but approved for deliberate, "
                    + "manually selected answer use. Review every detail before sharing."
            }
            return "Highly sensitive stories are excluded from automatic role matching. "
                + "Explicitly approve and select this story before using any of its facts in an answer."
        }
        if !experience.isApprovedForMatching {
            return "This story stays in your bank but is excluded from automatic role matching until you approve it."
        }
        if experience.confidentiality >= .confidential {
            return "This story can be matched, but every generated answer will remind you to review names, "
                + "internal systems and identifying detail before sharing."
        }
        return "This story is approved for on-device matching. You can switch matching off at any time without deleting the record."
    }

    private var privacyTint: Color {
        canMatchAutomatically ? BrandTheme.surface : BrandTheme.amberSoft.opacity(0.46)
    }
}
