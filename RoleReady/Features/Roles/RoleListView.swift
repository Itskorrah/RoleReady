import SwiftData
import SwiftUI

@MainActor
struct RoleListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppRouter.self) private var router
    @Environment(AppState.self) private var appState

    @Query(sort: \Opportunity.updatedAt, order: .reverse)
    private var opportunities: [Opportunity]

    @Query private var requirements: [JobRequirement]

    @State private var searchText = ""
    @State private var statusFilter: OpportunityStatus?
    @State private var pendingDeletion: Opportunity?
    @State private var persistenceError: String?

    private var filteredOpportunities: [Opportunity] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return opportunities.filter { opportunity in
            let matchesStatus = statusFilter.map { opportunity.status == $0 } ?? true
            guard matchesStatus else { return false }
            guard !query.isEmpty else { return true }
            return [
                opportunity.roleTitle,
                opportunity.organisation,
                opportunity.location,
                opportunity.status.title,
                opportunity.notes
            ]
            .contains { $0.localizedCaseInsensitiveContains(query) }
        }
    }

    private var confirmedRequirementCounts: [UUID: Int] {
        Dictionary(grouping: requirements.filter(\.isConfirmed), by: \.opportunityID)
            .mapValues(\.count)
    }

    var body: some View {
        let requirementCounts = confirmedRequirementCounts
        let visibleOpportunities = filteredOpportunities

        List {
            if !opportunities.isEmpty {
                RolePipelineSummary(opportunities: opportunities)
                    .listRowInsets(.init(top: RRSpacing.sm, leading: RRSpacing.md, bottom: RRSpacing.xs, trailing: RRSpacing.md))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)

                RoleStatusFilter(
                    selectedStatus: $statusFilter,
                    opportunities: opportunities
                )
                .listRowInsets(.init(top: RRSpacing.xs, leading: 0, bottom: RRSpacing.sm, trailing: 0))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }

            if opportunities.isEmpty {
                EmptyStatePanel(
                    title: "Bring your next role into focus",
                    message: "Paste or import a job advertisement. RoleReady will find requirement themes you can check before comparing your examples.",
                    symbol: "briefcase.fill",
                    actionTitle: "Add your first role"
                ) {
                    appState.presentedSheet = .addRole
                }
                .listRowInsets(.init(top: RRSpacing.xl, leading: RRSpacing.md, bottom: RRSpacing.md, trailing: RRSpacing.md))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .accessibilityIdentifier("roles.empty.add")
            } else if visibleOpportunities.isEmpty {
                ContentUnavailableView {
                    Label("No matching roles", systemImage: "magnifyingglass")
                } description: {
                    Text(emptyResultsMessage)
                } actions: {
                    Button("Clear filters") {
                        searchText = ""
                        statusFilter = nil
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(BrandTheme.violet)
                    .accessibilityIdentifier("roles.filters.clear")
                }
                .listRowInsets(.init(top: RRSpacing.xl, leading: RRSpacing.md, bottom: RRSpacing.md, trailing: RRSpacing.md))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            } else {
                Section {
                    ForEach(visibleOpportunities) { opportunity in
                        Button {
                            router.navigate(to: .opportunity(opportunity.id))
                        } label: {
                            RoleListRow(
                                opportunity: opportunity,
                                requirementCount: requirementCounts[opportunity.id, default: 0]
                            )
                        }
                        .buttonStyle(.plain)
                        .contentShape(Rectangle())
                        .listRowInsets(.init(top: RRSpacing.xs, leading: RRSpacing.md, bottom: RRSpacing.xs, trailing: RRSpacing.md))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .accessibilityIdentifier("roles.row.\(opportunity.id.uuidString)")
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                pendingDeletion = opportunity
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                } header: {
                    Text(resultHeader(count: visibleOpportunities.count))
                        .font(.rrCaption)
                        .foregroundStyle(BrandTheme.inkMuted)
                        .textCase(nil)
                        .accessibilityAddTraits(.isHeader)
                }
            }
        }
        .frame(maxWidth: 900)
        .frame(maxWidth: .infinity)
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .environment(\.defaultMinListRowHeight, 1)
        .navigationTitle("Roles")
        .navigationBarTitleDisplayMode(.large)
        .searchable(
            text: $searchText,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "Role, organisation or location"
        )
        .screenBackground()
        .alert(
            "Delete this role?",
            isPresented: Binding(
                get: { pendingDeletion != nil },
                set: { if !$0 { pendingDeletion = nil } }
            ),
            presenting: pendingDeletion
        ) { opportunity in
            Button("Delete", role: .destructive) { delete(opportunity) }
            Button("Cancel", role: .cancel) { pendingDeletion = nil }
        } message: { opportunity in
            Text("“\(opportunity.roleTitle)”, its requirements, reflection, and reminder will be removed. Prepared answers remain available as general practice.")
        }
        .alert("Role could not be deleted", isPresented: Binding(
            get: { persistenceError != nil },
            set: { if !$0 { persistenceError = nil } }
        )) {
            Button("OK", role: .cancel) { persistenceError = nil }
        } message: {
            Text(persistenceError ?? "Try again.")
        }
        .accessibilityIdentifier("roles.list")
    }

    private var emptyResultsMessage: String {
        if let statusFilter, !searchText.isEmpty {
            return "No \(statusFilter.title.lowercased()) roles match “\(searchText)”."
        }
        if let statusFilter {
            return "There are no roles in \(statusFilter.title.lowercased()) yet."
        }
        return "Try a role title, organisation, location or status."
    }

    private func resultHeader(count: Int) -> String {
        return "\(count) \(count == 1 ? "role" : "roles")"
    }

    private func delete(_ opportunity: Opportunity) {
        let opportunityID = opportunity.id
        do {
            try OpportunityDeletionService().delete(opportunity, in: modelContext)
            NotificationService().cancelReminders(for: opportunityID)
            appState.showToast("Role deleted", symbol: "trash.fill")
        } catch {
            modelContext.rollback()
            persistenceError = error.localizedDescription
        }
    }
}

private struct RolePipelineSummary: View {
    let opportunities: [Opportunity]

    private var activeCount: Int {
        opportunities.filter { $0.status != .closed }.count
    }

    private var interviewCount: Int {
        opportunities.filter { $0.status == .interviewing }.count
    }

    private var nextDate: Date? {
        let now = Calendar.current.startOfDay(for: Date())
        return opportunities
            .filter { $0.status != .closed }
            .flatMap { [$0.closingDate, $0.interviewDate].compactMap { $0 } }
            .filter { $0 >= now }
            .min()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: RRSpacing.lg) {
            VStack(alignment: .leading, spacing: RRSpacing.xs) {
                Text("YOUR OPPORTUNITY MAP")
                    .font(.rrCaption)
                    .tracking(0.9)
                    .foregroundStyle(Color.white.opacity(0.78))
                Text("Keep every application grounded")
                    .font(.rrTitle)
                    .foregroundStyle(.white)
                Text("Review the role, see what your evidence proves, and be candid about the gaps.")
                    .font(.rrBody)
                    .foregroundStyle(Color.white.opacity(0.86))
                    .fixedSize(horizontal: false, vertical: true)
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: RRSpacing.sm) {
                    pipelineMetrics
                }
                VStack(spacing: RRSpacing.sm) {
                    pipelineMetrics
                }
            }
        }
        .padding(RRSpacing.lg)
        .background(BrandTheme.heroGradient, in: RoundedRectangle(cornerRadius: RRRadius.hero, style: .continuous))
        .shadow(color: BrandTheme.violet.opacity(0.18), radius: 20, y: 10)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Opportunity summary. \(activeCount) active. \(interviewCount) interviewing. Next date \(accessibleNextDateText).")
    }

    private var nextDateText: String {
        guard let nextDate else { return "—" }
        return nextDate.formatted(.dateTime.day().month(.abbreviated))
    }

    private var accessibleNextDateText: String {
        guard let nextDate else { return "not set" }
        return nextDate.formatted(date: .long, time: .omitted)
    }

    @ViewBuilder
    private var pipelineMetrics: some View {
        PipelineMetric(value: "\(activeCount)", label: "Active")
        PipelineMetric(value: "\(interviewCount)", label: "Interviewing")
        PipelineMetric(value: nextDateText, label: "Next date")
    }
}

private struct PipelineMetric: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: RRSpacing.xxs) {
            Text(value)
                .font(.system(.title3, design: .rounded, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(label)
                .font(.rrCaption)
                .foregroundStyle(Color.white.opacity(0.76))
                .lineLimit(1)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(RRSpacing.sm)
        .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: RRRadius.small, style: .continuous))
    }
}

private struct RoleStatusFilter: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding var selectedStatus: OpportunityStatus?
    let opportunities: [Opportunity]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: RRSpacing.xs) {
                filterButton(title: "All", symbol: "square.grid.2x2.fill", status: nil, count: opportunities.count)
                ForEach(OpportunityStatus.allCases) { status in
                    filterButton(
                        title: status.title,
                        symbol: status.symbol,
                        status: status,
                        count: opportunities.filter { $0.status == status }.count
                    )
                }
            }
            .padding(.horizontal, RRSpacing.md)
        }
        .accessibilityIdentifier("roles.status.filter")
    }

    private func filterButton(
        title: String,
        symbol: String,
        status: OpportunityStatus?,
        count: Int
    ) -> some View {
        let isSelected = selectedStatus == status
        return Button {
            withAnimation(reduceMotion ? nil : .snappy(duration: 0.22)) {
                selectedStatus = status
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: symbol)
                Text(title)
                Text("\(count)")
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background((isSelected ? Color.white : BrandTheme.inkMuted).opacity(0.14), in: Capsule())
            }
            .font(.rrCaption)
            .foregroundStyle(isSelected ? Color.white : BrandTheme.ink)
            .padding(.horizontal, RRSpacing.sm)
            .padding(.vertical, 9)
            .background(isSelected ? BrandTheme.violet : BrandTheme.surface, in: Capsule())
            .overlay {
                Capsule().stroke(BrandTheme.separator.opacity(isSelected ? 0 : 0.75), lineWidth: 0.75)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title), \(count) roles")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct RoleListRow: View {
    let opportunity: Opportunity
    let requirementCount: Int

    var body: some View {
        HStack(alignment: .top, spacing: RRSpacing.md) {
            Image(systemName: opportunity.status.symbol)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(statusColour)
                .frame(width: 42, height: 42)
                .background(statusColour.opacity(0.12), in: RoundedRectangle(cornerRadius: RRRadius.small, style: .continuous))

            VStack(alignment: .leading, spacing: RRSpacing.xs) {
                HStack(alignment: .firstTextBaseline, spacing: RRSpacing.xs) {
                    Text(opportunity.roleTitle.isEmpty ? "Untitled role" : opportunity.roleTitle)
                        .font(.rrHeadline)
                        .foregroundStyle(BrandTheme.ink)
                        .lineLimit(2)
                    Spacer(minLength: RRSpacing.xs)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(BrandTheme.inkMuted)
                }

                if !opportunity.organisation.isEmpty {
                    Text(opportunity.organisation)
                        .font(.rrBody)
                        .foregroundStyle(BrandTheme.inkMuted)
                        .lineLimit(1)
                }

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: RRSpacing.sm) {
                        metadataItems
                    }
                    VStack(alignment: .leading, spacing: RRSpacing.xs) {
                        metadataItems
                    }
                }
                .font(.rrCaption)
                .foregroundStyle(BrandTheme.inkMuted)
            }
        }
        .padding(RRSpacing.md)
        .cardSurface(padding: 0)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
    }

    private var statusColour: Color {
        switch opportunity.status {
        case .saved: BrandTheme.inkMuted
        case .preparing: BrandTheme.violet
        case .applied, .recruiterScreen, .assessment: BrandTheme.violet
        case .interviewing: BrandTheme.amberText
        case .offer: BrandTheme.success
        case .rejected, .withdrawn, .closed: BrandTheme.inkMuted
        }
    }

    private var accessibilitySummary: String {
        var parts = [
            opportunity.roleTitle.isEmpty ? "Untitled role" : opportunity.roleTitle,
            opportunity.organisation,
            opportunity.status.title,
            "\(requirementCount) requirements"
        ].filter { !$0.isEmpty }
        if let dueDate = opportunity.closingDate {
            parts.append("closes \(dueDate.formatted(date: .long, time: .omitted))")
        }
        return parts.joined(separator: ", ")
    }

    @ViewBuilder
    private var metadataItems: some View {
        RoleStatusPill(status: opportunity.status)
        Label("\(requirementCount) \(requirementCount == 1 ? "requirement" : "requirements")", systemImage: "checklist")
        if let dueDate = opportunity.closingDate {
            Label(dueDate.formatted(.dateTime.day().month(.abbreviated)), systemImage: "calendar")
        }
    }
}

private struct RoleStatusPill: View {
    let status: OpportunityStatus

    var body: some View {
        Text(status.title)
            .font(.rrCaption)
            .foregroundStyle(BrandTheme.violet)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(BrandTheme.violetSoft, in: Capsule())
    }
}
