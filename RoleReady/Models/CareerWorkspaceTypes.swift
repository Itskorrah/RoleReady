import Foundation

enum CareerSourceKind: String, CaseIterable, Identifiable, Codable, Sendable {
    case resume
    case jobDescription
    case manual
    case workspaceRestore

    var id: String { rawValue }

    var title: String {
        switch self {
        case .resume: "Résumé"
        case .jobDescription: "Job description"
        case .manual: "Manual entry"
        case .workspaceRestore: "Workspace restore"
        }
    }
}

enum CareerRecordStatus: String, CaseIterable, Identifiable, Codable, Sendable {
    case imported
    case reviewed
    case approved
    case rejected

    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var permitsGeneration: Bool { self == .approved }
}

enum EmploymentType: String, CaseIterable, Identifiable, Codable, Sendable {
    case fullTime
    case partTime
    case contract
    case internship
    case casual
    case volunteer
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fullTime: "Full-time"
        case .partTime: "Part-time"
        case .contract: "Contract"
        case .internship: "Internship"
        case .casual: "Casual"
        case .volunteer: "Volunteer"
        case .other: "Other"
        }
    }
}

enum SkillLevel: String, CaseIterable, Identifiable, Codable, Sendable {
    case familiar
    case working
    case proficient
    case advanced
    case expert

    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

enum ResumeTemplate: String, CaseIterable, Identifiable, Codable, Sendable {
    case technical
    case concise

    var id: String { rawValue }

    var title: String {
        switch self {
        case .technical: "Technical"
        case .concise: "Concise"
        }
    }
}

enum ResumeStatus: String, CaseIterable, Identifiable, Codable, Sendable {
    case draft
    case ready
    case archived

    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

enum ResumeSectionKind: String, CaseIterable, Identifiable, Codable, Sendable {
    case summary
    case skills
    case experience
    case projects
    case education
    case certifications

    var id: String { rawValue }

    var defaultTitle: String {
        switch self {
        case .summary: "Professional summary"
        case .skills: "Technical skills"
        case .experience: "Experience"
        case .projects: "Selected projects"
        case .education: "Education"
        case .certifications: "Certifications"
        }
    }
}

enum EvidenceClassification: String, CaseIterable, Identifiable, Codable, Sendable {
    case direct
    case transferable
    case partial
    case noEvidence

    var id: String { rawValue }

    var title: String {
        switch self {
        case .direct: "Direct evidence"
        case .transferable: "Transferable evidence"
        case .partial: "Partial evidence"
        case .noEvidence: "No evidence"
        }
    }
}

enum CoverLetterStatus: String, CaseIterable, Identifiable, Codable, Sendable {
    case draft
    case approved
    case archived

    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

enum ApplicationActivityKind: String, CaseIterable, Identifiable, Codable, Sendable {
    case saved
    case applied
    case followUp
    case recruiterContact
    case assessment
    case interview
    case offer
    case outcome
    case note

    var id: String { rawValue }

    var title: String {
        switch self {
        case .saved: "Saved"
        case .applied: "Applied"
        case .followUp: "Follow-up"
        case .recruiterContact: "Recruiter contact"
        case .assessment: "Assessment"
        case .interview: "Interview"
        case .offer: "Offer"
        case .outcome: "Outcome"
        case .note: "Note"
        }
    }
}

enum CareerReminderKind: String, CaseIterable, Identifiable, Codable, Sendable {
    case followUp
    case applicationDeadline
    case assessment
    case interview
    case checkProgress

    var id: String { rawValue }

    var title: String {
        switch self {
        case .followUp: "Follow up"
        case .applicationDeadline: "Application deadline"
        case .assessment: "Assessment"
        case .interview: "Interview"
        case .checkProgress: "Check progress"
        }
    }
}

struct ResumeContact: Codable, Hashable, Sendable {
    var name: String
    var email: String
    var phone: String
    var location: String
    var linkedIn: String
    var portfolio: String

    static let empty = ResumeContact(
        name: "",
        email: "",
        phone: "",
        location: "",
        linkedIn: "",
        portfolio: ""
    )
}

struct ResumeBullet: Codable, Hashable, Identifiable, Sendable {
    var id: UUID
    var text: String
    var sourceEntityIDs: [UUID]
    var evidence: EvidenceClassification
    var isApproved: Bool
    var generator: String?
    var generatedAt: Date?
    var isUserEdited: Bool?
    var validationWarnings: [String]?

    init(
        id: UUID = UUID(),
        text: String,
        sourceEntityIDs: [UUID] = [],
        evidence: EvidenceClassification = .noEvidence,
        isApproved: Bool = false,
        generator: String? = nil,
        generatedAt: Date? = nil,
        isUserEdited: Bool? = nil,
        validationWarnings: [String]? = nil
    ) {
        self.id = id
        self.text = text
        self.sourceEntityIDs = sourceEntityIDs
        self.evidence = evidence
        self.isApproved = isApproved
        self.generator = generator
        self.generatedAt = generatedAt
        self.isUserEdited = isUserEdited
        self.validationWarnings = validationWarnings
    }
}

struct ResumeItem: Codable, Hashable, Identifiable, Sendable {
    var id: UUID
    var sourceEntityIDs: [UUID]
    var heading: String
    var subheading: String
    var location: String
    var startDate: Date?
    var endDate: Date?
    var bullets: [ResumeBullet]

    init(
        id: UUID = UUID(),
        sourceEntityIDs: [UUID] = [],
        heading: String,
        subheading: String = "",
        location: String = "",
        startDate: Date? = nil,
        endDate: Date? = nil,
        bullets: [ResumeBullet] = []
    ) {
        self.id = id
        self.sourceEntityIDs = sourceEntityIDs
        self.heading = heading
        self.subheading = subheading
        self.location = location
        self.startDate = startDate
        self.endDate = endDate
        self.bullets = bullets
    }
}

struct ResumeSection: Codable, Hashable, Identifiable, Sendable {
    var id: UUID
    var kind: ResumeSectionKind
    var title: String
    var body: String
    var items: [ResumeItem]
    var isVisible: Bool

    init(
        id: UUID = UUID(),
        kind: ResumeSectionKind,
        title: String? = nil,
        body: String = "",
        items: [ResumeItem] = [],
        isVisible: Bool = true
    ) {
        self.id = id
        self.kind = kind
        self.title = title ?? kind.defaultTitle
        self.body = body
        self.items = items
        self.isVisible = isVisible
    }
}

struct ResumeDocument: Codable, Hashable, Sendable {
    var contact: ResumeContact
    var headline: String
    var sections: [ResumeSection]

    static let empty = ResumeDocument(
        contact: .empty,
        headline: "",
        sections: ResumeSectionKind.allCases.map { ResumeSection(kind: $0) }
    )
}

enum ResumeDocumentCodec {
    static func encode(_ document: ResumeDocument) -> String {
        guard let data = try? JSONEncoder().encode(document),
              let value = String(data: data, encoding: .utf8) else { return "" }
        return value
    }

    static func decode(_ value: String) -> ResumeDocument {
        guard let data = value.data(using: .utf8),
              let document = try? JSONDecoder().decode(ResumeDocument.self, from: data) else {
            return .empty
        }
        return document
    }
}

struct TailoringEvidenceMatch: Codable, Hashable, Identifiable, Sendable {
    var id: UUID
    var requirementID: UUID
    var requirement: String
    var classification: EvidenceClassification
    var sourceEntityIDs: [UUID]
    var sourceExcerpts: [String]
    var reason: String
    var followUpQuestion: String?

    init(
        id: UUID = UUID(),
        requirementID: UUID,
        requirement: String,
        classification: EvidenceClassification,
        sourceEntityIDs: [UUID],
        sourceExcerpts: [String],
        reason: String,
        followUpQuestion: String? = nil
    ) {
        self.id = id
        self.requirementID = requirementID
        self.requirement = requirement
        self.classification = classification
        self.sourceEntityIDs = sourceEntityIDs
        self.sourceExcerpts = sourceExcerpts
        self.reason = reason
        self.followUpQuestion = followUpQuestion
    }
}

struct TailoringReport: Codable, Hashable, Sendable {
    var matches: [TailoringEvidenceMatch]
    var changeSummary: [String]
    var validationWarnings: [String]
    var generator: String
    var generatedAt: Date

    static let empty = TailoringReport(
        matches: [],
        changeSummary: [],
        validationWarnings: [],
        generator: "",
        generatedAt: .distantPast
    )
}

struct GroundedParagraph: Codable, Hashable, Identifiable, Sendable {
    var id: UUID
    var text: String
    var sourceEntityIDs: [UUID]
    var claimType: String
    var isApproved: Bool
    var isUserEdited: Bool
    var validationWarnings: [String]

    init(
        id: UUID = UUID(),
        text: String,
        sourceEntityIDs: [UUID] = [],
        claimType: String,
        isApproved: Bool = false,
        isUserEdited: Bool = false,
        validationWarnings: [String] = []
    ) {
        self.id = id
        self.text = text
        self.sourceEntityIDs = sourceEntityIDs
        self.claimType = claimType
        self.isApproved = isApproved
        self.isUserEdited = isUserEdited
        self.validationWarnings = validationWarnings
    }
}

struct CoverLetterGrounding: Codable, Hashable, Sendable {
    var paragraphs: [GroundedParagraph]
    var generator: String
    var generatedAt: Date
    var validationWarnings: [String]

    static let empty = CoverLetterGrounding(
        paragraphs: [],
        generator: "",
        generatedAt: .distantPast,
        validationWarnings: []
    )
}

enum CareerWorkspaceJSONCodec {
    static func encode<T: Encodable>(_ value: T) -> String {
        guard let data = try? JSONEncoder().encode(value),
              let string = String(data: data, encoding: .utf8) else { return "" }
        return string
    }

    static func decode<T: Decodable>(_ type: T.Type, from value: String, fallback: T) -> T {
        guard let data = value.data(using: .utf8),
              let decoded = try? JSONDecoder().decode(type, from: data) else { return fallback }
        return decoded
    }
}
