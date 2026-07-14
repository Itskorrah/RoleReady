import Foundation
import SwiftUI

enum AppTab: String, CaseIterable, Identifiable, Codable, Sendable {
    case prepare
    case examples
    case practise

    var id: String { rawValue }

    var title: String {
        switch self {
        case .prepare: "Prepare"
        case .examples: "My Examples"
        case .practise: "Practise"
        }
    }

    var symbol: String {
        switch self {
        case .prepare: "target"
        case .examples: "square.stack.3d.up.fill"
        case .practise: "quote.bubble.fill"
        }
    }
}

enum ExperienceKind: String, CaseIterable, Identifiable, Codable, Sendable {
    case achievement
    case project
    case problemSolved
    case leadership
    case stakeholder
    case conflict
    case mistakeAndLearning
    case customerService
    case study
    case volunteering

    var id: String { rawValue }

    var title: String {
        switch self {
        case .achievement: "Achievement"
        case .project: "Project"
        case .problemSolved: "Problem solved"
        case .leadership: "Leadership"
        case .stakeholder: "Stakeholder work"
        case .conflict: "Conflict resolved"
        case .mistakeAndLearning: "Mistake & learning"
        case .customerService: "Customer service"
        case .study: "Study"
        case .volunteering: "Volunteering"
        }
    }

    var symbol: String {
        switch self {
        case .achievement: "trophy.fill"
        case .project: "hammer.fill"
        case .problemSolved: "wrench.and.screwdriver.fill"
        case .leadership: "person.3.fill"
        case .stakeholder: "bubble.left.and.bubble.right.fill"
        case .conflict: "arrow.trianglehead.merge"
        case .mistakeAndLearning: "arrow.counterclockwise.circle.fill"
        case .customerService: "heart.text.square.fill"
        case .study: "graduationcap.fill"
        case .volunteering: "hands.sparkles.fill"
        }
    }
}

enum OwnershipLevel: String, CaseIterable, Identifiable, Codable, Sendable {
    case led
    case owned
    case contributed
    case supported

    var id: String { rawValue }

    var title: String { rawValue.capitalized }

    var phrasing: String {
        switch self {
        case .led: "I led"
        case .owned: "I owned"
        case .contributed: "I contributed"
        case .supported: "I supported"
        }
    }
}

enum Confidentiality: String, CaseIterable, Identifiable, Codable, Comparable, Sendable {
    case standard
    case privateRecord
    case confidential
    case highlySensitive

    var id: String { rawValue }

    var title: String {
        switch self {
        case .standard: "Standard"
        case .privateRecord: "Private"
        case .confidential: "Confidential"
        case .highlySensitive: "Highly sensitive"
        }
    }

    var symbol: String {
        switch self {
        case .standard: "checkmark.shield"
        case .privateRecord: "lock"
        case .confidential: "lock.fill"
        case .highlySensitive: "hand.raised.fill"
        }
    }

    var blocksAutomaticUse: Bool { self == .highlySensitive }

    private var rank: Int {
        switch self {
        case .standard: 0
        case .privateRecord: 1
        case .confidential: 2
        case .highlySensitive: 3
        }
    }

    static func < (lhs: Confidentiality, rhs: Confidentiality) -> Bool {
        lhs.rank < rhs.rank
    }
}

enum Capability: String, CaseIterable, Identifiable, Codable, Sendable {
    case technicalProblemSolving
    case processImprovement
    case dataQuality
    case stakeholderCommunication
    case leadership
    case teamwork
    case delivery
    case customerFocus
    case adaptability
    case accountability
    case learning
    case planning

    var id: String { rawValue }

    var title: String {
        switch self {
        case .technicalProblemSolving: "Technical problem-solving"
        case .processImprovement: "Process improvement"
        case .dataQuality: "Quality & risk"
        case .stakeholderCommunication: "Stakeholder communication"
        case .leadership: "Leadership"
        case .teamwork: "Teamwork"
        case .delivery: "Delivery"
        case .customerFocus: "Customer focus"
        case .adaptability: "Adaptability"
        case .accountability: "Accountability"
        case .learning: "Learning"
        case .planning: "Planning & priorities"
        }
    }

    var symbol: String {
        switch self {
        case .technicalProblemSolving: "terminal.fill"
        case .processImprovement: "arrow.triangle.2.circlepath"
        case .dataQuality: "checkmark.seal.fill"
        case .stakeholderCommunication: "person.2.wave.2.fill"
        case .leadership: "flag.fill"
        case .teamwork: "person.3.sequence.fill"
        case .delivery: "shippingbox.fill"
        case .customerFocus: "person.crop.circle.badge.checkmark"
        case .adaptability: "arrow.left.arrow.right"
        case .accountability: "hand.raised.fill"
        case .learning: "lightbulb.fill"
        case .planning: "calendar.badge.clock"
        }
    }
}

enum OpportunityStatus: String, CaseIterable, Identifiable, Codable, Sendable {
    case saved
    case preparing
    case interviewing
    case offer
    case closed

    var id: String { rawValue }

    var title: String { rawValue.capitalized }

    var symbol: String {
        switch self {
        case .saved: "bookmark.fill"
        case .preparing: "wand.and.stars"
        case .interviewing: "person.2.fill"
        case .offer: "party.popper.fill"
        case .closed: "archivebox.fill"
        }
    }
}

enum RequirementKind: String, CaseIterable, Identifiable, Codable, Sendable {
    case mustHave
    case responsibility
    case signal

    var id: String { rawValue }

    var title: String {
        switch self {
        case .mustHave: "Must-have"
        case .responsibility: "Responsibility"
        case .signal: "Role signal"
        }
    }
}

enum AnswerFormat: String, CaseIterable, Identifiable, Codable, Sendable {
    case quickPrompt
    case thirtySeconds
    case sixtySeconds
    case ninetySeconds
    case writtenSTAR
    case resumeBullet
    case coverLetter
    case selectionCriteria

    var id: String { rawValue }

    var title: String {
        switch self {
        case .quickPrompt: "Quick cues"
        case .thirtySeconds: "30 seconds"
        case .sixtySeconds: "60 seconds"
        case .ninetySeconds: "90 seconds"
        case .writtenSTAR: "Written STAR"
        case .resumeBullet: "Résumé bullet"
        case .coverLetter: "Cover letter"
        case .selectionCriteria: "Selection criterion"
        }
    }

    var targetWordCount: ClosedRange<Int> {
        switch self {
        case .quickPrompt: 8...45
        case .thirtySeconds: 55...90
        case .sixtySeconds: 105...145
        case .ninetySeconds: 165...240
        case .writtenSTAR: 220...420
        case .resumeBullet: 16...42
        case .coverLetter: 70...140
        case .selectionCriteria: 150...360
        }
    }
}

enum AnswerAudience: String, CaseIterable, Identifiable, Codable, Sendable {
    case recruiter
    case hiringManager
    case technicalPanel
    case executivePanel

    var id: String { rawValue }

    var title: String {
        switch self {
        case .recruiter: "Recruiter"
        case .hiringManager: "Hiring manager"
        case .technicalPanel: "Technical panel"
        case .executivePanel: "Executive panel"
        }
    }
}

enum AnswerTone: String, CaseIterable, Identifiable, Codable, Sendable {
    case natural
    case confident
    case concise
    case technical

    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

enum ListCodec {
    private static let separator = "\u{001F}"

    static func encode(_ values: [String]) -> String {
        values
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: separator)
    }

    static func decode(_ value: String) -> [String] {
        guard !value.isEmpty else { return [] }
        return value.components(separatedBy: separator).filter { !$0.isEmpty }
    }
}
