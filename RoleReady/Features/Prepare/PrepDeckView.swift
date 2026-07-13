import SwiftData
import SwiftUI

struct PrepDeckView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppRouter.self) private var router
    @Environment(AppState.self) private var appState
    @Query(sort: \GeneratedAnswer.updatedAt, order: .reverse) private var allAnswers: [GeneratedAnswer]
    @Query(sort: \Opportunity.updatedAt, order: .reverse) private var opportunities: [Opportunity]
    @Query(sort: \Experience.updatedAt, order: .reverse) private var experiences: [Experience]

    let opportunityID: UUID?

    @State private var currentIndex = 0
    @State private var isRevealed = false
    @State private var showFullStructure = false
    @State private var startedAt = Date()
    @State private var errorMessage: String?
    @State private var isComplete = false
    @State private var strongCount = 0
    @State private var retryCount = 0

    var body: some View {
        ScrollView {
            VStack(spacing: RRSpacing.lg) {
                InfoBanner(
                    title: "Practice before the interview",
                    message: "This deck is designed for rehearsal and recall. Put it away when the interview begins.",
                    kind: .information
                )
                if answers.isEmpty {
                    EmptyStatePanel(
                        title: "No approved answers yet",
                        message: "Confirm an answer’s facts before adding it to a practice deck.",
                        symbol: "rectangle.stack.badge.plus",
                        actionTitle: "Build an answer",
                        action: { router.navigate(to: .answerStudio(experienceID: nil, opportunityID: opportunityID)) }
                    )
                } else if isComplete {
                    completionState
                } else {
                    progressHeader
                    promptCard(answers[safe: currentIndex] ?? answers[0])
                    ratingControls(answers[safe: currentIndex] ?? answers[0])
                }
            }
            .padding(RRSpacing.md)
            .padding(.bottom, RRSpacing.xxl)
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle(opportunity?.roleTitle ?? "Prep deck")
        .navigationBarTitleDisplayMode(.inline)
        .screenBackground()
        .onAppear { startedAt = Date() }
        .onChange(of: answers.map(\.id)) { _, _ in
            if answers.isEmpty {
                currentIndex = 0
                isComplete = false
            } else {
                currentIndex = min(currentIndex, answers.count - 1)
            }
        }
        .alert("Practice", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) { Button("OK", role: .cancel) {} } message: { Text(errorMessage ?? "Try again.") }
        .accessibilityIdentifier("prep-deck")
    }

    private var answers: [GeneratedAnswer] {
        let sources = Dictionary(uniqueKeysWithValues: experiences.map { ($0.id, $0) })
        let roles = Dictionary(uniqueKeysWithValues: opportunities.map { ($0.id, $0) })
        allAnswers.filter { answer in
            answer.isApprovalCurrent(
                for: sources[answer.experienceID],
                opportunity: answer.opportunityID.flatMap { roles[$0] }
            )
                && (opportunityID == nil || answer.opportunityID == opportunityID)
        }
    }

    private var opportunity: Opportunity? {
        guard let opportunityID else { return nil }
        return opportunities.first { $0.id == opportunityID }
    }

    private var progressHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: RRSpacing.xxs) {
                Text("QUESTION \(currentIndex + 1) OF \(answers.count)")
                    .font(.rrCaption)
                    .tracking(0.8)
                    .foregroundStyle(BrandTheme.violet)
                ProgressView(value: Double(currentIndex + 1), total: Double(max(answers.count, 1)))
                    .tint(BrandTheme.violet)
                    .frame(maxWidth: 260)
            }
            Spacer()
            TimelineView(.periodic(from: startedAt, by: 1)) { context in
                Label(duration(from: startedAt, to: context.date), systemImage: "timer")
                    .font(.rrHeadline)
                    .monospacedDigit()
                    .foregroundStyle(BrandTheme.inkMuted)
                    .accessibilityLabel("Practice timer \(duration(from: startedAt, to: context.date))")
            }
        }
    }

    private func promptCard(_ answer: GeneratedAnswer) -> some View {
        VStack(alignment: .leading, spacing: RRSpacing.lg) {
            HStack {
                Label(answer.format.title, systemImage: "quote.opening")
                    .font(.rrCaption)
                    .foregroundStyle(BrandTheme.violet)
                Spacer()
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(BrandTheme.success)
            }
            Text(answer.question)
                .font(.system(.title, design: .rounded, weight: .bold))
                .fixedSize(horizontal: false, vertical: true)

            if isRevealed {
                Divider()
                VStack(alignment: .leading, spacing: RRSpacing.sm) {
                    Text("MEMORY CUES")
                        .font(.rrCaption)
                        .tracking(0.8)
                        .foregroundStyle(BrandTheme.amberText)
                    ForEach(Array(answer.quickCues.enumerated()), id: \.offset) { index, cue in
                        HStack(alignment: .firstTextBaseline, spacing: RRSpacing.sm) {
                            Text("\(index + 1)")
                                .font(.caption.bold())
                                .foregroundStyle(BrandTheme.violet)
                                .frame(width: 26, height: 26)
                                .background(BrandTheme.violetSoft, in: Circle())
                            Text(cue)
                                .font(.rrHeadline)
                        }
                    }
                }
                if showFullStructure {
                    Divider()
                    Text(answer.content)
                        .font(.rrBody)
                        .foregroundStyle(BrandTheme.inkMuted)
                        .fixedSize(horizontal: false, vertical: true)
                        .transition(.opacity)
                }
                Button(showFullStructure ? "Hide suggested structure" : "Compare suggested structure") {
                    withAnimation(reduceMotion ? nil : .snappy) { showFullStructure.toggle() }
                }
                .font(.rrHeadline)
                .foregroundStyle(BrandTheme.violet)
            } else {
                Text("Say your answer aloud, then reveal the cues. Aim for the shape of the story—not exact wording.")
                    .font(.rrBody)
                    .foregroundStyle(BrandTheme.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
                Button {
                    withAnimation(reduceMotion ? nil : .snappy) { isRevealed = true }
                } label: {
                    Label("Reveal memory cues", systemImage: "eye.fill")
                }
                .buttonStyle(PrimaryActionButtonStyle())
                .accessibilityIdentifier("reveal-practice-cues")
            }
        }
        .frame(maxWidth: .infinity, minHeight: 360, alignment: .topLeading)
        .padding(RRSpacing.lg)
        .background(BrandTheme.surface, in: RoundedRectangle(cornerRadius: RRRadius.hero, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: RRRadius.hero, style: .continuous)
                .stroke(BrandTheme.separator, lineWidth: 0.75)
        }
        .shadow(color: .black.opacity(0.07), radius: 18, y: 10)
        .privacySensitive()
    }

    @ViewBuilder
    private func ratingControls(_ answer: GeneratedAnswer) -> some View {
        if isRevealed {
            VStack(alignment: .leading, spacing: RRSpacing.md) {
                Text("How did that feel?")
                    .font(.rrTitle)
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: RRSpacing.sm) { ratingButtons(answer) }
                    VStack(spacing: RRSpacing.sm) { ratingButtons(answer) }
                }
            }
            .cardSurface(tint: BrandTheme.tealSoft.opacity(0.45))
        } else {
            HStack {
                Button("Previous", systemImage: "chevron.left") { move(by: -1) }
                    .disabled(currentIndex == 0)
                Spacer()
                Button("Skip", systemImage: "chevron.right") { move(by: 1) }
                    .disabled(currentIndex == answers.count - 1)
            }
            .font(.rrHeadline)
        }
    }

    @ViewBuilder
    private func ratingButtons(_ answer: GeneratedAnswer) -> some View {
        ratingButton("Felt strong", symbol: "checkmark.circle.fill", confidence: 5, answer: answer)
        ratingButton("Another go", symbol: "arrow.counterclockwise", confidence: 3, answer: answer)
        ratingButton("Strengthen story", symbol: "wrench.adjustable.fill", confidence: 1, answer: answer)
    }

    private func ratingButton(_ title: String, symbol: String, confidence: Int, answer: GeneratedAnswer) -> some View {
        Button {
            saveRating(confidence, answer: answer)
        } label: {
            Label(title, systemImage: symbol)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(confidence == 5 ? AnyRRButtonStyle.primary : AnyRRButtonStyle.secondary)
    }

    private func saveRating(_ confidence: Int, answer: GeneratedAnswer) {
        let elapsed = max(Int(Date().timeIntervalSince(startedAt)), 0)
        modelContext.insert(PracticeSession(
            answerID: answer.id,
            experienceID: answer.experienceID,
            opportunityID: answer.opportunityID,
            question: answer.question,
            durationSeconds: elapsed,
            confidence: confidence
        ))
        do {
            try modelContext.save()
            HapticService.success(enabled: appState.hapticsEnabled)
            if confidence == 1 {
                appState.showToast("Opening the source story", symbol: "wrench.adjustable.fill")
                appState.presentedSheet = .editStory(answer.experienceID)
            } else if confidence == 3 {
                retryCount += 1
                appState.showToast("Try it once more", symbol: "arrow.counterclockwise")
                resetCurrentPrompt()
            } else {
                strongCount += 1
                appState.showToast("Practice saved")
                if currentIndex == answers.count - 1 {
                    withAnimation(reduceMotion ? nil : .snappy) { isComplete = true }
                } else {
                    move(by: 1)
                }
            }
        } catch {
            modelContext.rollback()
            errorMessage = error.localizedDescription
        }
    }

    private var completionState: some View {
        VStack(spacing: RRSpacing.lg) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 54))
                .foregroundStyle(BrandTheme.success)
                .accessibilityHidden(true)
            VStack(spacing: RRSpacing.xs) {
                Text("Practice complete")
                    .font(.rrHero)
                    .multilineTextAlignment(.center)
                Text("You completed \(strongCount) answer\(strongCount == 1 ? "" : "s") with \(retryCount) extra attempt\(retryCount == 1 ? "" : "s"). Keep the ideas, not a memorised script.")
                    .font(.rrBody)
                    .foregroundStyle(BrandTheme.inkMuted)
                    .multilineTextAlignment(.center)
            }

            Button {
                restartDeck()
            } label: {
                Label("Practise this deck again", systemImage: "arrow.counterclockwise")
            }
            .buttonStyle(PrimaryActionButtonStyle())

            if let opportunityID,
               let interviewDate = opportunity?.interviewDate,
               interviewDate <= Date() {
                Button {
                    router.navigate(to: .reflection(opportunityID))
                } label: {
                    Label("Record interview reflection", systemImage: "square.and.pencil")
                }
                .buttonStyle(SecondaryActionButtonStyle())
            } else if let opportunityID {
                Button {
                    router.navigate(to: .opportunity(opportunityID))
                } label: {
                    Label("Back to role preparation", systemImage: "briefcase.fill")
                }
                .buttonStyle(SecondaryActionButtonStyle())
            }

            Button("Done") { dismiss() }
                .font(.rrHeadline)
                .foregroundStyle(BrandTheme.violet)
        }
        .frame(maxWidth: .infinity)
        .cardSurface(tint: BrandTheme.tealSoft.opacity(0.55))
        .accessibilityIdentifier("practice-complete")
    }

    private func resetCurrentPrompt() {
        withAnimation(reduceMotion ? nil : .snappy) {
            isRevealed = false
            showFullStructure = false
            startedAt = Date()
        }
    }

    private func restartDeck() {
        currentIndex = 0
        strongCount = 0
        retryCount = 0
        isComplete = false
        resetCurrentPrompt()
    }

    private func move(by offset: Int) {
        let next = min(max(currentIndex + offset, 0), max(answers.count - 1, 0))
        guard next != currentIndex else { return }
        withAnimation(reduceMotion ? nil : .snappy) {
            currentIndex = next
            isRevealed = false
            showFullStructure = false
            startedAt = Date()
        }
        HapticService.selection(enabled: appState.hapticsEnabled)
    }

    private func duration(from start: Date, to end: Date) -> String {
        let seconds = max(Int(end.timeIntervalSince(start)), 0)
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}

private enum AnyRRButtonStyle: ButtonStyle {
    case primary
    case secondary

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.rrHeadline)
            .foregroundStyle(BrandTheme.ink)
            .padding(.horizontal, RRSpacing.md)
            .padding(.vertical, 13)
            .background(
                (self == .primary ? BrandTheme.amber : BrandTheme.surfaceMuted)
                    .opacity(configuration.isPressed ? 0.72 : 1),
                in: RoundedRectangle(cornerRadius: RRRadius.medium, style: .continuous)
            )
    }
}

private extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
