import Foundation
import SwiftData

@Model
final class CareerProfile {
    @Attribute(.unique) var id: UUID = UUID()
    var name: String = ""
    var headline: String = ""
    var professionalSummary: String = ""
    var currentOrganisation: String = ""
    var targetRolesRaw: String = ""
    var skillsRaw: String = ""
    var careerGoal: String = ""
    var isSample: Bool = false
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(
        id: UUID = UUID(),
        name: String,
        headline: String,
        professionalSummary: String,
        currentOrganisation: String,
        targetRoles: [String],
        skills: [String],
        careerGoal: String,
        isSample: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.headline = headline
        self.professionalSummary = professionalSummary
        self.currentOrganisation = currentOrganisation
        self.targetRolesRaw = ListCodec.encode(targetRoles)
        self.skillsRaw = ListCodec.encode(skills)
        self.careerGoal = careerGoal
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
}
