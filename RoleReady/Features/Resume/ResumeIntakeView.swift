import SwiftData
import SwiftUI

@MainActor
struct ResumeIntakeView: View {
    enum Step { case source, review }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState

    let onCreated: (UUID?) -> Void

    @State private var step: Step = .source
    @State private var sourceText = ""
    @State private var sourceName = "Pasted résumé"
    @State private var filename = "resume.txt"
    @State private var draft: ResumeIntakeDraft?
    @State private var isWorking = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                switch step {
                case .source: sourceStep
                case .review: reviewStep
                }
            }
            .navigationTitle(step == .source ? "Add your résumé" : "Review the import")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(step == .source ? "Cancel" : "Back") {
                        if step == .source { dismiss() } else { step = .source }
                    }
                    .disabled(isWorking)
                }
            }
            .interactiveDismissDisabled(isWorking)
            .alert("Couldn’t continue", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "Try again.")
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .accessibilityIdentifier("resumeIntake.root")
    }

    private var sourceStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: RRSpacing.lg) {
                InfoBanner(
                    title: "Private and reviewable",
                    message: "Files are read on this device. Extracted details remain unverified until you inspect and approve them.",
                    kind: .information
                )

                Button {
                    presentDocumentPicker()
                } label: {
                    HStack(spacing: RRSpacing.md) {
                        Image(systemName: "doc.badge.plus")
                            .font(.title2)
                        VStack(alignment: .leading, spacing: RRSpacing.xxs) {
                            Text(isWorking ? "Reading document…" : "Choose a document")
                                .font(.rrHeadline)
                            Text("PDF, DOCX, RTF or plain text")
                                .font(.subheadline)
                                .foregroundStyle(BrandTheme.inkMuted)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                    .cardSurface(tint: BrandTheme.violetSoft.opacity(0.42))
                }
                .buttonStyle(.plain)
                .disabled(isWorking)
                .accessibilityIdentifier("resumeIntake.chooseDocument")

                HStack {
                    Rectangle().fill(BrandTheme.separator).frame(height: 1)
                    Text("OR PASTE")
                        .font(.rrCaption)
                        .foregroundStyle(BrandTheme.inkMuted)
                    Rectangle().fill(BrandTheme.separator).frame(height: 1)
                }

                VStack(alignment: .leading, spacing: RRSpacing.sm) {
                    Text("Résumé text")
                        .font(.rrHeadline)
                    TextEditor(text: $sourceText)
                        .font(.body)
                        .frame(minHeight: 260)
                        .padding(RRSpacing.sm)
                        .scrollContentBackground(.hidden)
                        .background(BrandTheme.surface, in: RoundedRectangle(cornerRadius: RRRadius.medium))
                        .overlay {
                            RoundedRectangle(cornerRadius: RRRadius.medium)
                                .stroke(BrandTheme.separator, lineWidth: 1)
                        }
                        .accessibilityLabel("Pasted résumé text")
                        .accessibilityIdentifier("resumeIntake.paste")
                }

                Button(action: analyseSource) {
                    Label(isWorking ? "Finding career details…" : "Review extracted details", systemImage: "arrow.right")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryActionButtonStyle())
                .disabled(isWorking || sourceText.trimmingCharacters(in: .whitespacesAndNewlines).count < 40)
                .opacity(sourceText.trimmingCharacters(in: .whitespacesAndNewlines).count < 40 ? 0.55 : 1)
                .accessibilityIdentifier("resumeIntake.analyse")
            }
            .padding(RRSpacing.md)
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
        }
        .screenBackground()
    }

    @ViewBuilder
    private var reviewStep: some View {
        if draft != nil {
            ResumeDraftReviewView(draft: draftBinding) { approve in
                save(approve: approve)
            }
            .disabled(isWorking)
        } else {
            ProgressView("Preparing review…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .screenBackground()
        }
    }

    private var draftBinding: Binding<ResumeIntakeDraft> {
        Binding(
            get: { draft ?? fallbackDraft },
            set: { draft = $0 }
        )
    }

    private var fallbackDraft: ResumeIntakeDraft {
        ResumeIntakeDraft(
            sourceName: sourceName,
            sourceText: sourceText,
            contact: .empty,
            headline: "",
            summary: "",
            positions: [],
            education: [],
            certifications: [],
            skills: [],
            warnings: []
        )
    }

    private func presentDocumentPicker() {
        SystemDocumentPickerService.shared.present(
            contentTypes: DocumentImportService.supportedContentTypes
        ) { outcome in
            guard case .selected(let url) = outcome else { return }
            importDocument(url)
        }
    }

    private func importDocument(_ url: URL) {
        isWorking = true
        Task {
            do {
                let document = try await Task.detached(priority: .userInitiated) {
                    try DocumentImportService().extractText(from: url)
                }.value
                sourceText = document.text
                sourceName = URL(fileURLWithPath: document.name).deletingPathExtension().lastPathComponent
                filename = document.name
                if !document.warnings.isEmpty {
                    appState.showToast(document.warnings[0], symbol: "exclamationmark.triangle.fill")
                }
                analyseSource()
            } catch {
                isWorking = false
                errorMessage = error.localizedDescription
            }
        }
    }

    private func analyseSource() {
        guard !isWorking || draft == nil else { return }
        let text = sourceText
        let name = sourceName
        isWorking = true
        Task {
            do {
                let result = try await Task.detached(priority: .userInitiated) {
                    try ResumeIntakeService().extract(from: text, sourceName: name)
                }.value
                draft = result
                step = .review
            } catch {
                errorMessage = error.localizedDescription
            }
            isWorking = false
        }
    }

    private func save(approve: Bool) {
        guard let draft else { return }
        isWorking = true
        do {
            let summary = try CareerWorkspaceService().saveResumeImport(
                draft,
                filename: filename,
                approveIncludedItems: approve,
                createBaselineResume: approve,
                in: modelContext
            )
            onCreated(summary.resumeVersionID)
            appState.showToast(
                approve ? "Career details approved · résumé created" : "Imported details saved for review",
                symbol: approve ? "checkmark.seal.fill" : "tray.full.fill"
            )
            dismiss()
        } catch {
            modelContext.rollback()
            errorMessage = error.localizedDescription
            isWorking = false
        }
    }
}

private struct ResumeDraftReviewView: View {
    @Binding var draft: ResumeIntakeDraft
    let onSave: (Bool) -> Void

    private var includedCount: Int {
        draft.positions.filter(\.isIncluded).count
            + draft.education.filter(\.isIncluded).count
            + draft.certifications.filter(\.isIncluded).count
            + draft.skills.filter(\.isIncluded).count
    }

    private var duplicateCount: Int {
        let keys = draft.positions.map { "\($0.title.lowercased())|\($0.organisation.lowercased())" }
        return keys.count - Set(keys).count
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: RRSpacing.lg) {
                InfoBanner(
                    title: "Check before approving",
                    message: "Compare each card with the source. Switch off anything incorrect; edit wording, dates and ownership-sensitive details before using them.",
                    kind: .warning
                )

                ForEach(draft.warnings, id: \.self) { warning in
                    Label(warning, systemImage: "info.circle")
                        .font(.footnote)
                        .foregroundStyle(BrandTheme.inkMuted)
                }

                profileSection
                positionSection
                skillSection
                educationSection
                certificationSection

                DisclosureGroup("Compare with original source") {
                    Text(draft.sourceText)
                        .font(.footnote.monospaced())
                        .textSelection(.enabled)
                        .padding(.top, RRSpacing.sm)
                }
                .cardSurface()

                VStack(spacing: RRSpacing.sm) {
                    Button {
                        onSave(true)
                    } label: {
                        Label("Approve \(includedCount) items and create résumé", systemImage: "checkmark.seal.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryActionButtonStyle())
                    .disabled(includedCount == 0 && draft.contact.name.isEmpty)
                    .accessibilityIdentifier("resumeIntake.approve")

                    Button {
                        onSave(false)
                    } label: {
                        Label("Save as unverified drafts", systemImage: "tray.full")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(SecondaryActionButtonStyle())
                    .accessibilityHint("Saves imported details but prevents them from being used in generation")
                }
            }
            .padding(RRSpacing.md)
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
        }
        .screenBackground()
    }

    private var profileSection: some View {
        VStack(alignment: .leading, spacing: RRSpacing.md) {
            SectionHeading(title: "Personal profile", eyebrow: "From the résumé header")
            TextField("Name", text: $draft.contact.name)
                .textContentType(.name)
            TextField("Professional headline", text: $draft.headline)
            TextField("Email", text: $draft.contact.email)
                .textContentType(.emailAddress)
                .textInputAutocapitalization(.never)
            TextField("Phone", text: $draft.contact.phone)
                .textContentType(.telephoneNumber)
            TextField("Location", text: $draft.contact.location)
            TextField("LinkedIn", text: $draft.contact.linkedIn)
                .textInputAutocapitalization(.never)
            TextField("Portfolio", text: $draft.contact.portfolio)
                .textInputAutocapitalization(.never)
            Text("Professional summary")
                .font(.rrCaption)
                .foregroundStyle(BrandTheme.inkMuted)
            TextEditor(text: $draft.summary)
                .frame(minHeight: 100)
                .padding(RRSpacing.xs)
                .background(BrandTheme.surfaceMuted.opacity(0.55), in: RoundedRectangle(cornerRadius: RRRadius.small))
        }
        .textFieldStyle(.roundedBorder)
        .cardSurface()
    }

    private var positionSection: some View {
        VStack(alignment: .leading, spacing: RRSpacing.md) {
            SectionHeading(
                title: "Employment and projects",
                eyebrow: "\(draft.positions.filter(\.isIncluded).count) included"
            )
            if duplicateCount > 0 {
                Button("Combine duplicate roles", action: mergeDuplicatePositions)
                    .font(.rrHeadline)
                    .foregroundStyle(BrandTheme.violet)
            }
            if draft.positions.isEmpty {
                missingDetail("No roles were extracted. Add them later from Career, or edit the résumé manually.")
            } else {
                ForEach($draft.positions) { $position in
                    PositionDraftEditor(position: $position)
                }
            }
        }
        .cardSurface()
    }

    private var skillSection: some View {
        VStack(alignment: .leading, spacing: RRSpacing.md) {
            SectionHeading(title: "Skills and technologies", eyebrow: "Approve only what you have used")
            if draft.skills.isEmpty {
                missingDetail("No dedicated skills section was found.")
            } else {
                ForEach($draft.skills) { $skill in
                    HStack {
                        Toggle(isOn: $skill.isIncluded) {
                            VStack(alignment: .leading, spacing: RRSpacing.xxs) {
                                TextField("Skill", text: $skill.name)
                                    .font(.rrHeadline)
                                if !skill.category.isEmpty {
                                    Text(skill.category)
                                        .font(.rrCaption)
                                        .foregroundStyle(BrandTheme.inkMuted)
                                }
                            }
                        }
                        .tint(BrandTheme.violet)
                    }
                    .textFieldStyle(.plain)
                }
            }
        }
        .cardSurface()
    }

    private var educationSection: some View {
        VStack(alignment: .leading, spacing: RRSpacing.md) {
            SectionHeading(title: "Education", eyebrow: "Verify qualification and institution")
            if draft.education.isEmpty {
                missingDetail("No education section was found.")
            } else {
                ForEach($draft.education) { $item in
                    VStack(alignment: .leading, spacing: RRSpacing.sm) {
                        Toggle("Include", isOn: $item.isIncluded).tint(BrandTheme.violet)
                        TextField("Qualification", text: $item.qualification)
                        TextField("Institution", text: $item.institution)
                        TextField("Field of study", text: $item.fieldOfStudy)
                        TextField("Dates as shown", text: $item.dateText)
                        DisclosureGroup("Source excerpt") {
                            Text(item.sourceExcerpt).font(.footnote.monospaced()).textSelection(.enabled)
                        }
                    }
                    .textFieldStyle(.roundedBorder)
                    .padding(.vertical, RRSpacing.xs)
                }
            }
        }
        .cardSurface()
    }

    private var certificationSection: some View {
        VStack(alignment: .leading, spacing: RRSpacing.md) {
            SectionHeading(title: "Certifications", eyebrow: "Verify issuer and date")
            if draft.certifications.isEmpty {
                missingDetail("No certifications section was found.")
            } else {
                ForEach($draft.certifications) { $item in
                    VStack(alignment: .leading, spacing: RRSpacing.sm) {
                        Toggle("Include", isOn: $item.isIncluded).tint(BrandTheme.violet)
                        TextField("Certification", text: $item.name)
                        TextField("Issuer", text: $item.issuer)
                    }
                    .textFieldStyle(.roundedBorder)
                    .padding(.vertical, RRSpacing.xs)
                }
            }
        }
        .cardSurface()
    }

    private func missingDetail(_ message: String) -> some View {
        Label(message, systemImage: "questionmark.bubble.fill")
            .font(.footnote)
            .foregroundStyle(BrandTheme.warning)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func mergeDuplicatePositions() {
        var merged: [PositionIntakeDraft] = []
        for position in draft.positions {
            let index = merged.firstIndex {
                $0.title.localizedCaseInsensitiveCompare(position.title) == .orderedSame
                    && $0.organisation.localizedCaseInsensitiveCompare(position.organisation) == .orderedSame
            }
            if let index {
                merged[index].bullets = Array(Set(merged[index].bullets + position.bullets)).sorted()
                merged[index].sourceExcerpt += "\n\n" + position.sourceExcerpt
                merged[index].isIncluded = merged[index].isIncluded || position.isIncluded
            } else {
                merged.append(position)
            }
        }
        draft.positions = merged
    }
}

private struct PositionDraftEditor: View {
    @Binding var position: PositionIntakeDraft

    var body: some View {
        VStack(alignment: .leading, spacing: RRSpacing.sm) {
            Toggle("Include this role", isOn: $position.isIncluded)
                .font(.rrHeadline)
                .tint(BrandTheme.violet)
            TextField("Role title", text: $position.title)
            TextField("Organisation", text: $position.organisation)
            TextField("Location", text: $position.location)
            TextField("Dates as shown", text: $position.dateText)
            Text("Achievement bullets")
                .font(.rrCaption)
                .foregroundStyle(BrandTheme.inkMuted)
            TextEditor(text: bulletText)
                .frame(minHeight: 110)
                .padding(RRSpacing.xs)
                .background(BrandTheme.surfaceMuted.opacity(0.55), in: RoundedRectangle(cornerRadius: RRRadius.small))
            if !position.bullets.contains(where: hasOutcomeSignal) {
                Label("How do you know this work helped? Add a truthful result if the résumé omitted it.", systemImage: "questionmark.bubble.fill")
                    .font(.footnote)
                    .foregroundStyle(BrandTheme.warning)
                    .fixedSize(horizontal: false, vertical: true)
            }
            DisclosureGroup("Source excerpt") {
                Text(position.sourceExcerpt)
                    .font(.footnote.monospaced())
                    .textSelection(.enabled)
            }
        }
        .textFieldStyle(.roundedBorder)
        .padding(RRSpacing.md)
        .background(BrandTheme.surfaceMuted.opacity(position.isIncluded ? 0.45 : 0.2), in: RoundedRectangle(cornerRadius: RRRadius.medium))
        .opacity(position.isIncluded ? 1 : 0.62)
    }

    private var bulletText: Binding<String> {
        Binding(
            get: { position.bullets.joined(separator: "\n") },
            set: { value in
                position.bullets = value.components(separatedBy: .newlines)
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
            }
        )
    }

    private func hasOutcomeSignal(_ value: String) -> Bool {
        value.range(of: #"\b(?:increased|reduced|improved|saved|delivered|result|outcome|%|\d+)\b"#, options: [.regularExpression, .caseInsensitive]) != nil
    }
}
