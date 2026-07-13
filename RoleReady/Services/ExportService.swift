import Foundation
import SwiftData

struct RoleReadyExport: Codable {
    static let formatIdentifier = "com.roleready.export"
    static let formatVersion = 1

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

    struct ProfileDTO: Codable {
        let id: UUID
        let name: String
        let headline: String
        let professionalSummary: String
        let currentOrganisation: String
        let targetRoles: [String]
        let skills: [String]
        let careerGoal: String
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
    }

    struct OpportunityDTO: Codable {
        let id: UUID
        let roleTitle: String
        let organisation: String
        let location: String
        let sourceText: String
        let status: String
        let closingDate: Date?
        let interviewDate: Date?
        let notes: String
        let contentUpdatedAt: Date
    }

    struct RequirementDTO: Codable {
        let id: UUID
        let opportunityID: UUID
        let text: String
        let kind: String
        let keywords: [String]
        let capabilities: [String]
        let importance: Int
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
                createdAt: item.createdAt
            )
        }

        let export = RoleReadyExport(
            identifier: RoleReadyExport.formatIdentifier,
            version: RoleReadyExport.formatVersion,
            createdAt: Date(),
            includesConfidential: includeConfidential,
            profiles: profiles.map { profile in
                .init(id: profile.id, name: profile.name, headline: profile.headline, professionalSummary: profile.professionalSummary, currentOrganisation: profile.currentOrganisation, targetRoles: profile.targetRoles, skills: profile.skills, careerGoal: profile.careerGoal)
            },
            experiences: experiences.map { item in
                .init(id: item.id, title: item.title, organisation: item.organisation, occurredAt: item.occurredAt, kind: item.kind.rawValue, situation: item.situation, task: item.task, actions: item.actions, result: item.result, evidence: item.evidence, learning: item.learning, ownership: item.ownership.rawValue, capabilities: item.capabilities.map(\.rawValue), tools: item.tools, confidentiality: item.confidentiality.rawValue)
            },
            opportunities: opportunities.map { item in
                .init(
                    id: item.id,
                    roleTitle: item.roleTitle,
                    organisation: item.organisation,
                    location: item.location,
                    sourceText: includeConfidential ? item.sourceText : "",
                    status: item.status.rawValue,
                    closingDate: item.closingDate,
                    interviewDate: item.interviewDate,
                    notes: includeConfidential ? item.notes : "",
                    contentUpdatedAt: item.contentUpdatedAt
                )
            },
            requirements: requirements.map { item in
                .init(id: item.id, opportunityID: item.opportunityID, text: item.text, kind: item.kind.rawValue, keywords: item.keywords, capabilities: item.capabilities.map(\.rawValue), importance: item.importance)
            },
            answers: answers.map { item in
                .init(id: item.id, question: item.question, experienceID: item.experienceID, opportunityID: item.opportunityID, format: item.format.rawValue, audience: item.audience.rawValue, tone: item.tone.rawValue, content: item.content, quickCues: item.quickCues, sourceFields: item.sourceFields, sourceClaims: item.sourceClaims, followUps: item.followUps, isFactConfirmed: item.isFactConfirmed, sourceExperienceUpdatedAt: item.sourceExperienceUpdatedAt, sourceOpportunityUpdatedAt: item.sourceOpportunityUpdatedAt, createdAt: item.createdAt)
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
            reflections: reflections
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
