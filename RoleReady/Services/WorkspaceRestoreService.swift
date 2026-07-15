import Foundation
import SwiftData

enum WorkspaceRestoreError: LocalizedError, Equatable, Sendable {
    case inaccessible
    case tooLarge
    case malformed
    case wrongFormat
    case unsupportedVersion(Int)
    case nothingToRestore
    case pendingChanges

    var errorDescription: String? {
        switch self {
        case .inaccessible:
            "RoleReady could not access that export. Choose it again from Files."
        case .tooLarge:
            "Choose a RoleReady export smaller than 20 MB."
        case .malformed:
            "This file is not a readable RoleReady export. Your current workspace was not changed."
        case .wrongFormat:
            "This JSON file was not created by RoleReady. Your current workspace was not changed."
        case .unsupportedVersion(let version):
            "This export uses version \(version), which this version of RoleReady cannot restore. Update the app before trying again."
        case .nothingToRestore:
            "No new valid records were found. Your current workspace was not changed."
        case .pendingChanges:
            "Finish or discard the edit already in progress before restoring. Your current workspace was not changed."
        }
    }
}

struct RestoreRecordCounts: Hashable, Sendable {
    var profiles = 0
    var careerSources = 0
    var sourceSpans = 0
    var positions = 0
    var education = 0
    var certifications = 0
    var careerSkills = 0
    var experiences = 0
    var opportunities = 0
    var requirements = 0
    var resumes = 0
    var coverLetters = 0
    var activities = 0
    var reminders = 0
    var answers = 0
    var practiceSessions = 0
    var reflections = 0

    var total: Int {
        profiles + careerSources + sourceSpans + positions + education + certifications + careerSkills
            + experiences + opportunities + requirements + resumes + coverLetters + activities + reminders
            + answers + practiceSessions + reflections
    }
}

struct WorkspaceRestorePreview: Hashable, Sendable {
    let sourceVersion: Int
    let createdAt: Date
    let includesConfidential: Bool
    let importable: RestoreRecordCounts
    let duplicates: RestoreRecordCounts
    let rejected: RestoreRecordCounts
    let warnings: [String]
}

struct WorkspaceRestoreResult: Hashable, Sendable {
    let restored: RestoreRecordCounts
    let skippedDuplicates: Int
    let rejectedRecords: Int
}

struct RestoreDocumentReader: Sendable {
    private let maximumBytes = 20 * 1_024 * 1_024

    func readData(from url: URL) throws -> Data {
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }

        guard url.pathExtension.caseInsensitiveCompare("json") == .orderedSame else {
            throw WorkspaceRestoreError.wrongFormat
        }
        let values = try? url.resourceValues(forKeys: [.fileSizeKey])
        if let fileSize = values?.fileSize, fileSize > maximumBytes {
            throw WorkspaceRestoreError.tooLarge
        }
        guard let data = try? Data(contentsOf: url, options: [.mappedIfSafe]) else {
            throw WorkspaceRestoreError.inaccessible
        }
        guard data.count <= maximumBytes else { throw WorkspaceRestoreError.tooLarge }
        return data
    }
}

@MainActor
struct WorkspaceRestoreService {
    func preview(_ data: Data, in context: ModelContext) throws -> WorkspaceRestorePreview {
        try validatedArchive(from: data, in: context).preview
    }

    func restore(_ data: Data, in context: ModelContext) throws -> WorkspaceRestoreResult {
        guard !context.hasChanges else { throw WorkspaceRestoreError.pendingChanges }
        let restoreContext = ModelContext(context.container)
        restoreContext.autosaveEnabled = false
        return try restoreValidated(data, in: restoreContext)
    }

    private func restoreValidated(_ data: Data, in context: ModelContext) throws -> WorkspaceRestoreResult {
        let validated = try validatedArchive(from: data, in: context)
        guard validated.preview.importable.total > 0 else { throw WorkspaceRestoreError.nothingToRestore }

        do {
            for item in validated.careerSources {
                guard let kind = CareerSourceKind(rawValue: item.kind),
                      let confidentiality = Confidentiality(rawValue: item.confidentiality) else { continue }
                context.insert(CareerSource(
                    id: item.id,
                    kind: kind,
                    name: item.name,
                    filename: item.filename,
                    contentType: item.contentType,
                    rawText: item.rawText,
                    fingerprint: item.fingerprint,
                    confidentiality: confidentiality,
                    isSample: item.isSample,
                    importedAt: item.importedAt,
                    updatedAt: item.updatedAt
                ))
            }

            for item in validated.profiles {
                if let replacementID = validated.emptyProfileID,
                   let profile = try context.fetch(FetchDescriptor<CareerProfile>()).first(where: { $0.id == replacementID }) {
                    profile.name = item.name
                    profile.email = item.email ?? ""
                    profile.phone = item.phone ?? ""
                    profile.location = item.location ?? ""
                    profile.linkedIn = item.linkedIn ?? ""
                    profile.portfolio = item.portfolio ?? ""
                    profile.headline = item.headline
                    profile.professionalSummary = item.professionalSummary
                    profile.currentOrganisation = item.currentOrganisation
                    profile.targetRoles = item.targetRoles
                    profile.skills = item.skills
                    profile.careerGoal = item.careerGoal
                    profile.sourceID = item.sourceID
                    profile.verificationStatus = item.verificationStatus.flatMap(CareerRecordStatus.init(rawValue:)) ?? .approved
                    profile.confidentiality = item.confidentiality.flatMap(Confidentiality.init(rawValue:)) ?? .privateRecord
                    profile.isSample = item.isSample ?? false
                    profile.updatedAt = item.updatedAt ?? validated.archive.createdAt
                } else {
                    context.insert(CareerProfile(
                        id: item.id,
                        name: item.name,
                        email: item.email ?? "",
                        phone: item.phone ?? "",
                        location: item.location ?? "",
                        linkedIn: item.linkedIn ?? "",
                        portfolio: item.portfolio ?? "",
                        headline: item.headline,
                        professionalSummary: item.professionalSummary,
                        currentOrganisation: item.currentOrganisation,
                        targetRoles: item.targetRoles,
                        skills: item.skills,
                        careerGoal: item.careerGoal,
                        sourceID: item.sourceID,
                        verificationStatus: item.verificationStatus.flatMap(CareerRecordStatus.init(rawValue:)) ?? .approved,
                        confidentiality: item.confidentiality.flatMap(Confidentiality.init(rawValue:)) ?? .privateRecord,
                        isSample: item.isSample ?? false,
                        createdAt: item.createdAt ?? validated.archive.createdAt,
                        updatedAt: item.updatedAt ?? validated.archive.createdAt
                    ))
                }
            }

            for item in validated.experiences {
                guard let kind = ExperienceKind(rawValue: item.kind),
                      let ownership = OwnershipLevel(rawValue: item.ownership),
                      let confidentiality = Confidentiality(rawValue: item.confidentiality) else { continue }
                let capabilities = item.capabilities.compactMap(Capability.init(rawValue:))
                context.insert(Experience(
                    id: item.id,
                    title: item.title,
                    organisation: item.organisation,
                    occurredAt: item.occurredAt,
                    kind: kind,
                    situation: item.situation,
                    task: item.task,
                    actions: item.actions,
                    result: item.result,
                    evidence: item.evidence,
                    learning: item.learning,
                    ownership: ownership,
                    capabilities: capabilities,
                    tools: item.tools,
                    confidentiality: confidentiality,
                    sourceID: item.sourceID,
                    sourceExcerpt: item.sourceExcerpt ?? "",
                    verificationStatus: item.verificationStatus.flatMap(CareerRecordStatus.init(rawValue:)) ?? .approved,
                    isApprovedForMatching: matchingApproval(for: item),
                    isSample: item.isSample ?? false,
                    useCount: item.useCount ?? 0,
                    createdAt: item.createdAt ?? validated.archive.createdAt,
                    updatedAt: item.updatedAt ?? validated.archive.createdAt
                ))
            }

            for item in validated.positions {
                guard let employmentType = EmploymentType(rawValue: item.employmentType),
                      let verification = CareerRecordStatus(rawValue: item.verificationStatus),
                      let confidentiality = Confidentiality(rawValue: item.confidentiality) else { continue }
                context.insert(CareerPosition(
                    id: item.id,
                    sourceID: item.sourceID,
                    title: item.title,
                    organisation: item.organisation,
                    location: item.location,
                    employmentType: employmentType,
                    startDate: item.startDate,
                    endDate: item.endDate,
                    isCurrent: item.isCurrent,
                    summary: item.summary,
                    bullets: item.bullets,
                    skills: item.skills,
                    sourceExcerpt: item.sourceExcerpt,
                    verificationStatus: verification,
                    confidentiality: confidentiality,
                    approvedAt: item.approvedAt,
                    isSample: item.isSample,
                    createdAt: item.createdAt,
                    updatedAt: item.updatedAt
                ))
            }

            for item in validated.education {
                guard let verification = CareerRecordStatus(rawValue: item.verificationStatus),
                      let confidentiality = Confidentiality(rawValue: item.confidentiality) else { continue }
                context.insert(CareerEducation(
                    id: item.id,
                    sourceID: item.sourceID,
                    institution: item.institution,
                    qualification: item.qualification,
                    fieldOfStudy: item.fieldOfStudy,
                    location: item.location,
                    startDate: item.startDate,
                    endDate: item.endDate,
                    details: item.details,
                    sourceExcerpt: item.sourceExcerpt,
                    verificationStatus: verification,
                    confidentiality: confidentiality,
                    isSample: item.isSample,
                    createdAt: item.createdAt,
                    updatedAt: item.updatedAt
                ))
            }

            for item in validated.certifications {
                guard let verification = CareerRecordStatus(rawValue: item.verificationStatus),
                      let confidentiality = Confidentiality(rawValue: item.confidentiality) else { continue }
                context.insert(CareerCertification(
                    id: item.id,
                    sourceID: item.sourceID,
                    name: item.name,
                    issuer: item.issuer,
                    issuedAt: item.issuedAt,
                    expiresAt: item.expiresAt,
                    credentialID: item.credentialID,
                    credentialURL: item.credentialURL,
                    sourceExcerpt: item.sourceExcerpt,
                    verificationStatus: verification,
                    confidentiality: confidentiality,
                    isSample: item.isSample,
                    createdAt: item.createdAt,
                    updatedAt: item.updatedAt
                ))
            }

            for item in validated.careerSkills {
                guard let level = SkillLevel(rawValue: item.level),
                      let verification = CareerRecordStatus(rawValue: item.verificationStatus),
                      let confidentiality = Confidentiality(rawValue: item.confidentiality) else { continue }
                context.insert(CareerSkill(
                    id: item.id,
                    sourceID: item.sourceID,
                    name: item.name,
                    category: item.category,
                    level: level,
                    yearsExperience: item.yearsExperience,
                    lastUsedAt: item.lastUsedAt,
                    sourceExcerpt: item.sourceExcerpt,
                    verificationStatus: verification,
                    confidentiality: confidentiality,
                    isSample: item.isSample,
                    createdAt: item.createdAt,
                    updatedAt: item.updatedAt
                ))
            }

            for item in validated.opportunities {
                guard let status = OpportunityStatus(rawValue: item.status) else { continue }
                context.insert(Opportunity(
                    id: item.id,
                    roleTitle: item.roleTitle,
                    organisation: item.organisation,
                    location: item.location,
                    jobURL: item.jobURL ?? "",
                    sourceName: item.sourceName ?? "",
                    sourceText: item.sourceText,
                    status: status,
                    closingDate: item.closingDate,
                    savedAt: item.savedAt,
                    appliedAt: item.appliedAt,
                    followUpAt: item.followUpAt,
                    assessmentDate: item.assessmentDate,
                    interviewDate: item.interviewDate,
                    salaryRange: item.salaryRange ?? "",
                    workArrangement: item.workArrangement ?? "",
                    contactName: item.contactName ?? "",
                    contactDetails: item.contactDetails ?? "",
                    nextAction: item.nextAction ?? "",
                    notes: item.notes,
                    isSample: item.isSample ?? false,
                    createdAt: item.createdAt ?? validated.archive.createdAt,
                    updatedAt: item.updatedAt ?? validated.archive.createdAt,
                    contentUpdatedAt: item.contentUpdatedAt
                ))
            }

            for item in validated.resumes {
                guard let template = ResumeTemplate(rawValue: item.template),
                      let status = ResumeStatus(rawValue: item.status) else { continue }
                let sanitized = sanitizedResume(
                    document: item.document,
                    report: item.tailoringReport,
                    status: status,
                    allowedEntityIDs: validated.groundingEntityIDs,
                    allowedRequirementIDs: validated.requirementIDs
                )
                context.insert(ResumeVersion(
                    id: item.id,
                    parentVersionID: item.parentVersionID,
                    sourceID: item.sourceID,
                    opportunityID: item.opportunityID,
                    name: item.name,
                    targetRole: item.targetRole,
                    targetOrganisation: item.targetOrganisation,
                    template: template,
                    status: sanitized.status,
                    document: sanitized.document,
                    tailoringReport: sanitized.report,
                    isBaseline: item.isBaseline,
                    isSample: item.isSample,
                    createdAt: item.createdAt,
                    updatedAt: item.updatedAt,
                    lastExportedAt: item.lastExportedAt
                ))
            }

            for item in validated.coverLetters {
                guard let status = CoverLetterStatus(rawValue: item.status) else { continue }
                let sanitized = sanitizedCoverLetter(
                    item,
                    status: status,
                    allowedEntityIDs: validated.groundingEntityIDs
                )
                context.insert(CoverLetter(
                    id: item.id,
                    opportunityID: item.opportunityID,
                    resumeVersionID: item.resumeVersionID,
                    title: item.title,
                    body: item.body,
                    grounding: sanitized.grounding,
                    generator: item.generator,
                    isUserEdited: item.isUserEdited,
                    validationWarnings: sanitized.warnings,
                    sourceEntityIDs: sanitized.sourceEntityIDs,
                    status: sanitized.status,
                    isSample: item.isSample,
                    createdAt: item.createdAt,
                    updatedAt: item.updatedAt
                ))
            }

            for item in validated.activities {
                guard let kind = ApplicationActivityKind(rawValue: item.kind) else { continue }
                context.insert(ApplicationActivity(
                    id: item.id,
                    opportunityID: item.opportunityID,
                    kind: kind,
                    title: item.title,
                    notes: item.notes,
                    occurredAt: item.occurredAt,
                    isSample: item.isSample,
                    createdAt: item.createdAt
                ))
            }

            for item in validated.reminders {
                guard let kind = CareerReminderKind(rawValue: item.kind) else { continue }
                context.insert(CareerReminder(
                    id: item.id,
                    opportunityID: item.opportunityID,
                    activityID: item.activityID,
                    kind: kind,
                    title: item.title,
                    notes: item.notes,
                    dueAt: item.dueAt,
                    notificationIdentifier: "",
                    isCompleted: item.isCompleted,
                    completedAt: item.completedAt,
                    isSample: item.isSample,
                    createdAt: item.createdAt,
                    updatedAt: item.updatedAt
                ))
            }

            for item in validated.requirements {
                guard let kind = RequirementKind(rawValue: item.kind) else { continue }
                context.insert(JobRequirement(
                    id: item.id,
                    opportunityID: item.opportunityID,
                    text: item.text,
                    kind: kind,
                    keywords: item.keywords,
                    capabilities: item.capabilities.compactMap(Capability.init(rawValue:)),
                    importance: item.importance,
                    isConfirmed: item.isConfirmed ?? true,
                    createdAt: item.createdAt ?? validated.archive.createdAt
                ))
            }

            for item in validated.answers {
                guard let format = AnswerFormat(rawValue: item.format),
                      let audience = AnswerAudience(rawValue: item.audience),
                      let tone = AnswerTone(rawValue: item.tone) else { continue }
                let isUserEdited = item.isUserEdited ?? false
                let roleTitle = item.opportunityID
                    .flatMap { validated.opportunitySources[$0]?.roleTitle } ?? ""
                let validatedClaims = validated.experienceSources[item.experienceID].map { source in
                    AnswerClaimValidator().validate(
                        item.sourceClaims,
                        question: item.question,
                        format: format,
                        audience: audience,
                        tone: tone,
                        roleTitle: roleTitle,
                        experience: source.experience
                    )
                } ?? item.sourceClaims.map { claim in
                    AnswerClaim(
                        text: claim.text,
                        sourceField: "Edited — source needed",
                        origin: .editedUnsupported,
                        isSupported: false
                    )
                }
                context.insert(GeneratedAnswer(
                    id: item.id,
                    question: item.question,
                    experienceID: item.experienceID,
                    opportunityID: item.opportunityID,
                    format: format,
                    audience: audience,
                    tone: tone,
                    content: item.content,
                    quickCues: item.quickCues,
                    sourceFields: item.sourceFields,
                    sourceClaims: AnswerProvenanceService().storedClaims(from: validatedClaims),
                    followUps: item.followUps,
                    isFactConfirmed: validated.approvableAnswerIDs.contains(item.id),
                    isUserEdited: isUserEdited,
                    isSample: item.isSample ?? false,
                    sourceExperienceUpdatedAt: validated.experienceSources[item.experienceID]?.updatedAt ?? .distantPast,
                    sourceOpportunityUpdatedAt: item.opportunityID.flatMap { validated.opportunitySources[$0]?.contentUpdatedAt },
                    createdAt: item.createdAt,
                    updatedAt: item.updatedAt ?? item.createdAt
                ))
            }

            for item in validated.practiceSessions {
                context.insert(PracticeSession(
                    id: item.id,
                    answerID: item.answerID,
                    experienceID: item.experienceID,
                    opportunityID: item.opportunityID,
                    question: item.question,
                    durationSeconds: item.durationSeconds,
                    confidence: item.confidence,
                    notes: item.notes,
                    practisedAt: item.practisedAt
                ))
            }

            for item in validated.reflections {
                context.insert(InterviewReflection(
                    id: item.id,
                    opportunityID: item.opportunityID,
                    questions: item.questions,
                    experienceIDs: item.experienceIDs,
                    strongestMoment: item.strongestMoment,
                    difficultMoment: item.difficultMoment,
                    feedback: item.feedback,
                    nextImprovement: item.nextImprovement,
                    createdAt: item.createdAt,
                    updatedAt: item.updatedAt ?? item.createdAt
                ))
            }

            for item in validated.sourceSpans {
                context.insert(CareerSourceSpan(
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
                ))
            }

            try context.save()
            return WorkspaceRestoreResult(
                restored: validated.preview.importable,
                skippedDuplicates: validated.preview.duplicates.total,
                rejectedRecords: validated.preview.rejected.total
            )
        } catch {
            context.rollback()
            throw error
        }
    }

    private func decode(_ data: Data) throws -> RoleReadyExport {
        guard data.count <= 20 * 1_024 * 1_024 else { throw WorkspaceRestoreError.tooLarge }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let envelope = try? decoder.decode(RestoreArchiveEnvelope.self, from: data) else {
            throw WorkspaceRestoreError.malformed
        }
        guard envelope.identifier == RoleReadyExport.formatIdentifier else {
            throw WorkspaceRestoreError.wrongFormat
        }
        guard (1...RoleReadyExport.formatVersion).contains(envelope.version) else {
            throw WorkspaceRestoreError.unsupportedVersion(envelope.version)
        }
        guard let archive = try? decoder.decode(RoleReadyExport.self, from: data) else {
            throw WorkspaceRestoreError.malformed
        }
        return archive
    }

    private func validatedArchive(from data: Data, in context: ModelContext) throws -> ValidatedRestoreArchive {
        let archive = try decode(data)
        let localProfiles = try context.fetch(FetchDescriptor<CareerProfile>())
        let localExperiences = try context.fetch(FetchDescriptor<Experience>())
        let localOpportunities = try context.fetch(FetchDescriptor<Opportunity>())
        let localAnswers = try context.fetch(FetchDescriptor<GeneratedAnswer>())
        let localReflections = try context.fetch(FetchDescriptor<InterviewReflection>())
        let localSources = try context.fetch(FetchDescriptor<CareerSource>())
        let localSpans = try context.fetch(FetchDescriptor<CareerSourceSpan>())
        let localPositions = try context.fetch(FetchDescriptor<CareerPosition>())
        let localEducation = try context.fetch(FetchDescriptor<CareerEducation>())
        let localCertifications = try context.fetch(FetchDescriptor<CareerCertification>())
        let localCareerSkills = try context.fetch(FetchDescriptor<CareerSkill>())
        let localResumes = try context.fetch(FetchDescriptor<ResumeVersion>())
        let localCoverLetters = try context.fetch(FetchDescriptor<CoverLetter>())
        let localActivities = try context.fetch(FetchDescriptor<ApplicationActivity>())
        let localReminders = try context.fetch(FetchDescriptor<CareerReminder>())
        let localExperienceIDs = Set(localExperiences.map(\.id))
        let localOpportunityIDs = Set(localOpportunities.map(\.id))
        let localRequirementIDs = Set(try context.fetch(FetchDescriptor<JobRequirement>()).map(\.id))
        let localAnswerIDs = Set(localAnswers.map(\.id))
        let localSessionIDs = Set(try context.fetch(FetchDescriptor<PracticeSession>()).map(\.id))
        let localReflectionIDs = Set(localReflections.map(\.id))
        let localSourceIDs = Set(localSources.map(\.id))
        let localSpanIDs = Set(localSpans.map(\.id))
        let localPositionIDs = Set(localPositions.map(\.id))
        let localEducationIDs = Set(localEducation.map(\.id))
        let localCertificationIDs = Set(localCertifications.map(\.id))
        let localCareerSkillIDs = Set(localCareerSkills.map(\.id))
        let localResumeIDs = Set(localResumes.map(\.id))
        let localCoverLetterIDs = Set(localCoverLetters.map(\.id))
        let localActivityIDs = Set(localActivities.map(\.id))
        let localReminderIDs = Set(localReminders.map(\.id))

        var valid = ValidatedRestoreArchive(archive: archive)

        var seenSources: Set<UUID> = []
        for item in archive.careerSources {
            guard seenSources.insert(item.id).inserted, !localSourceIDs.contains(item.id) else {
                valid.duplicates.careerSources += 1
                continue
            }
            guard CareerSourceKind(rawValue: item.kind) != nil,
                  Confidentiality(rawValue: item.confidentiality) != nil,
                  !item.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                valid.rejected.careerSources += 1
                continue
            }
            valid.careerSources.append(item)
            valid.importable.careerSources += 1
        }
        let availableSourceIDs = localSourceIDs.union(valid.careerSources.map(\.id))

        let restorableProfiles = archive.profiles.filter {
            $0.sourceID.map(availableSourceIDs.contains) ?? true
        }
        if localProfiles.isEmpty, let profile = restorableProfiles.first {
            valid.profiles = [profile]
            valid.importable.profiles = 1
            valid.duplicates.profiles = max(archive.profiles.count - 1, 0)
        } else if localProfiles.count == 1,
                  let localProfile = localProfiles.first,
                  isEmptyStarterProfile(localProfile),
                  let profile = restorableProfiles.first {
            valid.profiles = [profile]
            valid.emptyProfileID = localProfile.id
            valid.importable.profiles = 1
            valid.duplicates.profiles = max(archive.profiles.count - 1, 0)
        } else {
            valid.duplicates.profiles = archive.profiles.count
        }

        var seenExperiences: Set<UUID> = []
        for item in archive.experiences {
            guard seenExperiences.insert(item.id).inserted, !localExperienceIDs.contains(item.id) else {
                valid.duplicates.experiences += 1
                continue
            }
            guard ExperienceKind(rawValue: item.kind) != nil,
                  OwnershipLevel(rawValue: item.ownership) != nil,
                  Confidentiality(rawValue: item.confidentiality) != nil,
                  item.sourceID.map(availableSourceIDs.contains) ?? true,
                  item.verificationStatus.map({ CareerRecordStatus(rawValue: $0) != nil }) ?? true,
                  item.capabilities.allSatisfy({ Capability(rawValue: $0) != nil }),
                  !item.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                valid.rejected.experiences += 1
                continue
            }
            valid.experiences.append(item)
            valid.importable.experiences += 1
        }

        var seenPositions: Set<UUID> = []
        for item in archive.positions {
            guard seenPositions.insert(item.id).inserted, !localPositionIDs.contains(item.id) else {
                valid.duplicates.positions += 1
                continue
            }
            guard item.sourceID.map(availableSourceIDs.contains) ?? true,
                  EmploymentType(rawValue: item.employmentType) != nil,
                  CareerRecordStatus(rawValue: item.verificationStatus) != nil,
                  Confidentiality(rawValue: item.confidentiality) != nil,
                  !item.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                valid.rejected.positions += 1
                continue
            }
            valid.positions.append(item)
            valid.importable.positions += 1
        }

        var seenEducation: Set<UUID> = []
        for item in archive.education {
            guard seenEducation.insert(item.id).inserted, !localEducationIDs.contains(item.id) else {
                valid.duplicates.education += 1
                continue
            }
            guard item.sourceID.map(availableSourceIDs.contains) ?? true,
                  CareerRecordStatus(rawValue: item.verificationStatus) != nil,
                  Confidentiality(rawValue: item.confidentiality) != nil,
                  ![item.institution, item.qualification].allSatisfy({ $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
                valid.rejected.education += 1
                continue
            }
            valid.education.append(item)
            valid.importable.education += 1
        }

        var seenCertifications: Set<UUID> = []
        for item in archive.certifications {
            guard seenCertifications.insert(item.id).inserted, !localCertificationIDs.contains(item.id) else {
                valid.duplicates.certifications += 1
                continue
            }
            guard item.sourceID.map(availableSourceIDs.contains) ?? true,
                  CareerRecordStatus(rawValue: item.verificationStatus) != nil,
                  Confidentiality(rawValue: item.confidentiality) != nil,
                  !item.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                valid.rejected.certifications += 1
                continue
            }
            valid.certifications.append(item)
            valid.importable.certifications += 1
        }

        var seenCareerSkills: Set<UUID> = []
        for item in archive.careerSkills {
            guard seenCareerSkills.insert(item.id).inserted, !localCareerSkillIDs.contains(item.id) else {
                valid.duplicates.careerSkills += 1
                continue
            }
            guard item.sourceID.map(availableSourceIDs.contains) ?? true,
                  SkillLevel(rawValue: item.level) != nil,
                  CareerRecordStatus(rawValue: item.verificationStatus) != nil,
                  Confidentiality(rawValue: item.confidentiality) != nil,
                  item.yearsExperience >= 0,
                  !item.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                valid.rejected.careerSkills += 1
                continue
            }
            valid.careerSkills.append(item)
            valid.importable.careerSkills += 1
        }

        var seenOpportunities: Set<UUID> = []
        for item in archive.opportunities {
            guard seenOpportunities.insert(item.id).inserted, !localOpportunityIDs.contains(item.id) else {
                valid.duplicates.opportunities += 1
                continue
            }
            guard OpportunityStatus(rawValue: item.status) != nil,
                  !item.roleTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                valid.rejected.opportunities += 1
                continue
            }
            valid.opportunities.append(item)
            valid.importable.opportunities += 1
        }

        let availableExperienceIDs = localExperienceIDs.union(valid.experiences.map(\.id))
        let availableOpportunityIDs = localOpportunityIDs.union(valid.opportunities.map(\.id))

        valid.experienceSources = Dictionary(uniqueKeysWithValues: localExperiences.map {
            ($0.id, RestoreExperienceSource(experience: GroundedExperience($0), updatedAt: $0.updatedAt))
        })
        for item in valid.experiences {
            if let source = experienceSource(from: item, archiveCreatedAt: archive.createdAt) {
                valid.experienceSources[item.id] = source
            }
        }
        valid.opportunitySources = Dictionary(uniqueKeysWithValues: localOpportunities.map {
            ($0.id, RestoreOpportunitySource(roleTitle: $0.roleTitle, contentUpdatedAt: $0.contentUpdatedAt))
        })
        for item in valid.opportunities {
            valid.opportunitySources[item.id] = RestoreOpportunitySource(
                roleTitle: item.roleTitle,
                contentUpdatedAt: item.contentUpdatedAt
            )
        }

        var seenRequirements: Set<UUID> = []
        for item in archive.requirements {
            guard seenRequirements.insert(item.id).inserted, !localRequirementIDs.contains(item.id) else {
                valid.duplicates.requirements += 1
                continue
            }
            guard availableOpportunityIDs.contains(item.opportunityID),
                  RequirementKind(rawValue: item.kind) != nil,
                  item.capabilities.allSatisfy({ Capability(rawValue: $0) != nil }),
                  !item.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                valid.rejected.requirements += 1
                continue
            }
            valid.requirements.append(item)
            valid.importable.requirements += 1
        }

        var seenResumes: Set<UUID> = []
        var resumeCandidates: [RoleReadyExport.ResumeDTO] = []
        for item in archive.resumes {
            guard seenResumes.insert(item.id).inserted, !localResumeIDs.contains(item.id) else {
                valid.duplicates.resumes += 1
                continue
            }
            guard item.sourceID.map(availableSourceIDs.contains) ?? true,
                  item.opportunityID.map(availableOpportunityIDs.contains) ?? true,
                  item.parentVersionID != item.id,
                  ResumeTemplate(rawValue: item.template) != nil,
                  ResumeStatus(rawValue: item.status) != nil,
                  !item.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                valid.rejected.resumes += 1
                continue
            }
            resumeCandidates.append(item)
        }
        let resumeCandidateIDs = Set(resumeCandidates.map(\.id))
        let possibleResumeParentIDs = localResumeIDs.union(resumeCandidateIDs)
        let resumeCandidatesByID = Dictionary(uniqueKeysWithValues: resumeCandidates.map { ($0.id, $0) })
        for item in resumeCandidates {
            guard item.parentVersionID.map(possibleResumeParentIDs.contains) ?? true,
                  !resumeParentChainHasCycle(startingAt: item.id, resumesByID: resumeCandidatesByID) else {
                valid.rejected.resumes += 1
                continue
            }
            valid.resumes.append(item)
            valid.importable.resumes += 1
        }
        let restorableResumeIDs = localResumeIDs.union(valid.resumes.map(\.id))

        var groundingEntityIDs = Set(localProfiles.map(\.id))
        groundingEntityIDs.formUnion(localExperienceIDs)
        groundingEntityIDs.formUnion(localSourceIDs)
        groundingEntityIDs.formUnion(localPositionIDs)
        groundingEntityIDs.formUnion(localEducationIDs)
        groundingEntityIDs.formUnion(localCertificationIDs)
        groundingEntityIDs.formUnion(localCareerSkillIDs)
        if valid.emptyProfileID == nil { groundingEntityIDs.formUnion(valid.profiles.map(\.id)) }
        groundingEntityIDs.formUnion(valid.experiences.map(\.id))
        groundingEntityIDs.formUnion(valid.careerSources.map(\.id))
        groundingEntityIDs.formUnion(valid.positions.map(\.id))
        groundingEntityIDs.formUnion(valid.education.map(\.id))
        groundingEntityIDs.formUnion(valid.certifications.map(\.id))
        groundingEntityIDs.formUnion(valid.careerSkills.map(\.id))
        valid.groundingEntityIDs = groundingEntityIDs
        valid.requirementIDs = localRequirementIDs.union(valid.requirements.map(\.id))

        var seenCoverLetters: Set<UUID> = []
        for item in archive.coverLetters {
            guard seenCoverLetters.insert(item.id).inserted, !localCoverLetterIDs.contains(item.id) else {
                valid.duplicates.coverLetters += 1
                continue
            }
            guard availableOpportunityIDs.contains(item.opportunityID),
                  item.resumeVersionID.map(restorableResumeIDs.contains) ?? true,
                  CoverLetterStatus(rawValue: item.status) != nil,
                  !item.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  !item.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                valid.rejected.coverLetters += 1
                continue
            }
            valid.coverLetters.append(item)
            valid.importable.coverLetters += 1
        }

        var seenActivities: Set<UUID> = []
        for item in archive.activities {
            guard seenActivities.insert(item.id).inserted, !localActivityIDs.contains(item.id) else {
                valid.duplicates.activities += 1
                continue
            }
            guard availableOpportunityIDs.contains(item.opportunityID),
                  ApplicationActivityKind(rawValue: item.kind) != nil,
                  !item.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                valid.rejected.activities += 1
                continue
            }
            valid.activities.append(item)
            valid.importable.activities += 1
        }
        let restorableActivityIDs = localActivityIDs.union(valid.activities.map(\.id))

        var seenReminders: Set<UUID> = []
        for item in archive.reminders {
            guard seenReminders.insert(item.id).inserted, !localReminderIDs.contains(item.id) else {
                valid.duplicates.reminders += 1
                continue
            }
            guard item.opportunityID.map(availableOpportunityIDs.contains) ?? true,
                  item.activityID.map(restorableActivityIDs.contains) ?? true,
                  CareerReminderKind(rawValue: item.kind) != nil,
                  !item.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                valid.rejected.reminders += 1
                continue
            }
            valid.reminders.append(item)
            valid.importable.reminders += 1
        }

        var seenAnswers: Set<UUID> = []
        for item in archive.answers {
            guard seenAnswers.insert(item.id).inserted, !localAnswerIDs.contains(item.id) else {
                valid.duplicates.answers += 1
                continue
            }
            guard availableExperienceIDs.contains(item.experienceID),
                  item.opportunityID.map(availableOpportunityIDs.contains) ?? true,
                  AnswerFormat(rawValue: item.format) != nil,
                  AnswerAudience(rawValue: item.audience) != nil,
                  AnswerTone(rawValue: item.tone) != nil,
                  !item.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                valid.rejected.answers += 1
                continue
            }
            valid.answers.append(item)
            valid.importable.answers += 1
            if answerApprovalIsRestorable(item, archiveVersion: archive.version, in: valid) {
                valid.approvableAnswerIDs.insert(item.id)
            }
        }

        let availableAnswerIDs = localAnswerIDs.union(valid.answers.map(\.id))
        var answerAssociations = Dictionary(uniqueKeysWithValues: localAnswers.map {
            ($0.id, RestoreAnswerAssociation(experienceID: $0.experienceID, opportunityID: $0.opportunityID))
        })
        for item in valid.answers {
            answerAssociations[item.id] = RestoreAnswerAssociation(
                experienceID: item.experienceID,
                opportunityID: item.opportunityID
            )
        }
        var seenSessions: Set<UUID> = []
        for item in archive.practiceSessions {
            guard seenSessions.insert(item.id).inserted, !localSessionIDs.contains(item.id) else {
                valid.duplicates.practiceSessions += 1
                continue
            }
            guard availableAnswerIDs.contains(item.answerID) else {
                valid.rejected.practiceSessions += 1
                continue
            }
            guard item.experienceID.map(availableExperienceIDs.contains) ?? true,
                  item.opportunityID.map(availableOpportunityIDs.contains) ?? true else {
                valid.rejected.practiceSessions += 1
                continue
            }
            guard let answerAssociation = answerAssociations[item.answerID],
                  item.experienceID.map({ $0 == answerAssociation.experienceID }) ?? true,
                  item.opportunityID.map({ $0 == answerAssociation.opportunityID }) ?? true else {
                valid.rejected.practiceSessions += 1
                continue
            }
            valid.practiceSessions.append(item)
            valid.importable.practiceSessions += 1
        }

        var seenReflections: Set<UUID> = []
        var seenReflectionOpportunityIDs = Set(localReflections.map(\.opportunityID))
        for item in archive.reflections {
            guard seenReflections.insert(item.id).inserted,
                  !localReflectionIDs.contains(item.id),
                  seenReflectionOpportunityIDs.insert(item.opportunityID).inserted else {
                valid.duplicates.reflections += 1
                continue
            }
            guard availableOpportunityIDs.contains(item.opportunityID),
                  item.experienceIDs.allSatisfy(availableExperienceIDs.contains) else {
                valid.rejected.reflections += 1
                continue
            }
            valid.reflections.append(item)
            valid.importable.reflections += 1
        }

        let localEntityIDs = Set(localProfiles.map(\.id))
            .union(localExperienceIDs)
            .union(localOpportunityIDs)
            .union(localRequirementIDs)
            .union(localSourceIDs)
            .union(localPositionIDs)
            .union(localEducationIDs)
            .union(localCertificationIDs)
            .union(localCareerSkillIDs)
            .union(localResumeIDs)
            .union(localCoverLetterIDs)
            .union(localActivityIDs)
            .union(localReminderIDs)
            .union(localAnswerIDs)
            .union(localSessionIDs)
            .union(localReflectionIDs)
        let importedEntityIDs = Set(valid.profiles.map(\.id))
            .union(valid.experiences.map(\.id))
            .union(valid.opportunities.map(\.id))
            .union(valid.requirements.map(\.id))
            .union(valid.careerSources.map(\.id))
            .union(valid.positions.map(\.id))
            .union(valid.education.map(\.id))
            .union(valid.certifications.map(\.id))
            .union(valid.careerSkills.map(\.id))
            .union(valid.resumes.map(\.id))
            .union(valid.coverLetters.map(\.id))
            .union(valid.activities.map(\.id))
            .union(valid.reminders.map(\.id))
            .union(valid.answers.map(\.id))
            .union(valid.practiceSessions.map(\.id))
            .union(valid.reflections.map(\.id))
        let availableEntityIDs = localEntityIDs.union(importedEntityIDs)
        var sourceTextByID = Dictionary(uniqueKeysWithValues: localSources.map { ($0.id, $0.rawText) })
        for source in valid.careerSources { sourceTextByID[source.id] = source.rawText }
        var seenSpans: Set<UUID> = []
        for item in archive.sourceSpans {
            guard seenSpans.insert(item.id).inserted, !localSpanIDs.contains(item.id) else {
                valid.duplicates.sourceSpans += 1
                continue
            }
            guard availableSourceIDs.contains(item.sourceID),
                  availableEntityIDs.contains(item.entityID),
                  !item.entityType.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  !item.fieldPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  item.startOffset >= 0,
                  item.endOffset >= item.startOffset,
                  sourceTextByID[item.sourceID].map({ $0.isEmpty || item.endOffset <= $0.count }) ?? false,
                  (0...1).contains(item.confidence) else {
                valid.rejected.sourceSpans += 1
                continue
            }
            valid.sourceSpans.append(item)
            valid.importable.sourceSpans += 1
        }

        var warnings: [String] = []
        if archive.version == 1 {
            warnings.append("This is a version 1 export. Saved answers will return as drafts because their edited-source status cannot be proven.")
            if valid.experiences.contains(where: {
                Confidentiality(rawValue: $0.confidentiality)?.blocksAutomaticUse == true
            }) {
                warnings.append("Highly sensitive version 1 examples will stay disabled for automatic matching until you approve them again.")
            }
        } else if archive.version == 2 {
            warnings.append("This is a version 2 export. Existing interview records can be restored, but it predates résumé, cover-letter and application-workspace backup support.")
        }
        let containsConfidentialExamples = archive.experiences.contains {
            guard let confidentiality = Confidentiality(rawValue: $0.confidentiality) else { return false }
            return confidentiality >= .confidential
        }
        if !archive.includesConfidential && containsConfidentialExamples {
            warnings.append("This export is labelled reduced sensitivity but contains confidential examples. Review its source before restoring.")
        } else if !archive.includesConfidential {
            warnings.append("This reduced-sensitivity export omits confidential examples, imported source text and spans, full job advertisements, private contact and activity notes, notification registrations and interview reflections.")
        }
        if valid.duplicates.total > 0 {
            warnings.append("\(valid.duplicates.total) existing or repeated record\(valid.duplicates.total == 1 ? "" : "s") will be kept from this device and skipped.")
        }
        if valid.rejected.total > 0 {
            warnings.append("\(valid.rejected.total) incomplete or invalid record\(valid.rejected.total == 1 ? "" : "s") will be skipped; valid independent records can still be restored.")
        }
        if valid.emptyProfileID != nil {
            warnings.append("Your empty starter profile will be filled from this export. Profile information you have entered is never replaced.")
        }
        valid.preview = WorkspaceRestorePreview(
            sourceVersion: archive.version,
            createdAt: archive.createdAt,
            includesConfidential: archive.includesConfidential || containsConfidentialExamples,
            importable: valid.importable,
            duplicates: valid.duplicates,
            rejected: valid.rejected,
            warnings: warnings
        )
        return valid
    }

    private func isEmptyStarterProfile(_ profile: CareerProfile) -> Bool {
        [
            profile.name,
            profile.headline,
            profile.professionalSummary,
            profile.currentOrganisation,
            profile.careerGoal
        ].allSatisfy { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            && profile.targetRoles.isEmpty
            && profile.skills.isEmpty
            && !profile.isSample
    }

    private func matchingApproval(for item: RoleReadyExport.ExperienceDTO) -> Bool {
        guard let confidentiality = Confidentiality(rawValue: item.confidentiality) else { return false }
        return item.isApprovedForMatching ?? !confidentiality.blocksAutomaticUse
    }

    private func experienceSource(
        from item: RoleReadyExport.ExperienceDTO,
        archiveCreatedAt: Date
    ) -> RestoreExperienceSource? {
        guard let ownership = OwnershipLevel(rawValue: item.ownership),
              let confidentiality = Confidentiality(rawValue: item.confidentiality) else { return nil }
        return RestoreExperienceSource(
            experience: GroundedExperience(
                id: item.id,
                title: item.title,
                organisation: item.organisation,
                situation: item.situation,
                task: item.task,
                actions: item.actions,
                result: item.result,
                evidence: item.evidence,
                learning: item.learning,
                ownership: ownership,
                capabilities: item.capabilities.compactMap(Capability.init(rawValue:)),
                tools: item.tools,
                confidentiality: confidentiality,
                isApprovedForMatching: matchingApproval(for: item)
            ),
            updatedAt: item.updatedAt ?? archiveCreatedAt
        )
    }

    private func answerApprovalIsRestorable(
        _ item: RoleReadyExport.AnswerDTO,
        archiveVersion: Int,
        in validated: ValidatedRestoreArchive
    ) -> Bool {
        guard archiveVersion == RoleReadyExport.formatVersion,
              item.isFactConfirmed,
              let format = AnswerFormat(rawValue: item.format),
              let audience = AnswerAudience(rawValue: item.audience),
              let tone = AnswerTone(rawValue: item.tone),
              let source = validated.experienceSources[item.experienceID],
              !source.experience.confidentiality.blocksAutomaticUse || source.experience.isApprovedForMatching,
              source.updatedAt <= item.sourceExperienceUpdatedAt,
              !item.sourceClaims.isEmpty else { return false }

        let opportunity = item.opportunityID.flatMap { validated.opportunitySources[$0] }
        if item.opportunityID != nil {
            guard let opportunity,
                  let recordedOpportunityDate = item.sourceOpportunityUpdatedAt,
                  opportunity.contentUpdatedAt <= recordedOpportunityDate else { return false }
        }

        let roleTitle = opportunity?.roleTitle ?? ""
        let allowedContext = [item.question, roleTitle]
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let provenance = AnswerProvenanceService()
        let claims = AnswerClaimValidator().validate(
            item.sourceClaims,
            question: item.question,
            format: format,
            audience: audience,
            tone: tone,
            roleTitle: roleTitle,
            experience: source.experience
        )
        guard claims.count == item.sourceClaims.count,
              claims.allSatisfy({ !$0.needsSource }) else { return false }

        guard provenance.claimsCompletelyCover(content: item.content, claims: claims) else { return false }

        let wordCount = item.content.split(whereSeparator: \.isWhitespace).count
        guard format.targetWordCount.contains(wordCount) else { return false }
        let blockingWarnings = GroundedAnswerEngine().reviewWarnings(
            output: item.content,
            against: source.experience,
            allowedContext: allowedContext
        ).filter {
            !$0.localizedCaseInsensitiveContains("uses a confidential example")
                && !$0.localizedCaseInsensitiveContains("uses a highly sensitive example")
        }
        return blockingWarnings.isEmpty
    }

    private func resumeParentChainHasCycle(
        startingAt id: UUID,
        resumesByID: [UUID: RoleReadyExport.ResumeDTO]
    ) -> Bool {
        var visited: Set<UUID> = []
        var currentID: UUID? = id
        while let candidateID = currentID, let candidate = resumesByID[candidateID] {
            guard visited.insert(candidateID).inserted else { return true }
            currentID = candidate.parentVersionID
        }
        return false
    }

    private func sanitizedResume(
        document: ResumeDocument,
        report: TailoringReport,
        status: ResumeStatus,
        allowedEntityIDs: Set<UUID>,
        allowedRequirementIDs: Set<UUID>
    ) -> (document: ResumeDocument, report: TailoringReport, status: ResumeStatus) {
        var document = document
        var report = report
        var removedProvenance = false

        for sectionIndex in document.sections.indices {
            for itemIndex in document.sections[sectionIndex].items.indices {
                let originalItemIDs = document.sections[sectionIndex].items[itemIndex].sourceEntityIDs
                let itemIDs = originalItemIDs.filter(allowedEntityIDs.contains)
                document.sections[sectionIndex].items[itemIndex].sourceEntityIDs = itemIDs
                removedProvenance = removedProvenance || itemIDs.count != originalItemIDs.count

                for bulletIndex in document.sections[sectionIndex].items[itemIndex].bullets.indices {
                    var bullet = document.sections[sectionIndex].items[itemIndex].bullets[bulletIndex]
                    let originalBulletIDs = bullet.sourceEntityIDs
                    bullet.sourceEntityIDs = originalBulletIDs.filter(allowedEntityIDs.contains)
                    if bullet.sourceEntityIDs.count != originalBulletIDs.count
                        || (bullet.isApproved && bullet.sourceEntityIDs.isEmpty) {
                        removedProvenance = true
                        bullet.isApproved = false
                        bullet.evidence = .noEvidence
                        var warnings = bullet.validationWarnings ?? []
                        warnings.append("Approval was removed during restore because linked career evidence was unavailable.")
                        bullet.validationWarnings = Array(Set(warnings)).sorted()
                    }
                    document.sections[sectionIndex].items[itemIndex].bullets[bulletIndex] = bullet
                }
            }
        }

        var matches: [TailoringEvidenceMatch] = []
        for var match in report.matches {
            guard allowedRequirementIDs.contains(match.requirementID) else {
                removedProvenance = true
                continue
            }
            let originalIDs = match.sourceEntityIDs
            match.sourceEntityIDs = originalIDs.filter(allowedEntityIDs.contains)
            if match.sourceEntityIDs.count != originalIDs.count
                || (match.classification != .noEvidence && match.sourceEntityIDs.isEmpty) {
                removedProvenance = true
                match.classification = .noEvidence
                match.sourceExcerpts = []
                match.reason = "Linked career evidence was unavailable after restore."
                match.followUpQuestion = "Can you add or approve career evidence for this requirement?"
            }
            matches.append(match)
        }
        report.matches = matches
        if removedProvenance {
            report.validationWarnings.append("Some evidence links were unavailable during restore. Review this résumé before marking it ready.")
            report.validationWarnings = Array(Set(report.validationWarnings)).sorted()
        }
        return (document, report, removedProvenance && status == .ready ? .draft : status)
    }

    private func sanitizedCoverLetter(
        _ item: RoleReadyExport.CoverLetterDTO,
        status: CoverLetterStatus,
        allowedEntityIDs: Set<UUID>
    ) -> (
        grounding: CoverLetterGrounding,
        warnings: [String],
        sourceEntityIDs: [UUID],
        status: CoverLetterStatus
    ) {
        var grounding = item.grounding
        var warnings = item.validationWarnings
        let sourceEntityIDs = item.sourceEntityIDs.filter(allowedEntityIDs.contains)
        var removedProvenance = sourceEntityIDs.count != item.sourceEntityIDs.count

        for index in grounding.paragraphs.indices {
            let originalIDs = grounding.paragraphs[index].sourceEntityIDs
            grounding.paragraphs[index].sourceEntityIDs = originalIDs.filter(allowedEntityIDs.contains)
            if grounding.paragraphs[index].sourceEntityIDs.count != originalIDs.count
                || (grounding.paragraphs[index].isApproved
                    && grounding.paragraphs[index].claimType == "career evidence"
                    && grounding.paragraphs[index].sourceEntityIDs.isEmpty) {
                removedProvenance = true
                grounding.paragraphs[index].isApproved = false
                grounding.paragraphs[index].validationWarnings.append(
                    "Approval was removed during restore because linked career evidence was unavailable."
                )
                grounding.paragraphs[index].validationWarnings = Array(
                    Set(grounding.paragraphs[index].validationWarnings)
                ).sorted()
            }
        }
        if removedProvenance {
            let warning = "Some evidence links were unavailable during restore. Review factual claims before approval."
            warnings.append(warning)
            grounding.validationWarnings.append(warning)
            warnings = Array(Set(warnings)).sorted()
            grounding.validationWarnings = Array(Set(grounding.validationWarnings)).sorted()
        }
        let restoredStatus: CoverLetterStatus = removedProvenance && status == .approved ? .draft : status
        return (grounding, warnings, sourceEntityIDs, restoredStatus)
    }

}

private struct RestoreArchiveEnvelope: Decodable {
    let identifier: String
    let version: Int
}

private struct RestoreExperienceSource {
    let experience: GroundedExperience
    let updatedAt: Date
}

private struct RestoreOpportunitySource {
    let roleTitle: String
    let contentUpdatedAt: Date
}

private struct RestoreAnswerAssociation {
    let experienceID: UUID
    let opportunityID: UUID?
}

private struct ValidatedRestoreArchive {
    let archive: RoleReadyExport
    var profiles: [RoleReadyExport.ProfileDTO] = []
    var experiences: [RoleReadyExport.ExperienceDTO] = []
    var opportunities: [RoleReadyExport.OpportunityDTO] = []
    var requirements: [RoleReadyExport.RequirementDTO] = []
    var answers: [RoleReadyExport.AnswerDTO] = []
    var practiceSessions: [RoleReadyExport.PracticeSessionDTO] = []
    var reflections: [RoleReadyExport.ReflectionDTO] = []
    var careerSources: [RoleReadyExport.CareerSourceDTO] = []
    var sourceSpans: [RoleReadyExport.SourceSpanDTO] = []
    var positions: [RoleReadyExport.PositionDTO] = []
    var education: [RoleReadyExport.EducationDTO] = []
    var certifications: [RoleReadyExport.CertificationDTO] = []
    var careerSkills: [RoleReadyExport.CareerSkillDTO] = []
    var resumes: [RoleReadyExport.ResumeDTO] = []
    var coverLetters: [RoleReadyExport.CoverLetterDTO] = []
    var activities: [RoleReadyExport.ActivityDTO] = []
    var reminders: [RoleReadyExport.ReminderDTO] = []
    var emptyProfileID: UUID?
    var experienceSources: [UUID: RestoreExperienceSource] = [:]
    var opportunitySources: [UUID: RestoreOpportunitySource] = [:]
    var approvableAnswerIDs: Set<UUID> = []
    var groundingEntityIDs: Set<UUID> = []
    var requirementIDs: Set<UUID> = []
    var importable = RestoreRecordCounts()
    var duplicates = RestoreRecordCounts()
    var rejected = RestoreRecordCounts()
    var preview: WorkspaceRestorePreview

    init(archive: RoleReadyExport) {
        self.archive = archive
        preview = WorkspaceRestorePreview(
            sourceVersion: archive.version,
            createdAt: archive.createdAt,
            includesConfidential: archive.includesConfidential,
            importable: RestoreRecordCounts(),
            duplicates: RestoreRecordCounts(),
            rejected: RestoreRecordCounts(),
            warnings: []
        )
    }
}
