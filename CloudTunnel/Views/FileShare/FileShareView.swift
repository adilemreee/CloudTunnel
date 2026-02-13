// MARK: - File Share View
// Share folders via HTTP server + Cloudflare quick tunnel

import SwiftUI

struct FileShareView: View {
    @EnvironmentObject var fileShareService: FileShareService
    @EnvironmentObject var tunnelService: TunnelService
    
    @State private var dragOver = false
    @State private var isCopied = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CTSpacing.xxl) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text(NSLocalizedString("fileShare.title", comment: ""))
                        .font(CTTypography.largeTitle)
                        .foregroundStyle(CTColors.textPrimary)
                    
                    Text(NSLocalizedString("fileShare.subtitle", comment: ""))
                        .font(CTTypography.body)
                        .foregroundStyle(CTColors.textSecondary)
                }
                
                if fileShareService.isSharing {
                    activeShareCard
                } else {
                    selectFolderCard
                }
                
                // How it works
                howItWorks
            }
            .padding(CTSpacing.xxl)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
    
    // MARK: - Active Share Card
    var activeShareCard: some View {
        VStack(spacing: CTSpacing.xl) {
            // Status
            HStack(spacing: CTSpacing.lg) {
                ZStack {
                    Circle()
                        .fill(CTColors.success.opacity(0.12))
                        .frame(width: 56, height: 56)
                    
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(CTColors.success)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(NSLocalizedString("fileShare.active", comment: ""))
                        .font(CTTypography.title2)
                        .foregroundStyle(CTColors.success)
                    
                    if let folder = fileShareService.selectedFolder {
                        Text(folder)
                            .font(CTTypography.mono)
                            .foregroundStyle(CTColors.textSecondary)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                CTButton(NSLocalizedString("fileShare.stop", comment: ""), icon: "stop.fill", style: .danger) {
                    fileShareService.stopSharing()
                }
            }
            
            Divider()
            
            // URLs
            VStack(spacing: CTSpacing.md) {
                if let localURL = fileShareService.localURL {
                    urlRow(label: NSLocalizedString("fileShare.localURL", comment: ""), url: localURL, color: CTColors.textSecondary)
                }
                
                if let publicURL = fileShareService.publicURL {
                    urlRow(label: NSLocalizedString("fileShare.publicURL", comment: ""), url: publicURL, color: CTColors.brand)
                } else {
                    HStack(spacing: CTSpacing.sm) {
                        ProgressView()
                            .controlSize(.small)
                        Text(NSLocalizedString("fileShare.waitingURL", comment: ""))
                            .font(CTTypography.callout)
                            .foregroundStyle(CTColors.textSecondary)
                    }
                }
            }
        }
        .ctCard()
    }
    
    func urlRow(label: String, url: String, color: Color) -> some View {
        HStack {
            Text(label)
                .font(CTTypography.captionBold)
                .foregroundStyle(CTColors.textSecondary)
                .frame(width: 80, alignment: .leading)
            
            Text(url)
                .font(CTTypography.mono)
                .foregroundStyle(color)
                .textSelection(.enabled)
            
            Spacer()
            
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(url, forType: .string)
                isCopied = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { isCopied = false }
            } label: {
                Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 12))
                    .foregroundStyle(isCopied ? CTColors.success : CTColors.textTertiary)
                    .frame(width: 28, height: 28)
                    .background(Color.primary.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
        }
    }
    
    // MARK: - Select Folder Card
    var selectFolderCard: some View {
        VStack(spacing: CTSpacing.xl) {
            // Drop zone
            VStack(spacing: CTSpacing.lg) {
                Image(systemName: "folder.badge.plus")
                    .font(.system(size: 48, weight: .light))
                    .foregroundStyle(dragOver ? CTColors.brand : CTColors.textTertiary)
                
                VStack(spacing: 4) {
                    Text(NSLocalizedString("fileShare.dropzone.title", comment: ""))
                        .font(CTTypography.title3)
                        .foregroundStyle(CTColors.textPrimary)
                    
                    Text(NSLocalizedString("fileShare.dropzone.subtitle", comment: ""))
                        .font(CTTypography.callout)
                        .foregroundStyle(CTColors.textSecondary)
                }
                
                CTButton(NSLocalizedString("fileShare.selectFolder", comment: ""), icon: "folder", style: .primary) {
                    selectFolder()
                }
            }
            .frame(maxWidth: .infinity)
            .padding(CTSpacing.xxxl)
            .background(
                RoundedRectangle(cornerRadius: CTRadius.lg, style: .continuous)
                    .strokeBorder(
                        style: StrokeStyle(lineWidth: 2, dash: [8, 4])
                    )
                    .foregroundStyle(dragOver ? CTColors.brand.opacity(0.5) : Color.primary.opacity(0.1))
            )
            .background(
                RoundedRectangle(cornerRadius: CTRadius.lg, style: .continuous)
                    .fill(dragOver ? CTColors.brand.opacity(0.03) : .clear)
            )
            .onDrop(of: [.fileURL], isTargeted: $dragOver) { providers in
                guard let provider = providers.first else { return false }
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    if let url {
                        var isDir: ObjCBool = false
                        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
                            Task { @MainActor in
                                await fileShareService.startSharing(folderPath: url.path)
                            }
                        }
                    }
                }
                return true
            }
        }
        .ctCard()
    }
    
    // MARK: - How It Works
    var howItWorks: some View {
        VStack(alignment: .leading, spacing: CTSpacing.md) {
            CTSectionHeader(title: NSLocalizedString("fileShare.howItWorks", comment: ""))
            
            HStack(spacing: CTSpacing.lg) {
                stepCard(
                    number: "1",
                    title: NSLocalizedString("fileShare.step1.title", comment: ""),
                    description: NSLocalizedString("fileShare.step1.desc", comment: ""),
                    icon: "folder"
                )
                
                Image(systemName: "arrow.right")
                    .foregroundStyle(CTColors.textTertiary)
                
                stepCard(
                    number: "2",
                    title: NSLocalizedString("fileShare.step2.title", comment: ""),
                    description: NSLocalizedString("fileShare.step2.desc", comment: ""),
                    icon: "server.rack"
                )
                
                Image(systemName: "arrow.right")
                    .foregroundStyle(CTColors.textTertiary)
                
                stepCard(
                    number: "3",
                    title: NSLocalizedString("fileShare.step3.title", comment: ""),
                    description: NSLocalizedString("fileShare.step3.desc", comment: ""),
                    icon: "link"
                )
            }
        }
    }
    
    func stepCard(number: String, title: String, description: String, icon: String) -> some View {
        VStack(spacing: CTSpacing.md) {
            ZStack {
                Circle()
                    .fill(CTColors.brand.opacity(0.1))
                    .frame(width: 44, height: 44)
                
                Text(number)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(CTColors.brand)
            }
            
            Text(title)
                .font(CTTypography.headline)
                .foregroundStyle(CTColors.textPrimary)
            
            Text(description)
                .font(CTTypography.caption)
                .foregroundStyle(CTColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(CTSpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: CTRadius.md, style: .continuous)
                .fill(Color.primary.opacity(0.02))
        )
    }
    
    // MARK: - Actions
    func selectFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = NSLocalizedString("fileShare.selectFolder.message", comment: "")
        
        if panel.runModal() == .OK, let url = panel.url {
            Task {
                await fileShareService.startSharing(folderPath: url.path)
            }
        }
    }
}
