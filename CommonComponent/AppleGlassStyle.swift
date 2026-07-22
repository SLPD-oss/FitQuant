import SwiftUI

//【设计规范：全局玻璃材质样式封装】

/// 苹果 iOS 原生液态玻璃材质 + HIG 8pt 栅格设计常量
enum AppleGlassStyle {

    // MARK: - Material 分层
    static let ultraThin: Material   = .ultraThinMaterial
    static let thin: Material       = .regularMaterial
    static let standard: Material   = .regularMaterial
    static let thick: Material      = .thickMaterial
    static let ultraThick: Material = .ultraThickMaterial

    // MARK: - 间距 (HIG 8pt 倍数)
    static let spacingXS: CGFloat = 8
    static let spacingSM: CGFloat = 16
    static let spacingMD: CGFloat = 24
    static let spacingLG: CGFloat = 32

    // MARK: - 圆角
    static let cornerRadiusSmall: CGFloat  = 8
    static let cornerRadiusMedium: CGFloat = 12
    static let cornerRadiusLarge: CGFloat  = 16

    // MARK: - 低饱和原生配色
    static let accent           = Color(.systemBlue)
    static let textPrimary      = Color(.label)
    static let textSecondary    = Color(.secondaryLabel)
    static let textTertiary     = Color(.tertiaryLabel)
    static let background       = Color(.systemBackground)
    static let groupedBackground = Color(.systemGroupedBackground)
}
