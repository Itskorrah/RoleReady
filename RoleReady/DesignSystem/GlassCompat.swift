import SwiftUI

extension View {
    @ViewBuilder
    func roleReadyGlass(
        cornerRadius: CGFloat = RRRadius.large,
        tint: Color = BrandTheme.violet,
        interactive: Bool = false
    ) -> some View {
        if #available(iOS 26.0, *) {
            if interactive {
                self.glassEffect(
                    .regular.tint(tint.opacity(0.16)).interactive(),
                    in: .rect(cornerRadius: cornerRadius)
                )
            } else {
                self.glassEffect(
                    .regular.tint(tint.opacity(0.10)),
                    in: .rect(cornerRadius: cornerRadius)
                )
            }
        } else {
            self
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(tint.opacity(0.18), lineWidth: 0.75)
                }
        }
    }
}

struct GlassActionCluster<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: RRSpacing.sm) {
                content()
            }
        } else {
            content()
        }
    }
}

