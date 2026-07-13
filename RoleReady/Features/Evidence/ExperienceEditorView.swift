import SwiftData
import SwiftUI

@MainActor
struct ExperienceEditorView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState

    @State private var draft: ExperienceEditorDraft
    @State private var baseline: ExperienceEditorDraft
    @State private var loadState: ExperienceEditorLoadState
    @State private var step: ExperienceEditorStep = .basics
    @State private var attemptedSteps: Set<ExperienceEditorStep> = []
    @State private var isSaving = false
    @State private var isConfirmingDiscard = false
    @State private var issue: ExperienceEditorIssue?
    @State private var hasSetInitialFocus = false

    @FocusState private var focusedField: ExperienceEditorFocusField?

    private let experienceID: UUID?

    init(experienceID: UUID? = nil) {
        self.experienceID = experienceID
        let initialDraft = ExperienceEditorDraft()
        _draft = State(initialValue: initialDraft)
        _baseline = State(initialValue: initialDraft)
        _loadState = State(initialValue: experienceID == nil ? .ready : .loading)
    }

    var body: some View {
        NavigationStack {
            editorContent
                .navigationTitle(experienceID == nil ? "Add evidence" : "Edit evidence")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel", action: requestDismissal)
                            .accessibilityIdentifier("experienceEditor.cancel")
                    }

                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button("Done") {
                            focusedField = nil
                        }
                    }
                }
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    if loadState == .ready {
                        ExperienceEditorFooter(
                            step: step,
                            isSaving: isSaving,
                            goBack: goBack,
                            continueOrSave: primaryAction
                        )
                    }
                }
        }
        .screenBackground()
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(isDirty)
        .task {
            loadExperienceIfNeeded()
            if experienceID == nil, !hasSetInitialFocus {
                hasSetInitialFocus = true
                await Task.yield()
                focusedField = .title
            }
        }
        .confirmationDialog(
            "Discard your changes?",
            isPresented: $isConfirmingDiscard,
            titleVisibility: .visible
        ) {
            Button("Discard changes", role: .destructive) {
                dismiss()
            }
            Button("Keep editing", role: .cancel) {}
        } message: {
            Text("This story has not been saved.")
        }
        .alert(issue?.title ?? "Evidence editor", isPresented: Binding(
            get: { issue != nil },
            set: { if !$0 { issue = nil } }
        )) {
            Button("OK", role: .cancel) { issue = nil }
        } message: {
            Text(issue?.message ?? "Try again.")
        }
        .accessibilityIdentifier("experienceEditor.root")
    }

    @ViewBuilder
    private var editorContent: some View {
        switch loadState {
        case .loading:
            VStack(spacing: RRSpacing.md) {
                ProgressView()
                Text("Loading your evidence story…")
                    .font(.rrBody)
                    .foregroundStyle(BrandTheme.inkMuted)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("experienceEditor.loading")

        case .ready:
            Form {
                ExperienceEditorProgressHeader(step: step)
                    .listRowInsets(.init(top: RRSpacing.md, leading: RRSpacing.md, bottom: RRSpacing.sm, trailing: RRSpacing.md))
                    .listRowBackground(Color.clear)

                let stepProblems = visibleProblems(for: step)
                if !stepProblems.isEmpty {
                    ExperienceEditorValidationSummary(problems: stepProblems)
                        .listRowInsets(.init(top: RRSpacing.xs, leading: RRSpacing.md, bottom: RRSpacing.xs, trailing: RRSpacing.md))
                        .listRowBackground(Color.clear)
                        .accessibilityIdentifier("experienceEditor.validation")
                }

                activeStepContent
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .background {
                BrandTheme.canvasGradient.ignoresSafeArea()
            }
            .scrollDismissesKeyboard(.interactively)
            .tint(BrandTheme.violet)
            .accessibilityIdentifier("experienceEditor.form")

        case .failed(let message):
            ContentUnavailableView {
                Label("Story unavailable", systemImage: "exclamationmark.triangle")
            } description: {
                Text(message)
            } actions: {
                Button("Close") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .tint(BrandTheme.violet)
            }
            .accessibilityIdentifier("experienceEditor.loadFailed")
        }
    }

    @ViewBuilder
    private var activeStepContent: some View {
        switch step {
        case .basics:
            basicsContent
        case .context:
            contextContent
        case .actions:
            actionsContent
        case .outcome:
            outcomeContent
        case .privacy:
            privacyContent
        }
    }

    private var basicsContent: some View {
        Group {
            Section {
                TextField("e.g. Rebuilt a legacy reporting workflow", text: $draft.title)
                    .textInputAutocapitalization(.sentences)
                    .submitLabel(.next)
                    .focused($focusedField, equals: .title)
                    .onSubmit { focusedField = .organisation }
                    .accessibilityLabel("Story title")
                    .accessibilityIdentifier("experienceEditor.title")
                fieldProblem(.title)

                TextField("Organisation, university or personal project", text: $draft.organisation)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.done)
                    .focused($focusedField, equals: .organisation)
                    .accessibilityLabel("Organisation or context")
                    .accessibilityIdentifier("experienceEditor.organisation")
                fieldProblem(.organisation)

                DatePicker(
                    "When it happened",
                    selection: $draft.occurredAt,
                    in: ...Date(),
                    displayedComponents: .date
                )
                .accessibilityIdentifier("experienceEditor.date")
                fieldProblem(.occurredAt)

                Picker("Type of experience", selection: $draft.kind) {
                    ForEach(ExperienceKind.allCases) { kind in
                        Label(kind.title, systemImage: kind.symbol).tag(kind)
                    }
                }
                .accessibilityIdentifier("experienceEditor.kind")
            } header: {
                Text("Name the moment")
            } footer: {
                Text("Use a specific title you will recognise quickly in an interview, not a generic category.")
            }

            Section {
                Picker("Your level of ownership", selection: $draft.ownership) {
                    ForEach(OwnershipLevel.allCases) { level in
                        Text(level.phrasing).tag(level)
                    }
                }
                .pickerStyle(.inline)
                .accessibilityIdentifier("experienceEditor.ownership")
            } header: {
                Text("Your role")
            } footer: {
                Text("Accurate ownership keeps generated answers credible. Contributing or supporting is still valuable evidence.")
            }
        }
    }

    private var contextContent: some View {
        Group {
            Section {
                multilineField(
                    title: "What was happening?",
                    prompt: "Give enough background to understand why this mattered and what made it difficult.",
                    text: $draft.situation,
                    field: .situation,
                    maximumLength: 2_000,
                    accessibilityID: "experienceEditor.situation"
                )
                fieldProblem(.situation)
            } header: {
                Text("Situation")
            } footer: {
                Text("Aim for the context an interviewer needs, without retelling the whole project history.")
            }

            Section {
                multilineField(
                    title: "What were you responsible for?",
                    prompt: "State your objective, constraint or decision clearly in the first person.",
                    text: $draft.task,
                    field: .task,
                    maximumLength: 1_500,
                    accessibilityID: "experienceEditor.task"
                )
                fieldProblem(.task)
            } header: {
                Text("Task and responsibility")
            } footer: {
                Text("A useful task distinguishes your responsibility from the team’s broader goal.")
            }
        }
    }

    private var actionsContent: some View {
        Group {
            Section {
                ForEach($draft.actions) { $action in
                    let index = draft.actions.firstIndex(where: { $0.id == action.id }) ?? 0
                    VStack(alignment: .leading, spacing: RRSpacing.xs) {
                        HStack(alignment: .top, spacing: RRSpacing.sm) {
                            Text("\(index + 1)")
                                .font(.rrCaption)
                                .foregroundStyle(BrandTheme.violet)
                                .frame(width: 28, height: 28)
                                .background(BrandTheme.violetSoft, in: Circle())
                                .accessibilityHidden(true)

                            TextField(
                                "What did you do, decide, test or communicate?",
                                text: $action.text,
                                axis: .vertical
                            )
                            .lineLimit(3...7)
                            .textInputAutocapitalization(.sentences)
                            .focused($focusedField, equals: .action(action.id))
                            .accessibilityLabel("Action \(index + 1)")
                            .accessibilityIdentifier("experienceEditor.action.\(index)")

                            if draft.actions.count > 1 {
                                Button(role: .destructive) {
                                    removeAction(action.id)
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .frame(width: 44, height: 44)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Remove action \(index + 1)")
                            }
                        }

                        Text("Use “I” and include a reason or trade-off where it matters.")
                            .font(.caption)
                            .foregroundStyle(BrandTheme.inkMuted)
                            .padding(.leading, 40)
                    }
                }

                Button(action: addAction) {
                    Label("Add another action", systemImage: "plus.circle.fill")
                }
                .disabled(draft.actions.count >= ExperienceEditorDraft.maximumActions)
                .accessibilityIdentifier("experienceEditor.addAction")

                fieldProblem(.actions)
            } header: {
                Text("What you personally did")
            } footer: {
                Text("Separate concrete steps so RoleReady can shorten or reorder them without inventing connective detail.")
            }

            Section {
                ForEach(Capability.allCases) { capability in
                    Button {
                        toggle(capability)
                    } label: {
                        HStack(spacing: RRSpacing.sm) {
                            Label(capability.title, systemImage: capability.symbol)
                                .foregroundStyle(BrandTheme.ink)
                            Spacer(minLength: RRSpacing.sm)
                            Image(systemName: draft.capabilities.contains(capability) ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(draft.capabilities.contains(capability) ? BrandTheme.violet : BrandTheme.inkMuted)
                                .font(.headline)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(draft.capabilities.contains(capability) ? .isSelected : [])
                    .accessibilityIdentifier("experienceEditor.capability.\(capability.rawValue)")
                }

                fieldProblem(.capabilities)
            } header: {
                Text("Capabilities demonstrated")
            } footer: {
                Text("Choose only the signals this story genuinely supports. Two to four strong tags are usually enough.")
            }

            Section {
                TextField("Python, facilitation, Jira, regression testing", text: $draft.toolsText, axis: .vertical)
                    .lineLimit(2...5)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .tools)
                    .accessibilityLabel("Tools and methods")
                    .accessibilityIdentifier("experienceEditor.tools")
                fieldProblem(.tools)
            } header: {
                Text("Tools and methods")
            } footer: {
                Text("Separate items with commas. Include methods such as workshops, peer review or testing—not only software.")
            }
        }
    }

    private var outcomeContent: some View {
        Group {
            Section {
                multilineField(
                    title: "What changed because of your work?",
                    prompt: "Describe the outcome without adding a metric you cannot verify.",
                    text: $draft.result,
                    field: .result,
                    maximumLength: 1_500,
                    accessibilityID: "experienceEditor.result"
                )
                fieldProblem(.result)
            } header: {
                Text("Result")
            } footer: {
                Text("A clear observation, approval, completed delivery or prevented problem can be valid evidence even without a percentage.")
            }

            Section {
                multilineField(
                    title: "How can you verify it? (optional)",
                    prompt: "Add a test result, sign-off, measurement, feedback, log, artefact or direct observation.",
                    text: $draft.evidence,
                    field: .evidence,
                    maximumLength: 1_500,
                    accessibilityID: "experienceEditor.evidence"
                )
                fieldProblem(.evidence)
            } header: {
                Text("Proof")
            } footer: {
                Text("Leave this blank if no proof is available. RoleReady will show the gap rather than fabricate certainty.")
            }

            Section {
                multilineField(
                    title: "What did you learn? (optional)",
                    prompt: "Capture what you would repeat, change or notice earlier next time.",
                    text: $draft.learning,
                    field: .learning,
                    maximumLength: 1_500,
                    accessibilityID: "experienceEditor.learning"
                )
                fieldProblem(.learning)
            } header: {
                Text("Reflection")
            } footer: {
                Text(
                    draft.kind == .mistakeAndLearning
                        ? "A reflection is required for a mistake-and-learning story."
                        : "Reflection helps with follow-up questions and shows considered growth."
                )
            }
        }
    }

    private var privacyContent: some View {
        Group {
            Section {
                Picker("Confidentiality", selection: confidentialitySelection) {
                    ForEach(Confidentiality.allCases) { level in
                        Label(level.title, systemImage: level.symbol).tag(level)
                    }
                }
                .pickerStyle(.inline)
                .accessibilityIdentifier("experienceEditor.confidentiality")

                fieldProblem(.confidentiality)
            } header: {
                Text("Privacy level")
            } footer: {
                Text("Highly sensitive stories never participate in automatic role matching.")
            }

            Section {
                Toggle(isOn: $draft.isApprovedForMatching) {
                    VStack(alignment: .leading, spacing: RRSpacing.xxs) {
                        Text(draft.confidentiality.blocksAutomaticUse ? "Allow explicit answer use" : "Allow automatic matching")
                            .font(.body)
                        Text(
                            draft.confidentiality.blocksAutomaticUse
                                ? "You must choose this story yourself; RoleReady will never suggest it automatically."
                                : "RoleReady may suggest this story for relevant job requirements."
                        )
                            .font(.caption)
                            .foregroundStyle(BrandTheme.inkMuted)
                    }
                }
                .accessibilityIdentifier("experienceEditor.matchingApproval")

                if draft.confidentiality.blocksAutomaticUse {
                    InfoBanner(
                        title: draft.isApprovedForMatching ? "Explicit use approved" : "Automatic matching is always off",
                        message: draft.isApprovedForMatching
                            ? "RoleReady can build an answer only when you deliberately select this story. It remains excluded from role matching."
                            : "Keep this story for private reference, or deliberately approve it for a manually selected answer.",
                        kind: .warning
                    )
                    .listRowBackground(Color.clear)
                } else if draft.confidentiality >= .confidential {
                    InfoBanner(
                        title: "Review before sharing",
                        message: "Generated drafts will remind you to remove identifying names, internal systems and sensitive detail.",
                        kind: .warning
                    )
                    .listRowBackground(Color.clear)
                }
            } header: {
                Text("Matching permission")
            }

            Section {
                ExperienceEditorReviewCard(draft: draft)
                    .listRowInsets(.init())
                    .listRowBackground(Color.clear)
            } header: {
                Text("Review")
            } footer: {
                Text("Saving updates the source record on this device. Generated answers stay traceable to the named story fields.")
            }
        }
    }

    private var validator: ExperienceEditorValidator {
        ExperienceEditorValidator(draft: draft)
    }

    private var isDirty: Bool {
        loadState == .ready && draft != baseline
    }

    private var confidentialitySelection: Binding<Confidentiality> {
        Binding(
            get: { draft.confidentiality },
            set: { newLevel in
                let becameHighlySensitive = newLevel.blocksAutomaticUse && !draft.confidentiality.blocksAutomaticUse
                draft.confidentiality = newLevel
                if becameHighlySensitive {
                    draft.isApprovedForMatching = false
                }
            }
        )
    }

    @ViewBuilder
    private func multilineField(
        title: String,
        prompt: String,
        text: Binding<String>,
        field: ExperienceEditorFocusField,
        maximumLength: Int,
        accessibilityID: String
    ) -> some View {
        VStack(alignment: .leading, spacing: RRSpacing.xs) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(BrandTheme.ink)

            TextField(prompt, text: text, axis: .vertical)
                .lineLimit(4...9)
                .textInputAutocapitalization(.sentences)
                .focused($focusedField, equals: field)
                .accessibilityIdentifier(accessibilityID)

            HStack {
                Spacer()
                Text("\(text.wrappedValue.count) / \(maximumLength)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(text.wrappedValue.count > maximumLength ? BrandTheme.danger : BrandTheme.inkMuted)
            }
            .accessibilityHidden(true)
        }
    }

    @ViewBuilder
    private func fieldProblem(_ field: ExperienceEditorValidationField) -> some View {
        if let problem = visibleProblem(for: field) {
            Label(problem.message, systemImage: "exclamationmark.circle.fill")
                .font(.caption)
                .foregroundStyle(BrandTheme.danger)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("experienceEditor.error.\(field.rawValue)")
        }
    }

    private func visibleProblem(for field: ExperienceEditorValidationField) -> ExperienceEditorValidationProblem? {
        guard let problem = validator.problem(for: field), attemptedSteps.contains(problem.step) else { return nil }
        return problem
    }

    private func visibleProblems(for step: ExperienceEditorStep) -> [ExperienceEditorValidationProblem] {
        guard attemptedSteps.contains(step) else { return [] }
        return validator.problems(for: step)
    }

    private func loadExperienceIfNeeded() {
        guard case .loading = loadState, let experienceID else { return }

        do {
            guard let experience = try fetchExperience(id: experienceID) else {
                loadState = .failed("This evidence record could not be found. It may have been deleted in another view.")
                return
            }
            let loadedDraft = ExperienceEditorDraft(experience: experience)
            draft = loadedDraft
            baseline = loadedDraft
            loadState = .ready
        } catch {
            loadState = .failed("RoleReady could not load this record. \(error.localizedDescription)")
        }
    }

    private func fetchExperience(id: UUID) throws -> Experience? {
        let requestedID = id
        var descriptor = FetchDescriptor<Experience>(
            predicate: #Predicate<Experience> { experience in
                experience.id == requestedID
            }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    private func requestDismissal() {
        focusedField = nil
        if isDirty {
            isConfirmingDiscard = true
        } else {
            dismiss()
        }
    }

    private func goBack() {
        guard let previous = step.previous else { return }
        focusedField = nil
        withAnimation(reduceMotion ? nil : .snappy) {
            step = previous
        }
        HapticService.selection(enabled: appState.hapticsEnabled)
    }

    private func primaryAction() {
        if step == .privacy {
            save()
        } else {
            advance()
        }
    }

    private func advance() {
        attemptedSteps.insert(step)
        guard validator.problems(for: step).isEmpty, let next = step.next else {
            focusedField = validator.firstFocusField(for: step)
            HapticService.warning(enabled: appState.hapticsEnabled)
            return
        }

        focusedField = nil
        withAnimation(reduceMotion ? nil : .snappy) {
            step = next
        }
        HapticService.selection(enabled: appState.hapticsEnabled)
    }

    private func save() {
        attemptedSteps.formUnion(ExperienceEditorStep.allCases)
        let validation = ExperienceEditorValidator(draft: draft)

        if let invalidStep = ExperienceEditorStep.allCases.first(where: { !validation.problems(for: $0).isEmpty }) {
            withAnimation(reduceMotion ? nil : .snappy) {
                step = invalidStep
            }
            focusedField = validation.firstFocusField(for: invalidStep)
            HapticService.warning(enabled: appState.hapticsEnabled)
            return
        }

        isSaving = true
        defer { isSaving = false }

        let normalized = draft.normalized()
        var invalidatedAnswerCount = 0

        do {
            if let experienceID {
                guard let experience = try fetchExperience(id: experienceID) else {
                    issue = .storyMissing
                    return
                }
                normalized.apply(to: experience)
                invalidatedAnswerCount = try AnswerApprovalService()
                    .invalidateAnswers(for: experienceID, in: modelContext)
            } else {
                modelContext.insert(normalized.makeExperience())
            }

            try modelContext.save()
            draft = normalized
            baseline = normalized
            HapticService.success(enabled: appState.hapticsEnabled)
            if invalidatedAnswerCount > 0 {
                appState.showToast(
                    "Story updated · \(invalidatedAnswerCount) answer\(invalidatedAnswerCount == 1 ? "" : "s") need reconfirmation",
                    symbol: "exclamationmark.triangle.fill"
                )
            } else {
                appState.showToast(experienceID == nil ? "Evidence story added" : "Evidence story updated")
            }
            dismiss()
        } catch {
            modelContext.rollback()
            issue = .saveFailed(error.localizedDescription)
        }
    }

    private func addAction() {
        guard draft.actions.count < ExperienceEditorDraft.maximumActions else { return }
        let action = ExperienceEditorActionDraft()
        draft.actions.append(action)
        Task { @MainActor in
            await Task.yield()
            focusedField = .action(action.id)
        }
        HapticService.selection(enabled: appState.hapticsEnabled)
    }

    private func removeAction(_ id: UUID) {
        guard draft.actions.count > 1 else { return }
        if focusedField == .action(id) {
            focusedField = nil
        }
        withAnimation(reduceMotion ? nil : .snappy) {
            draft.actions.removeAll { $0.id == id }
        }
    }

    private func toggle(_ capability: Capability) {
        if draft.capabilities.contains(capability) {
            draft.capabilities.remove(capability)
        } else {
            draft.capabilities.insert(capability)
        }
        HapticService.selection(enabled: appState.hapticsEnabled)
    }
}

private enum ExperienceEditorLoadState: Equatable {
    case loading
    case ready
    case failed(String)
}

private enum ExperienceEditorIssue: Identifiable {
    case storyMissing
    case saveFailed(String)

    var id: String {
        switch self {
        case .storyMissing: "story-missing"
        case .saveFailed: "save-failed"
        }
    }

    var title: String {
        switch self {
        case .storyMissing: "Story no longer exists"
        case .saveFailed: "Could not save story"
        }
    }

    var message: String {
        switch self {
        case .storyMissing:
            "This evidence record was deleted before your changes could be saved."
        case .saveFailed(let detail):
            "Your editor remains open and your draft is unchanged. \(detail)"
        }
    }
}

private enum ExperienceEditorStep: String, CaseIterable, Identifiable {
    case basics
    case context
    case actions
    case outcome
    case privacy

    var id: String { rawValue }

    var title: String {
        switch self {
        case .basics: "The moment"
        case .context: "Context & role"
        case .actions: "What you did"
        case .outcome: "Outcome & proof"
        case .privacy: "Review & privacy"
        }
    }

    var prompt: String {
        switch self {
        case .basics: "Give this story a memorable name and record your real level of ownership."
        case .context: "Set up the challenge and separate your responsibility from the wider team’s goal."
        case .actions: "Capture concrete choices, steps, communication and the capabilities they demonstrate."
        case .outcome: "Record what changed, how you know, and what the experience taught you."
        case .privacy: "Decide how this story may be matched and check the source record before saving."
        }
    }

    var symbol: String {
        switch self {
        case .basics: "bookmark.fill"
        case .context: "map.fill"
        case .actions: "figure.run"
        case .outcome: "flag.checkered"
        case .privacy: "hand.raised.fill"
        }
    }

    var index: Int {
        Self.allCases.firstIndex(of: self) ?? 0
    }

    var next: Self? {
        let nextIndex = index + 1
        guard Self.allCases.indices.contains(nextIndex) else { return nil }
        return Self.allCases[nextIndex]
    }

    var previous: Self? {
        let previousIndex = index - 1
        guard Self.allCases.indices.contains(previousIndex) else { return nil }
        return Self.allCases[previousIndex]
    }
}

private enum ExperienceEditorFocusField: Hashable {
    case title
    case organisation
    case situation
    case task
    case action(UUID)
    case tools
    case result
    case evidence
    case learning
}

private struct ExperienceEditorActionDraft: Identifiable, Equatable {
    let id: UUID
    var text: String

    init(id: UUID = UUID(), text: String = "") {
        self.id = id
        self.text = text
    }
}

private struct ExperienceEditorDraft: Equatable {
    static let maximumActions = 8

    var title = ""
    var organisation = ""
    var occurredAt = Date()
    var kind: ExperienceKind = .project
    var situation = ""
    var task = ""
    var actions: [ExperienceEditorActionDraft] = [ExperienceEditorActionDraft()]
    var result = ""
    var evidence = ""
    var learning = ""
    var ownership: OwnershipLevel = .owned
    var capabilities: Set<Capability> = []
    var toolsText = ""
    var confidentiality: Confidentiality = .privateRecord
    var isApprovedForMatching = true

    init() {}

    init(experience: Experience) {
        title = experience.title
        organisation = experience.organisation
        occurredAt = experience.occurredAt
        kind = experience.kind
        situation = experience.situation
        task = experience.task
        actions = experience.actions.isEmpty
            ? [ExperienceEditorActionDraft()]
            : experience.actions.map { ExperienceEditorActionDraft(text: $0) }
        result = experience.result
        evidence = experience.evidence
        learning = experience.learning
        ownership = experience.ownership
        capabilities = Set(experience.capabilities)
        toolsText = experience.tools.joined(separator: ", ")
        confidentiality = experience.confidentiality
        isApprovedForMatching = experience.isApprovedForMatching
    }

    var cleanedActions: [String] {
        actions
            .map { clean($0.text) }
            .filter { !$0.isEmpty }
    }

    var parsedTools: [String] {
        let candidates = toolsText
            .components(separatedBy: CharacterSet(charactersIn: ",;\n"))
            .map(clean)
            .filter { !$0.isEmpty }

        var seen: Set<String> = []
        return candidates.filter { tool in
            seen.insert(tool.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)).inserted
        }
    }

    func normalized() -> Self {
        var copy = self
        copy.title = clean(title)
        copy.organisation = clean(organisation)
        copy.situation = clean(situation)
        copy.task = clean(task)
        copy.actions = cleanedActions.map { ExperienceEditorActionDraft(text: $0) }
        copy.result = clean(result)
        copy.evidence = clean(evidence)
        copy.learning = clean(learning)
        copy.toolsText = parsedTools.joined(separator: ", ")
        return copy
    }

    func makeExperience() -> Experience {
        Experience(
            title: title,
            organisation: organisation,
            occurredAt: occurredAt,
            kind: kind,
            situation: situation,
            task: task,
            actions: cleanedActions,
            result: result,
            evidence: evidence,
            learning: learning,
            ownership: ownership,
            capabilities: Capability.allCases.filter(capabilities.contains),
            tools: parsedTools,
            confidentiality: confidentiality,
            isApprovedForMatching: isApprovedForMatching,
            updatedAt: Date()
        )
    }

    func apply(to experience: Experience) {
        experience.title = title
        experience.organisation = organisation
        experience.occurredAt = occurredAt
        experience.kind = kind
        experience.situation = situation
        experience.task = task
        experience.actions = cleanedActions
        experience.result = result
        experience.evidence = evidence
        experience.learning = learning
        experience.ownership = ownership
        experience.capabilities = Capability.allCases.filter(capabilities.contains)
        experience.tools = parsedTools
        experience.confidentiality = confidentiality
        experience.isApprovedForMatching = isApprovedForMatching
        experience.updatedAt = Date()
    }

    private func clean(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private enum ExperienceEditorValidationField: String {
    case title
    case organisation
    case occurredAt
    case situation
    case task
    case actions
    case capabilities
    case tools
    case result
    case evidence
    case learning
    case confidentiality
}

private struct ExperienceEditorValidationProblem: Identifiable {
    let field: ExperienceEditorValidationField
    let step: ExperienceEditorStep
    let message: String

    var id: String { "\(step.rawValue).\(field.rawValue).\(message)" }
}

private struct ExperienceEditorValidator {
    let draft: ExperienceEditorDraft

    var problems: [ExperienceEditorValidationProblem] {
        var result: [ExperienceEditorValidationProblem] = []

        appendRequiredOrMaximum(
            draft.title,
            field: .title,
            step: .basics,
            requiredMessage: "Give this story a specific title.",
            maximum: 120,
            maximumMessage: "Keep the story title to 120 characters or fewer.",
            to: &result
        )
        appendRequiredOrMaximum(
            draft.organisation,
            field: .organisation,
            step: .basics,
            requiredMessage: "Add the organisation or write “Independent” for personal work.",
            maximum: 120,
            maximumMessage: "Keep the organisation to 120 characters or fewer.",
            to: &result
        )
        if Calendar.current.startOfDay(for: draft.occurredAt) > Calendar.current.startOfDay(for: Date()) {
            result.append(problem(.occurredAt, .basics, "Choose today or an earlier date."))
        }

        appendRequiredOrMaximum(
            draft.situation,
            field: .situation,
            step: .context,
            requiredMessage: "Add enough situation detail to understand the challenge.",
            maximum: 2_000,
            maximumMessage: "Shorten the situation to 2,000 characters or fewer.",
            to: &result
        )
        appendRequiredOrMaximum(
            draft.task,
            field: .task,
            step: .context,
            requiredMessage: "State what you were personally responsible for.",
            maximum: 1_500,
            maximumMessage: "Shorten the responsibility to 1,500 characters or fewer.",
            to: &result
        )

        if draft.cleanedActions.isEmpty {
            result.append(problem(.actions, .actions, "Add at least one action you personally took."))
        } else if draft.actions.contains(where: { clean($0.text).isEmpty }) {
            result.append(problem(.actions, .actions, "Complete or remove the blank action."))
        } else if draft.actions.contains(where: { clean($0.text).count > 1_500 }) {
            result.append(problem(.actions, .actions, "Keep each action to 1,500 characters or fewer."))
        }
        if draft.actions.count > ExperienceEditorDraft.maximumActions {
            result.append(problem(.actions, .actions, "Keep this story to eight actions or fewer."))
        }
        if draft.capabilities.isEmpty {
            result.append(problem(.capabilities, .actions, "Choose at least one capability this story demonstrates."))
        }
        if draft.parsedTools.count > 20 {
            result.append(problem(.tools, .actions, "Keep the tool and method list to 20 items or fewer."))
        } else if draft.parsedTools.contains(where: { $0.count > 60 }) {
            result.append(problem(.tools, .actions, "Keep each tool or method to 60 characters or fewer."))
        }

        appendRequiredOrMaximum(
            draft.result,
            field: .result,
            step: .outcome,
            requiredMessage: "Record what changed because of your work.",
            maximum: 1_500,
            maximumMessage: "Shorten the result to 1,500 characters or fewer.",
            to: &result
        )
        appendOptionalMaximum(
            draft.evidence,
            field: .evidence,
            step: .outcome,
            maximum: 1_500,
            message: "Shorten the proof to 1,500 characters or fewer.",
            to: &result
        )
        appendOptionalMaximum(
            draft.learning,
            field: .learning,
            step: .outcome,
            maximum: 1_500,
            message: "Shorten the reflection to 1,500 characters or fewer.",
            to: &result
        )
        if draft.kind == .mistakeAndLearning, clean(draft.learning).isEmpty {
            result.append(problem(.learning, .outcome, "Add the learning that makes this mistake useful evidence."))
        }

        return result
    }

    func problems(for step: ExperienceEditorStep) -> [ExperienceEditorValidationProblem] {
        problems.filter { $0.step == step }
    }

    func problem(for field: ExperienceEditorValidationField) -> ExperienceEditorValidationProblem? {
        problems.first { $0.field == field }
    }

    func firstFocusField(for step: ExperienceEditorStep) -> ExperienceEditorFocusField? {
        guard let first = problems(for: step).first else { return nil }
        switch first.field {
        case .title: .title
        case .organisation: .organisation
        case .situation: .situation
        case .task: .task
        case .actions: draft.actions.first.map { .action($0.id) }
        case .tools: .tools
        case .result: .result
        case .evidence: .evidence
        case .learning: .learning
        case .occurredAt, .capabilities, .confidentiality: nil
        }
    }

    private func appendRequiredOrMaximum(
        _ value: String,
        field: ExperienceEditorValidationField,
        step: ExperienceEditorStep,
        requiredMessage: String,
        maximum: Int,
        maximumMessage: String,
        to problems: inout [ExperienceEditorValidationProblem]
    ) {
        let cleaned = clean(value)
        if cleaned.isEmpty {
            problems.append(problem(field, step, requiredMessage))
        } else if cleaned.count > maximum {
            problems.append(problem(field, step, maximumMessage))
        }
    }

    private func appendOptionalMaximum(
        _ value: String,
        field: ExperienceEditorValidationField,
        step: ExperienceEditorStep,
        maximum: Int,
        message: String,
        to problems: inout [ExperienceEditorValidationProblem]
    ) {
        if clean(value).count > maximum {
            problems.append(problem(field, step, message))
        }
    }

    private func problem(
        _ field: ExperienceEditorValidationField,
        _ step: ExperienceEditorStep,
        _ message: String
    ) -> ExperienceEditorValidationProblem {
        ExperienceEditorValidationProblem(field: field, step: step, message: message)
    }

    private func clean(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private struct ExperienceEditorProgressHeader: View {
    let step: ExperienceEditorStep

    private var progress: Double {
        Double(step.index + 1) / Double(ExperienceEditorStep.allCases.count)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: RRSpacing.sm) {
            HStack {
                Text("Step \(step.index + 1) of \(ExperienceEditorStep.allCases.count)")
                    .font(.rrCaption)
                    .foregroundStyle(BrandTheme.violet)
                Spacer()
                Text(step.title)
                    .font(.rrHeadline)
                    .foregroundStyle(BrandTheme.ink)
            }

            ProgressView(value: progress)
                .tint(BrandTheme.violet)

            Label(step.prompt, systemImage: step.symbol)
                .font(.subheadline)
                .foregroundStyle(BrandTheme.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(RRSpacing.md)
        .cardSurface(padding: 0, tint: BrandTheme.canvasRaised)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Step \(step.index + 1) of \(ExperienceEditorStep.allCases.count), \(step.title). \(step.prompt)")
        .accessibilityIdentifier("experienceEditor.progress")
    }
}

private struct ExperienceEditorValidationSummary: View {
    let problems: [ExperienceEditorValidationProblem]

    var body: some View {
        VStack(alignment: .leading, spacing: RRSpacing.xs) {
            Label("A little more detail is needed", systemImage: "exclamationmark.triangle.fill")
                .font(.rrHeadline)
                .foregroundStyle(BrandTheme.danger)

            ForEach(problems.prefix(3)) { problem in
                Text("• \(problem.message)")
                    .font(.subheadline)
                    .foregroundStyle(BrandTheme.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if problems.count > 3 {
                Text("And \(problems.count - 3) more item\(problems.count - 3 == 1 ? "" : "s").")
                    .font(.caption)
                    .foregroundStyle(BrandTheme.inkMuted)
            }
        }
        .padding(RRSpacing.md)
        .background(BrandTheme.danger.opacity(0.09), in: RoundedRectangle(cornerRadius: RRRadius.medium, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

private struct ExperienceEditorFooter: View {
    let step: ExperienceEditorStep
    let isSaving: Bool
    let goBack: () -> Void
    let continueOrSave: () -> Void

    var body: some View {
        HStack(spacing: RRSpacing.sm) {
            if step.previous != nil {
                Button("Back", action: goBack)
                    .buttonStyle(SecondaryActionButtonStyle())
                    .disabled(isSaving)
                    .accessibilityIdentifier("experienceEditor.back")
            }

            Button(action: continueOrSave) {
                if isSaving {
                    HStack(spacing: RRSpacing.xs) {
                        ProgressView()
                        Text("Saving…")
                    }
                } else {
                    Label(
                        step == .privacy ? "Save story" : "Continue",
                        systemImage: step == .privacy ? "checkmark" : "arrow.right"
                    )
                }
            }
            .buttonStyle(PrimaryActionButtonStyle())
            .disabled(isSaving)
            .accessibilityIdentifier(step == .privacy ? "experienceEditor.save" : "experienceEditor.continue")
        }
        .padding(.horizontal, RRSpacing.md)
        .padding(.vertical, RRSpacing.sm)
        .background(.regularMaterial)
        .overlay(alignment: .top) {
            Divider().overlay(BrandTheme.separator)
        }
    }
}

private struct ExperienceEditorReviewCard: View {
    let draft: ExperienceEditorDraft

    private var capabilityText: String {
        Capability.allCases
            .filter(draft.capabilities.contains)
            .map(\.title)
            .joined(separator: ", ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: RRSpacing.md) {
            HStack(alignment: .top, spacing: RRSpacing.sm) {
                Image(systemName: draft.kind.symbol)
                    .font(.title3)
                    .foregroundStyle(BrandTheme.violet)
                    .frame(width: 42, height: 42)
                    .background(BrandTheme.violetSoft, in: RoundedRectangle(cornerRadius: RRRadius.small, style: .continuous))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: RRSpacing.xxs) {
                    Text(draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Untitled story" : draft.title)
                        .font(.rrHeadline)
                    Text(draft.organisation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Organisation missing" : draft.organisation)
                        .font(.subheadline)
                        .foregroundStyle(BrandTheme.inkMuted)
                    Text(draft.occurredAt.formatted(.dateTime.month(.wide).year()))
                        .font(.rrCaption)
                        .foregroundStyle(BrandTheme.inkMuted)
                }
            }

            Divider().overlay(BrandTheme.separator)

            ReviewMetric(label: "Ownership", value: draft.ownership.phrasing, symbol: "person.fill.checkmark")
            ReviewMetric(label: "Actions", value: "\(draft.cleanedActions.count)", symbol: "figure.run")
            ReviewMetric(
                label: "Capabilities",
                value: capabilityText.isEmpty ? "None selected" : capabilityText,
                symbol: "sparkles"
            )
            ReviewMetric(
                label: "Matching",
                value: matchingSummary,
                symbol: "point.3.connected.trianglepath.dotted"
            )
        }
        .cardSurface(tint: BrandTheme.canvasRaised)
        .accessibilityIdentifier("experienceEditor.review")
    }

    private var matchingSummary: String {
        if draft.confidentiality.blocksAutomaticUse {
            return draft.isApprovedForMatching ? "Explicit use only" : "Excluded"
        }
        return draft.isApprovedForMatching ? "Allowed" : "Excluded"
    }
}

private struct ReviewMetric: View {
    let label: String
    let value: String
    let symbol: String

    var body: some View {
        HStack(alignment: .top, spacing: RRSpacing.sm) {
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
                .multilineTextAlignment(.trailing)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label): \(value)")
    }
}
