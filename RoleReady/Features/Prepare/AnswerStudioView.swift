import SwiftData
import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct AnswerStudioView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @Query(sort: \Experience.updatedAt, order: .reverse) private var experiences: [Experience]
    @Query(sort: \Opportunity.updatedAt, order: .reverse) private var opportunities: [Opportunity]
    @Query(sort: \GeneratedAnswer.updatedAt, order: .reverse) private var savedAnswers: [GeneratedAnswer]

    @State private var selectedExperienceID: UUID?
    @State private var selectedOpportunityID: UUID?
    @State private var question = ""
    @State private var format: AnswerFormat = .sixtySeconds
    @State private var audience: AnswerAudience = .hiringManager
    @State private var tone: AnswerTone = .natural
    @State private var draft: GeneratedDraft?
    @State private var editedContent = ""
    @State private var factsConfirmed = false
    @State private var approvedContent = ""
    @State private var generatedInputs: AnswerDraftInputs?
    @State private var lastSuggestedQuestion = ""
    @State private var hasLoadedInitialState = false
    @State private var selectedClaim: AnswerClaim?
    @State private var errorMessage: String?
    @State private var isSaving = false
    @State private var isGenerating = false
    @State private var pendingConfirmation: AnswerStudioConfirmation?
    @State private var baselineSnapshot: AnswerEditSnapshot?
    @State private var reconciledClaims: [AnswerClaim] = []
    @State private var sourceOverrides: [String: AnswerSourceField] = [:]
    @State private var answerWasUserEdited = false

    private let showsCloseButton: Bool
    private let answerID: UUID?
    private let dismissAfterSave: Bool
    private let onBack: (() -> Void)?
    private let onSaved: ((UUID, Bool) -> Void)?

    private let engine = GroundedAnswerEngine()
    private let provenanceService = AnswerProvenanceService()
    private let approvalService = AnswerApprovalService()

    init(
        answerID: UUID? = nil,
        experienceID: UUID? = nil,
        opportunityID: UUID? = nil,
        initialQuestion: String? = nil,
        initialFormat: AnswerFormat = .sixtySeconds,
        showsCloseButton: Bool = false,
        dismissAfterSave: Bool = true,
        onBack: (() -> Void)? = nil,
        onSaved: ((UUID, Bool) -> Void)? = nil
    ) {
        self.answerID = answerID
        _selectedExperienceID = State(initialValue: experienceID)
        _selectedOpportunityID = State(initialValue: opportunityID)
        _question = State(initialValue: initialQuestion ?? "")
        _format = State(initialValue: initialFormat)
        self.showsCloseButton = showsCloseButton
        self.dismissAfterSave = dismissAfterSave
        self.onBack = onBack
        self.onSaved = onSaved
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: RRSpacing.xl) {
                setup
                if let draft {
                    answerDraft(draft)
                } else {
                    generationEmptyState
                }
            }
            .padding(RRSpacing.md)
            .padding(.bottom, RRSpacing.xxl)
            .frame(maxWidth: 820)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle(answerID == nil ? "Answer Studio" : "Edit answer")
        .navigationBarTitleDisplayMode(.inline)
        .screenBackground()
        .interactiveDismissDisabled(hasUnsavedAnswer)
        .navigationBarBackButtonHidden(hasUnsavedAnswer && !showsCloseButton)
        .toolbar {
            if showsCloseButton {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", action: requestDismissal)
                }
            } else if hasUnsavedAnswer {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: requestDismissal) {
                        Label("Back", systemImage: "chevron.left")
                    }
                    .accessibilityIdentifier("answer-back")
                }
            }
            if answerID != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Delete answer", systemImage: "trash", role: .destructive) {
                            pendingConfirmation = .delete
                        }
                    } label: {
                        Label("More actions", systemImage: "ellipsis.circle")
                    }
                    .accessibilityIdentifier("answer-more-actions")
                }
            }
        }
        .task {
            await Task.yield()
            loadInitialStateIfNeeded()
        }
        .onChange(of: selectedOpportunityID) { _, _ in
            if question.isEmpty || question == lastSuggestedQuestion {
                let nextSuggestion = suggestedQuestion
                question = nextSuggestion
                lastSuggestedQuestion = nextSuggestion
            }
        }
        .onChange(of: currentInputs) { _, newInputs in
            guard draft != nil, let generatedInputs, newInputs != generatedInputs else { return }
            factsConfirmed = false
            approvedContent = ""
        }
        .onChange(of: editedContent) { _, newContent in
            if factsConfirmed, newContent != approvedContent {
                factsConfirmed = false
            }
            reconcileEditedClaims()
        }
        .onChange(of: factsConfirmed) { _, isConfirmed in
            if isConfirmed { approvedContent = editedContent }
        }
        .sheet(item: $selectedClaim) { claim in
            SourceClaimSheet(
                claim: claim,
                experience: selectedExperience,
                availableSources: selectedExperience.map { provenanceService.availableSources(for: $0) } ?? [],
                onConnect: { field in
                    connect(claim, to: field)
                }
            )
        }
        .alert("Answer Studio", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "Try again.")
        }
        .confirmationDialog(
            confirmationTitle,
            isPresented: Binding(
                get: { pendingConfirmation != nil },
                set: { if !$0 { pendingConfirmation = nil } }
            ),
            titleVisibility: .visible
        ) {
            confirmationActions
        } message: {
            Text(confirmationMessage)
        }
        .accessibilityIdentifier("answer-studio")
    }

    private var setup: some View {
        VStack(alignment: .leading, spacing: RRSpacing.md) {
            SectionHeading(title: "Build from approved facts", eyebrow: "GROUNDING")
            InfoBanner(
                title: "Evidence before eloquence",
                message: "RoleReady only uses the selected story. Missing facts stay missing, and every output clause keeps its source.",
                kind: .information
            )

            VStack(alignment: .leading, spacing: RRSpacing.md) {
                menuPicker("Story", symbol: "square.stack.3d.up.fill") {
                    Picker("Story", selection: $selectedExperienceID) {
                        Text("Choose a story").tag(UUID?.none)
                        ForEach(experiences) { experience in
                            Text(experience.title).tag(Optional(experience.id))
                        }
                    }
                }

                menuPicker("Role", symbol: "briefcase.fill") {
                    Picker("Role", selection: $selectedOpportunityID) {
                        Text("General preparation").tag(UUID?.none)
                        ForEach(opportunities) { opportunity in
                            Text("\(opportunity.roleTitle) · \(opportunity.organisation)").tag(Optional(opportunity.id))
                        }
                    }
                }

                VStack(alignment: .leading, spacing: RRSpacing.xs) {
                    Label("Interview question", systemImage: "text.bubble")
                        .font(.rrCaption)
                        .foregroundStyle(BrandTheme.inkMuted)
                    TextField("Tell me about a time…", text: $question, axis: .vertical)
                        .lineLimit(2...5)
                        .textFieldStyle(.plain)
                        .padding(RRSpacing.sm)
                        .background(BrandTheme.surfaceMuted, in: RoundedRectangle(cornerRadius: RRRadius.small))
                        .accessibilityIdentifier("answer-question")
                }

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: RRSpacing.sm) { optionPickers }
                    VStack(spacing: RRSpacing.sm) { optionPickers }
                }
            }
            .cardSurface()

            if isDraftOutdated {
                InfoBanner(
                    title: "Inputs changed",
                    message: "Your current wording is preserved. Regenerate to align it with the selected story, role and answer settings before saving.",
                    kind: .warning
                )
            }

            Button(action: requestGeneration) {
                if isGenerating {
                    HStack {
                        ProgressView().tint(.white)
                        Text("Creating grounded answer…")
                    }
                } else {
                    Label(draft == nil ? "Create grounded answer" : "Regenerate from source", systemImage: "wand.and.stars")
                }
            }
            .buttonStyle(PrimaryActionButtonStyle())
            .disabled(isGenerating || selectedExperience == nil || question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .accessibilityIdentifier("generate-answer")
        }
    }

    @ViewBuilder
    private var optionPickers: some View {
        compactPicker("Length", selection: $format, options: AnswerFormat.allCases)
        compactPicker("Audience", selection: $audience, options: AnswerAudience.allCases)
        compactPicker("Tone", selection: $tone, options: AnswerTone.allCases)
    }

    private func answerDraft(_ draft: GeneratedDraft) -> some View {
        let decision = currentApprovalDecision
        let activeWarnings = reviewWarnings(for: draft)
        let policyIssues = decision?.issues ?? ["Choose an available source example before approval."]
        let advisoryWarnings = activeWarnings.filter { !policyIssues.contains($0) }
        let wordCount = decision?.wordCount ?? editedContent.split(whereSeparator: \.isWhitespace).count
        let unsupportedCount = reconciledClaims.filter(\.needsSource).count

        return VStack(alignment: .leading, spacing: RRSpacing.lg) {
            HStack(alignment: .firstTextBaseline) {
                SectionHeading(
                    title: "Suggested phrasing",
                    eyebrow: "\(wordCount) WORDS · ABOUT \(decision?.estimatedSpeakingSeconds ?? 0) SEC"
                )
                Spacer()
                Label(factsConfirmed ? "Ready" : "Draft", systemImage: factsConfirmed ? "checkmark.seal.fill" : "pencil.circle")
                    .font(.rrCaption)
                    .foregroundStyle(factsConfirmed ? BrandTheme.success : BrandTheme.warning)
            }

            VStack(alignment: .leading, spacing: RRSpacing.md) {
                TextEditor(text: $editedContent)
                    .font(.rrBody)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 210)
                    .accessibilityLabel("Generated answer")
                    .accessibilityHint("Editable suggested phrasing")
                    .accessibilityIdentifier("answer-content")

                Divider()
                HStack {
                    Label("\(reconciledClaims.count) clauses checked against source", systemImage: "link")
                        .font(.rrCaption)
                        .foregroundStyle(BrandTheme.inkMuted)
                    Spacer()
                    Button {
                        UIPasteboard.general.setItems(
                            [[UTType.utf8PlainText.identifier: editedContent]],
                            options: [
                                .localOnly: true,
                                .expirationDate: Date().addingTimeInterval(10 * 60)
                            ]
                        )
                        appState.showToast("Copied locally for 10 minutes", symbol: "doc.on.doc.fill")
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                    }
                    .font(.rrHeadline)
                }
            }
            .cardSurface()

            if editedContent != draft.content {
                InfoBanner(
                    title: unsupportedCount == 0 ? "Edited wording rechecked" : "\(unsupportedCount) edited clause\(unsupportedCount == 1 ? "" : "s") need a source",
                    message: unsupportedCount == 0
                        ? "Your wording is still connected to the evidence shown below. Approval was revoked so you can review it again."
                        : "RoleReady will save your wording as a draft, but it cannot call unsupported additions verified. Connect each marked clause to evidence, rewrite it, or remove it.",
                    kind: unsupportedCount == 0 ? .information : .warning
                )
            }

            if !draft.quickCues.isEmpty {
                VStack(alignment: .leading, spacing: RRSpacing.sm) {
                    Text("QUICK CUES")
                        .font(.rrCaption)
                        .tracking(0.8)
                        .foregroundStyle(BrandTheme.violet)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: RRSpacing.xs) {
                            ForEach(draft.quickCues, id: \.self) { cue in
                                Text(cue)
                                    .font(.rrCaption)
                                    .padding(.horizontal, RRSpacing.sm)
                                    .padding(.vertical, RRSpacing.xs)
                                    .background(BrandTheme.violetSoft, in: Capsule())
                            }
                        }
                    }
                }
            }

            sourceTrail

            if !policyIssues.isEmpty {
                VStack(spacing: RRSpacing.sm) {
                    ForEach(policyIssues, id: \.self) { issue in
                        InfoBanner(title: "Needed before approval", message: issue, kind: .warning)
                    }
                }
            }

            if !advisoryWarnings.isEmpty {
                VStack(spacing: RRSpacing.sm) {
                    ForEach(advisoryWarnings, id: \.self) { warning in
                        InfoBanner(title: "Privacy reminder", message: warning, kind: .information)
                    }
                }
            }

            VStack(alignment: .leading, spacing: RRSpacing.md) {
                Toggle(isOn: approvalBinding) {
                    VStack(alignment: .leading, spacing: RRSpacing.xxs) {
                        Text("I approve this grounded answer")
                            .font(.rrHeadline)
                        Text("I have checked the facts, numbers and my level of ownership. Approved answers can appear in practice.")
                            .font(.subheadline)
                            .foregroundStyle(BrandTheme.inkMuted)
                    }
                }
                .tint(BrandTheme.success)
                .disabled(decision?.canApprove != true || isDraftOutdated)
                .accessibilityHint(policyIssues.first ?? "Approves this answer for practice")
                .accessibilityIdentifier("confirm-answer-facts")

                Button {
                    save(draft)
                } label: {
                    Label(
                        factsConfirmed ? (answerID == nil ? "Approve to Practise" : "Update approved answer") : (answerID == nil ? "Save as draft" : "Update draft"),
                        systemImage: factsConfirmed ? "checkmark.seal.fill" : "square.and.arrow.down"
                    )
                }
                .buttonStyle(PrimaryActionButtonStyle())
                .disabled(isSaving || isDraftOutdated || editedContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityIdentifier("save-answer")
            }
            .cardSurface(tint: BrandTheme.tealSoft.opacity(0.55))

            followUps(draft)
        }
    }

    private var generationEmptyState: some View {
        EmptyStatePanel(
            title: "Your source stays visible",
            message: "Choose a story and question. RoleReady will produce several useful formats without adding achievements or numbers.",
            symbol: "link.badge.plus"
        )
    }

    private var sourceTrail: some View {
        VStack(alignment: .leading, spacing: RRSpacing.sm) {
            SectionHeading(title: "Where each claim came from", eyebrow: "TAP TO CHECK")
            ForEach(reconciledClaims) { claim in
                Button {
                    selectedClaim = claim
                } label: {
                    VStack(alignment: .leading, spacing: RRSpacing.xs) {
                        HStack(spacing: RRSpacing.xs) {
                            Label(
                                claim.needsSource ? "Needs a source" : "Supported by \(claim.sourceField)",
                                systemImage: claim.needsSource ? "exclamationmark.triangle.fill" : "checkmark.shield.fill"
                            )
                            .font(.caption.bold())
                            .foregroundStyle(claim.needsSource ? BrandTheme.warning : BrandTheme.success)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right")
                                .font(.caption.bold())
                                .foregroundStyle(BrandTheme.inkMuted)
                        }
                        Text(claim.text)
                            .font(.subheadline)
                            .foregroundStyle(BrandTheme.ink)
                            .lineLimit(3)
                            .multilineTextAlignment(.leading)
                    }
                    .padding(RRSpacing.sm)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        claim.needsSource ? BrandTheme.amberSoft.opacity(0.55) : BrandTheme.surface,
                        in: RoundedRectangle(cornerRadius: RRRadius.small)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(
                    claim.needsSource
                        ? "Needs a source. \(claim.text)"
                        : "Supported by \(claim.sourceField). \(claim.text)"
                )
                .accessibilityHint(claim.needsSource ? "Opens evidence choices for this clause" : "Shows the supporting evidence")
                .accessibilityIdentifier(claim.needsSource ? "answer-claim-needs-source" : "answer-claim-supported")
            }
        }
    }

    private func followUps(_ draft: GeneratedDraft) -> some View {
        VStack(alignment: .leading, spacing: RRSpacing.md) {
            SectionHeading(title: "Likely follow-ups", eyebrow: "STAY NATURAL")
            ForEach(draft.followUps, id: \.self) { question in
                Label(question, systemImage: "arrow.turn.down.right")
                    .font(.rrBody)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(RRSpacing.sm)
                    .background(BrandTheme.surface, in: RoundedRectangle(cornerRadius: RRRadius.small))
            }
        }
    }

    private func menuPicker<Content: View>(_ title: String, symbol: String, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            Label(title, systemImage: symbol)
                .font(.rrCaption)
                .foregroundStyle(BrandTheme.inkMuted)
            Spacer()
            content().labelsHidden().pickerStyle(.menu)
        }
    }

    private func compactPicker<Option: Identifiable & Hashable>(
        _ title: String,
        selection: Binding<Option>,
        options: [Option]
    ) -> some View where Option.ID == String {
        VStack(alignment: .leading, spacing: RRSpacing.xxs) {
            Text(title.uppercased())
                .font(.caption2.bold())
                .foregroundStyle(BrandTheme.inkMuted)
            Picker(title, selection: selection) {
                ForEach(options) { option in
                    Text(optionTitle(option)).tag(option)
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, RRSpacing.xs)
            .background(BrandTheme.surfaceMuted, in: RoundedRectangle(cornerRadius: RRRadius.small))
        }
        .frame(maxWidth: .infinity)
    }

    private func optionTitle<Option>(_ option: Option) -> String {
        if let format = option as? AnswerFormat { return format.title }
        if let audience = option as? AnswerAudience { return audience.title }
        if let tone = option as? AnswerTone { return tone.title }
        return String(describing: option)
    }

    private var selectedExperience: Experience? {
        guard let selectedExperienceID else { return nil }
        return experiences.first { $0.id == selectedExperienceID }
    }

    private var selectedOpportunity: Opportunity? {
        guard let selectedOpportunityID else { return nil }
        return opportunities.first { $0.id == selectedOpportunityID }
    }

    private var existingAnswer: GeneratedAnswer? {
        guard let answerID else { return nil }
        return savedAnswers.first { $0.id == answerID }
    }

    private var currentInputs: AnswerDraftInputs {
        AnswerDraftInputs(
            experienceID: selectedExperienceID,
            experienceRevision: selectedExperience?.updatedAt,
            opportunityID: selectedOpportunityID,
            opportunityRevision: selectedOpportunity?.contentUpdatedAt,
            question: question.trimmingCharacters(in: .whitespacesAndNewlines),
            format: format,
            audience: audience,
            tone: tone
        )
    }

    private var allowedContext: String {
        [question, selectedOpportunity?.roleTitle ?? ""]
            .joined(separator: " ")
    }

    private var currentApprovalDecision: AnswerApprovalDecision? {
        guard let selectedExperience else { return nil }
        return approvalService.decision(
            content: editedContent,
            format: format,
            claims: reconciledClaims,
            experience: selectedExperience,
            allowedContext: allowedContext
        )
    }

    private var approvalBinding: Binding<Bool> {
        Binding(
            get: {
                factsConfirmed
                    && currentApprovalDecision?.canApprove == true
                    && !isDraftOutdated
            },
            set: { wantsApproval in
                guard wantsApproval else {
                    factsConfirmed = false
                    approvedContent = ""
                    return
                }
                guard !isDraftOutdated,
                      let decision = currentApprovalDecision,
                      decision.canApprove else {
                    factsConfirmed = false
                    errorMessage = currentApprovalDecision?.issues.first
                        ?? "This answer still needs review before approval."
                    return
                }
                factsConfirmed = true
            }
        )
    }

    private func reconcileEditedClaims() {
        guard let draft, let selectedExperience else {
            reconciledClaims = []
            return
        }
        let nextClaims = provenanceService.reconcile(
            content: editedContent,
            generatedContent: draft.content,
            generatedClaims: draft.claims,
            experience: selectedExperience,
            sourceOverrides: sourceOverrides
        )
        if nextClaims != reconciledClaims {
            reconciledClaims = nextClaims
        }
    }

    private func connect(_ claim: AnswerClaim, to field: AnswerSourceField) {
        sourceOverrides[provenanceService.claimKey(for: claim.text)] = field
        factsConfirmed = false
        approvedContent = ""
        reconcileEditedClaims()
        selectedClaim = nil

        let updatedClaim = reconciledClaims.first {
            provenanceService.claimKey(for: $0.text) == provenanceService.claimKey(for: claim.text)
        }
        if updatedClaim?.needsSource == false {
            appState.showToast("Clause connected to \(field.title.lowercased())", symbol: "link.badge.plus")
        } else {
            appState.showToast("Source connected — revise unsupported wording", symbol: "exclamationmark.triangle.fill")
        }
    }

    private var suggestedQuestion: String {
        guard let selectedOpportunityID,
              let opportunity = opportunities.first(where: { $0.id == selectedOpportunityID }) else {
            return "Tell me about a piece of work you’re proud of."
        }
        return "Tell me about an example that shows why you’re suited to the \(opportunity.roleTitle) role."
    }

    private var isDraftOutdated: Bool {
        draft != nil && generatedInputs != currentInputs
    }

    private var currentEditSnapshot: AnswerEditSnapshot? {
        guard draft != nil else { return nil }
        return AnswerEditSnapshot(
            inputs: currentInputs,
            content: editedContent,
            factsConfirmed: factsConfirmed
        )
    }

    private var hasUnsavedAnswer: Bool {
        guard let currentEditSnapshot else { return false }
        guard let baselineSnapshot else { return true }
        return currentEditSnapshot != baselineSnapshot
    }

    private var confirmationTitle: String {
        switch pendingConfirmation {
        case .delete: "Delete this answer?"
        case .replaceDraft: "Replace your current wording?"
        case .discard: "Discard unsaved changes?"
        case nil: "Answer Studio"
        }
    }

    private var confirmationMessage: String {
        switch pendingConfirmation {
        case .delete: "The source evidence story remains in your bank."
        case .replaceDraft: "Regenerating creates fresh wording from the current source and settings. Your edits cannot be recovered."
        case .discard: "Your saved answer remains unchanged. Any edits made on this screen will be lost."
        case nil: ""
        }
    }

    @ViewBuilder
    private var confirmationActions: some View {
        switch pendingConfirmation {
        case .delete:
            Button("Delete answer and practice history", role: .destructive, action: deleteAnswer)
        case .replaceDraft:
            Button("Regenerate and replace", role: .destructive) {
                pendingConfirmation = nil
                generate()
            }
        case .discard:
            Button("Discard changes", role: .destructive) {
                pendingConfirmation = nil
                completeDismissal()
            }
        case nil:
            EmptyView()
        }
        Button("Cancel", role: .cancel) { pendingConfirmation = nil }
    }

    private func requestGeneration() {
        if let draft, editedContent != draft.content {
            pendingConfirmation = .replaceDraft
        } else {
            generate()
        }
    }

    private func requestDismissal() {
        if hasUnsavedAnswer {
            pendingConfirmation = .discard
        } else {
            completeDismissal()
        }
    }

    private func completeDismissal() {
        if let onBack {
            onBack()
        } else {
            dismiss()
        }
    }

    private func generate() {
        guard let selectedExperience else { return }
        let request = AnswerCompositionRequest(
            question: question,
            experience: GroundedExperience(selectedExperience),
            format: format,
            audience: audience,
            tone: tone,
            roleTitle: selectedOpportunity?.roleTitle
        )
        isGenerating = true
        Task { @MainActor in
            defer { isGenerating = false }
            do {
                let service = LanguageProviderRegistry().resolvedService(for: appState.languageProvider)
                let newDraft: GeneratedDraft
                do {
                    newDraft = try await service.composeAnswer(request)
                } catch where service.descriptor.kind != .deterministicLocal {
                    newDraft = try await DeterministicLanguageService().composeAnswer(request)
                    appState.showToast("Used private basic fallback", symbol: "shield.fill")
                }
                draft = newDraft
                editedContent = newDraft.content
                reconciledClaims = newDraft.claims
                sourceOverrides = [:]
                answerWasUserEdited = false
                factsConfirmed = false
                approvedContent = ""
                generatedInputs = currentInputs
                HapticService.success(enabled: appState.hapticsEnabled)
            } catch {
                errorMessage = error.localizedDescription
                HapticService.warning(enabled: appState.hapticsEnabled)
            }
        }
    }

    private func save(_ draft: GeneratedDraft) {
        guard let selectedExperience else { return }
        let decision = approvalService.decision(
            content: editedContent,
            format: format,
            claims: reconciledClaims,
            experience: selectedExperience,
            allowedContext: allowedContext
        )
        guard !factsConfirmed || decision.canApprove else {
            factsConfirmed = false
            errorMessage = decision.issues.first ?? "This answer still needs review before approval."
            return
        }
        isSaving = true
        let answer: GeneratedAnswer
        let previouslyConfirmedExperienceID: UUID?
        if let existingAnswer {
            answer = existingAnswer
            previouslyConfirmedExperienceID = existingAnswer.isFactConfirmed ? existingAnswer.experienceID : nil
        } else {
            answer = GeneratedAnswer(
                question: question,
                experienceID: selectedExperience.id,
                opportunityID: selectedOpportunityID,
                format: format,
                audience: audience,
                tone: tone,
                content: editedContent,
                quickCues: draft.quickCues,
                sourceFields: reconciledClaims.map(\.sourceField),
                sourceClaims: [],
                followUps: draft.followUps
            )
            previouslyConfirmedExperienceID = nil
            modelContext.insert(answer)
        }

        answer.question = question.trimmingCharacters(in: .whitespacesAndNewlines)
        answer.experienceID = selectedExperience.id
        answer.opportunityID = selectedOpportunityID
        answer.format = format
        answer.audience = audience
        answer.tone = tone
        answer.content = editedContent.trimmingCharacters(in: .whitespacesAndNewlines)
        answer.quickCues = draft.quickCues
        answer.sourceFields = reconciledClaims.map(\.sourceField)
        answer.sourceClaims = provenanceService.storedClaims(from: reconciledClaims)
        answer.followUps = draft.followUps
        answer.isFactConfirmed = factsConfirmed
        answer.isUserEdited = answerWasUserEdited || editedContent != draft.content
        answer.sourceExperienceUpdatedAt = selectedExperience.updatedAt
        answer.sourceOpportunityUpdatedAt = selectedOpportunity?.contentUpdatedAt
        answer.updatedAt = Date()

        if factsConfirmed, previouslyConfirmedExperienceID != selectedExperience.id {
            selectedExperience.useCount += 1
        }
        do {
            try modelContext.save()
            baselineSnapshot = currentEditSnapshot
            appState.showToast(factsConfirmed ? "Answer ready for practice" : "Draft saved")
            HapticService.success(enabled: appState.hapticsEnabled)
            onSaved?(answer.id, factsConfirmed)
            if dismissAfterSave {
                dismiss()
            }
        } catch {
            modelContext.rollback()
            errorMessage = error.localizedDescription
        }
        isSaving = false
    }

    private func loadInitialStateIfNeeded() {
        guard !hasLoadedInitialState else { return }
        hasLoadedInitialState = true

        if let answerID {
            guard let answer = savedAnswers.first(where: { $0.id == answerID }) else {
                errorMessage = "This saved answer is no longer available."
                return
            }
            selectedExperienceID = answer.experienceID
            selectedOpportunityID = answer.opportunityID
            question = answer.question
            format = answer.format
            audience = answer.audience
            tone = answer.tone

            let source = experiences.first { $0.id == answer.experienceID }
            let sourceOptions = source.map { provenanceService.availableSources(for: $0) } ?? []
            let recoveredStoredClaims = answer.sourceClaims.map { storedClaim in
                let recoveredSource = sourceOptions.first {
                    $0.title.localizedCaseInsensitiveCompare(storedClaim.sourceField) == .orderedSame
                }?.text ?? {
                    switch storedClaim.sourceField {
                    case "Question context": answer.question
                    case "Story title": source?.title ?? ""
                    default: ""
                    }
                }()
                let isUntraceableEdit = answer.isUserEdited && storedClaim.origin == .legacy
                return StoredAnswerClaim(
                    sourceField: isUntraceableEdit ? "Edited — source needed" : storedClaim.sourceField,
                    text: storedClaim.text,
                    sourceText: storedClaim.sourceText.isEmpty ? recoveredSource : storedClaim.sourceText,
                    origin: isUntraceableEdit ? .editedUnsupported : storedClaim.origin,
                    isSupported: storedClaim.isSupported && !isUntraceableEdit
                )
            }
            let roleTitle = answer.opportunityID
                .flatMap { id in opportunities.first { $0.id == id }?.roleTitle } ?? ""
            let claims = source.map {
                AnswerClaimValidator().validate(
                    recoveredStoredClaims,
                    question: answer.question,
                    format: answer.format,
                    audience: answer.audience,
                    tone: answer.tone,
                    roleTitle: roleTitle,
                    experience: GroundedExperience($0)
                )
            } ?? recoveredStoredClaims.map { stored in
                AnswerClaim(
                    text: stored.text,
                    sourceField: "Edited — source needed",
                    origin: .editedUnsupported,
                    isSupported: false
                )
            }
            let warnings = source.map {
                engine.reviewWarnings(
                    output: answer.content,
                    against: $0,
                    allowedContext: [answer.question, selectedOpportunity?.roleTitle ?? ""].joined(separator: " ")
                )
            } ?? ["The source story is unavailable. This answer cannot be approved until it is grounded again."]
            draft = GeneratedDraft(
                content: answer.content,
                quickCues: answer.quickCues,
                claims: claims,
                followUps: answer.followUps,
                warnings: warnings,
                wordCount: answer.content.split(whereSeparator: \.isWhitespace).count
            )
            editedContent = answer.content
            reconciledClaims = claims
            sourceOverrides = [:]
            answerWasUserEdited = answer.isUserEdited
            generatedInputs = AnswerDraftInputs(
                experienceID: answer.experienceID,
                experienceRevision: answer.sourceExperienceUpdatedAt,
                opportunityID: answer.opportunityID,
                opportunityRevision: answer.sourceOpportunityUpdatedAt,
                question: answer.question.trimmingCharacters(in: .whitespacesAndNewlines),
                format: answer.format,
                audience: answer.audience,
                tone: answer.tone
            )
            let sourceIsCurrent = answer.isApprovalCurrent(for: source, opportunity: selectedOpportunity)
            let approvalIsCurrent = source.map {
                approvalService.decision(
                    content: answer.content,
                    format: answer.format,
                    claims: claims,
                    experience: $0,
                    allowedContext: [answer.question, selectedOpportunity?.roleTitle ?? ""].joined(separator: " ")
                ).canApprove
            } ?? false
            factsConfirmed = sourceIsCurrent && approvalIsCurrent
            approvedContent = factsConfirmed ? answer.content : ""
            baselineSnapshot = currentEditSnapshot
            if answer.isFactConfirmed, !sourceIsCurrent {
                appState.showToast("Source changed — reconfirm this answer", symbol: "exclamationmark.triangle.fill")
            }
            return
        }

        if selectedExperienceID == nil { selectedExperienceID = experiences.first?.id }
        if selectedOpportunityID == nil {
            selectedOpportunityID = opportunities.first(where: { $0.status == .interviewing })?.id
                ?? opportunities.first(where: { $0.status == .preparing })?.id
        }
        if question.isEmpty {
            question = suggestedQuestion
            lastSuggestedQuestion = question
        }
    }

    private func reviewWarnings(for draft: GeneratedDraft) -> [String] {
        guard let selectedExperience else { return draft.warnings }
        return engine.reviewWarnings(
            output: editedContent,
            against: selectedExperience,
            allowedContext: allowedContext
        )
    }

    private func deleteAnswer() {
        guard let answer = existingAnswer else { return }
        do {
            let answerID = answer.id
            try modelContext.fetch(FetchDescriptor<PracticeSession>())
                .filter { $0.answerID == answerID }
                .forEach(modelContext.delete)
            modelContext.delete(answer)
            try modelContext.save()
            appState.showToast("Answer deleted", symbol: "trash.fill")
            dismiss()
        } catch {
            modelContext.rollback()
            errorMessage = error.localizedDescription
        }
    }
}

private struct AnswerDraftInputs: Equatable {
    let experienceID: UUID?
    let experienceRevision: Date?
    let opportunityID: UUID?
    let opportunityRevision: Date?
    let question: String
    let format: AnswerFormat
    let audience: AnswerAudience
    let tone: AnswerTone
}

private struct AnswerEditSnapshot: Equatable {
    let inputs: AnswerDraftInputs
    let content: String
    let factsConfirmed: Bool
}

private enum AnswerStudioConfirmation {
    case delete
    case replaceDraft
    case discard
}

private struct SourceClaimSheet: View {
    @Environment(\.dismiss) private var dismiss
    let claim: AnswerClaim
    let experience: Experience?
    let availableSources: [AnswerSourceOption]
    let onConnect: (AnswerSourceField) -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: RRSpacing.lg) {
                    Label(
                        claim.needsSource ? "SOURCE NEEDED" : "SUPPORTED CLAIM",
                        systemImage: claim.needsSource ? "exclamationmark.triangle.fill" : "checkmark.shield.fill"
                    )
                        .font(.rrCaption)
                        .tracking(0.8)
                        .foregroundStyle(claim.needsSource ? BrandTheme.warning : BrandTheme.success)
                    Text(claim.needsSource ? "Check this wording" : claim.sourceField)
                        .font(.rrHero)
                    Text("Answer clause")
                        .font(.rrCaption)
                        .foregroundStyle(BrandTheme.inkMuted)
                    Text(claim.text)
                        .font(.rrBody)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .cardSurface(tint: claim.needsSource ? BrandTheme.amberSoft.opacity(0.5) : BrandTheme.violetSoft.opacity(0.5))

                    if claim.needsSource {
                        InfoBanner(
                            title: "Not verified yet",
                            message: claim.sourceText.isEmpty
                                ? "This edited clause is not connected to evidence. Choose the saved detail that supports it, or return to the answer and rewrite or remove it."
                                : "This clause is connected to \(claim.sourceField.lowercased()), but it adds wording that the saved detail does not fully support. Revise the clause before approval.",
                            kind: .warning
                        )
                    }

                    if !claim.sourceText.isEmpty {
                        VStack(alignment: .leading, spacing: RRSpacing.xs) {
                            Text(claim.needsSource ? "CONNECTED EVIDENCE" : "SUPPORTING EVIDENCE")
                                .font(.rrCaption)
                                .tracking(0.8)
                                .foregroundStyle(BrandTheme.inkMuted)
                            Text(claim.sourceText)
                                .font(.rrBody)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .cardSurface()
                        }
                    } else if !claim.needsSource {
                        InfoBanner(
                            title: "Older source record",
                            message: "This saved claim names \(claim.sourceField.lowercased()), but its exact source excerpt was not stored by the earlier answer format.",
                            kind: .information
                        )
                    }

                    if claim.needsSource, !availableSources.isEmpty {
                        VStack(alignment: .leading, spacing: RRSpacing.sm) {
                            SectionHeading(title: "Connect to saved evidence", eyebrow: "CHOOSE ONE")
                            Text("Connecting a field lets RoleReady check the wording; it does not automatically make an unsupported claim true.")
                                .font(.subheadline)
                                .foregroundStyle(BrandTheme.inkMuted)

                            ForEach(availableSources) { source in
                                Button {
                                    onConnect(source.field)
                                    dismiss()
                                } label: {
                                    VStack(alignment: .leading, spacing: RRSpacing.xxs) {
                                        HStack {
                                            Text(source.title)
                                                .font(.rrHeadline)
                                            Spacer()
                                            Image(systemName: "link.badge.plus")
                                                .foregroundStyle(BrandTheme.violet)
                                        }
                                        Text(source.text)
                                            .font(.subheadline)
                                            .foregroundStyle(BrandTheme.inkMuted)
                                            .lineLimit(3)
                                            .multilineTextAlignment(.leading)
                                    }
                                    .padding(RRSpacing.sm)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(BrandTheme.surface, in: RoundedRectangle(cornerRadius: RRRadius.small))
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Connect to \(source.title). \(source.text)")
                                .accessibilityHint("Checks this answer clause against the selected saved evidence")
                                .accessibilityIdentifier("connect-claim-\(source.field.rawValue)")
                            }
                        }
                    }

                    if let experience {
                        Divider()
                        Text(experience.title)
                            .font(.rrHeadline)
                        HStack {
                            ConfidentialityBadge(level: experience.confidentiality)
                            Spacer()
                            Text(experience.updatedAt, format: .dateTime.day().month().year())
                                .font(.rrCaption)
                                .foregroundStyle(BrandTheme.inkMuted)
                        }
                    }
                    InfoBanner(
                        title: "Private, local check",
                        message: "RoleReady checks this wording against the saved example on this device. It does not search the web or another example.",
                        kind: .information
                    )
                }
                .padding(RRSpacing.lg)
            }
            .navigationTitle("Source")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .screenBackground()
        }
        .presentationDetents([.medium, .large])
        .accessibilityIdentifier("source-claim-sheet")
    }
}
