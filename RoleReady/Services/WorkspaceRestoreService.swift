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
    var experiences = 0
    var opportunities = 0
    var requirements = 0
    var answers = 0
    var practiceSessions = 0
    var reflections = 0

    var total: Int {
        profiles + experiences + opportunities + requirements + answers + practiceSessions + reflections
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
            for item in validated.profiles {
                if let replacementID = validated.emptyProfileID,
                   let profile = try context.fetch(FetchDescriptor<CareerProfile>()).first(where: { $0.id == replacementID }) {
                    profile.name = item.name
                    profile.headline = item.headline
                    profile.professionalSummary = item.professionalSummary
                    profile.currentOrganisation = item.currentOrganisation
                    profile.targetRoles = item.targetRoles
                    profile.skills = item.skills
                    profile.careerGoal = item.careerGoal
                    profile.isSample = item.isSample ?? false
                    profile.updatedAt = item.updatedAt ?? validated.archive.createdAt
                } else {
                    context.insert(CareerProfile(
                        id: item.id,
                        name: item.name,
                        headline: item.headline,
                        professionalSummary: item.professionalSummary,
                        currentOrganisation: item.currentOrganisation,
                        targetRoles: item.targetRoles,
                        skills: item.skills,
                        careerGoal: item.careerGoal,
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
                    isApprovedForMatching: matchingApproval(for: item),
                    isSample: item.isSample ?? false,
                    useCount: item.useCount ?? 0,
                    createdAt: item.createdAt ?? validated.archive.createdAt,
                    updatedAt: item.updatedAt ?? validated.archive.createdAt
                ))
            }

            for item in validated.opportunities {
                guard let status = OpportunityStatus(rawValue: item.status) else { continue }
                context.insert(Opportunity(
                    id: item.id,
                    roleTitle: item.roleTitle,
                    organisation: item.organisation,
                    location: item.location,
                    sourceText: item.sourceText,
                    status: status,
                    closingDate: item.closingDate,
                    interviewDate: item.interviewDate,
                    notes: item.notes,
                    isSample: item.isSample ?? false,
                    createdAt: item.createdAt ?? validated.archive.createdAt,
                    updatedAt: item.updatedAt ?? validated.archive.createdAt,
                    contentUpdatedAt: item.contentUpdatedAt
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
        let localExperienceIDs = Set(localExperiences.map(\.id))
        let localOpportunityIDs = Set(localOpportunities.map(\.id))
        let localRequirementIDs = Set(try context.fetch(FetchDescriptor<JobRequirement>()).map(\.id))
        let localAnswerIDs = Set(localAnswers.map(\.id))
        let localSessionIDs = Set(try context.fetch(FetchDescriptor<PracticeSession>()).map(\.id))
        let localReflectionIDs = Set(localReflections.map(\.id))

        var valid = ValidatedRestoreArchive(archive: archive)

        if localProfiles.isEmpty, let profile = archive.profiles.first {
            valid.profiles = [profile]
            valid.importable.profiles = 1
            valid.duplicates.profiles = max(archive.profiles.count - 1, 0)
        } else if localProfiles.count == 1,
                  let localProfile = localProfiles.first,
                  isEmptyStarterProfile(localProfile),
                  let profile = archive.profiles.first {
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
                  item.capabilities.allSatisfy({ Capability(rawValue: $0) != nil }),
                  !item.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                valid.rejected.experiences += 1
                continue
            }
            valid.experiences.append(item)
            valid.importable.experiences += 1
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

        var warnings: [String] = []
        if archive.version == 1 {
            warnings.append("This is a version 1 export. Saved answers will return as drafts because their edited-source status cannot be proven.")
            if valid.experiences.contains(where: {
                Confidentiality(rawValue: $0.confidentiality)?.blocksAutomaticUse == true
            }) {
                warnings.append("Highly sensitive version 1 examples will stay disabled for automatic matching until you approve them again.")
            }
        }
        let containsConfidentialExamples = archive.experiences.contains {
            guard let confidentiality = Confidentiality(rawValue: $0.confidentiality) else { return false }
            return confidentiality >= .confidential
        }
        if !archive.includesConfidential && containsConfidentialExamples {
            warnings.append("This export is labelled reduced sensitivity but contains confidential examples. Review its source before restoring.")
        } else if !archive.includesConfidential {
            warnings.append("This reduced-sensitivity export does not contain confidential examples, full job advertisements, private role notes or reflections that were omitted when it was created.")
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
    var emptyProfileID: UUID?
    var experienceSources: [UUID: RestoreExperienceSource] = [:]
    var opportunitySources: [UUID: RestoreOpportunitySource] = [:]
    var approvableAnswerIDs: Set<UUID> = []
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
