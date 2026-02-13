// MARK: - CloudTunnel Design System
// A comprehensive design system inspired by ServeBay / Linear / Raycast

import SwiftUI

// MARK: - Color Palette
struct CTColors {
    // Brand (dynamic - reads from user's accent color preference)
    static var brand: Color {
        let index = UserDefaults.standard.integer(forKey: "accentColorIndex")
        let palette: [Color] = [
            Color(hex: "4285FC"), // Blue
            Color(hex: "7B61FF"), // Purple
            Color(hex: "FF6B9D"), // Pink
            Color(hex: "FF3B30"), // Red
            Color(hex: "FF9F0A"), // Orange
            Color(hex: "34C759"), // Green
            Color(hex: "5AC8FA"), // Teal
            Color(hex: "5856D6"), // Indigo
        ]
        return index < palette.count ? palette[index] : palette[0]
    }
    static var brandLight: Color { brand.opacity(0.7) }
    static var brandDark: Color { brand.opacity(1.0) }
    
    // Semantic
    static let success = Color(hex: "34C759")
    static let warning = Color(hex: "FF9F0A")
    static let danger = Color(hex: "FF3B30")
    static let info = Color(hex: "5AC8FA")
    
    // Gradients
    static var brandGradient: LinearGradient {
        LinearGradient(
            colors: [brand, brand.opacity(0.7)],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    }
    static let successGradient = LinearGradient(
        colors: [Color(hex: "34C759"), Color(hex: "30D158")],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
    static let dangerGradient = LinearGradient(
        colors: [Color(hex: "FF3B30"), Color(hex: "FF6961")],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
    static let warmGradient = LinearGradient(
        colors: [Color(hex: "FF9F0A"), Color(hex: "FF6B6B")],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
    static let coolGradient = LinearGradient(
        colors: [Color(hex: "5AC8FA"), Color(hex: "7B61FF")],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
    static let darkGradient = LinearGradient(
        colors: [Color(hex: "1C1C2E"), Color(hex: "2D2D44")],
        startPoint: .top, endPoint: .bottom
    )
    
    // Surface Colors (adaptive - using system colors as fallback)
    struct Surface {
        static let primary = Color(nsColor: .windowBackgroundColor)
        static let secondary = Color(nsColor: .controlBackgroundColor)
        static let elevated = Color(nsColor: .underPageBackgroundColor)
    }
    
    // Sidebar
    static let sidebarBg = Color(nsColor: .controlBackgroundColor)
    static let sidebarSelected = Color.accentColor.opacity(0.15)
    static let sidebarHover = Color.primary.opacity(0.06)
    
    // Text
    static let textPrimary = Color.primary
    static let textSecondary = Color.secondary
    static let textTertiary = Color.primary.opacity(0.4)
}

// MARK: - Color Hex Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = ((int >> 24) & 0xFF, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Typography
struct CTTypography {
    static let largeTitle = Font.system(size: 28, weight: .bold, design: .rounded)
    static let title = Font.system(size: 22, weight: .bold, design: .rounded)
    static let title2 = Font.system(size: 18, weight: .semibold, design: .rounded)
    static let title3 = Font.system(size: 16, weight: .semibold, design: .rounded)
    static let headline = Font.system(size: 14, weight: .semibold)
    static let body = Font.system(size: 13, weight: .regular)
    static let callout = Font.system(size: 12, weight: .regular)
    static let caption = Font.system(size: 11, weight: .regular)
    static let captionBold = Font.system(size: 11, weight: .semibold)
    static let mono = Font.system(size: 12, weight: .regular, design: .monospaced)
    static let monoSmall = Font.system(size: 11, weight: .regular, design: .monospaced)
}

// MARK: - Spacing
struct CTSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 20
    static let xxl: CGFloat = 24
    static let xxxl: CGFloat = 32
}

// MARK: - Corner Radius
struct CTRadius {
    static let sm: CGFloat = 6
    static let md: CGFloat = 10
    static let lg: CGFloat = 14
    static let xl: CGFloat = 18
    static let full: CGFloat = 100
}

// MARK: - Shadows
struct CTShadow {
    static func small(_ scheme: ColorScheme) -> some View {
        Color.clear.shadow(
            color: scheme == .dark ? .black.opacity(0.3) : .black.opacity(0.08),
            radius: 4, x: 0, y: 2
        )
    }
    
    static func medium(_ scheme: ColorScheme) -> some View {
        Color.clear.shadow(
            color: scheme == .dark ? .black.opacity(0.4) : .black.opacity(0.12),
            radius: 8, x: 0, y: 4
        )
    }
}

// MARK: - Card Style Modifier
struct CTCardModifier: ViewModifier {
    @Environment(\.colorScheme) var colorScheme
    var padding: CGFloat = CTSpacing.lg
    
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background {
                RoundedRectangle(cornerRadius: CTRadius.lg, style: .continuous)
                    .fill(colorScheme == .dark
                          ? Color(nsColor: .controlBackgroundColor)
                          : .white)
                    .shadow(
                        color: colorScheme == .dark ? .black.opacity(0.3) : .black.opacity(0.06),
                        radius: 8, x: 0, y: 2
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: CTRadius.lg, style: .continuous)
                            .stroke(colorScheme == .dark
                                    ? Color.white.opacity(0.06)
                                    : Color.black.opacity(0.04), lineWidth: 1)
                    )
            }
    }
}

// MARK: - Glass Card Modifier
struct CTGlassModifier: ViewModifier {
    @Environment(\.colorScheme) var colorScheme
    
    func body(content: Content) -> some View {
        content
            .padding(CTSpacing.lg)
            .background {
                RoundedRectangle(cornerRadius: CTRadius.lg, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: CTRadius.lg, style: .continuous)
                            .stroke(Color.white.opacity(colorScheme == .dark ? 0.1 : 0.3), lineWidth: 1)
                    )
            }
    }
}

// MARK: - Stat Card Modifier
struct CTStatCardModifier: ViewModifier {
    let gradient: LinearGradient
    @Environment(\.colorScheme) var colorScheme
    
    func body(content: Content) -> some View {
        content
            .padding(CTSpacing.lg)
            .background {
                RoundedRectangle(cornerRadius: CTRadius.lg, style: .continuous)
                    .fill(gradient)
                    .opacity(colorScheme == .dark ? 0.8 : 1.0)
                    .overlay(
                        RoundedRectangle(cornerRadius: CTRadius.lg, style: .continuous)
                            .fill(.ultraThinMaterial.opacity(0.3))
                    )
            }
            .foregroundStyle(.white)
    }
}

// MARK: - View Extensions
extension View {
    func ctCard(padding: CGFloat = CTSpacing.lg) -> some View {
        modifier(CTCardModifier(padding: padding))
    }
    
    func ctGlass() -> some View {
        modifier(CTGlassModifier())
    }
    
    func ctStatCard(_ gradient: LinearGradient) -> some View {
        modifier(CTStatCardModifier(gradient: gradient))
    }
    
    func ctSection() -> some View {
        self.padding(.horizontal, CTSpacing.xxl)
    }
}

// MARK: - Status Badge
struct CTStatusBadge: View {
    let status: TunnelStatus
    
    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
                .overlay(
                    Circle()
                        .fill(statusColor.opacity(0.4))
                        .frame(width: 14, height: 14)
                        .opacity(status == .running ? 1 : 0)
                        .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: status)
                )
            
            Text(status.displayName)
                .font(CTTypography.captionBold)
                .foregroundStyle(statusColor)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(statusColor.opacity(0.12))
        .clipShape(Capsule())
    }
    
    var statusColor: Color {
        switch status {
        case .running: CTColors.success
        case .stopped: CTColors.textTertiary
        case .starting: CTColors.warning
        case .stopping: CTColors.warning
        case .error: CTColors.danger
        }
    }
}

// MARK: - Action Button
struct CTButton: View {
    let title: String
    let icon: String?
    let style: ButtonStyle
    let action: () -> Void
    
    @State private var isHovered = false
    
    enum ButtonStyle {
        case primary, secondary, danger, success, ghost
    }
    
    init(_ title: String, icon: String? = nil, style: ButtonStyle = .primary, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.style = style
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .semibold))
                }
                Text(title)
                    .font(CTTypography.headline)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(background)
            .foregroundStyle(foregroundColor)
            .clipShape(RoundedRectangle(cornerRadius: CTRadius.sm, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: CTRadius.sm, style: .continuous)
                    .stroke(borderColor, lineWidth: style == .ghost ? 1 : 0)
            )
            .scaleEffect(isHovered ? 1.02 : 1.0)
            .animation(.easeOut(duration: 0.15), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
    
    @ViewBuilder
    var background: some View {
        switch style {
        case .primary: CTColors.brand.opacity(isHovered ? 0.9 : 1)
        case .secondary: Color.primary.opacity(isHovered ? 0.12 : 0.08)
        case .danger: CTColors.danger.opacity(isHovered ? 0.9 : 1)
        case .success: CTColors.success.opacity(isHovered ? 0.9 : 1)
        case .ghost: Color.clear
        }
    }
    
    var foregroundColor: Color {
        switch style {
        case .primary, .danger, .success: .white
        case .secondary, .ghost: .primary
        }
    }
    
    var borderColor: Color {
        switch style {
        case .ghost: Color.primary.opacity(0.15)
        default: .clear
        }
    }
}

// MARK: - Icon Badge
struct CTIconBadge: View {
    let icon: String
    let color: Color
    var size: CGFloat = 36
    
    var body: some View {
        Image(systemName: icon)
            .font(.system(size: size * 0.42, weight: .semibold))
            .foregroundStyle(color)
            .frame(width: size, height: size)
            .background(color.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: size * 0.28, style: .continuous))
    }
}

// MARK: - Empty State
struct CTEmptyState: View {
    let icon: String
    let title: String
    let message: String
    var action: (() -> Void)? = nil
    var actionTitle: String? = nil
    
    var body: some View {
        VStack(spacing: CTSpacing.lg) {
            Image(systemName: icon)
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(CTColors.textTertiary)
            
            Text(title)
                .font(CTTypography.title2)
                .foregroundStyle(CTColors.textPrimary)
            
            Text(message)
                .font(CTTypography.body)
                .foregroundStyle(CTColors.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
            
            if let action, let actionTitle {
                CTButton(actionTitle, icon: "plus", action: action)
                    .padding(.top, CTSpacing.sm)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Section Header
struct CTSectionHeader: View {
    let title: String
    var subtitle: String? = nil
    var trailing: (() -> AnyView)? = nil
    
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(CTTypography.title2)
                    .foregroundStyle(CTColors.textPrimary)
                
                if let subtitle {
                    Text(subtitle)
                        .font(CTTypography.callout)
                        .foregroundStyle(CTColors.textSecondary)
                }
            }
            
            Spacer()
            
            if let trailing {
                trailing()
            }
        }
    }
}

// MARK: - Info Row
struct CTInfoRow: View {
    let label: String
    let value: String
    var isMono: Bool = false
    var copyable: Bool = false
    
    var body: some View {
        HStack {
            Text(label)
                .font(CTTypography.callout)
                .foregroundStyle(CTColors.textSecondary)
            
            Spacer()
            
            HStack(spacing: 6) {
                Text(value)
                    .font(isMono ? CTTypography.mono : CTTypography.callout)
                    .foregroundStyle(CTColors.textPrimary)
                    .textSelection(.enabled)
                
                if copyable {
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(value, forType: .string)
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 10))
                            .foregroundStyle(CTColors.textTertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Animated Pulse
struct PulseAnimation: ViewModifier {
    @State private var isPulsing = false
    let color: Color
    
    func body(content: Content) -> some View {
        content
            .overlay(
                Circle()
                    .fill(color)
                    .scaleEffect(isPulsing ? 2.5 : 1)
                    .opacity(isPulsing ? 0 : 0.6)
            )
            .onAppear {
                withAnimation(.easeOut(duration: 1.5).repeatForever(autoreverses: false)) {
                    isPulsing = true
                }
            }
    }
}

// MARK: - Shimmer Effect
struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    colors: [.clear, .white.opacity(0.15), .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .offset(x: phase)
                .mask(content)
            )
            .onAppear {
                withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                    phase = 400
                }
            }
    }
}

extension View {
    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }
}

// MARK: - Loading Indicator
struct CTLoadingView: View {
    let message: String
    @State private var rotation: Double = 0
    
    var body: some View {
        VStack(spacing: CTSpacing.lg) {
            Circle()
                .trim(from: 0, to: 0.7)
                .stroke(
                    CTColors.brandGradient,
                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                )
                .frame(width: 32, height: 32)
                .rotationEffect(.degrees(rotation))
                .onAppear {
                    withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                        rotation = 360
                    }
                }
            
            Text(message)
                .font(CTTypography.callout)
                .foregroundStyle(CTColors.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Tag
struct CTTag: View {
    let text: String
    var color: Color = CTColors.brand
    
    var body: some View {
        Text(text)
            .font(CTTypography.captionBold)
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }
}

// MARK: - Search Bar
struct CTSearchBar: View {
    @Binding var text: String
    var placeholder: String = "Search..."
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13))
                .foregroundStyle(CTColors.textTertiary)
            
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(CTTypography.body)
            
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(CTColors.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background {
            RoundedRectangle(cornerRadius: CTRadius.sm, style: .continuous)
                .fill(Color.primary.opacity(0.05))
        }
    }
}
