// MARK: - Keyboard Shortcuts View
// Displays and allows customization of keyboard shortcuts

import SwiftUI

struct KeyboardShortcutsView: View {
    @StateObject private var manager = KeyboardShortcutManager.shared
    @State private var selectedCategory: KeyboardShortcutManager.ShortcutAction.Category?
    
    var filteredShortcuts: [KeyboardShortcutManager.ShortcutAction] {
        if let category = selectedCategory {
            return manager.shortcuts.filter { $0.category == category }
        }
        return manager.shortcuts
    }
    
    var body: some View {
        VStack(spacing: CTSpacing.lg) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: CTSpacing.xs) {
                    Text("Klavye Kısayolları")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(CTColors.textPrimary)
                    
                    Text("Uygulama içi kısayollarla hızlı erişim")
                        .font(CTTypography.body)
                        .foregroundStyle(CTColors.textSecondary)
                }
                
                Spacer()
                
                Button {
                    manager.resetToDefaults()
                } label: {
                    Label("Varsayılana Dön", systemImage: "arrow.counterclockwise")
                        .font(.system(size: 12))
                }
                .buttonStyle(.bordered)
            }
            
            // Category filter
            HStack(spacing: CTSpacing.sm) {
                categoryChip(nil, title: "Tümü")
                ForEach(KeyboardShortcutManager.ShortcutAction.Category.allCases, id: \.self) { cat in
                    categoryChip(cat, title: cat.rawValue)
                }
                Spacer()
            }
            
            // Shortcuts list
            VStack(spacing: CTSpacing.xs) {
                ForEach(filteredShortcuts) { shortcut in
                    shortcutRow(shortcut)
                }
            }
            
            Spacer()
        }
        .padding(CTSpacing.lg)
    }
    
    // MARK: - Category Chip
    func categoryChip(_ category: KeyboardShortcutManager.ShortcutAction.Category?, title: String) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedCategory = category
            }
        } label: {
            Text(title)
                .font(.system(size: 12, weight: selectedCategory == category ? .semibold : .regular))
                .foregroundStyle(selectedCategory == category ? .white : CTColors.textSecondary)
                .padding(.horizontal, CTSpacing.md)
                .padding(.vertical, CTSpacing.xs)
                .background(
                    Capsule()
                        .fill(selectedCategory == category ? CTColors.brand : CTColors.Surface.secondary)
                )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Shortcut Row
    func shortcutRow(_ shortcut: KeyboardShortcutManager.ShortcutAction) -> some View {
        HStack(spacing: CTSpacing.md) {
            Image(systemName: shortcut.icon)
                .font(.system(size: 14))
                .foregroundStyle(CTColors.brand)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(shortcut.name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(CTColors.textPrimary)
                
                Text(shortcut.category.rawValue)
                    .font(CTTypography.caption)
                    .foregroundStyle(CTColors.textTertiary)
            }
            
            Spacer()
            
            // Shortcut display
            HStack(spacing: 3) {
                ForEach(shortcut.modifiers, id: \.self) { mod in
                    keyCapView(mod.rawValue)
                }
                keyCapView(shortcut.key.uppercased())
            }
        }
        .padding(.horizontal, CTSpacing.md)
        .padding(.vertical, CTSpacing.sm)
        .background(CTColors.Surface.secondary)
        .clipShape(RoundedRectangle(cornerRadius: CTRadius.sm))
    }
    
    // MARK: - Key Cap
    func keyCapView(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundStyle(CTColors.textPrimary)
            .frame(minWidth: 24, minHeight: 24)
            .padding(.horizontal, 4)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color(nsColor: .windowBackgroundColor))
                    .shadow(color: .black.opacity(0.15), radius: 0.5, y: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(Color.primary.opacity(0.15), lineWidth: 0.5)
            )
    }
}

#Preview {
    KeyboardShortcutsView()
        .frame(width: 600, height: 500)
}
