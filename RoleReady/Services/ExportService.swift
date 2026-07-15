import Foundation
import SwiftData

struct RoleReadyExport: Codable {
    static let formatIdentifier = "com.roleready.export"
    static let formatVersion = 3

    let identifier: String
    let version: Int
    let createdAt: Date
    let includesConfidential: Bool
    let profiles: [ProfileDTO]
    let experiences: [ExperienceDTO]
    let opportunities: [OpportunityDTO]
    let requirements: [RequirementDTO]
    let answers: [AnswerDTO]
    let practiceSessions: [PracticeSessionDTO]
    let reflections: [ReflectionDTO]
    let careerSources: [CareerSourceDTO]
    let sourceSpans: [SourceSpanDTO]
    let positions: [PositionDTO]
    let education: [EducationDTO]
    let certifications: [CertificationDTO]
    let careerSkills: [CareerSkillDTO]
    let resumes: [ResumeDTO]
    let coverLetters: [CoverLetterDTO]
    let activities: [ActivityDTO]
    let reminders: [ReminderDTO]

    struct ProfileDTO: Codable {
        let id: UUID
        let name: String
        let email: String?
        let phone: String?
        let location: String?
        let linkedIn: String?
        let portfolio: String?
        let headline: String
        let professionalSummary: String
        let currentOrganisation: String
        let targetRoles: [String]
        let skills: [String]
        let careerGoal: String
        let sourceID: UUID?
        let verificationStatus: String?
        let confidentiality: String?
        let isSample: Bool?
        let createdAt: Date?
        let updatedAt: Date?
    }

    struct ExperienceDTO: Codable {
        let id: UUID
        let title: String
        let organisation: String
        let occurredAt: Date
        let kind: String
        let situation: String
        let task: String
        let actions: [String]
        let result: String
        let evidence: String
        let learning: String
        let ownership: String
        let capabilities: [String]
        let tools: [String]
        let confidentiality: String
        let sourceID: UUID?
        let sourceExcerpt: String?
        let verificationStatus: String?
        let isApprovedForMatching: Bool?
        let isSample: Bool?
        let useCount: Int?
        let createdAt: Date?
        let updatedAt: Date?
    }

    struct OpportunityDTO: Codable {
        let id: UUID
        let roleTitle: String
        let organisation: String
        let location: String
        let jobURL: String?
        let sourceName: String?
        let sourceText: String
        let status: String
        let closingDate: Date?
        let savedAt: Date?
        let appliedAt: Date?
        let followUpAt: Date?
        let assessmentDate: Date?
        let interviewDate: Date?
        let salaryRange: String?
        let workArrangement: String?
        let contactName: String?
        let contactDetails: String?
        let nextAction: String?
        let notes: String
        let contentUpdatedAt: Date
        let isSample: Bool?
        let createdAt: Date?
        let updatedAt: Date?
    }

    struct RequirementDTO: Codable {
        let id: UUID
        let opportunityID: UUID
        let text: String
        let kind: String
        let keywords: [String]
        let capabilities: [String]
        let importance: Int
        let isConfirmed: Bool?
        let createdAt: Date?
    }

    struct AnswerDTO: Codable {
        let id: UUID
        let question: String
        let experienceID: UUID
        let opportunityID: UUID?
        let format: String
        let audience: String
        let tone: String
        let content: String
        let quickCues: [String]
        let sourceFields: [String]
        let sourceClaims: [StoredAnswerClaim]
        let followUps: [String]
        let isFactConfirmed: Bool
        let sourceExperienceUpdatedAt: Date
        let sourceOpportunityUpdatedAt: Date?
        let createdAt: Date
        let isUserEdited: Bool?
        let isSample: Bool?
        let updatedAt: Date?
    }

    struct ReflectionDTO: Codable {
        let id: UUID
        let opportunityID: UUID
        let questions: [String]
        let experienceIDs: [UUID]
        let strongestMoment: String
        let difficultMoment: String
        let feedback: String
        let nextImprovement: String
        let createdAt: Date
        let updatedAt: Date?
    }

    struct PracticeSessionDTO: Codable {
        let id: UUID
        let answerID: UUID
        let experienceID: UUID?
        let opportunityID: UUID?
        let question: String
        let durationSeconds: Int
        let confidence: Int
        let notes: String
        let practisedAt: Date
    }

    struct CareerSourceDTO: Codable {
        let id: UUID
        let kind: String
        let name: String
        let filename: String
        let contentType: String
        let rawText: String
        let fingerprint: String
        let confidentiality: String
        let isSample: Bool
        let importedAt: Date
        let updatedAt: Date
    }

    struct SourceSpanDTO: Codable {
        let id: UUID
        let sourceID: UUID
        let entityID: UUID
        let entityType: String
        let fieldPath: String
        let startOffset: Int
        let endOffset: Int
        let excerpt: String
        let confidence: Double
        let isApproved: Bool
        let createdAt: Date
    }

    struct PositionDTO: Codable {
        let id: UUID
        let sourceID: UUID?
        let title: String
        let organisation: String
        let location: String
        let employmentType: String
        let startDate: Date?
        let endDate: Date?
        let isCurrent: Bool
        let summary: String
        let bullets: [String]
        let skills: [String]
        let sourceExcerpt: String
        let verificationStatus: String
        let confidentiality: String
        let approvedAt: Date?
        let isSample: Bool
        let createdAt: Date
        let updatedAt: Date
    }

    struct EducationDTO: Codable {
        let id: UUID
        let sourceID: UUID?
        let institution: String
        let qualification: String
        let fieldOfStudy: String
        let location: String
        let startDate: Date?
        let endDate: Date?
        let details: [String]
        let sourceExcerpt: String
        let verificationStatus: String
        let confidentiality: String
        let isSample: Bool
        let createdAt: Date
        let updatedAt: Date
    }

    struct CertificationDTO: Codable {
        let id: UUID
        let sourceID: UUID?
        let name: String
        let issuer: String
        let issuedAt: Date?
        let expiresAt: Date?
        let credentialID: String
        let credentialURL: String
        let sourceExcerpt: String
        let verificationStatus: String
        let confidentiality: String
        let isSample: Bool
        let createdAt: Date
        let updatedAt: Date
    }

    struct CareerSkillDTO: Codable {
        let id: UUID
        let sourceID: UUID?
        let name: String
        let category: String
        let level: String
        let yearsExperience: Double
        let lastUsedAt: Date?
        let sourceExcerpt: String
        let verificationStatus: String
        let confidentiality: String
        let isSample: Bool
        let createdAt: Date
        let updatedAt: Date
    }

    struct ResumeDTO: Codable {
        let id: UUID
        let parentVersionID: UUID?
        let sourceID: UUID?
        let opportunityID: UUID?
        let name: String
        let targetRole: String
        let targetOrganisation: String
        let template: String
        let status: String
        let document: ResumeDocument
        let tailoringReport: TailoringReport
        let isBaseline: Bool
        let isSample: Bool
        let createdAt: Date
        let updatedAt: Date
        let lastExportedAt: Date?
    }

    struct CoverLetterDTO: Codable {
        let id: UUID
        let opportunityID: UUID
        let resumeVersionID: UUID?
        let title: String
        let body: String
        let grounding: CoverLetterGrounding
        let generator: String
        let isUserEdited: Bool
        let validationWarnings: [String]
        let sourceEntityIDs: [UUID]
        let status: String
        let isSample: Bool
        let createdAt: Date
        let updatedAt: Date
    }

    struct ActivityDTO: Codable {
        let id: UUID
        let opportunityID: UUID
        let kind: String
        let title: String
        let notes: String
        let occurredAt: Date
        let isSample: Bool
        let createdAt: Date
    }

    struct ReminderDTO: Codable {
        let id: UUID
        let opportunityID: UUID?
        let activityID: UUID?
        let kind: String
        let title: String
        let notes: String
        let dueAt: Date
        let notificationIdentifier: String
        let isCompleted: Bool
        let completedAt: Date?
        let isSample: Bool
        let createdAt: Date
        let updatedAt: Date
    }

    init(
        identifier: String,
        version: Int,
        createdAt: Date,
        includesConfidential: Bool,
        profiles: [ProfileDTO],
        experiences: [ExperienceDTO],
        opportunities: [OpportunityDTO],
        requirements: [RequirementDTO],
        answers: [AnswerDTO],
        practiceSessions: [PracticeSessionDTO],
        reflections: [ReflectionDTO],
        careerSources: [CareerSourceDTO] = [],
        sourceSpans: [SourceSpanDTO] = [],
        positions: [PositionDTO] = [],
        education: [EducationDTO] = [],
        certifications: [CertificationDTO] = [],
        careerSkills: [CareerSkillDTO] = [],
        resumes: [ResumeDTO] = [],
        coverLetters: [CoverLetterDTO] = [],
        activities: [ActivityDTO] = [],
        reminders: [ReminderDTO] = []
    ) {
        self.identifier = identifier
        self.version = version
        self.createdAt = createdAt
        self.includesConfidential = includesConfidential
        self.profiles = profiles
        self.experiences = experiences
        self.opportunities = opportunities
        self.requirements = requirements
        self.answers = answers
        self.practiceSessions = practiceSessions
        self.reflections = reflections
        self.careerSources = careerSources
        self.sourceSpans = sourceSpans
        self.positions = positions
        self.education = education
        self.certifications = certifications
        self.careerSkills = careerSkills
        self.resumes = resumes
        self.coverLetters = coverLetters
        self.activities = activities
        self.reminders = reminders
    }

    private enum CodingKeys: String, CodingKey {
        case identifier
        case version
        case createdAt
        case includesConfidential
        case profiles
        case experiences
        case opportunities
        case requirements
        case answers
        case practiceSessions
        case reflections
        case careerSources
        case sourceSpans
        case positions
        case education
        case certifications
        case careerSkills
        case resumes
        case coverLetters
        case activities
        case reminders
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        identifier = try container.decode(String.self, forKey: .identifier)
        version = try container.decode(Int.self, forKey: .version)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        includesConfidential = try container.decodeIfPresent(Bool.self, forKey: .includesConfidential) ?? false
        profiles = try container.decodeIfPresent([ProfileDTO].self, forKey: .profiles) ?? []
        experiences = try container.decodeIfPresent([ExperienceDTO].self, forKey: .experiences) ?? []
        opportunities = try container.decodeIfPresent([OpportunityDTO].self, forKey: .opportunities) ?? []
        requirements = try container.decodeIfPresent([RequirementDTO].self, forKey: .requirements) ?? []
        answers = try container.decodeIfPresent([AnswerDTO].self, forKey: .answers) ?? []
        practiceSessions = try container.decodeIfPresent([PracticeSessionDTO].self, forKey: .practiceSessions) ?? []
        reflections = try container.decodeIfPresent([ReflectionDTO].self, forKey: .reflections) ?? []
        careerSources = try container.decodeIfPresent([CareerSourceDTO].self, forKey: .careerSources) ?? []
        sourceSpans = try container.decodeIfPresent([SourceSpanDTO].self, forKey: .sourceSpans) ?? []
        positions = try container.decodeIfPresent([PositionDTO].self, forKey: .positions) ?? []
        education = try container.decodeIfPresent([EducationDTO].self, forKey: .education) ?? []
        certifications = try container.decodeIfPresent([CertificationDTO].self, forKey: .certifications) ?? []
        careerSkills = try container.decodeIfPresent([CareerSkillDTO].self, forKey: .careerSkills) ?? []
        resumes = try container.decodeIfPresent([ResumeDTO].self, forKey: .resumes) ?? []
        coverLetters = try container.decodeIfPresent([CoverLetterDTO].self, forKey: .coverLetters) ?? []
        activities = try container.decodeIfPresent([ActivityDTO].self, forKey: .activities) ?? []
        reminders = try container.decodeIfPresent([ReminderDTO].self, forKey: .reminders) ?? []
    }
}

@MainActor
struct ExportService {
    func makeExport(in context: ModelContext, includeConfidential: Bool) throws -> Data {
        let profiles = try context.fetch(FetchDescriptor<CareerProfile>())
        let allExperiences = try context.fetch(FetchDescriptor<Experience>())
        let experiences = allExperiences.filter { includeConfidential || $0.confidentiality < .confidential }
        let allowedExperienceIDs = Set(experiences.map(\.id))
        let opportunities = try context.fetch(FetchDescriptor<Opportunity>())
        let requirements = try context.fetch(FetchDescriptor<JobRequirement>())
        let answers = try context.fetch(FetchDescriptor<GeneratedAnswer>()).filter { allowedExperienceIDs.contains($0.experienceID) }
        let allowedAnswerIDs = Set(answers.map(\.id))
        let practiceSessions = try context.fetch(FetchDescriptor<PracticeSession>())
            .filter { allowedAnswerIDs.contains($0.answerID) }
        let reflections = try context.fetch(FetchDescriptor<InterviewReflection>())
            .filter { _ in includeConfidential }
            .map { item in
            RoleReadyExport.ReflectionDTO(
                id: item.id,
                opportunityID: item.opportunityID,
                questions: item.questions,
                experienceIDs: item.experienceIDs,
                strongestMoment: item.strongestMoment,
                difficultMoment: item.difficultMoment,
                feedback: item.feedback,
                nextImprovement: item.nextImprovement,
                createdAt: item.createdAt,
                updatedAt: item.updatedAt
            )
        }
        let careerSources = try context.fetch(FetchDescriptor<CareerSource>())
        let sourceSpans = includeConfidential
            ? try context.fetch(FetchDescriptor<CareerSourceSpan>())
            : []
        let positions = try context.fetch(FetchDescriptor<CareerPosition>()).filter {
            includeConfidential || $0.confidentiality < .confidential
        }
        let education = try context.fetch(FetchDescriptor<CareerEducation>()).filter {
            includeConfidential || $0.confidentiality < .confidential
        }
        let certifications = try context.fetch(FetchDescriptor<CareerCertification>()).filter {
            includeConfidential || $0.confidentiality < .confidential
        }
        let careerSkills = try context.fetch(FetchDescriptor<CareerSkill>()).filter {
            includeConfidential || $0.confidentiality < .confidential
        }
        let resumes = try context.fetch(FetchDescriptor<ResumeVersion>())
        let coverLetters = try context.fetch(FetchDescriptor<CoverLetter>())
        let activities = try context.fetch(FetchDescriptor<ApplicationActivity>())
        let reminders = try context.fetch(FetchDescriptor<CareerReminder>())

        let export = RoleReadyExport(
            identifier: RoleReadyExport.formatIdentifier,
            version: RoleReadyExport.formatVersion,
            createdAt: Date(),
            includesConfidential: includeConfidential,
            profiles: profiles.map { profile in
                .init(
                    id: profile.id,
                    name: profile.name,
                    email: profile.email,
                    phone: profile.phone,
                    location: profile.location,
                    linkedIn: profile.linkedIn,
                    portfolio: profile.portfolio,
                    headline: profile.headline,
                    professionalSummary: profile.professionalSummary,
                    currentOrganisation: profile.currentOrganisation,
                    targetRoles: profile.targetRoles,
                    skills: profile.skills,
                    careerGoal: profile.careerGoal,
                    sourceID: profile.sourceID,
                    verificationStatus: profile.verificationStatus.rawValue,
                    confidentiality: profile.confidentiality.rawValue,
                    isSample: profile.isSample,
                    createdAt: profile.createdAt,
                    updatedAt: profile.updatedAt
                )
            },
            experiences: experiences.map { item in
                .init(
                    id: item.id,
                    title: item.title,
                    organisation: item.organisation,
                    occurredAt: item.occurredAt,
                    kind: item.kind.rawValue,
                    situation: item.situation,
                    task: item.task,
                    actions: item.actions,
                    result: item.result,
                    evidence: item.evidence,
                    learning: item.learning,
                    ownership: item.ownership.rawValue,
                    capabilities: item.capabilities.map(\.rawValue),
                    tools: item.tools,
                    confidentiality: item.confidentiality.rawValue,
                    sourceID: item.sourceID,
                    sourceExcerpt: includeConfidential ? item.sourceExcerpt : "",
                    verificationStatus: item.verificationStatus.rawValue,
                    isApprovedForMatching: item.isApprovedForMatching,
                    isSample: item.isSample,
                    useCount: item.useCount,
                    createdAt: item.createdAt,
                    updatedAt: item.updatedAt
                )
            },
            opportunities: opportunities.map { item in
                .init(
                    id: item.id,
                    roleTitle: item.roleTitle,
                    organisation: item.organisation,
                    location: item.location,
                    jobURL: item.jobURL,
                    sourceName: item.sourceName,
                    sourceText: includeConfidential ? item.sourceText : "",
                    status: item.status.rawValue,
                    closingDate: item.closingDate,
                    savedAt: item.savedAt,
                    appliedAt: item.appliedAt,
                    followUpAt: item.followUpAt,
                    assessmentDate: item.assessmentDate,
                    interviewDate: item.interviewDate,
                    salaryRange: item.salaryRange,
                    workArrangement: item.workArrangement,
                    contactName: includeConfidential ? item.contactName : "",
                    contactDetails: includeConfidential ? item.contactDetails : "",
                    nextAction: item.nextAction,
                    notes: includeConfidential ? item.notes : "",
                    contentUpdatedAt: item.contentUpdatedAt,
                    isSample: item.isSample,
                    createdAt: item.createdAt,
                    updatedAt: item.updatedAt
                )
            },
            requirements: requirements.map { item in
                .init(
                    id: item.id,
                    opportunityID: item.opportunityID,
                    text: item.text,
                    kind: item.kind.rawValue,
                    keywords: item.keywords,
                    capabilities: item.capabilities.map(\.rawValue),
                    importance: item.importance,
                    isConfirmed: item.isConfirmed,
                    createdAt: item.createdAt
                )
            },
            answers: answers.map { item in
                .init(
                    id: item.id,
                    question: item.question,
                    experienceID: item.experienceID,
                    opportunityID: item.opportunityID,
                    format: item.format.rawValue,
                    audience: item.audience.rawValue,
                    tone: item.tone.rawValue,
                    content: item.content,
                    quickCues: item.quickCues,
                    sourceFields: item.sourceFields,
                    sourceClaims: item.sourceClaims,
                    followUps: item.followUps,
                    isFactConfirmed: item.isFactConfirmed,
                    sourceExperienceUpdatedAt: item.sourceExperienceUpdatedAt,
                    sourceOpportunityUpdatedAt: item.sourceOpportunityUpdatedAt,
                    createdAt: item.createdAt,
                    isUserEdited: item.isUserEdited,
                    isSample: item.isSample,
                    updatedAt: item.updatedAt
                )
            },
            practiceSessions: practiceSessions.map { item in
                .init(
                    id: item.id,
                    answerID: item.answerID,
                    experienceID: item.experienceID,
                    opportunityID: item.opportunityID,
                    question: item.question,
                    durationSeconds: item.durationSeconds,
                    confidence: item.confidence,
                    notes: item.notes,
                    practisedAt: item.practisedAt
                )
            },
            reflections: reflections,
            careerSources: careerSources.map { item in
                .init(
                    id: item.id,
                    kind: item.kind.rawValue,
                    name: item.name,
                    filename: item.filename,
                    contentType: item.contentType,
                    rawText: includeConfidential ? item.rawText : "",
                    fingerprint: item.fingerprint,
                    confidentiality: item.confidentiality.rawValue,
                    isSample: item.isSample,
                    importedAt: item.importedAt,
                    updatedAt: item.updatedAt
                )
            },
            sourceSpans: sourceSpans.map { item in
                .init(
                    id: item.id,
                    sourceID: item.sourceID,
                    entityID: item.entityID,
                    entityType: item.entityType,
                    fieldPath: item.fieldPath,
                    startOffset: item.startOffset,
                    endOffset: item.endOffset,
                    excerpt: item.excerpt,
                    confidence: item.confidence,
                    isApproved: item.isApproved,
                    createdAt: item.createdAt
                )
            },
            positions: positions.map { item in
                .init(
                    id: item.id,
                    sourceID: item.sourceID,
                    title: item.title,
                    organisation: item.organisation,
                    location: item.location,
                    employmentType: item.employmentType.rawValue,
                    startDate: item.startDate,
                    endDate: item.endDate,
                    isCurrent: item.isCurrent,
                    summary: item.summary,
                    bullets: item.bullets,
                    skills: item.skills,
                    sourceExcerpt: includeConfidential ? item.sourceExcerpt : "",
                    verificationStatus: item.verificationStatus.rawValue,
                    confidentiality: item.confidentiality.rawValue,
                    approvedAt: item.approvedAt,
                    isSample: item.isSample,
                    createdAt: item.createdAt,
                    updatedAt: item.updatedAt
                )
            },
            education: education.map { item in
                .init(
                    id: item.id,
                    sourceID: item.sourceID,
                    institution: item.institution,
                    qualification: item.qualification,
                    fieldOfStudy: item.fieldOfStudy,
                    location: item.location,
                    startDate: item.startDate,
                    endDate: item.endDate,
                    details: item.details,
                    sourceExcerpt: includeConfidential ? item.sourceExcerpt : "",
                    verificationStatus: item.verificationStatus.rawValue,
                    confidentiality: item.confidentiality.rawValue,
                    isSample: item.isSample,
                    createdAt: item.createdAt,
                    updatedAt: item.updatedAt
                )
            },
            certifications: certifications.map { item in
                .init(
                    id: item.id,
                    sourceID: item.sourceID,
                    name: item.name,
                    issuer: item.issuer,
                    issuedAt: item.issuedAt,
                    expiresAt: item.expiresAt,
                    credentialID: item.credentialID,
                    credentialURL: item.credentialURL,
                    sourceExcerpt: includeConfidential ? item.sourceExcerpt : "",
                    verificationStatus: item.verificationStatus.rawValue,
                    confidentiality: item.confidentiality.rawValue,
                    isSample: item.isSample,
                    createdAt: item.createdAt,
                    updatedAt: item.updatedAt
                )
            },
            careerSkills: careerSkills.map { item in
                .init(
                    id: item.id,
                    sourceID: item.sourceID,
                    name: item.name,
                    category: item.category,
                    level: item.level.rawValue,
                    yearsExperience: item.yearsExperience,
                    lastUsedAt: item.lastUsedAt,
                    sourceExcerpt: includeConfidential ? item.sourceExcerpt : "",
                    verificationStatus: item.verificationStatus.rawValue,
                    confidentiality: item.confidentiality.rawValue,
                    isSample: item.isSample,
                    createdAt: item.createdAt,
                    updatedAt: item.updatedAt
                )
            },
            resumes: resumes.map { item in
                .init(
                    id: item.id,
                    parentVersionID: item.parentVersionID,
                    sourceID: item.sourceID,
                    opportunityID: item.opportunityID,
                    name: item.name,
                    targetRole: item.targetRole,
                    targetOrganisation: item.targetOrganisation,
                    template: item.template.rawValue,
                    status: item.status.rawValue,
                    document: item.document,
                    tailoringReport: item.tailoringReport,
                    isBaseline: item.isBaseline,
                    isSample: item.isSample,
                    createdAt: item.createdAt,
                    updatedAt: item.updatedAt,
                    lastExportedAt: item.lastExportedAt
                )
            },
            coverLetters: coverLetters.map { item in
                .init(
                    id: item.id,
                    opportunityID: item.opportunityID,
                    resumeVersionID: item.resumeVersionID,
                    title: item.title,
                    body: item.body,
                    grounding: item.grounding,
                    generator: item.generator,
                    isUserEdited: item.isUserEdited,
                    validationWarnings: item.validationWarnings,
                    sourceEntityIDs: item.sourceEntityIDs,
                    status: item.status.rawValue,
                    isSample: item.isSample,
                    createdAt: item.createdAt,
                    updatedAt: item.updatedAt
                )
            },
            activities: activities.map { item in
                .init(
                    id: item.id,
                    opportunityID: item.opportunityID,
                    kind: item.kind.rawValue,
                    title: item.title,
                    notes: includeConfidential ? item.notes : "",
                    occurredAt: item.occurredAt,
                    isSample: item.isSample,
                    createdAt: item.createdAt
                )
            },
            reminders: reminders.map { item in
                .init(
                    id: item.id,
                    opportunityID: item.opportunityID,
                    activityID: item.activityID,
                    kind: item.kind.rawValue,
                    title: item.title,
                    notes: includeConfidential ? item.notes : "",
                    dueAt: item.dueAt,
                    notificationIdentifier: "",
                    isCompleted: item.isCompleted,
                    completedAt: item.completedAt,
                    isSample: item.isSample,
                    createdAt: item.createdAt,
                    updatedAt: item.updatedAt
                )
            }
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(export)
    }

    func writeTemporaryExport(_ data: Data) throws -> URL {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("RoleReady-\(formatter.string(from: Date())).json")
        try data.write(to: url, options: [.atomic, .completeFileProtection])
        return url
    }

    func removeTemporaryExports() {
        let directory = FileManager.default.temporaryDirectory
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return }
        for file in files where file.lastPathComponent.hasPrefix("RoleReady-") && file.pathExtension == "json" {
            try? FileManager.default.removeItem(at: file)
        }
    }
}
