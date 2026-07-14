import Foundation
import SwiftData

@Model
final class Experience {
    @Attribute(.unique) var id: UUID = UUID()
    var title: String = ""
    var organisation: String = ""
    var occurredAt: Date = Date()
    var kindRaw: String = ExperienceKind.project.rawValue
    var situation: String = ""
    var task: String = ""
    var actionsRaw: String = ""
    var result: String = ""
    var evidence: String = ""
    var learning: String = ""
    var ownershipRaw: String = OwnershipLevel.owned.rawValue
    var capabilityRaw: String = ""
    var toolsRaw: String = ""
    var confidentialityRaw: String = Confidentiality.privateRecord.rawValue
    var sourceID: UUID?
    var sourceExcerpt: String = ""
    var verificationStatusRaw: String = CareerRecordStatus.approved.rawValue
    var isApprovedForMatching: Bool = true
    var isSample: Bool = false
    var useCount: Int = 0
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(
        id: UUID = UUID(),
        title: String,
        organisation: String,
        occurredAt: Date,
        kind: ExperienceKind,
        situation: String,
        task: String,
        actions: [String],
        result: String,
        evidence: String,
        learning: String,
        ownership: OwnershipLevel,
        capabilities: [Capability],
        tools: [String],
        confidentiality: Confidentiality = .privateRecord,
        sourceID: UUID? = nil,
        sourceExcerpt: String = "",
        verificationStatus: CareerRecordStatus = .approved,
        isApprovedForMatching: Bool = true,
        isSample: Bool = false,
        useCount: Int = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.organisation = organisation
        self.occurredAt = occurredAt
        self.kindRaw = kind.rawValue
        self.situation = situation
        self.task = task
        self.actionsRaw = ListCodec.encode(actions)
        self.result = result
        self.evidence = evidence
        self.learning = learning
        self.ownershipRaw = ownership.rawValue
        self.capabilityRaw = ListCodec.encode(capabilities.map(\.rawValue))
        self.toolsRaw = ListCodec.encode(tools)
        self.confidentialityRaw = confidentiality.rawValue
        self.sourceID = sourceID
        self.sourceExcerpt = sourceExcerpt
        self.verificationStatusRaw = verificationStatus.rawValue
        self.isApprovedForMatching = isApprovedForMatching
        self.isSample = isSample
        self.useCount = useCount
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var kind: ExperienceKind {
        get { ExperienceKind(rawValue: kindRaw) ?? .project }
        set { kindRaw = newValue.rawValue }
    }

    var actions: [String] {
        get { ListCodec.decode(actionsRaw) }
        set { actionsRaw = ListCodec.encode(newValue) }
    }

    var ownership: OwnershipLevel {
        get { OwnershipLevel(rawValue: ownershipRaw) ?? .owned }
        set { ownershipRaw = newValue.rawValue }
    }

    var capabilities: [Capability] {
        get { ListCodec.decode(capabilityRaw).compactMap(Capability.init(rawValue:)) }
        set { capabilityRaw = ListCodec.encode(newValue.map(\.rawValue)) }
    }

    var tools: [String] {
        get { ListCodec.decode(toolsRaw) }
        set { toolsRaw = ListCodec.encode(newValue) }
    }

    var confidentiality: Confidentiality {
        get { Confidentiality(rawValue: confidentialityRaw) ?? .privateRecord }
        set { confidentialityRaw = newValue.rawValue }
    }

    var verificationStatus: CareerRecordStatus {
        get { CareerRecordStatus(rawValue: verificationStatusRaw) ?? .approved }
        set { verificationStatusRaw = newValue.rawValue }
    }

    var searchableText: String {
        [title, organisation, situation, task, actions.joined(separator: " "), result, evidence, learning, tools.joined(separator: " "), capabilities.map(\.title).joined(separator: " ")]
            .joined(separator: " ")
    }
}
