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
    
    private init() {}
    
    // MARK: - Start Sharing
    func startSharing(folderPath: String) async {
        guard !isSharing else { return }
        
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
        
        serverProcess?.terminationHandler = { [weak self] _ in
            Task { @MainActor in
                self?.cleanup()
            }
        }
        
        do {
            try serverProcess?.run()
            HistoryService.shared.log(.info, .fileShare, "HTTP server started on port \(freePort)")
            
            // Wait a moment for the server to start
            try? await Task.sleep(for: .milliseconds(800))
            
            // Start quick tunnel
            await startTunnel(port: freePort)
        } catch {
            cleanup()
            HistoryService.shared.log(.error, .fileShare, "Failed to start HTTP server: \(error)")
        }
    }
    
    // MARK: - Start Tunnel
    private func startTunnel(port: Int) async {
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
                self?.publicURL = nil
            }
        }
        
        do {
            try tunnelProcess?.run()
            
            // Parse URL from output
            Task.detached {
                let handle = pipe.fileHandleForReading
                while true {
                    guard let data = try? handle.availableData, !data.isEmpty else { break }
                    let output = String(data: data, encoding: .utf8) ?? ""
                    
                    if let urlRange = output.range(of: #"https://[a-zA-Z0-9-]+\.trycloudflare\.com"#, options: .regularExpression) {
                        let url = String(output[urlRange])
                        await MainActor.run {
                            self.publicURL = url
                        }
                        HistoryService.shared.logFromBackground(.info, .fileShare, "File share public URL: \(url)")
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
        tunnelProcess?.terminate()
        serverProcess?.terminate()
        cleanup()
        HistoryService.shared.log(.info, .fileShare, "File sharing stopped")
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
    
    // MARK: - Python Server Script
    private func buildPythonServer(directory: String, port: Int) -> String {
        return """
        import http.server
        import socketserver
        import os
        import urllib.parse
        import html

        PORT = \(port)
        DIRECTORY = "\(directory.replacingOccurrences(of: "\"", with: "\\\""))"

        class StyledHandler(http.server.SimpleHTTPRequestHandler):
            def __init__(self, *args, **kwargs):
                super().__init__(*args, directory=DIRECTORY, **kwargs)

            def list_directory(self, path):
                try:
                    entries = os.listdir(path)
                except OSError:
                    self.send_error(404, "Directory not found")
                    return None

                entries.sort(key=lambda x: (not os.path.isdir(os.path.join(path, x)), x.lower()))
                
                rel_path = os.path.relpath(path, DIRECTORY)
                display_path = '/' if rel_path == '.' else '/' + rel_path

                html_content = f'''<!DOCTYPE html>
        <html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
        <title>CloudTunnel File Share</title>
        <style>
        *{{margin:0;padding:0;box-sizing:border-box}}
        body{{font-family:-apple-system,BlinkMacSystemFont,'SF Pro',sans-serif;background:#0F0F1A;color:#E0E0E0;min-height:100vh}}
        .header{{background:linear-gradient(135deg,#1a1a2e,#16213e);padding:24px 32px;border-bottom:1px solid rgba(255,255,255,.06)}}
        .header h1{{font-size:20px;font-weight:600;color:#fff;display:flex;align-items:center;gap:10px}}
        .header .path{{font-size:13px;color:rgba(255,255,255,.5);margin-top:6px;font-family:monospace}}
        .container{{max-width:1000px;margin:0 auto;padding:24px}}
        .file-list{{display:flex;flex-direction:column;gap:2px}}
        .file-item{{display:flex;align-items:center;padding:12px 16px;border-radius:10px;text-decoration:none;color:#E0E0E0;transition:all .15s}}
        .file-item:hover{{background:rgba(66,133,252,.1)}}
        .file-icon{{width:36px;height:36px;border-radius:8px;display:flex;align-items:center;justify-content:center;font-size:18px;margin-right:14px;flex-shrink:0}}
        .dir .file-icon{{background:rgba(66,133,252,.15);color:#4285FC}}
        .file .file-icon{{background:rgba(255,159,10,.1);color:#FF9F0A}}
        .file-name{{font-size:14px;font-weight:500;flex:1}}
        .file-size{{font-size:12px;color:rgba(255,255,255,.4);font-family:monospace}}
        .badge{{font-size:11px;padding:3px 8px;border-radius:20px;background:rgba(255,255,255,.06);color:rgba(255,255,255,.5);margin-left:12px}}
        </style></head><body>
        <div class="header"><h1>📁 CloudTunnel File Share</h1><div class="path">{html.escape(display_path)}</div></div>
        <div class="container"><div class="file-list">'''

                if rel_path != '.':
                    html_content += '<a class="file-item dir" href=".."><div class="file-icon">⬆️</div><div class="file-name">..</div></a>'

                for name in entries:
                    if name.startswith('.'): continue
                    full_path = os.path.join(path, name)
                    link = urllib.parse.quote(name)
                    
                    if os.path.isdir(full_path):
                        count = len([f for f in os.listdir(full_path) if not f.startswith('.')])
                        html_content += f'<a class="file-item dir" href="{link}/"><div class="file-icon">📁</div><div class="file-name">{html.escape(name)}</div><span class="badge">{count} items</span></a>'
                    else:
                        size = os.path.getsize(full_path)
                        size_str = self.format_size(size)
                        html_content += f'<a class="file-item file" href="{link}"><div class="file-icon">📄</div><div class="file-name">{html.escape(name)}</div><span class="file-size">{size_str}</span></a>'

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

        with socketserver.TCPServer(("127.0.0.1", PORT), StyledHandler) as httpd:
            httpd.serve_forever()
        """
    }
}
