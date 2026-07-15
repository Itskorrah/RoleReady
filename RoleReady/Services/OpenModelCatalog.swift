import CryptoKit
import Foundation

struct LocalModelEvaluationCandidate: Codable, Hashable, Identifiable, Sendable {
    let id: String
    let displayName: String
    let publisher: String
    let parameterSummary: String
    let intendedDeviceUse: String
    let weightLicense: String
    let licenseURL: URL
    let strengthsToEvaluate: [String]
    let knownRisks: [String]
}

enum LocalModelCandidateCatalog {
    static let qwen35TwoB = LocalModelEvaluationCandidate(
        id: "qwen-3.5-2b",
        displayName: "Qwen3.5-2B",
        publisher: "Qwen",
        parameterSummary: "2B parameters; evaluate a four-bit text-only package",
        intendedDeviceUse: "Optional higher-quality local drafting on supported devices",
        weightLicense: "Apache 2.0",
        licenseURL: URL(string: "https://huggingface.co/Qwen/Qwen3.5-2B")!,
        strengthsToEvaluate: [
            "Compact parameter count", "Long-context architecture", "Structured extraction", "Multilingual career text"
        ],
        knownRisks: [
            "No selected iOS runtime artifact or checksum yet", "Quality may be insufficient for final factual prose", "Thermal and memory behaviour require physical-device measurement"
        ]
    )

    static let gemma3nE2B = LocalModelEvaluationCandidate(
        id: "gemma-3n-e2b",
        displayName: "Gemma 3n E2B",
        publisher: "Google",
        parameterSummary: "E2B effective parameters; standard execution loads more than 5B parameters",
        intendedDeviceUse: "Device-optimised comparison candidate",
        weightLicense: "Gemma Terms of Use",
        licenseURL: URL(string: "https://ai.google.dev/gemma/terms")!,
        strengthsToEvaluate: [
            "Designed for phones and laptops", "Parameter-efficient execution", "Strong structured and multilingual tasks"
        ],
        knownRisks: [
            "Licence acceptance is an external decision", "Larger total loaded weights than the E2B label suggests", "iOS packaging and runtime must be proven"
        ]
    )

    static let candidates = [qwen35TwoB, gemma3nE2B]
}

struct LocalModelArtifactManifest: Codable, Hashable, Sendable {
    let schemaVersion: Int
    let candidateID: String
    let artifactName: String
    let quantization: String
    let exactByteCount: Int64
    let sha256: String
    let sourceURL: URL
    let licenseName: String
    let licenseURL: URL
}

enum LocalModelStoreError: LocalizedError, Equatable, Sendable {
    case licenceNotAccepted
    case invalidManifest
    case byteCountMismatch
    case checksumMismatch

    var errorDescription: String? {
        switch self {
        case .licenceNotAccepted: "Review and accept the model publisher’s licence before installing its weights."
        case .invalidManifest: "The local model manifest is incomplete or unsupported."
        case .byteCountMismatch: "The model download is incomplete or has an unexpected size."
        case .checksumMismatch: "The model download failed its integrity check and was not installed."
        }
    }
}

actor LocalModelStore {
    private let rootURL: URL

    init(rootURL: URL? = nil) {
        if let rootURL {
            self.rootURL = rootURL
        } else {
            let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory
            self.rootURL = support.appending(path: "RoleReady/LocalModels", directoryHint: .isDirectory)
        }
    }

    func install(
        temporaryArtifactURL: URL,
        manifest: LocalModelArtifactManifest,
        licenceAccepted: Bool
    ) throws -> URL {
        guard licenceAccepted else { throw LocalModelStoreError.licenceNotAccepted }
        guard manifest.schemaVersion == 1,
              !manifest.candidateID.isEmpty,
              manifest.sha256.count == 64,
              manifest.exactByteCount > 0 else {
            throw LocalModelStoreError.invalidManifest
        }
        let attributes = try FileManager.default.attributesOfItem(atPath: temporaryArtifactURL.path)
        let byteCount = (attributes[.size] as? NSNumber)?.int64Value ?? -1
        guard byteCount == manifest.exactByteCount else { throw LocalModelStoreError.byteCountMismatch }
        guard try checksum(of: temporaryArtifactURL) == manifest.sha256.lowercased() else {
            throw LocalModelStoreError.checksumMismatch
        }

        let modelRoot = rootURL.appending(path: manifest.candidateID, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: modelRoot, withIntermediateDirectories: true)
        let artifactURL = modelRoot.appending(path: manifest.artifactName)
        let manifestURL = modelRoot.appending(path: "manifest.json")
        if FileManager.default.fileExists(atPath: artifactURL.path) {
            try FileManager.default.removeItem(at: artifactURL)
        }
        try FileManager.default.copyItem(at: temporaryArtifactURL, to: artifactURL)
        let data = try JSONEncoder().encode(manifest)
        try data.write(to: manifestURL, options: [.atomic, .completeFileProtection])
        return artifactURL
    }

    func installedManifest(candidateID: String) throws -> LocalModelArtifactManifest? {
        let modelRoot = rootURL.appending(path: candidateID, directoryHint: .isDirectory)
        let manifestURL = modelRoot.appending(path: "manifest.json")
        guard FileManager.default.fileExists(atPath: manifestURL.path) else { return nil }
        let manifest = try JSONDecoder().decode(
            LocalModelArtifactManifest.self,
            from: Data(contentsOf: manifestURL)
        )
        let artifactURL = modelRoot.appending(path: manifest.artifactName)
        guard FileManager.default.fileExists(atPath: artifactURL.path) else { return nil }
        return manifest
    }

    func remove(candidateID: String) throws {
        let modelRoot = rootURL.appending(path: candidateID, directoryHint: .isDirectory)
        guard FileManager.default.fileExists(atPath: modelRoot.path) else { return }
        try FileManager.default.removeItem(at: modelRoot)
    }

    private func checksum(of url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        while true {
            let data = try handle.read(upToCount: 1_048_576) ?? Data()
            if data.isEmpty { break }
            hasher.update(data: data)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}
