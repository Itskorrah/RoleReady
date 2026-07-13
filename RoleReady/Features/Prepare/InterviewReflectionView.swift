import SwiftData
import SwiftUI

struct InterviewReflectionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @Query(sort: \Opportunity.updatedAt, order: .reverse) private var opportunities: [Opportunity]
    @Query(sort: \Experience.updatedAt, order: .reverse) private var experiences: [Experience]
    @Query(sort: \InterviewReflection.updatedAt, order: .reverse) private var reflections: [InterviewReflection]

    let opportunityID: UUID

    @State private var questionsText = ""
    @State private var selectedExperienceIDs: Set<UUID> = []
    @State private var strongestMoment = ""
    @State private var difficultMoment = ""
    @State private var feedback = ""
    @State private var nextImprovement = ""
    @State private var errorMessage: String?
    @State private var baseline = ReflectionDraft.empty
    @State private var isConfirmingDiscard = false

    var body: some View {
        Form {
            Section {
                InfoBanner(
                    title: "Reflect while it’s fresh",
                    message: "Record what actually happened. Nothing here changes an underlying story until you edit and confirm it.",
                    kind: .information
                )
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

            Section {
                TextField("One question per line", text: $questionsText, axis: .vertical)
                    .lineLimit(4...12)
                    .accessibilityIdentifier("reflection-questions")
            } header: {
                Text("Questions you were asked")
            } footer: {
                Text("Include unexpected questions and useful follow-ups.")
            }

            Section {
                if experiences.isEmpty {
                    Text("No stories recorded")
                        .foregroundStyle(BrandTheme.inkMuted)
                } else {
                    ForEach(experiences) { experience in
                        Button {
                            toggle(experience.id)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(experience.title)
                                        .foregroundStyle(BrandTheme.ink)
                                    Text(experience.organisation)
                                        .font(.caption)
                                        .foregroundStyle(BrandTheme.inkMuted)
                                }
                                Spacer()
                                Image(systemName: selectedExperienceIDs.contains(experience.id) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(selectedExperienceIDs.contains(experience.id) ? BrandTheme.success : BrandTheme.separator)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityValue(selectedExperienceIDs.contains(experience.id) ? "Selected" : "Not selected")
                    }
                }
            } header: {
                Text("Stories you used")
            }

            Section("What felt strong") {
                TextField("Where did your answer feel clear or credible?", text: $strongestMoment, axis: .vertical)
                    .lineLimit(2...6)
            }

            Section("What was difficult") {
                TextField("Where did you hesitate or need more detail?", text: $difficultMoment, axis: .vertical)
                    .lineLimit(2...6)
            }

            Section("Feedback or panel reaction") {
                TextField("Follow-up questions, comments, or formal feedback", text: $feedback, axis: .vertical)
                    .lineLimit(2...6)
            }

            Section {
                TextField("One concrete change for next time", text: $nextImprovement, axis: .vertical)
                    .lineLimit(2...6)
            } header: {
                Text("Next improvement")
            } footer: {
                Text("RoleReady stores this as a coaching note. Review the source story separately before changing its facts.")
            }

            Section {
                Button {
                    save()
                } label: {
                    Label("Save reflection", systemImage: "checkmark.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryActionButtonStyle())
                .disabled(!hasMeaningfulContent)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .accessibilityIdentifier("save-reflection")
            }
        }
        .navigationTitle("Interview reflection")
        .navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .screenBackground()
        .onAppear(perform: load)
        .interactiveDismissDisabled(hasUnsavedChanges)
        .navigationBarBackButtonHidden(hasUnsavedChanges)
        .toolbar {
            if hasUnsavedChanges {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: requestDismissal) {
                        Label("Back", systemImage: "chevron.left")
                    }
                    .accessibilityIdentifier("reflection-back")
                }
            }
        }
        .alert("Couldn’t save reflection", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) { Button("OK", role: .cancel) {} } message: { Text(errorMessage ?? "Try again.") }
        .confirmationDialog(
            "Discard reflection changes?",
            isPresented: $isConfirmingDiscard,
            titleVisibility: .visible
        ) {
            Button("Discard changes", role: .destructive) { dismiss() }
            Button("Keep editing", role: .cancel) {}
        } message: {
            Text("Your last saved reflection will remain unchanged.")
        }
    }

    private var opportunity: Opportunity? { opportunities.first { $0.id == opportunityID } }
    private var existing: InterviewReflection? { reflections.first { $0.opportunityID == opportunityID } }
    private var currentDraft: ReflectionDraft {
        ReflectionDraft(
            questionsText: questionsText,
            selectedExperienceIDs: selectedExperienceIDs,
            strongestMoment: strongestMoment,
            difficultMoment: difficultMoment,
            feedback: feedback,
            nextImprovement: nextImprovement
        )
    }
    private var hasUnsavedChanges: Bool { currentDraft != baseline }
    private var hasMeaningfulContent: Bool {
        !questionsText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !selectedExperienceIDs.isEmpty
            || !strongestMoment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !difficultMoment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !feedback.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !nextImprovement.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func load() {
        guard let existing else { return }
        questionsText = existing.questions.joined(separator: "\n")
        selectedExperienceIDs = Set(existing.experienceIDs)
        strongestMoment = existing.strongestMoment
        difficultMoment = existing.difficultMoment
        feedback = existing.feedback
        nextImprovement = existing.nextImprovement
        baseline = currentDraft
    }

    private func toggle(_ id: UUID) {
        if selectedExperienceIDs.contains(id) {
            selectedExperienceIDs.remove(id)
        } else {
            selectedExperienceIDs.insert(id)
        }
        HapticService.selection(enabled: appState.hapticsEnabled)
    }

    private func save() {
        guard hasMeaningfulContent else {
            errorMessage = "Add at least one question, story, or reflection note before saving."
            return
        }
        let questions = questionsText.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        if let existing {
            existing.questions = questions
            existing.experienceIDs = Array(selectedExperienceIDs)
            existing.strongestMoment = strongestMoment.trimmingCharacters(in: .whitespacesAndNewlines)
            existing.difficultMoment = difficultMoment.trimmingCharacters(in: .whitespacesAndNewlines)
            existing.feedback = feedback.trimmingCharacters(in: .whitespacesAndNewlines)
            existing.nextImprovement = nextImprovement.trimmingCharacters(in: .whitespacesAndNewlines)
            existing.updatedAt = Date()
        } else {
            modelContext.insert(InterviewReflection(
                opportunityID: opportunityID,
                questions: questions,
                experienceIDs: Array(selectedExperienceIDs),
                strongestMoment: strongestMoment.trimmingCharacters(in: .whitespacesAndNewlines),
                difficultMoment: difficultMoment.trimmingCharacters(in: .whitespacesAndNewlines),
                feedback: feedback.trimmingCharacters(in: .whitespacesAndNewlines),
                nextImprovement: nextImprovement.trimmingCharacters(in: .whitespacesAndNewlines)
            ))
        }
        do {
            try modelContext.save()
            questionsText = questions.joined(separator: "\n")
            strongestMoment = strongestMoment.trimmingCharacters(in: .whitespacesAndNewlines)
            difficultMoment = difficultMoment.trimmingCharacters(in: .whitespacesAndNewlines)
            feedback = feedback.trimmingCharacters(in: .whitespacesAndNewlines)
            nextImprovement = nextImprovement.trimmingCharacters(in: .whitespacesAndNewlines)
            baseline = currentDraft
            appState.showToast("Reflection saved")
            HapticService.success(enabled: appState.hapticsEnabled)
        } catch {
            modelContext.rollback()
            errorMessage = error.localizedDescription
        }
    }

    private func requestDismissal() {
        guard hasUnsavedChanges else {
            dismiss()
            return
        }
        isConfirmingDiscard = true
    }
}

private struct ReflectionDraft: Equatable {
    let questionsText: String
    let selectedExperienceIDs: Set<UUID>
    let strongestMoment: String
    let difficultMoment: String
    let feedback: String
    let nextImprovement: String

    static let empty = ReflectionDraft(
        questionsText: "",
        selectedExperienceIDs: [],
        strongestMoment: "",
        difficultMoment: "",
        feedback: "",
        nextImprovement: ""
    )
}
