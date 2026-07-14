import UniformTypeIdentifiers
import UIKit

enum SystemDocumentPickerOutcome: Sendable {
    case selected(URL)
    case cancelled
}

/// Owns the system document browser delegate and presents from the currently
/// visible controller. This avoids SwiftUI's modal-on-modal presentation edge
/// case when an importer is launched from the preparation sheet.
@MainActor
final class SystemDocumentPickerService: NSObject, UIDocumentPickerDelegate {
    static let shared = SystemDocumentPickerService()

    private var onResult: (@MainActor (SystemDocumentPickerOutcome) -> Void)?

    func present(
        contentTypes: [UTType],
        onResult: @escaping @MainActor (SystemDocumentPickerOutcome) -> Void
    ) {
        guard self.onResult == nil,
              let presenter = Self.topViewController()
        else {
            onResult(.cancelled)
            return
        }

        self.onResult = onResult
        let picker = UIDocumentPickerViewController(
            forOpeningContentTypes: contentTypes,
            asCopy: true
        )
        picker.delegate = self
        picker.allowsMultipleSelection = false
        picker.shouldShowFileExtensions = true
        presenter.present(picker, animated: true)
    }

    func documentPicker(
        _ controller: UIDocumentPickerViewController,
        didPickDocumentsAt urls: [URL]
    ) {
        finish(with: urls.first.map(SystemDocumentPickerOutcome.selected) ?? .cancelled)
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        finish(with: .cancelled)
    }

    private func finish(with outcome: SystemDocumentPickerOutcome) {
        let completion = onResult
        onResult = nil
        completion?(outcome)
    }

    private static func topViewController(
        from controller: UIViewController? = keyWindow?.rootViewController
    ) -> UIViewController? {
        if let presented = controller?.presentedViewController {
            return topViewController(from: presented)
        }
        if let navigation = controller as? UINavigationController {
            return topViewController(from: navigation.visibleViewController)
        }
        if let tabs = controller as? UITabBarController {
            return topViewController(from: tabs.selectedViewController)
        }
        return controller
    }

    private static var keyWindow: UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)
    }
}
