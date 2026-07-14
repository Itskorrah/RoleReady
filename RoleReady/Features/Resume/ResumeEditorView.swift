import PDFKit
import SwiftData
import SwiftUI

@MainActor
struct ResumeEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState

    let versionID: UUID

    @Query private var versions: [ResumeVersion]
    @State private var draft: ResumeEditingDraft?
    @State private var shareURL: URL?
    @State private var isShowingPreview = false
    @State private var errorMessage: String?
    @State private var hasResolved = false

    init(versionID: UUID) {
        self.versionID = versionID
        let id = versionID
        _versions = Query(filter: #Predicate<ResumeVersion> { $0.id == id })
    }

    var body: some View {
        Group {
            if draft != nil {
                editor
            } else if hasResolved {
                ContentUnavailableView("Résumé unavailable", systemImage: "doc.questionmark", description: Text("This version may have been deleted."))
            } else {
                ProgressView("Opening résumé…")
            }
        }
        .navigationTitle(draft?.name ?? "Résumé")
        .navigationBarTitleDisplayMode(.inline)
        .screenBackground()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Preview", systemImage: "eye", action: preview)
                    Button("Export and share PDF", systemImage: "square.and.arrow.up", action: exportPDF)
                    Button("Mark ready", systemImage: "checkmark.seal") { setReady() }
                } label: {
                    Label("Résumé actions", systemImage: "ellipsis.circle")
                }
                .disabled(draft == nil)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: save)
                    .fontWeight(.semibold)
                    .disabled(draft == nil)
                    .accessibilityIdentifier("resumeEditor.save")
            }
        }
        .task {
            guard draft == nil else { return }
            if let version = versions.first {
                draft = ResumeEditingDraft(version)
            }
            hasResolved = true
        }
        .sheet(isPresented: $isShowingPreview) {
            if let document = draft?.document {
                ResumePreviewView(document: document, name: draft?.name ?? "Résumé")
            }
        }
        .sheet(isPresented: Binding(
            get: { shareURL != nil },
            set: { if !$0 { shareURL = nil } }
        )) {
            if let shareURL {
                ShareSheet(items: [shareURL])
                    .presentationDetents([.medium, .large])
            }
        }
        .alert("Résumé could not be updated", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "Try again.")
        }
        .accessibilityIdentifier("resumeEditor.root")
    }

    private var editor: some View {
        Form {
            Section {
                TextField("Version name", text: draftName)
                Picker("Style", selection: draftTemplate) {
                    ForEach(ResumeTemplate.allCases) { template in
                        Text(template.title).tag(template)
                    }
                }
            } header: {
                Text("Version")
            } footer: {
                Text("Technical is the default restrained, ATS-safe layout. Both styles export as normal selectable text.")
            }

            Section("Contact") {
                TextField("Full name", text: contact(\.name))
                    .textContentType(.name)
                TextField("Professional headline", text: headline)
                TextField("Email", text: contact(\.email))
                    .textContentType(.emailAddress)
                    .textInputAutocapitalization(.never)
                TextField("Phone", text: contact(\.phone))
                    .textContentType(.telephoneNumber)
                TextField("Location", text: contact(\.location))
                TextField("LinkedIn", text: contact(\.linkedIn))
                    .textInputAutocapitalization(.never)
                TextField("Portfolio", text: contact(\.portfolio))
                    .textInputAutocapitalization(.never)
            }

            Section {
                ForEach(sectionIndices, id: \.self) { index in
                    ResumeSectionEditor(section: section(at: index))
                        .moveDisabled(false)
                }
                .onMove(perform: moveSections)
            } header: {
                HStack {
                    Text("Sections")
                    Spacer()
                    EditButton()
                }
            } footer: {
                Text("Switch a section off to remove it from this version. Reorder sections with Edit.")
            }

            Section {
                Button("Preview PDF", systemImage: "eye", action: preview)
                Button("Export and share PDF", systemImage: "square.and.arrow.up", action: exportPDF)
            }
        }
        .scrollContentBackground(.hidden)
    }

    private var draftName: Binding<String> {
        Binding(get: { draft?.name ?? "" }, set: { draft?.name = $0 })
    }

    private var draftTemplate: Binding<ResumeTemplate> {
        Binding(get: { draft?.template ?? .technical }, set: { draft?.template = $0 })
    }

    private var headline: Binding<String> {
        Binding(get: { draft?.document.headline ?? "" }, set: { draft?.document.headline = $0 })
    }

    private func contact(_ keyPath: WritableKeyPath<ResumeContact, String>) -> Binding<String> {
        Binding(
            get: { draft?.document.contact[keyPath: keyPath] ?? "" },
            set: { draft?.document.contact[keyPath: keyPath] = $0 }
        )
    }

    private var sectionIndices: [Int] {
        draft.map { Array($0.document.sections.indices) } ?? []
    }

    private func section(at index: Int) -> Binding<ResumeSection> {
        Binding(
            get: { draft?.document.sections[index] ?? ResumeSection(kind: .summary) },
            set: { draft?.document.sections[index] = $0 }
        )
    }

    private func moveSections(from source: IndexSet, to destination: Int) {
        draft?.document.sections.move(fromOffsets: source, toOffset: destination)
    }

    private func save() {
        guard let draft, let version = versions.first else { return }
        version.name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Untitled résumé" : draft.name
        version.template = draft.template
        version.document = draft.document
        version.updatedAt = Date()
        do {
            try modelContext.save()
            self.draft = ResumeEditingDraft(version)
            appState.showToast("Résumé saved", symbol: "checkmark.circle.fill")
        } catch {
            modelContext.rollback()
            errorMessage = error.localizedDescription
        }
    }

    private func setReady() {
        save()
        guard let version = versions.first else { return }
        version.status = .ready
        version.updatedAt = Date()
        do {
            try modelContext.save()
            draft?.status = .ready
            appState.showToast("Résumé marked ready", symbol: "checkmark.seal.fill")
        } catch {
            modelContext.rollback()
            errorMessage = error.localizedDescription
        }
    }

    private func preview() {
        save()
        guard errorMessage == nil else { return }
        isShowingPreview = true
    }

    private func exportPDF() {
        save()
        guard let draft, errorMessage == nil else { return }
        do {
            let url = try ResumePDFService().makeTemporaryPDF(for: draft.document, name: draft.name)
            if let version = versions.first {
                version.lastExportedAt = Date()
                version.updatedAt = Date()
                try modelContext.save()
            }
            shareURL = url
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct ResumeEditingDraft {
    var name: String
    var template: ResumeTemplate
    var status: ResumeStatus
    var document: ResumeDocument

    init(_ version: ResumeVersion) {
        name = version.name
        template = version.template
        status = version.status
        document = version.document
    }
}

private struct ResumeSectionEditor: View {
    @Binding var section: ResumeSection

    var body: some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: RRSpacing.md) {
                TextField("Section title", text: $section.title)
                    .font(.rrHeadline)
                if section.kind == .summary || section.kind == .skills {
                    TextEditor(text: $section.body)
                        .frame(minHeight: 100)
                        .padding(RRSpacing.xs)
                        .background(BrandTheme.surfaceMuted.opacity(0.55), in: RoundedRectangle(cornerRadius: RRRadius.small))
                }
                ForEach($section.items) { $item in
                    ResumeItemEditor(item: $item) {
                        section.items.removeAll { $0.id == item.id }
                    }
                }
                Button("Add item", systemImage: "plus") {
                    section.items.append(ResumeItem(heading: ""))
                }
                .font(.rrHeadline)
            }
            .padding(.vertical, RRSpacing.sm)
        } label: {
            HStack {
                Image(systemName: section.isVisible ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(section.isVisible ? BrandTheme.success : BrandTheme.inkMuted)
                VStack(alignment: .leading, spacing: RRSpacing.xxs) {
                    Text(section.title)
                        .font(.rrHeadline)
                    Text(section.isVisible ? "Included" : "Hidden from this version")
                        .font(.rrCaption)
                        .foregroundStyle(BrandTheme.inkMuted)
                }
                Spacer()
                Toggle("Include", isOn: $section.isVisible)
                    .labelsHidden()
                    .tint(BrandTheme.violet)
            }
        }
    }
}

private struct ResumeItemEditor: View {
    @Binding var item: ResumeItem
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: RRSpacing.sm) {
            TextField("Role, project or qualification", text: $item.heading)
                .font(.rrHeadline)
            TextField("Organisation or institution", text: $item.subheading)
            TextField("Location", text: $item.location)
            optionalDate("Start", date: $item.startDate)
            optionalDate("End", date: $item.endDate)
            ForEach($item.bullets) { $bullet in
                VStack(alignment: .leading, spacing: RRSpacing.xs) {
                    TextEditor(text: $bullet.text)
                        .frame(minHeight: 72)
                        .padding(RRSpacing.xs)
                        .background(BrandTheme.surfaceMuted.opacity(0.55), in: RoundedRectangle(cornerRadius: RRRadius.small))
                    HStack {
                        Label(bullet.evidence.title, systemImage: evidenceSymbol(bullet.evidence))
                            .font(.rrCaption)
                            .foregroundStyle(bullet.evidence == .noEvidence ? BrandTheme.warning : BrandTheme.success)
                        Spacer()
                        Button("Remove", role: .destructive) {
                            item.bullets.removeAll { $0.id == bullet.id }
                        }
                        .font(.rrCaption)
                    }
                }
            }
            Button("Add bullet", systemImage: "plus") {
                item.bullets.append(ResumeBullet(text: "", evidence: .noEvidence, isApproved: false))
            }
            Button("Remove item", role: .destructive, action: onDelete)
        }
        .padding(RRSpacing.md)
        .background(BrandTheme.surfaceMuted.opacity(0.42), in: RoundedRectangle(cornerRadius: RRRadius.medium))
    }

    @ViewBuilder
    private func optionalDate(_ label: String, date: Binding<Date?>) -> some View {
        Toggle(isOn: Binding(
            get: { date.wrappedValue != nil },
            set: { date.wrappedValue = $0 ? Date() : nil }
        )) {
            Text(label)
        }
        if date.wrappedValue != nil {
            DatePicker(label, selection: Binding(
                get: { date.wrappedValue ?? Date() },
                set: { date.wrappedValue = $0 }
            ), displayedComponents: .date)
        }
    }

    private func evidenceSymbol(_ evidence: EvidenceClassification) -> String {
        switch evidence {
        case .direct: "checkmark.seal.fill"
        case .transferable: "arrow.triangle.branch"
        case .partial: "circle.lefthalf.filled"
        case .noEvidence: "exclamationmark.triangle.fill"
        }
    }
}

private struct ResumePreviewView: View {
    @Environment(\.dismiss) private var dismiss
    let document: ResumeDocument
    let name: String

    @State private var data: Data?
    @State private var errorMessage: String?
    @State private var shareURL: URL?

    var body: some View {
        NavigationStack {
            Group {
                if let data {
                    PDFPreview(data: data)
                        .background(Color(uiColor: .secondarySystemBackground))
                } else if let errorMessage {
                    ContentUnavailableView("Preview unavailable", systemImage: "doc.questionmark", description: Text(errorMessage))
                } else {
                    ProgressView("Creating preview…")
                }
            }
            .navigationTitle("Résumé preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Share", systemImage: "square.and.arrow.up", action: share)
                        .disabled(data == nil)
                }
            }
            .task {
                do {
                    data = try ResumePDFService().data(for: document)
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
            .sheet(isPresented: Binding(
                get: { shareURL != nil },
                set: { if !$0 { shareURL = nil } }
            )) {
                if let shareURL { ShareSheet(items: [shareURL]) }
            }
        }
    }

    private func share() {
        do {
            shareURL = try ResumePDFService().makeTemporaryPDF(for: document, name: name)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct PDFPreview: UIViewRepresentable {
    let data: Data

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.document = PDFDocument(data: data)
        return view
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
        if uiView.document?.dataRepresentation() != data {
            uiView.document = PDFDocument(data: data)
        }
    }
}
