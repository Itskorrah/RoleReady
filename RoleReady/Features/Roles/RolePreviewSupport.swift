#if DEBUG
import SwiftData
import SwiftUI

@MainActor
private enum RolePreviewSupport {
    static let roleID = UUID(uuidString: "2D205A6D-4B90-49BE-B573-95D5BA75A7F0")!

    static func makeContainer(seed: Bool = true) -> ModelContainer {
        let schema = Schema([
            Opportunity.self,
            JobRequirement.self,
            Experience.self
        ])
        let configuration = ModelConfiguration("RoleReadyPreview", schema: schema, isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: [configuration])
        guard seed else { return container }

        let role = Opportunity(
            id: roleID,
            roleTitle: "Senior Data Integration Analyst",
            organisation: "Harbour Health Exchange",
            location: "Sydney · Hybrid",
            sourceText: "Lead reliable data integration delivery across health partners. The successful candidate must demonstrate Python development, automated quality assurance and clear stakeholder communication in a regulated environment.",
            status: .preparing,
            closingDate: Calendar.current.date(byAdding: .day, value: 9, to: Date()),
            interviewDate: Calendar.current.date(byAdding: .day, value: 17, to: Date()),
            notes: "Prepare examples for quality controls, technical trade-offs and partner communication."
        )
        let pythonRequirement = JobRequirement(
            opportunityID: roleID,
            text: "Demonstrated experience developing maintainable Python data-processing workflows.",
            kind: .mustHave,
            keywords: ["Python", "data processing", "maintainable"],
            capabilities: [.technicalProblemSolving, .delivery],
            importance: 3
        )
        let stakeholderRequirement = JobRequirement(
            opportunityID: roleID,
            text: "Communicate delivery risks and technical decisions clearly with non-technical partners.",
            kind: .responsibility,
            keywords: ["stakeholder", "risk", "technical decisions"],
            capabilities: [.stakeholderCommunication, .accountability],
            importance: 2
        )
        let experience = Experience(
            title: "SAS-to-Python workflow migration",
            organisation: "Public Health Analytics",
            occurredAt: Calendar.current.date(byAdding: .month, value: -5, to: Date()) ?? Date(),
            kind: .project,
            situation: "A large SAS workflow was difficult to maintain and extend.",
            task: "Translate the process into Python without changing its outputs.",
            actions: [
                "Mapped the existing business rules into testable processing stages.",
                "Built modular Python and Polars components with schema validation.",
                "Explained validation results and delivery risks to stakeholders."
            ],
            result: "The new workflow produced matching outputs and was easier for the team to support.",
            evidence: "All 133 automated regression tests passed against the legacy outputs.",
            learning: "Early comparison fixtures made technical trade-offs easier to explain.",
            ownership: .owned,
            capabilities: [.technicalProblemSolving, .dataQuality, .stakeholderCommunication, .delivery],
            tools: ["Python", "Polars", "pytest"],
            confidentiality: .privateRecord
        )

        container.mainContext.insert(role)
        container.mainContext.insert(pythonRequirement)
        container.mainContext.insert(stakeholderRequirement)
        container.mainContext.insert(experience)
        try? container.mainContext.save()
        return container
    }

    static func makeAppState() -> AppState {
        let defaults = UserDefaults(suiteName: "roleready.roles.preview.\(UUID().uuidString)")!
        return AppState(defaults: defaults)
    }
}

#Preview("Roles · populated") {
    NavigationStack {
        RoleListView()
    }
    .modelContainer(RolePreviewSupport.makeContainer())
    .environment(AppRouter())
    .environment(RolePreviewSupport.makeAppState())
}

#Preview("Roles · empty") {
    NavigationStack {
        RoleListView()
    }
    .modelContainer(RolePreviewSupport.makeContainer(seed: false))
    .environment(AppRouter())
    .environment(RolePreviewSupport.makeAppState())
}

#Preview("Role editor") {
    RoleEditorView()
        .modelContainer(RolePreviewSupport.makeContainer(seed: false))
        .environment(RolePreviewSupport.makeAppState())
}

#Preview("Role detail") {
    NavigationStack {
        RoleDetailView(opportunityID: RolePreviewSupport.roleID)
    }
    .modelContainer(RolePreviewSupport.makeContainer())
    .environment(AppRouter())
    .environment(RolePreviewSupport.makeAppState())
}

#Preview("Match report") {
    NavigationStack {
        MatchReportView(opportunityID: RolePreviewSupport.roleID)
    }
    .modelContainer(RolePreviewSupport.makeContainer())
    .environment(AppRouter())
    .environment(RolePreviewSupport.makeAppState())
}
#endif
