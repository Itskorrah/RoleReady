import SwiftData
import SwiftUI

@MainActor
struct CareerWorkspaceView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppRouter.self) private var router
    @Environment(AppState.self) private var appState

    @Query(sort: \CareerProfile.updatedAt, order: .reverse) private var profiles: [CareerProfile]
    @Query(sort: \CareerPosition.startDate, order: .reverse) private var positions: [CareerPosition]
    @Query(sort: \CareerEducation.endDate, order: .reverse) private var education: [CareerEducation]
    @Query(sort: \CareerCertification.issuedAt, order: .reverse) private var certifications: [CareerCertification]
    @Query(sort: \CareerSkill.name) private var skills: [CareerSkill]
    @Query(sort: \CareerSource.importedAt, order: .reverse) private var sources: [CareerSource]
    @Query(sort: \Experience.updatedAt, order: .reverse) private var examples: [Experience]

    @State private var editingPosition: CareerPosition?
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: RRSpacing.lg) {
                profileCard
                reviewSummary
                positionsSection
                skillsSection
                educationSection
                certificationsSection
                examplesCard
                sourceSection
            }
            .padding(.horizontal, RRSpacing.md)
            .padding(.vertical, RRSpacing.lg)
            .frame(maxWidth: 880)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("Career")
        .screenBackground()
        .sheet(item: $editingPosition) { position in
            CareerPositionEditorView(position: position)
        }
        .alert("Career profile could not be updated", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "Try again.")
        }
        .accessibilityIdentifier("career.workspace")
    }

    private var profileCard: some View {
        Button {
            router.navigate(to: .profile)
        } label: {
            HStack(spacing: RRSpacing.md) {
                CareerAvatar(name: profiles.first?.name ?? "")
                VStack(alignment: .leading, spacing: RRSpacing.xs) {
                    Text(profiles.first?.name.isEmpty == false ? profiles.first?.name ?? "My career profile" : "Complete your career profile")
                        .font(.rrTitle)
                        .foregroundStyle(BrandTheme.ink)
                    Text(profiles.first?.headline.isEmpty == false ? profiles.first?.headline ?? "" : "Contact details, headline, goals and professional summary")
                        .font(.rrBody)
                        .foregroundStyle(BrandTheme.inkMuted)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(BrandTheme.inkMuted)
            }
            .cardSurface(tint: BrandTheme.violetSoft.opacity(0.38))
        }
        .buttonStyle(.plain)
    }

    private var reviewSummary: some View {
        HStack(spacing: RRSpacing.sm) {
            CareerMetric(value: "\(approvedCount)", label: "Approved", color: BrandTheme.success)
            CareerMetric(value: "\(needsReviewCount)", label: "Needs review", color: BrandTheme.warning)
            CareerMetric(value: "\(sources.count)", label: "Sources", color: BrandTheme.violet)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(approvedCount) approved career items. \(needsReviewCount) need review. \(sources.count) sources.")
    }

    private var positionsSection: some View {
        VStack(alignment: .leading, spacing: RRSpacing.md) {
            SectionHeading(title: "Employment and projects", eyebrow: "\(positions.count) records")
            if positions.isEmpty {
                Text("Import a résumé from the Résumés tab or add roles to a résumé manually.")
                    .font(.rrBody)
                    .foregroundStyle(BrandTheme.inkMuted)
                    .cardSurface()
            } else {
                ForEach(positions) { position in
                    CareerRecordCard(
                        title: position.title,
                        subtitle: position.organisation,
                        excerpt: position.sourceExcerpt,
                        status: position.verificationStatus,
                        onEdit: { editingPosition = position },
                        onApprove: position.verificationStatus == .approved ? nil : { approve(position) },
                        onReject: position.verificationStatus == .rejected ? nil : { reject(position) }
                    )
                }
            }
        }
    }

    private var skillsSection: some View {
        VStack(alignment: .leading, spacing: RRSpacing.md) {
            SectionHeading(title: "Skills and technologies", eyebrow: "Only approved skills power generation")
            if skills.isEmpty {
                Text("No skills recorded yet.")
                    .foregroundStyle(BrandTheme.inkMuted)
                    .cardSurface()
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: RRSpacing.xs)], alignment: .leading, spacing: RRSpacing.xs) {
                    ForEach(skills) { skill in
                        Menu {
                            if skill.verificationStatus != .approved {
                                Button("Approve", systemImage: "checkmark.seal") { approve(skill) }
                            }
                            Button("Reject", systemImage: "xmark", role: .destructive) { reject(skill) }
                        } label: {
                            Label(skill.name, systemImage: skill.verificationStatus == .approved ? "checkmark.circle.fill" : "clock.badge.questionmark")
                                .font(.rrCaption)
                                .foregroundStyle(skill.verificationStatus == .approved ? BrandTheme.success : BrandTheme.warning)
                                .padding(.horizontal, RRSpacing.sm)
                                .padding(.vertical, RRSpacing.xs)
                                .background(BrandTheme.surface, in: Capsule())
                        }
                    }
                }
            }
        }
    }

    private var educationSection: some View {
        careerListSection(
            title: "Education",
            empty: "No education recorded yet.",
            records: education.map { item in
                CareerListRecord(
                    id: item.id,
                    title: item.qualification,
                    subtitle: item.institution,
                    status: item.verificationStatus,
                    onApprove: { approve(item) },
                    onReject: { reject(item) }
                )
            }
        )
    }

    private var certificationsSection: some View {
        careerListSection(
            title: "Certifications",
            empty: "No certifications recorded yet.",
            records: certifications.map { item in
                CareerListRecord(
                    id: item.id,
                    title: item.name,
                    subtitle: item.issuer,
                    status: item.verificationStatus,
                    onApprove: { approve(item) },
                    onReject: { reject(item) }
                )
            }
        )
    }

    private var examplesCard: some View {
        Button {
            router.navigate(to: .examples)
        } label: {
            HStack(spacing: RRSpacing.md) {
                Image(systemName: "square.stack.3d.up.fill")
                    .font(.title3)
                    .foregroundStyle(BrandTheme.violet)
                    .frame(width: 48, height: 48)
                    .background(BrandTheme.violetSoft, in: RoundedRectangle(cornerRadius: RRRadius.small))
                VStack(alignment: .leading, spacing: RRSpacing.xs) {
                    Text("Interview examples")
                        .font(.rrHeadline)
                        .foregroundStyle(BrandTheme.ink)
                    Text("\(examples.count) STAR example\(examples.count == 1 ? "" : "s") · used for answers and interview practice")
                        .font(.subheadline)
                        .foregroundStyle(BrandTheme.inkMuted)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(BrandTheme.inkMuted)
            }
            .cardSurface()
        }
        .buttonStyle(.plain)
    }

    private var sourceSection: some View {
        VStack(alignment: .leading, spacing: RRSpacing.md) {
            SectionHeading(title: "Sources", eyebrow: "Private on this device")
            ForEach(sources) { source in
                DisclosureGroup {
                    Text(source.rawText)
                        .font(.footnote.monospaced())
                        .textSelection(.enabled)
                        .padding(.top, RRSpacing.sm)
                } label: {
                    VStack(alignment: .leading, spacing: RRSpacing.xxs) {
                        Text(source.name).font(.rrHeadline)
                        Text("\(source.kind.title) · imported \(source.importedAt.formatted(.relative(presentation: .named)))")
                            .font(.rrCaption)
                            .foregroundStyle(BrandTheme.inkMuted)
                    }
                }
                .cardSurface()
            }
        }
    }

    private var approvedCount: Int {
        positions.filter { $0.verificationStatus == .approved }.count
            + education.filter { $0.verificationStatus == .approved }.count
            + certifications.filter { $0.verificationStatus == .approved }.count
            + skills.filter { $0.verificationStatus == .approved }.count
    }

    private var needsReviewCount: Int {
        positions.filter { $0.verificationStatus == .imported || $0.verificationStatus == .reviewed }.count
            + education.filter { $0.verificationStatus == .imported || $0.verificationStatus == .reviewed }.count
            + certifications.filter { $0.verificationStatus == .imported || $0.verificationStatus == .reviewed }.count
            + skills.filter { $0.verificationStatus == .imported || $0.verificationStatus == .reviewed }.count
    }

    private func careerListSection(
        title: String,
        empty: String,
        records: [CareerListRecord]
    ) -> some View {
        VStack(alignment: .leading, spacing: RRSpacing.md) {
            SectionHeading(title: title, eyebrow: "\(records.count) records")
            if records.isEmpty {
                Text(empty).foregroundStyle(BrandTheme.inkMuted).cardSurface()
            } else {
                ForEach(records) { record in
                    HStack {
                        VStack(alignment: .leading, spacing: RRSpacing.xxs) {
                            Text(record.title).font(.rrHeadline)
                            Text(record.subtitle).font(.subheadline).foregroundStyle(BrandTheme.inkMuted)
                        }
                        Spacer()
                        Menu {
                            if record.status != .approved { Button("Approve", action: record.onApprove) }
                            Button("Reject", role: .destructive, action: record.onReject)
                        } label: {
                            CareerStatusBadge(status: record.status)
                        }
                    }
                    .cardSurface()
                }
            }
        }
    }

    private func approve(_ position: CareerPosition) {
        perform { try CareerWorkspaceService().approveRecord(position, in: modelContext) }
    }

    private func approve(_ item: CareerEducation) {
        perform { try CareerWorkspaceService().approveRecord(item, in: modelContext) }
    }

    private func approve(_ item: CareerCertification) {
        perform { try CareerWorkspaceService().approveRecord(item, in: modelContext) }
    }

    private func approve(_ item: CareerSkill) {
        perform { try CareerWorkspaceService().approveRecord(item, in: modelContext) }
    }

    private func reject(_ position: CareerPosition) {
        perform { position.verificationStatus = .rejected; position.updatedAt = Date(); try modelContext.save() }
    }

    private func reject(_ item: CareerEducation) {
        perform { item.verificationStatus = .rejected; item.updatedAt = Date(); try modelContext.save() }
    }

    private func reject(_ item: CareerCertification) {
        perform { item.verificationStatus = .rejected; item.updatedAt = Date(); try modelContext.save() }
    }

    private func reject(_ item: CareerSkill) {
        perform { item.verificationStatus = .rejected; item.updatedAt = Date(); try modelContext.save() }
    }

    private func perform(_ action: () throws -> Void) {
        do {
            try action()
            appState.showToast("Career record updated", symbol: "checkmark.circle.fill")
        } catch {
            modelContext.rollback()
            errorMessage = error.localizedDescription
        }
    }
}

private struct CareerMetric: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: RRSpacing.xxs) {
            Text(value).font(.rrTitle).foregroundStyle(color)
            Text(label).font(.rrCaption).foregroundStyle(BrandTheme.inkMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface(padding: RRSpacing.sm)
    }
}

private struct CareerListRecord: Identifiable {
    let id: UUID
    let title: String
    let subtitle: String
    let status: CareerRecordStatus
    let onApprove: () -> Void
    let onReject: () -> Void
}

private struct CareerAvatar: View {
    let name: String

    private var initials: String {
        let parts = name.split(separator: " ")
        let value = parts.prefix(2).compactMap(\.first).map(String.init).joined()
        return value.isEmpty ? "ME" : value.uppercased()
    }

    var body: some View {
        Text(initials)
            .font(.rrHeadline)
            .foregroundStyle(.white)
            .frame(width: 52, height: 52)
            .background(BrandTheme.violet, in: Circle())
            .accessibilityHidden(true)
    }
}

private struct CareerStatusBadge: View {
    let status: CareerRecordStatus

    var body: some View {
        Label(status.title, systemImage: status == .approved ? "checkmark.seal.fill" : "clock.badge.questionmark")
            .font(.rrCaption)
            .foregroundStyle(status == .approved ? BrandTheme.success : BrandTheme.warning)
            .padding(.horizontal, RRSpacing.sm)
            .padding(.vertical, 7)
            .background((status == .approved ? BrandTheme.tealSoft : BrandTheme.amberSoft), in: Capsule())
    }
}

private struct CareerRecordCard: View {
    let title: String
    let subtitle: String
    let excerpt: String
    let status: CareerRecordStatus
    let onEdit: () -> Void
    let onApprove: (() -> Void)?
    let onReject: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: RRSpacing.sm) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: RRSpacing.xxs) {
                    Text(title).font(.rrHeadline)
                    Text(subtitle).font(.subheadline).foregroundStyle(BrandTheme.inkMuted)
                }
                Spacer()
                CareerStatusBadge(status: status)
            }
            if !excerpt.isEmpty {
                DisclosureGroup("Source") {
                    Text(excerpt).font(.footnote.monospaced()).textSelection(.enabled)
                }
            }
            HStack {
                Button("Edit", action: onEdit)
                Spacer()
                if let onReject { Button("Reject", role: .destructive, action: onReject) }
                if let onApprove { Button("Approve", action: onApprove).buttonStyle(.borderedProminent).tint(BrandTheme.violet) }
            }
        }
        .cardSurface()
    }
}

private struct CareerPositionEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState
    @Bindable var position: CareerPosition

    @State private var bulletText = ""
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Role") {
                    TextField("Title", text: $position.title)
                    TextField("Organisation", text: $position.organisation)
                    TextField("Location", text: $position.location)
                    Picker("Employment type", selection: $position.employmentType) {
                        ForEach(EmploymentType.allCases) { type in Text(type.title).tag(type) }
                    }
                    Toggle("Current role", isOn: $position.isCurrent)
                }
                Section("Achievement bullets") {
                    TextEditor(text: $bulletText).frame(minHeight: 180)
                    Text("Use one truthful bullet per line. Keep metrics only when the source supports them.")
                        .font(.footnote)
                }
                if !position.sourceExcerpt.isEmpty {
                    Section("Original source") {
                        Text(position.sourceExcerpt).font(.footnote.monospaced()).textSelection(.enabled)
                    }
                }
            }
            .navigationTitle("Edit career record")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { modelContext.rollback(); dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save", action: save).fontWeight(.semibold) }
            }
            .onAppear { bulletText = position.bullets.joined(separator: "\n") }
            .alert("Could not save", isPresented: Binding(
                get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }
            )) { Button("OK", role: .cancel) {} } message: { Text(errorMessage ?? "Try again.") }
        }
    }

    private func save() {
        position.bullets = bulletText.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        position.verificationStatus = .reviewed
        position.updatedAt = Date()
        do {
            try modelContext.save()
            appState.showToast("Saved for approval", symbol: "pencil.and.list.clipboard")
            dismiss()
        } catch {
            modelContext.rollback()
            errorMessage = error.localizedDescription
        }
    }
}
