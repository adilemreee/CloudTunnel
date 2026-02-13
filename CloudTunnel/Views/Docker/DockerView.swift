// MARK: - Docker View
// Docker container management & tunnel creation from containers

import SwiftUI

struct DockerView: View {
    @EnvironmentObject var dockerService: DockerService
    @EnvironmentObject var tunnelService: TunnelService
    
    @State private var searchText = ""
    @State private var selectedContainer: DockerContainer? = nil
    @State private var showCreateTunnel = false
    @State private var selectedPort: DockerContainer.PortMapping? = nil
    
    var filteredContainers: [DockerContainer] {
        if searchText.isEmpty { return dockerService.containers }
        return dockerService.containers.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.image.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerBar
            
            Divider()
            
            if !dockerService.isDockerInstalled {
                CTEmptyState(
                    icon: "shippingbox",
                    title: NSLocalizedString("docker.notInstalled.title", comment: ""),
                    message: NSLocalizedString("docker.notInstalled.message", comment: "")
                )
            } else if !dockerService.isDockerRunning {
                CTEmptyState(
                    icon: "shippingbox",
                    title: NSLocalizedString("docker.notRunning.title", comment: ""),
                    message: NSLocalizedString("docker.notRunning.message", comment: ""),
                    action: { dockerService.checkDockerStatus() },
                    actionTitle: NSLocalizedString("docker.refresh", comment: "")
                )
            } else if dockerService.containers.isEmpty {
                CTEmptyState(
                    icon: "shippingbox",
                    title: NSLocalizedString("docker.noContainers.title", comment: ""),
                    message: NSLocalizedString("docker.noContainers.message", comment: ""),
                    action: { dockerService.refreshContainers() },
                    actionTitle: NSLocalizedString("docker.refresh", comment: "")
                )
            } else {
                HSplitView {
                    // Container List
                    containerList
                        .frame(minWidth: 320)
                    
                    // Detail Panel
                    if let container = selectedContainer {
                        containerDetail(container)
                            .frame(minWidth: 300)
                    } else {
                        VStack {
                            Spacer()
                            Text(NSLocalizedString("docker.selectContainer", comment: ""))
                                .font(CTTypography.callout)
                                .foregroundStyle(CTColors.textTertiary)
                            Spacer()
                        }
                        .frame(minWidth: 300)
                    }
                }
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .sheet(isPresented: $showCreateTunnel) {
            if let container = selectedContainer {
                CreateFromDockerSheet(container: container, selectedPort: selectedPort)
                    .frame(minWidth: 480, minHeight: 400)
            }
        }
    }
    
    // MARK: - Header
    var headerBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Docker")
                    .font(CTTypography.title)
                    .foregroundStyle(CTColors.textPrimary)
                
                HStack(spacing: CTSpacing.sm) {
                    Circle()
                        .fill(dockerService.isDockerRunning ? CTColors.success : CTColors.danger)
                        .frame(width: 8, height: 8)
                    
                    Text(dockerService.isDockerRunning
                         ? "\(dockerService.containers.count) containers"
                         : "Docker not running")
                        .font(CTTypography.callout)
                        .foregroundStyle(CTColors.textSecondary)
                }
            }
            
            Spacer()
            
            CTButton(NSLocalizedString("docker.refresh", comment: ""), icon: "arrow.clockwise", style: .secondary) {
                dockerService.checkDockerStatus()
            }
        }
        .padding(CTSpacing.lg)
    }
    
    // MARK: - Container List
    var containerList: some View {
        VStack(spacing: 0) {
            CTSearchBar(text: $searchText, placeholder: "Search containers...")
                .padding(CTSpacing.md)
            
            ScrollView {
                LazyVStack(spacing: CTSpacing.xs) {
                    ForEach(filteredContainers) { container in
                        ContainerRow(
                            container: container,
                            isSelected: selectedContainer?.id == container.id
                        ) {
                            selectedContainer = container
                        }
                    }
                }
                .padding(.horizontal, CTSpacing.md)
                .padding(.bottom, CTSpacing.md)
            }
        }
    }
    
    // MARK: - Container Detail
    func containerDetail(_ container: DockerContainer) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CTSpacing.xl) {
                // Container Info
                HStack(spacing: CTSpacing.lg) {
                    CTIconBadge(
                        icon: "shippingbox.fill",
                        color: container.isRunning ? CTColors.success : CTColors.textTertiary,
                        size: 48
                    )
                    
                    VStack(alignment: .leading, spacing: 3) {
                        Text(container.name)
                            .font(CTTypography.title2)
                            .foregroundStyle(CTColors.textPrimary)
                        
                        Text(container.image)
                            .font(CTTypography.mono)
                            .foregroundStyle(CTColors.textSecondary)
                    }
                    
                    Spacer()
                    
                    CTStatusBadge(status: container.isRunning ? .running : .stopped)
                }
                
                Divider()
                
                // Info
                VStack(spacing: CTSpacing.sm) {
                    CTInfoRow(label: "Container ID", value: String(container.id.prefix(12)), isMono: true, copyable: true)
                    CTInfoRow(label: "Image", value: container.image, isMono: true)
                    CTInfoRow(label: "Status", value: container.status)
                }
                
                // Ports
                if !container.ports.isEmpty {
                    VStack(alignment: .leading, spacing: CTSpacing.md) {
                        Text("Exposed Ports")
                            .font(CTTypography.headline)
                            .foregroundStyle(CTColors.textPrimary)
                        
                        ForEach(container.ports, id: \.self) { port in
                            HStack {
                                CTIconBadge(icon: "network", color: CTColors.brand, size: 28)
                                
                                Text("\(port.hostPort) → \(port.containerPort)/\(port.proto)")
                                    .font(CTTypography.mono)
                                    .foregroundStyle(CTColors.textPrimary)
                                
                                Spacer()
                                
                                CTButton(NSLocalizedString("docker.createTunnel", comment: ""), icon: "plus", style: .primary) {
                                    selectedPort = port
                                    showCreateTunnel = true
                                }
                            }
                            .padding(CTSpacing.md)
                            .background(
                                RoundedRectangle(cornerRadius: CTRadius.sm, style: .continuous)
                                    .fill(Color.primary.opacity(0.03))
                            )
                        }
                    }
                }
                
                // Create Tunnel Button (no ports)
                if container.ports.isEmpty && container.isRunning {
                    CTButton(NSLocalizedString("docker.createTunnel", comment: ""), icon: "point.3.connected.trianglepath.dotted", style: .primary) {
                        showCreateTunnel = true
                    }
                }
            }
            .padding(CTSpacing.xl)
        }
    }
}

// MARK: - Container Row
struct ContainerRow: View {
    let container: DockerContainer
    let isSelected: Bool
    let onTap: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: CTSpacing.md) {
                Circle()
                    .fill(container.isRunning ? CTColors.success : CTColors.textTertiary)
                    .frame(width: 8, height: 8)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(container.name)
                        .font(CTTypography.headline)
                        .foregroundStyle(CTColors.textPrimary)
                        .lineLimit(1)
                    
                    Text(container.image)
                        .font(CTTypography.caption)
                        .foregroundStyle(CTColors.textTertiary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                if !container.ports.isEmpty {
                    Text("\(container.ports.count)")
                        .font(CTTypography.captionBold)
                        .foregroundStyle(CTColors.brand)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(CTColors.brand.opacity(0.1))
                        .clipShape(Capsule())
                }
            }
            .padding(CTSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: CTRadius.sm, style: .continuous)
                    .fill(isSelected ? CTColors.sidebarSelected : (isHovered ? CTColors.sidebarHover : .clear))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Create from Docker Sheet
struct CreateFromDockerSheet: View {
    let container: DockerContainer
    let selectedPort: DockerContainer.PortMapping?
    
    @EnvironmentObject var tunnelService: TunnelService
    @Environment(\.dismiss) var dismiss
    
    @State private var tunnelName = ""
    @State private var hostname = ""
    @State private var port = ""
    @State private var isCreating = false
    @State private var errorMessage: String?
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Create Tunnel from Docker")
                    .font(CTTypography.title2)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(CTColors.textTertiary)
                        .frame(width: 28, height: 28)
                        .background(Color.primary.opacity(0.06))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(CTSpacing.xl)
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: CTSpacing.xl) {
                    // Container info
                    HStack(spacing: CTSpacing.md) {
                        CTIconBadge(icon: "shippingbox.fill", color: CTColors.brand, size: 40)
                        VStack(alignment: .leading) {
                            Text(container.name).font(CTTypography.headline)
                            Text(container.image).font(CTTypography.caption).foregroundStyle(CTColors.textSecondary)
                        }
                    }
                    
                    formField("Tunnel Name", text: $tunnelName, placeholder: container.name)
                    formField("Hostname", text: $hostname, placeholder: "tunnel.example.com")
                    formField("Port", text: $port, placeholder: "\(selectedPort?.hostPort ?? 80)")
                    
                    if let error = errorMessage {
                        Text(error).font(CTTypography.callout).foregroundStyle(CTColors.danger)
                    }
                }
                .padding(CTSpacing.xl)
            }
            
            Divider()
            
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button {
                    createTunnel()
                } label: {
                    HStack {
                        if isCreating { ProgressView().controlSize(.small) }
                        Text("Create Tunnel")
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(tunnelName.isEmpty || isCreating)
            }
            .padding(CTSpacing.lg)
        }
        .onAppear {
            tunnelName = container.name
            port = "\(selectedPort?.hostPort ?? 80)"
        }
    }
    
    func formField(_ label: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(CTTypography.headline)
            TextField(placeholder, text: text)
                .textFieldStyle(.roundedBorder)
        }
    }
    
    func createTunnel() {
        isCreating = true
        errorMessage = nil
        let portNum = Int(port) ?? selectedPort?.hostPort ?? 80
        
        Task {
            do {
                _ = try await tunnelService.createTunnel(
                    name: tunnelName, hostname: hostname,
                    port: portNum, protocol: .http, source: .docker
                )
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
            isCreating = false
        }
    }
}
