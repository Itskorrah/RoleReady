import SwiftData
import SwiftUI

@MainActor
struct RoleDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppRouter.self) private var router
    @Environment(AppState.self) private var appState

    let opportunityID: UUID

    @Query private var opportunities: [Opportunity]
    @Query private var requirements: [JobRequirement]

    @State private var hasResolvedRole = false
    @State private var editingOpportunity: Opportunity?
    @State private var presentedError: RoleDetailError?

    init(opportunityID: UUID) {
        self.opportunityID = opportunityID
        let id = opportunityID
        _opportunities = Query(
            filter: #Predicate<Opportunity> { opportunity in
                opportunity.id == id
            }
        )
        _requirements = Query(
            filter: #Predicate<JobRequirement> { requirement in
                requirement.opportunityID == id
            },
            sort: [
                SortDescriptor(\JobRequirement.importance, order: .reverse),
                SortDescriptor(\JobRequirement.createdAt)
            ]
        )
    }

    init(opportunity: Opportunity) {
        self.init(opportunityID: opportunity.id)
    }

    var body: some View {
        Group {
            if let opportunity = opportunities.first {
                loadedContent(opportunity)
            } else if hasResolvedRole {
                missingRoleState
            } else {
                loadingState
            }
        }
        .screenBackground()
        .task {
            await Task.yield()
            hasResolvedRole = true
        }
        .sheet(item: $editingOpportunity) { opportunity in
            RoleEditorView(opportunity: opportunity)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .alert("Role could not be updated", isPresented: Binding(
            get: { presentedError != nil },
            set: { if !$0 { presentedError = nil } }
        )) {
            Button("OK", role: .cancel) { presentedError = nil }
        } message: {
            Text(presentedError?.message ?? "Try again.")
        }
        .accessibilityIdentifier("roleDetail.root")
    }

    private func loadedContent(_ opportunity: Opportunity) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: RRSpacing.lg) {
                RoleDetailHero(opportunity: opportunity) { status in
                    update(opportunity, to: status)
                }

                roleActions(opportunity)

                if opportunity.closingDate != nil || opportunity.interviewDate != nil {
                    RoleDateCard(opportunity: opportunity)
                }

                requirementSection(opportunity)

                if !opportunity.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    RoleTextSection(
                        title: "Private notes",
                        eyebrow: "For you",
                        symbol: "note.text",
                        text: opportunity.notes
                    )
                }

                if !opportunity.sourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    RoleSourceDisclosure(sourceText: opportunity.sourceText)
                }
            }
            .padding(.horizontal, RRSpacing.md)
            .padding(.vertical, RRSpacing.lg)
            .frame(maxWidth: 860)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle(opportunity.roleTitle.isEmpty ? "Role" : opportunity.roleTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") {
                    editingOpportunity = opportunity
                }
                .accessibilityIdentifier("roleDetail.edit")
            }
        }
        .accessibilityIdentifier("roleDetail.loaded")
    }

    private func roleActions(_ opportunity: Opportunity) -> some View {
        VStack(spacing: RRSpacing.sm) {
            Button {
                router.navigate(to: .applicationWorkspace(opportunity.id))
            } label: {
                Label("Open application workspace", systemImage: "folder.fill.badge.gearshape")
            }
            .buttonStyle(PrimaryActionButtonStyle())
            .accessibilityHint("Tailor a résumé, draft a cover letter and track this application")
            .accessibilityIdentifier("roleDetail.applicationWorkspace")

            Button {
                router.navigate(to: .matchReport(opportunity.id))
            } label: {
                Label("View evidence match", systemImage: "arrow.triangle.branch")
            }
            .buttonStyle(SecondaryActionButtonStyle())
            .disabled(requirements.filter(\.isConfirmed).isEmpty)
            .opacity(requirements.contains(where: \.isConfirmed) ? 1 : 0.55)
            .accessibilityHint(requirements.filter(\.isConfirmed).isEmpty ? "Add a confirmed requirement first" : "Shows the best evidence for each requirement")
            .accessibilityIdentifier("roleDetail.matchReport")

            Button {
                router.navigate(to: .prepDeck(opportunity.id))
            } label: {
                Label("Prepare for this interview", systemImage: "quote.bubble.fill")
            }
            .buttonStyle(SecondaryActionButtonStyle())
            .accessibilityIdentifier("roleDetail.interviewPrep")
        }
    }

    @ViewBuilder
    private func requirementSection(_ opportunity: Opportunity) -> some View {
        let confirmed = requirements.filter(\.isConfirmed)
        VStack(alignment: .leading, spacing: RRSpacing.md) {
            SectionHeading(
                title: "What this role needs",
                eyebrow: confirmed.isEmpty ? "Not analysed" : "\(confirmed.count) confirmed",
                actionTitle: "Edit"
            ) {
                editingOpportunity = opportunity
            }

            if confirmed.isEmpty {
                EmptyStatePanel(
                    title: "Add requirements to unlock matching",
                    message: "Paste the advertisement again or add the role’s must-haves manually. Matching only uses requirements you have reviewed.",
                    symbol: "checklist",
                    actionTitle: "Edit role"
                ) {
                    editingOpportunity = opportunity
                }
                .accessibilityIdentifier("roleDetail.requirements.empty")
            } else {
                ForEach(confirmed) { requirement in
                    RoleDetailRequirementCard(requirement: requirement)
                        .accessibilityIdentifier("roleDetail.requirement.\(requirement.id.uuidString)")
                }
            }
        }
    }

    private var loadingState: some View {
        ScrollView {
            VStack(spacing: RRSpacing.md) {
                ForEach(0..<3, id: \.self) { index in
                    RoundedRectangle(cornerRadius: RRRadius.large, style: .continuous)
                        .fill(BrandTheme.surface)
                        .frame(height: index == 0 ? 220 : 130)
                }
            }
            .padding(RRSpacing.md)
            .redacted(reason: .placeholder)
        }
        .navigationTitle("Role")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Loading role")
        .accessibilityIdentifier("roleDetail.loading")
    }

    private var missingRoleState: some View {
        ContentUnavailableView {
            Label("Role unavailable", systemImage: "briefcase.fill")
        } description: {
            Text("This role may have been deleted on another screen.")
        } actions: {
            Button("Back to roles") { dismiss() }
                .buttonStyle(.borderedProminent)
                .tint(BrandTheme.violet)
        }
        .navigationTitle("Role")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("roleDetail.missing")
    }

    private func update(_ opportunity: Opportunity, to status: OpportunityStatus) {
        let previousStatus = opportunity.status
        guard previousStatus != status else { return }
        opportunity.status = status
        opportunity.updatedAt = Date()
        do {
            try modelContext.save()
            if status != .preparing && status != .interviewing {
                NotificationService().cancelReminders(for: opportunity.id)
            }
            appState.showToast("Moved to \(status.title)", symbol: status.symbol)
        } catch {
            modelContext.rollback()
            presentedError = RoleDetailError(message: error.localizedDescription)
        }
    }
}

private struct RoleDetailError: Identifiable {
    let id = UUID()
    let message: String
}

private struct RoleDetailHero: View {
    let opportunity: Opportunity
    let onStatusChange: (OpportunityStatus) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: RRSpacing.lg) {
            HStack(alignment: .top, spacing: RRSpacing.md) {
                Image(systemName: "briefcase.fill")
                    .font(.system(size: 25, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 58, height: 58)
                    .background(Color.white.opacity(0.15), in: RoundedRectangle(cornerRadius: RRRadius.medium, style: .continuous))

                VStack(alignment: .leading, spacing: RRSpacing.xs) {
                    Text(opportunity.roleTitle.isEmpty ? "Untitled role" : opportunity.roleTitle)
                        .font(.rrHero)
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                    if !opportunity.organisation.isEmpty {
                        Text(opportunity.organisation)
                            .font(.rrHeadline)
                            .foregroundStyle(Color.white.opacity(0.86))
                    }
                    if !opportunity.location.isEmpty {
                        Label(opportunity.location, systemImage: "mappin.and.ellipse")
                            .font(.rrCaption)
                            .foregroundStyle(Color.white.opacity(0.76))
                    }
                }
                Spacer(minLength: 0)
            }

            Menu {
                ForEach(OpportunityStatus.allCases) { status in
                    Button {
                        onStatusChange(status)
                    } label: {
                        Label(
                            status.title,
                            systemImage: status == opportunity.status ? "checkmark" : status.symbol
                        )
                    }
                }
            } label: {
                HStack {
                    Label(opportunity.status.title, systemImage: opportunity.status.symbol)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2.weight(.bold))
                }
                .font(.rrHeadline)
                .foregroundStyle(.white)
                .padding(.horizontal, RRSpacing.md)
                .padding(.vertical, RRSpacing.sm)
                .background(Color.white.opacity(0.13), in: RoundedRectangle(cornerRadius: RRRadius.medium, style: .continuous))
            }
            .accessibilityLabel("Application status")
            .accessibilityValue(opportunity.status.title)
            .accessibilityHint("Double tap to change status")
            .accessibilityIdentifier("roleDetail.status")
        }
        .padding(RRSpacing.lg)
        .background(BrandTheme.heroGradient, in: RoundedRectangle(cornerRadius: RRRadius.hero, style: .continuous))
        .shadow(color: BrandTheme.violet.opacity(0.18), radius: 22, y: 11)
    }
}

private struct RoleDateCard: View {
    let opportunity: Opportunity

    var body: some View {
        VStack(alignment: .leading, spacing: RRSpacing.md) {
            SectionHeading(title: "Key dates", eyebrow: "Plan ahead")
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: RRSpacing.sm) {
                    dateMetrics
                }
                VStack(spacing: RRSpacing.sm) {
                    dateMetrics
                }
            }
        }
        .cardSurface()
    }

    private func dateMetric(
        title: String,
        date: Date,
        symbol: String,
        colour: Color,
        includesTime: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: RRSpacing.xs) {
            Image(systemName: symbol)
                .font(.headline)
                .foregroundStyle(colour)
            Text(title)
                .font(.rrCaption)
                .foregroundStyle(BrandTheme.inkMuted)
            Text(displayText(for: date, includesTime: includesTime))
                .font(.rrHeadline)
                .foregroundStyle(BrandTheme.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(RRSpacing.md)
        .background(colour.opacity(0.10), in: RoundedRectangle(cornerRadius: RRRadius.medium, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(date.formatted(date: .long, time: includesTime ? .shortened : .omitted))")
    }

    private func displayText(for date: Date, includesTime: Bool) -> String {
        if includesTime {
            return date.formatted(.dateTime.day().month(.abbreviated).hour().minute())
        }
        return date.formatted(.dateTime.day().month(.abbreviated))
    }

    @ViewBuilder
    private var dateMetrics: some View {
        if let closingDate = opportunity.closingDate {
            dateMetric(
                title: "Closes",
                date: closingDate,
                symbol: "calendar.badge.exclamationmark",
                colour: closingDate < Date() ? BrandTheme.danger : BrandTheme.amberText
            )
        }
        if let interviewDate = opportunity.interviewDate {
            dateMetric(
                title: "Interview",
                date: interviewDate,
                symbol: "person.2.fill",
                colour: BrandTheme.violet,
                includesTime: true
            )
        }
    }
}

private struct RoleDetailRequirementCard: View {
    let requirement: JobRequirement

    var body: some View {
        VStack(alignment: .leading, spacing: RRSpacing.sm) {
            HStack(alignment: .center, spacing: RRSpacing.sm) {
                Text(requirement.kind.title)
                    .font(.rrCaption)
                    .foregroundStyle(kindColour)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .background(kindColour.opacity(0.11), in: Capsule())
                Spacer()
                ImportanceIndicator(value: requirement.importance)
            }

            Text(requirement.text)
                .font(.rrBody)
                .foregroundStyle(BrandTheme.ink)
                .fixedSize(horizontal: false, vertical: true)

            if !requirement.capabilities.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: RRSpacing.xs) {
                        ForEach(requirement.capabilities) { capability in
                            CapabilityChip(capability: capability)
                        }
                    }
                }
            }

            if !requirement.keywords.isEmpty {
                Text(requirement.keywords.prefix(6).joined(separator: " · "))
                    .font(.rrCaption)
                    .foregroundStyle(BrandTheme.inkMuted)
                    .lineLimit(2)
            }
        }
        .cardSurface()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(requirement.kind.title), importance \(requirement.importance) of 3. \(requirement.text)")
    }

    private var kindColour: Color {
        switch requirement.kind {
        case .mustHave: BrandTheme.danger
        case .responsibility: BrandTheme.violet
        case .signal: BrandTheme.tealText
        }
    }
}

private struct ImportanceIndicator: View {
    let value: Int

    var body: some View {
        HStack(spacing: 4) {
            ForEach(1...3, id: \.self) { index in
                Circle()
                    .fill(index <= value ? BrandTheme.amberText : BrandTheme.separator)
                    .frame(width: 7, height: 7)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Importance")
        .accessibilityValue("\(value) of 3")
    }
}

private struct RoleTextSection: View {
    let title: String
    let eyebrow: String
    let symbol: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: RRSpacing.md) {
            SectionHeading(title: title, eyebrow: eyebrow)
            Label {
                Text(text)
                    .font(.rrBody)
                    .foregroundStyle(BrandTheme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            } icon: {
                Image(systemName: symbol)
                    .foregroundStyle(BrandTheme.violet)
            }
            .labelStyle(.titleAndIcon)
        }
        .cardSurface()
    }
}

private struct RoleSourceDisclosure: View {
    let sourceText: String
    @State private var isExpanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            Text(sourceText)
                .font(.rrBody)
                .foregroundStyle(BrandTheme.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
                .padding(.top, RRSpacing.md)
        } label: {
            Label("Original job advertisement", systemImage: "doc.text")
                .font(.rrHeadline)
                .foregroundStyle(BrandTheme.ink)
        }
        .tint(BrandTheme.violet)
        .cardSurface()
        .accessibilityIdentifier("roleDetail.source")
    }
}
