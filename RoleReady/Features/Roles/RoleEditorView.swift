import SwiftData
import SwiftUI
import UniformTypeIdentifiers

@MainActor
struct RoleEditorView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState

    private let opportunity: Opportunity?

    @State private var step: RoleEditorStep
    @State private var roleTitle: String
    @State private var organisation: String
    @State private var location: String
    @State private var sourceText: String
    @State private var status: OpportunityStatus
    @State private var notes: String
    @State private var closingDate: Date
    @State private var interviewDate: Date
    @State private var hasClosingDate: Bool
    @State private var hasInterviewDate: Bool
    @State private var requirementDrafts: [RoleRequirementDraft] = []
    @State private var baselineRequirementDrafts: [RoleRequirementDraft] = []
    @State private var importedFilename: String?
    @State private var importWarnings: [String] = []
    @State private var parserWarnings: [String] = []
    @State private var editorError: String?
    @State private var isFileImporterPresented = false
    @State private var isImporting = false
    @State private var isAnalysing = false
    @State private var isSaving = false
    @State private var isLoadingExistingRequirements: Bool
    @State private var isConfirmingDiscard = false
    @State private var hasLoadedExistingRequirements = false
    @FocusState private var focusedField: RoleEditorField?

    init(opportunity: Opportunity? = nil) {
        self.opportunity = opportunity
        _step = State(initialValue: opportunity == nil ? .source : .review)
        _roleTitle = State(initialValue: opportunity?.roleTitle ?? "")
        _organisation = State(initialValue: opportunity?.organisation ?? "")
        _location = State(initialValue: opportunity?.location ?? "")
        _sourceText = State(initialValue: opportunity?.sourceText ?? "")
        _status = State(initialValue: opportunity?.status ?? .saved)
        _notes = State(initialValue: opportunity?.notes ?? "")
        _closingDate = State(initialValue: opportunity?.closingDate ?? Calendar.current.date(byAdding: .day, value: 14, to: Date()) ?? Date())
        _interviewDate = State(initialValue: opportunity?.interviewDate ?? Calendar.current.date(byAdding: .day, value: 21, to: Date()) ?? Date())
        _hasClosingDate = State(initialValue: opportunity?.closingDate != nil)
        _hasInterviewDate = State(initialValue: opportunity?.interviewDate != nil)
        _isLoadingExistingRequirements = State(initialValue: opportunity != nil)
    }

    var body: some View {
        NavigationStack {
            Group {
                switch step {
                case .source:
                    sourceStep
                case .review:
                    reviewStep
                }
            }
            .navigationTitle(opportunity == nil ? "Add a role" : "Edit role")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { editorToolbar }
            .screenBackground()
        }
        .interactiveDismissDisabled(hasUnsavedChanges || isImporting || isAnalysing || isSaving)
        .fileImporter(
            isPresented: $isFileImporterPresented,
            allowedContentTypes: DocumentImportService.supportedContentTypes,
            onCompletion: handleImportResult
        )
        .task { loadExistingRequirementsIfNeeded() }
        .confirmationDialog(
            "Discard your role changes?",
            isPresented: $isConfirmingDiscard,
            titleVisibility: .visible
        ) {
            Button("Discard changes", role: .destructive) { dismiss() }
            Button("Keep editing", role: .cancel) {}
        } message: {
            Text("The job text and requirement review on this screen have not been saved.")
        }
        .accessibilityIdentifier("roleEditor.root")
    }

    @ViewBuilder
    private var sourceStep: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: RRSpacing.lg) {
                VStack(alignment: .leading, spacing: RRSpacing.sm) {
                    Label("Job analyser", systemImage: "doc.text.magnifyingglass")
                        .font(.rrCaption)
                        .foregroundStyle(BrandTheme.violet)
                    Text("Start with the role, not a blank application")
                        .font(.rrHero)
                        .foregroundStyle(BrandTheme.ink)
                    Text("Paste the job advertisement or choose a PDF, Word, RTF or text file. Analysis stays on this device, and you review every requirement before it is saved.")
                        .font(.rrBody)
                        .foregroundStyle(BrandTheme.inkMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let editorError {
                    InfoBanner(title: "Couldn’t analyse this role", message: editorError, kind: .warning)
                        .accessibilityIdentifier("roleEditor.error")
                }

                if !importWarnings.isEmpty {
                    InfoBanner(
                        title: "Check the imported document",
                        message: importWarnings.joined(separator: "\n"),
                        kind: .warning
                    )
                }

                VStack(alignment: .leading, spacing: RRSpacing.sm) {
                    HStack {
                        Text("Job advertisement")
                            .font(.rrHeadline)
                        Spacer()
                        if let importedFilename {
                            Label(importedFilename, systemImage: "doc.fill")
                                .font(.rrCaption)
                                .foregroundStyle(BrandTheme.inkMuted)
                                .lineLimit(1)
                        }
                    }

                    ZStack(alignment: .topLeading) {
                        if sourceText.isEmpty {
                            Text("Paste the complete advertisement here, including responsibilities and essential requirements…")
                                .font(.rrBody)
                                .foregroundStyle(BrandTheme.inkMuted.opacity(0.72))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 9)
                                .allowsHitTesting(false)
                        }
                        TextEditor(text: $sourceText)
                            .font(.rrBody)
                            .foregroundStyle(BrandTheme.ink)
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 250)
                            .focused($focusedField, equals: .source)
                            .accessibilityLabel("Job advertisement text")
                            .accessibilityIdentifier("roleEditor.sourceText")
                    }
                    .padding(RRSpacing.sm)
                    .background(BrandTheme.canvasRaised, in: RoundedRectangle(cornerRadius: RRRadius.medium, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: RRRadius.medium, style: .continuous)
                            .stroke(sourceBorderColour, lineWidth: 1)
                    }

                    HStack {
                        Text(sourceCountMessage)
                            .font(.rrCaption)
                            .foregroundStyle(sourceText.count > 250_000 ? BrandTheme.danger : BrandTheme.inkMuted)
                        Spacer()
                        Button {
                            sourceText = ""
                            importedFilename = nil
                            importWarnings = []
                            editorError = nil
                        } label: {
                            Label("Clear", systemImage: "xmark.circle")
                        }
                        .font(.rrCaption)
                        .disabled(sourceText.isEmpty)
                        .accessibilityIdentifier("roleEditor.source.clear")
                    }

                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: RRSpacing.sm) {
                            sourceButtons
                        }
                        VStack(spacing: RRSpacing.sm) {
                            sourceButtons
                        }
                    }
                }
                .cardSurface()

                VStack(spacing: RRSpacing.sm) {
                    Button(action: analyseSource) {
                        HStack {
                            if isAnalysing {
                                ProgressView()
                                    .tint(BrandTheme.ink)
                            } else {
                                Image(systemName: "wand.and.stars")
                            }
                            Text(isAnalysing ? "Finding requirements…" : "Analyse and review")
                        }
                    }
                    .buttonStyle(PrimaryActionButtonStyle())
                    .disabled(!canAnalyse || isAnalysing || isImporting)
                    .opacity(canAnalyse && !isAnalysing && !isImporting ? 1 : 0.55)
                    .accessibilityIdentifier("roleEditor.analyse")

                    Button("Enter role details manually") {
                        beginManualReview()
                    }
                    .buttonStyle(SecondaryActionButtonStyle())
                    .disabled(isAnalysing || isImporting)
                    .accessibilityIdentifier("roleEditor.manual")
                }
            }
            .padding(.horizontal, RRSpacing.md)
            .padding(.vertical, RRSpacing.lg)
            .frame(maxWidth: 820)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    @ViewBuilder
    private var reviewStep: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: RRSpacing.lg) {
                reviewProgress

                if let editorError {
                    InfoBanner(title: "This role needs attention", message: editorError, kind: .warning)
                        .accessibilityIdentifier("roleEditor.error")
                }

                if !parserWarnings.isEmpty {
                    InfoBanner(
                        title: "Review the analysis",
                        message: parserWarnings.joined(separator: "\n"),
                        kind: .warning
                    )
                }

                roleDetailsCard
                datesAndStatusCard

                VStack(alignment: .leading, spacing: RRSpacing.md) {
                    SectionHeading(
                        title: "Role requirements",
                        eyebrow: "\(includedRequirementCount) included",
                        actionTitle: "Add requirement"
                    ) {
                        addRequirement()
                    }

                    Text("Keep only what the advertisement actually says. Adjust the category, importance and capabilities so your later matches remain explainable.")
                        .font(.rrBody)
                        .foregroundStyle(BrandTheme.inkMuted)
                        .fixedSize(horizontal: false, vertical: true)

                    if isLoadingExistingRequirements {
                        ForEach(0..<2, id: \.self) { _ in
                            VStack(alignment: .leading, spacing: RRSpacing.sm) {
                                RoundedRectangle(cornerRadius: 5)
                                    .fill(BrandTheme.surfaceMuted)
                                    .frame(width: 112, height: 18)
                                RoundedRectangle(cornerRadius: RRRadius.small)
                                    .fill(BrandTheme.surfaceMuted)
                                    .frame(height: 72)
                            }
                            .cardSurface()
                        }
                        .redacted(reason: .placeholder)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("Loading saved requirements")
                    } else if requirementDrafts.isEmpty {
                        EmptyStatePanel(
                            title: "No clear requirements yet",
                            message: "Add the responsibilities or must-haves that matter most for this application.",
                            symbol: "checklist",
                            actionTitle: "Add a requirement"
                        ) {
                            addRequirement()
                        }
                        .accessibilityIdentifier("roleEditor.requirements.empty")
                    } else {
                        ForEach($requirementDrafts) { $draft in
                            RoleRequirementEditorCard(
                                draft: $draft,
                                focusedField: $focusedField
                            ) {
                                removeRequirement(draft.id)
                            }
                            .accessibilityIdentifier("roleEditor.requirement.\(draft.id.uuidString)")
                        }
                    }
                }

                VStack(alignment: .leading, spacing: RRSpacing.sm) {
                    Text("Private notes")
                        .font(.rrHeadline)
                    TextField(
                        "Contact, salary context, next action or anything you want to remember",
                        text: $notes,
                        axis: .vertical
                    )
                    .lineLimit(3...8)
                    .focused($focusedField, equals: .notes)
                    .textFieldStyle(.plain)
                    .padding(RRSpacing.sm)
                    .background(BrandTheme.canvasRaised, in: RoundedRectangle(cornerRadius: RRRadius.small, style: .continuous))
                    .accessibilityIdentifier("roleEditor.notes")
                }
                .cardSurface()

                Button(action: saveRole) {
                    HStack {
                        if isSaving {
                            ProgressView()
                                .tint(BrandTheme.ink)
                        } else {
                            Image(systemName: "checkmark.circle.fill")
                        }
                        Text(isSaving ? "Saving role…" : (opportunity == nil ? "Save role" : "Save changes"))
                    }
                }
                .buttonStyle(PrimaryActionButtonStyle())
                .disabled(isSaving || (opportunity != nil && !hasUnsavedChanges))
                .accessibilityIdentifier("roleEditor.save.primary")
            }
            .padding(.horizontal, RRSpacing.md)
            .padding(.vertical, RRSpacing.lg)
            .frame(maxWidth: 820)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private var reviewProgress: some View {
        HStack(spacing: RRSpacing.sm) {
            Image(systemName: "checkmark.seal.fill")
                .foregroundStyle(BrandTheme.success)
            VStack(alignment: .leading, spacing: RRSpacing.xxs) {
                Text("You stay in control")
                    .font(.rrHeadline)
                Text("Nothing below becomes part of a match until you save it.")
                    .font(.rrCaption)
                    .foregroundStyle(BrandTheme.inkMuted)
            }
            Spacer(minLength: 0)
            Button {
                focusedField = nil
                withAnimation(reduceMotion ? nil : .snappy(duration: 0.24)) {
                    step = .source
                }
            } label: {
                Label("Source", systemImage: "doc.text")
                    .labelStyle(.iconOnly)
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(.bordered)
            .tint(BrandTheme.violet)
            .accessibilityLabel("Review source text")
            .accessibilityIdentifier("roleEditor.source.review")
        }
        .padding(RRSpacing.md)
        .background(BrandTheme.tealSoft, in: RoundedRectangle(cornerRadius: RRRadius.medium, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private var roleDetailsCard: some View {
        VStack(alignment: .leading, spacing: RRSpacing.md) {
            SectionHeading(title: "Role details", eyebrow: "Confirm")

            VStack(alignment: .leading, spacing: RRSpacing.xxs) {
                Text("Role title")
                    .font(.rrCaption)
                    .foregroundStyle(BrandTheme.inkMuted)
                TextField("e.g. Senior Data Analyst", text: $roleTitle)
                    .font(.rrBody)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.next)
                    .focused($focusedField, equals: .title)
                    .onSubmit { focusedField = .organisation }
                    .roleEditorTextField()
                    .accessibilityIdentifier("roleEditor.title")
            }

            VStack(alignment: .leading, spacing: RRSpacing.xxs) {
                Text("Organisation")
                    .font(.rrCaption)
                    .foregroundStyle(BrandTheme.inkMuted)
                TextField("Organisation", text: $organisation)
                    .font(.rrBody)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.next)
                    .focused($focusedField, equals: .organisation)
                    .onSubmit { focusedField = .location }
                    .roleEditorTextField()
                    .accessibilityIdentifier("roleEditor.organisation")
            }

            VStack(alignment: .leading, spacing: RRSpacing.xxs) {
                Text("Location")
                    .font(.rrCaption)
                    .foregroundStyle(BrandTheme.inkMuted)
                TextField("City, hybrid or remote", text: $location)
                    .font(.rrBody)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.done)
                    .focused($focusedField, equals: .location)
                    .roleEditorTextField()
                    .accessibilityIdentifier("roleEditor.location")
            }
        }
        .cardSurface()
    }

    private var datesAndStatusCard: some View {
        VStack(alignment: .leading, spacing: RRSpacing.md) {
            SectionHeading(title: "Application plan", eyebrow: "Track")

            HStack {
                Label("Status", systemImage: status.symbol)
                    .font(.rrBody)
                Spacer()
                Picker("Status", selection: $status) {
                    ForEach(OpportunityStatus.allCases) { value in
                        Label(value.title, systemImage: value.symbol).tag(value)
                    }
                }
                .pickerStyle(.menu)
                .tint(BrandTheme.violet)
                .accessibilityIdentifier("roleEditor.status")
            }

            Divider().overlay(BrandTheme.separator)

            Toggle("Closing date", isOn: $hasClosingDate)
                .font(.rrBody)
                .tint(BrandTheme.violet)
                .accessibilityIdentifier("roleEditor.closingDate.toggle")
            if hasClosingDate {
                DatePicker(
                    "Choose closing date",
                    selection: $closingDate,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .tint(BrandTheme.violet)
                .accessibilityIdentifier("roleEditor.closingDate")
            }

            Divider().overlay(BrandTheme.separator)

            Toggle("Interview date", isOn: $hasInterviewDate)
                .font(.rrBody)
                .tint(BrandTheme.violet)
                .accessibilityIdentifier("roleEditor.interviewDate.toggle")
            if hasInterviewDate {
                DatePicker(
                    "Choose interview date and time",
                    selection: $interviewDate,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .tint(BrandTheme.violet)
                .accessibilityIdentifier("roleEditor.interviewDate")
            }
        }
        .cardSurface()
    }

    @ToolbarContentBuilder
    private var editorToolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel", action: requestDismissal)
                .disabled(isImporting || isAnalysing || isSaving)
                .accessibilityIdentifier("roleEditor.cancel")
        }

        if step == .review {
            ToolbarItem(placement: .confirmationAction) {
                Button(opportunity == nil ? "Save" : "Done", action: saveRole)
                    .fontWeight(.semibold)
                    .disabled(isSaving || (opportunity != nil && !hasUnsavedChanges))
                    .accessibilityIdentifier("roleEditor.save")
            }
        }

        ToolbarItemGroup(placement: .keyboard) {
            Spacer()
            Button("Done") { focusedField = nil }
                .accessibilityIdentifier("roleEditor.keyboard.done")
        }
    }

    private var sourceBorderColour: Color {
        if sourceText.count > 250_000 { return BrandTheme.danger }
        if focusedField == .source { return BrandTheme.violet }
        return BrandTheme.separator
    }

    private var sourceCountMessage: String {
        switch sourceText.count {
        case 0:
            "No text yet"
        case 1..<80:
            "\(sourceText.count.formatted()) characters · add a little more to analyse"
        case 250_001...:
            "\(sourceText.count.formatted()) characters · maximum is 250,000"
        default:
            "\(sourceText.count.formatted()) characters · analysed on device"
        }
    }

    private var canAnalyse: Bool {
        (80...250_000).contains(sourceText.roleReadyTrimmed.count)
    }

    @ViewBuilder
    private var sourceButtons: some View {
        PasteButton(payloadType: String.self) { strings in
            guard let pastedText = strings.first else { return }
            sourceText = pastedText
            importedFilename = nil
            importWarnings = []
            editorError = nil
        }
        .labelStyle(.titleAndIcon)
        .buttonStyle(.bordered)
        .tint(BrandTheme.violet)
        .accessibilityLabel("Paste job advertisement")
        .accessibilityIdentifier("roleEditor.source.paste")

        Button {
            isFileImporterPresented = true
        } label: {
            if isImporting {
                Label("Importing…", systemImage: "hourglass")
            } else {
                Label("Choose file", systemImage: "folder")
            }
        }
        .buttonStyle(.bordered)
        .tint(BrandTheme.violet)
        .disabled(isImporting)
        .accessibilityIdentifier("roleEditor.source.import")
    }

    private var includedRequirementCount: Int {
        requirementDrafts.filter { $0.isIncluded && !$0.text.roleReadyTrimmed.isEmpty }.count
    }

    private var hasUnsavedChanges: Bool {
        if let opportunity {
            return roleTitle != opportunity.roleTitle
                || organisation != opportunity.organisation
                || location != opportunity.location
                || sourceText != opportunity.sourceText
                || status != opportunity.status
                || notes != opportunity.notes
                || (hasClosingDate ? closingDate : nil) != opportunity.closingDate
                || (hasInterviewDate ? interviewDate : nil) != opportunity.interviewDate
                || requirementDrafts != baselineRequirementDrafts
        }

        return !roleTitle.roleReadyTrimmed.isEmpty
            || !organisation.roleReadyTrimmed.isEmpty
            || !location.roleReadyTrimmed.isEmpty
            || !sourceText.roleReadyTrimmed.isEmpty
            || !notes.roleReadyTrimmed.isEmpty
            || hasClosingDate
            || hasInterviewDate
            || !requirementDrafts.isEmpty
            || status != .saved
    }

    private func analyseSource() {
        guard canAnalyse else {
            editorError = sourceText.roleReadyTrimmed.count > 250_000
                ? JobParserError.tooLarge.localizedDescription
                : JobParserError.tooShort.localizedDescription
            return
        }

        isAnalysing = true
        editorError = nil
        focusedField = nil
        let text = sourceText

        Task { @MainActor in
            await Task.yield()
            defer { isAnalysing = false }
            do {
                let parsedJob = try await Task.detached(priority: .userInitiated) {
                    try JobParser().parse(text)
                }.value
                try Task.checkCancellation()
                apply(parsedJob)
                withAnimation(reduceMotion ? nil : .snappy(duration: 0.28)) {
                    step = .review
                }
            } catch is CancellationError {
                return
            } catch {
                editorError = error.localizedDescription
            }
        }
    }

    private func apply(_ parsedJob: ParsedJob) {
        if roleTitle.roleReadyTrimmed.isEmpty {
            roleTitle = parsedJob.suggestedTitle
        }
        if organisation.roleReadyTrimmed.isEmpty {
            organisation = parsedJob.suggestedOrganisation
        }
        requirementDrafts = parsedJob.requirements.map(RoleRequirementDraft.init)
        parserWarnings = importWarnings + parsedJob.warnings
        if requirementDrafts.isEmpty {
            requirementDrafts = [.blank]
        }
    }

    private func beginManualReview() {
        editorError = nil
        parserWarnings = importWarnings + (sourceText.roleReadyTrimmed.isEmpty
            ? []
            : ["The source text has not been analysed. Add the important requirements manually."])
        if requirementDrafts.isEmpty {
            requirementDrafts = [.blank]
        }
        withAnimation(reduceMotion ? nil : .snappy(duration: 0.28)) {
            step = .review
        }
        focusedField = .title
    }

    private func handleImportResult(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            Task { @MainActor in
                isImporting = true
                editorError = nil
                await Task.yield()
                defer { isImporting = false }
                do {
                    let document = try await Task.detached(priority: .userInitiated) {
                        try DocumentImportService().extractText(from: url)
                    }.value
                    try Task.checkCancellation()
                    sourceText = document.text
                    importedFilename = document.name
                    importWarnings = document.warnings
                } catch is CancellationError {
                    return
                } catch {
                    editorError = error.localizedDescription
                }
            }
        case .failure(let error):
            if (error as NSError).code != NSUserCancelledError {
                editorError = error.localizedDescription
            }
        }
    }

    private func addRequirement() {
        let draft = RoleRequirementDraft.blank
        withAnimation(reduceMotion ? nil : .snappy(duration: 0.22)) {
            requirementDrafts.append(draft)
        }
        focusedField = .requirement(draft.id)
    }

    private func removeRequirement(_ id: UUID) {
        withAnimation(reduceMotion ? nil : .snappy(duration: 0.22)) {
            requirementDrafts.removeAll { $0.id == id }
        }
    }

    private func requestDismissal() {
        guard hasUnsavedChanges else {
            dismiss()
            return
        }
        isConfirmingDiscard = true
    }

    private func loadExistingRequirementsIfNeeded() {
        guard let opportunity, !hasLoadedExistingRequirements else { return }
        hasLoadedExistingRequirements = true
        defer { isLoadingExistingRequirements = false }
        let opportunityID = opportunity.id
        do {
            let descriptor = FetchDescriptor<JobRequirement>(
                predicate: #Predicate { requirement in
                    requirement.opportunityID == opportunityID
                },
                sortBy: [
                    SortDescriptor(\JobRequirement.importance, order: .reverse),
                    SortDescriptor(\JobRequirement.createdAt)
                ]
            )
            let drafts = try modelContext.fetch(descriptor).map(RoleRequirementDraft.init)
            requirementDrafts = drafts
            baselineRequirementDrafts = drafts
        } catch {
            editorError = "Saved requirements could not be loaded. \(error.localizedDescription)"
        }
    }

    private func saveRole() {
        guard !isSaving else { return }
        let cleanTitle = roleTitle.roleReadyTrimmed
        guard !cleanTitle.isEmpty else {
            editorError = "Add a role title before saving."
            focusedField = .title
            return
        }

        isSaving = true
        editorError = nil
        focusedField = nil
        defer { isSaving = false }

        let savedInterviewDate = hasInterviewDate ? interviewDate : nil
        let interviewDateChanged = opportunity?.interviewDate != savedInterviewDate
        let cleanSourceText = sourceText.roleReadyTrimmed
        let answerContextChanged = opportunity.map { existing in
            cleanTitle != existing.roleTitle
                || cleanSourceText != existing.sourceText
                || requirementDrafts != baselineRequirementDrafts
        } ?? false

        let target: Opportunity
        if let opportunity {
            target = opportunity
        } else {
            target = Opportunity(
                roleTitle: cleanTitle,
                organisation: organisation.roleReadyTrimmed,
                location: location.roleReadyTrimmed,
                sourceText: sourceText.roleReadyTrimmed,
                status: status,
                closingDate: hasClosingDate ? closingDate : nil,
                interviewDate: hasInterviewDate ? interviewDate : nil,
                notes: notes.roleReadyTrimmed
            )
            modelContext.insert(target)
        }

        target.roleTitle = cleanTitle
        target.organisation = organisation.roleReadyTrimmed
        target.location = location.roleReadyTrimmed
        target.sourceText = cleanSourceText
        target.status = status
        target.closingDate = hasClosingDate ? closingDate : nil
        target.interviewDate = savedInterviewDate
        target.notes = notes.roleReadyTrimmed
        let now = Date()
        target.updatedAt = now
        if opportunity == nil || answerContextChanged {
            target.contentUpdatedAt = now
        }

        do {
            let opportunityID = target.id
            let invalidatedAnswerCount = answerContextChanged
                ? try AnswerApprovalService().invalidateAnswers(forOpportunityID: opportunityID, in: modelContext)
                : 0
            let descriptor = FetchDescriptor<JobRequirement>(
                predicate: #Predicate { requirement in
                    requirement.opportunityID == opportunityID
                }
            )
            try modelContext.fetch(descriptor).forEach(modelContext.delete)

            for draft in requirementDrafts where draft.isIncluded && !draft.text.roleReadyTrimmed.isEmpty {
                modelContext.insert(
                    JobRequirement(
                        opportunityID: target.id,
                        text: draft.text.roleReadyTrimmed,
                        kind: draft.kind,
                        keywords: draft.keywords,
                        capabilities: draft.capabilities,
                        importance: draft.importance,
                        isConfirmed: true
                    )
                )
            }

            try modelContext.save()
            if interviewDateChanged, opportunity != nil {
                NotificationService().cancelReminders(for: target.id)
            }
            if invalidatedAnswerCount > 0 {
                appState.showToast(
                    "Role updated · \(invalidatedAnswerCount) answer\(invalidatedAnswerCount == 1 ? "" : "s") need reconfirmation",
                    symbol: "exclamationmark.triangle.fill"
                )
            } else if interviewDateChanged, opportunity != nil {
                appState.showToast("Role updated · reminder cleared", symbol: "bell.slash.fill")
            } else {
                appState.showToast(opportunity == nil ? "Role added" : "Role updated", symbol: "briefcase.fill")
            }
            dismiss()
        } catch {
            modelContext.rollback()
            editorError = "Your changes could not be saved. \(error.localizedDescription)"
        }
    }
}

private enum RoleEditorStep {
    case source
    case review
}

private enum RoleEditorField: Hashable {
    case source
    case title
    case organisation
    case location
    case notes
    case requirement(UUID)
}

private struct RoleRequirementDraft: Identifiable, Hashable {
    let id: UUID
    var text: String
    var kind: RequirementKind
    var keywordText: String
    var capabilities: [Capability]
    var importance: Int
    var isIncluded: Bool

    init(_ parsed: ParsedRequirement) {
        id = parsed.id
        text = parsed.text
        kind = parsed.kind
        keywordText = parsed.keywords.joined(separator: ", ")
        capabilities = parsed.capabilities
        importance = parsed.importance
        isIncluded = true
    }

    init(_ requirement: JobRequirement) {
        id = requirement.id
        text = requirement.text
        kind = requirement.kind
        keywordText = requirement.keywords.joined(separator: ", ")
        capabilities = requirement.capabilities
        importance = requirement.importance
        isIncluded = requirement.isConfirmed
    }

    init(
        id: UUID = UUID(),
        text: String,
        kind: RequirementKind,
        keywordText: String,
        capabilities: [Capability],
        importance: Int,
        isIncluded: Bool
    ) {
        self.id = id
        self.text = text
        self.kind = kind
        self.keywordText = keywordText
        self.capabilities = capabilities
        self.importance = importance
        self.isIncluded = isIncluded
    }

    static var blank: RoleRequirementDraft {
        RoleRequirementDraft(
            text: "",
            kind: .responsibility,
            keywordText: "",
            capabilities: [],
            importance: 2,
            isIncluded: true
        )
    }

    var keywords: [String] {
        keywordText
            .split(separator: ",")
            .map { String($0).roleReadyTrimmed }
            .filter { !$0.isEmpty }
    }
}

private struct RoleRequirementEditorCard: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding var draft: RoleRequirementDraft
    let focusedField: FocusState<RoleEditorField?>.Binding
    let onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: RRSpacing.md) {
            HStack(alignment: .center, spacing: RRSpacing.sm) {
                Toggle(isOn: $draft.isIncluded) {
                    Label(draft.isIncluded ? "Included" : "Excluded", systemImage: draft.isIncluded ? "checkmark.circle.fill" : "minus.circle")
                        .font(.rrHeadline)
                }
                .tint(BrandTheme.violet)
                .accessibilityHint("Excluded requirements are not saved or matched")

                Spacer(minLength: 0)

                Button(role: .destructive, action: onRemove) {
                    Image(systemName: "trash")
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Remove requirement")
            }

            if draft.isIncluded {
                VStack(alignment: .leading, spacing: RRSpacing.xxs) {
                    Text("Requirement")
                        .font(.rrCaption)
                        .foregroundStyle(BrandTheme.inkMuted)
                    TextField("What does the role ask for?", text: $draft.text, axis: .vertical)
                        .lineLimit(3...8)
                        .focused(focusedField, equals: .requirement(draft.id))
                        .textFieldStyle(.plain)
                        .padding(RRSpacing.sm)
                        .background(BrandTheme.canvasRaised, in: RoundedRectangle(cornerRadius: RRRadius.small, style: .continuous))
                }

                HStack(spacing: RRSpacing.md) {
                    VStack(alignment: .leading, spacing: RRSpacing.xxs) {
                        Text("Type")
                            .font(.rrCaption)
                            .foregroundStyle(BrandTheme.inkMuted)
                        Picker("Requirement type", selection: $draft.kind) {
                            ForEach(RequirementKind.allCases) { kind in
                                Text(kind.title).tag(kind)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(BrandTheme.violet)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: RRSpacing.xxs) {
                        Text("Importance")
                            .font(.rrCaption)
                            .foregroundStyle(BrandTheme.inkMuted)
                        Stepper(value: $draft.importance, in: 1...3) {
                            Text(importanceLabel)
                                .font(.rrCaption)
                                .foregroundStyle(BrandTheme.ink)
                        }
                        .fixedSize()
                    }
                }

                VStack(alignment: .leading, spacing: RRSpacing.xxs) {
                    Text("Keywords")
                        .font(.rrCaption)
                        .foregroundStyle(BrandTheme.inkMuted)
                    TextField("Comma-separated terms", text: $draft.keywordText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .roleEditorTextField()
                }

                VStack(alignment: .leading, spacing: RRSpacing.xs) {
                    HStack {
                        Text("Capabilities")
                            .font(.rrCaption)
                            .foregroundStyle(BrandTheme.inkMuted)
                        Spacer()
                        capabilityMenu
                    }

                    if draft.capabilities.isEmpty {
                        Text("No capability selected")
                            .font(.rrCaption)
                            .foregroundStyle(BrandTheme.inkMuted)
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: RRSpacing.xs) {
                                ForEach(draft.capabilities) { capability in
                                    CapabilityChip(capability: capability, selected: true)
                                }
                            }
                        }
                    }
                }
            }
        }
        .cardSurface(tint: draft.isIncluded ? BrandTheme.surface : BrandTheme.surfaceMuted)
        .opacity(draft.isIncluded ? 1 : 0.78)
        .animation(reduceMotion ? nil : .snappy(duration: 0.2), value: draft.isIncluded)
    }

    private var capabilityMenu: some View {
        Menu {
            ForEach(Capability.allCases) { capability in
                Button {
                    toggle(capability)
                } label: {
                    Label(
                        capability.title,
                        systemImage: draft.capabilities.contains(capability) ? "checkmark" : capability.symbol
                    )
                }
            }
        } label: {
            Label("Choose", systemImage: "tag")
                .font(.rrCaption)
        }
        .tint(BrandTheme.violet)
        .accessibilityLabel("Choose capabilities")
        .accessibilityValue(draft.capabilities.map(\.title).joined(separator: ", "))
    }

    private var importanceLabel: String {
        switch draft.importance {
        case 3: "High"
        case 2: "Medium"
        default: "Supporting"
        }
    }

    private func toggle(_ capability: Capability) {
        if let index = draft.capabilities.firstIndex(of: capability) {
            draft.capabilities.remove(at: index)
        } else {
            draft.capabilities.append(capability)
            draft.capabilities.sort { $0.title < $1.title }
        }
    }
}

private extension View {
    func roleEditorTextField() -> some View {
        padding(RRSpacing.sm)
            .background(BrandTheme.canvasRaised, in: RoundedRectangle(cornerRadius: RRRadius.small, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: RRRadius.small, style: .continuous)
                    .stroke(BrandTheme.separator.opacity(0.8), lineWidth: 0.75)
            }
    }
}

private extension String {
    var roleReadyTrimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
