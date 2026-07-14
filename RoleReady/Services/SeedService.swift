import Foundation
import SwiftData

@MainActor
struct SeedService {
    enum IDs {
        static let profile = UUID(uuidString: "10000000-0000-4000-8000-000000000001")!
        static let sasMigration = UUID(uuidString: "20000000-0000-4000-8000-000000000001")!
        static let parquet = UUID(uuidString: "20000000-0000-4000-8000-000000000002")!
        static let reviewApp = UUID(uuidString: "20000000-0000-4000-8000-000000000003")!
        static let definitionConflict = UUID(uuidString: "20000000-0000-4000-8000-000000000004")!
        static let mappingMistake = UUID(uuidString: "20000000-0000-4000-8000-000000000005")!
        static let gitMentoring = UUID(uuidString: "20000000-0000-4000-8000-000000000006")!
        static let opportunity = UUID(uuidString: "30000000-0000-4000-8000-000000000001")!
        static let answer = UUID(uuidString: "40000000-0000-4000-8000-000000000001")!
        static let careerSource = UUID(uuidString: "50000000-0000-4000-8000-000000000001")!
        static let position = UUID(uuidString: "50000000-0000-4000-8000-000000000002")!
        static let education = UUID(uuidString: "50000000-0000-4000-8000-000000000003")!
        static let pythonSkill = UUID(uuidString: "50000000-0000-4000-8000-000000000004")!
        static let sqlSkill = UUID(uuidString: "50000000-0000-4000-8000-000000000005")!
        static let baselineResume = UUID(uuidString: "50000000-0000-4000-8000-000000000006")!
        static let sourceSpan = UUID(uuidString: "50000000-0000-4000-8000-000000000007")!
        static let savedActivity = UUID(uuidString: "50000000-0000-4000-8000-000000000008")!
        static let followUpReminder = UUID(uuidString: "50000000-0000-4000-8000-000000000009")!
    }

    func installSampleWorkspace(in context: ModelContext) throws {
        let existing = try context.fetch(FetchDescriptor<CareerProfile>())
        if let profile = existing.first(where: { $0.id == IDs.profile }) {
            try installConnectedCareerSample(profile: profile, in: context)
            try context.save()
            return
        }

        let profile = CareerProfile(
            id: IDs.profile,
            name: "Maya Chen",
            headline: "Senior Data Analyst",
            professionalSummary: "Data specialist focused on reliable pipelines, modernising legacy workflows, and making complex quality decisions clear to technical and business stakeholders.",
            currentOrganisation: "Harbour Health Analytics",
            targetRoles: ["Senior Data Engineer", "Analytics Engineer"],
            skills: ["Python", "Polars", "SQL", "SAS", "Azure Data Factory", "Git", "pytest", "Data quality", "Stakeholder workshops"],
            careerGoal: "Move into a hands-on engineering role with broader technical ownership.",
            isSample: true,
            createdAt: date(2026, 7, 1)
        )

        let experiences = sampleExperiences()
        let opportunity = Opportunity(
            id: IDs.opportunity,
            roleTitle: "Senior Data Engineer",
            organisation: "CobaltGrid",
            location: "Sydney, NSW · Hybrid",
            sourceText: sampleJobDescription,
            status: .interviewing,
            closingDate: futureDate(days: 7, hour: 17),
            interviewDate: futureDate(days: 14, hour: 10, minute: 30),
            notes: "Panel interview with the Head of Data Platform, an analytics engineering lead, and a delivery partner.",
            isSample: true,
            createdAt: Date()
        )
        let requirements = sampleRequirements(opportunityID: opportunity.id)

        context.insert(profile)
        experiences.forEach(context.insert)
        context.insert(opportunity)
        requirements.forEach(context.insert)

        if let source = experiences.first(where: { $0.id == IDs.sasMigration }),
           let draft = try? GroundedAnswerEngine().generate(
               question: "Tell us about a time you modernised a difficult data process without compromising quality.",
               from: source,
               format: .sixtySeconds,
               audience: .technicalPanel,
               tone: .natural
           ) {
            context.insert(GeneratedAnswer(
                id: IDs.answer,
                question: "Tell us about a time you modernised a difficult data process without compromising quality.",
                experienceID: source.id,
                opportunityID: opportunity.id,
                format: .sixtySeconds,
                audience: .technicalPanel,
                tone: .natural,
                content: draft.content,
                quickCues: draft.quickCues,
                sourceFields: draft.claims.map(\.sourceField),
                sourceClaims: draft.claims.map {
                    StoredAnswerClaim(
                        sourceField: $0.sourceField,
                        text: $0.text,
                        sourceText: $0.sourceText,
                        origin: $0.origin,
                        isSupported: $0.isSupported
                    )
                },
                followUps: draft.followUps,
                isFactConfirmed: true,
                isSample: true,
                sourceExperienceUpdatedAt: source.updatedAt,
                sourceOpportunityUpdatedAt: opportunity.contentUpdatedAt,
                createdAt: date(2026, 7, 10)
            ))
        }
        try installConnectedCareerSample(profile: profile, in: context)
        try context.save()
    }

    func createBlankWorkspace(in context: ModelContext) throws {
        guard try context.fetch(FetchDescriptor<CareerProfile>()).isEmpty else { return }
        context.insert(CareerProfile(
            name: "",
            headline: "",
            professionalSummary: "",
            currentOrganisation: "",
            targetRoles: [],
            skills: [],
            careerGoal: ""
        ))
        try context.save()
    }

    func removeSampleWorkspace(from context: ModelContext) throws {
        let profiles = try context.fetch(FetchDescriptor<CareerProfile>())
        let experiences = try context.fetch(FetchDescriptor<Experience>())
        let opportunities = try context.fetch(FetchDescriptor<Opportunity>())
        let requirements = try context.fetch(FetchDescriptor<JobRequirement>())
        let answers = try context.fetch(FetchDescriptor<GeneratedAnswer>())
        let sessions = try context.fetch(FetchDescriptor<PracticeSession>())
        let reflections = try context.fetch(FetchDescriptor<InterviewReflection>())
        let sources = try context.fetch(FetchDescriptor<CareerSource>())
        let spans = try context.fetch(FetchDescriptor<CareerSourceSpan>())
        let positions = try context.fetch(FetchDescriptor<CareerPosition>())
        let education = try context.fetch(FetchDescriptor<CareerEducation>())
        let certifications = try context.fetch(FetchDescriptor<CareerCertification>())
        let skills = try context.fetch(FetchDescriptor<CareerSkill>())
        let resumes = try context.fetch(FetchDescriptor<ResumeVersion>())
        let coverLetters = try context.fetch(FetchDescriptor<CoverLetter>())
        let activities = try context.fetch(FetchDescriptor<ApplicationActivity>())
        let reminders = try context.fetch(FetchDescriptor<CareerReminder>())
        let sampleExperienceIDs = Set(experiences.filter(\.isSample).map(\.id))
        let sampleOpportunityIDs = Set(opportunities.filter(\.isSample).map(\.id))
        let derivedAnswerIDs = Set(answers.filter {
            $0.isSample
                || sampleExperienceIDs.contains($0.experienceID)
                || $0.opportunityID.map(sampleOpportunityIDs.contains) == true
        }.map(\.id))

        sessions.filter { derivedAnswerIDs.contains($0.answerID) }.forEach(context.delete)
        reflections.filter { sampleOpportunityIDs.contains($0.opportunityID) }.forEach(context.delete)
        answers.filter { derivedAnswerIDs.contains($0.id) }.forEach(context.delete)
        requirements.filter { sampleOpportunityIDs.contains($0.opportunityID) }.forEach(context.delete)
        profiles.filter(\.isSample).forEach(context.delete)
        experiences.filter(\.isSample).forEach(context.delete)
        opportunities.filter(\.isSample).forEach(context.delete)
        sources.filter(\.isSample).forEach(context.delete)
        spans.filter { span in
            sources.contains(where: { $0.isSample && $0.id == span.sourceID })
        }.forEach(context.delete)
        positions.filter(\.isSample).forEach(context.delete)
        education.filter(\.isSample).forEach(context.delete)
        certifications.filter(\.isSample).forEach(context.delete)
        skills.filter(\.isSample).forEach(context.delete)
        resumes.filter(\.isSample).forEach(context.delete)
        coverLetters.filter(\.isSample).forEach(context.delete)
        activities.filter(\.isSample).forEach(context.delete)
        reminders.filter(\.isSample).forEach(context.delete)
        try context.save()
    }

    func deleteAll(from context: ModelContext) throws {
        try context.delete(model: CareerReminder.self)
        try context.delete(model: ApplicationActivity.self)
        try context.delete(model: CoverLetter.self)
        try context.delete(model: ResumeVersion.self)
        try context.delete(model: CareerSourceSpan.self)
        try context.delete(model: CareerSkill.self)
        try context.delete(model: CareerCertification.self)
        try context.delete(model: CareerEducation.self)
        try context.delete(model: CareerPosition.self)
        try context.delete(model: CareerSource.self)
        try context.delete(model: InterviewReflection.self)
        try context.delete(model: PracticeSession.self)
        try context.delete(model: GeneratedAnswer.self)
        try context.delete(model: JobRequirement.self)
        try context.delete(model: Opportunity.self)
        try context.delete(model: Experience.self)
        try context.delete(model: CareerProfile.self)
        try context.save()
    }

    private func sampleExperiences() -> [Experience] {
        [
            Experience(
                id: IDs.sasMigration,
                title: "Rebuilt a legacy SAS workflow in Python",
                organisation: "Harbour Health Analytics",
                occurredAt: date(2026, 3, 18),
                kind: .project,
                situation: "A large SAS workflow carried critical reporting rules but had become difficult to maintain and extend.",
                task: "I led the technical translation into Python while preserving the approved business rules and output quality.",
                actions: [
                    "I mapped the SAS workflow into discrete processing stages and documented the dependencies before changing code.",
                    "I chose modular Polars components so the large transformations stayed readable and could be tested independently.",
                    "I added schema checks and a regression suite that compared each output with the approved SAS baseline."
                ],
                result: "The Python workflow matched the approved outputs and all 133 regression tests passed.",
                evidence: "The comparison report, test run, and handover review were approved by the reporting lead.",
                learning: "I learnt to make parity criteria explicit before modernising a process, rather than treating testing as a final step.",
                ownership: .led,
                capabilities: [.technicalProblemSolving, .processImprovement, .dataQuality, .delivery],
                tools: ["Python", "Polars", "SAS", "pytest", "Git"],
                confidentiality: .confidential,
                isSample: true,
                useCount: 5,
                createdAt: date(2026, 4, 2)
            ),
            Experience(
                id: IDs.parquet,
                title: "Stabilised monthly Parquet processing",
                organisation: "Harbour Health Analytics",
                occurredAt: date(2026, 1, 22),
                kind: .problemSolved,
                situation: "A monthly pipeline began exhausting memory while processing a 48 GB partitioned Parquet dataset.",
                task: "I owned the diagnosis and needed to restore reliable completion without changing the overnight delivery window.",
                actions: [
                    "I reproduced the failure with memory logging and traced the peak to eager reads across unused partitions.",
                    "I replaced the eager path with lazy scanning and partition pruning because the downstream checks required only a subset of columns.",
                    "I added a bounded-memory validation step and monitored the next scheduled runs."
                ],
                result: "The workflow completed inside the existing overnight window for the next six monthly runs.",
                evidence: "Operations logs recorded six consecutive successful completions with no memory alert.",
                learning: "I now include representative data-volume tests before approving pipeline changes.",
                ownership: .owned,
                capabilities: [.technicalProblemSolving, .dataQuality, .delivery, .planning],
                tools: ["Python", "Polars", "Parquet", "Azure Data Factory"],
                confidentiality: .privateRecord,
                isSample: true,
                useCount: 3,
                createdAt: date(2026, 2, 1)
            ),
            Experience(
                id: IDs.reviewApp,
                title: "Built an ingestion review app",
                organisation: "Harbour Health Analytics",
                occurredAt: date(2025, 11, 8),
                kind: .achievement,
                situation: "A five-person operations team reviewed ingestion exceptions through emailed spreadsheets, which regularly created version conflicts.",
                task: "I built a small internal review workflow to give the team one place to triage and record decisions.",
                actions: [
                    "I observed the existing review process and mapped the decisions that needed an audit trail.",
                    "I prototyped the queue with two pilot users and changed the layout after their feedback.",
                    "I documented the handover and created a fallback export for operational continuity."
                ],
                result: "Pilot users reported fewer version-conflict issues and chose the app for the next review cycle.",
                evidence: "The pilot feedback is recorded, but the reduction in conflicts was not measured.",
                learning: "I would agree a baseline measure before the next workflow pilot.",
                ownership: .owned,
                capabilities: [.processImprovement, .customerFocus, .stakeholderCommunication],
                tools: ["Swift", "Python", "SQLite"],
                confidentiality: .confidential,
                isSample: true,
                useCount: 1,
                createdAt: date(2025, 11, 20)
            ),
            Experience(
                id: IDs.definitionConflict,
                title: "Resolved a reporting-definition conflict",
                organisation: "Harbour Health Analytics",
                occurredAt: date(2025, 8, 14),
                kind: .conflict,
                situation: "Clinical reporting and engineering were using different definitions for three measures in an upcoming release.",
                task: "I was responsible for clarifying the disagreement before the release rules were finalised.",
                actions: [
                    "I interviewed each group separately to separate policy concerns from implementation details.",
                    "I facilitated a workshop that compared the three disputed definitions against the reporting purpose and source data.",
                    "I recorded the agreed definitions, owners, and edge cases and asked both leads for written sign-off."
                ],
                result: "Both leads approved the definitions before release, and engineering implemented one agreed rule set.",
                evidence: "The signed decision log and release notes captured all three definitions.",
                learning: "I learnt that a shared example dataset resolves abstract definition debates faster than more discussion alone.",
                ownership: .owned,
                capabilities: [.stakeholderCommunication, .teamwork, .dataQuality, .delivery],
                tools: ["Requirements workshops", "Decision log", "SQL"],
                confidentiality: .confidential,
                isSample: true,
                useCount: 4,
                createdAt: date(2025, 8, 20)
            ),
            Experience(
                id: IDs.mappingMistake,
                title: "Caught and corrected a production mapping mistake",
                organisation: "Harbour Health Analytics",
                occurredAt: date(2025, 5, 30),
                kind: .mistakeAndLearning,
                situation: "I introduced an incorrect category mapping while updating a production reporting rule.",
                task: "I needed to correct the issue, confirm its impact, and prevent the same mistake from recurring.",
                actions: [
                    "I raised the issue as soon as validation exposed the mismatch and paused the planned external release.",
                    "I traced the change, corrected the mapping, and reran the complete regression pack.",
                    "I added a targeted regression test and updated the peer-review checklist with a mapping-table comparison."
                ],
                result: "The error was corrected before external release and the approved output passed the regression pack.",
                evidence: "The incident note, test result, and updated review checklist were accepted by the release owner.",
                learning: "I learnt to treat reference-data changes as code changes with explicit diff review.",
                ownership: .owned,
                capabilities: [.accountability, .learning, .dataQuality, .technicalProblemSolving],
                tools: ["SQL", "pytest", "Git"],
                confidentiality: .confidential,
                isSample: true,
                useCount: 2,
                createdAt: date(2025, 6, 2)
            ),
            Experience(
                id: IDs.gitMentoring,
                title: "Supported graduate adoption of Git",
                organisation: "Harbour Health Analytics",
                occurredAt: date(2025, 3, 7),
                kind: .leadership,
                situation: "Two graduate analysts were joining a team that had recently moved shared analytics code into Git.",
                task: "I supported the wider adoption effort by helping the graduates build confidence with the team workflow.",
                actions: [
                    "I created a safe branching exercise using a disposable repository and examples from our review conventions.",
                    "I paired with each graduate on their first pull request and explained why the review comments mattered.",
                    "I shared their recurring questions with the colleague who led the wider rollout."
                ],
                result: "Both graduates completed their next pull requests without needing the workflow corrected.",
                evidence: "The merged pull requests and review history confirm the outcome.",
                learning: "I learnt that a low-risk practice repository makes unfamiliar version-control concepts much easier to discuss.",
                ownership: .supported,
                capabilities: [.leadership, .teamwork, .learning],
                tools: ["Git", "GitHub", "Pull requests"],
                confidentiality: .privateRecord,
                isSample: true,
                useCount: 1,
                createdAt: date(2025, 3, 12)
            )
        ]
    }

    private func installConnectedCareerSample(profile: CareerProfile, in context: ModelContext) throws {
        profile.email = profile.email.isEmpty ? "maya.chen@example.com" : profile.email
        profile.location = profile.location.isEmpty ? "Sydney, NSW" : profile.location
        profile.linkedIn = profile.linkedIn.isEmpty ? "linkedin.com/in/maya-chen" : profile.linkedIn

        let sourceText = """
        Maya Chen
        Senior Data Analyst
        Harbour Health Analytics | Sydney, NSW | 2021 – Present
        • Rebuilt a critical SAS reporting workflow in Python and Polars while preserving approved business rules.
        • Added schema checks and 133 regression tests against the approved SAS baseline.
        • Stabilised 48 GB Parquet processing through lazy scanning and partition pruning.
        Skills: Python, Polars, SQL, SAS, Azure Data Factory, Git, pytest
        Bachelor of Information Systems | University of Technology Sydney | 2017 – 2020
        """
        let sources = try context.fetch(FetchDescriptor<CareerSource>())
        let source: CareerSource
        if let existing = sources.first(where: { $0.id == IDs.careerSource }) {
            source = existing
        } else {
            source = CareerSource(
                id: IDs.careerSource,
                kind: .resume,
                name: "Maya Chen technical résumé",
                filename: "maya-chen-resume.pdf",
                contentType: "application/pdf",
                rawText: sourceText,
                fingerprint: "sample-maya-resume-v1",
                confidentiality: .privateRecord,
                isSample: true,
                importedAt: date(2026, 7, 8),
                updatedAt: date(2026, 7, 8)
            )
            context.insert(source)
        }

        let positions = try context.fetch(FetchDescriptor<CareerPosition>())
        let position: CareerPosition
        if let existing = positions.first(where: { $0.id == IDs.position }) {
            position = existing
        } else {
            let excerpt = "Senior Data Analyst\nHarbour Health Analytics | Sydney, NSW | 2021 – Present"
            position = CareerPosition(
                id: IDs.position,
                sourceID: source.id,
                title: "Senior Data Analyst",
                organisation: "Harbour Health Analytics",
                location: "Sydney, NSW",
                startDate: date(2021, 2, 1),
                isCurrent: true,
                summary: "Modernises and protects business-critical analytics workflows.",
                bullets: [
                    "Rebuilt a critical SAS reporting workflow in Python and Polars while preserving approved business rules.",
                    "Added schema checks and 133 regression tests against the approved SAS baseline.",
                    "Stabilised 48 GB Parquet processing through lazy scanning and partition pruning."
                ],
                skills: ["Python", "Polars", "SQL", "SAS", "Azure Data Factory", "Git", "pytest"],
                sourceExcerpt: excerpt,
                verificationStatus: .approved,
                confidentiality: .privateRecord,
                approvedAt: date(2026, 7, 8),
                isSample: true,
                createdAt: date(2026, 7, 8),
                updatedAt: date(2026, 7, 8)
            )
            context.insert(position)
        }

        let educationRecords = try context.fetch(FetchDescriptor<CareerEducation>())
        let education: CareerEducation
        if let existing = educationRecords.first(where: { $0.id == IDs.education }) {
            education = existing
        } else {
            education = CareerEducation(
                id: IDs.education,
                sourceID: source.id,
                institution: "University of Technology Sydney",
                qualification: "Bachelor of Information Systems",
                startDate: date(2017, 2, 1),
                endDate: date(2020, 11, 1),
                sourceExcerpt: "Bachelor of Information Systems | University of Technology Sydney | 2017 – 2020",
                verificationStatus: .approved,
                isSample: true,
                createdAt: date(2026, 7, 8),
                updatedAt: date(2026, 7, 8)
            )
            context.insert(education)
        }

        let existingSkills = try context.fetch(FetchDescriptor<CareerSkill>())
        let skillDefinitions: [(UUID, String, String, Double)] = [
            (IDs.pythonSkill, "Python", "Languages", 6),
            (IDs.sqlSkill, "SQL", "Languages", 7)
        ]
        var careerSkills: [CareerSkill] = []
        for definition in skillDefinitions {
            if let existing = existingSkills.first(where: { $0.id == definition.0 }) {
                careerSkills.append(existing)
                continue
            }
            let skill = CareerSkill(
                id: definition.0,
                sourceID: source.id,
                name: definition.1,
                category: definition.2,
                level: .advanced,
                yearsExperience: definition.3,
                lastUsedAt: Date(),
                sourceExcerpt: "Skills: Python, Polars, SQL, SAS, Azure Data Factory, Git, pytest",
                verificationStatus: .approved,
                isSample: true,
                createdAt: date(2026, 7, 8),
                updatedAt: date(2026, 7, 8)
            )
            context.insert(skill)
            careerSkills.append(skill)
        }

        let spans = try context.fetch(FetchDescriptor<CareerSourceSpan>())
        if !spans.contains(where: { $0.id == IDs.sourceSpan }),
           let range = sourceText.range(of: position.title) {
            context.insert(CareerSourceSpan(
                id: IDs.sourceSpan,
                sourceID: source.id,
                entityID: position.id,
                entityType: "careerPosition",
                fieldPath: "title",
                startOffset: sourceText.distance(from: sourceText.startIndex, to: range.lowerBound),
                endOffset: sourceText.distance(from: sourceText.startIndex, to: range.upperBound),
                excerpt: position.title,
                confidence: 1,
                isApproved: true,
                createdAt: date(2026, 7, 8)
            ))
        }

        let resumes = try context.fetch(FetchDescriptor<ResumeVersion>())
        if !resumes.contains(where: { $0.id == IDs.baselineResume }) {
            let document = ResumeDocumentFactory().makeDocument(
                profile: profile,
                positions: [position],
                education: [education],
                certifications: [],
                skills: careerSkills
            )
            context.insert(ResumeVersion(
                id: IDs.baselineResume,
                sourceID: source.id,
                name: "Maya Chen · Technical baseline",
                targetRole: "Senior Data Engineer",
                template: .technical,
                status: .ready,
                document: document,
                isBaseline: true,
                isSample: true,
                createdAt: date(2026, 7, 8),
                updatedAt: date(2026, 7, 8)
            ))
        }

        let activities = try context.fetch(FetchDescriptor<ApplicationActivity>())
        if !activities.contains(where: { $0.id == IDs.savedActivity }) {
            context.insert(ApplicationActivity(
                id: IDs.savedActivity,
                opportunityID: IDs.opportunity,
                kind: .interview,
                title: "Panel interview scheduled",
                notes: "Review the role-specific prep deck and technical examples.",
                occurredAt: date(2026, 7, 12),
                isSample: true,
                createdAt: date(2026, 7, 12)
            ))
        }

        let reminders = try context.fetch(FetchDescriptor<CareerReminder>())
        if !reminders.contains(where: { $0.id == IDs.followUpReminder }) {
            context.insert(CareerReminder(
                id: IDs.followUpReminder,
                opportunityID: IDs.opportunity,
                kind: .interview,
                title: "Prepare for the CobaltGrid interview",
                notes: "Practise the grounded migration and data-quality examples.",
                dueAt: futureDate(days: 13, hour: 17),
                isSample: true,
                createdAt: date(2026, 7, 12),
                updatedAt: date(2026, 7, 12)
            ))
        }
    }

    private func sampleRequirements(opportunityID: UUID) -> [JobRequirement] {
        [
            JobRequirement(opportunityID: opportunityID, text: "Build and maintain reliable Python data pipelines for business-critical workloads.", kind: .mustHave, keywords: ["Python", "data pipelines", "reliable"], capabilities: [.technicalProblemSolving, .delivery, .dataQuality], importance: 3),
            JobRequirement(opportunityID: opportunityID, text: "Design efficient processing for large columnar datasets using Parquet or equivalent formats.", kind: .mustHave, keywords: ["large datasets", "Parquet", "performance"], capabilities: [.technicalProblemSolving, .processImprovement], importance: 3),
            JobRequirement(opportunityID: opportunityID, text: "Use automated testing and data-quality controls to protect production outputs.", kind: .mustHave, keywords: ["automated testing", "data quality", "production"], capabilities: [.dataQuality, .accountability], importance: 3),
            JobRequirement(opportunityID: opportunityID, text: "Communicate technical decisions clearly with engineering and business stakeholders.", kind: .responsibility, keywords: ["technical decisions", "business stakeholders"], capabilities: [.stakeholderCommunication, .teamwork], importance: 2),
            JobRequirement(opportunityID: opportunityID, text: "Mentor analysts and engineers through practical feedback and pairing.", kind: .responsibility, keywords: ["mentor", "feedback", "pairing"], capabilities: [.leadership, .learning], importance: 2),
            JobRequirement(opportunityID: opportunityID, text: "Experience orchestrating production workloads in a cloud platform.", kind: .signal, keywords: ["cloud", "orchestration", "production"], capabilities: [.delivery, .technicalProblemSolving], importance: 2)
        ]
    }

    private var sampleJobDescription: String {
        """
        Senior Data Engineer
        CobaltGrid — Sydney, NSW (Hybrid)

        About the role
        Join a small data platform team modernising operational analytics for critical infrastructure. You will own reliable batch pipelines, partner with analysts and business leaders, and raise engineering quality across the team.

        Essential requirements
        • Build and maintain reliable Python data pipelines for business-critical workloads.
        • Design efficient processing for large columnar datasets using Parquet or equivalent formats.
        • Use automated testing and data-quality controls to protect production outputs.
        • Communicate technical decisions clearly with engineering and business stakeholders.

        Responsibilities
        • Mentor analysts and engineers through practical feedback and pairing.
        • Contribute to incident reviews, documentation, and sustainable delivery practices.

        Desirable
        • Experience orchestrating production workloads in a cloud platform.
        • Familiarity with Azure Data Factory, GitHub Actions, or comparable tooling.
        """
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 9, minute: Int = 0) -> Date {
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = TimeZone(identifier: "Australia/Sydney")
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        return components.date ?? Date(timeIntervalSince1970: 0)
    }

    private func futureDate(days: Int, hour: Int, minute: Int = 0) -> Date {
        let calendar = Calendar(identifier: .gregorian)
        let target = calendar.date(byAdding: .day, value: days, to: Date()) ?? Date()
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: target) ?? target
    }
}
