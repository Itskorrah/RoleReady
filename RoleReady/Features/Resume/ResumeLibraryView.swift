import SwiftData
import SwiftUI

@MainActor
struct ResumeLibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppRouter.self) private var router
    @Environment(AppState.self) private var appState

    @Query(sort: \ResumeVersion.updatedAt, order: .reverse) private var versions: [ResumeVersion]
    @Query(sort: \CareerProfile.updatedAt, order: .reverse) private var profiles: [CareerProfile]
    @Query(sort: \CareerPosition.startDate, order: .reverse) private var positions: [CareerPosition]
    @Query private var education: [CareerEducation]
    @Query private var certifications: [CareerCertification]
    @Query(sort: \CareerSkill.name) private var skills: [CareerSkill]

    @State private var isPresentingIntake = false
    @State private var versionToDelete: ResumeVersion?
    @State private var pendingVersionID: UUID?
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: RRSpacing.lg) {
                hero
                if versions.isEmpty {
                    emptyState
                } else {
                    SectionHeading(title: "Your versions", eyebrow: "\(versions.count) saved")
                    ForEach(versions) { version in
                        ResumeVersionCard(
                            version: version,
                            onOpen: { router.navigate(to: .resume(version.id)) },
                            onDuplicate: { duplicate(version) },
                            onDelete: { versionToDelete = version }
                        )
                    }
                }
            }
            .padding(.horizontal, RRSpacing.md)
            .padding(.vertical, RRSpacing.lg)
            .frame(maxWidth: 880)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("Résumés")
        .screenBackground()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Import or paste", systemImage: "square.and.arrow.down") {
                        isPresentingIntake = true
                    }
                    Button("Create manually", systemImage: "doc.badge.plus") {
                        createManualResume()
                    }
                } label: {
                    Label("New résumé", systemImage: "plus")
                }
                .accessibilityIdentifier("resumes.new")
            }
        }
        .sheet(isPresented: $isPresentingIntake, onDismiss: openPendingVersion) {
            ResumeIntakeView { versionID in
                pendingVersionID = versionID
            }
        }
        .alert(
            "Delete this résumé version?",
            isPresented: Binding(
                get: { versionToDelete != nil },
                set: { if !$0 { versionToDelete = nil } }
            ),
            presenting: versionToDelete
        ) { version in
            Button("Delete", role: .destructive) { delete(version) }
            Button("Cancel", role: .cancel) { versionToDelete = nil }
        } message: { version in
            Text("“\(version.name)” will be removed. Your approved career profile and source résumé stay available.")
        }
        .alert("Résumé could not be updated", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "Try again.")
        }
        .accessibilityIdentifier("resumes.library")
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: RRSpacing.lg) {
            HStack(alignment: .top, spacing: RRSpacing.md) {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(.white.opacity(0.14), in: RoundedRectangle(cornerRadius: RRRadius.medium))
                VStack(alignment: .leading, spacing: RRSpacing.xs) {
                    Text("BUILD ON WHAT IS TRUE")
                        .font(.rrCaption)
                        .tracking(0.9)
                        .foregroundStyle(.white.opacity(0.78))
                    Text("One career profile. Every résumé version.")
                        .font(.rrTitle)
                        .foregroundStyle(.white)
                    Text("Import what you have, approve the facts, then create a clear ATS-safe résumé without adding experience you cannot prove.")
                        .font(.rrBody)
                        .foregroundStyle(.white.opacity(0.86))
                }
            }
            Button {
                isPresentingIntake = true
            } label: {
                Label(versions.isEmpty ? "Import or paste a résumé" : "Import another résumé", systemImage: "square.and.arrow.down")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryActionButtonStyle())
            .accessibilityIdentifier("resumes.import")
        }
        .padding(RRSpacing.lg)
        .background(BrandTheme.heroGradient, in: RoundedRectangle(cornerRadius: RRRadius.hero, style: .continuous))
        .shadow(color: BrandTheme.violet.opacity(0.18), radius: 20, y: 10)
    }

    private var emptyState: some View {
        EmptyStatePanel(
            title: "Start with your current résumé",
            message: "Choose a PDF, DOCX, RTF or text file—or paste the content. You will review everything before it becomes approved career information.",
            symbol: "doc.badge.plus",
            actionTitle: "Import or paste"
        ) {
            isPresentingIntake = true
        }
    }

    private func createManualResume() {
        let document = ResumeDocumentFactory().makeDocument(
            profile: profiles.first,
            positions: positions,
            education: education,
            certifications: certifications,
            skills: skills
        )
        let version = ResumeVersion(
            name: versions.isEmpty ? "My résumé" : "Résumé \(versions.count + 1)",
            document: document,
            isBaseline: versions.isEmpty
        )
        modelContext.insert(version)
        do {
            try modelContext.save()
            router.navigate(to: .resume(version.id))
        } catch {
            modelContext.rollback()
            errorMessage = error.localizedDescription
        }
    }

    private func duplicate(_ version: ResumeVersion) {
        let copy = ResumeVersion(
            parentVersionID: version.id,
            sourceID: version.sourceID,
            opportunityID: version.opportunityID,
            name: "\(version.name) copy",
            targetRole: version.targetRole,
            targetOrganisation: version.targetOrganisation,
            template: version.template,
            document: version.document
        )
        modelContext.insert(copy)
        do {
            try modelContext.save()
            appState.showToast("Résumé duplicated", symbol: "doc.on.doc.fill")
        } catch {
            modelContext.rollback()
            errorMessage = error.localizedDescription
        }
    }

    private func delete(_ version: ResumeVersion) {
        modelContext.delete(version)
        do {
            try modelContext.save()
            appState.showToast("Résumé deleted", symbol: "trash.fill")
        } catch {
            modelContext.rollback()
            errorMessage = error.localizedDescription
        }
        versionToDelete = nil
    }

    private func openPendingVersion() {
        guard let id = pendingVersionID else { return }
        pendingVersionID = nil
        router.navigate(to: .resume(id))
    }
}

private struct ResumeVersionCard: View {
    let version: ResumeVersion
    let onOpen: () -> Void
    let onDuplicate: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: RRSpacing.md) {
            Button(action: onOpen) {
                HStack(alignment: .top, spacing: RRSpacing.md) {
                    Image(systemName: version.opportunityID == nil ? "doc.text.fill" : "target")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(BrandTheme.violet)
                        .frame(width: 48, height: 48)
                        .background(BrandTheme.violetSoft, in: RoundedRectangle(cornerRadius: RRRadius.small))
                    VStack(alignment: .leading, spacing: RRSpacing.xs) {
                        HStack {
                            Text(version.name)
                                .font(.rrHeadline)
                                .foregroundStyle(BrandTheme.ink)
                                .multilineTextAlignment(.leading)
                            if version.isBaseline {
                                Text("BASELINE")
                                    .font(.caption2.bold())
                                    .foregroundStyle(BrandTheme.tealText)
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 3)
                                    .background(BrandTheme.tealSoft, in: Capsule())
                            }
                        }
                        if !version.targetRole.isEmpty {
                            Text([version.targetRole, version.targetOrganisation].filter { !$0.isEmpty }.joined(separator: " · "))
                                .font(.subheadline)
                                .foregroundStyle(BrandTheme.inkMuted)
                        }
                        Text("Updated \(version.updatedAt.formatted(.relative(presentation: .named))) · \(version.status.title)")
                            .font(.rrCaption)
                            .foregroundStyle(BrandTheme.inkMuted)
                    }
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("resumes.version.\(version.id.uuidString)")
            Menu {
                Button("Duplicate", systemImage: "doc.on.doc", action: onDuplicate)
                Button("Delete", systemImage: "trash", role: .destructive, action: onDelete)
            } label: {
                Image(systemName: "ellipsis")
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Résumé actions for \(version.name)")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
    }
}
