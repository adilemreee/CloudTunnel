// MARK: - History View
// Log viewer with filtering, search, and export

import SwiftUI
import UniformTypeIdentifiers

struct HistoryView: View {
    @EnvironmentObject var historyService: HistoryService
    
    @State private var searchText = ""
    @State private var selectedLevel: LogEntry.LogLevel? = nil
    @State private var selectedCategory: LogEntry.LogCategory? = nil
    @State private var showExportDialog = false
    
    var filteredLogs: [LogEntry] {
        historyService.filtered(level: selectedLevel, category: selectedCategory, search: searchText)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerBar
            
            Divider()
            
            // Stats Bar
            statsBar
            
            Divider()
            
            if filteredLogs.isEmpty {
                CTEmptyState(
                    icon: "clock.arrow.circlepath",
                    title: NSLocalizedString("history.empty.title", comment: ""),
                    message: NSLocalizedString("history.empty.message", comment: "")
                )
            } else {
                // Log List
                ScrollView {
                    LazyVStack(spacing: 1) {
                        ForEach(filteredLogs) { entry in
                            LogRow(entry: entry)
                        }
                    }
                    .padding(.horizontal, CTSpacing.lg)
                    .padding(.vertical, CTSpacing.sm)
                }
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .fileExporter(
            isPresented: $showExportDialog,
            document: TextDocument(text: historyService.exportLogs()),
            contentType: .plainText,
            defaultFilename: "cloudtunnel_logs_\(Date().ISO8601Format())"
        ) { _ in }
    }
    
    // MARK: - Header
    var headerBar: some View {
        VStack(spacing: CTSpacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(NSLocalizedString("history.title", comment: ""))
                        .font(CTTypography.title)
                        .foregroundStyle(CTColors.textPrimary)
                    
                    Text("\(historyService.logs.count) " + NSLocalizedString("history.entries", comment: ""))
                        .font(CTTypography.callout)
                        .foregroundStyle(CTColors.textSecondary)
                }
                
                Spacer()
                
                HStack(spacing: CTSpacing.sm) {
                    CTButton(NSLocalizedString("history.export", comment: ""), icon: "square.and.arrow.up", style: .secondary) {
                        showExportDialog = true
                    }
                    
                    CTButton(NSLocalizedString("history.clear", comment: ""), icon: "trash", style: .danger) {
                        historyService.clearLogs()
                    }
                }
            }
            
            HStack(spacing: CTSpacing.sm) {
                CTSearchBar(text: $searchText, placeholder: NSLocalizedString("history.search", comment: ""))
                
                // Level Filter
                Menu {
                    Button(NSLocalizedString("filter.all", comment: "")) { selectedLevel = nil }
                    Divider()
                    ForEach(LogEntry.LogLevel.allCases, id: \.self) { level in
                        Button {
                            selectedLevel = level
                        } label: {
                            Label(level.rawValue.capitalized, systemImage: level.icon)
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "line.3.horizontal.decrease")
                        Text(selectedLevel?.rawValue.capitalized ?? NSLocalizedString("filter.level", comment: ""))
                            .font(CTTypography.captionBold)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(Color.primary.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: CTRadius.sm))
                }
                
                // Category Filter
                Menu {
                    Button(NSLocalizedString("filter.all", comment: "")) { selectedCategory = nil }
                    Divider()
                    ForEach(LogEntry.LogCategory.allCases, id: \.self) { category in
                        Button(category.displayName) { selectedCategory = category }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "tag")
                        Text(selectedCategory?.displayName ?? NSLocalizedString("filter.category", comment: ""))
                            .font(CTTypography.captionBold)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(Color.primary.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: CTRadius.sm))
                }
            }
        }
        .padding(CTSpacing.lg)
    }
    
    // MARK: - Stats Bar
    var statsBar: some View {
        HStack(spacing: CTSpacing.xl) {
            statItem("Total", count: historyService.logs.count, color: CTColors.textSecondary)
            statItem("Errors", count: historyService.errorCount, color: CTColors.danger)
            statItem("Warnings", count: historyService.warningCount, color: CTColors.warning)
            statItem("Today", count: historyService.todayCount, color: CTColors.brand)
            Spacer()
        }
        .padding(.horizontal, CTSpacing.lg)
        .padding(.vertical, CTSpacing.sm)
        .background(Color.primary.opacity(0.02))
    }
    
    func statItem(_ label: String, count: Int, color: Color) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            
            Text("\(count)")
                .font(CTTypography.captionBold)
                .foregroundStyle(CTColors.textPrimary)
            
            Text(label)
                .font(CTTypography.caption)
                .foregroundStyle(CTColors.textTertiary)
        }
    }
}

// MARK: - Log Row
struct LogRow: View {
    let entry: LogEntry
    @State private var isExpanded = false
    
    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()
    
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return f
    }()
    
    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) { isExpanded.toggle() }
        } label: {
            VStack(alignment: .leading, spacing: isExpanded ? CTSpacing.sm : 0) {
                HStack(spacing: CTSpacing.sm) {
                    // Level icon
                    Image(systemName: entry.level.icon)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(entry.level.color)
                        .frame(width: 18)
                    
                    // Timestamp
                    Text(Self.timeFormatter.string(from: entry.timestamp))
                        .font(CTTypography.monoSmall)
                        .foregroundStyle(CTColors.textTertiary)
                        .frame(width: 60, alignment: .leading)
                    
                    // Category badge
                    Text(entry.category.displayName)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(CTColors.textTertiary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.primary.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                    
                    // Message
                    Text(entry.message)
                        .font(CTTypography.callout)
                        .foregroundStyle(CTColors.textPrimary)
                        .lineLimit(isExpanded ? nil : 1)
                    
                    Spacer()
                }
                
                if isExpanded {
                    VStack(alignment: .leading, spacing: 4) {
                        CTInfoRow(label: "Time", value: Self.dateFormatter.string(from: entry.timestamp))
                        CTInfoRow(label: "Level", value: entry.level.rawValue.capitalized)
                        CTInfoRow(label: "Category", value: entry.category.displayName)
                        if let source = entry.source {
                            CTInfoRow(label: "Source", value: source)
                        }
                    }
                    .padding(.leading, 28)
                    .padding(.top, 4)
                }
            }
            .padding(.vertical, 6)
            .padding(.horizontal, CTSpacing.sm)
            .background(
                RoundedRectangle(cornerRadius: CTRadius.sm, style: .continuous)
                    .fill(isExpanded ? Color.primary.opacity(0.03) : .clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Text Document for Export
struct TextDocument: FileDocument {
    static var readableContentTypes: [UTType] = [.plainText]
    var text: String
    
    init(text: String) { self.text = text }
    
    init(configuration: ReadConfiguration) throws {
        text = String(data: configuration.file.regularFileContents ?? Data(), encoding: .utf8) ?? ""
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: text.data(using: .utf8)!)
    }
}
