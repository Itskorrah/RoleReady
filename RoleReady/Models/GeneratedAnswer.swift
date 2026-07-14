import Foundation
import SwiftData

enum AnswerClaimOrigin: String, Codable, Sendable {
    case generated
    case questionContext
    case editedSupported
    case editedUnsupported
    case legacy
}

struct StoredAnswerClaim: Codable, Hashable, Sendable {
    let sourceField: String
    let text: String
    let sourceText: String
    let origin: AnswerClaimOrigin
    let isSupported: Bool

    init(
        sourceField: String,
        text: String,
        sourceText: String = "",
        origin: AnswerClaimOrigin = .generated,
        isSupported: Bool = true
    ) {
        self.sourceField = sourceField
        self.text = text
        self.sourceText = sourceText
        self.origin = origin
        self.isSupported = isSupported
    }

    private enum CodingKeys: String, CodingKey {
        case sourceField
        case text
        case sourceText
        case origin
        case isSupported
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sourceField = try container.decode(String.self, forKey: .sourceField)
        text = try container.decode(String.self, forKey: .text)
        sourceText = try container.decodeIfPresent(String.self, forKey: .sourceText) ?? ""
        origin = try container.decodeIfPresent(AnswerClaimOrigin.self, forKey: .origin) ?? .legacy
        isSupported = try container.decodeIfPresent(Bool.self, forKey: .isSupported) ?? true
    }

    var needsSource: Bool {
        !isSupported || origin == .editedUnsupported
    }
}

@Model
final class GeneratedAnswer {
    @Attribute(.unique) var id: UUID = UUID()
    var question: String = ""
    var experienceID: UUID = UUID()
    var opportunityID: UUID?
    var formatRaw: String = AnswerFormat.sixtySeconds.rawValue
    var audienceRaw: String = AnswerAudience.hiringManager.rawValue
    var toneRaw: String = AnswerTone.natural.rawValue
    var content: String = ""
    var quickCuesRaw: String = ""
    var sourceFieldsRaw: String = ""
    var sourceClaimsJSON: String = "[]"
    var followUpsRaw: String = ""
    var isFactConfirmed: Bool = false
    var isUserEdited: Bool = false
    var isSample: Bool = false
    var sourceExperienceUpdatedAt: Date = Date.distantPast
    var sourceOpportunityUpdatedAt: Date?
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(
        id: UUID = UUID(),
        question: String,
        experienceID: UUID,
        opportunityID: UUID? = nil,
        format: AnswerFormat,
        audience: AnswerAudience,
        tone: AnswerTone,
        content: String,
        quickCues: [String],
        sourceFields: [String],
        sourceClaims: [StoredAnswerClaim] = [],
        followUps: [String],
        isFactConfirmed: Bool = false,
        isUserEdited: Bool = false,
        isSample: Bool = false,
        sourceExperienceUpdatedAt: Date = .distantPast,
        sourceOpportunityUpdatedAt: Date? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.question = question
        self.experienceID = experienceID
        self.opportunityID = opportunityID
        self.formatRaw = format.rawValue
        self.audienceRaw = audience.rawValue
        self.toneRaw = tone.rawValue
        self.content = content
        self.quickCuesRaw = ListCodec.encode(quickCues)
        self.sourceFieldsRaw = ListCodec.encode(sourceFields)
        self.sourceClaimsJSON = Self.encodeClaims(sourceClaims)
        self.followUpsRaw = ListCodec.encode(followUps)
        self.isFactConfirmed = isFactConfirmed
        self.isUserEdited = isUserEdited
        self.isSample = isSample
        self.sourceExperienceUpdatedAt = sourceExperienceUpdatedAt
        self.sourceOpportunityUpdatedAt = sourceOpportunityUpdatedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var format: AnswerFormat {
        get { AnswerFormat(rawValue: formatRaw) ?? .sixtySeconds }
        set { formatRaw = newValue.rawValue }
    }

    var audience: AnswerAudience {
        get { AnswerAudience(rawValue: audienceRaw) ?? .hiringManager }
        set { audienceRaw = newValue.rawValue }
    }

    var tone: AnswerTone {
        get { AnswerTone(rawValue: toneRaw) ?? .natural }
        set { toneRaw = newValue.rawValue }
    }

    var quickCues: [String] {
        get { ListCodec.decode(quickCuesRaw) }
        set { quickCuesRaw = ListCodec.encode(newValue) }
    }

    var sourceFields: [String] {
        get { ListCodec.decode(sourceFieldsRaw) }
        set { sourceFieldsRaw = ListCodec.encode(newValue) }
    }

    var sourceClaims: [StoredAnswerClaim] {
        get {
            guard let data = sourceClaimsJSON.data(using: .utf8),
                  let claims = try? JSONDecoder().decode([StoredAnswerClaim].self, from: data) else {
                return []
            }
            return claims
        }
        set { sourceClaimsJSON = Self.encodeClaims(newValue) }
    }

    var followUps: [String] {
        get { ListCodec.decode(followUpsRaw) }
        set { followUpsRaw = ListCodec.encode(newValue) }
    }

    func isApprovalCurrent(for source: Experience?, opportunity: Opportunity? = nil) -> Bool {
        guard isFactConfirmed, let source else { return false }
        guard hasTrustworthyProvenance else { return false }
        guard source.updatedAt <= sourceExperienceUpdatedAt else { return false }
        guard !source.confidentiality.blocksAutomaticUse || source.isApprovedForMatching else { return false }
        if opportunityID != nil {
            guard let opportunity,
                  let sourceOpportunityUpdatedAt,
                  opportunity.contentUpdatedAt <= sourceOpportunityUpdatedAt else { return false }
        }
        return true
    }

    var hasTrustworthyProvenance: Bool {
        let claims = sourceClaims
        guard !claims.isEmpty, claims.allSatisfy({ !$0.needsSource }) else { return false }
        if isUserEdited, claims.contains(where: { $0.origin == .legacy }) {
            return false
        }
        return true
    }

    private static func encodeClaims(_ claims: [StoredAnswerClaim]) -> String {
        guard let data = try? JSONEncoder().encode(claims),
              let value = String(data: data, encoding: .utf8) else { return "[]" }
        return value
    }
}

@Model
final class PracticeSession {
    @Attribute(.unique) var id: UUID = UUID()
    var answerID: UUID = UUID()
    var experienceID: UUID?
    var opportunityID: UUID?
    var question: String = ""
    var durationSeconds: Int = 0
    var confidence: Int = 3
    var notes: String = ""
    var practisedAt: Date = Date()

    init(
        id: UUID = UUID(),
        answerID: UUID,
        experienceID: UUID? = nil,
        opportunityID: UUID? = nil,
        question: String,
        durationSeconds: Int,
        confidence: Int,
        notes: String = "",
        practisedAt: Date = Date()
    ) {
        self.id = id
        self.answerID = answerID
        self.experienceID = experienceID
        self.opportunityID = opportunityID
        self.question = question
        self.durationSeconds = max(durationSeconds, 0)
        self.confidence = min(max(confidence, 1), 5)
        self.notes = notes
        self.practisedAt = practisedAt
    }
}

@Model
final class InterviewReflection {
    @Attribute(.unique) var id: UUID = UUID()
    @Attribute(.unique) var opportunityID: UUID = UUID()
    var questionsRaw: String = ""
    var experienceIDsRaw: String = ""
    var strongestMoment: String = ""
    var difficultMoment: String = ""
    var feedback: String = ""
    var nextImprovement: String = ""
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(
        id: UUID = UUID(),
        opportunityID: UUID,
        questions: [String],
        experienceIDs: [UUID],
        strongestMoment: String,
        difficultMoment: String,
        feedback: String,
        nextImprovement: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.opportunityID = opportunityID
        self.questionsRaw = ListCodec.encode(questions)
        self.experienceIDsRaw = ListCodec.encode(experienceIDs.map(\.uuidString))
        self.strongestMoment = strongestMoment
        self.difficultMoment = difficultMoment
        self.feedback = feedback
        self.nextImprovement = nextImprovement
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var questions: [String] {
        get { ListCodec.decode(questionsRaw) }
        set { questionsRaw = ListCodec.encode(newValue) }
    }

    var experienceIDs: [UUID] {
        get { ListCodec.decode(experienceIDsRaw).compactMap(UUID.init(uuidString:)) }
        set { experienceIDsRaw = ListCodec.encode(newValue.map(\.uuidString)) }
    }
}
