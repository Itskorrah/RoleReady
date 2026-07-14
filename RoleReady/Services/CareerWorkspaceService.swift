import CryptoKit
import Foundation
import SwiftData

struct CareerImportSummary: Hashable, Sendable {
    let sourceID: UUID
    let profileID: UUID?
    let positionIDs: [UUID]
    let educationIDs: [UUID]
    let certificationIDs: [UUID]
    let skillIDs: [UUID]
    let resumeVersionID: UUID?

    var importedItemCount: Int {
        positionIDs.count + educationIDs.count + certificationIDs.count + skillIDs.count
    }
}

@MainActor
struct CareerWorkspaceService {
    func saveResumeImport(
        _ draft: ResumeIntakeDraft,
        filename: String,
        approveIncludedItems: Bool,
        createBaselineResume: Bool,
        in context: ModelContext
    ) throws -> CareerImportSummary {
        let sourceID = UUID()
        let source = CareerSource(
            id: sourceID,
            kind: .resume,
            name: draft.sourceName,
            filename: filename,
            contentType: contentType(for: filename),
            rawText: draft.sourceText,
            fingerprint: fingerprint(draft.sourceText),
            confidentiality: .privateRecord
        )
        context.insert(source)

        let status: CareerRecordStatus = approveIncludedItems ? .approved : .imported
        let profile = try mergeProfile(from: draft, sourceID: sourceID, status: status, in: context)
        var positions: [CareerPosition] = []
        var education: [CareerEducation] = []
        var certifications: [CareerCertification] = []
        var skills: [CareerSkill] = []

        for item in draft.positions where item.isIncluded {
            let position = CareerPosition(
                id: item.id,
                sourceID: sourceID,
                title: item.title,
                organisation: item.organisation,
                location: item.location,
                startDate: item.startDate,
                endDate: item.endDate,
                isCurrent: item.isCurrent,
                bullets: item.bullets,
                skills: item.skills,
                sourceExcerpt: item.sourceExcerpt,
                verificationStatus: status,
                approvedAt: approveIncludedItems ? Date() : nil
            )
            context.insert(position)
            insertSpan(for: position.id, type: "careerPosition", field: "sourceExcerpt", range: item.sourceRange, excerpt: item.sourceExcerpt, source: source, approved: approveIncludedItems, in: context)
            positions.append(position)
        }

        for item in draft.education where item.isIncluded {
            let record = CareerEducation(
                id: item.id,
                sourceID: sourceID,
                institution: item.institution,
                qualification: item.qualification,
                fieldOfStudy: item.fieldOfStudy,
                startDate: item.startDate,
                endDate: item.endDate,
                details: item.details,
                sourceExcerpt: item.sourceExcerpt,
                verificationStatus: status
            )
            context.insert(record)
            insertSpan(for: record.id, type: "careerEducation", field: "sourceExcerpt", range: item.sourceRange, excerpt: item.sourceExcerpt, source: source, approved: approveIncludedItems, in: context)
            education.append(record)
        }

        for item in draft.certifications where item.isIncluded {
            let record = CareerCertification(
                id: item.id,
                sourceID: sourceID,
                name: item.name,
                issuer: item.issuer,
                issuedAt: item.issuedAt,
                sourceExcerpt: item.sourceExcerpt,
                verificationStatus: status
            )
            context.insert(record)
            insertSpan(for: record.id, type: "careerCertification", field: "sourceExcerpt", range: item.sourceRange, excerpt: item.sourceExcerpt, source: source, approved: approveIncludedItems, in: context)
            certifications.append(record)
        }

        let existingSkillNames = Set(try context.fetch(FetchDescriptor<CareerSkill>()).map { $0.name.lowercased() })
        var importedSkillNames = Set<String>()
        for item in draft.skills where item.isIncluded {
            let key = item.name.lowercased()
            guard !existingSkillNames.contains(key), importedSkillNames.insert(key).inserted else { continue }
            let record = CareerSkill(
                id: item.id,
                sourceID: sourceID,
                name: item.name,
                category: item.category,
                sourceExcerpt: item.sourceExcerpt,
                verificationStatus: status
            )
            context.insert(record)
            insertSpan(for: record.id, type: "careerSkill", field: "name", range: item.sourceRange, excerpt: item.sourceExcerpt, source: source, approved: approveIncludedItems, in: context)
            skills.append(record)
        }

        var version: ResumeVersion?
        if createBaselineResume, approveIncludedItems {
            let document = ResumeDocumentFactory().makeDocument(
                profile: profile,
                positions: positions,
                education: education,
                certifications: certifications,
                skills: skills
            )
            let created = ResumeVersion(
                sourceID: sourceID,
                name: baselineName(from: filename),
                targetRole: profile?.targetRoles.first ?? "",
                document: document,
                isBaseline: true
            )
            context.insert(created)
            version = created
        }

        try context.save()
        return CareerImportSummary(
            sourceID: sourceID,
            profileID: profile?.id,
            positionIDs: positions.map(\.id),
            educationIDs: education.map(\.id),
            certificationIDs: certifications.map(\.id),
            skillIDs: skills.map(\.id),
            resumeVersionID: version?.id
        )
    }

    func approveRecord(_ position: CareerPosition, in context: ModelContext) throws {
        position.verificationStatus = .approved
        position.approvedAt = Date()
        position.updatedAt = Date()
        try approveSpans(entityID: position.id, in: context)
    }

    func approveRecord(_ education: CareerEducation, in context: ModelContext) throws {
        education.verificationStatus = .approved
        education.updatedAt = Date()
        try approveSpans(entityID: education.id, in: context)
    }

    func approveRecord(_ certification: CareerCertification, in context: ModelContext) throws {
        certification.verificationStatus = .approved
        certification.updatedAt = Date()
        try approveSpans(entityID: certification.id, in: context)
    }

    func approveRecord(_ skill: CareerSkill, in context: ModelContext) throws {
        skill.verificationStatus = .approved
        skill.updatedAt = Date()
        try approveSpans(entityID: skill.id, in: context)
    }

    private func mergeProfile(
        from draft: ResumeIntakeDraft,
        sourceID: UUID,
        status: CareerRecordStatus,
        in context: ModelContext
    ) throws -> CareerProfile? {
        let hasProfileContent = !draft.contact.name.isEmpty || !draft.headline.isEmpty || !draft.summary.isEmpty
        guard hasProfileContent else { return nil }
        let current = try context.fetch(FetchDescriptor<CareerProfile>(sortBy: [SortDescriptor(\CareerProfile.updatedAt, order: .reverse)])).first
        let profile = current ?? CareerProfile(
            name: "",
            headline: "",
            professionalSummary: "",
            currentOrganisation: "",
            targetRoles: [],
            skills: [],
            careerGoal: ""
        )
        if current == nil { context.insert(profile) }

        // This method is only called after an explicit review action. Existing non-empty
        // values still win so an import never silently erases a user's career profile.
        if profile.name.isEmpty { profile.name = draft.contact.name }
        if profile.email.isEmpty { profile.email = draft.contact.email }
        if profile.phone.isEmpty { profile.phone = draft.contact.phone }
        if profile.location.isEmpty { profile.location = draft.contact.location }
        if profile.linkedIn.isEmpty { profile.linkedIn = draft.contact.linkedIn }
        if profile.portfolio.isEmpty { profile.portfolio = draft.contact.portfolio }
        if profile.headline.isEmpty { profile.headline = draft.headline }
        if profile.professionalSummary.isEmpty { profile.professionalSummary = draft.summary }
        profile.sourceID = sourceID
        profile.verificationStatus = status
        profile.updatedAt = Date()
        insertSpan(
            for: profile.id,
            type: "careerProfile",
            field: "professionalSummary",
            range: draft.sourceText.range(of: draft.summary),
            excerpt: draft.summary,
            sourceID: sourceID,
            sourceText: draft.sourceText,
            approved: status == .approved,
            in: context
        )
        return profile
    }

    private func insertSpan(
        for entityID: UUID,
        type: String,
        field: String,
        range: Range<String.Index>?,
        excerpt: String,
        source: CareerSource,
        approved: Bool,
        in context: ModelContext
    ) {
        insertSpan(for: entityID, type: type, field: field, range: range, excerpt: excerpt, sourceID: source.id, sourceText: source.rawText, approved: approved, in: context)
    }

    private func insertSpan(
        for entityID: UUID,
        type: String,
        field: String,
        range: Range<String.Index>?,
        excerpt: String,
        sourceID: UUID,
        sourceText: String = "",
        approved: Bool,
        in context: ModelContext
    ) {
        guard !excerpt.isEmpty else { return }
        let start: Int
        let end: Int
        if let range {
            start = sourceText.distance(from: sourceText.startIndex, to: range.lowerBound)
            end = sourceText.distance(from: sourceText.startIndex, to: range.upperBound)
        } else {
            start = 0
            end = excerpt.count
        }
        context.insert(CareerSourceSpan(
            sourceID: sourceID,
            entityID: entityID,
            entityType: type,
            fieldPath: field,
            startOffset: start,
            endOffset: end,
            excerpt: excerpt,
            confidence: 0.72,
            isApproved: approved
        ))
    }

    private func approveSpans(entityID: UUID, in context: ModelContext) throws {
        let id = entityID
        let descriptor = FetchDescriptor<CareerSourceSpan>(predicate: #Predicate { $0.entityID == id })
        for span in try context.fetch(descriptor) { span.isApproved = true }
        try context.save()
    }

    private func fingerprint(_ text: String) -> String {
        SHA256.hash(data: Data(text.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    private func contentType(for filename: String) -> String {
        switch URL(fileURLWithPath: filename).pathExtension.lowercased() {
        case "pdf": "application/pdf"
        case "docx": "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
        case "rtf": "application/rtf"
        default: "text/plain"
        }
    }

    private func baselineName(from filename: String) -> String {
        let base = URL(fileURLWithPath: filename).deletingPathExtension().lastPathComponent
        return base.isEmpty ? "Baseline résumé" : "\(base) · Baseline"
    }
}

struct ResumeDocumentFactory: Sendable {
    func makeDocument(
        profile: CareerProfile?,
        positions: [CareerPosition],
        education: [CareerEducation],
        certifications: [CareerCertification],
        skills: [CareerSkill]
    ) -> ResumeDocument {
        let approvedPositions = positions.filter { $0.verificationStatus.permitsGeneration }
        let approvedEducation = education.filter { $0.verificationStatus.permitsGeneration }
        let approvedCertifications = certifications.filter { $0.verificationStatus.permitsGeneration }
        let approvedSkills = skills.filter { $0.verificationStatus.permitsGeneration }

        let sections = [
            ResumeSection(
                kind: .summary,
                body: profile?.verificationStatus.permitsGeneration == true ? profile?.professionalSummary ?? "" : ""
            ),
            ResumeSection(
                kind: .skills,
                body: approvedSkills.map(\.name).joined(separator: " · ")
            ),
            ResumeSection(
                kind: .experience,
                items: approvedPositions.map { position in
                    ResumeItem(
                        sourceEntityIDs: [position.id],
                        heading: position.title,
                        subheading: position.organisation,
                        location: position.location,
                        startDate: position.startDate,
                        endDate: position.endDate,
                        bullets: position.bullets.map {
                            ResumeBullet(
                                text: $0,
                                sourceEntityIDs: [position.id],
                                evidence: .direct,
                                isApproved: true
                            )
                        }
                    )
                }
            ),
            ResumeSection(kind: .projects, isVisible: false),
            ResumeSection(
                kind: .education,
                items: approvedEducation.map { item in
                    ResumeItem(
                        sourceEntityIDs: [item.id],
                        heading: item.qualification,
                        subheading: item.institution,
                        location: item.location,
                        startDate: item.startDate,
                        endDate: item.endDate,
                        bullets: item.details.map {
                            ResumeBullet(text: $0, sourceEntityIDs: [item.id], evidence: .direct, isApproved: true)
                        }
                    )
                }
            ),
            ResumeSection(
                kind: .certifications,
                items: approvedCertifications.map { item in
                    ResumeItem(
                        sourceEntityIDs: [item.id],
                        heading: item.name,
                        subheading: item.issuer,
                        startDate: item.issuedAt
                    )
                }
            )
        ]
        return ResumeDocument(
            contact: ResumeContact(
                name: profile?.name ?? "",
                email: profile?.email ?? "",
                phone: profile?.phone ?? "",
                location: profile?.location ?? "",
                linkedIn: profile?.linkedIn ?? "",
                portfolio: profile?.portfolio ?? ""
            ),
            headline: profile?.headline ?? "",
            sections: sections
        )
    }
}
