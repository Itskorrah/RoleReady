import Foundation
import SwiftData

@Model
final class CareerSource {
    @Attribute(.unique) var id: UUID = UUID()
    var kindRaw: String = CareerSourceKind.manual.rawValue
    var name: String = ""
    var filename: String = ""
    var contentType: String = ""
    var rawText: String = ""
    var fingerprint: String = ""
    var confidentialityRaw: String = Confidentiality.privateRecord.rawValue
    var isSample: Bool = false
    var importedAt: Date = Date()
    var updatedAt: Date = Date()

    init(
        id: UUID = UUID(),
        kind: CareerSourceKind,
        name: String,
        filename: String = "",
        contentType: String = "",
        rawText: String,
        fingerprint: String = "",
        confidentiality: Confidentiality = .privateRecord,
        isSample: Bool = false,
        importedAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.kindRaw = kind.rawValue
        self.name = name
        self.filename = filename
        self.contentType = contentType
        self.rawText = rawText
        self.fingerprint = fingerprint
        self.confidentialityRaw = confidentiality.rawValue
        self.isSample = isSample
        self.importedAt = importedAt
        self.updatedAt = updatedAt
    }

    var kind: CareerSourceKind {
        get { CareerSourceKind(rawValue: kindRaw) ?? .manual }
        set { kindRaw = newValue.rawValue }
    }

    var confidentiality: Confidentiality {
        get { Confidentiality(rawValue: confidentialityRaw) ?? .privateRecord }
        set { confidentialityRaw = newValue.rawValue }
    }
}

@Model
final class CareerSourceSpan {
    @Attribute(.unique) var id: UUID = UUID()
    var sourceID: UUID = UUID()
    var entityID: UUID = UUID()
    var entityType: String = ""
    var fieldPath: String = ""
    var startOffset: Int = 0
    var endOffset: Int = 0
    var excerpt: String = ""
    var confidence: Double = 0
    var isApproved: Bool = false
    var createdAt: Date = Date()

    init(
        id: UUID = UUID(),
        sourceID: UUID,
        entityID: UUID,
        entityType: String,
        fieldPath: String,
        startOffset: Int,
        endOffset: Int,
        excerpt: String,
        confidence: Double,
        isApproved: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.sourceID = sourceID
        self.entityID = entityID
        self.entityType = entityType
        self.fieldPath = fieldPath
        self.startOffset = max(0, startOffset)
        self.endOffset = max(self.startOffset, endOffset)
        self.excerpt = excerpt
        self.confidence = min(max(confidence, 0), 1)
        self.isApproved = isApproved
        self.createdAt = createdAt
    }
}

@Model
final class CareerPosition {
    @Attribute(.unique) var id: UUID = UUID()
    var sourceID: UUID?
    var title: String = ""
    var organisation: String = ""
    var location: String = ""
    var employmentTypeRaw: String = EmploymentType.fullTime.rawValue
    var startDate: Date?
    var endDate: Date?
    var isCurrent: Bool = false
    var summary: String = ""
    var bulletsRaw: String = ""
    var skillsRaw: String = ""
    var sourceExcerpt: String = ""
    var verificationStatusRaw: String = CareerRecordStatus.imported.rawValue
    var confidentialityRaw: String = Confidentiality.privateRecord.rawValue
    var approvedAt: Date?
    var isSample: Bool = false
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(
        id: UUID = UUID(),
        sourceID: UUID? = nil,
        title: String,
        organisation: String,
        location: String = "",
        employmentType: EmploymentType = .fullTime,
        startDate: Date? = nil,
        endDate: Date? = nil,
        isCurrent: Bool = false,
        summary: String = "",
        bullets: [String] = [],
        skills: [String] = [],
        sourceExcerpt: String = "",
        verificationStatus: CareerRecordStatus = .imported,
        confidentiality: Confidentiality = .privateRecord,
        approvedAt: Date? = nil,
        isSample: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.sourceID = sourceID
        self.title = title
        self.organisation = organisation
        self.location = location
        self.employmentTypeRaw = employmentType.rawValue
        self.startDate = startDate
        self.endDate = endDate
        self.isCurrent = isCurrent
        self.summary = summary
        self.bulletsRaw = ListCodec.encode(bullets)
        self.skillsRaw = ListCodec.encode(skills)
        self.sourceExcerpt = sourceExcerpt
        self.verificationStatusRaw = verificationStatus.rawValue
        self.confidentialityRaw = confidentiality.rawValue
        self.approvedAt = approvedAt
        self.isSample = isSample
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var employmentType: EmploymentType {
        get { EmploymentType(rawValue: employmentTypeRaw) ?? .fullTime }
        set { employmentTypeRaw = newValue.rawValue }
    }

    var bullets: [String] {
        get { ListCodec.decode(bulletsRaw) }
        set { bulletsRaw = ListCodec.encode(newValue) }
    }

    var skills: [String] {
        get { ListCodec.decode(skillsRaw) }
        set { skillsRaw = ListCodec.encode(newValue) }
    }

    var verificationStatus: CareerRecordStatus {
        get { CareerRecordStatus(rawValue: verificationStatusRaw) ?? .imported }
        set { verificationStatusRaw = newValue.rawValue }
    }

    var confidentiality: Confidentiality {
        get { Confidentiality(rawValue: confidentialityRaw) ?? .privateRecord }
        set { confidentialityRaw = newValue.rawValue }
    }
}

@Model
final class CareerEducation {
    @Attribute(.unique) var id: UUID = UUID()
    var sourceID: UUID?
    var institution: String = ""
    var qualification: String = ""
    var fieldOfStudy: String = ""
    var location: String = ""
    var startDate: Date?
    var endDate: Date?
    var detailsRaw: String = ""
    var sourceExcerpt: String = ""
    var verificationStatusRaw: String = CareerRecordStatus.imported.rawValue
    var confidentialityRaw: String = Confidentiality.privateRecord.rawValue
    var isSample: Bool = false
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(
        id: UUID = UUID(),
        sourceID: UUID? = nil,
        institution: String,
        qualification: String,
        fieldOfStudy: String = "",
        location: String = "",
        startDate: Date? = nil,
        endDate: Date? = nil,
        details: [String] = [],
        sourceExcerpt: String = "",
        verificationStatus: CareerRecordStatus = .imported,
        confidentiality: Confidentiality = .privateRecord,
        isSample: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.sourceID = sourceID
        self.institution = institution
        self.qualification = qualification
        self.fieldOfStudy = fieldOfStudy
        self.location = location
        self.startDate = startDate
        self.endDate = endDate
        self.detailsRaw = ListCodec.encode(details)
        self.sourceExcerpt = sourceExcerpt
        self.verificationStatusRaw = verificationStatus.rawValue
        self.confidentialityRaw = confidentiality.rawValue
        self.isSample = isSample
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var details: [String] {
        get { ListCodec.decode(detailsRaw) }
        set { detailsRaw = ListCodec.encode(newValue) }
    }

    var verificationStatus: CareerRecordStatus {
        get { CareerRecordStatus(rawValue: verificationStatusRaw) ?? .imported }
        set { verificationStatusRaw = newValue.rawValue }
    }

    var confidentiality: Confidentiality {
        get { Confidentiality(rawValue: confidentialityRaw) ?? .privateRecord }
        set { confidentialityRaw = newValue.rawValue }
    }
}

@Model
final class CareerCertification {
    @Attribute(.unique) var id: UUID = UUID()
    var sourceID: UUID?
    var name: String = ""
    var issuer: String = ""
    var issuedAt: Date?
    var expiresAt: Date?
    var credentialID: String = ""
    var credentialURL: String = ""
    var sourceExcerpt: String = ""
    var verificationStatusRaw: String = CareerRecordStatus.imported.rawValue
    var confidentialityRaw: String = Confidentiality.privateRecord.rawValue
    var isSample: Bool = false
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(
        id: UUID = UUID(),
        sourceID: UUID? = nil,
        name: String,
        issuer: String,
        issuedAt: Date? = nil,
        expiresAt: Date? = nil,
        credentialID: String = "",
        credentialURL: String = "",
        sourceExcerpt: String = "",
        verificationStatus: CareerRecordStatus = .imported,
        confidentiality: Confidentiality = .privateRecord,
        isSample: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.sourceID = sourceID
        self.name = name
        self.issuer = issuer
        self.issuedAt = issuedAt
        self.expiresAt = expiresAt
        self.credentialID = credentialID
        self.credentialURL = credentialURL
        self.sourceExcerpt = sourceExcerpt
        self.verificationStatusRaw = verificationStatus.rawValue
        self.confidentialityRaw = confidentiality.rawValue
        self.isSample = isSample
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var verificationStatus: CareerRecordStatus {
        get { CareerRecordStatus(rawValue: verificationStatusRaw) ?? .imported }
        set { verificationStatusRaw = newValue.rawValue }
    }

    var confidentiality: Confidentiality {
        get { Confidentiality(rawValue: confidentialityRaw) ?? .privateRecord }
        set { confidentialityRaw = newValue.rawValue }
    }
}

@Model
final class CareerSkill {
    @Attribute(.unique) var id: UUID = UUID()
    var sourceID: UUID?
    var name: String = ""
    var category: String = ""
    var levelRaw: String = SkillLevel.working.rawValue
    var yearsExperience: Double = 0
    var lastUsedAt: Date?
    var sourceExcerpt: String = ""
    var verificationStatusRaw: String = CareerRecordStatus.imported.rawValue
    var confidentialityRaw: String = Confidentiality.privateRecord.rawValue
    var isSample: Bool = false
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(
        id: UUID = UUID(),
        sourceID: UUID? = nil,
        name: String,
        category: String = "",
        level: SkillLevel = .working,
        yearsExperience: Double = 0,
        lastUsedAt: Date? = nil,
        sourceExcerpt: String = "",
        verificationStatus: CareerRecordStatus = .imported,
        confidentiality: Confidentiality = .privateRecord,
        isSample: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.sourceID = sourceID
        self.name = name
        self.category = category
        self.levelRaw = level.rawValue
        self.yearsExperience = max(0, yearsExperience)
        self.lastUsedAt = lastUsedAt
        self.sourceExcerpt = sourceExcerpt
        self.verificationStatusRaw = verificationStatus.rawValue
        self.confidentialityRaw = confidentiality.rawValue
        self.isSample = isSample
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var level: SkillLevel {
        get { SkillLevel(rawValue: levelRaw) ?? .working }
        set { levelRaw = newValue.rawValue }
    }

    var verificationStatus: CareerRecordStatus {
        get { CareerRecordStatus(rawValue: verificationStatusRaw) ?? .imported }
        set { verificationStatusRaw = newValue.rawValue }
    }

    var confidentiality: Confidentiality {
        get { Confidentiality(rawValue: confidentialityRaw) ?? .privateRecord }
        set { confidentialityRaw = newValue.rawValue }
    }
}

@Model
final class ResumeVersion {
    @Attribute(.unique) var id: UUID = UUID()
    var parentVersionID: UUID?
    var sourceID: UUID?
    var opportunityID: UUID?
    var name: String = ""
    var targetRole: String = ""
    var targetOrganisation: String = ""
    var templateRaw: String = ResumeTemplate.technical.rawValue
    var statusRaw: String = ResumeStatus.draft.rawValue
    var contentJSON: String = ""
    var isBaseline: Bool = false
    var isSample: Bool = false
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var lastExportedAt: Date?

    init(
        id: UUID = UUID(),
        parentVersionID: UUID? = nil,
        sourceID: UUID? = nil,
        opportunityID: UUID? = nil,
        name: String,
        targetRole: String = "",
        targetOrganisation: String = "",
        template: ResumeTemplate = .technical,
        status: ResumeStatus = .draft,
        document: ResumeDocument = .empty,
        isBaseline: Bool = false,
        isSample: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        lastExportedAt: Date? = nil
    ) {
        self.id = id
        self.parentVersionID = parentVersionID
        self.sourceID = sourceID
        self.opportunityID = opportunityID
        self.name = name
        self.targetRole = targetRole
        self.targetOrganisation = targetOrganisation
        self.templateRaw = template.rawValue
        self.statusRaw = status.rawValue
        self.contentJSON = ResumeDocumentCodec.encode(document)
        self.isBaseline = isBaseline
        self.isSample = isSample
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.lastExportedAt = lastExportedAt
    }

    var template: ResumeTemplate {
        get { ResumeTemplate(rawValue: templateRaw) ?? .technical }
        set { templateRaw = newValue.rawValue }
    }

    var status: ResumeStatus {
        get { ResumeStatus(rawValue: statusRaw) ?? .draft }
        set { statusRaw = newValue.rawValue }
    }

    var document: ResumeDocument {
        get { ResumeDocumentCodec.decode(contentJSON) }
        set { contentJSON = ResumeDocumentCodec.encode(newValue) }
    }
}

@Model
final class CoverLetter {
    @Attribute(.unique) var id: UUID = UUID()
    var opportunityID: UUID = UUID()
    var resumeVersionID: UUID?
    var title: String = ""
    var body: String = ""
    var sourceEntityIDsRaw: String = ""
    var statusRaw: String = CoverLetterStatus.draft.rawValue
    var isSample: Bool = false
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(
        id: UUID = UUID(),
        opportunityID: UUID,
        resumeVersionID: UUID? = nil,
        title: String,
        body: String,
        sourceEntityIDs: [UUID] = [],
        status: CoverLetterStatus = .draft,
        isSample: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.opportunityID = opportunityID
        self.resumeVersionID = resumeVersionID
        self.title = title
        self.body = body
        self.sourceEntityIDsRaw = ListCodec.encode(sourceEntityIDs.map(\.uuidString))
        self.statusRaw = status.rawValue
        self.isSample = isSample
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var sourceEntityIDs: [UUID] {
        get { ListCodec.decode(sourceEntityIDsRaw).compactMap(UUID.init(uuidString:)) }
        set { sourceEntityIDsRaw = ListCodec.encode(newValue.map(\.uuidString)) }
    }

    var status: CoverLetterStatus {
        get { CoverLetterStatus(rawValue: statusRaw) ?? .draft }
        set { statusRaw = newValue.rawValue }
    }
}

@Model
final class ApplicationActivity {
    @Attribute(.unique) var id: UUID = UUID()
    var opportunityID: UUID = UUID()
    var kindRaw: String = ApplicationActivityKind.note.rawValue
    var title: String = ""
    var notes: String = ""
    var occurredAt: Date = Date()
    var isSample: Bool = false
    var createdAt: Date = Date()

    init(
        id: UUID = UUID(),
        opportunityID: UUID,
        kind: ApplicationActivityKind,
        title: String,
        notes: String = "",
        occurredAt: Date = Date(),
        isSample: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.opportunityID = opportunityID
        self.kindRaw = kind.rawValue
        self.title = title
        self.notes = notes
        self.occurredAt = occurredAt
        self.isSample = isSample
        self.createdAt = createdAt
    }

    var kind: ApplicationActivityKind {
        get { ApplicationActivityKind(rawValue: kindRaw) ?? .note }
        set { kindRaw = newValue.rawValue }
    }
}

@Model
final class CareerReminder {
    @Attribute(.unique) var id: UUID = UUID()
    var opportunityID: UUID?
    var activityID: UUID?
    var kindRaw: String = CareerReminderKind.checkProgress.rawValue
    var title: String = ""
    var notes: String = ""
    var dueAt: Date = Date()
    var notificationIdentifier: String = ""
    var isCompleted: Bool = false
    var completedAt: Date?
    var isSample: Bool = false
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(
        id: UUID = UUID(),
        opportunityID: UUID? = nil,
        activityID: UUID? = nil,
        kind: CareerReminderKind,
        title: String,
        notes: String = "",
        dueAt: Date,
        notificationIdentifier: String = "",
        isCompleted: Bool = false,
        completedAt: Date? = nil,
        isSample: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.opportunityID = opportunityID
        self.activityID = activityID
        self.kindRaw = kind.rawValue
        self.title = title
        self.notes = notes
        self.dueAt = dueAt
        self.notificationIdentifier = notificationIdentifier
        self.isCompleted = isCompleted
        self.completedAt = completedAt
        self.isSample = isSample
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var kind: CareerReminderKind {
        get { CareerReminderKind(rawValue: kindRaw) ?? .checkProgress }
        set { kindRaw = newValue.rawValue }
    }
}
