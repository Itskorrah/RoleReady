import Foundation
import Observation
import SwiftUI

enum AppRoute: Hashable {
    case experience(UUID)
    case opportunity(UUID)
    case matchReport(UUID)
    case answerStudio(experienceID: UUID?, opportunityID: UUID?)
    case answerStudioForRequirement(experienceID: UUID, opportunityID: UUID, question: String)
    case editAnswer(UUID)
    case prepDeck(UUID?)
    case reflection(UUID)
    case profile
    case insights
    case settings
    case privacy
}

enum SheetDestination: Identifiable, Hashable {
    case addStory
    case editStory(UUID)
    case addRole
    case addQuestion

    var id: String {
        switch self {
        case .addStory, .editStory: "story-editor"
        case .addRole: "role-editor"
        case .addQuestion: "question-editor"
        }
    }
}

@MainActor
@Observable
final class AppRouter {
    var path: [AppRoute] = []

    func navigate(to route: AppRoute) {
        path.append(route)
    }

    func reset() {
        path.removeAll()
    }
}
