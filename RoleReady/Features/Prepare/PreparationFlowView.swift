import SwiftData
import SwiftUI
import UIKit

@MainActor
struct PreparationFlowView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState

    @Query(sort: \Experience.updatedAt, order: .reverse) private var experiences: [Experience]
    @Query(sort: \Opportunity.updatedAt, order: .reverse) private var opportunities: [Opportunity]
    @Query private var savedRequirements: [JobRequirement]

    @State private var step: PreparationStep = .career
    @State private var careerSource = ""
    @State private var importedCareerFilename: String?
    @State private var careerWarnings: [String] = []
    @State private var drafts: [CareerHistoryDraft] = []
    @State private var selectedDraftID: UUID?
    @State private var isAnalysingCareer = false
    @State private var isImportingCareer = false

    @State private var roleSource = ""
    @State private var roleTitle = ""
    @State private var roleOrganisation = ""
    @State private var importedRoleFilename: String?
    @State private var roleWarnings: [String] = []
    @State private var requirementDrafts: [PreparationRequirementDraft] = []
    @State private var selectedRequirementID: UUID?
    @State private var isAnalysingRole = false
    @State private var isImportingRole = false
    @State private var selectedExperienceID: UUID?
    @State private var explicitlySelectedSensitiveExperienceID: UUID?
    @State private var strengtheningDraft: ExperienceStrengtheningDraft?
    @State private var rankedMatchesCache: [EvidenceMatch] = []
    @State private var savedOpportunityID: UUID?
    @State private var answerQuestion = ""
    @State private var answerFormat: AnswerFormat = .sixtySeconds
    @State private var savedAnswerID: UUID?
    @State private var hasChosenRecommendation = false
    @State private var isSaving = false
    @State private var issue: PreparationIssue?
    @State private var showCloseConfirmation = false
    @AccessibilityFocusState private var isStepHeadingFocused: Bool
    @FocusState private var textFocus: PreparationTextFocus?

    var body: some View {
        NavigationStack {
            Group {
                switch step {
                case .career:
                    careerInputStep
                case .exampleReview:
                    exampleReviewStep
                case .role:
                    roleInputStep
                case .requirements:
                    requirementReviewStep
                case .match:
                    matchAndStrengthenStep
                case .answer:
                    answerStep
                case .practice:
                    practiceStep
                }
            }
            .navigationTitle(step.navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { flowToolbar }
            .screenBackground()
        }
        .interactiveDismissDisabled(step != .practice && (step != .career || hasUnsavedCareerInput))
        .confirmationDialog(
            "Close role preparation?",
            isPresented: $showCloseConfirmation,
            titleVisibility: .visible
        ) {
            Button("Close preparation", role: .destructive) { dismiss() }
            Button("Keep preparing", role: .cancel) {}
        } message: {
            Text(closeMessage)
        }
        .alert(item: $issue) { issue in
            Alert(
                title: Text(issue.title),
                message: Text(issue.message),
                dismissButton: .default(Text("OK"))
            )
        }
        .onChange(of: step) { _, _ in
            Task { @MainActor in
                await Task.yield()
                isStepHeadingFocused = true
            }
        }
        .accessibilityIdentifier("preparation-flow")
    }

    @ToolbarContentBuilder
    private var flowToolbar: some ToolbarContent {
        if step != .career && step != .answer && step != .practice {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    moveBack()
                } label: {
                    Label("Back", systemImage: "chevron.left")
                }
                .accessibilityIdentifier("preparation-back")
            }
        }
        ToolbarItem(placement: .cancellationAction) {
            Button("Close") {
                if step == .practice || (step == .career && !hasUnsavedCareerInput) {
                    dismiss()
                } else {
                    showCloseConfirmation = true
                }
            }
            .accessibilityIdentifier("preparation-close")
        }
        ToolbarItemGroup(placement: .keyboard) {
            Spacer()
            Button("Done") {
                textFocus = nil
                // Some progressive-disclosure editors are reusable child views
                // and do not share this FocusState. End whichever responder is
                // active so the keyboard action works consistently everywhere.
                UIApplication.shared.sendAction(
                    #selector(UIResponder.resignFirstResponder),
                    to: nil,
                    from: nil,
                    for: nil
                )
            }
        }
    }

    private var careerInputStep: some View {
        flowScroll {
            flowHeader(
                eyebrow: "1 · YOUR EXPERIENCE",
                title: "Start with what you already have",
                message: "Import a résumé, paste rough career notes, or describe one real example. Nothing becomes verified evidence until you review it."
            )

            trustStrip

            if !careerWarnings.isEmpty {
                InfoBanner(
                    title: "Check the imported history",
                    message: careerWarnings.joined(separator: "\n"),
                    kind: .warning
                )
            }

            VStack(alignment: .leading, spacing: RRSpacing.md) {
                HStack {
                    Label("Career history", systemImage: "doc.text.fill")
                        .font(.rrHeadline)
                    Spacer()
                    if let importedCareerFilename {
                        Text(importedCareerFilename)
                            .font(.rrCaption)
                            .foregroundStyle(BrandTheme.inkMuted)
                            .lineLimit(1)
                    }
                }

                ZStack(alignment: .topLeading) {
                    if careerSource.isEmpty {
                        Text("Paste a résumé, project notes, or a few bullet points about work you are proud of…")
                            .font(.rrBody)
                            .foregroundStyle(BrandTheme.inkMuted.opacity(0.72))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 9)
                            .allowsHitTesting(false)
                    }
                    TextEditor(text: $careerSource)
                        .font(.rrBody)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 220)
                        .focused($textFocus, equals: .careerHistory)
                        .accessibilityLabel("Career history text")
                        .accessibilityIdentifier("career-history-text")
                }
                .padding(RRSpacing.sm)
                .background(BrandTheme.canvasRaised, in: RoundedRectangle(cornerRadius: RRRadius.medium, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: RRRadius.medium, style: .continuous)
                        .stroke(BrandTheme.separator, lineWidth: 1)
                }

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: RRSpacing.sm) { careerSourceButtons }
                    VStack(spacing: RRSpacing.sm) { careerSourceButtons }
                }
            }
            .cardSurface()

            Button(action: analyseCareerHistory) {
                Label(
                    isAnalysingCareer ? "Finding potential examples…" : "Find potential examples",
                    systemImage: isAnalysingCareer ? "hourglass" : "sparkle.magnifyingglass"
                )
            }
            .buttonStyle(PrimaryActionButtonStyle())
            .disabled(isAnalysingCareer || isImportingCareer || careerSource.trimmingCharacters(in: .whitespacesAndNewlines).count < 24)
            .accessibilityIdentifier("analyse-career-history")

            Button {
                beginManualExample()
            } label: {
                Label("Describe one example instead", systemImage: "square.and.pencil")
            }
            .buttonStyle(SecondaryActionButtonStyle())
            .accessibilityIdentifier("describe-one-example")

            if !experiences.filter(\.isApprovedForMatching).isEmpty {
                DisclosureGroup("Use an example already in RoleReady") {
                    VStack(spacing: RRSpacing.xs) {
                        ForEach(experiences.filter(\.isApprovedForMatching).prefix(6)) { experience in
                            Button {
                                selectedExperienceID = experience.id
                                explicitlySelectedSensitiveExperienceID = experience.confidentiality.blocksAutomaticUse
                                    ? experience.id
                                    : nil
                                step = .role
                            } label: {
                                HStack {
                                    Image(systemName: experience.kind.symbol)
                                    Text(experience.title)
                                        .multilineTextAlignment(.leading)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                }
                            }
                            .buttonStyle(SecondaryActionButtonStyle())
                        }
                    }
                    .padding(.top, RRSpacing.sm)
                }
                .font(.rrHeadline)
                .cardSurface()
            }
        }
    }

    @ViewBuilder
    private var careerSourceButtons: some View {
        Button {
            presentDocumentPicker(for: .career)
        } label: {
            Label(isImportingCareer ? "Importing…" : "Choose résumé", systemImage: "doc.badge.plus")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(SecondaryActionButtonStyle())
        .disabled(isImportingCareer || isAnalysingCareer)
        .accessibilityIdentifier("import-career-document")

        Button {
            careerSource = ""
            importedCareerFilename = nil
            careerWarnings = []
        } label: {
            Label("Clear", systemImage: "xmark.circle")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(SecondaryActionButtonStyle())
        .disabled(careerSource.isEmpty)
    }

    private var exampleReviewStep: some View {
        flowScroll {
            flowHeader(
                eyebrow: "2 · REVIEW",
                title: "Confirm one example",
                message: "RoleReady found possible examples, not verified facts. Check the wording and make your personal contribution explicit."
            )

            if !careerWarnings.isEmpty {
                InfoBanner(
                    title: "Unverified drafts",
                    message: careerWarnings.joined(separator: "\n"),
                    kind: .information
                )
            }

            if drafts.count > 1 {
                VStack(alignment: .leading, spacing: RRSpacing.sm) {
                    SectionHeading(title: "What was found", eyebrow: "SELECT TO REVIEW")
                    ForEach(Array(drafts.enumerated()), id: \.element.id) { index, draft in
                        HStack(spacing: RRSpacing.sm) {
                            Toggle(
                                "Keep \(draft.title)",
                                isOn: Binding(
                                    get: { drafts[index].isIncluded },
                                    set: { drafts[index].isIncluded = $0 }
                                )
                            )
                            .labelsHidden()
                            .accessibilityLabel("Keep \(draft.title)")
                            Button {
                                selectedDraftID = draft.id
                                if !draft.isIncluded { drafts[index].isIncluded = true }
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: RRSpacing.xxs) {
                                        Text(draft.title)
                                            .font(.rrHeadline)
                                            .foregroundStyle(BrandTheme.ink)
                                        Text(draft.isIncluded ? "Keep as a draft" : "Rejected")
                                            .font(.rrCaption)
                                            .foregroundStyle(BrandTheme.inkMuted)
                                    }
                                    Spacer()
                                    if selectedDraftID == draft.id {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(BrandTheme.violet)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(RRSpacing.sm)
                        .background(BrandTheme.surfaceMuted, in: RoundedRectangle(cornerRadius: RRRadius.small))
                    }

                    if drafts.filter(\.isIncluded).count > 1 {
                        Button {
                            combineIncludedDrafts()
                        } label: {
                            Label("Combine selected sections", systemImage: "square.stack.3d.up")
                        }
                        .font(.rrHeadline)
                        .foregroundStyle(BrandTheme.violet)
                    }
                }
                .cardSurface()
            }

            if let draftBinding = selectedDraftBinding {
                CareerDraftReviewCard(draft: draftBinding)

                Button(action: saveReviewedExamples) {
                    Label(
                        isSaving ? "Saving example…" : "Confirm and use this example",
                        systemImage: "checkmark.seal.fill"
                    )
                }
                .buttonStyle(PrimaryActionButtonStyle())
                .disabled(!canSaveReviewedExample || isSaving)
                .accessibilityIdentifier("use-reviewed-example")
                .accessibilityHint("Confirms that the wording and ownership reflect your real experience")

                Label(
                    "By continuing, you confirm that the wording and ownership reflect your real experience. You can strengthen the outcome next.",
                    systemImage: "lock.shield.fill"
                )
                .font(.rrCaption)
                .foregroundStyle(BrandTheme.inkMuted)
                .cardSurface(tint: BrandTheme.tealSoft.opacity(0.45))
            } else {
                EmptyStatePanel(
                    title: "Choose an example to review",
                    message: "Keep at least one draft, or go back and describe one example manually.",
                    symbol: "square.stack.3d.up"
                )
            }
        }
    }

    private var roleInputStep: some View {
        flowScroll {
            flowHeader(
                eyebrow: "3 · THE ROLE",
                title: "What are you preparing for?",
                message: "Paste the advertisement or targeted question. RoleReady keeps the source local and turns it into themes you can review."
            )

            if !roleWarnings.isEmpty {
                InfoBanner(title: "Check the role source", message: roleWarnings.joined(separator: "\n"), kind: .warning)
            }

            VStack(alignment: .leading, spacing: RRSpacing.md) {
                HStack {
                    Label("Job advertisement", systemImage: "briefcase.fill")
                        .font(.rrHeadline)
                    Spacer()
                    if let importedRoleFilename {
                        Text(importedRoleFilename)
                            .font(.rrCaption)
                            .foregroundStyle(BrandTheme.inkMuted)
                            .lineLimit(1)
                    }
                }

                ZStack(alignment: .topLeading) {
                    if roleSource.isEmpty {
                        Text("Paste responsibilities, capability requirements, selection criteria, or the complete advertisement…")
                            .font(.rrBody)
                            .foregroundStyle(BrandTheme.inkMuted.opacity(0.72))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 9)
                            .allowsHitTesting(false)
                    }
                    TextEditor(text: $roleSource)
                        .font(.rrBody)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 230)
                        .focused($textFocus, equals: .roleSource)
                        .accessibilityLabel("Job advertisement text")
                        .accessibilityIdentifier("preparation-job-text")
                }
                .padding(RRSpacing.sm)
                .background(BrandTheme.canvasRaised, in: RoundedRectangle(cornerRadius: RRRadius.medium, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: RRRadius.medium, style: .continuous)
                        .stroke(BrandTheme.separator, lineWidth: 1)
                }

                Button {
                    presentDocumentPicker(for: .role)
                } label: {
                    Label(isImportingRole ? "Importing…" : "Choose job document", systemImage: "doc.badge.plus")
                }
                .buttonStyle(SecondaryActionButtonStyle())
                .disabled(isImportingRole || isAnalysingRole)
                .accessibilityIdentifier("import-role-document")
            }
            .cardSurface()

            Button(action: analyseRole) {
                Label(
                    isAnalysingRole ? "Finding requirements…" : "Find requirement themes",
                    systemImage: isAnalysingRole ? "hourglass" : "checklist"
                )
            }
            .buttonStyle(PrimaryActionButtonStyle())
            .disabled(isAnalysingRole || isImportingRole || roleSource.trimmingCharacters(in: .whitespacesAndNewlines).count < 80)
            .accessibilityIdentifier("analyse-role-source")

            if !opportunities.isEmpty {
                DisclosureGroup("Use a saved role") {
                    VStack(spacing: RRSpacing.xs) {
                        ForEach(opportunities.prefix(6)) { opportunity in
                            Button {
                                useSavedRole(opportunity)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: RRSpacing.xxs) {
                                        Text(opportunity.roleTitle).font(.rrHeadline)
                                        Text(opportunity.organisation).font(.rrCaption)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                }
                            }
                            .buttonStyle(SecondaryActionButtonStyle())
                        }
                    }
                    .padding(.top, RRSpacing.sm)
                }
                .font(.rrHeadline)
                .cardSurface()
            }
        }
    }

    private var requirementReviewStep: some View {
        flowScroll {
            flowHeader(
                eyebrow: "4 · REQUIREMENTS",
                title: "Check what matters most",
                message: "Keep the themes the role actually asks for. Your first answer will focus on one high-value requirement."
            )

            VStack(alignment: .leading, spacing: RRSpacing.md) {
                TextField("Role title", text: $roleTitle)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("preparation-role-title")
                TextField("Organisation (optional)", text: $roleOrganisation)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("preparation-role-organisation")
            }
            .cardSurface()

            if !roleWarnings.isEmpty {
                InfoBanner(title: "Review the analysis", message: roleWarnings.joined(separator: "\n"), kind: .warning)
            }

            VStack(alignment: .leading, spacing: RRSpacing.md) {
                SectionHeading(
                    title: "Requirement themes",
                    eyebrow: "\(includedRequirementCount) INCLUDED",
                    actionTitle: "Add"
                ) {
                    addRequirementDraft()
                }

                ForEach($requirementDrafts) { $requirement in
                    VStack(alignment: .leading, spacing: RRSpacing.sm) {
                        Toggle(isOn: $requirement.isIncluded) {
                            Text(requirement.kind.title)
                                .font(.rrCaption)
                                .foregroundStyle(BrandTheme.violet)
                        }
                        TextField("Requirement", text: $requirement.text, axis: .vertical)
                            .lineLimit(2...5)
                            .textFieldStyle(.plain)
                            .padding(RRSpacing.sm)
                            .background(BrandTheme.surfaceMuted, in: RoundedRectangle(cornerRadius: RRRadius.small))

                        DisclosureGroup("Category and importance") {
                            Picker("Category", selection: $requirement.kind) {
                                ForEach(RequirementKind.allCases) { kind in
                                    Text(kind.title).tag(kind)
                                }
                            }
                            Picker("Importance", selection: $requirement.importance) {
                                Text("Useful").tag(1)
                                Text("Important").tag(2)
                                Text("Essential").tag(3)
                            }
                        }
                        .font(.rrCaption)
                    }
                    .padding(RRSpacing.sm)
                    .background(BrandTheme.canvasRaised, in: RoundedRectangle(cornerRadius: RRRadius.medium))
                }
            }
            .cardSurface()

            if includedRequirementCount > 0 {
                VStack(alignment: .leading, spacing: RRSpacing.sm) {
                    Text("Start with")
                        .font(.rrHeadline)
                    Picker("First requirement", selection: $selectedRequirementID) {
                        ForEach(requirementDrafts.filter { $0.isIncluded && !$0.text.trimmedForPreparation.isEmpty }) { requirement in
                            Text(requirement.text).tag(Optional(requirement.id))
                        }
                    }
                    .pickerStyle(.menu)
                    .accessibilityIdentifier("preparation-focus-requirement")
                }
                .cardSurface(tint: BrandTheme.violetSoft.opacity(0.45))
            }

            Button(action: saveRoleAndRequirements) {
                Label(isSaving ? "Saving role…" : "Match my experience", systemImage: "arrow.triangle.branch")
            }
            .buttonStyle(PrimaryActionButtonStyle())
            .disabled(!canSaveRole || isSaving)
            .accessibilityIdentifier("save-and-match-role")
        }
    }

    private var matchAndStrengthenStep: some View {
        flowScroll {
            flowHeader(
                eyebrow: "5 · BEST EVIDENCE",
                title: "Use the strongest honest example",
                message: "A wording match is not proof. RoleReady checks verified detail and tells you when an example is direct, transferable, partial, or unsupported."
            )

            if let requirement = selectedRequirementModel {
                VStack(alignment: .leading, spacing: RRSpacing.xs) {
                    Text("FOCUS REQUIREMENT")
                        .font(.rrCaption)
                        .tracking(0.8)
                        .foregroundStyle(BrandTheme.violet)
                    Text(requirement.text)
                        .font(.rrTitle)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .cardSurface(tint: BrandTheme.violetSoft.opacity(0.42))
            }

            if experiences.filter(\.isApprovedForMatching).count > 1 {
                VStack(alignment: .leading, spacing: RRSpacing.sm) {
                    Text("Suggested example")
                        .font(.rrHeadline)
                    Picker("Example", selection: Binding(
                        get: { selectedExperienceID },
                        set: { newValue in
                            selectedExperienceID = newValue
                            let chosen = experiences.first { $0.id == newValue }
                            explicitlySelectedSensitiveExperienceID = chosen?.confidentiality.blocksAutomaticUse == true
                                ? chosen?.id
                                : nil
                            refreshMatches()
                        }
                    )) {
                        ForEach(experiences.filter(\.isApprovedForMatching)) { experience in
                            Text(experience.title).tag(Optional(experience.id))
                        }
                    }
                    .pickerStyle(.menu)
                    .accessibilityIdentifier("matched-example-picker")
                }
                .cardSurface()
            }

            if let experience = selectedExperience, let match = selectedMatch {
                VStack(alignment: .leading, spacing: RRSpacing.md) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: RRSpacing.xxs) {
                            Text(experience.title)
                                .font(.rrTitle)
                            if !experience.organisation.isEmpty {
                                Text(experience.organisation)
                                    .font(.rrBody)
                                    .foregroundStyle(BrandTheme.inkMuted)
                            }
                        }
                        Spacer()
                        MatchTierBadge(tier: match.tier)
                    }
                    Text(match.explanation)
                        .font(.rrBody)
                        .foregroundStyle(BrandTheme.inkMuted)
                        .fixedSize(horizontal: false, vertical: true)

                    DisclosureGroup("Why this example?") {
                        VStack(alignment: .leading, spacing: RRSpacing.xs) {
                            if !match.matchedCapabilities.isEmpty {
                                Text("Relevant capabilities: \(match.matchedCapabilities.map(\.title).joined(separator: ", ")).")
                            }
                            if !match.matchedTerms.isEmpty {
                                Text("Shared verified detail: \(match.matchedTerms.prefix(6).joined(separator: ", ")).")
                            }
                            ForEach(match.cautions, id: \.self) { caution in
                                Label(caution, systemImage: "exclamationmark.triangle")
                            }
                            Text("This assessment describes evidence fit only. It is not a hiring probability.")
                        }
                        .font(.subheadline)
                        .foregroundStyle(BrandTheme.inkMuted)
                        .padding(.top, RRSpacing.xs)
                    }
                    .font(.rrHeadline)
                }
                .cardSurface(tint: match.tier.allowsAnswer ? BrandTheme.tealSoft.opacity(0.42) : BrandTheme.amberSoft.opacity(0.48))
                .accessibilityIdentifier("preparation-match-result")

                if let strengtheningDraftBinding {
                    AdaptiveEvidenceQuestions(
                        draft: strengtheningDraftBinding,
                        requirement: selectedRequirementModel
                    )
                    .id(experience.id)
                } else {
                    ProgressView("Preparing the example…")
                        .frame(maxWidth: .infinity)
                        .padding(RRSpacing.lg)
                        .task { prepareStrengtheningDraft(for: experience) }
                }

                if !match.tier.allowsAnswer {
                    InfoBanner(
                        title: match.tier == .none ? "No verified support yet" : "This link is still partial",
                        message: "Choose another real example or add specific, truthful detail that directly demonstrates the requirement. RoleReady will not turn a loose wording match into a confident recommendation.",
                        kind: .warning
                    )
                }

                answerChoiceCard

                Button(action: continueToAnswer) {
                    Label(isSaving ? "Checking evidence…" : "Create grounded answer", systemImage: "wand.and.stars")
                }
                .buttonStyle(PrimaryActionButtonStyle())
                .disabled(!canContinueToAnswer || isSaving)
                .accessibilityIdentifier("continue-to-grounded-answer")

                if match.tier.allowsAnswer, !hasEnoughDetailForTarget {
                    InfoBanner(
                        title: "Add one more useful detail",
                        message: targetDetailMessage,
                        kind: .warning
                    )
                }
            } else if selectedRequirementModel == nil {
                ProgressView("Loading your role…")
                    .frame(maxWidth: .infinity)
                    .padding(RRSpacing.xl)
            } else {
                EmptyStatePanel(
                    title: "No verified example is available",
                    message: "Highly sensitive or unreviewed drafts are never matched automatically. Go back and confirm a suitable real example.",
                    symbol: "shield.slash",
                    actionTitle: "Choose another example"
                ) {
                    step = .career
                }
            }
        }
        .task {
            await Task.yield()
            refreshMatches()
            chooseRecommendationIfNeeded()
        }
        .onChange(of: selectedExperienceID) { _, _ in
            prepareStrengtheningDraft(for: selectedExperience)
        }
    }

    private var answerChoiceCard: some View {
        VStack(alignment: .leading, spacing: RRSpacing.md) {
            SectionHeading(title: "First answer", eyebrow: "OUTPUT")
            Picker("Answer type", selection: $answerFormat) {
                Text("60-second interview answer").tag(AnswerFormat.sixtySeconds)
                Text("Written selection criterion").tag(AnswerFormat.selectionCriteria)
            }
            .pickerStyle(.inline)
            .onChange(of: answerFormat) { _, _ in
                answerQuestion = suggestedQuestion
            }

            VStack(alignment: .leading, spacing: RRSpacing.xs) {
                Text(answerFormat == .selectionCriteria ? "Criterion or targeted question" : "Interview question")
                    .font(.rrCaption)
                    .foregroundStyle(BrandTheme.inkMuted)
                TextField("Tell me about a time…", text: $answerQuestion, axis: .vertical)
                    .lineLimit(2...5)
                    .textFieldStyle(.plain)
                    .padding(RRSpacing.sm)
                    .background(BrandTheme.surfaceMuted, in: RoundedRectangle(cornerRadius: RRRadius.small))
                    .accessibilityIdentifier("preparation-answer-question")
            }
        }
        .cardSurface()
    }

    @ViewBuilder
    private var answerStep: some View {
        if let selectedExperienceID, let savedOpportunityID {
            AnswerStudioView(
                experienceID: selectedExperienceID,
                opportunityID: savedOpportunityID,
                initialQuestion: answerQuestion,
                initialFormat: answerFormat,
                showsCloseButton: false,
                dismissAfterSave: false,
                onBack: { step = .match }
            ) { answerID, isApproved in
                if isApproved {
                    savedAnswerID = answerID
                    step = .practice
                    appState.showToast("Answer approved for practice", symbol: "checkmark.seal.fill")
                } else {
                    appState.showToast("Draft saved — approve it when the sources are clear", symbol: "square.and.arrow.down")
                }
            }
        } else {
            EmptyStatePanel(
                title: "Preparation context unavailable",
                message: "Go back and choose a role and example before building an answer.",
                symbol: "exclamationmark.triangle",
                actionTitle: "Back to matching"
            ) {
                step = .match
            }
            .padding(RRSpacing.md)
        }
    }

    @ViewBuilder
    private var practiceStep: some View {
        if let savedAnswerID {
            GuidedPracticeView(
                answerID: savedAnswerID,
                strengthen: { step = .match },
                finish: { dismiss() }
            )
        } else {
            EmptyStatePanel(
                title: "Approve an answer first",
                message: "Only answers with complete source links can enter practice.",
                symbol: "checkmark.seal",
                actionTitle: "Review answer"
            ) {
                step = .answer
            }
            .padding(RRSpacing.md)
        }
    }

    private var trustStrip: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: RRSpacing.sm) { trustItems }
            VStack(spacing: RRSpacing.xs) { trustItems }
        }
    }

    @ViewBuilder
    private var trustItems: some View {
        trustItem("Local by default", symbol: "iphone.and.arrow.forward")
        trustItem("You approve facts", symbol: "checkmark.seal")
        trustItem("No live assistance", symbol: "person.crop.circle.badge.xmark")
    }

    private func trustItem(_ title: String, symbol: String) -> some View {
        Label(title, systemImage: symbol)
            .font(.rrCaption)
            .foregroundStyle(BrandTheme.inkMuted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(RRSpacing.sm)
            .background(BrandTheme.surfaceMuted, in: RoundedRectangle(cornerRadius: RRRadius.small))
            .accessibilityElement(children: .combine)
    }

    private func flowHeader(eyebrow: String, title: String, message: String) -> some View {
        VStack(alignment: .leading, spacing: RRSpacing.sm) {
            PreparationProgress(step: step)
            Text(eyebrow)
                .font(.rrCaption)
                .tracking(0.8)
                .foregroundStyle(BrandTheme.violet)
            Text(title)
                .font(.rrHero)
                .fixedSize(horizontal: false, vertical: true)
            Text(message)
                .font(.rrBody)
                .foregroundStyle(BrandTheme.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
        .accessibilityFocused($isStepHeadingFocused)
    }

    private func flowScroll<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: RRSpacing.lg) {
                content()
            }
            .padding(RRSpacing.md)
            .padding(.bottom, RRSpacing.xxl)
            .frame(maxWidth: 820)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .accessibilityIdentifier("preparation-scroll")
    }

    private var selectedDraftBinding: Binding<CareerHistoryDraft>? {
        guard let selectedDraftID,
              let index = drafts.firstIndex(where: { $0.id == selectedDraftID }) else { return nil }
        return Binding(
            get: { drafts[index] },
            set: { drafts[index] = $0 }
        )
    }

    private var canSaveReviewedExample: Bool {
        guard let draft = selectedDraftBinding?.wrappedValue, draft.isIncluded else { return false }
        return !draft.title.trimmedForPreparation.isEmpty
            && !draft.situation.trimmedForPreparation.isEmpty
            && draft.actions.contains(where: { !$0.trimmedForPreparation.isEmpty })
    }

    private var includedRequirementCount: Int {
        requirementDrafts.filter { $0.isIncluded && !$0.text.trimmedForPreparation.isEmpty }.count
    }

    private var canSaveRole: Bool {
        !roleTitle.trimmedForPreparation.isEmpty
            && includedRequirementCount > 0
            && selectedRequirementID != nil
    }

    private var selectedExperience: Experience? {
        guard let selectedExperienceID else { return nil }
        return experiences.first { $0.id == selectedExperienceID }
    }

    private var strengtheningDraftBinding: Binding<ExperienceStrengtheningDraft>? {
        guard let selectedExperience,
              strengtheningDraft?.experienceID == selectedExperience.id else { return nil }
        return Binding(
            get: { strengtheningDraft ?? ExperienceStrengtheningDraft(selectedExperience) },
            set: { strengtheningDraft = $0 }
        )
    }

    private var selectedRequirementModel: JobRequirement? {
        guard let selectedRequirementID else { return nil }
        return savedRequirements.first { $0.id == selectedRequirementID }
    }

    private var rankedMatches: [EvidenceMatch] {
        rankedMatchesCache
    }

    private var selectedMatch: EvidenceMatch? {
        guard let selectedExperienceID else { return nil }
        return rankedMatches.first { $0.experienceID == selectedExperienceID }
    }

    private var suggestedQuestion: String {
        guard let requirement = selectedRequirementModel else { return "" }
        if answerFormat == .selectionCriteria { return requirement.text }
        if let capability = requirement.capabilities.first {
            return "Tell me about a time you demonstrated \(capability.title.lowercased())."
        }
        return "Tell me about a time your experience was relevant to this requirement: \(requirement.text)"
    }

    private var previewAnswerDraft: GeneratedDraft? {
        guard let experience = selectedExperience,
              let strengtheningDraft,
              strengtheningDraft.experienceID == experience.id,
              !answerQuestion.trimmedForPreparation.isEmpty else { return nil }
        return try? GroundedAnswerEngine().generate(
            question: answerQuestion,
            from: strengtheningDraft.groundedExperience(using: experience),
            format: answerFormat,
            audience: .hiringManager,
            tone: .natural,
            roleTitle: roleTitle
        )
    }

    private var hasEnoughDetailForTarget: Bool {
        previewAnswerDraft?.isWithinTarget == true
    }

    private var targetDetailMessage: String {
        guard let previewAnswerDraft else {
            return "Add a truthful result and at least one concrete action before creating an answer."
        }
        let current = "The current grounded draft is \(previewAnswerDraft.wordCount) words. "
        if previewAnswerDraft.wordCount > answerFormat.targetWordCount.upperBound {
            return current + "Review the full example and remove background detail that does not help answer this requirement."
        }
        return current + (answerFormat == .selectionCriteria
            ? "A credible written response needs more source material. Add the reason for your approach, proof of the outcome, or what you learnt—only where it is true."
            : "A useful 60-second answer needs enough substance to speak naturally. Add why you chose the approach or how you verified the outcome.")
    }

    private var canContinueToAnswer: Bool {
        guard let experience = selectedExperience,
              let strengtheningDraft,
              strengtheningDraft.experienceID == experience.id,
              selectedMatch != nil else { return false }
        return !answerQuestion.trimmedForPreparation.isEmpty
            && !strengtheningDraft.situation.trimmedForPreparation.isEmpty
            && strengtheningDraft.actions.contains(where: { !$0.trimmedForPreparation.isEmpty })
            && !strengtheningDraft.result.trimmedForPreparation.isEmpty
            && (!strengtheningDraft.confidentiality.blocksAutomaticUse || strengtheningDraft.isApprovedForMatching)
            && hasEnoughDetailForTarget
    }

    private var closeMessage: String {
        if selectedExperienceID != nil {
            return "Any reviewed examples and saved role details remain safely in My Examples and Prepare. Your unsaved answer work will be left here."
        }
        return "Unsaved career and role text on this screen will be discarded."
    }

    private var hasUnsavedCareerInput: Bool {
        !careerSource.trimmedForPreparation.isEmpty || !drafts.isEmpty
    }

    private func beginManualExample() {
        let draft = CareerHistoryDraft(
            title: "",
            occurredAt: Date(),
            kind: .project,
            ownership: .contributed,
            sourceExcerpt: "",
            warnings: ["This example is not verified until you confirm it below."]
        )
        drafts = [draft]
        selectedDraftID = draft.id
        careerWarnings = []
        step = .exampleReview
    }

    private func analyseCareerHistory() {
        let source = careerSource
        isAnalysingCareer = true
        issue = nil
        Task {
            do {
                let result = try await Task.detached(priority: .userInitiated) {
                    try CareerHistoryIngestionService().extractDrafts(from: source)
                }.value
                drafts = result.drafts
                selectedDraftID = result.drafts.first?.id
                careerWarnings = careerWarnings + result.warnings
                step = .exampleReview
            } catch {
                issue = PreparationIssue(title: "Couldn’t find an example", message: error.localizedDescription)
            }
            isAnalysingCareer = false
        }
    }

    private func combineIncludedDrafts() {
        let included = drafts.filter(\.isIncluded)
        guard let combined = CareerHistoryIngestionService().combine(included) else { return }
        let rejected = drafts.filter { !$0.isIncluded }
        drafts = rejected + [combined]
        selectedDraftID = combined.id
    }

    private func makeExperience(
        from draft: CareerHistoryDraft,
        isApprovedForMatching: Bool
    ) -> Experience {
        Experience(
            id: draft.id,
            title: draft.title.trimmedForPreparation,
            organisation: draft.organisation.trimmedForPreparation,
            occurredAt: min(draft.occurredAt, Date()),
            kind: draft.kind,
            situation: draft.situation.trimmedForPreparation,
            task: draft.task.trimmedForPreparation,
            actions: draft.actions.map(\.trimmedForPreparation).filter { !$0.isEmpty },
            result: draft.result.trimmedForPreparation,
            evidence: draft.evidence.trimmedForPreparation,
            learning: draft.learning.trimmedForPreparation,
            ownership: draft.ownership,
            capabilities: draft.capabilities,
            tools: draft.tools.map(\.trimmedForPreparation).filter { !$0.isEmpty },
            confidentiality: .privateRecord,
            isApprovedForMatching: isApprovedForMatching
        )
    }

    private func update(
        _ experience: Experience,
        from draft: CareerHistoryDraft,
        isApprovedForMatching: Bool
    ) throws -> Int {
        let title = draft.title.trimmedForPreparation
        let organisation = draft.organisation.trimmedForPreparation
        let occurredAt = min(draft.occurredAt, Date())
        let situation = draft.situation.trimmedForPreparation
        let task = draft.task.trimmedForPreparation
        let actions = draft.actions.map(\.trimmedForPreparation).filter { !$0.isEmpty }
        let result = draft.result.trimmedForPreparation
        let evidence = draft.evidence.trimmedForPreparation
        let learning = draft.learning.trimmedForPreparation
        let tools = draft.tools.map(\.trimmedForPreparation).filter { !$0.isEmpty }
        let factsChanged = experience.title != title
            || experience.organisation != organisation
            || experience.occurredAt != occurredAt
            || experience.kind != draft.kind
            || experience.situation != situation
            || experience.task != task
            || experience.actions != actions
            || experience.result != result
            || experience.evidence != evidence
            || experience.learning != learning
            || experience.ownership != draft.ownership
            || experience.capabilities != draft.capabilities
            || experience.tools != tools

        experience.title = title
        experience.organisation = organisation
        experience.occurredAt = occurredAt
        experience.kind = draft.kind
        experience.situation = situation
        experience.task = task
        experience.actions = actions
        experience.result = result
        experience.evidence = evidence
        experience.learning = learning
        experience.ownership = draft.ownership
        experience.capabilities = draft.capabilities
        experience.tools = tools
        experience.isApprovedForMatching = isApprovedForMatching

        guard factsChanged else { return 0 }
        experience.updatedAt = Date()
        return try AnswerApprovalService().invalidateAnswers(for: experience.id, in: modelContext)
    }

    private func saveReviewedExamples() {
        guard let selectedDraftID else { return }
        isSaving = true
        issue = nil
        let included = drafts.filter(\.isIncluded)
        let draftIDs = Set(drafts.map(\.id))
        var selectedID: UUID?
        do {
            var invalidatedAnswerCount = 0
            for existing in experiences where draftIDs.contains(existing.id) {
                existing.isApprovedForMatching = existing.id == selectedDraftID
                    && included.contains(where: { $0.id == existing.id })
            }
            for draft in included {
                if let existing = experiences.first(where: { $0.id == draft.id }) {
                    invalidatedAnswerCount += try update(
                        existing,
                        from: draft,
                        isApprovedForMatching: draft.id == selectedDraftID
                    )
                    if draft.id == selectedDraftID { selectedID = existing.id }
                } else {
                    let experience = makeExperience(
                        from: draft,
                        isApprovedForMatching: draft.id == selectedDraftID
                    )
                    modelContext.insert(experience)
                    if draft.id == selectedDraftID { selectedID = experience.id }
                }
            }
            try modelContext.save()
            selectedExperienceID = selectedID
            let message = invalidatedAnswerCount > 0
                ? "Example saved · linked answers need reconfirmation"
                : "Reviewed example saved"
            appState.showToast(message, symbol: "checkmark.seal.fill")
            step = .role
        } catch {
            modelContext.rollback()
            issue = PreparationIssue(title: "Couldn’t save the example", message: error.localizedDescription)
        }
        isSaving = false
    }

    private func analyseRole() {
        let source = roleSource
        isAnalysingRole = true
        issue = nil
        Task {
            do {
                let parsed = try await Task.detached(priority: .userInitiated) {
                    try JobParser().parse(source)
                }.value
                roleTitle = parsed.suggestedTitle
                roleOrganisation = parsed.suggestedOrganisation
                roleWarnings = roleWarnings + parsed.warnings
                requirementDrafts = parsed.requirements.map(PreparationRequirementDraft.init)
                if requirementDrafts.isEmpty { addRequirementDraft() }
                selectedRequirementID = requirementDrafts
                    .filter(\.isIncluded)
                    .sorted { $0.importance > $1.importance }
                    .first?.id
                step = .requirements
            } catch {
                issue = PreparationIssue(title: "Couldn’t analyse the role", message: error.localizedDescription)
            }
            isAnalysingRole = false
        }
    }

    private func addRequirementDraft() {
        let draft = PreparationRequirementDraft()
        requirementDrafts.append(draft)
        selectedRequirementID = selectedRequirementID ?? draft.id
    }

    private func saveRoleAndRequirements() {
        isSaving = true
        issue = nil
        let confirmedTitle = roleTitle.trimmedForPreparation
        let confirmedOrganisation = roleOrganisation.trimmedForPreparation
        let confirmedSource = roleSource.trimmedForPreparation
        let existingOpportunity = savedOpportunityID.flatMap { id in
            opportunities.first { $0.id == id }
        }
        let opportunity = existingOpportunity ?? Opportunity(
            roleTitle: confirmedTitle,
            organisation: confirmedOrganisation,
            location: "",
            sourceText: confirmedSource,
            status: .preparing
        )
        if existingOpportunity == nil { modelContext.insert(opportunity) }
        var contentChanged = opportunity.roleTitle != confirmedTitle
            || opportunity.organisation != confirmedOrganisation
            || opportunity.sourceText != confirmedSource
        opportunity.roleTitle = confirmedTitle
        opportunity.organisation = confirmedOrganisation
        opportunity.sourceText = confirmedSource
        let included = requirementDrafts.filter { $0.isIncluded && !$0.text.trimmedForPreparation.isEmpty }
        let includedIDs = Set(included.map(\.id))
        for existing in savedRequirements
            where existing.opportunityID == opportunity.id && !includedIDs.contains(existing.id) {
            if existing.isConfirmed { contentChanged = true }
            existing.isConfirmed = false
        }
        for draft in included {
            let confirmedText = draft.text.trimmedForPreparation
            let metadata = RequirementMetadataService().analyse(confirmedText)
            if let existing = savedRequirements.first(where: { $0.id == draft.id }) {
                if existing.opportunityID != opportunity.id
                    || existing.text != confirmedText
                    || existing.kind != draft.kind
                    || existing.keywords != metadata.keywords
                    || existing.capabilities != metadata.capabilities
                    || existing.importance != draft.importance
                    || !existing.isConfirmed {
                    contentChanged = true
                }
                existing.opportunityID = opportunity.id
                existing.text = confirmedText
                existing.kind = draft.kind
                existing.keywords = metadata.keywords
                existing.capabilities = metadata.capabilities
                existing.importance = min(max(draft.importance, 1), 3)
                existing.isConfirmed = true
            } else {
                contentChanged = true
                modelContext.insert(JobRequirement(
                    id: draft.id,
                    opportunityID: opportunity.id,
                    text: confirmedText,
                    kind: draft.kind,
                    keywords: metadata.keywords,
                    capabilities: metadata.capabilities,
                    importance: draft.importance,
                    isConfirmed: true
                ))
            }
        }
        do {
            var invalidatedAnswerCount = 0
            if contentChanged, existingOpportunity != nil {
                opportunity.contentUpdatedAt = Date()
                invalidatedAnswerCount = try AnswerApprovalService()
                    .invalidateAnswers(forOpportunityID: opportunity.id, in: modelContext)
            }
            opportunity.updatedAt = Date()
            try modelContext.save()
            savedOpportunityID = opportunity.id
            if selectedRequirementID == nil || !included.contains(where: { $0.id == selectedRequirementID }) {
                selectedRequirementID = included.first?.id
            }
            hasChosenRecommendation = false
            step = .match
            if invalidatedAnswerCount > 0 {
                appState.showToast("Role updated · linked answers need reconfirmation", symbol: "exclamationmark.shield.fill")
            }
            Task {
                await Task.yield()
                refreshMatches()
                chooseRecommendationIfNeeded()
            }
        } catch {
            modelContext.rollback()
            issue = PreparationIssue(title: "Couldn’t save this role", message: error.localizedDescription)
        }
        isSaving = false
    }

    private func useSavedRole(_ opportunity: Opportunity) {
        let requirements = savedRequirements
            .filter { $0.opportunityID == opportunity.id && $0.isConfirmed }
            .sorted { $0.importance > $1.importance }
        savedOpportunityID = opportunity.id
        requirementDrafts = requirements.map(PreparationRequirementDraft.init)
        guard let first = requirements.first else {
            roleTitle = opportunity.roleTitle
            roleOrganisation = opportunity.organisation
            roleSource = opportunity.sourceText
            roleWarnings = ["This saved role has no confirmed requirements. Analyse its source or add one manually."]
            requirementDrafts = []
            addRequirementDraft()
            step = .requirements
            return
        }
        roleTitle = opportunity.roleTitle
        roleOrganisation = opportunity.organisation
        roleSource = opportunity.sourceText
        selectedRequirementID = first.id
        hasChosenRecommendation = false
        step = .match
    }

    private func chooseRecommendationIfNeeded() {
        guard !hasChosenRecommendation else { return }
        let best = explicitlySelectedSensitiveExperienceID
            .flatMap { selectedID in rankedMatches.first { $0.experienceID == selectedID } }
            ?? rankedMatches.first
        guard let best else { return }
        selectedExperienceID = best.experienceID
        answerQuestion = suggestedQuestion
        hasChosenRecommendation = true
        prepareStrengtheningDraft(for: experiences.first { $0.id == best.experienceID })
    }

    private func refreshMatches() {
        guard let requirement = selectedRequirementModel else {
            rankedMatchesCache = []
            return
        }
        let explicitIDs = explicitlySelectedSensitiveExperienceID.map { Set([$0]) } ?? []
        rankedMatchesCache = EvidenceMatcher().rank(
            requirement: requirement,
            against: experiences,
            explicitlyApprovedSensitiveExperienceIDs: explicitIDs
        )
    }

    private func continueToAnswer() {
        guard let experience = selectedExperience,
              let strengtheningDraft,
              strengtheningDraft.experienceID == experience.id,
              let requirement = selectedRequirementModel else { return }
        isSaving = true
        issue = nil
        do {
            let changed = strengtheningDraft.differs(from: experience)
            var invalidatedAnswerCount = 0
            if changed {
                strengtheningDraft.apply(to: experience)
                experience.updatedAt = Date()
                explicitlySelectedSensitiveExperienceID = experience.confidentiality.blocksAutomaticUse
                    ? experience.id
                    : nil
                invalidatedAnswerCount = try AnswerApprovalService()
                    .invalidateAnswers(for: experience.id, in: modelContext)
            }
            try modelContext.save()
            refreshMatches()
            let refreshedMatch = EvidenceMatcher()
                .rank(
                    requirement: requirement,
                    against: [experience],
                    explicitlyApprovedSensitiveExperienceIDs: experience.confidentiality.blocksAutomaticUse
                        ? [experience.id]
                        : []
                )
                .first
            guard refreshedMatch?.tier.allowsAnswer == true else {
                issue = PreparationIssue(
                    title: "This example still needs a clearer link",
                    message: "Your edits were saved, but the verified detail still does not directly or transferably support this requirement. Choose another real example or add a specific truthful action, capability or result."
                )
                isSaving = false
                return
            }
            answerQuestion = answerQuestion.trimmedForPreparation
            step = .answer
            if invalidatedAnswerCount > 0 {
                appState.showToast(
                    "Example updated · \(invalidatedAnswerCount) answer\(invalidatedAnswerCount == 1 ? "" : "s") need reconfirmation",
                    symbol: "exclamationmark.shield.fill"
                )
            }
        } catch {
            modelContext.rollback()
            issue = PreparationIssue(title: "Couldn’t save the strengthened example", message: error.localizedDescription)
        }
        isSaving = false
    }

    private func prepareStrengtheningDraft(for experience: Experience?) {
        guard let experience else {
            strengtheningDraft = nil
            return
        }
        guard strengtheningDraft?.experienceID != experience.id else { return }
        strengtheningDraft = ExperienceStrengtheningDraft(experience)
    }

    private func handleCareerImport(_ url: URL) {
        handleDocumentImport(
            url,
            setLoading: { isImportingCareer = $0 },
            completion: { document in
                careerSource = document.text
                importedCareerFilename = document.name
                careerWarnings = document.warnings
            }
        )
    }

    private func handleRoleImport(_ url: URL) {
        handleDocumentImport(
            url,
            setLoading: { isImportingRole = $0 },
            completion: { document in
                roleSource = document.text
                importedRoleFilename = document.name
                roleWarnings = document.warnings
            }
        )
    }

    private func handleDocumentPickerOutcome(
        _ outcome: SystemDocumentPickerOutcome,
        purpose: PreparationDocumentImport
    ) {
        guard case .selected(let url) = outcome else { return }
        switch purpose {
        case .career:
            handleCareerImport(url)
        case .role:
            handleRoleImport(url)
        }
    }

    private func presentDocumentPicker(for purpose: PreparationDocumentImport) {
        SystemDocumentPickerService.shared.present(
            contentTypes: DocumentImportService.supportedContentTypes
        ) { outcome in
            handleDocumentPickerOutcome(outcome, purpose: purpose)
        }
    }

    private func handleDocumentImport(
        _ url: URL,
        setLoading: @escaping (Bool) -> Void,
        completion: @escaping (ImportedDocument) -> Void
    ) {
        setLoading(true)
        Task {
            do {
                let document = try await Task.detached(priority: .userInitiated) {
                    try DocumentImportService().extractText(from: url)
                }.value
                completion(document)
            } catch {
                issue = PreparationIssue(title: "Couldn’t import the document", message: error.localizedDescription)
            }
            setLoading(false)
        }
    }

    private func moveBack() {
        switch step {
        case .career: break
        case .exampleReview: step = .career
        case .role: step = drafts.isEmpty ? .career : .exampleReview
        case .requirements: step = .role
        case .match: step = .requirements
        case .answer: step = .match
        case .practice: step = .answer
        }
    }
}

private enum PreparationDocumentImport: String, Identifiable {
    case career
    case role

    var id: String { rawValue }
}

private enum PreparationTextFocus: Hashable {
    case careerHistory
    case roleSource
}

private enum PreparationStep: Int, CaseIterable {
    case career
    case exampleReview
    case role
    case requirements
    case match
    case answer
    case practice

    var navigationTitle: String {
        switch self {
        case .career, .exampleReview: "Prepare for a role"
        case .role, .requirements: "Role requirements"
        case .match: "Evidence match"
        case .answer: "Grounded answer"
        case .practice: "Practise"
        }
    }
}

private struct PreparationProgress: View {
    let step: PreparationStep

    private var progress: Double {
        Double(step.rawValue + 1) / Double(PreparationStep.allCases.count)
    }

    var body: some View {
        ProgressView(value: progress)
            .tint(BrandTheme.violet)
            .accessibilityLabel("Preparation progress")
            .accessibilityValue("Step \(step.rawValue + 1) of \(PreparationStep.allCases.count)")
    }
}

private struct PreparationRequirementDraft: Identifiable, Hashable {
    let id: UUID
    var text: String
    var kind: RequirementKind
    var keywords: [String]
    var capabilities: [Capability]
    var importance: Int
    var isIncluded: Bool

    init(
        id: UUID = UUID(),
        text: String = "",
        kind: RequirementKind = .mustHave,
        keywords: [String] = [],
        capabilities: [Capability] = [],
        importance: Int = 3,
        isIncluded: Bool = true
    ) {
        self.id = id
        self.text = text
        self.kind = kind
        self.keywords = keywords
        self.capabilities = capabilities
        self.importance = importance
        self.isIncluded = isIncluded
    }

    init(_ parsed: ParsedRequirement) {
        id = parsed.id
        text = parsed.text
        kind = parsed.kind
        keywords = parsed.keywords
        capabilities = parsed.capabilities
        importance = parsed.importance
        isIncluded = true
    }

    init(_ saved: JobRequirement) {
        id = saved.id
        text = saved.text
        kind = saved.kind
        keywords = saved.keywords
        capabilities = saved.capabilities
        importance = saved.importance
        isIncluded = saved.isConfirmed
    }
}

private struct PreparationIssue: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

private struct CareerDraftReviewCard: View {
    @Binding var draft: CareerHistoryDraft
    @State private var showMore = false

    var body: some View {
        VStack(alignment: .leading, spacing: RRSpacing.md) {
            SectionHeading(title: "Review the example", eyebrow: "UNVERIFIED")

            LabeledPreparationField(
                title: "Short title",
                prompt: "e.g. Resolved a difficult service issue",
                text: $draft.title,
                identifier: "draft-example-title"
            )
            LabeledPreparationField(
                title: "Organisation or context",
                prompt: "Optional",
                text: $draft.organisation,
                identifier: "draft-example-organisation"
            )

            Picker("What was your part?", selection: $draft.ownership) {
                ForEach(OwnershipLevel.allCases) { ownership in
                    Text(ownership.phrasing).tag(ownership)
                }
            }
            .accessibilityIdentifier("draft-example-ownership")

            LabeledPreparationEditor(
                title: "What happened?",
                prompt: "Give the context and why it mattered.",
                text: $draft.situation,
                identifier: "draft-example-situation"
            )
            LabeledPreparationEditor(
                title: "What did you personally do?",
                prompt: "Put each concrete action on a new line.",
                text: Binding(
                    get: { draft.actions.joined(separator: "\n") },
                    set: {
                        // Preserve spaces and unfinished lines while the user is typing.
                        // The explicit save step performs the final normalisation.
                        draft.actions = $0.components(separatedBy: .newlines)
                    }
                ),
                identifier: "draft-example-actions"
            )
            LabeledPreparationEditor(
                title: "What changed as a result?",
                prompt: "You can add or strengthen this on the next screen.",
                text: $draft.result,
                identifier: "draft-example-result"
            )

            DisclosureGroup(isExpanded: $showMore) {
                VStack(spacing: RRSpacing.md) {
                    LabeledPreparationEditor(
                        title: "What was your responsibility?",
                        prompt: "Optional detail about what you were accountable for.",
                        text: $draft.task,
                        identifier: "draft-example-task"
                    )
                    LabeledPreparationEditor(
                        title: "How do you know it worked?",
                        prompt: "A measure, observation, test, sign-off or feedback.",
                        text: $draft.evidence,
                        identifier: "draft-example-evidence"
                    )
                    LabeledPreparationEditor(
                        title: "What did you learn?",
                        prompt: "Optional reflection.",
                        text: $draft.learning,
                        identifier: "draft-example-learning"
                    )

                    VStack(alignment: .leading, spacing: RRSpacing.sm) {
                        Text("Capabilities used for matching")
                            .font(.rrHeadline)
                        Text("Résumé suggestions are not treated as confirmed until you review these selections.")
                            .font(.rrCaption)
                            .foregroundStyle(BrandTheme.inkMuted)
                        ForEach(Capability.allCases) { capability in
                            Toggle(
                                capability.title,
                                isOn: Binding(
                                    get: { draft.capabilities.contains(capability) },
                                    set: { selected in
                                        if selected, !draft.capabilities.contains(capability) {
                                            draft.capabilities.append(capability)
                                        } else if !selected {
                                            draft.capabilities.removeAll { $0 == capability }
                                        }
                                    }
                                )
                            )
                        }
                    }

                    LabeledPreparationField(
                        title: "Tools or methods used",
                        prompt: "Optional, separated by commas",
                        text: Binding(
                            get: { draft.tools.joined(separator: ",") },
                            set: { draft.tools = $0.components(separatedBy: ",") }
                        ),
                        identifier: "draft-example-tools"
                    )
                }
                .padding(.top, RRSpacing.sm)
            } label: {
                Label("More detail", systemImage: "slider.horizontal.3")
                    .font(.rrHeadline)
            }

            ForEach(draft.warnings, id: \.self) { warning in
                Label(warning, systemImage: "info.circle")
                    .font(.rrCaption)
                    .foregroundStyle(BrandTheme.inkMuted)
            }
        }
        .cardSurface()
    }
}

private struct ExperienceStrengtheningDraft: Equatable {
    let experienceID: UUID
    var situation: String
    var task: String
    var actionsText: String
    var result: String
    var evidence: String
    var learning: String
    var ownership: OwnershipLevel
    var capabilities: [Capability]
    var confidentiality: Confidentiality
    var isApprovedForMatching: Bool

    init(_ experience: Experience) {
        experienceID = experience.id
        situation = experience.situation
        task = experience.task
        actionsText = experience.actions.joined(separator: "\n")
        result = experience.result
        evidence = experience.evidence
        learning = experience.learning
        ownership = experience.ownership
        capabilities = experience.capabilities
        confidentiality = experience.confidentiality
        isApprovedForMatching = experience.isApprovedForMatching
    }

    var actions: [String] {
        actionsText.components(separatedBy: .newlines)
            .map(\.trimmedForPreparation)
            .filter { !$0.isEmpty }
    }

    func groundedExperience(using source: Experience) -> GroundedExperience {
        GroundedExperience(
            id: source.id,
            title: source.title,
            organisation: source.organisation,
            situation: situation.trimmedForPreparation,
            task: task.trimmedForPreparation,
            actions: actions,
            result: result.trimmedForPreparation,
            evidence: evidence.trimmedForPreparation,
            learning: learning.trimmedForPreparation,
            ownership: ownership,
            capabilities: capabilities,
            tools: source.tools,
            confidentiality: confidentiality,
            isApprovedForMatching: isApprovedForMatching
        )
    }

    func differs(from source: Experience) -> Bool {
        situation.trimmedForPreparation != source.situation
            || task.trimmedForPreparation != source.task
            || actions != source.actions
            || result.trimmedForPreparation != source.result
            || evidence.trimmedForPreparation != source.evidence
            || learning.trimmedForPreparation != source.learning
            || ownership != source.ownership
            || capabilities != source.capabilities
            || confidentiality != source.confidentiality
            || isApprovedForMatching != source.isApprovedForMatching
    }

    func apply(to source: Experience) {
        source.situation = situation.trimmedForPreparation
        source.task = task.trimmedForPreparation
        source.actions = actions
        source.result = result.trimmedForPreparation
        source.evidence = evidence.trimmedForPreparation
        source.learning = learning.trimmedForPreparation
        source.ownership = ownership
        source.capabilities = capabilities
        source.confidentiality = confidentiality
        source.isApprovedForMatching = isApprovedForMatching
    }
}

private struct AdaptiveEvidenceQuestions: View {
    @Binding var draft: ExperienceStrengtheningDraft
    let requirement: JobRequirement?
    @State private var rationale = ""
    @State private var asksForTask: Bool
    @State private var asksForResult: Bool
    @State private var asksForEvidence: Bool
    @State private var asksForLearning: Bool
    @State private var showsFullExample = false

    init(draft: Binding<ExperienceStrengtheningDraft>, requirement: JobRequirement?) {
        _draft = draft
        self.requirement = requirement
        let value = draft.wrappedValue
        _asksForTask = State(initialValue: value.task.trimmedForPreparation.isEmpty)
        _asksForResult = State(initialValue: value.result.split(whereSeparator: \.isWhitespace).count < 10)
        _asksForEvidence = State(initialValue: value.evidence.trimmedForPreparation.isEmpty)
        _asksForLearning = State(initialValue: value.learning.trimmedForPreparation.isEmpty)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: RRSpacing.md) {
            SectionHeading(title: "Strengthen only what matters", eyebrow: "ADAPTIVE QUESTIONS")
            Text("These details make the answer credible. Leave anything unknown blank—RoleReady will not fill it in for you.")
                .font(.rrBody)
                .foregroundStyle(BrandTheme.inkMuted)

            Picker("What was your part?", selection: $draft.ownership) {
                ForEach(OwnershipLevel.allCases) { ownership in
                    Text(ownership.phrasing).tag(ownership)
                }
            }

            if asksForTask {
                LabeledPreparationEditor(
                    title: "What were you responsible for?",
                    prompt: "Describe the part you personally owned, led, contributed to or supported.",
                    text: $draft.task,
                    identifier: "strengthen-task"
                )
            }

            if !hasDecisionReason {
                LabeledPreparationEditor(
                    title: "Why did you choose that approach?",
                    prompt: "Name one genuine reason, option or trade-off.",
                    text: $rationale,
                    identifier: "strengthen-rationale"
                )
                Button("Add this reason to my actions") {
                    let value = rationale.trimmedForPreparation
                    guard !value.isEmpty else { return }
                    let addition = "My reason for this approach was \(value)"
                    draft.actionsText += draft.actionsText.isEmpty ? addition : "\n\(addition)"
                    rationale = ""
                }
                .font(.rrHeadline)
                .foregroundStyle(BrandTheme.violet)
                .disabled(rationale.trimmedForPreparation.isEmpty)
            }

            if asksForResult {
                LabeledPreparationEditor(
                    title: "What changed as a result?",
                    prompt: "Describe the outcome without adding a metric you cannot support.",
                    text: $draft.result,
                    identifier: "strengthen-result"
                )
            }

            if asksForEvidence {
                LabeledPreparationEditor(
                    title: "How do you know it worked?",
                    prompt: "Add a measure, observation, test, sign-off or feedback if one exists.",
                    text: $draft.evidence,
                    identifier: "strengthen-evidence"
                )
            }

            if asksForLearning {
                LabeledPreparationEditor(
                    title: "What did you learn or repeat later?",
                    prompt: "Optional, but useful for panel follow-up questions.",
                    text: $draft.learning,
                    identifier: "strengthen-learning"
                )
            }

            if let requirement, !requirement.capabilities.isEmpty {
                VStack(alignment: .leading, spacing: RRSpacing.xs) {
                    Text("What does this example genuinely demonstrate?")
                        .font(.rrHeadline)
                    Text("Only select a capability you could defend with the example above.")
                        .font(.rrCaption)
                        .foregroundStyle(BrandTheme.inkMuted)
                    ForEach(requirement.capabilities) { capability in
                        Toggle(
                            capability.title,
                            isOn: Binding(
                                get: { draft.capabilities.contains(capability) },
                                set: { selected in
                                    if selected, !draft.capabilities.contains(capability) {
                                        draft.capabilities.append(capability)
                                    } else if !selected {
                                        draft.capabilities.removeAll { $0 == capability }
                                    }
                                }
                            )
                        )
                    }
                }
            }

            DisclosureGroup(isExpanded: $showsFullExample) {
                VStack(spacing: RRSpacing.md) {
                    LabeledPreparationEditor(
                        title: "What happened?",
                        prompt: "Add only context that helps the panel understand the challenge.",
                        text: $draft.situation,
                        identifier: "strengthen-full-situation"
                    )
                    LabeledPreparationEditor(
                        title: "Your responsibility",
                        prompt: "Make your part clear.",
                        text: $draft.task,
                        identifier: "strengthen-full-task"
                    )
                    LabeledPreparationEditor(
                        title: "Your actions",
                        prompt: "Put each action on a new line.",
                        text: $draft.actionsText,
                        identifier: "strengthen-full-actions"
                    )
                    LabeledPreparationEditor(
                        title: "Result",
                        prompt: "What changed?",
                        text: $draft.result,
                        identifier: "strengthen-full-result"
                    )
                    LabeledPreparationEditor(
                        title: "Proof",
                        prompt: "How do you know it worked?",
                        text: $draft.evidence,
                        identifier: "strengthen-full-evidence"
                    )
                    LabeledPreparationEditor(
                        title: "Learning",
                        prompt: "What would you repeat or change?",
                        text: $draft.learning,
                        identifier: "strengthen-full-learning"
                    )
                }
                .padding(.top, RRSpacing.sm)
            } label: {
                Label("Review the full example", systemImage: "square.and.pencil")
                    .font(.rrHeadline)
            }

            DisclosureGroup("Privacy level") {
                Picker("Privacy level", selection: Binding(
                    get: { draft.confidentiality },
                    set: { level in
                        let wasBlocked = draft.confidentiality.blocksAutomaticUse
                        draft.confidentiality = level
                        if level.blocksAutomaticUse, !wasBlocked {
                            draft.isApprovedForMatching = false
                        } else if !level.blocksAutomaticUse {
                            draft.isApprovedForMatching = true
                        }
                    }
                )) {
                    ForEach(Confidentiality.allCases) { level in
                        Text(level.title).tag(level)
                    }
                }
                if draft.confidentiality.blocksAutomaticUse {
                    Toggle("Allow this highly sensitive example for this preparation", isOn: $draft.isApprovedForMatching)
                        .tint(BrandTheme.warning)
                }
                Text("Highly sensitive examples are blocked from matching and answer generation unless you explicitly approve their use.")
                    .font(.rrCaption)
                    .foregroundStyle(BrandTheme.inkMuted)
            }
        }
        .cardSurface()
    }

    private var hasDecisionReason: Bool {
        let lower = draft.actions.joined(separator: " ").lowercased()
        return ["because", "chose", "decided", "instead", "trade-off", "so that"].contains(where: lower.contains)
    }
}

private struct LabeledPreparationField: View {
    let title: String
    let prompt: String
    @Binding var text: String
    let identifier: String

    var body: some View {
        VStack(alignment: .leading, spacing: RRSpacing.xs) {
            Text(title).font(.rrHeadline)
            TextField(prompt, text: $text)
                .textFieldStyle(.plain)
                .padding(RRSpacing.sm)
                .background(BrandTheme.surfaceMuted, in: RoundedRectangle(cornerRadius: RRRadius.small))
                .accessibilityIdentifier(identifier)
        }
    }
}

private struct LabeledPreparationEditor: View {
    let title: String
    let prompt: String
    @Binding var text: String
    let identifier: String

    var body: some View {
        VStack(alignment: .leading, spacing: RRSpacing.xs) {
            Text(title).font(.rrHeadline)
            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text(prompt)
                        .font(.rrBody)
                        .foregroundStyle(BrandTheme.inkMuted.opacity(0.72))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 9)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $text)
                    .font(.rrBody)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 92)
                    .accessibilityLabel(title)
                    .accessibilityIdentifier(identifier)
            }
            .padding(RRSpacing.xs)
            .background(BrandTheme.surfaceMuted, in: RoundedRectangle(cornerRadius: RRRadius.small))
        }
    }
}

@MainActor
private struct GuidedPracticeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState
    @Query private var answers: [GeneratedAnswer]

    let answerID: UUID
    let strengthen: () -> Void
    let finish: () -> Void

    @State private var startedAt = Date()
    @State private var cuesRevealed = false
    @State private var answerRevealed = false
    @State private var confidence: Int?
    @State private var saveError: String?
    @AccessibilityFocusState private var cuesHeadingFocused: Bool

    private var answer: GeneratedAnswer? {
        answers.first { $0.id == answerID }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: RRSpacing.lg) {
                if let answer {
                    VStack(alignment: .leading, spacing: RRSpacing.sm) {
                        PreparationProgress(step: .practice)
                        Text("7 · PRACTISE")
                            .font(.rrCaption)
                            .tracking(0.8)
                            .foregroundStyle(BrandTheme.violet)
                        Text("Remember the shape, not a script")
                            .font(.rrHero)
                        Text("Say the answer aloud before revealing the cues. This is preparation for before the interview, never live assistance.")
                            .font(.rrBody)
                            .foregroundStyle(BrandTheme.inkMuted)
                    }

                    HStack {
                        Label(answer.format.title, systemImage: "quote.bubble.fill")
                            .font(.rrCaption)
                            .foregroundStyle(BrandTheme.violet)
                        Spacer()
                        TimelineView(.periodic(from: startedAt, by: 1)) { context in
                            Label(duration(to: context.date), systemImage: "timer")
                                .font(.rrHeadline)
                                .monospacedDigit()
                                .accessibilityLabel("Practice timer \(duration(to: context.date))")
                        }
                    }

                    VStack(alignment: .leading, spacing: RRSpacing.lg) {
                        Text(answer.question)
                            .font(.system(.title, design: .rounded, weight: .bold))
                            .fixedSize(horizontal: false, vertical: true)

                        if cuesRevealed {
                            Divider()
                            Text("MEMORY CUES")
                                .font(.rrCaption)
                                .tracking(0.8)
                                .foregroundStyle(BrandTheme.amberText)
                                .accessibilityAddTraits(.isHeader)
                                .accessibilityFocused($cuesHeadingFocused)
                            ForEach(Array(answer.quickCues.prefix(5).enumerated()), id: \.offset) { index, cue in
                                HStack(alignment: .firstTextBaseline, spacing: RRSpacing.sm) {
                                    Text("\(index + 1)")
                                        .font(.caption.bold())
                                        .foregroundStyle(BrandTheme.violet)
                                        .frame(width: 28, height: 28)
                                        .background(BrandTheme.violetSoft, in: Circle())
                                    Text(cue).font(.rrHeadline)
                                }
                            }

                            Button(answerRevealed ? "Hide full answer" : "Reveal full answer") {
                                answerRevealed.toggle()
                            }
                            .font(.rrHeadline)
                            .foregroundStyle(BrandTheme.violet)

                            if answerRevealed {
                                Text(answer.content)
                                    .font(.rrBody)
                                    .foregroundStyle(BrandTheme.inkMuted)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        } else {
                            Button {
                                cuesRevealed = true
                                Task { @MainActor in
                                    await Task.yield()
                                    cuesHeadingFocused = true
                                }
                            } label: {
                                Label("Reveal memory cues", systemImage: "eye.fill")
                            }
                            .buttonStyle(PrimaryActionButtonStyle())
                            .accessibilityIdentifier("guided-reveal-cues")
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .cardSurface()
                    .privacySensitive()

                    if cuesRevealed {
                        confidenceCard(answer)

                        if !answer.followUps.isEmpty {
                            DisclosureGroup("Questions the panel may ask next") {
                                VStack(alignment: .leading, spacing: RRSpacing.sm) {
                                    ForEach(answer.followUps.prefix(5), id: \.self) { followUp in
                                        Label(followUp, systemImage: "questionmark.bubble")
                                            .font(.rrBody)
                                    }
                                }
                                .padding(.top, RRSpacing.sm)
                            }
                            .font(.rrHeadline)
                            .cardSurface(tint: BrandTheme.violetSoft.opacity(0.42))
                        }
                    }
                } else {
                    EmptyStatePanel(
                        title: "Approved answer unavailable",
                        message: "Return to the answer review and save it again before practising.",
                        symbol: "exclamationmark.triangle",
                        actionTitle: "Back to answer",
                        action: strengthen
                    )
                }
            }
            .padding(RRSpacing.md)
            .padding(.bottom, RRSpacing.xxl)
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("Focused practice")
        .navigationBarTitleDisplayMode(.inline)
        .screenBackground()
        .alert("Couldn’t save practice", isPresented: Binding(
            get: { saveError != nil },
            set: { if !$0 { saveError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(saveError ?? "Try again.")
        }
        .accessibilityIdentifier("guided-practice")
    }

    private func confidenceCard(_ answer: GeneratedAnswer) -> some View {
        VStack(alignment: .leading, spacing: RRSpacing.md) {
            SectionHeading(title: confidence == nil ? "How did that feel?" : "Practice saved", eyebrow: "REFLECT")
            if confidence == nil {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: RRSpacing.sm) { confidenceButtons(answer) }
                    VStack(spacing: RRSpacing.sm) { confidenceButtons(answer) }
                }
            } else {
                InfoBanner(
                    title: "Keep the ideas flexible",
                    message: "Come back for another rehearsal, or strengthen the source if any part still feels vague.",
                    kind: .success
                )
                Button {
                    startedAt = Date()
                    cuesRevealed = false
                    answerRevealed = false
                    confidence = nil
                } label: {
                    Label("Practise again", systemImage: "arrow.counterclockwise")
                }
                .buttonStyle(PrimaryActionButtonStyle())
                Button {
                    strengthen()
                } label: {
                    Label("Strengthen the source example", systemImage: "wrench.adjustable")
                }
                .buttonStyle(SecondaryActionButtonStyle())
                Button {
                    finish()
                } label: {
                    Label("Finish preparation", systemImage: "checkmark.circle.fill")
                }
                .buttonStyle(SecondaryActionButtonStyle())
                .accessibilityIdentifier("finish-guided-preparation")
            }
        }
        .cardSurface(tint: BrandTheme.tealSoft.opacity(0.45))
    }

    @ViewBuilder
    private func confidenceButtons(_ answer: GeneratedAnswer) -> some View {
        confidenceButton("Needs work", value: 2, answer: answer)
        confidenceButton("Getting there", value: 3, answer: answer)
        confidenceButton("Felt strong", value: 5, answer: answer)
    }

    private func confidenceButton(_ title: String, value: Int, answer: GeneratedAnswer) -> some View {
        Button(title) { savePractice(value, answer: answer) }
            .buttonStyle(value == 5 ? GuidedPracticeButtonStyle.primary : GuidedPracticeButtonStyle.secondary)
    }

    private func savePractice(_ value: Int, answer: GeneratedAnswer) {
        let elapsed = max(Int(Date().timeIntervalSince(startedAt)), 0)
        modelContext.insert(PracticeSession(
            answerID: answer.id,
            experienceID: answer.experienceID,
            opportunityID: answer.opportunityID,
            question: answer.question,
            durationSeconds: elapsed,
            confidence: value
        ))
        do {
            try modelContext.save()
            confidence = value
            HapticService.success(enabled: appState.hapticsEnabled)
        } catch {
            modelContext.rollback()
            saveError = error.localizedDescription
        }
    }

    private func duration(to end: Date) -> String {
        let seconds = max(Int(end.timeIntervalSince(startedAt)), 0)
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}

private enum GuidedPracticeButtonStyle: ButtonStyle {
    case primary
    case secondary

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.rrHeadline)
            .foregroundStyle(self == .primary ? BrandTheme.onAmber : BrandTheme.ink)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, RRSpacing.md)
            .padding(.vertical, 13)
            .background(
                (self == .primary ? BrandTheme.amber : BrandTheme.surfaceMuted)
                    .opacity(configuration.isPressed ? 0.72 : 1),
                in: RoundedRectangle(cornerRadius: RRRadius.medium)
            )
    }
}

private extension String {
    var trimmedForPreparation: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
