import SwiftUI

struct RoleReadyMark: View {
    var size: CGFloat = 44
    var inverse = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .fill(inverse ? Color.white.opacity(0.18) : BrandTheme.violetSoft)
                .rotationEffect(.degrees(-7))
                .offset(x: -size * 0.08, y: size * 0.06)

            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .fill(inverse ? Color.white : BrandTheme.ink)

            EvidencePathShape()
                .stroke(
                    inverse ? BrandTheme.violet : BrandTheme.amber,
                    style: StrokeStyle(lineWidth: size * 0.105, lineCap: .round, lineJoin: .round)
                )
                .padding(size * 0.23)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

private struct EvidencePathShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY * 1.06))
        path.addLine(to: CGPoint(x: rect.midX * 0.87, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        return path
    }
}

struct Wordmark: View {
    var inverse = false

    var body: some View {
        HStack(spacing: RRSpacing.sm) {
            RoleReadyMark(size: 38, inverse: inverse)
            Text("RoleReady")
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(inverse ? .white : BrandTheme.ink)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("RoleReady")
    }
}

