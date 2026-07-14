import SwiftUI

struct SectionHeading: View {
    let title: String
    var eyebrow: String?
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: RRSpacing.xxs) {
                if let eyebrow {
                    Text(eyebrow.uppercased())
                        .font(.rrCaption)
                        .tracking(0.8)
                        .foregroundStyle(BrandTheme.violet)
                }
                Text(title)
                    .font(.rrTitle)
                    .foregroundStyle(BrandTheme.ink)
            }
            Spacer(minLength: RRSpacing.sm)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(.rrHeadline)
                    .foregroundStyle(BrandTheme.violet)
            }
        }
        .accessibilityAddTraits(.isHeader)
    }
}

struct EvidenceScoreRing: View {
    let score: EvidenceScore
    var size: CGFloat = 56

    private var colour: Color {
        switch score.readiness {
        case .ready: BrandTheme.success
        case .nearlyReady: BrandTheme.amberText
        case .building: BrandTheme.violet
        }
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(colour.opacity(0.16), lineWidth: max(size * 0.10, 5))
            Circle()
                .trim(from: 0, to: CGFloat(score.total) / 100)
                .stroke(colour, style: StrokeStyle(lineWidth: max(size * 0.10, 5), lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(score.total)")
                .font(.system(size: size * 0.28, weight: .bold, design: .rounded))
                .foregroundStyle(BrandTheme.ink)
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Evidence readiness")
        .accessibilityValue("\(score.readiness.title), \(score.total) out of 100")
    }
}

struct ReadinessBadge: View {
    let readiness: EvidenceReadiness

    var body: some View {
        Label(readiness.title, systemImage: symbol)
            .font(.rrCaption)
            .foregroundStyle(colour)
            .padding(.horizontal, RRSpacing.sm)
            .padding(.vertical, 7)
            .background(colour.opacity(0.11), in: Capsule())
    }

    private var colour: Color {
        switch readiness {
        case .ready: BrandTheme.success
        case .nearlyReady: BrandTheme.warning
        case .building: BrandTheme.violet
        }
    }

    private var symbol: String {
        switch readiness {
        case .ready: "checkmark.seal.fill"
        case .nearlyReady: "sparkles"
        case .building: "hammer.fill"
        }
    }
}

struct CapabilityChip: View {
    let capability: Capability
    var selected = false

    var body: some View {
        Label(capability.title, systemImage: capability.symbol)
            .font(.rrCaption)
            .lineLimit(1)
            .foregroundStyle(selected ? Color.white : BrandTheme.ink)
            .padding(.horizontal, RRSpacing.sm)
            .padding(.vertical, RRSpacing.xs)
            .background(selected ? BrandTheme.violet : BrandTheme.surfaceMuted, in: Capsule())
            .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

struct ConfidentialityBadge: View {
    let level: Confidentiality

    var body: some View {
        Label(level.title, systemImage: level.symbol)
            .font(.rrCaption)
            .foregroundStyle(level >= .confidential ? BrandTheme.warning : BrandTheme.inkMuted)
            .accessibilityLabel("Privacy: \(level.title)")
    }
}

struct MatchTierBadge: View {
    let tier: MatchTier

    var body: some View {
        Label(tier.title, systemImage: symbol)
            .font(.rrCaption)
            .foregroundStyle(colour)
            .padding(.horizontal, RRSpacing.sm)
            .padding(.vertical, 7)
            .background(colour.opacity(0.11), in: Capsule())
    }

    private var colour: Color {
        switch tier {
        case .direct: BrandTheme.success
        case .transferable: BrandTheme.tealText
        case .weak: BrandTheme.warning
        case .none: BrandTheme.inkMuted
        }
    }

    private var symbol: String {
        switch tier {
        case .direct: "checkmark.seal.fill"
        case .transferable: "arrow.triangle.branch"
        case .weak: "circle.lefthalf.filled"
        case .none: "circle.dashed"
        }
    }
}

struct EmptyStatePanel: View {
    let title: String
    let message: String
    let symbol: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: RRSpacing.md) {
            Image(systemName: symbol)
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(BrandTheme.violet)
                .frame(width: 66, height: 66)
                .background(BrandTheme.violetSoft, in: RoundedRectangle(cornerRadius: RRRadius.medium, style: .continuous))
            Text(title)
                .font(.rrTitle)
                .multilineTextAlignment(.center)
            Text(message)
                .font(.rrBody)
                .foregroundStyle(BrandTheme.inkMuted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(PrimaryActionButtonStyle())
            }
        }
        .frame(maxWidth: .infinity)
        .padding(RRSpacing.xl)
        .cardSurface()
    }
}

struct InfoBanner: View {
    enum Kind { case information, warning, success }

    let title: String
    let message: String
    var kind: Kind = .information

    var body: some View {
        HStack(alignment: .top, spacing: RRSpacing.sm) {
            Image(systemName: symbol)
                .foregroundStyle(colour)
                .font(.headline)
            VStack(alignment: .leading, spacing: RRSpacing.xxs) {
                Text(title).font(.rrHeadline)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(BrandTheme.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(RRSpacing.md)
        .background(colour.opacity(0.10), in: RoundedRectangle(cornerRadius: RRRadius.medium, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private var colour: Color {
        switch kind {
        case .information: BrandTheme.violet
        case .warning: BrandTheme.warning
        case .success: BrandTheme.success
        }
    }

    private var symbol: String {
        switch kind {
        case .information: "info.circle.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .success: "checkmark.circle.fill"
        }
    }
}

struct PrimaryActionButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.rrHeadline)
            .foregroundStyle(BrandTheme.onAmber)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, RRSpacing.lg)
            .padding(.vertical, 14)
            .background(BrandTheme.amber.opacity(configuration.isPressed ? 0.76 : 1), in: RoundedRectangle(cornerRadius: RRRadius.medium, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: RRRadius.medium, style: .continuous)
                    .stroke(BrandTheme.onAmber.opacity(0.72), lineWidth: 1.5)
            }
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.985 : 1)
            .animation(reduceMotion ? nil : .snappy(duration: 0.18), value: configuration.isPressed)
    }
}

struct SecondaryActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.rrHeadline)
            .foregroundStyle(BrandTheme.ink)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, RRSpacing.lg)
            .padding(.vertical, 14)
            .background(BrandTheme.surfaceMuted.opacity(configuration.isPressed ? 0.7 : 1), in: RoundedRectangle(cornerRadius: RRRadius.medium, style: .continuous))
    }
}

struct ToastView: View {
    let message: ToastMessage

    var body: some View {
        Label(message.title, systemImage: message.symbol)
            .font(.rrHeadline)
            .foregroundStyle(BrandTheme.ink)
            .padding(.horizontal, RRSpacing.md)
            .padding(.vertical, RRSpacing.sm)
            .roleReadyGlass(cornerRadius: RRRadius.medium, tint: BrandTheme.success)
            .shadow(color: .black.opacity(0.12), radius: 18, y: 8)
            .accessibilityAddTraits(.isStaticText)
    }
}
