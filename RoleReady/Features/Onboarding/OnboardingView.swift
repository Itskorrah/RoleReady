import SwiftData
import SwiftUI

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var page = 0
    @State private var isWorking = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            BrandTheme.canvasGradient.ignoresSafeArea()
            TabView(selection: $page) {
                promisePage.tag(0)
                evidencePage.tag(1)
                privacyPage.tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .animation(reduceMotion ? nil : .smooth(duration: 0.35), value: page)
        }
        .alert("Couldn’t create your workspace", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "Try again.")
        }
    }

    private var promisePage: some View {
        onboardingPage(
            eyebrow: "REAL EXPERIENCE. READY TO USE.",
            title: "Walk into the interview with proof—not a script.",
            body: "RoleReady turns work you’ve actually done into clear, credible answers you can say naturally.",
            illustration: heroIllustration,
            primaryTitle: "See how it works",
            primaryAction: { page = 1 }
        )
        .accessibilityIdentifier("onboarding-promise")
    }

    private var evidencePage: some View {
        onboardingPage(
            eyebrow: "ONE STORY, MANY USES",
            title: "Capture the facts once. Reuse them with confidence.",
            body: "Guided prompts strengthen ownership, decisions, outcomes, and proof. Every generated claim links back to your source story.",
            illustration: evidenceIllustration,
            primaryTitle: "Privacy first",
            primaryAction: { page = 2 },
            secondaryTitle: "Back",
            secondaryAction: { page = 0 }
        )
        .accessibilityIdentifier("onboarding-evidence")
    }

    private var privacyPage: some View {
        ScrollView {
            VStack(spacing: 0) {
                Spacer(minLength: RRSpacing.lg)
                VStack(spacing: RRSpacing.lg) {
                    RoleReadyMark(size: 82)
                    VStack(spacing: RRSpacing.sm) {
                        Text("Private by design")
                            .font(.rrHero)
                            .multilineTextAlignment(.center)
                        Text("Matching and answer building happen on this device. There’s no account, tracker, API key, or subscription between you and your evidence.")
                            .font(.rrBody)
                            .foregroundStyle(BrandTheme.inkMuted)
                            .multilineTextAlignment(.center)
                    }
                    VStack(alignment: .leading, spacing: RRSpacing.md) {
                        privacyRow("Works offline", symbol: "wifi.slash")
                        privacyRow("You control which stories are eligible for matching", symbol: "hand.raised.fill")
                        privacyRow("Export or delete everything whenever you choose", symbol: "arrow.down.doc.fill")
                    }
                    .cardSurface()
                }
                .frame(maxWidth: 620)
                Spacer(minLength: RRSpacing.lg)
                VStack(spacing: RRSpacing.sm) {
                    Button {
                        startWorkspace(sample: true)
                    } label: {
                        Label(isWorking ? "Preparing sample…" : "Explore the sample workspace", systemImage: "sparkles")
                    }
                    .buttonStyle(PrimaryActionButtonStyle())
                    .disabled(isWorking)
                    .accessibilityIdentifier("start-sample-workspace")

                    Button("Start with my own story") {
                        startWorkspace(sample: false)
                    }
                    .buttonStyle(SecondaryActionButtonStyle())
                    .disabled(isWorking)
                    .accessibilityIdentifier("start-blank-workspace")

                    Button("Back") { page = 1 }
                        .font(.rrHeadline)
                        .foregroundStyle(BrandTheme.inkMuted)
                        .padding(.top, RRSpacing.xs)
                }
                .frame(maxWidth: 620)
            }
            .padding(RRSpacing.lg)
        }
        .scrollIndicators(.hidden)
        .accessibilityIdentifier("onboarding-privacy")
    }

    private func onboardingPage<Illustration: View>(
        eyebrow: String,
        title: String,
        body: String,
        illustration: Illustration,
        primaryTitle: String,
        primaryAction: @escaping () -> Void,
        secondaryTitle: String? = nil,
        secondaryAction: (() -> Void)? = nil
    ) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                Spacer(minLength: RRSpacing.lg)
                illustration
                    .frame(maxHeight: 330)
                Spacer(minLength: RRSpacing.lg)
                VStack(spacing: RRSpacing.md) {
                    Text(eyebrow)
                        .font(.rrCaption)
                        .tracking(1.1)
                        .foregroundStyle(BrandTheme.violet)
                    Text(title)
                        .font(.rrHero)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(body)
                        .font(.rrBody)
                        .foregroundStyle(BrandTheme.inkMuted)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: 620)
                Spacer(minLength: RRSpacing.xl)
                VStack(spacing: RRSpacing.sm) {
                    Button(primaryTitle, action: primaryAction)
                        .buttonStyle(PrimaryActionButtonStyle())
                    if let secondaryTitle, let secondaryAction {
                        Button(secondaryTitle, action: secondaryAction)
                            .font(.rrHeadline)
                            .foregroundStyle(BrandTheme.inkMuted)
                    }
                }
                .frame(maxWidth: 620)
            }
            .padding(RRSpacing.lg)
        }
        .scrollIndicators(.hidden)
    }

    private var heroIllustration: some View {
        ZStack {
            RoundedRectangle(cornerRadius: RRRadius.hero, style: .continuous)
                .fill(BrandTheme.heroGradient)
                .rotationEffect(.degrees(-3))
                .padding(.horizontal, 18)
            VStack(alignment: .leading, spacing: RRSpacing.md) {
                Wordmark(inverse: true)
                Spacer()
                Text("Tell us about a difficult process you improved.")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)
                HStack(spacing: RRSpacing.xs) {
                    cue("Legacy SAS")
                    cue("133 tests")
                    cue("Outputs matched")
                }
            }
            .padding(RRSpacing.xl)
        }
        .frame(maxWidth: 560)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("An interview question supported by concise evidence cues")
    }

    private var evidenceIllustration: some View {
        ZStack {
            RoundedRectangle(cornerRadius: RRRadius.hero, style: .continuous)
                .fill(BrandTheme.violetSoft)
            VStack(spacing: RRSpacing.md) {
                evidenceStep("Capture", "What actually happened", "square.and.pencil", active: true)
                evidenceStep("Strengthen", "Ownership, decisions, result", "wand.and.stars", active: true)
                evidenceStep("Match", "Why this story fits", "point.3.filled.connected.trianglepath.dotted", active: false)
                evidenceStep("Practise", "Cues you can say naturally", "quote.bubble.fill", active: false)
            }
            .padding(RRSpacing.lg)
        }
        .frame(maxWidth: 560)
        .accessibilityElement(children: .combine)
    }

    private func cue(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, RRSpacing.sm)
            .padding(.vertical, RRSpacing.xs)
            .background(.white.opacity(0.16), in: Capsule())
    }

    private func evidenceStep(_ title: String, _ detail: String, _ symbol: String, active: Bool) -> some View {
        HStack(spacing: RRSpacing.md) {
            Image(systemName: symbol)
                .font(.headline)
                .foregroundStyle(active ? .white : BrandTheme.violet)
                .frame(width: 42, height: 42)
                .background(active ? BrandTheme.violet : BrandTheme.surface, in: RoundedRectangle(cornerRadius: RRRadius.small))
            VStack(alignment: .leading, spacing: RRSpacing.xxs) {
                Text(title).font(.rrHeadline)
                Text(detail).font(.subheadline).foregroundStyle(BrandTheme.inkMuted)
            }
            Spacer()
            Image(systemName: active ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(active ? BrandTheme.success : BrandTheme.separator)
        }
        .padding(RRSpacing.sm)
        .background(BrandTheme.surface, in: RoundedRectangle(cornerRadius: RRRadius.medium))
    }

    private func privacyRow(_ text: String, symbol: String) -> some View {
        Label {
            Text(text).font(.rrBody)
        } icon: {
            Image(systemName: symbol).foregroundStyle(BrandTheme.violet)
        }
    }

    private func startWorkspace(sample: Bool) {
        isWorking = true
        do {
            if sample {
                try SeedService().installSampleWorkspace(in: modelContext)
            } else {
                try SeedService().createBlankWorkspace(in: modelContext)
            }
            appState.completeOnboarding(usingSample: sample)
            HapticService.success(enabled: appState.hapticsEnabled)
        } catch {
            modelContext.rollback()
            errorMessage = error.localizedDescription
        }
        isWorking = false
    }
}
