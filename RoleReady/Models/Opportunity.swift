import Foundation
import SwiftData

@Model
final class Opportunity {
    @Attribute(.unique) var id: UUID = UUID()
    var roleTitle: String = ""
    var organisation: String = ""
    var location: String = ""
    var sourceText: String = ""
    var statusRaw: String = OpportunityStatus.saved.rawValue
    var closingDate: Date?
    var interviewDate: Date?
    var notes: String = ""
    var isSample: Bool = false
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var contentUpdatedAt: Date = Date()

    init(
        id: UUID = UUID(),
        roleTitle: String,
        organisation: String,
        location: String,
        sourceText: String,
        status: OpportunityStatus,
        closingDate: Date? = nil,
        interviewDate: Date? = nil,
        notes: String = "",
        isSample: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        contentUpdatedAt: Date? = nil
    ) {
        self.id = id
        self.roleTitle = roleTitle
        self.organisation = organisation
        self.location = location
        self.sourceText = sourceText
        self.statusRaw = status.rawValue
        self.closingDate = closingDate
        self.interviewDate = interviewDate
        self.notes = notes
        self.isSample = isSample
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.contentUpdatedAt = contentUpdatedAt ?? updatedAt
    }

    var status: OpportunityStatus {
        get { OpportunityStatus(rawValue: statusRaw) ?? .saved }
        set { statusRaw = newValue.rawValue }
    }
}

@Model
final class JobRequirement {
    @Attribute(.unique) var id: UUID = UUID()
    var opportunityID: UUID = UUID()
    var text: String = ""
    var kindRaw: String = RequirementKind.responsibility.rawValue
    var keywordsRaw: String = ""
    var capabilityRaw: String = ""
    var importance: Int = 2
    var isConfirmed: Bool = true
    var createdAt: Date = Date()

    init(
        id: UUID = UUID(),
        opportunityID: UUID,
        text: String,
        kind: RequirementKind,
        keywords: [String],
        capabilities: [Capability],
        importance: Int = 2,
        isConfirmed: Bool = true,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.opportunityID = opportunityID
        self.text = text
        self.kindRaw = kind.rawValue
        self.keywordsRaw = ListCodec.encode(keywords)
        self.capabilityRaw = ListCodec.encode(capabilities.map(\.rawValue))
        self.importance = min(max(importance, 1), 3)
        self.isConfirmed = isConfirmed
        self.createdAt = createdAt
    }

    var kind: RequirementKind {
        get { RequirementKind(rawValue: kindRaw) ?? .responsibility }
        set { kindRaw = newValue.rawValue }
    }

    var keywords: [String] {
        get { ListCodec.decode(keywordsRaw) }
        set { keywordsRaw = ListCodec.encode(newValue) }
    }

    var capabilities: [Capability] {
        get { ListCodec.decode(capabilityRaw).compactMap(Capability.init(rawValue:)) }
        set { capabilityRaw = ListCodec.encode(newValue.map(\.rawValue)) }
    }
}
