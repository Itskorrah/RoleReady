import SwiftData
import SwiftUI

struct ProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @Query(sort: \CareerProfile.updatedAt, order: .reverse) private var profiles: [CareerProfile]

    @State private var name = ""
    @State private var headline = ""
    @State private var organisation = ""
    @State private var summary = ""
    @State private var targetRoles = ""
    @State private var skills = ""
    @State private var careerGoal = ""
    @State private var errorMessage: String?
    @State private var baseline = ProfileDraft.empty
    @State private var isConfirmingDiscard = false

    var body: some View {
        Form {
            Section {
                HStack(spacing: RRSpacing.md) {
                    ProfileMonogram(name: name)
                    VStack(alignment: .leading, spacing: RRSpacing.xxs) {
                        Text(name.isEmpty ? "Your career profile" : name)
                            .font(.rrTitle)
                        Text(headline.isEmpty ? "Add your current professional focus" : headline)
                            .font(.subheadline)
                            .foregroundStyle(BrandTheme.inkMuted)
                    }
                }
                .padding(.vertical, RRSpacing.xs)
            }
            .listRowBackground(BrandTheme.violetSoft.opacity(0.5))

            Section("Professional identity") {
                TextField("Name", text: $name)
                    .textContentType(.name)
                    .accessibilityIdentifier("profile-name")
                TextField("Current role", text: $headline)
                TextField("Organisation", text: $organisation)
                TextField("Professional summary", text: $summary, axis: .vertical)
                    .lineLimit(3...8)
            }

            Section {
                TextField("Senior Data Engineer, Analytics Engineer", text: $targetRoles, axis: .vertical)
                    .lineLimit(2...5)
            } header: {
                Text("Target roles")
            } footer: {
                Text("Separate roles with commas. These guide suggestions; they never change your evidence.")
            }

            Section {
                TextField("Python, facilitation, project delivery", text: $skills, axis: .vertical)
                    .lineLimit(3...7)
            } header: {
                Text("Skills & tools")
            } footer: {
                Text("Use names that appear in the roles you target.")
            }

            Section("Career direction") {
                TextField("What would you like your next role to make possible?", text: $careerGoal, axis: .vertical)
                    .lineLimit(3...8)
            }

            Section {
                Button {
                    save()
                } label: {
                    Label("Save profile", systemImage: "checkmark.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryActionButtonStyle())
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .accessibilityIdentifier("save-profile")
            }
        }
        .navigationTitle("Profile")
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
                    .accessibilityIdentifier("profile-back")
                }
            }
        }
        .alert("Couldn’t save profile", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) { Button("OK", role: .cancel) {} } message: { Text(errorMessage ?? "Try again.") }
        .confirmationDialog(
            "Discard profile changes?",
            isPresented: $isConfirmingDiscard,
            titleVisibility: .visible
        ) {
            Button("Discard changes", role: .destructive) { dismiss() }
            Button("Keep editing", role: .cancel) {}
        } message: {
            Text("Your last saved profile will remain unchanged.")
        }
    }

    private var currentDraft: ProfileDraft {
        ProfileDraft(
            name: name,
            headline: headline,
            organisation: organisation,
            summary: summary,
            targetRoles: targetRoles,
            skills: skills,
            careerGoal: careerGoal
        )
    }

    private var hasUnsavedChanges: Bool { currentDraft != baseline }

    private func load() {
        guard let profile = profiles.first else { return }
        name = profile.name
        headline = profile.headline
        organisation = profile.currentOrganisation
        summary = profile.professionalSummary
        targetRoles = profile.targetRoles.joined(separator: ", ")
        skills = profile.skills.joined(separator: ", ")
        careerGoal = profile.careerGoal
        baseline = currentDraft
    }

    private func save() {
        let profile: CareerProfile
        if let existing = profiles.first {
            profile = existing
        } else {
            profile = CareerProfile(name: "", headline: "", professionalSummary: "", currentOrganisation: "", targetRoles: [], skills: [], careerGoal: "")
            modelContext.insert(profile)
        }
        profile.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        profile.headline = headline.trimmingCharacters(in: .whitespacesAndNewlines)
        profile.currentOrganisation = organisation.trimmingCharacters(in: .whitespacesAndNewlines)
        profile.professionalSummary = summary.trimmingCharacters(in: .whitespacesAndNewlines)
        profile.targetRoles = splitList(targetRoles)
        profile.skills = splitList(skills)
        profile.careerGoal = careerGoal.trimmingCharacters(in: .whitespacesAndNewlines)
        profile.updatedAt = Date()
        do {
            try modelContext.save()
            name = profile.name
            headline = profile.headline
            organisation = profile.currentOrganisation
            summary = profile.professionalSummary
            targetRoles = profile.targetRoles.joined(separator: ", ")
            skills = profile.skills.joined(separator: ", ")
            careerGoal = profile.careerGoal
            baseline = currentDraft
            appState.showToast("Profile saved")
            HapticService.success(enabled: appState.hapticsEnabled)
        } catch {
            modelContext.rollback()
            errorMessage = error.localizedDescription
        }
    }

    private func splitList(_ text: String) -> [String] {
        text.components(separatedBy: CharacterSet(charactersIn: ",\n"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func requestDismissal() {
        guard hasUnsavedChanges else {
            dismiss()
            return
        }
        isConfirmingDiscard = true
    }
}

private struct ProfileDraft: Equatable {
    let name: String
    let headline: String
    let organisation: String
    let summary: String
    let targetRoles: String
    let skills: String
    let careerGoal: String

    static let empty = ProfileDraft(
        name: "",
        headline: "",
        organisation: "",
        summary: "",
        targetRoles: "",
        skills: "",
        careerGoal: ""
    )
}

private struct ProfileMonogram: View {
    let name: String

    var body: some View {
        ZStack {
            Circle().fill(BrandTheme.heroGradient)
            Text(initials)
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(.white)
        }
        .frame(width: 62, height: 62)
        .accessibilityHidden(true)
    }

    private var initials: String {
        let value = name.split(separator: " ").prefix(2).compactMap(\.first).map(String.init).joined()
        return value.isEmpty ? "RR" : value.uppercased()
    }
}
