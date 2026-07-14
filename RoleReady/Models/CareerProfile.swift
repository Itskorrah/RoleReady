import Foundation
import SwiftData

@Model
final class CareerProfile {
    @Attribute(.unique) var id: UUID = UUID()
    var name: String = ""
    var email: String = ""
    var phone: String = ""
    var location: String = ""
    var linkedIn: String = ""
    var portfolio: String = ""
    var headline: String = ""
    var professionalSummary: String = ""
    var currentOrganisation: String = ""
    var targetRolesRaw: String = ""
    var skillsRaw: String = ""
    var careerGoal: String = ""
    var sourceID: UUID?
    var verificationStatusRaw: String = CareerRecordStatus.approved.rawValue
    var confidentialityRaw: String = Confidentiality.privateRecord.rawValue
    var isSample: Bool = false
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(
        id: UUID = UUID(),
        name: String,
        email: String = "",
        phone: String = "",
        location: String = "",
        linkedIn: String = "",
        portfolio: String = "",
        headline: String,
        professionalSummary: String,
        currentOrganisation: String,
        targetRoles: [String],
        skills: [String],
        careerGoal: String,
        sourceID: UUID? = nil,
        verificationStatus: CareerRecordStatus = .approved,
        confidentiality: Confidentiality = .privateRecord,
        isSample: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.email = email
        self.phone = phone
        self.location = location
        self.linkedIn = linkedIn
        self.portfolio = portfolio
        self.headline = headline
        self.professionalSummary = professionalSummary
        self.currentOrganisation = currentOrganisation
        self.targetRolesRaw = ListCodec.encode(targetRoles)
        self.skillsRaw = ListCodec.encode(skills)
        self.careerGoal = careerGoal
        self.sourceID = sourceID
        self.verificationStatusRaw = verificationStatus.rawValue
        self.confidentialityRaw = confidentiality.rawValue
        self.isSample = isSample
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var targetRoles: [String] {
        get { ListCodec.decode(targetRolesRaw) }
        set { targetRolesRaw = ListCodec.encode(newValue) }
    }

    var skills: [String] {
        get { ListCodec.decode(skillsRaw) }
        set { skillsRaw = ListCodec.encode(newValue) }
    }

    var verificationStatus: CareerRecordStatus {
        get { CareerRecordStatus(rawValue: verificationStatusRaw) ?? .approved }
        set { verificationStatusRaw = newValue.rawValue }
    }

    var confidentiality: Confidentiality {
        get { Confidentiality(rawValue: confidentialityRaw) ?? .privateRecord }
        set { confidentialityRaw = newValue.rawValue }
    }
}
