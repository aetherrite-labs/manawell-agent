//
//  QRCodeImage.swift
//  ManawellAgentCore
//

import CoreGraphics
import QRCodeGenerator

public enum QRImageError: Error {
    case contextCreationFailed
    case imageCreationFailed
}

public extension QRCodeRenderer {
    /// Renders a crisp black-on-white `CGImage` for `text` (the menu-bar app wraps this
    /// in an `NSImage`). `moduleSize` is the pixel size of each QR module.
    static func cgImage(for text: String, moduleSize: Int = 8, quietZone: Int = 4) throws -> CGImage {
        let qr = try QRCode.encode(text: text, ecl: .medium)
        let modules = qr.size
        let dimension = (modules + quietZone * 2) * moduleSize

        guard let context = CGContext(
            data: nil,
            width: dimension,
            height: dimension,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else {
            throw QRImageError.contextCreationFailed
        }

        context.setFillColor(gray: 1, alpha: 1) // white paper
        context.fill(CGRect(x: 0, y: 0, width: dimension, height: dimension))
        context.setFillColor(gray: 0, alpha: 1) // black modules

        for y in 0..<modules {
            for x in 0..<modules where qr.getModule(x: x, y: y) {
                let originX = (x + quietZone) * moduleSize
                // CoreGraphics' origin is bottom-left; flip y so the code isn't upside down.
                let originY = (modules - 1 - y + quietZone) * moduleSize
                context.fill(CGRect(x: originX, y: originY, width: moduleSize, height: moduleSize))
            }
        }

        guard let image = context.makeImage() else {
            throw QRImageError.imageCreationFailed
        }
        return image
    }
}
