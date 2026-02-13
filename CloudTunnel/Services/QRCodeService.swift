// MARK: - QR Code Service
// Generates QR codes from tunnel URLs for mobile testing

import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins

@MainActor
final class QRCodeService: ObservableObject {
    static let shared = QRCodeService()
    
    private let context = CIContext()
    
    private init() {}
    
    // MARK: - Generate QR Code
    nonisolated func generateQRCode(from string: String, size: CGFloat = 256) -> NSImage? {
        guard let data = string.data(using: .utf8) else { return nil }
        
        let filter = CIFilter.qrCodeGenerator()
        filter.message = data
        filter.correctionLevel = "M"
        
        guard let ciImage = filter.outputImage else { return nil }
        
        let scale = size / ciImage.extent.width
        let transformed = ciImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        
        let context = CIContext()
        guard let cgImage = context.createCGImage(transformed, from: transformed.extent) else { return nil }
        
        return NSImage(cgImage: cgImage, size: NSSize(width: size, height: size))
    }
    
    // MARK: - Generate Styled QR Code
    nonisolated func generateStyledQRCode(from string: String, size: CGFloat = 256, color: NSColor = .black) -> NSImage? {
        guard let data = string.data(using: .utf8) else { return nil }
        
        let filter = CIFilter.qrCodeGenerator()
        filter.message = data
        filter.correctionLevel = "H"
        
        guard let ciImage = filter.outputImage else { return nil }
        
        // Color overlay
        let colorFilter = CIFilter.falseColor()
        colorFilter.inputImage = ciImage
        colorFilter.color0 = CIColor(color: color) ?? CIColor.black
        colorFilter.color1 = CIColor.white
        
        guard let coloredImage = colorFilter.outputImage else { return nil }
        
        let scale = size / coloredImage.extent.width
        let transformed = coloredImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        
        let context = CIContext()
        guard let cgImage = context.createCGImage(transformed, from: transformed.extent) else { return nil }
        
        return NSImage(cgImage: cgImage, size: NSSize(width: size, height: size))
    }
    
    // MARK: - Save QR Code
    nonisolated func saveQRCodeToDisk(_ image: NSImage, filename: String) -> URL? {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            return nil
        }
        
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("\(filename).png")
        
        do {
            try pngData.write(to: fileURL)
            return fileURL
        } catch {
            return nil
        }
    }
    
    // MARK: - Copy QR Code to Clipboard
    nonisolated func copyToClipboard(_ image: NSImage) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.writeObjects([image])
    }
}
