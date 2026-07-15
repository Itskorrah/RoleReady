import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

enum LanguageServiceKind: String, Codable, Sendable {
    case deterministicLocal
    case appleOnDevice
    case localOpenWeight
    case premiumCloud
}

enum LanguageProviderSelection: String, CaseIterable, Identifiable, Codable, Sendable {
    case automatic
    case deterministic
    case appleFoundation
    case localOpenWeight
    case premiumCloud

    var id: String { rawValue }

    var title: String {
        switch self {
        case .automatic: "Automatic"
        case .deterministic: "Private basic"
        case .appleFoundation: "Apple on-device"
        case .localOpenWeight: "Downloaded local model"
        case .premiumCloud: "Premium cloud"
        }
    }
}

struct LanguageServiceDescriptor: Hashable, Sendable, Identifiable {
    let id: String
    let kind: LanguageServiceKind
    let displayName: String
    let modelName: String
    let sendsDataOffDevice: Bool
    let isAvailable: Bool
    let requiresDownload: Bool
    let costSummary: String
    let privacySummary: String
    let unavailableReason: String?

    init(
        id: String? = nil,
        kind: LanguageServiceKind,
        displayName: String,
        modelName: String = "",
        sendsDataOffDevice: Bool,
        isAvailable: Bool,
        requiresDownload: Bool = false,
        costSummary: String = "No usage charge",
        privacySummary: String = "Stays on this device",
        unavailableReason: String? = nil
    ) {
        self.id = id ?? kind.rawValue
        self.kind = kind
        self.displayName = displayName
        self.modelName = modelName
        self.sendsDataOffDevice = sendsDataOffDevice
        self.isAvailable = isAvailable
        self.requiresDownload = requiresDownload
        self.costSummary = costSummary
        self.privacySummary = privacySummary
        self.unavailableReason = unavailableReason
    }
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

enum LanguageServiceError: LocalizedError, Equatable, Sendable {
    case providerUnavailable(String)
    case invalidStructuredOutput
    case explicitConsentRequired
    case highlySensitiveDataBlocked
    case secureBackendRequired

    var errorDescription: String? {
        switch self {
        case .providerUnavailable(let reason): reason
        case .invalidStructuredOutput: "The AI response did not match RoleReady’s safe structured format. The private basic generator was used instead."
        case .explicitConsentRequired: "Review and approve the exact information that will be sent before using cloud AI."
        case .highlySensitiveDataBlocked: "Highly sensitive career information cannot be sent to cloud AI."
        case .secureBackendRequired: "Premium AI needs a secure RoleReady backend. Provider keys are never stored in the app."
        }
    }
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
        displayName: "Private basic",
        modelName: "RoleReady deterministic engines",
        sendsDataOffDevice: false,
        isAvailable: true,
        privacySummary: "No account, download or network connection"
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

struct AppleFoundationLanguageService: RoleReadyLanguageService {
    var descriptor: LanguageServiceDescriptor {
        let availability = AppleFoundationAvailability.current
        return LanguageServiceDescriptor(
            kind: .appleOnDevice,
            displayName: "Apple on-device",
            modelName: "Apple Foundation Model",
            sendsDataOffDevice: false,
            isAvailable: availability.isAvailable,
            privacySummary: "Runs through Apple Intelligence on this device",
            unavailableReason: availability.reason
        )
    }

    func extractCareerExamples(_ request: CareerExtractionRequest) async throws -> CareerHistoryIngestionResult {
        // Import remains deterministic so a model cannot quietly alter dates, names or employers.
        try await DeterministicLanguageService().extractCareerExamples(request)
    }

    func groupRequirements(_ request: RequirementGroupingRequest) async throws -> ParsedJob {
        // Deterministic parsing is the authoritative fallback and keeps this operation repeatable.
        try await DeterministicLanguageService().groupRequirements(request)
    }

    func composeAnswer(_ request: AnswerCompositionRequest) async throws -> GeneratedDraft {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            return try await AppleFoundationAnswerComposer().compose(request)
        }
        #endif
        throw LanguageServiceError.providerUnavailable("Apple’s on-device model requires iOS 26 or later and an Apple Intelligence-capable device.")
    }
}

private struct AppleFoundationAvailability: Sendable {
    let isAvailable: Bool
    let reason: String?

    static var current: AppleFoundationAvailability {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            switch SystemLanguageModel.default.availability {
            case .available:
                return AppleFoundationAvailability(isAvailable: true, reason: nil)
            case .unavailable(.deviceNotEligible):
                return AppleFoundationAvailability(
                    isAvailable: false,
                    reason: "This device does not support Apple Intelligence. Private basic remains available."
                )
            case .unavailable(.appleIntelligenceNotEnabled):
                return AppleFoundationAvailability(
                    isAvailable: false,
                    reason: "Turn on Apple Intelligence in Settings to use this provider."
                )
            case .unavailable(.modelNotReady):
                return AppleFoundationAvailability(
                    isAvailable: false,
                    reason: "Apple’s on-device model is still downloading or is not ready."
                )
            @unknown default:
                return AppleFoundationAvailability(isAvailable: false, reason: "Apple’s on-device model is not available right now.")
            }
        }
        #endif
        return AppleFoundationAvailability(
            isAvailable: false,
            reason: "Apple’s on-device model requires iOS 26 or later."
        )
    }
}

#if canImport(FoundationModels)
@available(iOS 26.0, *)
private struct AppleFoundationAnswerComposer: Sendable {
    func compose(_ request: AnswerCompositionRequest) async throws -> GeneratedDraft {
        let baseline = try GroundedAnswerEngine().generate(
            question: request.question,
            from: request.experience,
            format: request.format,
            audience: request.audience,
            tone: request.tone,
            roleTitle: request.roleTitle
        )
        let model = SystemLanguageModel.default
        guard model.availability == .available else {
            throw LanguageServiceError.providerUnavailable(
                AppleFoundationAvailability.current.reason ?? "Apple’s on-device model is unavailable."
            )
        }
        let session = LanguageModelSession(
            model: model,
            instructions: """
            You improve the clarity and natural spoken flow of interview answers.
            Use only the supplied approved facts and the supplied role context.
            Never add an employer, role, date, tool, qualification, number, metric, outcome, responsibility or ownership claim.
            Preserve first-person ownership exactly. Return only the revised answer, without commentary.
            """
        )
        let response = try await session.respond(to: prompt(for: request, baseline: baseline))
        try Task.checkCancellation()
        let content = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { throw LanguageServiceError.invalidStructuredOutput }

        let claims = AnswerProvenanceService().reconcile(
            content: content,
            generatedContent: baseline.content,
            generatedClaims: baseline.claims,
            experience: request.experience
        )
        let wordCount = content.split(whereSeparator: \.isWhitespace).count
        var warnings = GroundedAnswerEngine().reviewWarnings(
            output: content,
            against: request.experience,
            allowedContext: [request.question, request.roleTitle ?? ""].joined(separator: " ")
        )
        let unsupportedCount = claims.filter(\.needsSource).count
        if unsupportedCount > 0 {
            warnings.append("Apple’s rewrite contains \(unsupportedCount) changed claim\(unsupportedCount == 1 ? "" : "s") that need evidence review before approval.")
        }
        if !request.format.targetWordCount.contains(wordCount) {
            warnings.append("The answer is \(wordCount) words; the target is \(request.format.targetWordCount.lowerBound)–\(request.format.targetWordCount.upperBound).")
        }
        return GeneratedDraft(
            content: content,
            quickCues: baseline.quickCues,
            claims: claims,
            followUps: baseline.followUps,
            warnings: Array(Set(warnings)).sorted(),
            wordCount: wordCount,
            estimatedSpeakingSeconds: Int((Double(wordCount) / 130 * 60).rounded()),
            targetWordCount: request.format.targetWordCount
        )
    }

    private func prompt(for request: AnswerCompositionRequest, baseline: GeneratedDraft) -> String {
        let experience = request.experience
        return """
        Question: \(request.question)
        Target role: \(request.roleTitle ?? "Not supplied")
        Audience: \(request.audience.title)
        Tone: \(request.tone.title)
        Target length: \(request.format.targetWordCount.lowerBound)-\(request.format.targetWordCount.upperBound) words

        APPROVED FACTS
        Role: \(experience.title)
        Organisation: \(experience.organisation)
        Situation: \(experience.situation)
        Responsibility: \(experience.task)
        Recorded ownership: \(experience.ownership.title)
        Actions: \(experience.actions.joined(separator: " | "))
        Result: \(experience.result)
        Evidence: \(experience.evidence)
        Learning: \(experience.learning)
        Tools: \(experience.tools.joined(separator: ", "))

        SAFE BASELINE DRAFT
        \(baseline.content)

        Revise only for natural flow. If a detail is absent, omit it.
        """
    }
}
#endif

struct LocalOpenWeightLanguageService: RoleReadyLanguageService {
    private let runtime: any LocalOpenWeightRuntime

    init(runtime: any LocalOpenWeightRuntime = UnavailableOpenWeightRuntime()) {
        self.runtime = runtime
    }

    var descriptor: LanguageServiceDescriptor {
        LanguageServiceDescriptor(
            kind: .localOpenWeight,
            displayName: "Downloaded local model",
            modelName: runtime.modelName,
            sendsDataOffDevice: false,
            isAvailable: runtime.isReady,
            requiresDownload: true,
            privacySummary: "Runs locally after an optional model download",
            unavailableReason: runtime.isReady ? nil : "No validated local model and runtime are installed. Private basic remains available."
        )
    }

    func extractCareerExamples(_ request: CareerExtractionRequest) async throws -> CareerHistoryIngestionResult {
        guard runtime.isReady else { throw unavailable }
        return try await DeterministicLanguageService().extractCareerExamples(request)
    }

    func groupRequirements(_ request: RequirementGroupingRequest) async throws -> ParsedJob {
        guard runtime.isReady else { throw unavailable }
        return try await DeterministicLanguageService().groupRequirements(request)
    }

    func composeAnswer(_ request: AnswerCompositionRequest) async throws -> GeneratedDraft {
        guard runtime.isReady else { throw unavailable }
        let baseline = try await DeterministicLanguageService().composeAnswer(request)
        let output = try await runtime.generate(prompt: baseline.content)
        let claims = AnswerProvenanceService().reconcile(
            content: output,
            generatedContent: baseline.content,
            generatedClaims: baseline.claims,
            experience: request.experience
        )
        let count = output.split(whereSeparator: \.isWhitespace).count
        let unsupported = claims.filter(\.needsSource).count
        var warnings = baseline.warnings
        if unsupported > 0 {
            warnings.append("The local model changed \(unsupported) claim\(unsupported == 1 ? "" : "s") that need evidence review.")
        }
        return GeneratedDraft(
            content: output,
            quickCues: baseline.quickCues,
            claims: claims,
            followUps: baseline.followUps,
            warnings: Array(Set(warnings)).sorted(),
            wordCount: count,
            estimatedSpeakingSeconds: Int((Double(count) / 130 * 60).rounded()),
            targetWordCount: request.format.targetWordCount
        )
    }

    private var unavailable: LanguageServiceError {
        .providerUnavailable(descriptor.unavailableReason ?? "The local model is unavailable.")
    }
}

protocol LocalOpenWeightRuntime: Sendable {
    var modelName: String { get }
    var isReady: Bool { get }
    func generate(prompt: String) async throws -> String
}

struct UnavailableOpenWeightRuntime: LocalOpenWeightRuntime {
    let modelName = "Not installed"
    let isReady = false

    func generate(prompt: String) async throws -> String {
        throw LanguageServiceError.providerUnavailable("No local open-weight model is installed.")
    }
}

struct MockPremiumLanguageService: RoleReadyLanguageService {
    let descriptor = LanguageServiceDescriptor(
        kind: .premiumCloud,
        displayName: "Premium cloud",
        modelName: "GPT-5.6 through a secure backend",
        sendsDataOffDevice: true,
        isAvailable: false,
        costSummary: "Paid usage when enabled",
        privacySummary: "Sends only user-approved fields",
        unavailableReason: "A secure backend and external API credential are not configured. No key belongs in the iOS app."
    )

    func extractCareerExamples(_ request: CareerExtractionRequest) async throws -> CareerHistoryIngestionResult {
        throw LanguageServiceError.secureBackendRequired
    }

    func groupRequirements(_ request: RequirementGroupingRequest) async throws -> ParsedJob {
        throw LanguageServiceError.secureBackendRequired
    }

    func composeAnswer(_ request: AnswerCompositionRequest) async throws -> GeneratedDraft {
        throw LanguageServiceError.secureBackendRequired
    }
}

struct LanguageProviderRegistry: Sendable {
    var descriptors: [LanguageServiceDescriptor] {
        [
            DeterministicLanguageService().descriptor,
            AppleFoundationLanguageService().descriptor,
            LocalOpenWeightLanguageService().descriptor,
            MockPremiumLanguageService().descriptor
        ]
    }

    func resolvedService(for selection: LanguageProviderSelection) -> any RoleReadyLanguageService {
        switch selection {
        case .automatic:
            let apple = AppleFoundationLanguageService()
            return apple.descriptor.isAvailable ? apple : DeterministicLanguageService()
        case .deterministic:
            return DeterministicLanguageService()
        case .appleFoundation:
            let apple = AppleFoundationLanguageService()
            return apple.descriptor.isAvailable ? apple : DeterministicLanguageService()
        case .localOpenWeight:
            let local = LocalOpenWeightLanguageService()
            return local.descriptor.isAvailable ? local : DeterministicLanguageService()
        case .premiumCloud:
            return DeterministicLanguageService()
        }
    }

    func descriptor(for selection: LanguageProviderSelection) -> LanguageServiceDescriptor {
        switch selection {
        case .automatic:
            let resolved = resolvedService(for: .automatic).descriptor
            return LanguageServiceDescriptor(
                id: "automatic",
                kind: resolved.kind,
                displayName: "Automatic · \(resolved.displayName)",
                modelName: resolved.modelName,
                sendsDataOffDevice: false,
                isAvailable: true,
                costSummary: resolved.costSummary,
                privacySummary: "Chooses the best available on-device option"
            )
        case .deterministic: return DeterministicLanguageService().descriptor
        case .appleFoundation: return AppleFoundationLanguageService().descriptor
        case .localOpenWeight: return LocalOpenWeightLanguageService().descriptor
        case .premiumCloud: return MockPremiumLanguageService().descriptor
        }
    }
}

struct CloudAIConsent: Hashable, Sendable {
    let approvedSourceIDs: Set<UUID>
    let includesHighlySensitiveData: Bool
    let confirmedAt: Date?

    func validate() throws {
        guard confirmedAt != nil else { throw LanguageServiceError.explicitConsentRequired }
        guard !includesHighlySensitiveData else { throw LanguageServiceError.highlySensitiveDataBlocked }
    }
}

struct CloudGenerationEnvelope: Codable, Hashable, Sendable {
    let requestID: UUID
    let task: String
    let approvedSourceIDs: [UUID]
    let approvedSourceExcerpts: [String]
    let requestedSchemaVersion: Int
}

protocol PremiumCloudTransport: Sendable {
    func send(_ request: CloudGenerationEnvelope, consent: CloudAIConsent) async throws -> Data
}

struct DisabledPremiumCloudTransport: PremiumCloudTransport {
    func send(_ request: CloudGenerationEnvelope, consent: CloudAIConsent) async throws -> Data {
        try consent.validate()
        throw LanguageServiceError.secureBackendRequired
    }
}
