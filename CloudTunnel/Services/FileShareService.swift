// MARK: - File Share Service
// Python HTTP server + Cloudflare quick tunnel for file sharing

import Foundation

@MainActor
final class FileShareService: ObservableObject {
    static let shared = FileShareService()
    
    @Published var isSharing = false
    @Published var selectedFolder: String?
    @Published var publicURL: String?
    @Published var localURL: String?
    @Published var port: Int?
    
    private var serverProcess: Process?
    private var tunnelProcess: Process?
    private var currentSessionID = UUID()
    
    private init() {}
    
    // MARK: - Start Sharing
    func startSharing(folderPath: String) async {
        guard !isSharing else { return }
        
        let sessionID = UUID()
        currentSessionID = sessionID
        
        selectedFolder = folderPath
        
        // Find a free port
        let freePort = PortService.shared.findFreePort(startingFrom: 50000)
        guard let freePort else {
            HistoryService.shared.log(.error, .fileShare, "Could not find a free port")
            return
        }
        
        port = freePort
        localURL = "http://127.0.0.1:\(freePort)"
        isSharing = true
        
        // Start Python HTTP server with custom template
        let pythonScript = buildPythonServer(directory: folderPath, port: freePort)
        
        serverProcess = Process()
        serverProcess?.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        serverProcess?.arguments = ["-c", pythonScript]
        serverProcess?.standardOutput = Pipe()
        serverProcess?.standardError = Pipe()
        
        serverProcess?.terminationHandler = { [weak self] process in
            Task { @MainActor in
                guard let self else { return }
                guard self.currentSessionID == sessionID else { return }
                
                self.cleanup()
                
                if process.terminationStatus != 0 {
                    HistoryService.shared.log(.warning, .fileShare, "HTTP server exited unexpectedly (status: \(process.terminationStatus))")
                }
            }
        }
        
        do {
            try serverProcess?.run()
            HistoryService.shared.log(.info, .fileShare, "HTTP server started on port \(freePort)")
            
            // Wait a moment for the server to start
            try? await Task.sleep(for: .milliseconds(800))
            
            // Start quick tunnel
            await startTunnel(port: freePort, sessionID: sessionID)
        } catch {
            cleanup()
            HistoryService.shared.log(.error, .fileShare, "Failed to start HTTP server: \(error)")
        }
    }
    
    // MARK: - Start Tunnel
    private func startTunnel(port: Int, sessionID: UUID) async {
        let tunnelService = TunnelService.shared
        guard tunnelService.cloudflaredInstalled else {
            HistoryService.shared.log(.error, .fileShare, "cloudflared not available")
            return
        }
        
        tunnelProcess = Process()
        tunnelProcess?.executableURL = URL(fileURLWithPath: tunnelService.cloudflaredPath)
        tunnelProcess?.arguments = ["tunnel", "--url", "http://127.0.0.1:\(port)"]
        
        let pipe = Pipe()
        tunnelProcess?.standardOutput = pipe
        tunnelProcess?.standardError = pipe
        
        tunnelProcess?.terminationHandler = { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                guard self.currentSessionID == sessionID else { return }
                
                self.publicURL = nil
            }
        }
        
        do {
            try tunnelProcess?.run()
            
            // Parse URL from output
            Task.detached {
                let handle = pipe.fileHandleForReading
                while true {
                    let data = handle.availableData
                    guard !data.isEmpty else { break }
                    let output = String(data: data, encoding: .utf8) ?? ""
                    
                    if let urlRange = output.range(of: #"https://[a-zA-Z0-9-]+\.trycloudflare\.com"#, options: .regularExpression) {
                        let url = String(output[urlRange])
                        let hasPublicDNS = await Self.isPublishedOnPublicDNS(urlString: url)
                        await MainActor.run {
                            guard self.currentSessionID == sessionID else { return }
                            self.publicURL = url
                            
                            if hasPublicDNS {
                                HistoryService.shared.log(.info, .fileShare, "File share public URL: \(url)")
                            } else {
                                HistoryService.shared.log(.warning, .fileShare, "Public URL created but not yet reachable (DNS propagation may still be in progress): \(url)")
                            }
                        }
                        break
                    }
                }
            }
        } catch {
            HistoryService.shared.log(.error, .fileShare, "Failed to start tunnel: \(error)")
        }
    }
    
    // MARK: - Stop Sharing
    func stopSharing() {
        currentSessionID = UUID()
        
        tunnelProcess?.terminationHandler = nil
        serverProcess?.terminationHandler = nil
        
        terminateProcess(tunnelProcess, label: "Cloudflare tunnel")
        terminateProcess(serverProcess, label: "HTTP server")
        
        cleanup()
        HistoryService.shared.log(.info, .fileShare, "File sharing stopped")
    }
    
    private func terminateProcess(_ process: Process?, label: String) {
        guard let process else { return }
        guard process.isRunning else { return }
        
        let pid = process.processIdentifier
        process.terminate()
        
        let deadline = Date().addingTimeInterval(1.5)
        while process.isRunning && Date() < deadline {
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.05))
        }
        
        if process.isRunning {
            _ = kill(pid, SIGKILL)
            HistoryService.shared.log(.warning, .fileShare, "\(label) did not stop gracefully, force-killed (PID: \(pid))")
        }
    }
    
    private func cleanup() {
        isSharing = false
        publicURL = nil
        localURL = nil
        selectedFolder = nil
        port = nil
        serverProcess = nil
        tunnelProcess = nil
    }
    
    nonisolated private static func isPublishedOnPublicDNS(urlString: String) async -> Bool {
        guard let host = URL(string: urlString)?.host else { return false }
        
        var components = URLComponents(string: "https://cloudflare-dns.com/dns-query")
        components?.queryItems = [
            URLQueryItem(name: "name", value: host),
            URLQueryItem(name: "type", value: "A")
        ]
        
        guard let queryURL = components?.url else { return false }
        
        var request = URLRequest(url: queryURL)
        request.timeoutInterval = 4
        request.setValue("application/dns-json", forHTTPHeaderField: "Accept")
        
        let session = makeDirectSession()
        defer { session.invalidateAndCancel() }
        
        do {
            let (data, _) = try await session.data(for: request)
            let response = try JSONDecoder().decode(CloudflareDNSResponse.self, from: data)
            return response.status == 0 && !(response.answer ?? []).isEmpty
        } catch {
            return false
        }
    }
    
    nonisolated private static func makeDirectSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 4
        config.timeoutIntervalForResource = 6
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        // Avoid PAC/proxy retries for quick DNS/URL health checks.
        config.connectionProxyDictionary = [:]
        return URLSession(configuration: config)
    }
    
    private struct CloudflareDNSResponse: Decodable {
        let status: Int
        let answer: [CloudflareDNSAnswer]?
        
        enum CodingKeys: String, CodingKey {
            case status = "Status"
            case answer = "Answer"
        }
    }
    
    private struct CloudflareDNSAnswer: Decodable {
        let name: String
        let type: Int
        let ttl: Int
        let data: String
        
        enum CodingKeys: String, CodingKey {
            case name
            case type
            case ttl = "TTL"
            case data
        }
    }
    
    // MARK: - Python Server Script
    private func buildPythonServer(directory: String, port: Int) -> String {
        return """
        import http.server
        import socketserver
        import os
        import shutil
        import tempfile
        import urllib.parse
        import zipfile
        import html

        PORT = \(port)
        DIRECTORY = "\(directory.replacingOccurrences(of: "\"", with: "\\\""))"

        class ReusableTCPServer(socketserver.TCPServer):
            allow_reuse_address = True

        class StyledHandler(http.server.SimpleHTTPRequestHandler):
            def __init__(self, *args, **kwargs):
                super().__init__(*args, directory=DIRECTORY, **kwargs)
            
            def do_GET(self):
                parsed = urllib.parse.urlparse(self.path)
                clean_path = parsed.path
                query = urllib.parse.parse_qs(parsed.query)
                
                if clean_path == "/__ct_download_folder__":
                    self.download_folder(query)
                    return
                
                if query.get("download", ["0"])[0] == "1":
                    file_path = os.path.realpath(self.translate_path(clean_path))
                    if self.is_path_inside_root(file_path) and os.path.isfile(file_path):
                        self.send_file_as_attachment(file_path)
                        return
                    self.send_error(404, "File not found")
                    return
                
                self.path = clean_path
                super().do_GET()
            
            def is_path_inside_root(self, target_path):
                root = os.path.realpath(DIRECTORY)
                return target_path == root or target_path.startswith(root + os.sep)
            
            def safe_target_path(self, relative_path):
                raw = urllib.parse.unquote(relative_path or ".")
                normalized = os.path.normpath(raw)
                target_path = os.path.realpath(os.path.join(DIRECTORY, normalized))
                return target_path if self.is_path_inside_root(target_path) else None
            
            def send_file_as_attachment(self, file_path, download_name=None):
                try:
                    file_size = os.path.getsize(file_path)
                    filename = download_name or os.path.basename(file_path)
                    quoted_name = urllib.parse.quote(filename)
                    
                    self.send_response(200)
                    self.send_header("Content-Type", "application/octet-stream")
                    self.send_header("Content-Disposition", f"attachment; filename*=UTF-8''{quoted_name}")
                    self.send_header("Content-Length", str(file_size))
                    self.send_header("Cache-Control", "no-store")
                    self.end_headers()
                    
                    with open(file_path, "rb") as file:
                        shutil.copyfileobj(file, self.wfile)
                except OSError:
                    self.send_error(404, "File not found")
            
            def download_folder(self, query):
                relative_path = query.get("path", ["."])[0]
                target_path = self.safe_target_path(relative_path)
                
                if not target_path or not os.path.isdir(target_path):
                    self.send_error(404, "Folder not found")
                    return
                
                folder_name = os.path.basename(target_path.rstrip(os.sep))
                if not folder_name:
                    folder_name = os.path.basename(os.path.realpath(DIRECTORY)) or "shared-folder"
                
                with tempfile.NamedTemporaryFile(suffix=".zip", delete=False) as temp_file:
                    zip_path = temp_file.name
                
                try:
                    with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED) as zip_file:
                        for folder_root, dir_names, file_names in os.walk(target_path):
                            dir_names[:] = [d for d in dir_names if not d.startswith(".")]
                            for file_name in file_names:
                                if file_name.startswith("."):
                                    continue
                                
                                full_file_path = os.path.join(folder_root, file_name)
                                relative_file_path = os.path.relpath(full_file_path, target_path)
                                archive_path = os.path.join(folder_name, relative_file_path)
                                zip_file.write(full_file_path, archive_path)
                    
                    self.send_file_as_attachment(zip_path, f"{folder_name}.zip")
                finally:
                    try:
                        os.remove(zip_path)
                    except OSError:
                        pass

            def list_directory(self, path):
                try:
                    entries = os.listdir(path)
                except OSError:
                    self.send_error(404, "Directory not found")
                    return None

                entries.sort(key=lambda x: (not os.path.isdir(os.path.join(path, x)), x.lower()))

                rel_path = os.path.relpath(path, DIRECTORY)
                display_path = '/' if rel_path == '.' else '/' + rel_path
                current_folder_download = urllib.parse.quote(rel_path if rel_path != '.' else '.', safe='')

                html_content = f'''<!DOCTYPE html>
        <html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
        <title>CloudTunnel File Share</title>
        <style>
        *{{margin:0;padding:0;box-sizing:border-box}}
        body{{font-family:-apple-system,BlinkMacSystemFont,'SF Pro',sans-serif;background:#0F0F1A;color:#E0E0E0;min-height:100vh}}
        .header{{background:linear-gradient(135deg,#1a1a2e,#16213e);padding:24px 32px;border-bottom:1px solid rgba(255,255,255,.06)}}
        .header-top{{display:flex;align-items:center;justify-content:space-between;gap:12px;flex-wrap:wrap}}
        .header h1{{font-size:20px;font-weight:600;color:#fff;display:flex;align-items:center;gap:10px}}
        .header .path{{font-size:13px;color:rgba(255,255,255,.5);margin-top:6px;font-family:monospace}}
        .header-download{{font-size:12px;font-weight:600;color:#D7E3FF;text-decoration:none;background:rgba(66,133,252,.18);padding:8px 12px;border-radius:10px;border:1px solid rgba(66,133,252,.35)}}
        .header-download:hover{{background:rgba(66,133,252,.28)}}
        .container{{max-width:1000px;margin:0 auto;padding:24px}}
        .file-list{{display:flex;flex-direction:column;gap:2px}}
        .file-item{{display:flex;align-items:center;gap:10px;padding:6px 8px;border-radius:10px;transition:all .15s}}
        .file-item:hover{{background:rgba(66,133,252,.1)}}
        .file-main{{display:flex;align-items:center;flex:1;min-width:0;text-decoration:none;color:#E0E0E0;padding:8px 10px;border-radius:8px}}
        .file-main:hover{{background:rgba(255,255,255,.04)}}
        .file-icon{{width:36px;height:36px;border-radius:8px;display:flex;align-items:center;justify-content:center;font-size:18px;margin-right:14px;flex-shrink:0}}
        .dir .file-icon{{background:rgba(66,133,252,.15);color:#4285FC}}
        .file .file-icon{{background:rgba(255,159,10,.1);color:#FF9F0A}}
        .file-name{{font-size:14px;font-weight:500;flex:1;min-width:0;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}}
        .file-meta{{display:flex;align-items:center;gap:10px;margin-left:10px}}
        .file-size{{font-size:12px;color:rgba(255,255,255,.4);font-family:monospace}}
        .badge{{font-size:11px;padding:3px 8px;border-radius:20px;background:rgba(255,255,255,.06);color:rgba(255,255,255,.5);margin-left:12px}}
        .action-btn{{font-size:12px;font-weight:600;color:#D7E3FF;text-decoration:none;background:rgba(66,133,252,.14);padding:7px 10px;border-radius:8px;border:1px solid rgba(66,133,252,.25);flex-shrink:0}}
        .action-btn:hover{{background:rgba(66,133,252,.24)}}
        </style></head><body>
        <div class="header"><div class="header-top"><h1>📁 CloudTunnel File Share</h1><a class="header-download" href="/__ct_download_folder__?path={current_folder_download}">Download This Folder</a></div><div class="path">{html.escape(display_path)}</div></div>
        <div class="container"><div class="file-list">'''

                if rel_path != '.':
                    html_content += '<div class="file-item dir"><a class="file-main" href=".."><div class="file-icon">⬆️</div><div class="file-name">..</div></a></div>'

                for name in entries:
                    if name.startswith('.'): continue
                    full_path = os.path.join(path, name)
                    link = urllib.parse.quote(name)
                    
                    if os.path.isdir(full_path):
                        try:
                            count = len([f for f in os.listdir(full_path) if not f.startswith('.')])
                        except OSError:
                            count = 0
                        folder_rel = name if rel_path == '.' else f"{rel_path}/{name}"
                        folder_download_link = urllib.parse.quote(folder_rel, safe='')
                        html_content += f'<div class="file-item dir"><a class="file-main" href="{link}/"><div class="file-icon">📁</div><div class="file-name">{html.escape(name)}</div><div class="file-meta"><span class="badge">{count} items</span></div></a><a class="action-btn" href="/__ct_download_folder__?path={folder_download_link}" title="Download folder as ZIP">Download</a></div>'
                    else:
                        size = os.path.getsize(full_path)
                        size_str = self.format_size(size)
                        html_content += f'<div class="file-item file"><a class="file-main" href="{link}"><div class="file-icon">📄</div><div class="file-name">{html.escape(name)}</div><div class="file-meta"><span class="file-size">{size_str}</span></div></a><a class="action-btn" href="{link}?download=1" title="Download file">Download</a></div>'

                html_content += '</div></div></body></html>'
                
                encoded = html_content.encode('utf-8')
                self.send_response(200)
                self.send_header("Content-type", "text/html; charset=utf-8")
                self.send_header("Content-Length", str(len(encoded)))
                self.end_headers()
                self.wfile.write(encoded)
                return None

            def format_size(self, size):
                for unit in ['B', 'KB', 'MB', 'GB']:
                    if size < 1024: return f"{size:.1f} {unit}"
                    size /= 1024
                return f"{size:.1f} TB"

            def log_message(self, format, *args):
                pass

        with ReusableTCPServer(("127.0.0.1", PORT), StyledHandler) as httpd:
            httpd.serve_forever()
        """
    }
}
