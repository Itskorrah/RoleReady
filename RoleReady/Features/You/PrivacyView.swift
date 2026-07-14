import SwiftUI

struct PrivacyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: RRSpacing.xl) {
                VStack(alignment: .leading, spacing: RRSpacing.md) {
                    RoleReadyMark(size: 72)
                    Text("Your career history belongs to you.")
                        .font(.rrHero)
                    Text("RoleReady is useful without an account, server, analytics SDK, or advertising identifier.")
                        .font(.rrBody)
                        .foregroundStyle(BrandTheme.inkMuted)
                }

                privacySection(
                    title: "What stays on this device",
                    symbol: "iphone.gen3.radiowaves.left.and.right",
                    colour: BrandTheme.violet,
                    points: [
                        "Career profile, stories, job advertisements, matches, answers, and practice history",
                        "Search, evidence scoring, requirement extraction, matching, and answer building",
                        "Your optional app-lock preference and notification schedule"
                    ]
                )

                privacySection(
                    title: "What RoleReady never sends to a server",
                    symbol: "nosign",
                    colour: BrandTheme.success,
                    points: [
                        "No account identity, contact list, advertising ID, or location",
                        "No story text, employer name, job description, answer, or practice activity",
                        "No biometric or passcode data; iOS returns only authentication success or failure"
                    ]
                )

                privacySection(
                    title: "Your controls",
                    symbol: "slider.horizontal.3",
                    colour: BrandTheme.amberText,
                    points: [
                        "Set confidentiality per story and exclude highly sensitive content from automatic matching",
                        "Export a versioned JSON copy with confidential content excluded by default",
                        "Delete all local content and preferences without contacting support"
                    ]
                )

                InfoBanner(
                    title: "About device backups",
                    message: "iOS may include app data in an encrypted device backup according to your system settings. RoleReady does not operate a separate cloud backup.",
                    kind: .information
                )

                Text("This product is a preparation tool, not legal, recruitment, or employment advice.")
                    .font(.footnote)
                    .foregroundStyle(BrandTheme.inkMuted)
            }
            .padding(RRSpacing.lg)
            .padding(.bottom, RRSpacing.xxl)
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("Privacy")
        .navigationBarTitleDisplayMode(.inline)
        .screenBackground()
    }

    private func privacySection(title: String, symbol: String, colour: Color, points: [String]) -> some View {
        VStack(alignment: .leading, spacing: RRSpacing.md) {
            Label(title, systemImage: symbol)
                .font(.rrTitle)
                .foregroundStyle(colour)
            ForEach(points, id: \.self) { point in
                HStack(alignment: .top, spacing: RRSpacing.sm) {
                    Image(systemName: "checkmark")
                        .font(.caption.bold())
                        .foregroundStyle(colour)
                        .padding(.top, 4)
                    Text(point)
                        .font(.rrBody)
                        .foregroundStyle(BrandTheme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
    }
}
