import SwiftData
import SwiftUI

@MainActor
struct JobApplicationWorkspaceView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppRouter.self) private var router
    @Environment(AppState.self) private var appState

    let opportunityID: UUID

    @Query private var opportunities: [Opportunity]
    @Query private var requirements: [JobRequirement]
    @Query(sort: \ResumeVersion.updatedAt, order: .reverse) private var resumes: [ResumeVersion]
    @Query(sort: \CoverLetter.updatedAt, order: .reverse) private var coverLetters: [CoverLetter]
    @Query(sort: \CareerPosition.startDate, order: .reverse) private var positions: [CareerPosition]
    @Query(sort: \CareerSkill.name) private var skills: [CareerSkill]
    @Query(sort: \CareerProfile.updatedAt, order: .reverse) private var profiles: [CareerProfile]
    @Query(sort: \ApplicationActivity.occurredAt, order: .reverse) private var activities: [ApplicationActivity]
    @Query(sort: \CareerReminder.dueAt) private var reminders: [CareerReminder]

    @State private var isCreatingCoverLetter = false
    @State private var isAddingActivity = false
    @State private var isAddingReminder = false
    @State private var editingLetter: CoverLetter?
    @State private var errorMessage: String?

    init(opportunityID: UUID) {
        self.opportunityID = opportunityID
        let id = opportunityID
        _opportunities = Query(filter: #Predicate<Opportunity> { $0.id == id })
        _requirements = Query(filter: #Predicate<JobRequirement> { $0.opportunityID == id })
    }

    var body: some View {
        Group {
            if let opportunity = opportunities.first {
                workspace(opportunity)
            } else {
                ContentUnavailableView("Application unavailable", systemImage: "briefcase.fill")
            }
        }
        .navigationTitle("Application")
        .navigationBarTitleDisplayMode(.inline)
        .screenBackground()
        .sheet(isPresented: $isCreatingCoverLetter) {
            CoverLetterSetupSheet { motivation, tone, targetWords in
                createCoverLetter(motivation: motivation, tone: tone, targetWords: targetWords)
            }
        }
        .sheet(item: $editingLetter) { letter in
            CoverLetterEditorSheet(
                letter: letter,
                approvedSources: approvedSourceText,
                allowedContext: opportunities.first.map { [$0.roleTitle, $0.organisation, $0.sourceText] } ?? []
            )
        }
        .sheet(isPresented: $isAddingActivity) {
            ActivityEditorSheet { kind, title, notes, date in
                addActivity(kind: kind, title: title, notes: notes, occurredAt: date)
            }
        }
        .sheet(isPresented: $isAddingReminder) {
            ReminderEditorSheet { kind, title, notes, dueAt in
                addReminder(kind: kind, title: title, notes: notes, dueAt: dueAt)
            }
        }
        .alert("Application could not be updated", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "Try again.")
        }
        .accessibilityIdentifier("application.workspace")
    }

    private func workspace(_ opportunity: Opportunity) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: RRSpacing.lg) {
                ApplicationHero(opportunity: opportunity) { status in
                    updateStatus(opportunity, status: status)
                }
                materialsSection(opportunity)
                trackerSection(opportunity)
                reminderSection
                interviewSection(opportunity)
            }
            .padding(.horizontal, RRSpacing.md)
            .padding(.vertical, RRSpacing.lg)
            .frame(maxWidth: 880)
            .frame(maxWidth: .infinity)
        }
    }

    private func materialsSection(_ opportunity: Opportunity) -> some View {
        VStack(alignment: .leading, spacing: RRSpacing.md) {
            SectionHeading(title: "Application materials", eyebrow: "Grounded in approved evidence")

            VStack(alignment: .leading, spacing: RRSpacing.md) {
                Label("Tailored résumé", systemImage: "doc.text.magnifyingglass")
                    .font(.rrHeadline)
                    .foregroundStyle(BrandTheme.ink)
                if baselineResumes.isEmpty {
                    Text("Create or import a baseline résumé first. Imported facts must be approved before RoleReady can generate a job-specific version.")
                        .font(.rrBody)
                        .foregroundStyle(BrandTheme.inkMuted)
                    Button("Open résumé builder") {
                        appState.selectedTab = .resumes
                    }
                    .buttonStyle(SecondaryActionButtonStyle())
                } else {
                    Menu {
                        ForEach(baselineResumes) { resume in
                            Button(resume.name) { tailor(resume, for: opportunity) }
                        }
                    } label: {
                        Label("Create a truthful tailored version", systemImage: "wand.and.stars")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryActionButtonStyle())
                    .disabled(confirmedRequirements.isEmpty || approvedEvidenceCount == 0)
                    .opacity(confirmedRequirements.isEmpty || approvedEvidenceCount == 0 ? 0.55 : 1)

                    if confirmedRequirements.isEmpty || approvedEvidenceCount == 0 {
                        Label(
                            confirmedRequirements.isEmpty
                                ? "Confirm at least one job requirement first."
                                : "Approve career evidence before tailoring.",
                            systemImage: "exclamationmark.triangle.fill"
                        )
                        .font(.rrCaption)
                        .foregroundStyle(BrandTheme.amberText)
                    }
                }

                ForEach(jobResumes) { resume in
                    TailoredResumeCard(resume: resume) {
                        router.navigate(to: .resume(resume.id))
                    }
                }
            }
            .cardSurface()

            VStack(alignment: .leading, spacing: RRSpacing.md) {
                HStack {
                    Label("Cover letters", systemImage: "envelope.open.fill")
                        .font(.rrHeadline)
                        .foregroundStyle(BrandTheme.ink)
                    Spacer()
                    Button("New") { isCreatingCoverLetter = true }
                        .disabled(approvedEvidenceCount == 0)
                        .accessibilityIdentifier("application.coverLetter.new")
                }
                Text("RoleReady drafts only from approved career evidence and shows warnings for claims it cannot support.")
                    .font(.rrBody)
                    .foregroundStyle(BrandTheme.inkMuted)
                if jobCoverLetters.isEmpty {
                    Text(approvedEvidenceCount == 0 ? "Approve career evidence to unlock a grounded draft." : "No cover letter yet.")
                        .font(.rrCaption)
                        .foregroundStyle(BrandTheme.inkMuted)
                } else {
                    ForEach(jobCoverLetters) { letter in
                        Button { editingLetter = letter } label: {
                            CoverLetterRow(letter: letter)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .cardSurface()
        }
    }

    private func trackerSection(_ opportunity: Opportunity) -> some View {
        VStack(alignment: .leading, spacing: RRSpacing.md) {
            SectionHeading(title: "Application tracker", eyebrow: "Keep the next move visible", actionTitle: "Add update") {
                isAddingActivity = true
            }

            ApplicationTrackerFields(opportunity: opportunity) {
                save(message: "Application details saved")
            }
            .cardSurface()

            if jobActivities.isEmpty {
                Text("Add applications, recruiter calls, assessments and outcomes to build a private timeline.")
                    .font(.rrBody)
                    .foregroundStyle(BrandTheme.inkMuted)
                    .cardSurface()
            } else {
                ForEach(jobActivities) { activity in
                    HStack(alignment: .top, spacing: RRSpacing.md) {
                        Image(systemName: activity.kind.symbol)
                            .foregroundStyle(BrandTheme.violet)
                            .frame(width: 34, height: 34)
                            .background(BrandTheme.violetSoft, in: Circle())
                        VStack(alignment: .leading, spacing: 3) {
                            Text(activity.title).font(.rrHeadline).foregroundStyle(BrandTheme.ink)
                            Text("\(activity.kind.title) · \(activity.occurredAt.formatted(date: .abbreviated, time: .shortened))")
                                .font(.rrCaption).foregroundStyle(BrandTheme.inkMuted)
                            if !activity.notes.isEmpty {
                                Text(activity.notes).font(.rrBody).foregroundStyle(BrandTheme.inkMuted)
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    .cardSurface(padding: RRSpacing.sm)
                }
            }
        }
    }

    private var reminderSection: some View {
        VStack(alignment: .leading, spacing: RRSpacing.md) {
            SectionHeading(title: "Follow-ups", eyebrow: "In-app and optional notification", actionTitle: "Add reminder") {
                isAddingReminder = true
            }
            if jobReminders.isEmpty {
                Text("Set a reminder to check the application, follow up, or prepare for a scheduled stage.")
                    .font(.rrBody)
                    .foregroundStyle(BrandTheme.inkMuted)
                    .cardSurface()
            } else {
                ForEach(jobReminders) { reminder in
                    ReminderRow(reminder: reminder) {
                        complete(reminder)
                    } onDelete: {
                        delete(reminder)
                    }
                }
            }
        }
    }

    private func interviewSection(_ opportunity: Opportunity) -> some View {
        VStack(alignment: .leading, spacing: RRSpacing.md) {
            SectionHeading(title: "Interview handoff", eyebrow: "Use the same job and evidence")
            Text("Turn confirmed requirements and your approved career examples into a focused prep deck. Tailoring gaps stay visible so practice does not turn into invention.")
                .font(.rrBody)
                .foregroundStyle(BrandTheme.inkMuted)
            Button {
                router.navigate(to: .prepDeck(opportunity.id))
            } label: {
                Label("Open interview prep for this job", systemImage: "quote.bubble.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(SecondaryActionButtonStyle())
            .accessibilityIdentifier("application.interviewPrep")
        }
        .cardSurface(tint: BrandTheme.tealSoft.opacity(0.45))
    }

    private var confirmedRequirements: [JobRequirement] { requirements.filter(\.isConfirmed) }
    private var approvedPositions: [CareerPosition] { positions.filter { $0.verificationStatus.permitsGeneration } }
    private var approvedSkills: [CareerSkill] { skills.filter { $0.verificationStatus.permitsGeneration } }
    private var approvedEvidenceCount: Int { approvedPositions.count + approvedSkills.count }
    private var baselineResumes: [ResumeVersion] { resumes.filter { $0.opportunityID == nil && $0.status != .archived } }
    private var jobResumes: [ResumeVersion] { resumes.filter { $0.opportunityID == opportunityID } }
    private var jobCoverLetters: [CoverLetter] { coverLetters.filter { $0.opportunityID == opportunityID } }
    private var jobActivities: [ApplicationActivity] { activities.filter { $0.opportunityID == opportunityID } }
    private var jobReminders: [CareerReminder] { reminders.filter { $0.opportunityID == opportunityID } }
    private var approvedSourceText: [String] {
        approvedPositions.flatMap { [$0.title, $0.organisation, $0.summary] + $0.bullets + $0.skills }
            + approvedSkills.flatMap { [$0.name, $0.sourceExcerpt] }
    }

    private func tailor(_ resume: ResumeVersion, for opportunity: Opportunity) {
        do {
            let version = try CareerApplicationService().makeTailoredResume(
                baseline: resume,
                opportunity: opportunity,
                requirements: requirements,
                positions: positions,
                skills: skills,
                in: modelContext
            )
            appState.showToast("Tailored résumé created", symbol: "checkmark.seal.fill")
            router.navigate(to: .resume(version.id))
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func createCoverLetter(motivation: String, tone: String, targetWords: Int) {
        guard let opportunity = opportunities.first else { return }
        do {
            let letter = try CareerApplicationService().makeCoverLetter(
                opportunity: opportunity,
                resume: jobResumes.first ?? baselineResumes.first,
                requirements: requirements,
                positions: positions,
                skills: skills,
                profile: profiles.first,
                motivation: motivation,
                tone: tone,
                targetWords: targetWords,
                in: modelContext
            )
            appState.showToast("Grounded cover letter drafted", symbol: "envelope.open.fill")
            editingLetter = letter
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func updateStatus(_ opportunity: Opportunity, status: OpportunityStatus) {
        guard opportunity.status != status else { return }
        opportunity.status = status
        opportunity.updatedAt = Date()
        if status == .applied && opportunity.appliedAt == nil { opportunity.appliedAt = Date() }
        let activity = ApplicationActivity(
            opportunityID: opportunity.id,
            kind: status.activityKind,
            title: "Moved to \(status.title)"
        )
        modelContext.insert(activity)
        save(message: "Moved to \(status.title)")
    }

    private func addActivity(kind: ApplicationActivityKind, title: String, notes: String, occurredAt: Date) {
        modelContext.insert(ApplicationActivity(
            opportunityID: opportunityID,
            kind: kind,
            title: title,
            notes: notes,
            occurredAt: occurredAt
        ))
        save(message: "Application update added")
    }

    private func addReminder(kind: CareerReminderKind, title: String, notes: String, dueAt: Date) {
        let reminder = CareerReminder(
            opportunityID: opportunityID,
            kind: kind,
            title: title,
            notes: notes,
            dueAt: dueAt
        )
        modelContext.insert(reminder)
        do {
            try modelContext.save()
            appState.showToast("Reminder saved", symbol: "bell.fill")
        } catch {
            modelContext.rollback()
            errorMessage = error.localizedDescription
            return
        }
        Task { @MainActor in
            let identifier = "roleready.career.\(reminder.id.uuidString)"
            do {
                try await NotificationService().schedule(
                    identifier: identifier,
                    title: title,
                    body: notes.isEmpty ? "Open RoleReady to update your application progress." : notes,
                    dueAt: dueAt
                )
                reminder.notificationIdentifier = identifier
                try? modelContext.save()
            } catch NotificationServiceError.denied {
                appState.showToast("Saved in app; notifications are off", symbol: "bell.slash.fill")
            } catch {
                appState.showToast("Saved in app; notification was not scheduled", symbol: "bell.slash.fill")
            }
        }
    }

    private func complete(_ reminder: CareerReminder) {
        reminder.isCompleted.toggle()
        reminder.completedAt = reminder.isCompleted ? Date() : nil
        reminder.updatedAt = Date()
        if reminder.isCompleted, !reminder.notificationIdentifier.isEmpty {
            NotificationService().cancel(identifier: reminder.notificationIdentifier)
        }
        save(message: reminder.isCompleted ? "Reminder completed" : "Reminder reopened")
    }

    private func delete(_ reminder: CareerReminder) {
        if !reminder.notificationIdentifier.isEmpty {
            NotificationService().cancel(identifier: reminder.notificationIdentifier)
        }
        modelContext.delete(reminder)
        save(message: "Reminder deleted")
    }

    private func save(message: String) {
        do {
            try modelContext.save()
            appState.showToast(message, symbol: "checkmark.circle.fill")
        } catch {
            modelContext.rollback()
            errorMessage = error.localizedDescription
        }
    }
}

private struct ApplicationHero: View {
    @Bindable var opportunity: Opportunity
    let onStatusChange: (OpportunityStatus) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: RRSpacing.lg) {
            Label("APPLICATION WORKSPACE", systemImage: "briefcase.fill")
                .font(.rrCaption).tracking(0.8).foregroundStyle(.white.opacity(0.78))
            Text(opportunity.roleTitle.isEmpty ? "Untitled role" : opportunity.roleTitle)
                .font(.rrHero).foregroundStyle(.white)
            Text(opportunity.organisation.isEmpty ? "Organisation not added" : opportunity.organisation)
                .font(.rrHeadline).foregroundStyle(.white.opacity(0.86))
            Menu {
                ForEach(OpportunityStatus.allCases) { status in
                    Button {
                        onStatusChange(status)
                    } label: {
                        Label(status.title, systemImage: status == opportunity.status ? "checkmark" : status.symbol)
                    }
                }
            } label: {
                HStack {
                    Label(opportunity.status.title, systemImage: opportunity.status.symbol)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                }
                .font(.rrHeadline)
                .foregroundStyle(.white)
                .padding(RRSpacing.md)
                .background(.white.opacity(0.13), in: RoundedRectangle(cornerRadius: RRRadius.medium))
            }
            .accessibilityIdentifier("application.status")
        }
        .padding(RRSpacing.lg)
        .background(BrandTheme.heroGradient, in: RoundedRectangle(cornerRadius: RRRadius.hero))
        .shadow(color: BrandTheme.violet.opacity(0.18), radius: 20, y: 10)
    }
}

private struct TailoredResumeCard: View {
    let resume: ResumeVersion
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: RRSpacing.sm) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(resume.name).font(.rrHeadline).foregroundStyle(BrandTheme.ink)
                        Text("Updated \(resume.updatedAt.formatted(.relative(presentation: .named)))")
                            .font(.rrCaption).foregroundStyle(BrandTheme.inkMuted)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").foregroundStyle(BrandTheme.inkMuted)
                }
                if !resume.tailoringReport.matches.isEmpty {
                    let direct = resume.tailoringReport.matches.filter { $0.classification == .direct }.count
                    let gaps = resume.tailoringReport.matches.filter { $0.classification == .noEvidence }.count
                    HStack(spacing: RRSpacing.sm) {
                        EvidenceBadge(text: "\(direct) direct", colour: BrandTheme.tealText)
                        EvidenceBadge(text: "\(gaps) gaps", colour: gaps == 0 ? BrandTheme.tealText : BrandTheme.amberText)
                    }
                    ForEach(resume.tailoringReport.matches.prefix(3)) { match in
                        HStack(alignment: .top, spacing: RRSpacing.xs) {
                            Image(systemName: match.classification.symbol)
                                .foregroundStyle(match.classification.colour)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(match.requirement).font(.subheadline.weight(.semibold)).foregroundStyle(BrandTheme.ink)
                                Text(match.classification.title).font(.rrCaption).foregroundStyle(BrandTheme.inkMuted)
                            }
                        }
                    }
                }
            }
            .padding(RRSpacing.sm)
            .background(BrandTheme.canvasRaised, in: RoundedRectangle(cornerRadius: RRRadius.medium))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("application.resume.\(resume.id.uuidString)")
    }
}

private struct EvidenceBadge: View {
    let text: String
    let colour: Color

    var body: some View {
        Text(text.uppercased())
            .font(.caption2.bold())
            .foregroundStyle(colour)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(colour.opacity(0.12), in: Capsule())
    }
}

private struct CoverLetterRow: View {
    let letter: CoverLetter

    var body: some View {
        HStack(alignment: .top, spacing: RRSpacing.sm) {
            Image(systemName: letter.validationWarnings.isEmpty ? "checkmark.shield.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(letter.validationWarnings.isEmpty ? BrandTheme.tealText : BrandTheme.amberText)
            VStack(alignment: .leading, spacing: 3) {
                Text(letter.title).font(.rrHeadline).foregroundStyle(BrandTheme.ink)
                Text("\(letter.body.split(whereSeparator: \.isWhitespace).count) words · \(letter.status.title)")
                    .font(.rrCaption).foregroundStyle(BrandTheme.inkMuted)
                if !letter.validationWarnings.isEmpty {
                    Text("\(letter.validationWarnings.count) grounding warning\(letter.validationWarnings.count == 1 ? "" : "s")")
                        .font(.rrCaption).foregroundStyle(BrandTheme.amberText)
                }
            }
            Spacer()
            Image(systemName: "chevron.right").foregroundStyle(BrandTheme.inkMuted)
        }
        .padding(RRSpacing.sm)
        .background(BrandTheme.canvasRaised, in: RoundedRectangle(cornerRadius: RRRadius.medium))
        .contentShape(Rectangle())
    }
}

private struct ApplicationTrackerFields: View {
    @Bindable var opportunity: Opportunity
    let onSave: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: RRSpacing.md) {
            TextField("Next action", text: $opportunity.nextAction, axis: .vertical)
                .textFieldStyle(.roundedBorder)
            TextField("Recruiter or contact", text: $opportunity.contactName)
                .textFieldStyle(.roundedBorder)
            TextField("Contact details", text: $opportunity.contactDetails)
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.never)
            TextField("Private notes", text: $opportunity.notes, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(3...8)
            Button("Save tracker details", action: onSave)
                .buttonStyle(SecondaryActionButtonStyle())
                .accessibilityIdentifier("application.tracker.save")
        }
    }
}

private struct ReminderRow: View {
    let reminder: CareerReminder
    let onToggle: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: RRSpacing.md) {
            Button(action: onToggle) {
                Image(systemName: reminder.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3).foregroundStyle(reminder.isCompleted ? BrandTheme.tealText : BrandTheme.violet)
            }
            .accessibilityLabel(reminder.isCompleted ? "Reopen reminder" : "Complete reminder")
            VStack(alignment: .leading, spacing: 3) {
                Text(reminder.title).font(.rrHeadline).foregroundStyle(BrandTheme.ink)
                    .strikethrough(reminder.isCompleted)
                Text("\(reminder.kind.title) · \(reminder.dueAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.rrCaption).foregroundStyle(BrandTheme.inkMuted)
                if !reminder.notes.isEmpty { Text(reminder.notes).font(.rrBody).foregroundStyle(BrandTheme.inkMuted) }
            }
            Spacer(minLength: 0)
            Menu {
                Button("Delete", systemImage: "trash", role: .destructive, action: onDelete)
            } label: {
                Image(systemName: "ellipsis").frame(width: 44, height: 44)
            }
            .accessibilityLabel("Reminder actions")
        }
        .cardSurface(padding: RRSpacing.sm)
    }
}

private struct CoverLetterSetupSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var motivation = ""
    @State private var tone = "Direct and professional"
    @State private var targetWords = 300
    let onCreate: (String, String, Int) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Why this job") {
                    TextField("Optional motivation in your own words", text: $motivation, axis: .vertical)
                        .lineLimit(3...7)
                    Text("RoleReady treats this as user-provided context; it will not invent motivation for you.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("Draft settings") {
                    Picker("Tone", selection: $tone) {
                        Text("Direct and professional").tag("Direct and professional")
                        Text("Warm and concise").tag("Warm and concise")
                        Text("Technical and precise").tag("Technical and precise")
                    }
                    Stepper("Target: \(targetWords) words", value: $targetWords, in: 250...400, step: 25)
                }
            }
            .navigationTitle("New cover letter")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        dismiss()
                        onCreate(motivation, tone, targetWords)
                    }
                }
            }
        }
    }
}

private struct CoverLetterEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Bindable var letter: CoverLetter
    let approvedSources: [String]
    let allowedContext: [String]
    @State private var originalBody = ""
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Letter") {
                    TextField("Title", text: $letter.title)
                    TextEditor(text: $letter.body).frame(minHeight: 360)
                    Text("\(letter.body.split(whereSeparator: \.isWhitespace).count) words")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if !letter.validationWarnings.isEmpty {
                    Section("Needs your review") {
                        ForEach(letter.validationWarnings, id: \.self) { warning in
                            Label(warning, systemImage: "exclamationmark.triangle.fill")
                                .foregroundStyle(BrandTheme.amberText)
                        }
                    }
                }
                Section("Evidence trail") {
                    Text("Generated by \(letter.generator.isEmpty ? "RoleReady" : letter.generator)")
                    ForEach(letter.grounding.paragraphs) { paragraph in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(paragraph.claimType.uppercased()).font(.caption2.bold()).foregroundStyle(.secondary)
                            Text(paragraph.text).font(.subheadline)
                            if !paragraph.sourceEntityIDs.isEmpty {
                                Label("Linked to \(paragraph.sourceEntityIDs.count) approved source\(paragraph.sourceEntityIDs.count == 1 ? "" : "s")", systemImage: "link")
                                    .font(.caption).foregroundStyle(BrandTheme.tealText)
                            }
                        }
                    }
                }
                Section("Status") {
                    Picker("Status", selection: Binding(
                        get: { letter.status },
                        set: { letter.status = $0 }
                    )) {
                        ForEach(CoverLetterStatus.allCases) { status in Text(status.title).tag(status) }
                    }
                    if letter.status == .approved && !letter.validationWarnings.isEmpty {
                        Text("Resolve grounding warnings before treating this letter as approved.")
                            .font(.caption).foregroundStyle(BrandTheme.amberText)
                    }
                }
            }
            .navigationTitle("Cover letter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save", action: save) }
            }
            .onAppear { originalBody = letter.body }
            .alert("Could not save", isPresented: Binding(
                get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }
            )) { Button("OK", role: .cancel) {} } message: { Text(errorMessage ?? "Try again.") }
        }
    }

    private func save() {
        letter.isUserEdited = letter.body != originalBody
        letter.validationWarnings = ClaimValidationService().validate(
            generatedText: letter.body,
            approvedSources: approvedSources,
            allowedContext: allowedContext
        )
        if letter.status == .approved && !letter.validationWarnings.isEmpty { letter.status = .draft }
        letter.updatedAt = Date()
        do {
            try modelContext.save()
            dismiss()
        } catch {
            modelContext.rollback()
            errorMessage = error.localizedDescription
        }
    }
}

private struct ActivityEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var kind = ApplicationActivityKind.note
    @State private var title = ""
    @State private var notes = ""
    @State private var occurredAt = Date()
    let onSave: (ApplicationActivityKind, String, String, Date) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Picker("Update type", selection: $kind) {
                    ForEach(ApplicationActivityKind.allCases) { kind in Text(kind.title).tag(kind) }
                }
                TextField("What happened?", text: $title)
                TextField("Notes", text: $notes, axis: .vertical).lineLimit(3...8)
                DatePicker("When", selection: $occurredAt)
            }
            .navigationTitle("Application update")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        dismiss()
                        onSave(kind, title.trimmingCharacters(in: .whitespacesAndNewlines), notes, occurredAt)
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

private struct ReminderEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var kind = CareerReminderKind.checkProgress
    @State private var title = "Check application progress"
    @State private var notes = ""
    @State private var dueAt = Date().addingTimeInterval(3 * 24 * 60 * 60)
    let onSave: (CareerReminderKind, String, String, Date) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Picker("Reminder type", selection: $kind) {
                    ForEach(CareerReminderKind.allCases) { kind in Text(kind.title).tag(kind) }
                }
                TextField("Reminder", text: $title)
                TextField("Notes", text: $notes, axis: .vertical).lineLimit(2...6)
                DatePicker("Due", selection: $dueAt, in: Date().addingTimeInterval(60)...)
                Text("The reminder remains visible in RoleReady even if you decline notifications.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .navigationTitle("New reminder")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        dismiss()
                        onSave(kind, title.trimmingCharacters(in: .whitespacesAndNewlines), notes, dueAt)
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

private extension ApplicationActivityKind {
    var symbol: String {
        switch self {
        case .saved: "bookmark.fill"
        case .applied: "paperplane.fill"
        case .followUp: "arrowshape.turn.up.right.fill"
        case .recruiterContact: "phone.fill"
        case .assessment: "checklist"
        case .interview: "person.2.fill"
        case .offer: "party.popper.fill"
        case .outcome: "flag.checkered"
        case .note: "note.text"
        }
    }
}

private extension OpportunityStatus {
    var activityKind: ApplicationActivityKind {
        switch self {
        case .saved, .preparing: .saved
        case .applied: .applied
        case .recruiterScreen: .recruiterContact
        case .assessment: .assessment
        case .interviewing: .interview
        case .offer: .offer
        case .rejected, .withdrawn, .closed: .outcome
        }
    }
}

private extension EvidenceClassification {
    var symbol: String {
        switch self {
        case .direct: "checkmark.seal.fill"
        case .transferable: "arrow.triangle.branch"
        case .partial: "circle.lefthalf.filled"
        case .noEvidence: "questionmark.diamond.fill"
        }
    }

    var colour: Color {
        switch self {
        case .direct: BrandTheme.tealText
        case .transferable: BrandTheme.violet
        case .partial, .noEvidence: BrandTheme.amberText
        }
    }
}
