import SwiftData
import SwiftUI

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState

    @State private var isWorking = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: RRSpacing.xl) {
                header
                promiseCard
                actions
            }
            .frame(maxWidth: 680)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, RRSpacing.lg)
            .padding(.vertical, RRSpacing.xl)
        }
        .scrollIndicators(.hidden)
        .screenBackground()
        .accessibilityIdentifier("onboarding-promise")
        .alert("Couldn’t create your workspace", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "Try again.")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: RRSpacing.lg) {
            ViewThatFits(in: .horizontal) {
                HStack {
                    Wordmark()
                    Spacer()
                    localBadge
                }
                VStack(alignment: .leading, spacing: RRSpacing.sm) {
                    Wordmark()
                    localBadge
                }
            }

            VStack(alignment: .leading, spacing: RRSpacing.sm) {
                Text("REAL EXPERIENCE. ROLE-READY ANSWERS.")
                    .font(.rrCaption)
                    .tracking(1.05)
                    .foregroundStyle(BrandTheme.violet)
                Text("Prepare one answer you can trust.")
                    .font(.rrHero)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Add your career history and a job advertisement. RoleReady finds the strongest real example, helps you fill the important gaps, and turns it into an answer you approve.")
                    .font(.rrBody)
                    .foregroundStyle(BrandTheme.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var localBadge: some View {
        Label("Local by default", systemImage: "lock.fill")
            .font(.rrCaption)
            .foregroundStyle(BrandTheme.violet)
            .padding(.horizontal, RRSpacing.sm)
            .padding(.vertical, RRSpacing.xs)
            .background(BrandTheme.violetSoft, in: Capsule())
    }

    private var promiseCard: some View {
        VStack(alignment: .leading, spacing: RRSpacing.lg) {
            trustRow(
                title: "Improve expression, never invent experience",
                detail: "Every factual claim must come from something you supplied.",
                symbol: "checkmark.seal.fill"
            )
            trustRow(
                title: "You stay in control",
                detail: "Review where claims came from and approve them before they are ready to practise.",
                symbol: "person.badge.shield.checkmark.fill"
            )
            trustRow(
                title: "Private preparation",
                detail: "Career information stays on this device by default. RoleReady prepares you before interviews; it is not covert live assistance.",
                symbol: "hand.raised.fill"
            )
        }
        .cardSurface(tint: BrandTheme.violetSoft.opacity(0.42))
        .accessibilityIdentifier("onboarding-trust")
    }

    private var actions: some View {
        VStack(spacing: RRSpacing.sm) {
            Button {
                startWorkspace(sample: false, destination: .prepareForRole)
            } label: {
                Label(isWorking ? "Preparing…" : "Prepare for a role", systemImage: "target")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryActionButtonStyle())
            .disabled(isWorking)
            .accessibilityHint("Starts with your career history and a job advertisement")
            .accessibilityIdentifier("start-blank-workspace")

            Button {
                startWorkspace(sample: true, destination: nil)
            } label: {
                Label("Explore a sample first", systemImage: "sparkles")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(SecondaryActionButtonStyle())
            .disabled(isWorking)
            .accessibilityIdentifier("start-sample-workspace")

            Button("Build my example library manually") {
                startWorkspace(sample: false, destination: .addStory)
            }
            .font(.rrHeadline)
            .foregroundStyle(BrandTheme.violet)
            .padding(.vertical, RRSpacing.xs)
            .disabled(isWorking)
            .accessibilityHint("Skips role preparation and opens the guided example editor")
            .accessibilityIdentifier("start-example-library")
        }
    }

    private func trustRow(title: String, detail: String, symbol: String) -> some View {
        HStack(alignment: .top, spacing: RRSpacing.md) {
            Image(systemName: symbol)
                .font(.headline)
                .foregroundStyle(BrandTheme.violet)
                .frame(width: 40, height: 40)
                .background(BrandTheme.surface, in: RoundedRectangle(cornerRadius: RRRadius.small))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: RRSpacing.xxs) {
                Text(title)
                    .font(.rrHeadline)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(BrandTheme.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func startWorkspace(sample: Bool, destination: SheetDestination?) {
        guard !isWorking else { return }
        isWorking = true
        do {
            if sample {
                try SeedService().installSampleWorkspace(in: modelContext)
            } else {
                try SeedService().createBlankWorkspace(in: modelContext)
            }
            appState.completeOnboarding(usingSample: sample, destination: destination)
            HapticService.success(enabled: appState.hapticsEnabled)
        } catch {
            modelContext.rollback()
            errorMessage = error.localizedDescription
        }
        isWorking = false
    }
}
