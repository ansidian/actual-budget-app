import SwiftUI

struct AppTheme {
    static let accent = Color.cyan
    static let accentSoft = Color.cyan.opacity(0.2)
    static let destructive = Color.red
    static let positive = Color.green
    
    struct Fonts {
        static let largeTitle = Font.system(size: 34, weight: .bold, design: .rounded)
        static let title = Font.system(size: 24, weight: .bold, design: .rounded)
        static let subtitle = Font.system(size: 18, weight: .semibold, design: .rounded)
        static let body = Font.system(size: 16, weight: .regular, design: .rounded)
        static let headline = Font.system(size: 16, weight: .semibold, design: .rounded)
        static let subheadline = Font.system(size: 14, weight: .medium, design: .rounded)
        static let footnote = Font.system(size: 12, weight: .regular, design: .rounded)
        static let caption = Font.system(size: 11, weight: .regular, design: .rounded)
    }
}