import Foundation

enum LanguageServiceKind: String, Codable, Sendable {
    case deterministicLocal
    case appleOnDevice
    case optionalCloud
}

struct LanguageServiceDescriptor: Hashable, Sendable {
    let kind: LanguageServiceKind
    let displayName: String
    let sendsDataOffDevice: Bool
    let isAvailable: Bool
}

struct CareerExtractionRequest: Hashable, Sendable {
    let text: String
}

struct AnswerCompositionRequest: Hashable, Sendable {
    let question: String
    let experience: GroundedExperience
    let format: AnswerFormat
    let audience: AnswerAudience
    let tone: AnswerTone
    let roleTitle: String?
}

struct RequirementGroupingRequest: Hashable, Sendable {
    let jobText: String
}

protocol RoleReadyLanguageService: Sendable {
    var descriptor: LanguageServiceDescriptor { get }

    func extractCareerExamples(_ request: CareerExtractionRequest) async throws -> CareerHistoryIngestionResult
    func groupRequirements(_ request: RequirementGroupingRequest) async throws -> ParsedJob
    func composeAnswer(_ request: AnswerCompositionRequest) async throws -> GeneratedDraft
}

struct DeterministicLanguageService: RoleReadyLanguageService {
    let descriptor = LanguageServiceDescriptor(
        kind: .deterministicLocal,
        displayName: "On-device deterministic",
        sendsDataOffDevice: false,
        isAvailable: true
    )

    func extractCareerExamples(_ request: CareerExtractionRequest) async throws -> CareerHistoryIngestionResult {
        try Task.checkCancellation()
        return try CareerHistoryIngestionService().extractDrafts(from: request.text)
    }

    func groupRequirements(_ request: RequirementGroupingRequest) async throws -> ParsedJob {
        try Task.checkCancellation()
        return try JobParser().parse(request.jobText)
    }

    func composeAnswer(_ request: AnswerCompositionRequest) async throws -> GeneratedDraft {
        try Task.checkCancellation()
        return try GroundedAnswerEngine().generate(
            question: request.question,
            from: request.experience,
            format: request.format,
            audience: request.audience,
            tone: request.tone,
            roleTitle: request.roleTitle
        )
    }
}
