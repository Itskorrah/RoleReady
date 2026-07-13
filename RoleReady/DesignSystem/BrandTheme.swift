import SwiftUI
import UIKit

enum BrandTheme {
    static let ink = Color(lightHex: 0x142033, darkHex: 0xF4F1E9)
    static let inkMuted = Color(lightHex: 0x566174, darkHex: 0xB7C0CE)
    static let canvas = Color(lightHex: 0xF7F3EA, darkHex: 0x0B111C)
    static let canvasRaised = Color(lightHex: 0xFFFDFC, darkHex: 0x131C2A)
    static let surface = Color(lightHex: 0xFFFFFF, darkHex: 0x172232)
    static let surfaceMuted = Color(lightHex: 0xEEE9DE, darkHex: 0x202C3D)
    static let amber = Color(lightHex: 0xE89A2E, darkHex: 0xFFB94E)
    static let amberText = Color(lightHex: 0x7A4A00, darkHex: 0xFFD083)
    static let amberSoft = Color(lightHex: 0xF8E5BF, darkHex: 0x49351C)
    static let violet = Color(lightHex: 0x6657D9, darkHex: 0x9B90FF)
    static let violetSoft = Color(lightHex: 0xEAE7FF, darkHex: 0x292449)
    static let teal = Color(lightHex: 0x238D7E, darkHex: 0x62D4C1)
    static let tealText = Color(lightHex: 0x00685E, darkHex: 0x7CE3D2)
    static let tealSoft = Color(lightHex: 0xDDF2EC, darkHex: 0x163C37)
    static let success = Color(lightHex: 0x267A50, darkHex: 0x65D493)
    static let warning = Color(lightHex: 0xA96518, darkHex: 0xF7B35B)
    static let danger = Color(lightHex: 0xB54848, darkHex: 0xFF8B8B)
    static let separator = Color(lightHex: 0xDED8CC, darkHex: 0x2F3B4D)

    static let heroGradient = LinearGradient(
        colors: [
            Color(lightHex: 0x4E43B8, darkHex: 0x5C4FC7),
            Color(lightHex: 0x664B82, darkHex: 0x6B518C),
            Color(lightHex: 0x744300, darkHex: 0x704600)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let canvasGradient = LinearGradient(
        colors: [canvas, violetSoft.opacity(0.28), canvas],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

enum RRSpacing {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
}

enum RRRadius {
    static let small: CGFloat = 12
    static let medium: CGFloat = 18
    static let large: CGFloat = 24
    static let hero: CGFloat = 30
}

extension Font {
    static let rrHero = Font.system(.largeTitle, design: .rounded, weight: .bold)
    static let rrTitle = Font.system(.title2, design: .rounded, weight: .bold)
    static let rrHeadline = Font.system(.headline, design: .rounded, weight: .semibold)
    static let rrBody = Font.system(.body, design: .rounded)
    static let rrCaption = Font.system(.caption, design: .rounded, weight: .medium)
}

extension Color {
    init(lightHex: UInt, darkHex: UInt) {
        self.init(uiColor: UIColor { traits in
            let hex = traits.userInterfaceStyle == .dark ? darkHex : lightHex
            return UIColor(
                red: CGFloat((hex >> 16) & 0xFF) / 255,
                green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255,
                alpha: 1
            )
        })
    }
}

struct ScreenBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background {
                BrandTheme.canvasGradient.ignoresSafeArea()
            }
            .foregroundStyle(BrandTheme.ink)
    }
}

struct CardSurface: ViewModifier {
    var padding: CGFloat = RRSpacing.md
    var tint: Color = BrandTheme.surface

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(tint, in: RoundedRectangle(cornerRadius: RRRadius.large, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: RRRadius.large, style: .continuous)
                    .stroke(BrandTheme.separator.opacity(0.7), lineWidth: 0.75)
            }
            .shadow(color: Color.black.opacity(0.055), radius: 14, x: 0, y: 7)
    }
}

extension View {
    func screenBackground() -> some View { modifier(ScreenBackground()) }

    func cardSurface(padding: CGFloat = RRSpacing.md, tint: Color = BrandTheme.surface) -> some View {
        modifier(CardSurface(padding: padding, tint: tint))
    }
}
